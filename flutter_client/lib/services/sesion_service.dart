import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalogo.dart';

/// Usuario identificado en este dispositivo (guardado localmente).
class Sesion extends ChangeNotifier {
  Sesion._();
  static final Sesion instancia = Sesion._();

  static const _kId = 'usuario_id';
  static const _kNombre = 'usuario_nombre';
  static const _kEmail = 'usuario_email';

  Usuario? usuario;

  bool get activa => usuario != null;

  Future<void> cargar() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getInt(_kId);
    final nombre = p.getString(_kNombre);
    final email = p.getString(_kEmail);
    if (id != null && nombre != null && email != null) {
      usuario = Usuario(id: id, nombre: nombre, email: email);
    }
    notifyListeners();
  }

  Future<void> guardar(Usuario u) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kId, u.id);
    await p.setString(_kNombre, u.nombre);
    await p.setString(_kEmail, u.email);
    usuario = u;
    notifyListeners();
  }

  Future<void> cerrar() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kId);
    await p.remove(_kNombre);
    await p.remove(_kEmail);
    usuario = null;
    notifyListeners();
  }
}
