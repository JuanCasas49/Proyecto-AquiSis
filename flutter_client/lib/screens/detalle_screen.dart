import 'package:flutter/material.dart';

import '../models/detalle.dart';
import '../services/api_service.dart';
import '../utils/formato.dart';
import '../widgets/aviso_antiguedad.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/foto_producto.dart';
import '../widgets/precio_tile.dart';
import 'reportar_precio_sheet.dart';

/// Detalle del producto: características, comparador de precios e historial.
class DetalleScreen extends StatefulWidget {
  final int productoId;
  const DetalleScreen({super.key, required this.productoId});

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  Comparacion? _comparacion;
  List<Reporte> _historial = [];
  List<String> _ciudades = [];
  String? _ciudad; // filtro de ciudad del comparador
  int _unidades = 1; // para calcular el ahorro potencial
  bool _verTodoHistorial = false;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final comparacion =
          await ApiService.obtenerComparacion(widget.productoId, ciudad: _ciudad);
      final historial = await ApiService.obtenerHistorial(widget.productoId);
      if (!mounted) return;
      setState(() {
        _comparacion = comparacion;
        _historial = historial;
        _ciudades = historial.map((h) => h.ciudad).toSet().toList()..sort();
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

  Future<void> _reportar() async {
    final c = _comparacion;
    if (c == null) return;
    final guardado = await mostrarReportarPrecio(context, c.producto);
    if (guardado == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Precio reportado. ¡Gracias!')));
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _comparacion;
    return Scaffold(
      appBar: AppBar(title: Text(c?.producto.nombre ?? 'Detalle del producto')),
      floatingActionButton: c == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _reportar,
              icon: const Icon(Icons.add_chart),
              label: const Text('Reportar precio'),
            ),
      body: _cargando && c == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && c == null
              ? Center(
                  child: EstadoVacio(
                    icono: Icons.cloud_off_outlined,
                    titulo: 'No se pudo cargar el producto',
                    detalle: _error,
                    textoAccion: 'Reintentar',
                    onAccion: _cargar,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: _contenido(c!),
                  ),
                ),
    );
  }

  List<Widget> _contenido(Comparacion c) {
    final resumen = c.resumen;
    return [
      _encabezado(c.producto),
      const SizedBox(height: 16),
      if (resumen != null) _resumen(resumen, c.diasVigencia),
      const SizedBox(height: 16),
      _comparador(c),
      const SizedBox(height: 24),
      _seccionHistorial(),
    ];
  }

  Widget _encabezado(ProductoDetalle p) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FotoProducto(productoId: p.id, tieneFoto: p.tieneFoto, tamano: 100),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nombre, style: tema.textTheme.titleLarge),
              Text(p.marca, style: tema.textTheme.bodyLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(p.categoria),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                        '${p.presentacion} ${cantidadTexto(p.cantidad, p.unidad)}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (p.descripcion != null && p.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(p.descripcion!, style: tema.textTheme.bodyMedium),
              ],
              if (p.creadoPor != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Registrado por ${p.creadoPor}',
                      style: tema.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resumen(ResumenComparacion r, int diasVigencia) {
    final tema = Theme.of(context);
    final barato = r.masEconomico;
    final unico = r.nSedes == 1;
    return Card(
      color: tema.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: tema.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text('Opción más económica',
                    style: tema.textTheme.labelLarge?.copyWith(
                        color: tema.colorScheme.onPrimaryContainer)),
              ],
            ),
            const SizedBox(height: 6),
            Text(cop(r.precioMinimo),
                style: tema.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: tema.colorScheme.onPrimaryContainer)),
            Text('${barato.almacen} · ${barato.sede} · ${barato.ciudad}',
                style: TextStyle(color: tema.colorScheme.onPrimaryContainer)),
            if (r.masEconomicoDesactualizado) ...[
              const SizedBox(height: 8),
              AvisoAntiguedad(dias: barato.dias),
            ],
            const Divider(height: 24),
            if (unico)
              Text(
                'Solo hay un precio reportado. Agregue más para poder comparar.',
                style: TextStyle(color: tema.colorScheme.onPrimaryContainer),
              )
            else ...[
              _filaDato('Precio más alto', cop(r.precioMaximo)),
              _filaDato('Precio promedio', cop(r.precioPromedio)),
              _filaDato('Ahorro máximo por unidad',
                  '${cop(r.ahorroMaximoCop)} (${porcentaje(r.ahorroMaximoPct)})',
                  destacado: true),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Si compra', style: TextStyle(color: tema.colorScheme.onPrimaryContainer)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _unidades > 1 ? () => setState(() => _unidades--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_unidades',
                      style: tema.textTheme.titleMedium?.copyWith(
                          color: tema.colorScheme.onPrimaryContainer)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _unidades < 99 ? () => setState(() => _unidades++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      _unidades == 1 ? 'unidad ahorra' : 'unidades ahorra',
                      style: TextStyle(color: tema.colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
              Text(cop(r.ahorroMaximoCop * _unidades),
                  style: tema.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tema.colorScheme.onPrimaryContainer)),
              Text(
                'frente a comprarlo en ${r.masCaro.almacen} (${r.masCaro.sede})',
                style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onPrimaryContainer),
              ),
            ],
            if (r.hayPreciosDesactualizados && !r.masEconomicoDesactualizado) ...[
              const SizedBox(height: 10),
              Text(
                'Algunos precios tienen más de $diasVigencia días y pueden haber cambiado.',
                style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onPrimaryContainer),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor, {bool destacado = false}) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: TextStyle(color: color))),
          Text(valor,
              style: TextStyle(
                  color: color,
                  fontWeight: destacado ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _comparador(Comparacion c) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comparador de precios', style: tema.textTheme.titleMedium),
        const Text('Último precio reportado en cada sede, de menor a mayor.'),
        if (_ciudades.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('Todas las ciudades'),
                    selected: _ciudad == null,
                    onSelected: (_) {
                      setState(() => _ciudad = null);
                      _cargar();
                    },
                  ),
                ),
                for (final ciudad in _ciudades)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(ciudad),
                      selected: _ciudad == ciudad,
                      onSelected: (_) {
                        setState(() => _ciudad = ciudad);
                        _cargar();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (c.precios.isEmpty)
          const EstadoVacio(
            icono: Icons.sell_outlined,
            titulo: 'Sin precios en esta selección',
          )
        else
          for (var i = 0; i < c.precios.length; i++)
            PrecioTile(precio: c.precios[i], posicion: i + 1),
      ],
    );
  }

  Widget _seccionHistorial() {
    final tema = Theme.of(context);
    final visibles = _verTodoHistorial ? _historial : _historial.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de reportes', style: tema.textTheme.titleMedium),
        Text('${_historial.length} ${_historial.length == 1 ? 'reporte' : 'reportes'} guardados.'),
        const SizedBox(height: 4),
        for (final h in visibles)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              h.variacionCop == null
                  ? Icons.fiber_manual_record
                  : (h.variacionCop! > 0
                      ? Icons.trending_up
                      : (h.variacionCop! < 0 ? Icons.trending_down : Icons.trending_flat)),
              color: h.variacionCop == null
                  ? tema.colorScheme.outline
                  : (h.variacionCop! > 0
                      ? tema.colorScheme.error
                      : (h.variacionCop! < 0 ? Colors.green : tema.colorScheme.outline)),
            ),
            title: Text('${h.almacen} · ${h.sede}'),
            subtitle: Text(
                '${fechaCorta(h.fecha)} (${antiguedad(h.dias)}) · ${h.ciudad} · ${h.usuario}'
                '${h.desactualizado ? ' · desactualizado' : ''}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(cop(h.precioCop),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (h.variacionCop != null && h.variacionCop != 0)
                  Text(copConSigno(h.variacionCop!),
                      style: TextStyle(
                          fontSize: 12,
                          color: h.variacionCop! > 0
                              ? tema.colorScheme.error
                              : Colors.green)),
              ],
            ),
          ),
        if (_historial.length > 8)
          TextButton(
            onPressed: () => setState(() => _verTodoHistorial = !_verTodoHistorial),
            child: Text(_verTodoHistorial ? 'Ver menos' : 'Ver todo el historial'),
          ),
      ],
    );
  }
}
