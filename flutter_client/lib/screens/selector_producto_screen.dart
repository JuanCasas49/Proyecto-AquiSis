import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalogo.dart';
import '../models/producto.dart';
import '../services/api_service.dart';
import '../services/sesion_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/foto_producto.dart';

/// Busca productos del catálogo y los agrega a una lista de mercado.
class SelectorProductoScreen extends StatefulWidget {
  final int listaId;

  const SelectorProductoScreen({super.key, required this.listaId});

  @override
  State<SelectorProductoScreen> createState() => _SelectorProductoScreenState();
}

class _SelectorProductoScreenState extends State<SelectorProductoScreen> {
  final TextEditingController _buscador = TextEditingController();
  Timer? _espera;
  List<Producto> _resultados = [];
  final Set<int> _agregados = {};
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final texto = _buscador.text.trim();
      final pagina = await ApiService.buscarProductos(
        FiltrosProducto(q: texto.isEmpty ? null : texto),
        tamano: 30,
      );
      if (!mounted) return;
      setState(() {
        _resultados = pagina.items;
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

  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 450), _cargar);
  }

  Future<void> _agregar(Producto p) async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final item = await ApiService.agregarItemLista(widget.listaId, usuario.id, p.id, 1);
      if (!mounted) return;
      setState(() => _agregados.add(p.id));
      mensajero.hideCurrentSnackBar();
      mensajero.showSnackBar(SnackBar(
        content: Text('${p.nombre} agregado (${item.cantidad} en la lista)'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      mensajero.showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.mensaje : 'No se pudo agregar el producto')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar productos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _buscador,
              onChanged: _alEscribir,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar producto o marca',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _resultados.isEmpty) return const Center(child: CircularProgressIndicator());
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
    if (_resultados.isEmpty) {
      return const Center(
        child: EstadoVacio(
          icono: Icons.search_off,
          titulo: 'Sin resultados',
          detalle: 'Pruebe con otro nombre. Si el producto no existe, regístrelo desde la pestaña Registrar.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _resultados.length,
      itemBuilder: (context, i) {
        final p = _resultados[i];
        final agregado = _agregados.contains(p.id);
        return ListTile(
          leading: FotoProducto(productoId: p.id, tieneFoto: p.tieneFoto, tamano: 48),
          title: Text(p.nombre),
          subtitle: Text('${p.marca} · ${p.presentacionCompleta}'
              '${p.precioMin != null ? ' · desde ${cop(p.precioMin!)}' : ''}'),
          trailing: IconButton(
            key: ValueKey('agregar-${p.id}'),
            tooltip: 'Agregar a la lista',
            icon: Icon(agregado ? Icons.check_circle : Icons.add_circle_outline),
            color: agregado ? Theme.of(context).colorScheme.primary : null,
            onPressed: () => _agregar(p),
          ),
        );
      },
    );
  }
}
