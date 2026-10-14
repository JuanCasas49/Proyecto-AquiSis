import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../utils/formato.dart';
import 'aviso_antiguedad.dart';
import 'foto_producto.dart';

/// Tarjeta del catálogo: producto, rango de precios y dónde está más barato.
class ProductoCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;

  const ProductoCard({super.key, required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final p = producto;
    final hayPrecio = p.precioMin != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FotoProducto(productoId: p.id, tieneFoto: p.tieneFoto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('${p.marca} · ${p.presentacionCompleta}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    if (hayPrecio) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(cop(p.precioMin!),
                              style: tema.textTheme.titleLarge?.copyWith(
                                  color: tema.colorScheme.primary,
                                  fontWeight: FontWeight.bold)),
                          if (p.precioMax != null && p.precioMax != p.precioMin)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text('hasta ${cop(p.precioMax!)}',
                                  style: tema.textTheme.bodySmall),
                            ),
                        ],
                      ),
                      Text(
                        'Más barato en ${p.mejorAlmacen ?? ''}'
                        '${p.mejorCiudad != null ? ' (${p.mejorCiudad})' : ''}'
                        ' · ${p.nSedes} ${p.nSedes == 1 ? 'sede' : 'sedes'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall,
                      ),
                      if (p.desactualizado && p.diasUltima != null) ...[
                        const SizedBox(height: 6),
                        AvisoAntiguedad(dias: p.diasUltima!, compacto: true),
                      ],
                    ] else
                      Text('Sin precios reportados',
                          style: tema.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
