import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/services/sesion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Datos simulados de listas de mercado, valoración y reportes con estado.

Map<String, dynamic> listaResumenJson({
  int id = 1,
  String nombre = 'Compra semanal',
  int nProductos = 3,
  int nUnidades = 8,
}) =>
    {'id': id, 'nombre': nombre, 'nProductos': nProductos, 'nUnidades': nUnidades, 'actualizada': '2026-10-26'};

Map<String, dynamic> itemListaJson({int id = 1, String nombre = 'Leche entera', int cantidad = 2}) => {
      'productoId': id,
      'nombre': nombre,
      'marca': 'Alquería',
      'presentacion': 'Bolsa',
      'cantidadProducto': 1100.0,
      'unidad': 'ml',
      'tieneFoto': false,
      'cantidad': cantidad,
    };

Map<String, dynamic> listaDetalleJson({
  int id = 9,
  String nombre = 'Compra semanal',
  List<Map<String, dynamic>>? items,
}) {
  final lista = items ??
      [
        itemListaJson(id: 1, nombre: 'Leche entera', cantidad: 2),
        itemListaJson(id: 2, nombre: 'Arroz blanco', cantidad: 1),
      ];
  return {
    'id': id,
    'nombre': nombre,
    'items': lista,
    'nProductos': lista.length,
    'nUnidades': lista.fold<int>(0, (a, i) => a + (i['cantidad'] as int)),
  };
}

Map<String, dynamic> lineaJson(int id, String producto, int cantidad, double? precio, {bool viejo = false}) => {
      'productoId': id,
      'producto': producto,
      'cantidad': cantidad,
      'precioUnitario': precio,
      'subtotal': precio == null ? null : precio * cantidad,
      'sede': precio == null ? null : 'Sede',
      'ciudad': precio == null ? null : 'Bogotá',
      'fecha': precio == null ? null : '2026-10-20',
      'dias': precio == null ? null : (viejo ? 45 : 3),
      'desactualizado': viejo,
    };

Map<String, dynamic> supermercadoJson({
  required int id,
  required String almacen,
  required double total,
  bool completo = true,
  bool barato = false,
  double? dif,
  double? difPct,
  List<String> faltan = const [],
  bool viejos = false,
  required List<Map<String, dynamic>> lineas,
}) =>
    {
      'establecimientoId': id,
      'almacen': almacen,
      'total': total,
      'completo': completo,
      'productosConPrecio': lineas.length - faltan.length,
      'productosSinPrecio': faltan,
      'esMasEconomico': barato,
      'diferenciaCop': dif,
      'diferenciaPct': difPct,
      'hayDesactualizados': viejos,
      'lineas': lineas,
    };

/// Escenario: Ara 22.700 (completo, más económico) · Éxito 25.600 (completo) · D1 11.000 (parcial, falta el aceite).
Map<String, dynamic> valoracionJson({bool viejos = false, String? ciudad, int nProductos = 3, int nUnidades = 4}) => {
      'listaId': 9,
      'nombre': 'Compra semanal',
      'nProductos': nProductos,
      'nUnidades': nUnidades,
      'ciudad': ciudad,
      'diasVigencia': 30,
      'supermercados': [
        supermercadoJson(id: 3, almacen: 'Ara', total: 22700, barato: true, dif: 0, difPct: 0, viejos: viejos, lineas: [
          lineaJson(1, 'Leche entera', 2, 4100),
          lineaJson(2, 'Arroz blanco', 1, 3500),
          lineaJson(3, 'Aceite', 1, 11000, viejo: viejos),
        ]),
        supermercadoJson(id: 1, almacen: 'Éxito', total: 25600, dif: 2900, difPct: 12.8, lineas: [
          lineaJson(1, 'Leche entera', 2, 5000),
          lineaJson(2, 'Arroz blanco', 1, 3600),
          lineaJson(3, 'Aceite', 1, 12000),
        ]),
        supermercadoJson(id: 2, almacen: 'D1', total: 11000, completo: false, faltan: ['Aceite'], lineas: [
          lineaJson(1, 'Leche entera', 2, 3900),
          lineaJson(2, 'Arroz blanco', 1, 3200),
          lineaJson(3, 'Aceite', 1, null),
        ]),
      ],
      'resumen': {
        'nComparables': 2,
        'masEconomico': 'Ara',
        'totalMasEconomico': 22700.0,
        'masCostoso': 'Éxito',
        'totalMasCostoso': 25600.0,
        'ahorroCop': 2900.0,
        'ahorroPct': 11.3,
        'hayPreciosDesactualizados': viejos,
      },
      'productosSinPrecioEnNingunSupermercado': <String>[],
    };

Map<String, dynamic> reporteUsuarioJson({
  int id = 1,
  int productoId = 7,
  String producto = 'Leche entera',
  String estado = 'pendiente',
  double precio = 4500,
  bool evidencia = false,
  String? motivo,
  String usuario = 'Ana',
}) =>
    {
      'reporteId': id,
      'productoId': productoId,
      'producto': producto,
      'almacen': 'Éxito',
      'sede': 'Éxito Chapinero',
      'ciudad': 'Bogotá',
      'precioCop': precio,
      'fecha': '2026-10-25',
      'estado': estado,
      'tieneEvidencia': evidencia,
      'motivoRechazo': motivo,
      'usuario': usuario,
    };

/// Deja una sesión abierta (usuario 5) para las pruebas que la necesitan.
Future<void> abrirSesion({String rol = 'usuario'}) async {
  SharedPreferences.setMockInitialValues({});
  await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com', rol: rol));
}

Future<void> cerrarSesion() async {
  SharedPreferences.setMockInitialValues({});
  Sesion.instancia.usuario = null;
}
