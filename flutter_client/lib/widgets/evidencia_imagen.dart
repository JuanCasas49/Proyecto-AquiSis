import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Muestra la evidencia fotográfica de un reporte (o un aviso si no la tiene).
class EvidenciaImagen extends StatelessWidget {
  final int reporteId;
  final bool tiene;
  final double alto;

  const EvidenciaImagen({super.key, required this.reporteId, required this.tiene, this.alto = 160});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    Widget marcador(String texto) => Container(
          height: alto,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colores.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined, color: colores.outline),
              const SizedBox(width: 8),
              Text(texto, style: TextStyle(color: colores.onSurfaceVariant)),
            ],
          ),
        );
    if (!tiene) return marcador('Sin evidencia fotográfica');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        ApiService.urlEvidencia(reporteId),
        height: alto,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => marcador('No se pudo cargar la evidencia'),
        loadingBuilder: (context, child, progreso) => progreso == null ? child : marcador('Cargando evidencia…'),
      ),
    );
  }
}
