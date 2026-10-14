import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalogo.dart';
import '../models/producto.dart';
import '../services/api_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/producto_card.dart';
import 'detalle_screen.dart';
import 'filtros_sheet.dart';

/// Catálogo: búsqueda por nombre/marca, filtros combinables y paginación.
class CatalogoScreen extends StatefulWidget {
  /// Cambia cuando otra pestaña registra algo, para recargar la lista.
  final int recarga;

  const CatalogoScreen({super.key, this.recarga = 0});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  FiltrosProducto _filtros = FiltrosProducto();
  final TextEditingController _buscador = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _espera;

  List<Producto> _items = [];
  int _pagina = 1;
  int _total = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
    _cargar();
  }

  @override
  void didUpdateWidget(covariant CatalogoScreen anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.recarga != widget.recarga) _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _buscador.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _mensaje(Object e) =>
      e is ApiException ? e.mensaje : 'Ocurrió un error inesperado';

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final p = await ApiService.buscarProductos(_filtros, pagina: 1);
      if (!mounted) return;
      setState(() {
        _items = p.items;
        _total = p.total;
        _pagina = 1;
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

  Future<void> _cargarMas() async {
    if (_cargando || _cargandoMas || _items.length >= _total) return;
    setState(() => _cargandoMas = true);
    try {
      final p = await ApiService.buscarProductos(_filtros, pagina: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...p.items];
        _total = p.total;
        _pagina = _pagina + 1;
        _cargandoMas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoMas = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mensaje(e))));
    }
  }

  void _alDesplazar() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _cargarMas();
    }
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 450), () {
      _filtros.q = texto.trim().isEmpty ? null : texto.trim();
      _cargar();
    });
  }

  Future<void> _abrirFiltros() async {
    final nuevos = await mostrarFiltros(context, _filtros);
    if (nuevos == null) return;
    nuevos.q = _filtros.q;
    setState(() => _filtros = nuevos);
    _cargar();
  }

  void _quitar(void Function() cambio) {
    setState(cambio);
    _cargar();
  }

  List<Widget> _chipsActivos() {
    final f = _filtros;
    final chips = <Widget>[];
    Widget chip(String texto, void Function() alQuitar) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InputChip(
            label: Text(texto),
            onDeleted: () => _quitar(alQuitar),
          ),
        );
    if (f.categoriaId != null) {
      chips.add(chip(f.categoriaNombre ?? 'Categoría', () {
        f.categoriaId = null;
        f.categoriaNombre = null;
      }));
    }
    if (f.marcaId != null) {
      chips.add(chip(f.marcaNombre ?? 'Marca', () {
        f.marcaId = null;
        f.marcaNombre = null;
      }));
    }
    if (f.establecimientoId != null) {
      chips.add(chip(f.establecimientoNombre ?? 'Almacén', () {
        f.establecimientoId = null;
        f.establecimientoNombre = null;
      }));
    }
    if (f.ciudad != null) chips.add(chip(f.ciudad!, () => f.ciudad = null));
    if (f.precioMin != null || f.precioMax != null) {
      final desde = f.precioMin != null ? cop(f.precioMin!) : '…';
      final hasta = f.precioMax != null ? cop(f.precioMax!) : '…';
      chips.add(chip('$desde – $hasta', () {
        f.precioMin = null;
        f.precioMax = null;
      }));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final chips = _chipsActivos();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Precios Colombia'),
        backgroundColor: tema.colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscador,
                    onChanged: (texto) {
                      setState(() {});
                      _alEscribir(texto);
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar producto o marca',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buscador.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _buscador.clear();
                                _alEscribir('');
                                setState(() {});
                              },
                            ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _filtros.activos > 0,
                  label: Text('${_filtros.activos}'),
                  child: IconButton.filledTonal(
                    onPressed: _abrirFiltros,
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filtros',
                  ),
                ),
              ],
            ),
          ),
          if (chips.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: chips,
              ),
            ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: EstadoVacio(
          icono: Icons.cloud_off_outlined,
          titulo: 'No se pudo cargar el catálogo',
          detalle: _error,
          textoAccion: 'Reintentar',
          onAccion: _cargar,
        ),
      );
    }
    if (_items.isEmpty) {
      final hayFiltros = _filtros.activos > 0 || (_filtros.q?.isNotEmpty ?? false);
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            EstadoVacio(
              icono: Icons.search_off,
              titulo: hayFiltros
                  ? 'Sin resultados para esa búsqueda'
                  : 'Aún no hay productos registrados',
              detalle: hayFiltros
                  ? 'Pruebe con otros filtros o quítelos.'
                  : 'Use la pestaña Registrar para reportar el primer precio.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _items.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
              child: Text(
                '$_total ${_total == 1 ? 'producto' : 'productos'}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            );
          }
          if (i == _items.length + 1) {
            return _cargandoMas
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final producto = _items[i - 1];
          return ProductoCard(
            producto: producto,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DetalleScreen(productoId: producto.id),
            )),
          );
        },
      ),
    );
  }
}
