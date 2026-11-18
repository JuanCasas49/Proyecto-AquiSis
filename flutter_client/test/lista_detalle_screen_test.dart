import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_client/screens/lista_detalle_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/api_falsa.dart';
import 'helpers/listas_falsas.dart';

Widget _app() => const MaterialApp(home: ListaDetalleScreen(listaId: 9, nombre: 'Compra semanal'));

int _cantidadMostrada(WidgetTester tester, int productoId) =>
    int.parse(tester.widget<Text>(find.byKey(ValueKey('cantidad-$productoId'))).data!);

/// HU-06: agregar, modificar la cantidad y eliminar productos de una lista.
void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));
  setUp(() async => abrirSesion());
  tearDown(() async => cerrarSesion());

  testWidgets('muestra los productos de la lista con su cantidad', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async => respuestaJson(listaDetalleJson()), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Compra semanal'), findsOneWidget);
      expect(find.text('Leche entera'), findsOneWidget);
      expect(find.text('Arroz blanco'), findsOneWidget);
      expect(find.text('Alquería · Bolsa 1100 ml'), findsNWidgets(2));
      expect(_cantidadMostrada(tester, 1), 2);
      expect(_cantidadMostrada(tester, 2), 1);
      expect(find.text('2 productos · 3 unidades'), findsOneWidget);
    });
  });

  testWidgets('una lista vacía invita a agregar productos', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async => respuestaJson(listaDetalleJson(items: [])), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('La lista está vacía'), findsOneWidget);
    });
  });

  testWidgets('aumentar y disminuir la cantidad se guarda en el servidor', (tester) async {
    pantallaAlta(tester);
    final puts = <Map<String, dynamic>>[];
    final rutas = <String>[];
    await conApiFalsa((p) async {
      if (p.method == 'PUT') {
        rutas.add(p.url.path);
        final cuerpo = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        puts.add(cuerpo);
        return respuestaJson(itemListaJson(id: 1, cantidad: cuerpo['cantidad'] as int));
      }
      return respuestaJson(listaDetalleJson());
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('mas-1')));
      await tester.pumpAndSettle();
      expect(_cantidadMostrada(tester, 1), 3);
      await tester.tap(find.byKey(const ValueKey('menos-1')));
      await tester.pumpAndSettle();
      expect(_cantidadMostrada(tester, 1), 2);

      expect(rutas, ['/api/listas/9/items/1', '/api/listas/9/items/1']);
      expect(puts, [
        {'usuarioId': 5, 'cantidad': 3},
        {'usuarioId': 5, 'cantidad': 2},
      ]);
      expect(find.text('2 productos · 3 unidades'), findsOneWidget);
    });
  });

  testWidgets('la cantidad mínima es 1: el botón de disminuir queda deshabilitado', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async => respuestaJson(listaDetalleJson()), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('menos-2'))).onPressed, isNull); // arroz x1
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('menos-1'))).onPressed, isNotNull); // leche x2
    });
  });

  testWidgets('si el servidor rechaza la cantidad se revierte y se informa', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      if (p.method == 'PUT') return respuestaJson({'error': 'La cantidad debe estar entre 1 y 999'}, 400);
      return respuestaJson(listaDetalleJson());
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mas-1')));
      await tester.pumpAndSettle();
      expect(_cantidadMostrada(tester, 1), 2); // volvió al valor anterior
      expect(find.text('La cantidad debe estar entre 1 y 999'), findsOneWidget);
    });
  });

  testWidgets('quitar un producto de la lista', (tester) async {
    pantallaAlta(tester);
    String? ruta;
    String? usuario;
    await conApiFalsa((p) async {
      if (p.method == 'DELETE') {
        ruta = p.url.path;
        usuario = p.url.queryParameters['usuarioId'];
        return respuestaJson(null, 204);
      }
      return respuestaJson(listaDetalleJson());
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quitar-1')));
      await tester.pumpAndSettle();

      expect(ruta, '/api/listas/9/items/1');
      expect(usuario, '5');
      expect(find.text('Leche entera'), findsNothing);
      expect(find.text('Arroz blanco'), findsOneWidget);
      expect(find.text('Leche entera se quitó de la lista'), findsOneWidget);
    });
  });

  testWidgets('agregar productos desde el catálogo', (tester) async {
    pantallaAlta(tester);
    Map<String, dynamic>? agregado;
    var cargasDeLista = 0;
    await conApiFalsa((p) async {
      if (p.method == 'POST' && p.url.path == '/api/listas/9/items') {
        agregado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        return respuestaJson(itemListaJson(id: 7, nombre: 'Aceite', cantidad: 1), 201);
      }
      if (p.url.path == '/api/productos') {
        return respuestaJson(paginaJson([productoJson(id: 7, nombre: 'Aceite', marca: 'Gourmet')]));
      }
      cargasDeLista++;
      return respuestaJson(listaDetalleJson());
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(cargasDeLista, 1);

      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar productos'), findsOneWidget);
      expect(find.text('Aceite'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agregar-7')));
      await tester.pumpAndSettle();
      expect(agregado, {'usuarioId': 5, 'productoId': 7, 'cantidad': 1});
      expect(find.textContaining('Aceite agregado'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(cargasDeLista, 2); // al volver se recarga la lista
    });
  });

  testWidgets('el selector busca por texto en el catálogo', (tester) async {
    pantallaAlta(tester);
    final consultas = <Map<String, String>>[];
    await conApiFalsa((p) async {
      if (p.url.path == '/api/productos') {
        consultas.add(p.url.queryParameters);
        return respuestaJson(paginaJson([productoJson(id: 7, nombre: 'Aceite')]));
      }
      return respuestaJson(listaDetalleJson());
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'aceite');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(consultas.last['q'], 'aceite');
    });
  });

  testWidgets('renombrar la lista desde la barra superior', (tester) async {
    pantallaAlta(tester);
    Map<String, dynamic>? enviado;
    await conApiFalsa((p) async {
      if (p.method == 'PUT' && p.url.path == '/api/listas/9') {
        enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        return respuestaJson(listaResumenJson(id: 9, nombre: 'Mercado quincenal'));
      }
      return respuestaJson(listaDetalleJson());
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Renombrar lista'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mercado quincenal');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(enviado, {'usuarioId': 5, 'nombre': 'Mercado quincenal'});
      expect(find.text('Mercado quincenal'), findsOneWidget);
    });
  });

  testWidgets('una lista que no existe muestra el error', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async => respuestaJson({'error': 'La lista no existe'}, 404), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar la lista'), findsOneWidget);
      expect(find.text('La lista no existe'), findsOneWidget);
    });
  });
}
