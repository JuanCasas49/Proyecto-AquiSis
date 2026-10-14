import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Servidor simulado: las pruebas NO usan red ni base de datos reales.
typedef Manejador = Future<http.Response> Function(http.Request peticion);

http.Response respuestaJson(Object? cuerpo, [int estado = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(cuerpo)),
      estado,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Ejecuta [cuerpo] con todas las peticiones HTTP de package:http redirigidas a [manejador].
Future<T> conApiFalsa<T>(Manejador manejador, Future<T> Function() cuerpo) =>
    http.runWithClient(cuerpo, () => MockClient(manejador));

/// Listas de apoyo vacías (marcas, categorías...) para pantallas que las cargan en segundo plano.
http.Response? listasVacias(http.Request p) {
  const rutas = ['/api/marcas', '/api/categorias', '/api/establecimientos', '/api/ciudades', '/api/sedes'];
  return (p.method == 'GET' && rutas.contains(p.url.path)) ? respuestaJson(<dynamic>[]) : null;
}

/// Pantalla alta para que todo el contenido quede visible sin desplazarse.
void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ------------------------------------------------------------------ datos --

Map<String, dynamic> productoJson({
  int id = 1,
  String nombre = 'Leche entera',
  String marca = 'Alquería',
  String categoria = 'Lácteos y huevos',
  double? precioMin = 3900,
  double? precioMax = 5000,
  int nSedes = 3,
  int? diasUltima = 2,
  bool desactualizado = false,
  String? mejorAlmacen = 'D1',
  String? mejorCiudad = 'Bogotá',
}) =>
    {
      'id': id,
      'nombre': nombre,
      'marca': marca,
      'categoria': categoria,
      'presentacion': 'Bolsa',
      'cantidad': 1100.0,
      'unidad': 'ml',
      'tieneFoto': false,
      'precioMin': precioMin,
      'precioMax': precioMax,
      'nSedes': nSedes,
      'ultimaFecha': '2026-10-12',
      'diasUltima': diasUltima,
      'desactualizado': desactualizado,
      'mejorAlmacen': mejorAlmacen,
      'mejorSede': 'D1 Suba',
      'mejorCiudad': mejorCiudad,
    };

Map<String, dynamic> paginaJson(List<Map<String, dynamic>> items, {int? total}) => {
      'items': items,
      'total': total ?? items.length,
      'pagina': 1,
      'tamano': 20,
    };

Map<String, dynamic> precioSedeJson({
  int id = 1,
  String almacen = 'D1',
  String ciudad = 'Bogotá',
  double precio = 3900,
  double diferencia = 0,
  double? pct = 0,
  bool barato = false,
  int dias = 2,
  bool desactualizado = false,
}) =>
    {
      'reporteId': id,
      'sedeId': id,
      'establecimientoId': id,
      'almacen': almacen,
      'sede': '$almacen Centro',
      'ciudad': ciudad,
      'direccion': null,
      'precioCop': precio,
      'fecha': '2026-10-12',
      'dias': dias,
      'desactualizado': desactualizado,
      'esMasBarato': barato,
      'diferenciaCop': diferencia,
      'diferenciaPct': pct,
    };

Map<String, dynamic> comparacionJson({
  List<Map<String, dynamic>>? precios,
  bool sinResumen = false,
}) {
  final filas = precios ??
      [
        precioSedeJson(id: 1, almacen: 'D1', precio: 3900, barato: true),
        precioSedeJson(id: 2, almacen: 'Ara', ciudad: 'Medellín', precio: 4100, diferencia: 200, pct: 5.1),
        precioSedeJson(id: 3, almacen: 'Éxito', precio: 5000, diferencia: 1100, pct: 28.2),
      ];
  final hayDatos = filas.isNotEmpty && !sinResumen;
  return {
    'producto': {
      'id': 7,
      'nombre': 'Leche entera',
      'descripcion': 'Leche UHT',
      'marca': 'Alquería',
      'categoria': 'Lácteos y huevos',
      'marcaId': 1,
      'categoriaId': 1,
      'presentacion': 'Bolsa',
      'cantidad': 1100.0,
      'unidad': 'ml',
      'tieneFoto': false,
      'creadoPor': 'Ana',
      'creadoEn': '2026-10-01',
    },
    'precios': filas,
    'resumen': !hayDatos
        ? null
        : {
            'nSedes': filas.length,
            'precioMinimo': filas.first['precioCop'],
            'precioMaximo': filas.last['precioCop'],
            'precioPromedio': 4333.33,
            'masEconomico': filas.first,
            'masCaro': filas.last,
            'ahorroMaximoCop': 1100.0,
            'ahorroMaximoPct': 22.0,
            'unidades': 1,
            'ahorroTotalCop': 1100.0,
            'ahorroVsPromedioCop': 433.33,
            'masEconomicoDesactualizado': filas.first['desactualizado'],
            'hayPreciosDesactualizados': filas.any((f) => f['desactualizado'] == true),
          },
    'diasVigencia': 30,
  };
}

Map<String, dynamic> reporteJson({
  int id = 1,
  String almacen = 'D1',
  String ciudad = 'Bogotá',
  double precio = 3900,
  double? variacion,
  int dias = 2,
}) =>
    {
      'reporteId': id,
      'sedeId': id,
      'almacen': almacen,
      'sede': '$almacen Centro',
      'ciudad': ciudad,
      'precioCop': precio,
      'fecha': '2026-10-12',
      'dias': dias,
      'desactualizado': dias > 30,
      'usuario': 'Ana',
      'variacionCop': variacion,
    };

List<Map<String, dynamic>> historialBasico() => [
      reporteJson(id: 4, almacen: 'D1', precio: 4500, variacion: 600),
      reporteJson(id: 3, almacen: 'Éxito', precio: 5000),
      reporteJson(id: 2, almacen: 'Ara', ciudad: 'Medellín', precio: 4100),
    ];
