import 'package:flutter_client/models/catalogo.dart';
import 'package:flutter_client/services/sesion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Usuario identificado en el dispositivo (guardado localmente).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Sesion.instancia.usuario = null;
  });

  test('sin datos guardados no hay sesión', () async {
    await Sesion.instancia.cargar();
    expect(Sesion.instancia.activa, isFalse);
    expect(Sesion.instancia.usuario, isNull);
  });

  test('guardar abre la sesión, notifica y persiste', () async {
    var avisos = 0;
    void oyente() => avisos++;
    Sesion.instancia.addListener(oyente);
    addTearDown(() => Sesion.instancia.removeListener(oyente));

    await Sesion.instancia.guardar(Usuario(id: 5, nombre: 'Ana', email: 'ana@example.com'));

    expect(Sesion.instancia.activa, isTrue);
    expect(Sesion.instancia.usuario!.nombre, 'Ana');
    expect(avisos, greaterThan(0));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('usuario_id'), 5);
    expect(prefs.getString('usuario_email'), 'ana@example.com');
  });

  test('cargar recupera la sesión guardada (como al reabrir la app)', () async {
    await Sesion.instancia.guardar(Usuario(id: 8, nombre: 'Luis', email: 'luis@example.com'));
    Sesion.instancia.usuario = null; // simula app cerrada
    await Sesion.instancia.cargar();
    expect(Sesion.instancia.usuario!.id, 8);
    expect(Sesion.instancia.usuario!.email, 'luis@example.com');
  });

  test('cerrar elimina la sesión y los datos guardados', () async {
    await Sesion.instancia.guardar(Usuario(id: 8, nombre: 'Luis', email: 'luis@example.com'));
    await Sesion.instancia.cerrar();
    expect(Sesion.instancia.activa, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('usuario_id'), isNull);
    await Sesion.instancia.cargar();
    expect(Sesion.instancia.activa, isFalse);
  });
}
