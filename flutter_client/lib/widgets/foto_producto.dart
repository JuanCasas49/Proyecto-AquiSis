import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Fotografía del producto (desde el servidor) o un ícono si no tiene.
class FotoProducto extends StatelessWidget {
  final int productoId;
  final bool tieneFoto;
  final double tamano;

  const FotoProducto({
    super.key,
    required this.productoId,
    required this.tieneFoto,
    this.tamano = 72,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final marcador = Container(
      width: tamano,
      height: tamano,
      color: colores.secondaryContainer,
      child: Icon(Icons.shopping_basket_outlined,
          size: tamano * 0.45, color: colores.onSecondaryContainer),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: tieneFoto
          ? Image.network(
              ApiService.urlFoto(productoId),
              width: tamano,
              height: tamano,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => marcador,
              loadingBuilder: (context, child, progreso) =>
                  progreso == null ? child : marcador,
            )
          : marcador,
    );
  }
}
