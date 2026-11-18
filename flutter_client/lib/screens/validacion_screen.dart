import 'package:flutter/material.dart';

import '../models/reporte_usuario.dart';
import '../services/api_service.dart';
import '../services/sesion_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/evidencia_imagen.dart';

/// HU-08 (moderadores): cola de precios pendientes para validar o rechazar mirando su evidencia.
class ValidacionScreen extends StatefulWidget {
  const ValidacionScreen({super.key});

  @override
  State<ValidacionScreen> createState() => _ValidacionScreenState();
}

class _ValidacionScreenState extends State<ValidacionScreen> {
  List<ReporteUsuario> _pendientes = [];
  bool _cargando = true;
  String? _error;
  final Set<int> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _mensaje(Object e) => e is ApiException ? e.mensaje : 'Ocurrió un error inesperado';

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 2)));
  }

  Future<void> _cargar() async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await ApiService.reportesPendientes(usuario.id);
      if (!mounted) return;
      setState(() {
        _pendientes = r;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mensaje(e);
        _cargando = false;
      });
    }
  }

  Future<void> _procesar(ReporteUsuario r, Future<void> Function(int moderadorId) accion, String mensaje) async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    setState(() => _procesando.add(r.reporteId));
    try {
      await accion(usuario.id);
      if (!mounted) return;
      setState(() {
        _pendientes = _pendientes.where((x) => x.reporteId != r.reporteId).toList();
        _procesando.remove(r.reporteId);
      });
      _aviso(mensaje);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando.remove(r.reporteId));
      _aviso(_mensaje(e));
    }
  }

  Future<void> _validar(ReporteUsuario r) => _procesar(
      r, (m) => ApiService.validarReporte(r.reporteId, m), 'Precio validado: ya es oficial');

  Future<void> _rechazar(ReporteUsuario r) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoMotivo(),
    );
    if (motivo == null || !mounted) return;
    await _procesar(r, (m) => ApiService.rechazarReporte(r.reporteId, m, motivo), 'Precio rechazado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validar precios')),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: EstadoVacio(
          icono: Icons.lock_outline,
          titulo: 'No se pudo cargar la cola de validación',
          detalle: _error,
          textoAccion: 'Reintentar',
          onAccion: _cargar,
        ),
      );
    }
    if (_pendientes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 60),
            EstadoVacio(
              icono: Icons.task_alt,
              titulo: 'No hay precios pendientes',
              detalle: 'Cuando alguien reporte un precio aparecerá aquí para validarlo.',
            ),
          ],
        ),
      );
    }
    final tema = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _pendientes.length,
        itemBuilder: (context, i) {
          final r = _pendientes[i];
          final ocupado = _procesando.contains(r.reporteId);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.producto, style: tema.textTheme.titleMedium)),
                      Text(cop(r.precioCop),
                          style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('${r.almacen} · ${r.sede} · ${r.ciudad}', style: tema.textTheme.bodySmall),
                  Text('${fechaCorta(r.fecha)} · reportado por ${r.usuario}', style: tema.textTheme.bodySmall),
                  const SizedBox(height: 10),
                  EvidenciaImagen(reporteId: r.reporteId, tiene: r.tieneEvidencia, alto: 180),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: ValueKey('rechazar-${r.reporteId}'),
                          onPressed: ocupado ? null : () => _rechazar(r),
                          icon: const Icon(Icons.close),
                          label: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: ValueKey('validar-${r.reporteId}'),
                          onPressed: ocupado ? null : () => _validar(r),
                          icon: const Icon(Icons.check),
                          label: const Text('Validar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo();

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final TextEditingController _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar precio'),
      content: TextField(
        controller: _controlador,
        maxLength: 200,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Motivo (opcional)', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controlador.text.trim()),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
