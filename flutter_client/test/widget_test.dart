import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/models/detalle.dart';
import 'package:flutter_client/models/producto.dart';
import 'package:flutter_client/utils/formato.dart';
import 'package:flutter_client/widgets/producto_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
  });

  group('Modelos (JSON del backend)', () {
    test('Producto.fromJson lee resumen de precios', () {
      final p = Producto.fromJson({
        'id': 7,
        'nombre': 'Leche entera',
        'marca': 'Alquería',
        'categoria': 'Lácteos y huevos',
        'presentacion': 'Bolsa',
        'cantidad': 1100.000,
        'unidad': 'ml',
        'tieneFoto': true,
        'precioMin': 3900.00,
        'precioMax': 5000.00,
        'nSedes': 3,
        'ultimaFecha': '2026-10-08',
        'diasUltima': 2,
        'desactualizado': false,
        'mejorAlmacen': 'D1',
        'mejorSede': 'D1 Suba',
        'mejorCiudad': 'Bogotá',
      });
      expect(p.id, 7);
      expect(p.precioMin, 3900.0);
      expect(p.presentacionCompleta, 'Bolsa 1100 ml');
      expect(p.mejorAlmacen, 'D1');
    });

    test('Producto sin precios admite nulos', () {
      final p = Producto.fromJson({
        'id': 1, 'nombre': 'X', 'marca': 'Y', 'categoria': 'Z',
        'presentacion': 'Caja', 'cantidad': 1, 'unidad': 'un',
        'tieneFoto': false, 'precioMin': null, 'precioMax': null, 'nSedes': 0,
      });
      expect(p.precioMin, isNull);
      expect(p.nSedes, 0);
    });

    test('Comparacion.fromJson con resumen y filas ordenadas', () {
      Map<String, dynamic> fila(int id, String almacen, double precio, double dif, bool barato) => {
            'reporteId': id, 'sedeId': id, 'establecimientoId': id, 'almacen': almacen,
            'sede': '$almacen Centro', 'ciudad': 'Bogotá', 'direccion': null,
            'precioCop': precio, 'fecha': '2026-10-08', 'dias': 2,
            'desactualizado': false, 'esMasBarato': barato,
            'diferenciaCop': dif, 'diferenciaPct': barato ? 0.0 : 28.2,
          };
      final barato = fila(1, 'D1', 3900.0, 0.0, true);
      final caro = fila(2, 'Éxito', 5000.0, 1100.0, false);
      final c = Comparacion.fromJson({
        'producto': {
          'id': 7, 'nombre': 'Leche', 'descripcion': null, 'marca': 'A',
          'categoria': 'L', 'marcaId': 1, 'categoriaId': 1, 'presentacion': 'Bolsa',
          'cantidad': 1100, 'unidad': 'ml', 'tieneFoto': false,
          'creadoPor': null, 'creadoEn': '2026-10-01',
        },
        'precios': [barato, caro],
        'resumen': {
          'nSedes': 2, 'precioMinimo': 3900.0, 'precioMaximo': 5000.0,
          'precioPromedio': 4450.0, 'masEconomico': barato, 'masCaro': caro,
          'ahorroMaximoCop': 1100.0, 'ahorroMaximoPct': 22.0, 'unidades': 1,
          'ahorroTotalCop': 1100.0, 'ahorroVsPromedioCop': 550.0,
          'masEconomicoDesactualizado': false, 'hayPreciosDesactualizados': false,
        },
        'diasVigencia': 30,
      });
      expect(c.precios.first.esMasBarato, isTrue);
      expect(c.resumen!.ahorroMaximoCop, 1100.0);
      expect(c.resumen!.masCaro.almacen, 'Éxito');
    });
  });

  group('Filtros', () {
    test('toQuery solo incluye filtros activos y se pueden combinar', () {
      final f = FiltrosProducto(
        q: ' leche ',
        categoriaId: 2,
        ciudad: 'Bogotá',
        precioMin: 1000,
        precioMax: 5000,
        orden: 'precio_asc',
      );
      final q = f.toQuery(1, 20);
      expect(q['q'], 'leche');
      expect(q['categoriaId'], '2');
      expect(q['ciudad'], 'Bogotá');
      expect(q.containsKey('marcaId'), isFalse);
      expect(q['orden'], 'precio_asc');
      expect(f.activos, 3); // categoría + ciudad + rango de precio
    });
  });

  group('Formato', () {
    test('cantidadTexto', () {
      expect(cantidadTexto(1100, 'ml'), '1100 ml');
      expect(cantidadTexto(0.5, 'kg'), contains('0,5'));
    });

    test('antigüedad en lenguaje natural', () {
      expect(antiguedad(0), 'hoy');
      expect(antiguedad(1), 'ayer');
      expect(antiguedad(12), 'hace 12 días');
      expect(antiguedad(75), 'hace 2 meses');
    });

    test('cop incluye separador de miles', () {
      expect(cop(4500), contains('4.500'));
      expect(copConSigno(600), startsWith('+'));
    });
  });

  testWidgets('ProductoCard muestra precio mínimo y advertencia de antigüedad',
      (WidgetTester tester) async {
    final producto = Producto(
      id: 1,
      nombre: 'Arroz blanco',
      marca: 'Diana',
      categoria: 'Granos',
      presentacion: 'Bolsa',
      cantidad: 500,
      unidad: 'g',
      tieneFoto: false,
      precioMin: 3200,
      precioMax: 3600,
      nSedes: 2,
      diasUltima: 45,
      desactualizado: true,
      mejorAlmacen: 'Jumbo',
      mejorCiudad: 'Bogotá',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProductoCard(producto: producto, onTap: () {})),
    ));
    expect(find.text('Arroz blanco'), findsOneWidget);
    expect(find.textContaining('3.200'), findsOneWidget);
    expect(find.textContaining('desactualizado'), findsOneWidget);
    expect(find.textContaining('Jumbo'), findsOneWidget);
  });
}
