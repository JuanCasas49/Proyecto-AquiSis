import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> escribir(WidgetTester tester, String etiqueta, String texto) async {
  await tester.enterText(find.widgetWithText(TextFormField, etiqueta), texto);
}

/// Llena el formulario de registro de producto con datos válidos.
Future<void> llenarRegistro(WidgetTester tester) async {
  await escribir(tester, 'Nombre del producto', 'Leche entera');
  await escribir(tester, 'Marca', 'Alquería');
  await escribir(tester, 'Categoría', 'Lácteos y huevos');
  await escribir(tester, 'Presentación (botella, bolsa, caja...)', 'Bolsa');
  await escribir(tester, 'Cantidad', '1100');
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ml').last);
  await tester.pumpAndSettle();
  await escribir(tester, 'Almacén (Éxito, D1, Ara...)', 'Éxito');
  await escribir(tester, 'Sede (ej. Éxito Chapinero)', 'Éxito Chapinero');
  await escribir(tester, 'Ciudad', 'Bogotá');
  await escribir(tester, 'Precio en COP', '4500');
  await tester.pump();
}
