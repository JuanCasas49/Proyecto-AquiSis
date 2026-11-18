import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_client/screens/listas_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/api_falsa.dart';
import 'helpers/listas_falsas.dart';

/// HU-06: crear varias listas con nombre propio, renombrar y eliminar.
void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));
  setUp(() async => abrirSesion());
  tearDown(() async => cerrarSesion());

  Widget app({VoidCallback? irAPerfil}) => MaterialApp(home: ListasScreen(irAPerfil: irAPerfil ?? () {}));

  testWidgets('sin identificarse pide ir al Perfil', (tester) async {
    pantallaAlta(tester);
    await cerrarSesion();
    var fue = false;
    await conApiFalsa((p) async => respuestaJson([]), () async {
      await tester.pumpWidget(app(irAPerfil: () => fue = true));
      await tester.pumpAndSettle();
      expect(find.text('Identifíquese para usar sus listas'), findsOneWidget);
      expect(find.text('Nueva lista'), findsNothing);
      await tester.tap(find.text('Ir a Perfil'));
      expect(fue, isTrue);
    });
  });

  testWidgets('muestra las listas del usuario con sus productos y unidades', (tester) async {
    pantallaAlta(tester);
    Map<String, String>? consulta;
    await conApiFalsa((p) async {
      consulta = p.url.queryParameters;
      return respuestaJson([
        listaResumenJson(id: 1, nombre: 'Compra semanal', nProductos: 3, nUnidades: 8),
        listaResumenJson(id: 2, nombre: 'Fiesta', nProductos: 1, nUnidades: 1),
      ]);
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(consulta!['usuarioId'], '5');
      expect(find.text('Compra semanal'), findsOneWidget);
      expect(find.text('Fiesta'), findsOneWidget);
      expect(find.text('3 productos · 8 unidades'), findsOneWidget);
      expect(find.text('1 producto · 1 unidad'), findsOneWidget);
    });
  });

  testWidgets('sin listas invita a crear la primera', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async => respuestaJson([]), () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Aún no tiene listas'), findsOneWidget);
      expect(find.text('Crear mi primera lista'), findsOneWidget);
    });
  });

  testWidgets('si falla la conexión muestra el error y permite reintentar', (tester) async {
    pantallaAlta(tester);
    var llamadas = 0;
    await conApiFalsa((p) async {
      llamadas++;
      if (llamadas == 1) throw Exception('sin red');
      return respuestaJson([listaResumenJson()]);
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('No se pudieron cargar sus listas'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Compra semanal'), findsOneWidget);
    });
  });

  testWidgets('crear una lista con nombre propio la envía al servidor y abre la lista', (tester) async {
    pantallaAlta(tester);
    Map<String, dynamic>? enviado;
    await conApiFalsa((p) async {
      if (p.method == 'POST' && p.url.path == '/api/listas') {
        enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        return respuestaJson(listaResumenJson(id: 4, nombre: 'Fiesta de grado', nProductos: 0, nUnidades: 0), 201);
      }
      if (p.url.path == '/api/listas/4') return respuestaJson(listaDetalleJson(id: 4, nombre: 'Fiesta de grado', items: []));
      return respuestaJson([]);
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva lista'));
      await tester.pumpAndSettle();
      expect(find.text('Nombre de la lista'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Fiesta de grado ');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(enviado, {'usuarioId': 5, 'nombre': 'Fiesta de grado'});
      expect(find.text('La lista está vacía'), findsOneWidget); // se abrió la lista nueva
    });
  });

  testWidgets('no permite crear una lista sin nombre', (tester) async {
    pantallaAlta(tester);
    var posts = 0;
    await conApiFalsa((p) async {
      if (p.method == 'POST') posts++;
      return respuestaJson([]);
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva lista'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      expect(find.text('Nombre de la lista'), findsOneWidget); // el diálogo sigue abierto
    });
  });

  testWidgets('un nombre repetido muestra el mensaje del servidor', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      if (p.method == 'POST') return respuestaJson({'error': 'Ya tiene una lista llamada "Fiesta"'}, 409);
      return respuestaJson([listaResumenJson(nombre: 'Fiesta')]);
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva lista'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Fiesta');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Ya tiene una lista llamada "Fiesta"'), findsOneWidget);
    });
  });

  testWidgets('renombrar una lista', (tester) async {
    pantallaAlta(tester);
    Map<String, dynamic>? enviado;
    var nombre = 'Compra semanal';
    await conApiFalsa((p) async {
      if (p.method == 'PUT' && p.url.path == '/api/listas/1') {
        enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        nombre = enviado!['nombre'] as String;
        return respuestaJson(listaResumenJson(nombre: nombre));
      }
      return respuestaJson([listaResumenJson(nombre: nombre)]);
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones de la lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renombrar'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Compra semanal'); // viene precargado
      await tester.enterText(find.byType(TextField), 'Mercado quincenal');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(enviado, {'usuarioId': 5, 'nombre': 'Mercado quincenal'});
      expect(find.text('Mercado quincenal'), findsOneWidget);
    });
  });

  testWidgets('eliminar una lista pide confirmación y la elimina', (tester) async {
    pantallaAlta(tester);
    _Borrado? borrado;
    var eliminada = false;
    await conApiFalsa((p) async {
      if (p.method == 'DELETE') {
        borrado = _Borrado(p.url.path, p.url.queryParameters);
        eliminada = true;
        return respuestaJson(null, 204);
      }
      return respuestaJson(eliminada ? [] : [listaResumenJson()]);
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones de la lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar "Compra semanal"? Se quitarán sus 3 productos.'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(borrado!.ruta, '/api/listas/1');
      expect(borrado!.consulta['usuarioId'], '5');
      expect(find.text('Lista eliminada'), findsOneWidget);
      expect(find.text('Aún no tiene listas'), findsOneWidget);
    });
  });

  testWidgets('cancelar la eliminación no borra nada', (tester) async {
    pantallaAlta(tester);
    var borrados = 0;
    await conApiFalsa((p) async {
      if (p.method == 'DELETE') borrados++;
      return respuestaJson([listaResumenJson()]);
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones de la lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(borrados, 0);
      expect(find.text('Compra semanal'), findsOneWidget);
    });
  });
}

class _Borrado {
  final String ruta;
  final Map<String, String> consulta;
  _Borrado(this.ruta, this.consulta);
}
