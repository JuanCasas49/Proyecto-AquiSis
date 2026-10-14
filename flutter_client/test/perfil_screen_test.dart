import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/screens/perfil_screen.dart';
import 'package:flutter_client/services/sesion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/api_falsa.dart';
import 'helpers/formularios.dart';

/// Perfil: identificación por nombre y correo, y estado de la conexión con la base de datos.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Sesion.instancia.usuario = null;
  });

  const app = MaterialApp(home: PerfilScreen());
  final saludOk = respuestaJson({'estado': 'ok', 'baseDeDatos': 'conectada', 'productos': 3, 'reportes': 9, 'usuarios': 2});

  testWidgets('valida nombre y correo antes de enviar', (tester) async {
    pantallaAlta(tester);
    var posts = 0;
    await conApiFalsa((p) async {
      if (p.method == 'POST') posts++;
      return saludOk;
    }, () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingrese su nombre'), findsOneWidget);
      expect(find.text('Ingrese un correo válido'), findsOneWidget);

      await escribir(tester, 'Nombre', 'Ana Pérez');
      await escribir(tester, 'Correo electrónico', 'no-es-correo');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingrese un correo válido'), findsOneWidget);
      expect(posts, 0);
    });
  });

  testWidgets('al identificarse se guarda la sesión y se muestra el perfil', (tester) async {
    pantallaAlta(tester);
    Map<String, dynamic>? enviado;
    await conApiFalsa((p) async {
      if (p.method == 'POST' && p.url.path == '/api/usuarios') {
        enviado = jsonDecode(utf8.decode(p.bodyBytes)) as Map<String, dynamic>;
        return respuestaJson({'id': 3, 'nombre': 'Ana Pérez', 'email': 'ana@example.com'});
      }
      return saludOk;
    }, () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await escribir(tester, 'Nombre', '  Ana Pérez ');
      await escribir(tester, 'Correo electrónico', ' ana@example.com ');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(enviado, {'nombre': 'Ana Pérez', 'email': 'ana@example.com'}); // sin espacios sobrantes
      expect(Sesion.instancia.usuario!.id, 3);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
      expect(find.text('Cerrar sesión en este dispositivo'), findsOneWidget);
      expect(find.text('Continuar'), findsNothing);
    });
  });

  testWidgets('si el servidor rechaza el registro muestra el mensaje', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async {
      if (p.method == 'POST') return respuestaJson({'error': 'El correo no es válido'}, 400);
      return saludOk;
    }, () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await escribir(tester, 'Nombre', 'Ana Pérez');
      await escribir(tester, 'Correo electrónico', 'ana@x.co');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('El correo no es válido'), findsOneWidget);
      expect(Sesion.instancia.activa, isFalse);
    });
  });

  testWidgets('cerrar sesión vuelve al formulario de identificación', (tester) async {
    pantallaAlta(tester);
    await Sesion.instancia.guardar(Usuario(id: 3, nombre: 'Ana Pérez', email: 'ana@example.com'));
    await conApiFalsa((p) async => saludOk, () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión en este dispositivo'));
      await tester.pumpAndSettle();
      expect(Sesion.instancia.activa, isFalse);
      expect(find.text('Identifíquese'), findsOneWidget);
    });
  });

  testWidgets('muestra que la base de datos está conectada y cuántos datos hay', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((p) async => saludOk, () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.textContaining('Conectado a la base de datos en la nube'), findsOneWidget);
      expect(find.textContaining('3 productos'), findsOneWidget);
      expect(find.textContaining('9 reportes'), findsOneWidget);
    });
  });

  testWidgets('si no hay conexión lo indica y permite comprobar de nuevo', (tester) async {
    pantallaAlta(tester);
    var llamadas = 0;
    await conApiFalsa((p) async {
      llamadas++;
      if (llamadas == 1) throw Exception('sin red');
      return saludOk;
    }, () async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo conectar'), findsOneWidget);

      await tester.tap(find.text('Comprobar de nuevo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Conectado a la base de datos en la nube'), findsOneWidget);
    });
  });
}
