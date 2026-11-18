import 'package:flutter/material.dart';

import '../models/reporte_usuario.dart';
import '../services/api_service.dart';
import '../services/sesion_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/evidencia_imagen.dart';
import 'detalle_screen.dart';

/// Chip de color con el estado de un reporte (pendiente, validado o rechazado).
class EstadoChip extends StatelessWidget {
  final String estado;
  const EstadoChip({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final Color fondo;
    final Color texto;
    final IconData icono;
    switch (estado) {
      case 'pendiente':
        fondo = Colors.amber.shade100;
        texto = Colors.amber.shade900;
        icono = Icons.hourglass_top;
        break;
      case 'rechazado':
        fondo = Colors.red.shade100;
        texto = Colors.red.shade900;
        icono = Icons.block;
        break;
      default:
        fondo = Colors.green.shade100;
        texto = Colors.green.shade900;
        icono = Icons.check_circle_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: texto),
          const SizedBox(width: 4),
          Text(etiquetaEstado(estado), style: TextStyle(fontSize: 12, color: texto, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// HU-08: los precios que el usuario ha reportado y su estado de validación.
class MisReportesScreen extends StatefulWidget {
  const MisReportesScreen({super.key});

  @override
  State<MisReportesScreen> createState() => _MisReportesScreenState();
}

class _MisReportesScreenState extends State<MisReportesScreen> {
  static const _filtros = <String?, String>{
    null: 'Todos',
    'pendiente': 'Pendientes',
    'validado': 'Validados',
    'rechazado': 'Rechazados',
  };

  List<ReporteUsuario> _reportes = [];
  String? _estado;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await ApiService.misReportes(usuario.id, estado: _estado);
      if (!mounted) return;
      setState(() {
        _reportes = r;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.mensaje : 'Ocurrió un error inesperado';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              children: [
                for (final e in _filtros.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _estado == e.key,
                      onSelected: (_) {
                        setState(() => _estado = e.key);
                        _cargar();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: EstadoVacio(
          icono: Icons.cloud_off_outlined,
          titulo: 'No se pudieron cargar sus reportes',
          detalle: _error,
          textoAccion: 'Reintentar',
          onAccion: _cargar,
        ),
      );
    }
    if (_reportes.isEmpty) {
      return const Center(
        child: EstadoVacio(
          icono: Icons.fact_check_outlined,
          titulo: 'No hay reportes en esta categoría',
          detalle: 'Los precios que reporte aparecerán aquí con su estado.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _reportes.length,
        itemBuilder: (context, i) {
          final r = _reportes[i];
          final tema = Theme.of(context);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DetalleScreen(productoId: r.productoId),
              )),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.producto, style: tema.textTheme.titleMedium)),
                        Text(cop(r.precioCop), style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text('${r.almacen} · ${r.sede} · ${r.ciudad}', style: tema.textTheme.bodySmall),
                    Text(fechaCorta(r.fecha), style: tema.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        EstadoChip(estado: r.estado),
                        const SizedBox(width: 8),
                        if (r.tieneEvidencia)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.photo_outlined, size: 16, color: tema.colorScheme.outline),
                            const SizedBox(width: 3),
                            Text('Con evidencia', style: tema.textTheme.bodySmall),
                          ]),
                      ],
                    ),
                    if (r.rechazado && r.motivoRechazo != null) ...[
                      const SizedBox(height: 6),
                      Text('Motivo: ${r.motivoRechazo}', style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                    ],
                    if (r.tieneEvidencia) ...[
                      const SizedBox(height: 8),
                      EvidenciaImagen(reporteId: r.reporteId, tiene: true, alto: 120),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
