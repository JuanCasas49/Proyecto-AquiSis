import '../models/catalogo.dart';
import 'api_service.dart';

/// Listas para autocompletar los formularios. Si no hay conexión quedan vacías
/// (el formulario sigue funcionando, solo sin sugerencias).
class ListasFormulario {
  final List<String> marcas;
  final List<String> categorias;
  final List<String> almacenes;
  final List<String> ciudades;
  final List<SedeInfo> sedes;

  const ListasFormulario({
    this.marcas = const [],
    this.categorias = const [],
    this.almacenes = const [],
    this.ciudades = const [],
    this.sedes = const [],
  });

  static Future<ListasFormulario> cargar() async {
    try {
      final marcas = await ApiService.marcas();
      final categorias = await ApiService.categorias();
      final almacenes = await ApiService.establecimientos();
      final ciudades = await ApiService.ciudades();
      final sedes = await ApiService.sedes();
      return ListasFormulario(
        marcas: marcas.map((o) => o.nombre).toList(),
        categorias: categorias.map((o) => o.nombre).toList(),
        almacenes: almacenes.map((o) => o.nombre).toList(),
        ciudades: ciudades,
        sedes: sedes,
      );
    } catch (_) {
      return const ListasFormulario();
    }
  }
}
