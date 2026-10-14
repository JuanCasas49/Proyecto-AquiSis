import 'producto.dart';

class Opcion {
  final int id;
  final String nombre;
  Opcion({required this.id, required this.nombre});
  factory Opcion.fromJson(Map<String, dynamic> j) =>
      Opcion(id: j['id'] as int, nombre: j['nombre'] as String);
}

class SedeInfo {
  final int id;
  final String almacen;
  final String nombre;
  final String ciudad;
  final String? direccion;
  SedeInfo({
    required this.id,
    required this.almacen,
    required this.nombre,
    required this.ciudad,
    this.direccion,
  });
  factory SedeInfo.fromJson(Map<String, dynamic> j) => SedeInfo(
        id: j['id'] as int,
        almacen: j['almacen'] as String,
        nombre: j['nombre'] as String,
        ciudad: j['ciudad'] as String,
        direccion: j['direccion'] as String?,
      );
}

class Usuario {
  final int id;
  final String nombre;
  final String email;
  Usuario({required this.id, required this.nombre, required this.email});
  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
      id: j['id'] as int,
      nombre: j['nombre'] as String,
      email: j['email'] as String);
}

class PaginaProductos {
  final List<Producto> items;
  final int total;
  final int pagina;
  final int tamano;
  PaginaProductos({
    required this.items,
    required this.total,
    required this.pagina,
    required this.tamano,
  });
  factory PaginaProductos.fromJson(Map<String, dynamic> j) => PaginaProductos(
        items: (j['items'] as List<dynamic>)
            .map((e) => Producto.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num).toInt(),
        pagina: j['pagina'] as int,
        tamano: j['tamano'] as int,
      );
}

/// Filtros combinables del catálogo.
class FiltrosProducto {
  String? q;
  int? categoriaId;
  int? marcaId;
  int? establecimientoId;
  String? ciudad;
  double? precioMin;
  double? precioMax;
  String orden;

  /// Etiquetas legibles para los chips (se completan al elegir en el panel).
  String? categoriaNombre;
  String? marcaNombre;
  String? establecimientoNombre;

  FiltrosProducto({
    this.q,
    this.categoriaId,
    this.marcaId,
    this.establecimientoId,
    this.ciudad,
    this.precioMin,
    this.precioMax,
    this.orden = 'nombre',
    this.categoriaNombre,
    this.marcaNombre,
    this.establecimientoNombre,
  });

  FiltrosProducto copia() => FiltrosProducto(
        q: q,
        categoriaId: categoriaId,
        marcaId: marcaId,
        establecimientoId: establecimientoId,
        ciudad: ciudad,
        precioMin: precioMin,
        precioMax: precioMax,
        orden: orden,
        categoriaNombre: categoriaNombre,
        marcaNombre: marcaNombre,
        establecimientoNombre: establecimientoNombre,
      );

  /// Cantidad de filtros activos (sin contar texto ni orden).
  int get activos =>
      (categoriaId != null ? 1 : 0) +
      (marcaId != null ? 1 : 0) +
      (establecimientoId != null ? 1 : 0) +
      (ciudad != null ? 1 : 0) +
      (precioMin != null || precioMax != null ? 1 : 0);

  Map<String, String> toQuery(int pagina, int tamano) {
    final m = <String, String>{
      'pagina': '$pagina',
      'tamano': '$tamano',
      'orden': orden,
    };
    if (q != null && q!.trim().isNotEmpty) m['q'] = q!.trim();
    if (categoriaId != null) m['categoriaId'] = '$categoriaId';
    if (marcaId != null) m['marcaId'] = '$marcaId';
    if (establecimientoId != null) m['establecimientoId'] = '$establecimientoId';
    if (ciudad != null) m['ciudad'] = ciudad!;
    if (precioMin != null) m['precioMin'] = '$precioMin';
    if (precioMax != null) m['precioMax'] = '$precioMax';
    return m;
  }
}

/// Cuerpo de POST /api/productos.
class RegistroProducto {
  final String nombre;
  final String? descripcion;
  final String marca;
  final String categoria;
  final String presentacion;
  final double cantidad;
  final String unidad;
  final double precioCop;
  final String almacen;
  final String sede;
  final String ciudad;
  final String? fecha; // yyyy-MM-dd
  final int usuarioId;
  final String? fotoBase64;

  RegistroProducto({
    required this.nombre,
    this.descripcion,
    required this.marca,
    required this.categoria,
    required this.presentacion,
    required this.cantidad,
    required this.unidad,
    required this.precioCop,
    required this.almacen,
    required this.sede,
    required this.ciudad,
    this.fecha,
    required this.usuarioId,
    this.fotoBase64,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        if (descripcion != null && descripcion!.isNotEmpty)
          'descripcion': descripcion,
        'marca': marca,
        'categoria': categoria,
        'presentacion': presentacion,
        'cantidad': cantidad,
        'unidad': unidad,
        'precioCop': precioCop,
        'almacen': almacen,
        'sede': sede,
        'ciudad': ciudad,
        if (fecha != null) 'fecha': fecha,
        'usuarioId': usuarioId,
        if (fotoBase64 != null) 'fotoBase64': fotoBase64,
      };
}

/// Cuerpo de POST /api/productos/{id}/precios.
class NuevoPrecio {
  final String almacen;
  final String sede;
  final String ciudad;
  final double precioCop;
  final String? fecha;
  final int usuarioId;

  NuevoPrecio({
    required this.almacen,
    required this.sede,
    required this.ciudad,
    required this.precioCop,
    this.fecha,
    required this.usuarioId,
  });

  Map<String, dynamic> toJson() => {
        'almacen': almacen,
        'sede': sede,
        'ciudad': ciudad,
        'precioCop': precioCop,
        if (fecha != null) 'fecha': fecha,
        'usuarioId': usuarioId,
      };
}

class ResultadoRegistro {
  final int productoId;
  final int reporteId;
  final bool productoNuevo;
  ResultadoRegistro({
    required this.productoId,
    required this.reporteId,
    required this.productoNuevo,
  });
  factory ResultadoRegistro.fromJson(Map<String, dynamic> j) =>
      ResultadoRegistro(
        productoId: j['productoId'] as int,
        reporteId: j['reporteId'] as int,
        productoNuevo: j['productoNuevo'] as bool,
      );
}
