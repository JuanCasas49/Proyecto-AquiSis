import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/sesion_service.dart';

/// Identificación ligera (nombre + correo) y estado de la conexión con la base de datos.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  bool _enviando = false;
  bool _probando = false;
  String? _estadoConexion;
  bool _conexionOk = false;

  @override
  void initState() {
    super.initState();
    Sesion.instancia.addListener(_refrescar);
    _probarConexion();
  }

  @override
  void dispose() {
    Sesion.instancia.removeListener(_refrescar);
    _nombre.dispose();
    _email.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  Future<void> _probarConexion() async {
    setState(() => _probando = true);
    try {
      final s = await ApiService.salud();
      if (!mounted) return;
      setState(() {
        _conexionOk = true;
        _estadoConexion =
            'Conectado a la base de datos en la nube · ${s['productos']} productos, ${s['reportes']} reportes';
        _probando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conexionOk = false;
        _estadoConexion = e is ApiException ? e.mensaje : 'Sin conexión con el servidor';
        _probando = false;
      });
    }
  }

  Future<void> _entrar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    try {
      final usuario =
          await ApiService.registrarUsuario(_nombre.text.trim(), _email.text.trim());
      await Sesion.instancia.guardar(usuario);
      if (!mounted) return;
      setState(() => _enviando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.mensaje : 'No se pudo registrar el usuario')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final usuario = Sesion.instancia.usuario;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: tema.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (usuario != null) ...[
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(usuario.nombre.isNotEmpty
                      ? usuario.nombre[0].toUpperCase()
                      : '?'),
                ),
                title: Text(usuario.nombre),
                subtitle: Text(usuario.email),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Sesion.instancia.cerrar(),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión en este dispositivo'),
            ),
          ] else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Identifíquese', style: tema.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                      'Sus reportes de precio quedarán asociados a su nombre. Si ya se registró antes con el mismo correo, se recupera su usuario.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Ingrese su nombre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder()),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                          ? null
                          : 'Ingrese un correo válido';
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _enviando ? null : _entrar,
                      icon: _enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          Text('Conexión', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _probando
                            ? Icons.sync
                            : (_conexionOk ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
                        color: _probando
                            ? tema.colorScheme.outline
                            : (_conexionOk ? Colors.green : tema.colorScheme.error),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_probando
                              ? 'Comprobando…'
                              : (_estadoConexion ?? 'Sin comprobar'))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Servidor: ${ApiService.baseUrl}', style: tema.textTheme.bodySmall),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: _probando ? null : _probarConexion,
                        child: const Text('Comprobar de nuevo')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
