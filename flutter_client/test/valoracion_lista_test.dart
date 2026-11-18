import 'package:flutter/material.dart';
import 'package:flutter_client/models/lista.dart';
import 'package:flutter_client/screens/lista_detalle_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/api_falsa.dart';
import 'helpers/listas_falsas.dart';

Widget _app() => const MaterialApp(home: ListaDetalleScreen(listaId: 9, nombre: 'Compra semanal'));

Manejador _servidor({
  Map<String, dynamic>? valoracion,
  List<Map<String, String>>? consultas,
  Map<String, dynamic>? detalle,
}) {
  return (p) async {
    if (p.url.path == '/api/listas/9/valoracion') {
      consultas?.add(p.url.queryParameters);
      return respuestaJson(valoracion ?? valoracionJson());
    }
    if (p.url.path == '/api/ciudades') return respuestaJson(['Bogotá', 'Cali']);
    if (p.method == 'PUT') return respuestaJson(itemListaJson(id: 1, cantidad: 3));
    return respuestaJson(detalle ?? listaDetalleJson());
  };
}

Future<void> _abrirValor(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Valor y ahorro'));
  await tester.pumpAndSettle();
}

/// HU-07: valor total estimado de la lista por supermercado y ahorro frente al más costoso.
void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));
  setUp(() async => abrirSesion());
  tearDown(() async => cerrarSesion());

  group('Modelo', () {
    test('Valoracion.fromJson lee supermercados, líneas y resumen', () {
      final v = Valoracion.fromJson(valoracionJson());
      expect(v.supermercados.map((s) => s.almacen), ['Ara', 'Éxito', 'D1']);
      expect(v.supermercados.first.esMasEconomico, isTrue);
      expect(v.supermercados[2].completo, isFalse);
      expect(v.supermercados[2].productosSinPrecio, ['Aceite']);
      expect(v.supermercados[2].lineas[2].precioUnitario, isNull);
      expect(v.supermercados[1].lineas.first.subtotal, 10000.0);
      expect(v.resumen.ahorroCop, 2900.0);
      expect(v.resumen.ahorroPct, 11.3);
      expect(v.resumen.masCostoso, 'Éxito');
    });

    test('ListaDetalle suma las unidades', () {
      final d = ListaDetalle.fromJson(listaDetalleJson());
      expect(d.items.length, 2);
      expect(d.unidades, 3);
      expect(d.items.first.conCantidad(5).cantidad, 5);
      expect(d.items.first.presentacionCompleta, 'Bolsa 1100 ml');
    });
  });

  testWidgets('muestra el ahorro en pesos y porcentaje respecto al supermercado más costoso', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await _abrirValor(tester);
      expect(find.text('Ahorro eligiendo el más económico'), findsOneWidget);
      expect(find.text('\$2.900'), findsOneWidget);
      expect(find.text('11,3 % menos que en Éxito'), findsOneWidget);
      expect(find.textContaining('Ara: \$22.700'), findsOneWidget);
      expect(find.textContaining('Éxito: \$25.600'), findsOneWidget);
      expect(find.text('3 productos · 4 unidades'), findsOneWidget);
    });
  });

  testWidgets('lista los supermercados con su total, de menor a mayor, y marca el más económico', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await _abrirValor(tester);
      final ara = tester.getTopLeft(find.text('Ara')).dy;
      final exito = tester.getTopLeft(find.text('Éxito')).dy;
      final d1 = tester.getTopLeft(find.text('D1')).dy;
      expect(ara, lessThan(exito));
      expect(exito, lessThan(d1));
      expect(find.text('Más económico'), findsOneWidget);
      expect(find.text('\$22.700'), findsOneWidget);
      expect(find.text('\$25.600'), findsOneWidget);
      expect(find.text('\$11.000'), findsOneWidget);
      expect(find.textContaining('+\$2.900'), findsOneWidget); // Éxito frente al más económico
      expect(find.textContaining('12,8 %'), findsOneWidget);
    });
  });

  testWidgets('un supermercado incompleto se muestra como parcial con lo que le falta', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await _abrirValor(tester);
      expect(find.text('Faltan 1: Aceite'), findsOneWidget);
      expect(find.text('parcial'), findsOneWidget);
      expect(find.text('total'), findsNWidgets(2));
    });
  });

  testWidgets('al expandir un supermercado se ve el detalle por producto', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await _abrirValor(tester);
      await tester.tap(find.text('Éxito'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 × \$5.000'), findsOneWidget);
      expect(find.text('\$10.000'), findsOneWidget); // subtotal de la leche
      await tester.tap(find.text('D1'));
      await tester.pumpAndSettle();
      expect(find.text('Sin precio en este supermercado'), findsOneWidget);
    });
  });

  testWidgets('advierte cuando algún precio usado tiene más de 30 días', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(valoracion: valoracionJson(viejos: true)), () async {
      await _abrirValor(tester);
      expect(find.textContaining('tienen más de 30 días y pueden haber cambiado'), findsOneWidget);
      expect(find.textContaining('Incluye precios con más de 30 días'), findsOneWidget);
    });
  });

  testWidgets('sin precios antiguos no muestra advertencias de antigüedad', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(_servidor(), () async {
      await _abrirValor(tester);
      expect(find.textContaining('más de 30 días'), findsNothing);
    });
  });

  testWidgets('con un solo supermercado completo explica que no se puede calcular el ahorro', (tester) async {
    pantallaAlta(tester);
    final v = valoracionJson();
    (v['resumen'] as Map<String, dynamic>)
      ..['nComparables'] = 1
      ..['masEconomico'] = 'Éxito'
      ..['totalMasEconomico'] = 25600.0
      ..['ahorroCop'] = 0.0
      ..['ahorroPct'] = 0.0;
    await conApiFalsa(_servidor(valoracion: v), () async {
      await _abrirValor(tester);
      expect(find.text('Solo Éxito tiene todos los productos'), findsOneWidget);
      expect(find.text('Ahorro eligiendo el más económico'), findsNothing);
    });
  });

  testWidgets('si ningún supermercado está completo se muestran totales parciales', (tester) async {
    pantallaAlta(tester);
    final v = valoracionJson();
    (v['resumen'] as Map<String, dynamic>)
      ..['nComparables'] = 0
      ..['masEconomico'] = null
      ..['totalMasEconomico'] = null
      ..['masCostoso'] = null
      ..['totalMasCostoso'] = null
      ..['ahorroCop'] = 0.0
      ..['ahorroPct'] = 0.0;
    await conApiFalsa(_servidor(valoracion: v), () async {
      await _abrirValor(tester);
      expect(find.textContaining('Ningún supermercado tiene precio para todos los productos'), findsOneWidget);
    });
  });

  testWidgets('informa los productos sin precio en ningún supermercado', (tester) async {
    pantallaAlta(tester);
    final v = valoracionJson();
    v['productosSinPrecioEnNingunSupermercado'] = ['Sal'];
    await conApiFalsa(_servidor(valoracion: v), () async {
      await _abrirValor(tester);
      expect(find.text('Sin precio en ningún supermercado: Sal.'), findsOneWidget);
    });
  });

  testWidgets('una lista vacía no calcula nada', (tester) async {
    pantallaAlta(tester);
    final vacia = valoracionJson(nProductos: 0, nUnidades: 0);
    vacia['supermercados'] = <dynamic>[];
    await conApiFalsa(_servidor(valoracion: vacia, detalle: listaDetalleJson(items: [])), () async {
      await _abrirValor(tester);
      expect(find.text('Agregue productos para calcular el valor'), findsOneWidget);
    });
  });

  testWidgets('el filtro de ciudad recalcula el valor con precios de esa ciudad', (tester) async {
    pantallaAlta(tester);
    final consultas = <Map<String, String>>[];
    await conApiFalsa(_servidor(consultas: consultas), () async {
      await _abrirValor(tester);
      expect(consultas.last.containsKey('ciudad'), isFalse);
      expect(consultas.last['usuarioId'], '5');

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cali').last);
      await tester.pumpAndSettle();
      expect(consultas.last['ciudad'], 'Cali');
    });
  });

  testWidgets('al cambiar una cantidad el valor se recalcula', (tester) async {
    pantallaAlta(tester);
    final consultas = <Map<String, String>>[];
    await conApiFalsa(_servidor(consultas: consultas), () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valor y ahorro'));
      await tester.pumpAndSettle();
      final antes = consultas.length;

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mas-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valor y ahorro'));
      await tester.pumpAndSettle();

      expect(consultas.length, greaterThan(antes));
    });
  });

  testWidgets('si falla el cálculo muestra el error y permite reintentar', (tester) async {
    pantallaAlta(tester);
    var llamadas = 0;
    await conApiFalsa((p) async {
      if (p.url.path == '/api/listas/9/valoracion') {
        llamadas++;
        if (llamadas == 1) return respuestaJson({'error': 'La lista no existe'}, 404);
        return respuestaJson(valoracionJson());
      }
      if (p.url.path == '/api/ciudades') return respuestaJson(['Bogotá']);
      return respuestaJson(listaDetalleJson());
    }, () async {
      await _abrirValor(tester);
      expect(find.text('No se pudo calcular el valor'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Ahorro eligiendo el más económico'), findsOneWidget);
    });
  });
}
