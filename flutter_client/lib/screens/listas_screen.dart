import 'package:flutter/material.dart';

import '../models/lista.dart';
import '../services/api_service.dart';
import '../services/sesion_service.dart';
import '../widgets/estado_vacio.dart';
import 'lista_detalle_screen.dart';

/// Pide un nombre para una lista (crear o renombrar). Devuelve null si se cancela.
Future<String?> pedirNombreLista(BuildContext context,
    {required String titulo, required String textoBoton, String inicial = ''}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoNombre(titulo: titulo, textoBoton: textoBoton, inicial: inicial),
  );
}

class _DialogoNombre extends StatefulWidget {
  final String titulo;
  final String textoBoton;
  final String inicial;
  const _DialogoNombre({required this.titulo, required this.textoBoton, required this.inicial});

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  late final TextEditingController _controlador = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _aceptar() {
    final nombre = _controlador.text.trim();
    if (nombre.isEmpty) return;
    Navigator.pop(context, nombre);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _controlador,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nombre de la lista', border: OutlineInputBorder()),
        onSubmitted: (_) => _aceptar(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _aceptar, child: Text(widget.textoBoton)),
      ],
    );
  }
}

/// HU-06: mis listas de mercado (crear varias con nombre propio, renombrar, eliminar).
class ListasScreen extends StatefulWidget {
  final VoidCallback irAPerfil;

  const ListasScreen({super.key, required this.irAPerfil});

  @override
  State<ListasScreen> createState() => _ListasScreenState();
}

class _ListasScreenState extends State<ListasScreen> {
  List<ListaResumen> _listas = [];
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Sesion.instancia.addListener(_alCambiarSesion);
    if (Sesion.instancia.activa) _cargar();
  }

  @override
  void dispose() {
    Sesion.instancia.removeListener(_alCambiarSesion);
    super.dispose();
  }

  void _alCambiarSesion() {
    if (!mounted) return;
    if (Sesion.instancia.activa) {
      _cargar();
    } else {
      setState(() => _listas = []);
    }
  }

  String _mensaje(Object e) => e is ApiException ? e.mensaje : 'Ocurrió un error inesperado';

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _cargar() async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final listas = await ApiService.listas(usuario.id);
      if (!mounted) return;
      setState(() {
        _listas = listas;
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

  Future<void> _abrir(ListaResumen lista) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ListaDetalleScreen(listaId: lista.id, nombre: lista.nombre),
    ));
    if (mounted) _cargar();
  }

  Future<void> _nueva() async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    final nombre = await pedirNombreLista(context, titulo: 'Nueva lista', textoBoton: 'Crear');
    if (nombre == null || !mounted) return;
    try {
      final lista = await ApiService.crearLista(usuario.id, nombre);
      if (!mounted) return;
      await _abrir(lista);
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    }
  }

  Future<void> _renombrar(ListaResumen lista) async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    final nombre = await pedirNombreLista(context,
        titulo: 'Renombrar lista', textoBoton: 'Guardar', inicial: lista.nombre);
    if (nombre == null || !mounted) return;
    try {
      await ApiService.renombrarLista(lista.id, usuario.id, nombre);
      if (mounted) _cargar();
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    }
  }

  Future<void> _eliminar(ListaResumen lista) async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text('¿Eliminar "${lista.nombre}"? Se quitarán sus ${lista.nProductos} productos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await ApiService.eliminarLista(lista.id, usuario.id);
      if (!mounted) return;
      _aviso('Lista eliminada');
      _cargar();
    } catch (e) {
      if (mounted) _aviso(_mensaje(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis listas'),
        backgroundColor: tema.colorScheme.inversePrimary,
      ),
      floatingActionButton: Sesion.instancia.activa
          ? FloatingActionButton.extended(
              onPressed: _nueva,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Nueva lista'),
            )
          : null,
      body: !Sesion.instancia.activa
          ? Center(
              child: EstadoVacio(
                icono: Icons.person_outline,
                titulo: 'Identifíquese para usar sus listas',
                detalle: 'Sus listas de mercado quedan guardadas en su cuenta.',
                textoAccion: 'Ir a Perfil',
                onAccion: widget.irAPerfil,
              ),
            )
          : _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _listas.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _listas.isEmpty) {
      return Center(
        child: EstadoVacio(
          icono: Icons.cloud_off_outlined,
          titulo: 'No se pudieron cargar sus listas',
          detalle: _error,
          textoAccion: 'Reintentar',
          onAccion: _cargar,
        ),
      );
    }
    if (_listas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            EstadoVacio(
              icono: Icons.shopping_cart_outlined,
              titulo: 'Aún no tiene listas',
              detalle: 'Cree una lista para organizar su compra antes de ir al supermercado.',
              textoAccion: 'Crear mi primera lista',
              onAccion: _nueva,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: _listas.length,
        itemBuilder: (context, i) {
          final lista = _listas[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: ListTile(
              onTap: () => _abrir(lista),
              leading: const CircleAvatar(child: Icon(Icons.shopping_basket_outlined)),
              title: Text(lista.nombre),
              subtitle: Text(
                  '${lista.nProductos} ${lista.nProductos == 1 ? 'producto' : 'productos'} · '
                  '${lista.nUnidades} ${lista.nUnidades == 1 ? 'unidad' : 'unidades'}'),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opciones de la lista',
                onSelected: (accion) => accion == 'renombrar' ? _renombrar(lista) : _eliminar(lista),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
