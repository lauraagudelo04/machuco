/// Formateadores de moneda de uso general, sin atarse a ninguna
/// funcionalidad concreta. Cualquier vista o controller del proyecto puede
/// importar este archivo en vez de reimplementar su propio formateador.
library;

/// Formatea un monto entero en pesos colombianos, p. ej. `123000` ->
/// `$123.000`.
String formatCurrencyAmount(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final position = digits.length - i;
    buffer.write(digits[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write('.');
    }
  }
  return '${amount < 0 ? '-' : ''}\$$buffer';
}
