import 'package:flutter/material.dart';

import '../models/catalogo.dart';
import '../models/detalle.dart';
import '../services/api_service.dart';
import '../services/listas_formulario.dart';
import '../services/sesion_service.dart';
import '../widgets/sede_precio_fields.dart';

/// Reporta un nuevo precio de un producto ya existente. Devuelve true si se guardó.
Future<bool?> mostrarReportarPrecio(BuildContext context, ProductoDetalle producto) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportarPrecioSheet(producto: producto),
  );
}

class _ReportarPrecioSheet extends StatefulWidget {
  final ProductoDetalle producto;
  const _ReportarPrecioSheet({required this.producto});

  @override
  State<_ReportarPrecioSheet> createState() => _ReportarPrecioSheetState();
}

class _ReportarPrecioSheetState extends State<_ReportarPrecioSheet> {
  final _formKey = GlobalKey<FormState>();
  final SedePrecioController _sede = SedePrecioController();
  ListasFormulario _listas = const ListasFormulario();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    ListasFormulario.cargar().then((l) {
      if (mounted) setState(() => _listas = l);
    });
  }

  @override
  void dispose() {
    _sede.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    try {
      await ApiService.agregarPrecio(
        widget.producto.id,
        NuevoPrecio(
          almacen: _sede.almacen.text.trim(),
          sede: _sede.sede.text.trim(),
          ciudad: _sede.ciudad.text.trim(),
          precioCop: _sede.precioValor!,
          fecha: _sede.fechaIsoValor,
          usuarioId: usuario.id,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.mensaje : 'No se pudo guardar el precio')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    final tema = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + teclado),
      child: !Sesion.instancia.activa
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline, size: 48, color: tema.colorScheme.outline),
                const SizedBox(height: 8),
                Text('Identifíquese para reportar precios',
                    style: tema.textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text(
                    'Abra la pestaña Perfil, registre su nombre y correo y vuelva aquí.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Entendido')),
              ],
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reportar precio', style: tema.textTheme.titleLarge),
                    Text(widget.producto.nombre, style: tema.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    SedePrecioFields(controller: _sede, listas: _listas),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_enviando ? 'Guardando…' : 'Guardar precio'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
