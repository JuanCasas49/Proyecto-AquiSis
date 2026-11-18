double _d(dynamic v) => (v as num).toDouble();

/// Reporte de precio con su estado de validación (HU-08).
class ReporteUsuario {
  final int reporteId;
  final int productoId;
  final String producto;
  final String almacen;
  final String sede;
  final String ciudad;
  final double precioCop;
  final String fecha;
  final String estado; // pendiente | validado | rechazado
  final bool tieneEvidencia;
  final String? motivoRechazo;
  final String usuario;

  ReporteUsuario({
    required this.reporteId,
    required this.productoId,
    required this.producto,
    required this.almacen,
    required this.sede,
    required this.ciudad,
    required this.precioCop,
    required this.fecha,
    required this.estado,
    required this.tieneEvidencia,
    this.motivoRechazo,
    required this.usuario,
  });

  factory ReporteUsuario.fromJson(Map<String, dynamic> j) => ReporteUsuario(
        reporteId: j['reporteId'] as int,
        productoId: j['productoId'] as int,
        producto: j['producto'] as String? ?? '',
        almacen: j['almacen'] as String? ?? '',
        sede: j['sede'] as String? ?? '',
        ciudad: j['ciudad'] as String? ?? '',
        precioCop: _d(j['precioCop']),
        fecha: j['fecha'] as String? ?? '',
        estado: j['estado'] as String? ?? 'validado',
        tieneEvidencia: j['tieneEvidencia'] as bool? ?? false,
        motivoRechazo: j['motivoRechazo'] as String?,
        usuario: j['usuario'] as String? ?? 'Anónimo',
      );

  bool get pendiente => estado == 'pendiente';
  bool get rechazado => estado == 'rechazado';
}

/// Texto legible del estado de un reporte.
String etiquetaEstado(String estado) {
  switch (estado) {
    case 'pendiente':
      return 'Pendiente de validación';
    case 'rechazado':
      return 'Rechazado';
    default:
      return 'Validado';
  }
}
