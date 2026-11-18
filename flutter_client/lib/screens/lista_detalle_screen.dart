import 'package:flutter/material.dart';

import '../models/lista.dart';
import '../services/api_service.dart';
import '../services/sesion_service.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/foto_producto.dart';
import 'listas_screen.dart';
import 'selector_producto_screen.dart';
import 'valoracion_tab.dart';

/// HU-06 + HU-07: productos de una lista (agregar, cambiar cantidad, quitar) y su valor por supermercado.
class ListaDetalleScreen extends StatefulWidget {
  final int listaId;
  final String nombre;

  const ListaDetalleScreen({super.key, required this.listaId, required this.nombre});

  @override
  State<ListaDetalleScreen> createState() => _ListaDetalleScreenState();
}

class _ListaDetalleScreenState extends State<ListaDetalleScreen> with SingleTickerProviderStateMixin {
  late final TabController _pestanas = TabController(length: 2, vsync: this);
  late String _nombre = widget.nombre;
  ListaDetalle? _detalle;
  bool _cargando = true;
  String? _error;

  /// Cambia cada vez que se modifica la lista para que la pestaña de valor se recalcule.
  int _version = 0;

  int get _usuarioId => Sesion.instancia.usuario?.id ?? 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pestanas.dispose();
    super.dispose();
  }

  String _mensaje(Object e) => e is ApiException ? e.mensaje : 'Ocurrió un error inesperado';

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 2)));
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _detalle == null;
      _error = null;
    });
    try {
      final d = await ApiService.detalleLista(widget.listaId, _usuarioId);
      if (!mounted) return;
      setState(() {
        _detalle = d;
        _nombre = d.nombre;
        _cargando = false;
        _version++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mensaje(e);
        _cargando = false;
      });
    }
  }

  Future<void> _cambiarCantidad(ItemLista item, int nueva) async {
    final detalle = _detalle;
    if (detalle == null || nueva < 1 || nueva > 999 || nueva == item.cantidad) return;
    List<ItemLista> con(int cantidad) =>
        detalle.items.map((i) => i.productoId == item.productoId ? i.conCantidad(cantidad) : i).toList();
    final anterior = item.cantidad;
    setState(() => _detalle = ListaDetalle(id: detalle.id, nombre: detalle.nombre, items: con(nueva)));
    try {
      await ApiService.modificarCantidadLista(widget.listaId, _usuarioId, item.productoId, nueva);
      if (mounted) setState(() => _version++);
    } catch (e) {
      if (!mounted) return;
      setState(() => _detalle = ListaDetalle(id: detalle.id, nombre: detalle.nombre, items: con(anterior)));
      _aviso(_mensaje(e));
    }
  }

  Future<void> _quitar(ItemLista item) async {
    final detalle = _detalle;
    if (detalle == null) return;
    try {
      await ApiService.quitarItemLista(widget.listaId, _usuarioId, item.productoId);
      if (!mounted) return;
      setState(() {
        _detalle = ListaDetalle(
            id: detalle.id,
            nombre: detalle.nombre,
            items: detalle.items.where((i) => i.productoId != item.productoId).toList());
        _version++;
      });
      _aviso('${item.nombre} se quitó de la lista');
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    }
  }

  Future<void> _agregar() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SelectorProductoScreen(listaId: widget.listaId),
    ));
    if (mounted) _cargar();
  }

  Future<void> _renombrar() async {
    final nombre = await pedirNombreLista(context,
        titulo: 'Renombrar lista', textoBoton: 'Guardar', inicial: _nombre);
    if (nombre == null || !mounted) return;
    try {
      final lista = await ApiService.renombrarLista(widget.listaId, _usuarioId, nombre);
      if (mounted) setState(() => _nombre = lista.nombre);
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nombre),
        actions: [
          IconButton(
            tooltip: 'Renombrar lista',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _renombrar,
          ),
        ],
        bottom: TabBar(
          controller: _pestanas,
          tabs: const [Tab(text: 'Productos'), Tab(text: 'Valor y ahorro')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Agregar producto'),
      ),
      body: TabBarView(
        controller: _pestanas,
        children: [
          _productos(),
          ValoracionTab(
            key: ValueKey(_version),
            listaId: widget.listaId,
            irAProductos: () => _pestanas.animateTo(0),
          ),
        ],
      ),
    );
  }

  Widget _productos() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null && _detalle == null) {
      return Center(
        child: EstadoVacio(
          icono: Icons.cloud_off_outlined,
          titulo: 'No se pudo cargar la lista',
          detalle: _error,
          textoAccion: 'Reintentar',
          onAccion: _cargar,
        ),
      );
    }
    final detalle = _detalle!;
    if (detalle.items.isEmpty) {
      return Center(
        child: EstadoVacio(
          icono: Icons.shopping_cart_outlined,
          titulo: 'La lista está vacía',
          detalle: 'Agregue los productos que piensa comprar para ver cuánto cuesta en cada supermercado.',
          textoAccion: 'Agregar producto',
          onAccion: _agregar,
        ),
      );
    }
    final tema = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              '${detalle.items.length} ${detalle.items.length == 1 ? 'producto' : 'productos'} · '
              '${detalle.unidades} ${detalle.unidades == 1 ? 'unidad' : 'unidades'}',
              style: tema.textTheme.labelLarge,
            ),
          ),
          for (final item in detalle.items) _tarjeta(item),
        ],
      ),
    );
  }

  Widget _tarjeta(ItemLista item) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        child: Row(
          children: [
            FotoProducto(productoId: item.productoId, tieneFoto: item.tieneFoto, tamano: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
                  Text('${item.marca} · ${item.presentacionCompleta}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('menos-${item.productoId}'),
              tooltip: 'Disminuir cantidad',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: item.cantidad > 1 ? () => _cambiarCantidad(item, item.cantidad - 1) : null,
            ),
            SizedBox(
              width: 28,
              child: Text('${item.cantidad}',
                  key: ValueKey('cantidad-${item.productoId}'),
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleMedium),
            ),
            IconButton(
              key: ValueKey('mas-${item.productoId}'),
              tooltip: 'Aumentar cantidad',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: item.cantidad < 999 ? () => _cambiarCantidad(item, item.cantidad + 1) : null,
            ),
            IconButton(
              key: ValueKey('quitar-${item.productoId}'),
              tooltip: 'Quitar de la lista',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, color: tema.colorScheme.error),
              onPressed: () => _quitar(item),
            ),
          ],
        ),
      ),
    );
  }
}
