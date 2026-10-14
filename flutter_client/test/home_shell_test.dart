import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/screens/home_shell.dart';
import 'package:flutter_client/services/sesion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/api_falsa.dart';
import 'helpers/formularios.dart';

/// Flujo completo de la app: navegación entre pestañas, registro y apertura del detalle.
void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Sesion.instancia.usuario = null;
  });

  const app = MaterialApp(home: HomeShell());

  Manejador servidor({List<Map<String, dynamic>>? posts}) => (p) async {
        if (p.method == 'POST' && p.url.path == '/api/productos') {
          posts?.add(jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>);
          return respuestaJson({'productoId': 7, 'reporteId': 50, 'productoNuevo': true}, 201);
        }
        if (p.url.path == '/api/productos/7/comparacion') return respuestaJson(comparacionJson());
        if (p.url.path == '/api/productos/7/historial') return respuestaJson(historialBasico());
        if (p.url.path == '/api/salud') return respuestaJson({'estado': 'ok', 'baseDeDatos': 'conectada', 'productos': 1, 'reportes': 1, 'usuarios': 1});
        final lista = listasVacias(p);
        if (lista != null) return lista;
        return respuestaJson(paginaJson([productoJson(id: 7)]));
      };

  testWidgets('la barra inferior navega entre Catálogo, Registrar y Perfil', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(servidor(), () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Catálogo'), findsOneWidget);
      expect(find.text('Registrar'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Precios Colombia'), findsOneWidget);
      expect(find.text('Leche entera'), findsOneWidget);

      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar precio'), findsOneWidget);

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Conexión'), findsOneWidget);
    });
  });

  testWidgets('desde Registrar sin sesión, "Ir a Perfil" cambia de pestaña', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(servidor(), () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ir a Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Conexión'), findsOneWidget);
    });
  });

  testWidgets('registrar un producto vuelve al catálogo y abre su detalle con el comparador', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));
    final posts = <Map<String, dynamic>>[];
    await conApiFalsa(servidor(posts: posts), () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      await llenarRegistro(tester);
      await tester.tap(find.text('Guardar en la nube'));
      await tester.pumpAndSettle();

      expect(posts.length, 1);
      expect(posts.single['usuarioId'], 5);
      expect(find.text('Comparador de precios'), findsOneWidget); // detalle del producto recién registrado
      expect(find.text('Opción más económica'), findsOneWidget);
    });
  });
}
