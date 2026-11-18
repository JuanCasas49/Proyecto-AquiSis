import 'package:flutter/material.dart';

/// Campo de texto libre con sugerencias (marca, categoría, almacén, sede, ciudad...).
/// El usuario puede escribir un valor nuevo: el servidor lo crea si no existe.
class CampoAutocompletar extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final IconData? icono;
  final List<String> Function() opciones;
  final String? Function(String?)? validator;
  final void Function(String)? alSeleccionar;

  const CampoAutocompletar({
    super.key,
    required this.controller,
    required this.etiqueta,
    required this.opciones,
    this.icono,
    this.validator,
    this.alSeleccionar,
  });

  @override
  State<CampoAutocompletar> createState() => _CampoAutocompletarState();
}

class _CampoAutocompletarState extends State<CampoAutocompletar> {
  final FocusNode _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        return RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _foco,
          optionsBuilder: (TextEditingValue valor) {
            final texto = valor.text.trim().toLowerCase();
            final todas = widget.opciones();
            if (texto.isEmpty) return todas.take(8);
            return todas
                .where((o) =>
                    o.toLowerCase().contains(texto) &&
                    o.toLowerCase() != texto)
                .take(8);
          },
          onSelected: (seleccion) => widget.alSeleccionar?.call(seleccion),
          fieldViewBuilder: (context, controller, focusNode, alEnviar) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.etiqueta,
                prefixIcon: widget.icono == null ? null : Icon(widget.icono),
                border: const OutlineInputBorder(),
              ),
              validator: widget.validator,
              onFieldSubmitted: (_) => alEnviar(),
            );
          },
          optionsViewBuilder: (context, alElegir, opciones) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 220,
                    maxWidth: restricciones.maxWidth,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: opciones.length,
                    itemBuilder: (context, i) {
                      final opcion = opciones.elementAt(i);
                      return ListTile(
                        dense: true,
                        title: Text(opcion),
                        onTap: () => alElegir(opcion),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
