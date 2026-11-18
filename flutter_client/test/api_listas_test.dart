import 'dart:convert';

import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/api_falsa.dart';
import 'helpers/listas_falsas.dart';

/// Comunicación app ↔ API de listas de mercado, valoración, reportes y moderación.
void main() {
  Map<String, dynamic> cuerpoDe(http.Request p) => jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;

  group('Listas de mercado (HU-06)', () {
    test('listas pide las del usuario', () async {
      late http.Request p0;
      await conApiFalsa((p) async {
        p0 = p;
        return respuestaJson([listaResumenJson(id: 1), listaResumenJson(id: 2, nombre: 'Fiesta')]);
      }, () async {
        final r = await ApiService.listas(5);
        expect(p0.method, 'GET');
        expect(p0.url.path, '/api/listas');
        expect(p0.url.queryParameters, {'usuarioId': '5'});
        expect(r.map((l) => l.nombre), ['Compra semanal', 'Fiesta']);
      });
    });

    test('crearLista, renombrarLista y eliminarLista usan sus rutas y verbos', () async {
      final peticiones = <String>[];
      Map<String, dynamic>? crear, renombrar;
      Map<String, String>? borrar;
      await conApiFalsa((p) async {
        peticiones.add('${p.method} ${p.url.path}');
        if (p.method == 'POST') {
          crear = cuerpoDe(p);
          return respuestaJson(listaResumenJson(id: 7, nombre: 'Nueva'), 201);
        }
        if (p.method == 'PUT') {
          renombrar = cuerpoDe(p);
          return respuestaJson(listaResumenJson(id: 7, nombre: 'Otra'));
        }
        borrar = p.url.queryParameters;
        return respuestaJson(null, 204);
      }, () async {
        expect((await ApiService.crearLista(5, 'Nueva')).id, 7);
        expect((await ApiService.renombrarLista(7, 5, 'Otra')).nombre, 'Otra');
        await ApiService.eliminarLista(7, 5);
        expect(peticiones, ['POST /api/listas', 'PUT /api/listas/7', 'DELETE /api/listas/7']);
        expect(crear, {'usuarioId': 5, 'nombre': 'Nueva'});
        expect(renombrar, {'usuarioId': 5, 'nombre': 'Otra'});
        expect(borrar, {'usuarioId': '5'});
      });
    });

    test('detalleLista, agregar, modificar cantidad y quitar productos', () async {
      final peticiones = <String>[];
      Map<String, dynamic>? agregar, modificar;
      await conApiFalsa((p) async {
        peticiones.add('${p.method} ${p.url.path}');
        if (p.method == 'GET') return respuestaJson(listaDetalleJson());
        if (p.method == 'POST') {
          agregar = cuerpoDe(p);
          return respuestaJson(itemListaJson(id: 3, cantidad: 2), 201);
        }
        if (p.method == 'PUT') {
          modificar = cuerpoDe(p);
          return respuestaJson(itemListaJson(id: 3, cantidad: 9));
        }
        return respuestaJson(null, 204);
      }, () async {
        expect((await ApiService.detalleLista(9, 5)).items.length, 2);
        expect((await ApiService.agregarItemLista(9, 5, 3, 2)).cantidad, 2);
        expect((await ApiService.modificarCantidadLista(9, 5, 3, 9)).cantidad, 9);
        await ApiService.quitarItemLista(9, 5, 3);
        expect(peticiones, [
          'GET /api/listas/9',
          'POST /api/listas/9/items',
          'PUT /api/listas/9/items/3',
          'DELETE /api/listas/9/items/3',
        ]);
        expect(agregar, {'usuarioId': 5, 'productoId': 3, 'cantidad': 2});
        expect(modificar, {'usuarioId': 5, 'cantidad': 9});
      });
    });

    test('el servidor puede responder 409 por nombre repetido y la app lo muestra', () async {
      await conApiFalsa((p) async => respuestaJson({'error': 'Ya tiene una lista llamada "Fiesta"'}, 409), () async {
        await expectLater(
          ApiService.crearLista(5, 'Fiesta'),
          throwsA(isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.mensaje, 'mensaje', contains('Ya tiene una lista'))),
        );
      });
    });
  });

  group('Valoración (HU-07)', () {
    test('valoracionLista envía el usuario y la ciudad opcional', () async {
      final consultas = <Map<String, String>>[];
      await conApiFalsa((p) async {
        expect(p.url.path, '/api/listas/9/valoracion');
        consultas.add(p.url.queryParameters);
        return respuestaJson(valoracionJson());
      }, () async {
        final v = await ApiService.valoracionLista(9, 5);
        await ApiService.valoracionLista(9, 5, ciudad: 'Cali');
        expect(consultas, [
          {'usuarioId': '5'},
          {'usuarioId': '5', 'ciudad': 'Cali'},
        ]);
        expect(v.resumen.ahorroCop, 2900.0);
        expect(v.supermercados.first.almacen, 'Ara');
      });
    });
  });

  group('Reportes y moderación (HU-08)', () {
    test('agregarPrecio envía la evidencia en base64 cuando existe', () async {
      Map<String, dynamic>? enviado;
      await conApiFalsa((p) async {
        enviado = cuerpoDe(p);
        return respuestaJson({'productoId': 7, 'reporteId': 30, 'productoNuevo': false, 'estado': 'pendiente'}, 201);
      }, () async {
        final r = await ApiService.agregarPrecio(7, _precio(evidencia: 'QUJD'));
        expect(enviado!['evidenciaBase64'], 'QUJD');
        expect(r.pendiente, isTrue);
        await ApiService.agregarPrecio(7, _precio());
        expect(enviado!.containsKey('evidenciaBase64'), isFalse);
      });
    });

    test('obtenerUsuario, misReportes y reportesPendientes', () async {
      final rutas = <String>[];
      final consultas = <Map<String, String>>[];
      await conApiFalsa((p) async {
        rutas.add(p.url.path);
        consultas.add(p.url.queryParameters);
        if (p.url.path == '/api/usuarios/5') return respuestaJson({'id': 5, 'nombre': 'Ana', 'email': 'a@x.co', 'rol': 'moderador'});
        return respuestaJson([reporteUsuarioJson()]);
      }, () async {
        expect((await ApiService.obtenerUsuario(5)).esModerador, isTrue);
        expect((await ApiService.misReportes(5)).single.estado, 'pendiente');
        await ApiService.misReportes(5, estado: 'rechazado');
        expect((await ApiService.reportesPendientes(5)).length, 1);
        expect(rutas, ['/api/usuarios/5', '/api/usuarios/5/reportes', '/api/usuarios/5/reportes', '/api/precios/pendientes']);
        expect(consultas[1], isEmpty);
        expect(consultas[2], {'estado': 'rechazado'});
        expect(consultas[3], {'usuarioId': '5'});
      });
    });

    test('validarReporte y rechazarReporte (con y sin motivo)', () async {
      final peticiones = <String>[];
      final cuerpos = <Map<String, dynamic>>[];
      await conApiFalsa((p) async {
        peticiones.add('${p.method} ${p.url.path}');
        cuerpos.add(cuerpoDe(p));
        return respuestaJson({'reporteId': 11, 'estado': 'ok'});
      }, () async {
        await ApiService.validarReporte(11, 5);
        await ApiService.rechazarReporte(11, 5, '  Foto ilegible ');
        await ApiService.rechazarReporte(11, 5, '   ');
        await ApiService.rechazarReporte(11, 5, null);
        expect(peticiones, ['POST /api/precios/11/validar', 'POST /api/precios/11/rechazar', 'POST /api/precios/11/rechazar', 'POST /api/precios/11/rechazar']);
        expect(cuerpos[0], {'usuarioId': 5});
        expect(cuerpos[1], {'usuarioId': 5, 'motivo': 'Foto ilegible'});
        expect(cuerpos[2], {'usuarioId': 5});
        expect(cuerpos[3], {'usuarioId': 5});
      });
    });

    test('un usuario sin permiso recibe 403 con el mensaje del servidor', () async {
      await conApiFalsa((p) async => respuestaJson({'error': 'Solo un moderador puede validar precios'}, 403), () async {
        await expectLater(
          ApiService.validarReporte(11, 5),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
        );
      });
    });

    test('urlEvidencia apunta al endpoint de evidencia del reporte', () {
      expect(ApiService.urlEvidencia(11), endsWith('/api/precios/11/evidencia'));
    });
  });
}

NuevoPrecio _precio({String? evidencia}) => NuevoPrecio(
      almacen: 'Ara',
      sede: 'Ara Kennedy',
      ciudad: 'Bogotá',
      precioCop: 4100,
      usuarioId: 5,
      evidenciaBase64: evidencia,
    );
