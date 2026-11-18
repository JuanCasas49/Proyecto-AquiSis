import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/screens/detalle_screen.dart';
import 'package:flutter_client/services/sesion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/api_falsa.dart';
import 'helpers/formularios.dart';

Widget _app() => const MaterialApp(home: DetalleScreen(productoId: 7));

Manejador _servidor({
  Map<String, dynamic>? comparacion,
  List<Map<String, dynamic>>? historial,
  List<Map<String, String>>? consultas,
}) {
  return (p) async {
    final lista = listasVacias(p);
    if (lista != null) return lista;
    if (p.url.path == '/api/productos/7/comparacion') {
      consultas?.add(p.url.queryParameters);
      return respuestaJson(comparacion ?? comparacionJson());
    }
    if (p.url.path == '/api/productos/7/historial') return respuestaJson(historial ?? historialBasico());
    return respuestaJson({'error': 'ruta no simulada ${p.url.path}'}, 404);
  };
}

/// Detalle: características, comparador (más barato, diferencias, ahorros), historial y reporte de precio.
void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Sesion.instancia.usuario = null;
  });

  testWidgets('muestra las características del producto', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Leche entera'), findsWidgets);
      expect(find.text('Alquería'), findsOneWidget);
      expect(find.text('Lácteos y huevos'), findsOneWidget);
      expect(find.text('Bolsa 1100 ml'), findsOneWidget);
      expect(find.text('Leche UHT'), findsOneWidget);
      expect(find.textContaining('Registrado por Ana'), findsOneWidget);
    });
  });

  testWidgets('el comparador ordena de menor a mayor y marca el más barato', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Comparador de precios'), findsOneWidget);
      expect(find.text('Más barato'), findsOneWidget);
      final d1 = tester.getTopLeft(find.text('D1')).dy;
      final ara = tester.getTopLeft(find.text('Ara')).dy;
      final exito = tester.getTopLeft(find.text('Éxito')).dy;
      expect(d1, lessThan(ara));
      expect(ara, lessThan(exito));
      // Diferencias contra el más barato
      expect(find.textContaining('+\$200'), findsOneWidget);
      expect(find.textContaining('+\$1.100'), findsOneWidget);
    });
  });

  testWidgets('resume la opción más económica y el ahorro máximo', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Opción más económica'), findsOneWidget);
      expect(find.textContaining('D1 Centro'), findsWidgets);
      expect(find.text('Precio promedio'), findsOneWidget);
      expect(find.textContaining('Ahorro máximo por unidad'), findsOneWidget);
      expect(find.textContaining('22'), findsWidgets); // 22 % de ahorro frente al más caro
    });
  });

  testWidgets('la calculadora multiplica el ahorro por las unidades a comprar', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('unidad ahorra'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pump();
      }
      expect(find.text('4'), findsOneWidget);
      expect(find.text('unidades ahorra'), findsOneWidget);
      expect(find.textContaining('4.400'), findsOneWidget); // 1.100 × 4

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();
      expect(find.textContaining('3.300'), findsOneWidget);
    });
  });

  testWidgets('advierte cuando el precio más barato puede estar desactualizado', (tester) async {
    pantallaAlta(tester);
    final viejo = comparacionJson(precios: [
      precioSedeJson(id: 1, almacen: 'Olímpica', precio: 1000, barato: true, dias: 45, desactualizado: true),
      precioSedeJson(id: 2, almacen: 'Éxito', precio: 5000, diferencia: 4000, pct: 400),
    ]);
    await conApiFalsa(_servidor(comparacion: viejo), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('podría estar desactualizado'), findsWidgets);
      expect(find.textContaining('hace 2 meses'), findsNothing);
      expect(find.textContaining('hace 45 días'), findsWidgets);
    });
  });

  testWidgets('sin advertencias cuando todos los precios son recientes', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('desactualizado'), findsNothing);
    });
  });

  testWidgets('con una sola sede se pide agregar más precios para comparar', (tester) async {
    pantallaAlta(tester);
    final unico = comparacionJson(precios: [precioSedeJson(id: 1, barato: true)]);
    await conApiFalsa(_servidor(comparacion: unico), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('Solo hay un precio reportado'), findsOneWidget);
    });
  });

  testWidgets('el filtro por ciudad vuelve a consultar el comparador', (tester) async {
    pantallaAlta(tester);
    final consultas = <Map<String, String>>[];
    await conApiFalsa(_servidor(consultas: consultas), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Todas las ciudades'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Medellín'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Medellín'));
      await tester.pumpAndSettle();
      expect(consultas.last['ciudad'], 'Medellín');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Todas las ciudades'));
      await tester.pumpAndSettle();
      expect(consultas.last.containsKey('ciudad'), isFalse);
    });
  });

  testWidgets('si no hay precios en la selección lo indica', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(comparacion: comparacionJson(precios: [])), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Sin precios en esta selección'), findsOneWidget);
    });
  });

  testWidgets('el historial muestra fecha, usuario y variación de precio', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Historial de reportes'), findsOneWidget);
      expect(find.text('3 reportes guardados.'), findsOneWidget);
      expect(find.textContaining('Ana'), findsWidgets);
      expect(find.textContaining('+\$600'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });
  });

  testWidgets('el historial largo se puede expandir y contraer', (tester) async {
    pantallaAlta(tester);
    final largo = [for (var i = 0; i < 10; i++) reporteJson(id: i + 1, almacen: 'Almacén $i', precio: 1000.0 + i)];
    await conApiFalsa(_servidor(historial: largo), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('10 reportes guardados.'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(8));

      await tester.tap(find.text('Ver todo el historial'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(10));

      await tester.tap(find.text('Ver menos'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(8));
    });
  });

  testWidgets('un producto inexistente muestra el error y permite reintentar', (tester) async {
    pantallaAlta(tester);
    var llamadas = 0;
    await conApiFalsa((p) async {
      if (p.url.path.endsWith('/comparacion')) {
        llamadas++;
        if (llamadas == 1) return respuestaJson({'error': 'Producto no encontrado'}, 404);
        return respuestaJson(comparacionJson());
      }
      return respuestaJson(historialBasico());
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar el producto'), findsOneWidget);
      expect(find.text('Producto no encontrado'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Comparador de precios'), findsOneWidget);
    });
  });

  testWidgets('reportar precio sin identificarse pide ir al Perfil', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar precio'));
      await tester.pumpAndSettle();
      expect(find.text('Identifíquese para reportar precios'), findsOneWidget);
    });
  });

  testWidgets('reportar un nuevo precio lo envía al servidor y recarga el comparador', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    final consultas = <Map<String, String>>[];
    Map<String, dynamic>? enviado;
    final base = _servidor(consultas: consultas);
    await conApiFalsa((p) async {
      if (p.method == 'POST' && p.url.path == '/api/productos/7/precios') {
        enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        return respuestaJson({'productoId': 7, 'reporteId': 99, 'productoNuevo': false}, 201);
      }
      return base(p);
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(consultas.length, 1);

      await tester.tap(find.text('Reportar precio'));
      await tester.pumpAndSettle();
      await escribir(tester, 'Almacén (Éxito, D1, Ara...)', 'Éxito');
      await escribir(tester, 'Sede (ej. Éxito Chapinero)', 'Éxito Chapinero');
      await escribir(tester, 'Ciudad', 'Bogotá');
      await escribir(tester, 'Precio en COP', '4200');
      await tester.tap(find.text('Guardar precio'));
      await tester.pumpAndSettle();

      expect(enviado!['almacen'], 'Éxito');
      expect(enviado!['sede'], 'Éxito Chapinero');
      expect(enviado!['ciudad'], 'Bogotá');
      expect(enviado!['precioCop'], 4200);
      expect(enviado!['usuarioId'], 5);
      expect(enviado!['fecha'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(find.text('Precio reportado. ¡Gracias!'), findsOneWidget);
      expect(consultas.length, 2); // se recargó el comparador
    });
  });

  testWidgets('el reporte de precio valida los campos obligatorios', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    var posts = 0;
    final base = _servidor();
    await conApiFalsa((p) async {
      if (p.method == 'POST') posts++;
      return base(p);
    }, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar precio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar precio'));
      await tester.pumpAndSettle();
      expect(find.text('Ingrese el almacén'), findsOneWidget);
      expect(find.text('Ingrese la sede'), findsOneWidget);
      expect(find.text('Ingrese la ciudad'), findsOneWidget);
      expect(find.text('Ingrese el precio'), findsOneWidget);
      expect(posts, 0);
    });
  });
}
