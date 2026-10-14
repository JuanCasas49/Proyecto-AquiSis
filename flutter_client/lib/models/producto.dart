import '../utils/formato.dart';

double _d(dynamic v) => (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();

/// Producto del catálogo con el resumen de sus precios vigentes (GET /api/productos).
class Producto {
  final int id;
  final String nombre;
  final String marca;
  final String categoria;
  final String presentacion;
  final double cantidad;
  final String unidad;
  final bool tieneFoto;
  final double? precioMin;
  final double? precioMax;
  final int nSedes;
  final String? ultimaFecha;
  final int? diasUltima;
  final bool desactualizado;
  final String? mejorAlmacen;
  final String? mejorSede;
  final String? mejorCiudad;

  Producto({
    required this.id,
    required this.nombre,
    required this.marca,
    required this.categoria,
    required this.presentacion,
    required this.cantidad,
    required this.unidad,
    required this.tieneFoto,
    this.precioMin,
    this.precioMax,
    this.nSedes = 0,
    this.ultimaFecha,
    this.diasUltima,
    this.desactualizado = false,
    this.mejorAlmacen,
    this.mejorSede,
    this.mejorCiudad,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
      categoria: json['categoria'] as String? ?? '',
      presentacion: json['presentacion'] as String? ?? '',
      cantidad: _d(json['cantidad']),
      unidad: json['unidad'] as String? ?? 'un',
      tieneFoto: json['tieneFoto'] as bool? ?? false,
      precioMin: _dn(json['precioMin']),
      precioMax: _dn(json['precioMax']),
      nSedes: json['nSedes'] as int? ?? 0,
      ultimaFecha: json['ultimaFecha'] as String?,
      diasUltima: json['diasUltima'] as int?,
      desactualizado: json['desactualizado'] as bool? ?? false,
      mejorAlmacen: json['mejorAlmacen'] as String?,
      mejorSede: json['mejorSede'] as String?,
      mejorCiudad: json['mejorCiudad'] as String?,
    );
  }

  /// "Bolsa 1100 ml"
  String get presentacionCompleta =>
      '$presentacion ${cantidadTexto(cantidad, unidad)}';
}
