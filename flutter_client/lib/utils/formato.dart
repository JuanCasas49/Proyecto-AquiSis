import 'package:intl/intl.dart';

final NumberFormat _formatoCop = NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
);

/// 4500 -> "$4.500"
String cop(num valor) => _formatoCop.format(valor);

/// "+$600"
String copConSigno(num valor) => '${valor >= 0 ? '+' : '-'}${cop(valor.abs())}';

/// 1100, "ml" -> "1100 ml";  0.5, "kg" -> "0,5 kg"
String cantidadTexto(double cantidad, String unidad) {
  final numero = cantidad == cantidad.roundToDouble()
      ? cantidad.toInt().toString()
      : NumberFormat('#,##0.###', 'es_CO').format(cantidad);
  return '$numero $unidad';
}

/// "2026-10-08" -> "8 oct 2026"
String fechaCorta(String iso) {
  final f = DateTime.tryParse(iso);
  if (f == null) return iso;
  return DateFormat('d MMM y', 'es_CO').format(f);
}

String fechaIso(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

/// 0 -> "hoy", 1 -> "ayer", 12 -> "hace 12 días", 75 -> "hace 2 meses"
String antiguedad(int dias) {
  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'ayer';
  if (dias < 60) return 'hace $dias días';
  final meses = (dias / 30).floor();
  if (meses < 24) return 'hace $meses meses';
  return 'hace ${(dias / 365).floor()} años';
}

String porcentaje(double? v) {
  if (v == null) return '';
  return '${NumberFormat('0.#', 'es_CO').format(v)} %';
}
