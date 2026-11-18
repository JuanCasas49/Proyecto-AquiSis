import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Adjuntar (o quitar) una foto como evidencia del precio. Opcional pero recomendada (HU-08).
class EvidenciaPicker extends StatelessWidget {
  final Uint8List? bytes;
  final ValueChanged<Uint8List?> alCambiar;
  final String ayuda;

  const EvidenciaPicker({
    super.key,
    required this.bytes,
    required this.alCambiar,
    this.ayuda = 'Recomendado: una foto de la etiqueta de precio sirve de evidencia y agiliza la validación.',
  });

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegir(BuildContext context, ImageSource fuente) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: fuente,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (archivo == null) return;
      final datos = await archivo.readAsBytes();
      if (!context.mounted) return;
      if (datos.length > 1000000) {
        _aviso(context, 'La foto pesa más de 1 MB. Elija otra o una de menor resolución.');
        return;
      }
      alCambiar(datos);
    } catch (_) {
      if (context.mounted) _aviso(context, 'No se pudo obtener la fotografía.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tema.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined, size: 18, color: tema.colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ayuda,
                    style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSecondaryContainer)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (bytes != null)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes!, width: 96, height: 96, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => alCambiar(null),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar foto'),
              ),
            ],
          )
        else
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _elegir(context, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Cámara'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _elegir(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ],
          ),
      ],
    );
  }
}
