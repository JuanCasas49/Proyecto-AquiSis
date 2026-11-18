import 'package:flutter/material.dart';
import 'package:flutter_client/screens/catalogo_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/api_falsa.dart';

Widget _app() => const MaterialApp(home: CatalogoScreen());

/// Catálogo: lista, búsqueda, filtros combinables, estados vacío y de error, navegación al detalle.
void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  testWidgets('muestra los productos con precio mínimo, rango y dónde está más barato', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      return respuestaJson(paginaJson([
        productoJson(),
        productoJson(id: 2, nombre: 'Arroz blanco', marca: 'Diana', precioMin: 3200, precioMax: 3600, nSedes: 2, mejorAlmacen: 'Jumbo'),
      ]));
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('2 productos'), findsOneWidget);
      expect(find.text('Leche entera'), findsOneWidget);
      expect(find.text('Arroz blanco'), findsOneWidget);
      expect(find.textContaining('3.900'), findsOneWidget);
      expect(find.textContaining('hasta'), findsNWidgets(2));
      expect(find.textContaining('Más barato en D1'), findsOneWidget);
      expect(find.textContaining('Más barato en Jumbo'), findsOneWidget);
    });
  });

  testWidgets('catálogo vacío invita a registrar el primer precio', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async => respuestaJson(paginaJson([])), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Aún no hay productos registrados'), findsOneWidget);
    });
  });

  testWidgets('si falla la conexión muestra el error y permite reintentar', (tester) async {
    pantallaAlta(tester);
    var llamadas = 0;
    await conApiFalsa((p) async {
      llamadas++;
      if (llamadas == 1) throw Exception('sin red');
      return respuestaJson(paginaJson([productoJson()]));
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar el catálogo'), findsOneWidget);
      expect(find.textContaining('No se pudo conectar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Leche entera'), findsOneWidget);
      expect(find.text('No se pudo cargar el catálogo'), findsNothing);
    });
  });

  testWidgets('la búsqueda por texto consulta al servidor y actualiza la lista', (tester) async {
    pantallaAlta(tester);
    final consultas = <Map<String, String>>[];
    await conApiFalsa((p) async {
      consultas.add(p.url.queryParameters);
      if (p.url.queryParameters['q'] == 'arroz') {
        return respuestaJson(paginaJson([productoJson(id: 2, nombre: 'Arroz blanco')]));
      }
      return respuestaJson(paginaJson([productoJson(), productoJson(id: 2, nombre: 'Arroz blanco')]));
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('2 productos'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'arroz');
      await tester.pump(const Duration(milliseconds: 600)); // espera del "debounce"
      await tester.pumpAndSettle();

      expect(consultas.last['q'], 'arroz');
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text('Leche entera'), findsNothing);
    });
  });

  testWidgets('sin resultados para la búsqueda se informa al usuario', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      return respuestaJson(paginaJson(p.url.queryParameters.containsKey('q') ? [] : [productoJson()]));
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados para esa búsqueda'), findsOneWidget);
    });
  });

  testWidgets('los filtros se combinan, se muestran como chips y se pueden quitar', (tester) async {
    pantallaAlta(tester);
    final consultas = <Map<String, String>>[];
    await conApiFalsa((p) async {
      switch (p.url.path) {
        case '/api/categorias':
          return respuestaJson([{'id': 1, 'nombre': 'Lácteos y huevos'}]);
        case '/api/marcas':
          return respuestaJson([{'id': 2, 'nombre': 'Alquería'}]);
        case '/api/establecimientos':
          return respuestaJson([{'id': 3, 'nombre': 'D1'}]);
        case '/api/ciudades':
          return respuestaJson(['Bogotá', 'Medellín']);
        default:
          consultas.add(p.url.queryParameters);
          return respuestaJson(paginaJson([productoJson()]));
      }
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.text('Filtros'), findsOneWidget);

      // Categoría
      await tester.tap(find.byType(DropdownButtonFormField<int?>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lácteos y huevos').last);
      await tester.pumpAndSettle();
      // Rango de precios
      await tester.enterText(find.widgetWithText(TextField, 'Precio mínimo'), '3000');
      await tester.enterText(find.widgetWithText(TextField, 'Precio máximo'), '5000');
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      final q = consultas.last;
      expect(q['categoriaId'], '1');
      expect(q['precioMin'], '3000.0');
      expect(q['precioMax'], '5000.0');
      expect(find.widgetWithText(InputChip, 'Lácteos y huevos'), findsOneWidget);

      // Quitar el chip de categoría vuelve a consultar sin ese filtro
      tester.widget<InputChip>(find.widgetWithText(InputChip, 'Lácteos y huevos')).onDeleted!();
      await tester.pumpAndSettle();
      expect(consultas.last.containsKey('categoriaId'), isFalse);
      expect(consultas.last['precioMin'], '3000.0');
    });
  });

  testWidgets('al tocar un producto se abre su detalle con el comparador', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      if (p.url.path.endsWith('/comparacion')) return respuestaJson(comparacionJson());
      if (p.url.path.endsWith('/historial')) return respuestaJson(historialBasico());
      final lista = listasVacias(p);
      if (lista != null) return lista;
      return respuestaJson(paginaJson([productoJson(id: 7)]));
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leche entera'));
      await tester.pumpAndSettle();
      expect(find.text('Comparador de precios'), findsOneWidget);
    });
  });
}
