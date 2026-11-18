import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/screens/registro_screen.dart';
import 'package:flutter_client/services/sesion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/api_falsa.dart';
import 'helpers/formularios.dart';

/// Registro de productos con su precio.
void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Sesion.instancia.usuario = null;
  });

  Widget app({void Function(int)? onRegistrado, VoidCallback? irAPerfil}) => MaterialApp(
        home: RegistroScreen(onRegistrado: onRegistrado ?? (_) {}, irAPerfil: irAPerfil ?? () {}),
      );

  testWidgets('sin identificarse no se puede registrar y se redirige al Perfil', (tester) async {
    pantallaAlta(tester);
    var fueAPerfil = false;
    await conApiFalsa((p) async => listasVacias(p) ?? respuestaJson({}), () async {
      await tester.pumpWidget(app(irAPerfil: () => fueAPerfil = true));
      await tester.pumpAndSettle();
      expect(find.text('Identifíquese para reportar precios'), findsOneWidget);
      expect(find.text('Guardar en la nube'), findsNothing);
      await tester.tap(find.text('Ir a Perfil'));
      expect(fueAPerfil, isTrue);
    });
  });

  testWidgets('el formulario contiene todos los campos del producto', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    await conApiFalsa((p) async => listasVacias(p) ?? respuestaJson({}), () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (final etiqueta in [
        'Nombre del producto', 'Marca', 'Categoría', 'Descripción (opcional)',
        'Presentación (botella, bolsa, caja...)', 'Cantidad', 'Unidad',
        'Almacén (Éxito, D1, Ara...)', 'Sede (ej. Éxito Chapinero)', 'Ciudad', 'Precio en COP', 'Fecha del precio',
      ]) {
        expect(find.text(etiqueta), findsOneWidget, reason: 'falta el campo "$etiqueta"');
      }
      expect(find.text('Cámara'), findsOneWidget);
      expect(find.text('Galería'), findsOneWidget);
    });
  });

  testWidgets('valida los campos obligatorios y no envía nada', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    var posts = 0;
    await conApiFalsa((p) async {
      if (p.method == 'POST') posts++;
      return listasVacias(p) ?? respuestaJson({});
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar en la nube'));
      await tester.pumpAndSettle();

      for (final mensaje in [
        'Ingrese el nombre', 'Ingrese la marca', 'Ingrese la categoría', 'Ingrese la presentación',
        'Cantidad inválida', 'Ingrese el almacén', 'Ingrese la sede', 'Ingrese la ciudad', 'Ingrese el precio',
      ]) {
        expect(find.text(mensaje), findsOneWidget, reason: 'falta el mensaje "$mensaje"');
      }
      expect(posts, 0);
    });
  });

  testWidgets('la cantidad debe ser mayor que cero', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    await conApiFalsa((p) async => listasVacias(p) ?? respuestaJson({}), () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await escribir(tester, 'Cantidad', '0');
      await tester.tap(find.text('Guardar en la nube'));
      await tester.pumpAndSettle();
      expect(find.text('Cantidad inválida'), findsOneWidget);
    });
  });

  testWidgets('registra un producto nuevo enviando todos los datos', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    Map<String, dynamic>? enviado;
    int? abierto;
    await conApiFalsa((p) async {
      if (p.method == 'POST' && p.url.path == '/api/productos') {
        enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        return respuestaJson({'productoId': 12, 'reporteId': 40, 'productoNuevo': true}, 201);
      }
      return listasVacias(p) ?? respuestaJson({});
    }, () async {
      await tester.pumpWidget(app(onRegistrado: (id) => abierto = id));
      await tester.pumpAndSettle();
      await llenarRegistro(tester);
      await tester.tap(find.text('Guardar en la nube'));
      await tester.pumpAndSettle();

      expect(enviado!['nombre'], 'Leche entera');
      expect(enviado!['marca'], 'Alquería');
      expect(enviado!['categoria'], 'Lácteos y huevos');
      expect(enviado!['presentacion'], 'Bolsa');
      expect(enviado!['cantidad'], 1100);
      expect(enviado!['unidad'], 'ml');
      expect(enviado!['precioCop'], 4500);
      expect(enviado!['almacen'], 'Éxito');
      expect(enviado!['sede'], 'Éxito Chapinero');
      expect(enviado!['ciudad'], 'Bogotá');
      expect(enviado!['usuarioId'], 5);
      expect(enviado!['fecha'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(enviado!.containsKey('fotoBase64'), isFalse);
      expect(abierto, 12);
      expect(find.text('Producto registrado. ¡Gracias por reportar!'), findsOneWidget);
      // El formulario queda limpio para el siguiente registro
      expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Nombre del producto')).controller!.text, isEmpty);
    });
  });

  testWidgets('si el producto ya existía lo informa (solo se agregó el precio)', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    await conApiFalsa((p) async {
      if (p.method == 'POST') return respuestaJson({'productoId': 3, 'reporteId': 41, 'productoNuevo': false});
      return listasVacias(p) ?? respuestaJson({});
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await llenarRegistro(tester);
      await tester.tap(find.text('Guardar en la nube'));
      await tester.pumpAndSettle();
      expect(find.text('Ese producto ya existía: se agregó su nuevo precio.'), findsOneWidget);
    });
  });

  testWidgets('muestra el mensaje del servidor si el registro es rechazado y conserva lo escrito', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    int? abierto;
    await conApiFalsa((p) async {
      if (p.method == 'POST') return respuestaJson({'error': 'La fecha del reporte no puede ser futura'}, 400);
      return listasVacias(p) ?? respuestaJson({});
    }, () async {
      await tester.pumpWidget(app(onRegistrado: (id) => abierto = id));
      await tester.pumpAndSettle();
      await llenarRegistro(tester);
      await tester.tap(find.text('Guardar en la nube'));
      await tester.pumpAndSettle();
      expect(find.text('La fecha del reporte no puede ser futura'), findsOneWidget);
      expect(abierto, isNull);
      expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Nombre del producto')).controller!.text, 'Leche entera');
    });
  });

  testWidgets('las listas del servidor se ofrecen como sugerencias de marca', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    await conApiFalsa((p) async {
      if (p.url.path == '/api/marcas') return respuestaJson([{'id': 1, 'nombre': 'Alquería'}, {'id': 2, 'nombre': 'Alpina'}]);
      return listasVacias(p) ?? respuestaJson({});
    }, () async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Marca'), 'Alp');
      await tester.pumpAndSettle();
      expect(find.text('Alpina'), findsOneWidget);
      expect(find.text('Alquería'), findsNothing);
    });
  });
}
