import 'package:flutter/material.dart';

import '../models/lista.dart';
import '../services/api_service.dart';
import '../services/sesion_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';

/// HU-07: valor total estimado de la lista por supermercado y ahorro frente al más costoso.
class ValoracionTab extends StatefulWidget {
  final int listaId;
  final VoidCallback irAProductos;

  const ValoracionTab({super.key, required this.listaId, required this.irAProductos});

  @override
  State<ValoracionTab> createState() => _ValoracionTabState();
}

class _ValoracionTabState extends State<ValoracionTab> {
  Valoracion? _valoracion;
  List<String> _ciudades = [];
  String? _ciudad;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    ApiService.ciudades().then((c) {
      if (mounted) setState(() => _ciudades = c);
    }).catchError((Object _) {});
  }

  Future<void> _cargar() async {
    final usuario = Sesion.instancia.usuario;
    if (usuario == null) return;
    setState(() {
      _cargando = _valoracion == null;
      _error = null;
    });
    try {
      final v = await ApiService.valoracionLista(widget.listaId, usuario.id, ciudad: _ciudad);
      if (!mounted) return;
      setState(() {
        _valoracion = v;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.mensaje : 'Ocurrió un error inesperado';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null && _valoracion == null) {
      return Center(
        child: EstadoVacio(
          icono: Icons.cloud_off_outlined,
          titulo: 'No se pudo calcular el valor',
          detalle: _error,
          textoAccion: 'Reintentar',
          onAccion: _cargar,
        ),
      );
    }
    final v = _valoracion!;
    if (v.nProductos == 0) {
      return Center(
        child: EstadoVacio(
          icono: Icons.calculate_outlined,
          titulo: 'Agregue productos para calcular el valor',
          detalle: 'Verá cuánto cuesta su compra en cada supermercado y cuánto ahorraría.',
          textoAccion: 'Ir a Productos',
          onAccion: widget.irAProductos,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          if (_ciudades.isNotEmpty) _selectorCiudad(),
          _resumen(v),
          if (v.sinPrecioEnNingunSupermercado.isNotEmpty) ...[
            const SizedBox(height: 8),
            _aviso(Icons.help_outline,
                'Sin precio en ningún supermercado: ${v.sinPrecioEnNingunSupermercado.join(', ')}.'),
          ],
          if (v.resumen.hayPreciosDesactualizados) ...[
            const SizedBox(height: 8),
            _aviso(Icons.schedule,
                'Algunos precios tienen más de ${v.diasVigencia} días y pueden haber cambiado. Confírmelos en la tienda.'),
          ],
          const SizedBox(height: 12),
          if (v.supermercados.isEmpty)
            const EstadoVacio(
              icono: Icons.storefront_outlined,
              titulo: 'Ningún supermercado tiene precios para esta lista',
              detalle: 'Reporte precios de estos productos para poder estimar el valor.',
            )
          else
            for (final s in v.supermercados) _tarjetaSupermercado(s),
        ],
      ),
    );
  }

  Widget _selectorCiudad() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('ciudades-${_ciudades.length}'),
        initialValue: _ciudad,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Ciudad (opcional)',
          prefixIcon: Icon(Icons.location_city_outlined),
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Todas las ciudades')),
          ..._ciudades.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
        ],
        onChanged: (c) {
          setState(() => _ciudad = c);
          _cargar();
        },
      ),
    );
  }

  Widget _aviso(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 13, color: Colors.amber.shade900))),
        ],
      ),
    );
  }

  Widget _resumen(Valoracion v) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.onPrimaryContainer;
    final r = v.resumen;
    Widget contenido;
    if (r.nComparables >= 2) {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ahorro eligiendo el más económico', style: tema.textTheme.labelLarge?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(cop(r.ahorroCop),
              style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          Text('${porcentaje(r.ahorroPct)} menos que en ${r.masCostoso}', style: TextStyle(color: color)),
          const Divider(height: 20),
          Text('${r.masEconomico}: ${cop(r.totalMasEconomico ?? 0)}  ·  ${r.masCostoso}: ${cop(r.totalMasCostoso ?? 0)}',
              style: TextStyle(color: color)),
        ],
      );
    } else if (r.nComparables == 1) {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solo ${r.masEconomico} tiene todos los productos',
              style: tema.textTheme.titleMedium?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text('Total: ${cop(r.totalMasEconomico ?? 0)}. Se necesitan al menos 2 supermercados completos para calcular el ahorro.',
              style: TextStyle(color: color)),
        ],
      );
    } else {
      contenido = Text(
        'Ningún supermercado tiene precio para todos los productos de la lista. Se muestran totales parciales.',
        style: TextStyle(color: color),
      );
    }
    return Card(
      color: tema.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            contenido,
            const SizedBox(height: 8),
            Text('${v.nProductos} ${v.nProductos == 1 ? 'producto' : 'productos'} · '
                '${v.nUnidades} ${v.nUnidades == 1 ? 'unidad' : 'unidades'}'
                '${v.ciudad != null ? ' · ${v.ciudad}' : ''}',
                style: tema.textTheme.bodySmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaSupermercado(SupermercadoValoracion s) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: s.esMasEconomico ? tema.colorScheme.tertiaryContainer : null,
      child: ExpansionTile(
        key: PageStorageKey('super-${s.establecimientoId}'),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(s.almacen, style: tema.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.esMasEconomico)
              Text('Más económico',
                  style: TextStyle(color: tema.colorScheme.primary, fontWeight: FontWeight.w600)),
            if (s.completo && !s.esMasEconomico && s.diferenciaCop != null)
              Text('${copConSigno(s.diferenciaCop!)} (${porcentaje(s.diferenciaPct)}) vs. el más económico',
                  style: TextStyle(color: tema.colorScheme.error)),
            if (!s.completo)
              Text('Faltan ${s.productosSinPrecio.length}: ${s.productosSinPrecio.join(', ')}',
                  style: TextStyle(color: Colors.amber.shade900)),
            if (s.hayDesactualizados)
              Text('Incluye precios con más de ${_valoracion?.diasVigencia ?? 30} días',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(cop(s.total), style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(s.completo ? 'total' : 'parcial', style: tema.textTheme.bodySmall),
          ],
        ),
        children: [
          for (final l in s.lineas)
            ListTile(
              dense: true,
              title: Text(l.producto),
              subtitle: Text(l.precioUnitario == null
                  ? 'Sin precio en este supermercado'
                  : '${l.cantidad} × ${cop(l.precioUnitario!)}'
                      '${l.dias != null ? ' · ${antiguedad(l.dias!)}' : ''}'
                      '${l.desactualizado ? ' · desactualizado' : ''}'),
              trailing: Text(l.subtotal == null ? '—' : cop(l.subtotal!)),
            ),
        ],
      ),
    );
  }
}
