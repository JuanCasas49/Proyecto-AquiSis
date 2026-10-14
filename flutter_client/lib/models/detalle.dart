double _d(dynamic v) => (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();

class ProductoDetalle {
  final int id;
  final String nombre;
  final String? descripcion;
  final String marca;
  final String categoria;
  final String presentacion;
  final double cantidad;
  final String unidad;
  final bool tieneFoto;
  final String? creadoPor;
  final String? creadoEn;

  ProductoDetalle({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.marca,
    required this.categoria,
    required this.presentacion,
    required this.cantidad,
    required this.unidad,
    required this.tieneFoto,
    this.creadoPor,
    this.creadoEn,
  });

  factory ProductoDetalle.fromJson(Map<String, dynamic> j) => ProductoDetalle(
        id: j['id'] as int,
        nombre: j['nombre'] as String? ?? '',
        descripcion: j['descripcion'] as String?,
        marca: j['marca'] as String? ?? '',
        categoria: j['categoria'] as String? ?? '',
        presentacion: j['presentacion'] as String? ?? '',
        cantidad: _d(j['cantidad']),
        unidad: j['unidad'] as String? ?? 'un',
        tieneFoto: j['tieneFoto'] as bool? ?? false,
        creadoPor: j['creadoPor'] as String?,
        creadoEn: j['creadoEn'] as String?,
      );
}

/// Último precio reportado en una sede (fila del comparador).
class PrecioSede {
  final int reporteId;
  final int sedeId;
  final String almacen;
  final String sede;
  final String ciudad;
  final String? direccion;
  final double precioCop;
  final String fecha;
  final int dias;
  final bool desactualizado;
  final bool esMasBarato;
  final double diferenciaCop;
  final double? diferenciaPct;

  PrecioSede({
    required this.reporteId,
    required this.sedeId,
    required this.almacen,
    required this.sede,
    required this.ciudad,
    this.direccion,
    required this.precioCop,
    required this.fecha,
    required this.dias,
    required this.desactualizado,
    required this.esMasBarato,
    required this.diferenciaCop,
    this.diferenciaPct,
  });

  factory PrecioSede.fromJson(Map<String, dynamic> j) => PrecioSede(
        reporteId: j['reporteId'] as int,
        sedeId: j['sedeId'] as int,
        almacen: j['almacen'] as String? ?? '',
        sede: j['sede'] as String? ?? '',
        ciudad: j['ciudad'] as String? ?? '',
        direccion: j['direccion'] as String?,
        precioCop: _d(j['precioCop']),
        fecha: j['fecha'] as String? ?? '',
        dias: j['dias'] as int? ?? 0,
        desactualizado: j['desactualizado'] as bool? ?? false,
        esMasBarato: j['esMasBarato'] as bool? ?? false,
        diferenciaCop: _d(j['diferenciaCop']),
        diferenciaPct: _dn(j['diferenciaPct']),
      );
}

class ResumenComparacion {
  final int nSedes;
  final double precioMinimo;
  final double precioMaximo;
  final double precioPromedio;
  final PrecioSede masEconomico;
  final PrecioSede masCaro;
  final double ahorroMaximoCop;
  final double ahorroMaximoPct;
  final int unidades;
  final double ahorroTotalCop;
  final double ahorroVsPromedioCop;
  final bool masEconomicoDesactualizado;
  final bool hayPreciosDesactualizados;

  ResumenComparacion({
    required this.nSedes,
    required this.precioMinimo,
    required this.precioMaximo,
    required this.precioPromedio,
    required this.masEconomico,
    required this.masCaro,
    required this.ahorroMaximoCop,
    required this.ahorroMaximoPct,
    required this.unidades,
    required this.ahorroTotalCop,
    required this.ahorroVsPromedioCop,
    required this.masEconomicoDesactualizado,
    required this.hayPreciosDesactualizados,
  });

  factory ResumenComparacion.fromJson(Map<String, dynamic> j) =>
      ResumenComparacion(
        nSedes: j['nSedes'] as int,
        precioMinimo: _d(j['precioMinimo']),
        precioMaximo: _d(j['precioMaximo']),
        precioPromedio: _d(j['precioPromedio']),
        masEconomico:
            PrecioSede.fromJson(j['masEconomico'] as Map<String, dynamic>),
        masCaro: PrecioSede.fromJson(j['masCaro'] as Map<String, dynamic>),
        ahorroMaximoCop: _d(j['ahorroMaximoCop']),
        ahorroMaximoPct: _d(j['ahorroMaximoPct']),
        unidades: j['unidades'] as int? ?? 1,
        ahorroTotalCop: _d(j['ahorroTotalCop']),
        ahorroVsPromedioCop: _d(j['ahorroVsPromedioCop']),
        masEconomicoDesactualizado:
            j['masEconomicoDesactualizado'] as bool? ?? false,
        hayPreciosDesactualizados:
            j['hayPreciosDesactualizados'] as bool? ?? false,
      );
}

class Comparacion {
  final ProductoDetalle producto;
  final List<PrecioSede> precios;
  final ResumenComparacion? resumen;
  final int diasVigencia;

  Comparacion({
    required this.producto,
    required this.precios,
    this.resumen,
    required this.diasVigencia,
  });

  factory Comparacion.fromJson(Map<String, dynamic> j) => Comparacion(
        producto:
            ProductoDetalle.fromJson(j['producto'] as Map<String, dynamic>),
        precios: (j['precios'] as List<dynamic>)
            .map((e) => PrecioSede.fromJson(e as Map<String, dynamic>))
            .toList(),
        resumen: j['resumen'] == null
            ? null
            : ResumenComparacion.fromJson(j['resumen'] as Map<String, dynamic>),
        diasVigencia: j['diasVigencia'] as int? ?? 30,
      );
}

/// Un reporte del historial de precios.
class Reporte {
  final int reporteId;
  final String almacen;
  final String sede;
  final String ciudad;
  final double precioCop;
  final String fecha;
  final int dias;
  final bool desactualizado;
  final String usuario;
  final double? variacionCop;

  Reporte({
    required this.reporteId,
    required this.almacen,
    required this.sede,
    required this.ciudad,
    required this.precioCop,
    required this.fecha,
    required this.dias,
    required this.desactualizado,
    required this.usuario,
    this.variacionCop,
  });

  factory Reporte.fromJson(Map<String, dynamic> j) => Reporte(
        reporteId: j['reporteId'] as int,
        almacen: j['almacen'] as String? ?? '',
        sede: j['sede'] as String? ?? '',
        ciudad: j['ciudad'] as String? ?? '',
        precioCop: _d(j['precioCop']),
        fecha: j['fecha'] as String? ?? '',
        dias: j['dias'] as int? ?? 0,
        desactualizado: j['desactualizado'] as bool? ?? false,
        usuario: j['usuario'] as String? ?? 'Anónimo',
        variacionCop: _dn(j['variacionCop']),
      );
}
