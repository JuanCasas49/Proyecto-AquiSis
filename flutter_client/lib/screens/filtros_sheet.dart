import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalogo.dart';
import '../services/api_service.dart';

/// Panel de filtros combinables. Devuelve los filtros elegidos o null si se cierra.
Future<FiltrosProducto?> mostrarFiltros(
    BuildContext context, FiltrosProducto actuales) {
  return showModalBottomSheet<FiltrosProducto>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FiltrosSheet(actuales: actuales),
  );
}

class _FiltrosSheet extends StatefulWidget {
  final FiltrosProducto actuales;
  const _FiltrosSheet({required this.actuales});

  @override
  State<_FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<_FiltrosSheet> {
  late final FiltrosProducto _f = widget.actuales.copia();
  late final TextEditingController _min = TextEditingController(
      text: _f.precioMin == null ? '' : _f.precioMin!.toInt().toString());
  late final TextEditingController _max = TextEditingController(
      text: _f.precioMax == null ? '' : _f.precioMax!.toInt().toString());

  List<Opcion> _categorias = [];
  List<Opcion> _marcas = [];
  List<Opcion> _almacenes = [];
  List<String> _ciudades = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final categorias = await ApiService.categorias();
      final marcas = await ApiService.marcas();
      final almacenes = await ApiService.establecimientos();
      final ciudades = await ApiService.ciudades();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _marcas = marcas;
        _almacenes = almacenes;
        _ciudades = ciudades;
        // Si un filtro apunta a algo que ya no existe, se descarta
        if (!_categorias.any((o) => o.id == _f.categoriaId)) _f.categoriaId = null;
        if (!_marcas.any((o) => o.id == _f.marcaId)) _f.marcaId = null;
        if (!_almacenes.any((o) => o.id == _f.establecimientoId)) {
          _f.establecimientoId = null;
        }
        if (_f.ciudad != null && !_ciudades.contains(_f.ciudad)) _f.ciudad = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.mensaje : 'No se pudieron cargar los filtros';
        _cargando = false;
      });
    }
  }

  String? _nombreDe(List<Opcion> lista, int? id) {
    for (final o in lista) {
      if (o.id == id) return o.nombre;
    }
    return null;
  }

  void _aplicar() {
    final min = double.tryParse(_min.text.trim());
    final max = double.tryParse(_max.text.trim());
    if (min != null && max != null && min > max) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El precio mínimo no puede ser mayor que el máximo')));
      return;
    }
    _f.precioMin = min;
    _f.precioMax = max;
    _f.categoriaNombre = _nombreDe(_categorias, _f.categoriaId);
    _f.marcaNombre = _nombreDe(_marcas, _f.marcaId);
    _f.establecimientoNombre = _nombreDe(_almacenes, _f.establecimientoId);
    Navigator.pop(context, _f);
  }

  void _limpiar() {
    setState(() {
      _f.categoriaId = null;
      _f.marcaId = null;
      _f.establecimientoId = null;
      _f.ciudad = null;
      _f.orden = 'nombre';
      _min.clear();
      _max.clear();
    });
  }

  DropdownButtonFormField<int?> _selectorId(
      String etiqueta, List<Opcion> lista, int? valor, void Function(int?) alCambiar) {
    return DropdownButtonFormField<int?>(
      initialValue: valor,
      isExpanded: true,
      decoration:
          InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
        ...lista.map((o) => DropdownMenuItem<int?>(
            value: o.id, child: Text(o.nombre, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: alCambiar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + teclado),
      child: _cargando
          ? const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? SizedBox(
                  height: 200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                          onPressed: _cargar, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filtros',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      _selectorId('Categoría', _categorias, _f.categoriaId,
                          (v) => setState(() => _f.categoriaId = v)),
                      const SizedBox(height: 12),
                      _selectorId('Marca', _marcas, _f.marcaId,
                          (v) => setState(() => _f.marcaId = v)),
                      const SizedBox(height: 12),
                      _selectorId('Almacén', _almacenes, _f.establecimientoId,
                          (v) => setState(() => _f.establecimientoId = v)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _f.ciudad,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Ciudad', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('Todas')),
                          ..._ciudades.map((c) =>
                              DropdownMenuItem<String?>(value: c, child: Text(c))),
                        ],
                        onChanged: (v) => setState(() => _f.ciudad = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _min,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Precio mínimo',
                                  prefixText: r'$ ',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _max,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Precio máximo',
                                  prefixText: r'$ ',
                                  border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _f.orden,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Ordenar por',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'nombre', child: Text('Nombre (A-Z)')),
                          DropdownMenuItem(
                              value: 'precio_asc',
                              child: Text('Precio: menor a mayor')),
                          DropdownMenuItem(
                              value: 'precio_desc',
                              child: Text('Precio: mayor a menor')),
                          DropdownMenuItem(
                              value: 'reciente',
                              child: Text('Reportados recientemente')),
                        ],
                        onChanged: (v) => setState(() => _f.orden = v ?? 'nombre'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                              onPressed: _limpiar, child: const Text('Limpiar')),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _aplicar,
                            icon: const Icon(Icons.check),
                            label: const Text('Aplicar filtros'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
