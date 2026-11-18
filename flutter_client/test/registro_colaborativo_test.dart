import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/models/detalle.dart';
import 'package:flutter_client/models/producto.dart';
import 'package:flutter_client/models/reporte_usuario.dart';
import 'package:flutter_client/screens/detalle_screen.dart';
import 'package:flutter_client/screens/mis_reportes_screen.dart';
import 'package:flutter_client/screens/perfil_screen.dart';
import 'package:flutter_client/screens/registro_screen.dart';
import 'package:flutter_client/screens/validacion_screen.dart';
import 'package:flutter_client/services/sesion_service.dart';
import 'package:flutter_client/widgets/producto_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/api_falsa.dart';
import 'helpers/formularios.dart';
import 'helpers/listas_falsas.dart';

/// HU-08: registro colaborativo de precios con evidencia; el precio queda "pendiente" hasta ser validado.
void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));
  setUp(() async => abrirSesion());
  tearDown(() async => cerrarSesion());

  group('Modelos', () {
    test('el reporte del historial conoce su estado y su evidencia', () {
      final r = Reporte.fromJson({
        'reporteId': 1, 'almacen': 'D1', 'sede': 'D1 Suba', 'ciudad': 'Bogotá', 'precioCop': 3900.0,
        'fecha': '2026-10-20', 'dias': 3, 'desactualizado': false, 'usuario': 'Ana', 'variacionCop': null,
        'estado': 'pendiente', 'tieneEvidencia': true, 'motivoRechazo': null,
      });
      expect(r.pendiente, isTrue);
      expect(r.rechazado, isFalse);
      expect(r.tieneEvidencia, isTrue);
    });

    test('un reporte sin estado en el JSON se considera validado (compatibilidad)', () {
      final r = Reporte.fromJson({
        'reporteId': 1, 'almacen': 'D1', 'sede': 'D1 Suba', 'ciudad': 'Bogotá', 'precioCop': 3900.0,
        'fecha': '2026-10-20', 'dias': 3, 'desactualizado': false, 'usuario': 'Ana',
      });
      expect(r.estado, 'validado');
      expect(r.pendiente, isFalse);
    });

    test('ResultadoRegistro, Usuario y Producto leen los campos nuevos', () {
      expect(ResultadoRegistro.fromJson({'productoId': 1, 'reporteId': 2, 'productoNuevo': true, 'estado': 'pendiente'}).pendiente, isTrue);
      expect(ResultadoRegistro.fromJson({'productoId': 1, 'reporteId': 2, 'productoNuevo': true}).pendiente, isFalse);
      expect(Usuario.fromJson({'id': 1, 'nombre': 'Ana', 'email': 'a@x.co', 'rol': 'moderador'}).esModerador, isTrue);
      expect(Usuario.fromJson({'id': 1, 'nombre': 'Ana', 'email': 'a@x.co'}).esModerador, isFalse);
      expect(Producto.fromJson(productoJson()..['nPendientes'] = 2).nPendientes, 2);
      expect(Producto.fromJson(productoJson()).nPendientes, 0);
    });

    test('ReporteUsuario y etiquetas de estado', () {
      final r = ReporteUsuario.fromJson(reporteUsuarioJson(estado: 'rechazado', motivo: 'Foto ilegible'));
      expect(r.rechazado, isTrue);
      expect(r.motivoRechazo, 'Foto ilegible');
      expect(etiquetaEstado('pendiente'), 'Pendiente de validación');
      expect(etiquetaEstado('validado'), 'Validado');
      expect(etiquetaEstado('rechazado'), 'Rechazado');
    });
  });

  testWidgets('el formulario de registro ofrece adjuntar evidencia fotográfica recomendada', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async => listasVacias(p) ?? respuestaJson({}), () async {
      await tester.pumpWidget(MaterialApp(home: RegistroScreen(onRegistrado: (_) {}, irAPerfil: () {})));
      await tester.pumpAndSettle();
      expect(find.text('Evidencia fotográfica (recomendada)'), findsOneWidget);
      expect(find.textContaining('Recomendado: una foto de la etiqueta de precio'), findsOneWidget);
      expect(find.text('Cámara'), findsOneWidget);
      expect(find.text('Galería'), findsOneWidget);
    });
  });

  testWidgets('al registrar un precio nuevo avisa que queda pendiente de validación', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      if (p.method == 'POST') return respuestaJson({'productoId': 12, 'reporteId': 40, 'productoNuevo': true, 'estado': 'pendiente'}, 201);
      return listasVacias(p) ?? respuestaJson({});
    }, () async {
      await tester.pumpWidget(MaterialApp(home: RegistroScreen(onRegistrado: (_) {}, irAPerfil: () {})));
      await tester.pumpAndSettle();
      await llenarRegistro(tester);
      await tester.tap(find.text('Guardar en la nube'));
      await tester.pumpAndSettle();
      expect(find.text('Producto registrado. Tu precio quedó pendiente de validación.'), findsOneWidget);
    });
  });

  testWidgets('el catálogo muestra los productos que solo tienen precios pendientes', (tester) async {
    pantallaAlta(tester);
    final p = Producto.fromJson(productoJson(precioMin: null, precioMax: null, nSedes: 0, diasUltima: null, mejorAlmacen: null, mejorCiudad: null)
      ..['nPendientes'] = 1);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductoCard(producto: p, onTap: () {}))));
    expect(find.text('Precio pendiente de validación'), findsOneWidget);
    expect(find.text('Sin precios reportados'), findsNothing);
  });

  testWidgets('el detalle avisa de los precios pendientes y los distingue en el historial', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      if (p.url.path.endsWith('/comparacion')) return respuestaJson(comparacionJson(precios: []));
      if (p.url.path.endsWith('/historial')) {
        return respuestaJson([
          reporteJson(id: 3, almacen: 'D1', precio: 3900)..['estado'] = 'pendiente'..['tieneEvidencia'] = true,
          reporteJson(id: 2, almacen: 'Ara', precio: 100)..['estado'] = 'rechazado'..['motivoRechazo'] = 'Precio irreal',
          reporteJson(id: 1, almacen: 'Éxito', precio: 5000),
        ]);
      }
      return listasVacias(p) ?? respuestaJson({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: DetalleScreen(productoId: 7)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hay 1 precio pendiente de validación'), findsOneWidget);
      expect(find.text('Sin precios en esta selección'), findsOneWidget);
      expect(find.textContaining('pendiente de validación · con evidencia'), findsOneWidget);
      expect(find.textContaining('rechazado: Precio irreal'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top), findsWidgets);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  });

  testWidgets('reportar un precio nuevo informa que quedó pendiente', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      if (p.method == 'POST') return respuestaJson({'productoId': 7, 'reporteId': 99, 'productoNuevo': false, 'estado': 'pendiente'}, 201);
      if (p.url.path.endsWith('/comparacion')) return respuestaJson(comparacionJson());
      if (p.url.path.endsWith('/historial')) return respuestaJson(historialBasico());
      return listasVacias(p) ?? respuestaJson({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: DetalleScreen(productoId: 7)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar precio'));
      await tester.pumpAndSettle();
      expect(find.text('Evidencia fotográfica (recomendada)'), findsOneWidget);
      await escribir(tester, 'Almacén (Éxito, D1, Ara...)', 'Éxito');
      await escribir(tester, 'Sede (ej. Éxito Chapinero)', 'Éxito Chapinero');
      await escribir(tester, 'Ciudad', 'Bogotá');
      await escribir(tester, 'Precio en COP', '4200');
      await tester.tap(find.text('Guardar precio'));
      await tester.pumpAndSettle();
      expect(find.text('Reporte enviado. Quedó pendiente de validación.'), findsOneWidget);
    });
  });

  group('Mis reportes', () {
    testWidgets('muestra cada reporte con su estado, motivo de rechazo y evidencia', (tester) async {
      pantallaAlta(tester);
      String? ruta;
      await conApiFalsa((p) async {
        ruta = p.url.path;
        return respuestaJson([
          reporteUsuarioJson(id: 1, estado: 'pendiente', evidencia: false),
          reporteUsuarioJson(id: 2, producto: 'Arroz blanco', estado: 'validado', precio: 3600),
          reporteUsuarioJson(id: 3, producto: 'Aceite', estado: 'rechazado', motivo: 'Foto ilegible'),
        ]);
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: MisReportesScreen()));
        await tester.pumpAndSettle();
        expect(ruta, '/api/usuarios/5/reportes');
        expect(find.text('Pendiente de validación'), findsWidgets);
        expect(find.text('Validado'), findsWidgets);
        expect(find.text('Rechazado'), findsWidgets);
        expect(find.text('Motivo: Foto ilegible'), findsOneWidget);
        expect(find.text('Arroz blanco'), findsOneWidget);
      });
    });

    testWidgets('filtra por estado', (tester) async {
      pantallaAlta(tester);
      final consultas = <Map<String, String>>[];
      await conApiFalsa((p) async {
        consultas.add(p.url.queryParameters);
        return respuestaJson([reporteUsuarioJson()]);
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: MisReportesScreen()));
        await tester.pumpAndSettle();
        expect(consultas.last.containsKey('estado'), isFalse);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Pendientes'));
        await tester.pumpAndSettle();
        expect(consultas.last['estado'], 'pendiente');
        await tester.tap(find.widgetWithText(ChoiceChip, 'Rechazados'));
        await tester.pumpAndSettle();
        expect(consultas.last['estado'], 'rechazado');
      });
    });

    testWidgets('sin reportes lo indica', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((p) async => respuestaJson([]), () async {
        await tester.pumpWidget(const MaterialApp(home: MisReportesScreen()));
        await tester.pumpAndSettle();
        expect(find.text('No hay reportes en esta categoría'), findsOneWidget);
      });
    });
  });

  group('Perfil y rol de moderador', () {
    testWidgets('un usuario común ve "Mis reportes" pero no "Validar precios"', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((p) async {
        if (p.url.path == '/api/usuarios/5') return respuestaJson({'id': 5, 'nombre': 'Ana', 'email': 'ana@example.com', 'rol': 'usuario'});
        return respuestaJson({'estado': 'ok', 'baseDeDatos': 'conectada', 'productos': 1, 'reportes': 1, 'usuarios': 1});
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Mis reportes'), findsOneWidget);
        expect(find.text('Validar precios'), findsNothing);
      });
    });

    testWidgets('un moderador ve "Validar precios"', (tester) async {
      pantallaAlta(tester);
      await abrirSesion(rol: 'moderador');
      await conApiFalsa((p) async {
        if (p.url.path == '/api/usuarios/5') return respuestaJson({'id': 5, 'nombre': 'Ana', 'email': 'ana@example.com', 'rol': 'moderador'});
        return respuestaJson({'estado': 'ok', 'baseDeDatos': 'conectada', 'productos': 1, 'reportes': 1, 'usuarios': 1});
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Validar precios'), findsOneWidget);
      });
    });

    testWidgets('el rol se sincroniza con el servidor al abrir el perfil', (tester) async {
      pantallaAlta(tester); // sesión guardada como "usuario"; el servidor ya lo ascendió
      await conApiFalsa((p) async {
        if (p.url.path == '/api/usuarios/5') return respuestaJson({'id': 5, 'nombre': 'Ana', 'email': 'ana@example.com', 'rol': 'moderador'});
        return respuestaJson({'estado': 'ok', 'baseDeDatos': 'conectada', 'productos': 1, 'reportes': 1, 'usuarios': 1});
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
        await tester.pumpAndSettle();
        expect(Sesion.instancia.usuario!.rol, 'moderador');
        expect(find.text('Validar precios'), findsOneWidget);
      });
    });
  });

  group('Validación por moderadores', () {
    Widget app() => const MaterialApp(home: ValidacionScreen());

    testWidgets('lista los precios pendientes con su evidencia', (tester) async {
      pantallaAlta(tester);
      String? moderador;
      await conApiFalsa((p) async {
        moderador = p.url.queryParameters['usuarioId'];
        return respuestaJson([
          reporteUsuarioJson(id: 11, producto: 'Leche entera', usuario: 'Luis'),
          reporteUsuarioJson(id: 12, producto: 'Arroz blanco', precio: 3600, usuario: 'Marta'),
        ]);
      }, () async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(moderador, '5');
        expect(find.text('Leche entera'), findsOneWidget);
        expect(find.text('Arroz blanco'), findsOneWidget);
        expect(find.textContaining('reportado por Luis'), findsOneWidget);
        expect(find.text('Sin evidencia fotográfica'), findsNWidgets(2));
        expect(find.text('Validar'), findsNWidgets(2));
        expect(find.text('Rechazar'), findsNWidgets(2));
      });
    });

    testWidgets('validar un precio lo envía al servidor y lo quita de la cola', (tester) async {
      pantallaAlta(tester);
      Map<String, dynamic>? enviado;
      String? ruta;
      await conApiFalsa((p) async {
        if (p.method == 'POST') {
          ruta = p.url.path;
          enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
          return respuestaJson({'reporteId': 11, 'estado': 'validado'});
        }
        return respuestaJson([reporteUsuarioJson(id: 11), reporteUsuarioJson(id: 12, producto: 'Arroz blanco')]);
      }, () async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('validar-11')));
        await tester.pumpAndSettle();
        expect(ruta, '/api/precios/11/validar');
        expect(enviado, {'usuarioId': 5});
        expect(find.text('Leche entera'), findsNothing);
        expect(find.text('Arroz blanco'), findsOneWidget);
        expect(find.text('Precio validado: ya es oficial'), findsOneWidget);
      });
    });

    testWidgets('rechazar un precio pide un motivo y lo envía', (tester) async {
      pantallaAlta(tester);
      Map<String, dynamic>? enviado;
      String? ruta;
      await conApiFalsa((p) async {
        if (p.method == 'POST') {
          ruta = p.url.path;
          enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
          return respuestaJson({'reporteId': 11, 'estado': 'rechazado'});
        }
        return respuestaJson([reporteUsuarioJson(id: 11)]);
      }, () async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('rechazar-11')));
        await tester.pumpAndSettle();
        expect(find.text('Rechazar precio'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '  Foto ilegible ');
        await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Rechazar')));
        await tester.pumpAndSettle();

        expect(ruta, '/api/precios/11/rechazar');
        expect(enviado, {'usuarioId': 5, 'motivo': 'Foto ilegible'});
        expect(find.text('Precio rechazado'), findsOneWidget);
        expect(find.text('No hay precios pendientes'), findsOneWidget);
      });
    });

    testWidgets('rechazar sin motivo también es posible (el motivo es opcional)', (tester) async {
      pantallaAlta(tester);
      Map<String, dynamic>? enviado;
      await conApiFalsa((p) async {
        if (p.method == 'POST') {
          enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
          return respuestaJson({'reporteId': 11, 'estado': 'rechazado'});
        }
        return respuestaJson([reporteUsuarioJson(id: 11)]);
      }, () async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('rechazar-11')));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Rechazar')));
        await tester.pumpAndSettle();
        expect(enviado, {'usuarioId': 5});
      });
    });

    testWidgets('cancelar el rechazo no envía nada', (tester) async {
      pantallaAlta(tester);
      var posts = 0;
      await conApiFalsa((p) async {
        if (p.method == 'POST') posts++;
        return respuestaJson([reporteUsuarioJson(id: 11)]);
      }, () async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('rechazar-11')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(posts, 0);
        expect(find.text('Leche entera'), findsOneWidget);
      });
    });

    testWidgets('si no hay pendientes lo indica', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((p) async => respuestaJson([]), () async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('No hay precios pendientes'), findsOneWidget);
      });
    });

    testWidgets('un usuario sin permiso recibe el mensaje del servidor', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((p) async => respuestaJson({'error': 'Solo un moderador puede validar precios'}, 403), () async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('No se pudo cargar la cola de validación'), findsOneWidget);
        expect(find.text('Solo un moderador puede validar precios'), findsOneWidget);
      });
    });

    testWidgets('si el servidor rechaza la validación (ya procesado) informa y conserva la lista', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((p) async {
        if (p.method == 'POST') return respuestaJson({'error': 'El reporte ya fue validado'}, 409);
        return respuestaJson([reporteUsuarioJson(id: 11)]);
      }, () async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('validar-11')));
        await tester.pumpAndSettle();
        expect(find.text('El reporte ya fue validado'), findsOneWidget);
        expect(find.text('Leche entera'), findsOneWidget);
      });
    });
  });
}
