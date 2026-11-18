import '../utils/formato.dart';

double _d(dynamic v) => (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();

/// Lista de mercado en el listado del usuario (HU-06).
class ListaResumen {
  final int id;
  final String nombre;
  final int nProductos;
  final int nUnidades;
  final String actualizada;

  ListaResumen({
    required this.id,
    required this.nombre,
    required this.nProductos,
    required this.nUnidades,
    required this.actualizada,
  });

  factory ListaResumen.fromJson(Map<String, dynamic> j) => ListaResumen(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        nProductos: (j['nProductos'] as num).toInt(),
        nUnidades: (j['nUnidades'] as num).toInt(),
        actualizada: j['actualizada'] as String? ?? '',
      );
}

/// Producto dentro de una lista, con las unidades que se quieren comprar.
class ItemLista {
  final int productoId;
  final String nombre;
  final String marca;
  final String presentacion;
  final double cantidadProducto;
  final String unidad;
  final bool tieneFoto;
  final int cantidad;

  ItemLista({
    required this.productoId,
    required this.nombre,
    required this.marca,
    required this.presentacion,
    required this.cantidadProducto,
    required this.unidad,
    required this.tieneFoto,
    required this.cantidad,
  });

  factory ItemLista.fromJson(Map<String, dynamic> j) => ItemLista(
        productoId: j['productoId'] as int,
        nombre: j['nombre'] as String? ?? '',
        marca: j['marca'] as String? ?? '',
        presentacion: j['presentacion'] as String? ?? '',
        cantidadProducto: _d(j['cantidadProducto']),
        unidad: j['unidad'] as String? ?? 'un',
        tieneFoto: j['tieneFoto'] as bool? ?? false,
        cantidad: (j['cantidad'] as num).toInt(),
      );

  ItemLista conCantidad(int nueva) => ItemLista(
        productoId: productoId,
        nombre: nombre,
        marca: marca,
        presentacion: presentacion,
        cantidadProducto: cantidadProducto,
        unidad: unidad,
        tieneFoto: tieneFoto,
        cantidad: nueva,
      );

  /// "Bolsa 1100 ml"
  String get presentacionCompleta => '$presentacion ${cantidadTexto(cantidadProducto, unidad)}';
}

class ListaDetalle {
  final int id;
  final String nombre;
  final List<ItemLista> items;

  ListaDetalle({required this.id, required this.nombre, required this.items});

  factory ListaDetalle.fromJson(Map<String, dynamic> j) => ListaDetalle(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        items: (j['items'] as List<dynamic>)
            .map((e) => ItemLista.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  int get unidades => items.fold(0, (suma, i) => suma + i.cantidad);
}

// ------------------------------------------------------ HU-07: valoración --

/// Un producto de la lista valorado en un supermercado (precio nulo = no lo tiene).
class LineaValoracion {
  final int productoId;
  final String producto;
  final int cantidad;
  final double? precioUnitario;
  final double? subtotal;
  final String? sede;
  final String? ciudad;
  final String? fecha;
  final int? dias;
  final bool desactualizado;

  LineaValoracion({
    required this.productoId,
    required this.producto,
    required this.cantidad,
    this.precioUnitario,
    this.subtotal,
    this.sede,
    this.ciudad,
    this.fecha,
    this.dias,
    this.desactualizado = false,
  });

  factory LineaValoracion.fromJson(Map<String, dynamic> j) => LineaValoracion(
        productoId: j['productoId'] as int,
        producto: j['producto'] as String? ?? '',
        cantidad: (j['cantidad'] as num).toInt(),
        precioUnitario: _dn(j['precioUnitario']),
        subtotal: _dn(j['subtotal']),
        sede: j['sede'] as String?,
        ciudad: j['ciudad'] as String?,
        fecha: j['fecha'] as String?,
        dias: j['dias'] as int?,
        desactualizado: j['desactualizado'] as bool? ?? false,
      );
}

class SupermercadoValoracion {
  final int establecimientoId;
  final String almacen;
  final double total;
  final bool completo;
  final int productosConPrecio;
  final List<String> productosSinPrecio;
  final bool esMasEconomico;
  final double? diferenciaCop;
  final double? diferenciaPct;
  final bool hayDesactualizados;
  final List<LineaValoracion> lineas;

  SupermercadoValoracion({
    required this.establecimientoId,
    required this.almacen,
    required this.total,
    required this.completo,
    required this.productosConPrecio,
    required this.productosSinPrecio,
    required this.esMasEconomico,
    this.diferenciaCop,
    this.diferenciaPct,
    required this.hayDesactualizados,
    required this.lineas,
  });

  factory SupermercadoValoracion.fromJson(Map<String, dynamic> j) => SupermercadoValoracion(
        establecimientoId: j['establecimientoId'] as int,
        almacen: j['almacen'] as String? ?? '',
        total: _d(j['total']),
        completo: j['completo'] as bool? ?? false,
        productosConPrecio: (j['productosConPrecio'] as num).toInt(),
        productosSinPrecio:
            (j['productosSinPrecio'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        esMasEconomico: j['esMasEconomico'] as bool? ?? false,
        diferenciaCop: _dn(j['diferenciaCop']),
        diferenciaPct: _dn(j['diferenciaPct']),
        hayDesactualizados: j['hayDesactualizados'] as bool? ?? false,
        lineas: (j['lineas'] as List<dynamic>? ?? [])
            .map((e) => LineaValoracion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ResumenValoracion {
  final int nComparables;
  final String? masEconomico;
  final double? totalMasEconomico;
  final String? masCostoso;
  final double? totalMasCostoso;
  final double ahorroCop;
  final double ahorroPct;
  final bool hayPreciosDesactualizados;

  ResumenValoracion({
    required this.nComparables,
    this.masEconomico,
    this.totalMasEconomico,
    this.masCostoso,
    this.totalMasCostoso,
    required this.ahorroCop,
    required this.ahorroPct,
    required this.hayPreciosDesactualizados,
  });

  factory ResumenValoracion.fromJson(Map<String, dynamic> j) => ResumenValoracion(
        nComparables: (j['nComparables'] as num).toInt(),
        masEconomico: j['masEconomico'] as String?,
        totalMasEconomico: _dn(j['totalMasEconomico']),
        masCostoso: j['masCostoso'] as String?,
        totalMasCostoso: _dn(j['totalMasCostoso']),
        ahorroCop: _dn(j['ahorroCop']) ?? 0,
        ahorroPct: _dn(j['ahorroPct']) ?? 0,
        hayPreciosDesactualizados: j['hayPreciosDesactualizados'] as bool? ?? false,
      );
}

class Valoracion {
  final int listaId;
  final String nombre;
  final int nProductos;
  final int nUnidades;
  final String? ciudad;
  final int diasVigencia;
  final List<SupermercadoValoracion> supermercados;
  final ResumenValoracion resumen;
  final List<String> sinPrecioEnNingunSupermercado;

  Valoracion({
    required this.listaId,
    required this.nombre,
    required this.nProductos,
    required this.nUnidades,
    this.ciudad,
    required this.diasVigencia,
    required this.supermercados,
    required this.resumen,
    required this.sinPrecioEnNingunSupermercado,
  });

  factory Valoracion.fromJson(Map<String, dynamic> j) => Valoracion(
        listaId: j['listaId'] as int,
        nombre: j['nombre'] as String? ?? '',
        nProductos: (j['nProductos'] as num).toInt(),
        nUnidades: (j['nUnidades'] as num).toInt(),
        ciudad: j['ciudad'] as String?,
        diasVigencia: j['diasVigencia'] as int? ?? 30,
        supermercados: (j['supermercados'] as List<dynamic>)
            .map((e) => SupermercadoValoracion.fromJson(e as Map<String, dynamic>))
            .toList(),
        resumen: ResumenValoracion.fromJson(j['resumen'] as Map<String, dynamic>),
        sinPrecioEnNingunSupermercado:
            (j['productosSinPrecioEnNingunSupermercado'] as List<dynamic>? ?? [])
                .map((e) => e as String)
                .toList(),
      );
}
