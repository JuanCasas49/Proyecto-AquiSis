import 'package:flutter/material.dart';

/// Mensaje centrado para listas vacías, errores o estados de carga fallida.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? detalle;
  final String? textoAccion;
  final VoidCallback? onAccion;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.textoAccion,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 56, color: tema.colorScheme.outline),
          const SizedBox(height: 12),
          Text(titulo,
              textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
          if (detalle != null) ...[
            const SizedBox(height: 6),
            Text(detalle!,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ],
          if (textoAccion != null && onAccion != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAccion, child: Text(textoAccion!)),
          ],
        ],
      ),
    );
  }
}
