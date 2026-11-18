import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalogo.dart';
import '../services/listas_formulario.dart';
import '../utils/formato.dart';
import 'campo_autocompletar.dart';

/// Controladores del bloque "dónde y a qué precio" (compartido por el registro de
/// producto y por el reporte de un nuevo precio).
class SedePrecioController {
  final TextEditingController almacen = TextEditingController();
  final TextEditingController sede = TextEditingController();
  final TextEditingController ciudad = TextEditingController();
  final TextEditingController precio = TextEditingController();
  DateTime fecha = DateTime.now();

  /// Precio en COP (solo dígitos) o null si está vacío.
  double? get precioValor {
    final digitos = precio.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) return null;
    return double.tryParse(digitos);
  }

  String get fechaIsoValor => fechaIso(fecha);

  void limpiar() {
    almacen.clear();
    sede.clear();
    ciudad.clear();
    precio.clear();
    fecha = DateTime.now();
  }

  void dispose() {
    almacen.dispose();
    sede.dispose();
    ciudad.dispose();
    precio.dispose();
  }
}

String? _obligatorio(String? v, String campo) =>
    (v == null || v.trim().isEmpty) ? 'Ingrese $campo' : null;

/// Almacén, sede, ciudad, precio en COP y fecha del reporte.
class SedePrecioFields extends StatefulWidget {
  final SedePrecioController controller;
  final ListasFormulario listas;

  const SedePrecioFields({
    super.key,
    required this.controller,
    required this.listas,
  });

  @override
  State<SedePrecioFields> createState() => _SedePrecioFieldsState();
}

class _SedePrecioFieldsState extends State<SedePrecioFields> {
  SedePrecioController get _c => widget.controller;

  List<String> _sedesSugeridas() {
    final almacen = _c.almacen.text.trim().toLowerCase();
    final ciudad = _c.ciudad.text.trim().toLowerCase();
    final nombres = <String>{};
    for (final SedeInfo s in widget.listas.sedes) {
      if (almacen.isNotEmpty && s.almacen.toLowerCase() != almacen) continue;
      if (ciudad.isNotEmpty && s.ciudad.toLowerCase() != ciudad) continue;
      nombres.add(s.nombre);
    }
    return nombres.toList()..sort();
  }

  void _alElegirSede(String nombre) {
    if (_c.ciudad.text.trim().isNotEmpty) return;
    final almacen = _c.almacen.text.trim().toLowerCase();
    for (final SedeInfo s in widget.listas.sedes) {
      if (s.nombre == nombre &&
          (almacen.isEmpty || s.almacen.toLowerCase() == almacen)) {
        _c.ciudad.text = s.ciudad;
        break;
      }
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _c.fecha,
      firstDate: hoy.subtract(const Duration(days: 730)),
      lastDate: hoy,
      helpText: 'Fecha en que vio el precio',
    );
    if (elegida != null) setState(() => _c.fecha = elegida);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CampoAutocompletar(
          controller: _c.almacen,
          etiqueta: 'Almacén (Éxito, D1, Ara...)',
          icono: Icons.storefront_outlined,
          opciones: () => widget.listas.almacenes,
          validator: (v) => _obligatorio(v, 'el almacén'),
        ),
        const SizedBox(height: 12),
        CampoAutocompletar(
          controller: _c.sede,
          etiqueta: 'Sede (ej. Éxito Chapinero)',
          icono: Icons.place_outlined,
          opciones: _sedesSugeridas,
          alSeleccionar: _alElegirSede,
          validator: (v) => _obligatorio(v, 'la sede'),
        ),
        const SizedBox(height: 12),
        CampoAutocompletar(
          controller: _c.ciudad,
          etiqueta: 'Ciudad',
          icono: Icons.location_city_outlined,
          opciones: () => widget.listas.ciudades,
          validator: (v) => _obligatorio(v, 'la ciudad'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _c.precio,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Precio en COP',
            prefixText: r'$ ',
            prefixIcon: Icon(Icons.payments_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            final valor = _c.precioValor;
            if (valor == null || valor < 1) return 'Ingrese el precio';
            if (valor > 100000000) return 'El precio es demasiado alto';
            return null;
          },
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _elegirFecha,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha del precio',
              prefixIcon: Icon(Icons.event_outlined),
              border: OutlineInputBorder(),
            ),
            child: Text(fechaCorta(_c.fechaIsoValor)),
          ),
        ),
      ],
    );
  }
}
