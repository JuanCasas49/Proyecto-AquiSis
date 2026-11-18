import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/catalogo.dart';
import '../models/detalle.dart';
import '../models/lista.dart';
import '../models/reporte_usuario.dart';
import '../models/producto.dart';

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final String mensaje;
  final int? status;
  ApiException(this.mensaje, [this.status]);
  @override
  String toString() => mensaje;
}

class ApiService {
  // URL del backend Quarkus. Puede fijarse al compilar/ejecutar:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
  // Valores por defecto según la plataforma:
  // - Web / iOS Simulator / Desktop: http://localhost:8080
  // - Android Emulator: http://10.0.2.2:8080
  // - Dispositivo físico: use --dart-define con la IP de su computador o la URL desplegada.
  static const String _urlDefinida = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_urlDefinida.isNotEmpty) return _urlDefinida;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const Duration _tiempoMaximo = Duration(seconds: 30);

  static Uri _uri(String ruta, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$ruta');
    return (query == null || query.isEmpty)
        ? uri
        : uri.replace(queryParameters: query);
  }

  static String urlFoto(int productoId) => '$baseUrl/api/productos/$productoId/foto';

  static dynamic _procesar(http.Response r) {
    final texto = utf8.decode(r.bodyBytes);
    dynamic cuerpo;
    if (texto.isNotEmpty) {
      try {
        cuerpo = jsonDecode(texto);
      } catch (_) {
        cuerpo = null;
      }
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return cuerpo;
    String mensaje = 'Error ${r.statusCode} del servidor';
    if (cuerpo is Map<String, dynamic> && cuerpo['error'] is String) {
      mensaje = cuerpo['error'] as String;
    }
    throw ApiException(mensaje, r.statusCode);
  }

  static Future<dynamic> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return _procesar(await peticion().timeout(_tiempoMaximo));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
          'No se pudo conectar con el servidor ($baseUrl). Revise su conexión e intente de nuevo.');
    }
  }

  static Future<dynamic> _get(String ruta, [Map<String, String>? query]) =>
      _enviar(() => http.get(_uri(ruta, query)));

  static Future<dynamic> _put(String ruta, Map<String, dynamic> cuerpo) =>
      _enviar(() => http.put(
            _uri(ruta),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(cuerpo),
          ));

  static Future<dynamic> _delete(String ruta, [Map<String, String>? query]) =>
      _enviar(() => http.delete(_uri(ruta, query)));

  static Future<dynamic> _post(String ruta, Map<String, dynamic> cuerpo) =>
      _enviar(() => http.post(
            _uri(ruta),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(cuerpo),
          ));

  // ---------------------------------------------------------------- catálogo

  static Future<PaginaProductos> buscarProductos(
    FiltrosProducto filtros, {
    int pagina = 1,
    int tamano = 20,
  }) async {
    final json = await _get('/api/productos', filtros.toQuery(pagina, tamano));
    return PaginaProductos.fromJson(json as Map<String, dynamic>);
  }

  /// Compatibilidad con la versión inicial: primera página del catálogo.
  static Future<List<Producto>> obtenerProductos({FiltrosProducto? filtros}) async {
    final pagina = await buscarProductos(filtros ?? FiltrosProducto());
    return pagina.items;
  }

  static Future<ProductoDetalle> obtenerDetalle(int id) async {
    final json = await _get('/api/productos/$id');
    return ProductoDetalle.fromJson(json as Map<String, dynamic>);
  }

  static Future<Comparacion> obtenerComparacion(
    int id, {
    String? ciudad,
    int unidades = 1,
  }) async {
    final query = <String, String>{'unidades': '$unidades'};
    if (ciudad != null) query['ciudad'] = ciudad;
    final json = await _get('/api/productos/$id/comparacion', query);
    return Comparacion.fromJson(json as Map<String, dynamic>);
  }

  static Future<List<Reporte>> obtenerHistorial(int id) async {
    final json = await _get('/api/productos/$id/historial');
    return (json as List<dynamic>)
        .map((e) => Reporte.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------- registro

  static Future<ResultadoRegistro> registrarProducto(RegistroProducto p) async {
    final json = await _post('/api/productos', p.toJson());
    return ResultadoRegistro.fromJson(json as Map<String, dynamic>);
  }

  static Future<ResultadoRegistro> agregarPrecio(int productoId, NuevoPrecio p) async {
    final json = await _post('/api/productos/$productoId/precios', p.toJson());
    return ResultadoRegistro.fromJson(json as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------- listas

  static Future<List<Opcion>> _opciones(String ruta) async {
    final json = await _get(ruta);
    return (json as List<dynamic>)
        .map((e) => Opcion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Opcion>> categorias() => _opciones('/api/categorias');
  static Future<List<Opcion>> marcas() => _opciones('/api/marcas');
  static Future<List<Opcion>> establecimientos() => _opciones('/api/establecimientos');

  static Future<List<String>> ciudades() async {
    final json = await _get('/api/ciudades');
    return (json as List<dynamic>).map((e) => e as String).toList();
  }

  static Future<List<SedeInfo>> sedes() async {
    final json = await _get('/api/sedes');
    return (json as List<dynamic>)
        .map((e) => SedeInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------- usuarios

  static Future<Usuario> registrarUsuario(String nombre, String email) async {
    final json = await _post('/api/usuarios', {'nombre': nombre, 'email': email});
    return Usuario.fromJson(json as Map<String, dynamic>);
  }

  /// Estado de la conexión con Neon: {estado, baseDeDatos, productos, reportes, usuarios}
  static Future<Map<String, dynamic>> salud() async {
    final json = await _get('/api/salud');
    return json as Map<String, dynamic>;
  }

  // ------------------------------------------- HU-06 / HU-07: listas de mercado

  static Future<List<ListaResumen>> listas(int usuarioId) async {
    final json = await _get('/api/listas', {'usuarioId': '$usuarioId'});
    return (json as List<dynamic>)
        .map((e) => ListaResumen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ListaResumen> crearLista(int usuarioId, String nombre) async {
    final json = await _post('/api/listas', {'usuarioId': usuarioId, 'nombre': nombre});
    return ListaResumen.fromJson(json as Map<String, dynamic>);
  }

  static Future<ListaResumen> renombrarLista(int listaId, int usuarioId, String nombre) async {
    final json = await _put('/api/listas/$listaId', {'usuarioId': usuarioId, 'nombre': nombre});
    return ListaResumen.fromJson(json as Map<String, dynamic>);
  }

  static Future<void> eliminarLista(int listaId, int usuarioId) async {
    await _delete('/api/listas/$listaId', {'usuarioId': '$usuarioId'});
  }

  static Future<ListaDetalle> detalleLista(int listaId, int usuarioId) async {
    final json = await _get('/api/listas/$listaId', {'usuarioId': '$usuarioId'});
    return ListaDetalle.fromJson(json as Map<String, dynamic>);
  }

  /// Agrega un producto a la lista (si ya estaba, el servidor suma las cantidades).
  static Future<ItemLista> agregarItemLista(
      int listaId, int usuarioId, int productoId, int cantidad) async {
    final json = await _post('/api/listas/$listaId/items',
        {'usuarioId': usuarioId, 'productoId': productoId, 'cantidad': cantidad});
    return ItemLista.fromJson(json as Map<String, dynamic>);
  }

  static Future<ItemLista> modificarCantidadLista(
      int listaId, int usuarioId, int productoId, int cantidad) async {
    final json = await _put('/api/listas/$listaId/items/$productoId',
        {'usuarioId': usuarioId, 'cantidad': cantidad});
    return ItemLista.fromJson(json as Map<String, dynamic>);
  }

  static Future<void> quitarItemLista(int listaId, int usuarioId, int productoId) async {
    await _delete('/api/listas/$listaId/items/$productoId', {'usuarioId': '$usuarioId'});
  }

  /// HU-07: total por supermercado y ahorro frente al más costoso.
  static Future<Valoracion> valoracionLista(int listaId, int usuarioId, {String? ciudad}) async {
    final query = <String, String>{'usuarioId': '$usuarioId'};
    if (ciudad != null) query['ciudad'] = ciudad;
    final json = await _get('/api/listas/$listaId/valoracion', query);
    return Valoracion.fromJson(json as Map<String, dynamic>);
  }

  // --------------------------------- HU-08: reportes, evidencia y moderación

  static String urlEvidencia(int reporteId) => '$baseUrl/api/precios/$reporteId/evidencia';

  static Future<Usuario> obtenerUsuario(int id) async {
    final json = await _get('/api/usuarios/$id');
    return Usuario.fromJson(json as Map<String, dynamic>);
  }

  static Future<List<ReporteUsuario>> misReportes(int usuarioId, {String? estado}) async {
    final query = <String, String>{};
    if (estado != null) query['estado'] = estado;
    final json = await _get('/api/usuarios/$usuarioId/reportes', query);
    return (json as List<dynamic>)
        .map((e) => ReporteUsuario.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cola de moderación (solo moderadores).
  static Future<List<ReporteUsuario>> reportesPendientes(int moderadorId) async {
    final json = await _get('/api/precios/pendientes', {'usuarioId': '$moderadorId'});
    return (json as List<dynamic>)
        .map((e) => ReporteUsuario.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> validarReporte(int reporteId, int moderadorId) async {
    await _post('/api/precios/$reporteId/validar', {'usuarioId': moderadorId});
  }

  static Future<void> rechazarReporte(int reporteId, int moderadorId, String? motivo) async {
    await _post('/api/precios/$reporteId/rechazar', {
      'usuarioId': moderadorId,
      if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
    });
  }
}
