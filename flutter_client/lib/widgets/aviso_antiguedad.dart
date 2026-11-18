import 'package:flutter/material.dart';

import '../utils/formato.dart';

/// Advertencia visible cuando un precio puede estar desactualizado.
class AvisoAntiguedad extends StatelessWidget {
  final int dias;
  final bool compacto;

  const AvisoAntiguedad({super.key, required this.dias, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    final texto = compacto
        ? 'Precio ${antiguedad(dias)} · podría estar desactualizado'
        : 'Reportado ${antiguedad(dias)}: podría estar desactualizado. Confírmelo en la tienda.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: Colors.amber.shade900),
          const SizedBox(width: 4),
          Flexible(
            child: Text(texto,
                style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
          ),
        ],
      ),
    );
  }
}
