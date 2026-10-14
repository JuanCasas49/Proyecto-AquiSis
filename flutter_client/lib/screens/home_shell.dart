import 'package:flutter/material.dart';

import 'catalogo_screen.dart';
import 'detalle_screen.dart';
import 'perfil_screen.dart';
import 'registro_screen.dart';

/// Navegación principal: Catálogo · Registrar · Perfil.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;
  int _recarga = 0;

  void _alRegistrar(int productoId) {
    setState(() {
      _recarga++;
      _indice = 0;
    });
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetalleScreen(productoId: productoId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          CatalogoScreen(recarga: _recarga),
          RegistroScreen(
            onRegistrado: _alRegistrar,
            irAPerfil: () => setState(() => _indice = 2),
          ),
          const PerfilScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Catálogo'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Registrar'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}
