import 'dart:convert';

import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/api_falsa.dart';

/// Comunicación app ↔ API: rutas, parámetros, cuerpos JSON y manejo de errores.
void main() {
  group('Catálogo', () {
    test('buscarProductos envía todos los filtros combinados y lee la página', () async {
      late http.Request recibida;
      await conApiFalsa((p) async {
        recibida = p;
        return respuestaJson(paginaJson([productoJson(), productoJson(id: 2, nombre: 'Arroz')], total: 35));
      }, () async {
        final filtros = FiltrosProducto(
          q: ' leche ',
          categoriaId: 2,
          marcaId: 3,
          establecimientoId: 4,
          ciudad: 'Bogotá',
          precioMin: 1000,
          precioMax: 5000,
          orden: 'precio_asc',
        );
        final pagina = await ApiService.buscarProductos(filtros, pagina: 2, tamano: 10);

        expect(recibida.method, 'GET');
        expect(recibida.url.path, '/api/productos');
        final q = recibida.url.queryParameters;
        expect(q['q'], 'leche');
        expect(q['categoriaId'], '2');
        expect(q['marcaId'], '3');
        expect(q['establecimientoId'], '4');
        expect(q['ciudad'], 'Bogotá');
        expect(q['precioMin'], '1000.0');
        expect(q['precioMax'], '5000.0');
        expect(q['orden'], 'precio_asc');
        expect(q['pagina'], '2');
        expect(q['tamano'], '10');
        expect(pagina.total, 35);
        expect(pagina.items.length, 2);
        expect(pagina.items.first.precioMin, 3900.0);
      });
    });

    test('sin filtros no envía parámetros de filtro', () async {
      late Map<String, String> q;
      await conApiFalsa((p) async {
        q = p.url.queryParameters;
        return respuestaJson(paginaJson([]));
      }, () async {
        await ApiService.buscarProductos(FiltrosProducto());
        expect(q.keys.toSet(), {'pagina', 'tamano', 'orden'});
      });
    });

    test('obtenerProductos (compatibilidad) devuelve la primera página', () async {
      await conApiFalsa((p) async => respuestaJson(paginaJson([productoJson()])), () async {
        final lista = await ApiService.obtenerProductos();
        expect(lista.single.nombre, 'Leche entera');
      });
    });

    test('obtenerDetalle, comparación e historial usan sus rutas', () async {
      final rutas = <String>[];
      final consultas = <Map<String, String>>[];
      await conApiFalsa((p) async {
        rutas.add(p.url.path);
        consultas.add(p.url.queryParameters);
        if (p.url.path.endsWith('/comparacion')) return respuestaJson(comparacionJson());
        if (p.url.path.endsWith('/historial')) return respuestaJson(historialBasico());
        return respuestaJson(comparacionJson()['producto']);
      }, () async {
        final d = await ApiService.obtenerDetalle(7);
        final c = await ApiService.obtenerComparacion(7, ciudad: 'Bogotá', unidades: 3);
        final h = await ApiService.obtenerHistorial(7);
        expect(rutas, ['/api/productos/7', '/api/productos/7/comparacion', '/api/productos/7/historial']);
        expect(consultas[1], {'unidades': '3', 'ciudad': 'Bogotá'});
        expect(d.nombre, 'Leche entera');
        expect(c.precios.first.esMasBarato, isTrue);
        expect(c.resumen!.ahorroMaximoCop, 1100.0);
        expect(h.first.variacionCop, 600.0);
        expect(h.length, 3);
      });
    });

    test('urlFoto apunta al endpoint de la fotografía', () {
      expect(ApiService.urlFoto(5), endsWith('/api/productos/5/foto'));
    });
  });

  group('Registro', () {
    test('registrarProducto envía el JSON esperado y lee el resultado', () async {
      late http.Request recibida;
      await conApiFalsa((p) async {
        recibida = p;
        return respuestaJson({'productoId': 9, 'reporteId': 21, 'productoNuevo': true}, 201);
      }, () async {
        final r = await ApiService.registrarProducto(RegistroProducto(
          nombre: 'Leche entera',
          descripcion: '',
          marca: 'Alquería',
          categoria: 'Lácteos y huevos',
          presentacion: 'Bolsa',
          cantidad: 1100,
          unidad: 'ml',
          precioCop: 4500,
          almacen: 'Éxito',
          sede: 'Éxito Chapinero',
          ciudad: 'Bogotá',
          fecha: '2026-10-12',
          usuarioId: 5,
        ));
        expect(recibida.method, 'POST');
        expect(recibida.url.path, '/api/productos');
        expect(recibida.headers['content-type'], startsWith('application/json'));
        final cuerpo = jsonDecode(utf8.decode(recibida.bodyBytes)) as Map<String, dynamic>;
        expect(cuerpo['nombre'], 'Leche entera');
        expect(cuerpo['marca'], 'Alquería');
        expect(cuerpo['cantidad'], 1100);
        expect(cuerpo['unidad'], 'ml');
        expect(cuerpo['precioCop'], 4500);
        expect(cuerpo['usuarioId'], 5);
        expect(cuerpo['fecha'], '2026-10-12');
        expect(cuerpo.containsKey('descripcion'), isFalse); // vacío: no se envía
        expect(cuerpo.containsKey('fotoBase64'), isFalse); // sin foto: no se envía
        expect(r.productoId, 9);
        expect(r.productoNuevo, isTrue);
      });
    });

    test('agregarPrecio publica en /precios del producto', () async {
      late http.Request recibida;
      await conApiFalsa((p) async {
        recibida = p;
        return respuestaJson({'productoId': 7, 'reporteId': 30, 'productoNuevo': false}, 201);
      }, () async {
        final r = await ApiService.agregarPrecio(
            7, NuevoPrecio(almacen: 'Ara', sede: 'Ara Kennedy', ciudad: 'Bogotá', precioCop: 4100, usuarioId: 5));
        expect(recibida.url.path, '/api/productos/7/precios');
        expect(r.reporteId, 30);
        expect(r.productoNuevo, isFalse);
      });
    });

    test('registrarUsuario devuelve el usuario', () async {
      await conApiFalsa((p) async {
        expect(p.url.path, '/api/usuarios');
        final cuerpo = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        expect(cuerpo, {'nombre': 'Ana', 'email': 'ana@example.com'});
        return respuestaJson({'id': 3, 'nombre': 'Ana', 'email': 'ana@example.com'});
      }, () async {
        final u = await ApiService.registrarUsuario('Ana', 'ana@example.com');
        expect(u.id, 3);
      });
    });
  });

  group('Listas de apoyo y estado', () {
    test('categorías, marcas, almacenes, ciudades, sedes y salud', () async {
      await conApiFalsa((p) async {
        switch (p.url.path) {
          case '/api/categorias':
          case '/api/marcas':
          case '/api/establecimientos':
            return respuestaJson([{'id': 1, 'nombre': 'X'}]);
          case '/api/ciudades':
            return respuestaJson(['Bogotá', 'Cali']);
          case '/api/sedes':
            return respuestaJson([{'id': 1, 'establecimientoId': 1, 'almacen': 'D1', 'nombre': 'D1 Suba', 'ciudad': 'Bogotá', 'direccion': null}]);
          default:
            return respuestaJson({'estado': 'ok', 'baseDeDatos': 'conectada', 'productos': 3, 'reportes': 9, 'usuarios': 1});
        }
      }, () async {
        expect((await ApiService.categorias()).single.nombre, 'X');
        expect((await ApiService.marcas()).length, 1);
        expect((await ApiService.establecimientos()).length, 1);
        expect(await ApiService.ciudades(), ['Bogotá', 'Cali']);
        expect((await ApiService.sedes()).single.nombre, 'D1 Suba');
        final salud = await ApiService.salud();
        expect(salud['estado'], 'ok');
        expect(salud['productos'], 3);
      });
    });
  });

  group('Errores', () {
    test('el mensaje de error del servidor llega a la app con su código', () async {
      await conApiFalsa((p) async => respuestaJson({'error': 'El precio debe estar entre \$1 y \$100.000.000 COP'}, 400), () async {
        await expectLater(
          ApiService.agregarPrecio(7, NuevoPrecio(almacen: 'A', sede: 'B', ciudad: 'C', precioCop: 0, usuarioId: 1)),
          throwsA(isA<ApiException>()
              .having((e) => e.mensaje, 'mensaje', contains('El precio debe estar entre'))
              .having((e) => e.status, 'status', 400)),
        );
      });
    });

    test('una respuesta que no es JSON genera un mensaje genérico con el código', () async {
      await conApiFalsa((p) async => http.Response('Internal Server Error', 500), () async {
        await expectLater(
          ApiService.categorias(),
          throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', 'Error 500 del servidor')),
        );
      });
    });

    test('404 de producto inexistente', () async {
      await conApiFalsa((p) async => respuestaJson({'error': 'Producto no encontrado'}, 404), () async {
        await expectLater(
          ApiService.obtenerDetalle(999),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
        );
      });
    });

    test('sin conexión se informa al usuario y se indica la URL del servidor', () async {
      await conApiFalsa((p) async => throw Exception('sin red'), () async {
        await expectLater(
          ApiService.categorias(),
          throwsA(isA<ApiException>()
              .having((e) => e.mensaje, 'mensaje', allOf(contains('No se pudo conectar'), contains(ApiService.baseUrl)))),
        );
      });
    });
  });
}
