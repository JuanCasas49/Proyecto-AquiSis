import 'package:flutter/material.dart';

import '../models/detalle.dart';
import '../utils/formato.dart';
import 'aviso_antiguedad.dart';

/// Fila del comparador: posición, sede, precio y diferencia contra el más barato.
class PrecioTile extends StatelessWidget {
  final PrecioSede precio;
  final int posicion;

  const PrecioTile({super.key, required this.precio, required this.posicion});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final p = precio;
    final destacado = p.esMasBarato;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: destacado ? tema.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: destacado
                      ? tema.colorScheme.primary
                      : tema.colorScheme.surfaceContainerHighest,
                  foregroundColor: destacado
                      ? tema.colorScheme.onPrimary
                      : tema.colorScheme.onSurfaceVariant,
                  child: Text('$posicion', style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.almacen, style: tema.textTheme.titleSmall),
                      Text('${p.sede} · ${p.ciudad}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall),
                      Text('Reportado ${antiguedad(p.dias)} (${fechaCorta(p.fecha)})',
                          style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(cop(p.precioCop),
                        style: tema.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (destacado)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: tema.colorScheme.primary),
                          const SizedBox(width: 3),
                          Text('Más barato',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: tema.colorScheme.primary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      )
                    else
                      Text(
                        '${copConSigno(p.diferenciaCop)}'
                        '${p.diferenciaPct != null ? ' (${porcentaje(p.diferenciaPct)})' : ''}',
                        style: TextStyle(
                            fontSize: 12, color: tema.colorScheme.error),
                      ),
                  ],
                ),
              ],
            ),
            if (p.desactualizado) ...[
              const SizedBox(height: 8),
              AvisoAntiguedad(dias: p.dias, compacto: true),
            ],
          ],
        ),
      ),
    );
  }
}
