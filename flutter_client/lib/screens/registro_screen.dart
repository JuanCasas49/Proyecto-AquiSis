import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/catalogo.dart';
import '../services/api_service.dart';
import '../services/listas_formulario.dart';
import '../services/sesion_service.dart';
import '../widgets/campo_autocompletar.dart';
import '../widgets/sede_precio_fields.dart';

/// Registro de un producto con su precio. Si el producto ya existe (mismo nombre,
/// marca, presentación y cantidad) el servidor solo agrega el nuevo precio.
class RegistroScreen extends StatefulWidget {
  final void Function(int productoId) onRegistrado;
  final VoidCallback irAPerfil;

  const RegistroScreen({
    super.key,
    required this.onRegistrado,
    required this.irAPerfil,
  });

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  static const List<String> _presentaciones = [
    'Botella', 'Bolsa', 'Caja', 'Paquete', 'Lata', 'Frasco', 'Tarro', 'Garrafa',
    'Sachet', 'Bandeja', 'Unidad', 'Tubo',
  ];
  static const List<String> _unidades = ['g', 'kg', 'ml', 'l', 'un'];

  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _marca = TextEditingController();
  final _categoria = TextEditingController();
  final _descripcion = TextEditingController();
  final _presentacion = TextEditingController();
  final _cantidad = TextEditingController();
  final SedePrecioController _sede = SedePrecioController();
  final ImagePicker _selector = ImagePicker();

  String _unidad = 'un';
  Uint8List? _foto;
  ListasFormulario _listas = const ListasFormulario();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    Sesion.instancia.addListener(_alCambiarSesion);
    _cargarListas();
  }

  @override
  void dispose() {
    Sesion.instancia.removeListener(_alCambiarSesion);
    _nombre.dispose();
    _marca.dispose();
    _categoria.dispose();
    _descripcion.dispose();
    _presentacion.dispose();
    _cantidad.dispose();
    _sede.dispose();
    super.dispose();
  }

  void _alCambiarSesion() {
    if (mounted) setState(() {});
  }

  Future<void> _cargarListas() async {
    final listas = await ListasFormulario.cargar();
    if (mounted) setState(() => _listas = listas);
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirFoto(ImageSource fuente) async {
    try {
      final archivo = await _selector.pickImage(
        source: fuente,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 1000000) {
        _aviso('La foto pesa más de 1 MB. Elija otra o una de menor resolución.');
        return;
      }
      setState(() => _foto = bytes);
    } catch (_) {
      _aviso('No se pudo obtener la fotografía.');
    }
  }

  double? get _cantidadValor =>
      double.tryParse(_cantidad.text.trim().replaceAll(',', '.'));

  Future<void> _enviar() async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    try {
      final resultado = await ApiService.registrarProducto(RegistroProducto(
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        marca: _marca.text.trim(),
        categoria: _categoria.text.trim(),
        presentacion: _presentacion.text.trim(),
        cantidad: _cantidadValor!,
        unidad: _unidad,
        precioCop: _sede.precioValor!,
        almacen: _sede.almacen.text.trim(),
        sede: _sede.sede.text.trim(),
        ciudad: _sede.ciudad.text.trim(),
        fecha: _sede.fechaIsoValor,
        usuarioId: usuario.id,
        fotoBase64: _foto == null ? null : base64Encode(_foto!),
      ));
      if (!mounted) return;
      _aviso(resultado.productoNuevo
          ? 'Producto registrado. ¡Gracias por reportar!'
          : 'Ese producto ya existía: se agregó su nuevo precio.');
      _limpiar();
      setState(() => _enviando = false);
      widget.onRegistrado(resultado.productoId);
      _cargarListas(); // incluye lo recién creado en las sugerencias
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _aviso(e is ApiException ? e.mensaje : 'No se pudo registrar el producto');
    }
  }

  void _limpiar() {
    _formKey.currentState?.reset();
    _nombre.clear();
    _marca.clear();
    _categoria.clear();
    _descripcion.clear();
    _presentacion.clear();
    _cantidad.clear();
    _sede.limpiar();
    _unidad = 'un';
    _foto = null;
  }

  String? _obligatorio(String? v, String campo) =>
      (v == null || v.trim().isEmpty) ? 'Ingrese $campo' : null;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar precio'),
        backgroundColor: tema.colorScheme.inversePrimary,
      ),
      body: !Sesion.instancia.activa
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 56, color: tema.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('Identifíquese para reportar precios',
                        style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    const Text(
                        'Así sus reportes quedan asociados a usted y otros usuarios pueden confiar en ellos.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: widget.irAPerfil, child: const Text('Ir a Perfil')),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _seccion('Fotografía (opcional)'),
                    _bloqueFoto(),
                    const SizedBox(height: 20),
                    _seccion('Producto'),
                    TextFormField(
                      controller: _nombre,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText: 'Nombre del producto',
                          prefixIcon: Icon(Icons.label_outline),
                          border: OutlineInputBorder()),
                      validator: (v) => _obligatorio(v, 'el nombre'),
                    ),
                    const SizedBox(height: 12),
                    CampoAutocompletar(
                      controller: _marca,
                      etiqueta: 'Marca',
                      icono: Icons.sell_outlined,
                      opciones: () => _listas.marcas,
                      validator: (v) => _obligatorio(v, 'la marca'),
                    ),
                    const SizedBox(height: 12),
                    CampoAutocompletar(
                      controller: _categoria,
                      etiqueta: 'Categoría',
                      icono: Icons.category_outlined,
                      opciones: () => _listas.categorias,
                      validator: (v) => _obligatorio(v, 'la categoría'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descripcion,
                      maxLines: 2,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 4),
                    CampoAutocompletar(
                      controller: _presentacion,
                      etiqueta: 'Presentación (botella, bolsa, caja...)',
                      icono: Icons.inventory_2_outlined,
                      opciones: () => _presentaciones,
                      validator: (v) => _obligatorio(v, 'la presentación'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _cantidad,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                            ],
                            decoration: const InputDecoration(
                                labelText: 'Cantidad',
                                prefixIcon: Icon(Icons.straighten),
                                border: OutlineInputBorder()),
                            validator: (v) {
                              final valor = _cantidadValor;
                              if (valor == null || valor <= 0) return 'Cantidad inválida';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _unidad,
                            decoration: const InputDecoration(
                                labelText: 'Unidad', border: OutlineInputBorder()),
                            items: [
                              for (final u in _unidades)
                                DropdownMenuItem(value: u, child: Text(u)),
                            ],
                            onChanged: (v) => setState(() => _unidad = v ?? 'un'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _seccion('Dónde y a qué precio'),
                    SedePrecioFields(controller: _sede, listas: _listas),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(_enviando ? 'Guardando…' : 'Guardar en la nube'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _seccion(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _bloqueFoto() {
    if (_foto != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_foto!, width: 96, height: 96, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () => setState(() => _foto = null),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Quitar foto'),
          ),
        ],
      );
    }
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () => _elegirFoto(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Cámara'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _elegirFoto(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Galería'),
        ),
      ],
    );
  }
}
