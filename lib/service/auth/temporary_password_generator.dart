import 'dart:math';

/// Generates the temporary password of a new administrator.
///
/// Uses [Random.secure]. The result is never logged or stored: the creator
/// sees it once and hands it over, and the new administrator must replace it
/// on first sign-in.
abstract final class TemporaryPasswordGenerator {
  static const minLength = 12;

  // Without look-alike characters (0/O, 1/l/I) so it can be read aloud.
  static const _lower = 'abcdefghijkmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _digits = '23456789';
  static const _symbols = '!@#\$%&*?';

  /// At least [minLength] characters, with a lowercase, uppercase, digit and
  /// symbol.
  static String generate({Random? random, int length = 16}) {
    final rng = random ?? Random.secure();
    final size = length < minLength ? minLength : length;
    const all = _lower + _upper + _digits + _symbols;
    final chars = <String>[
      _pick(_lower, rng),
      _pick(_upper, rng),
      _pick(_digits, rng),
      _pick(_symbols, rng),
      for (var i = 4; i < size; i++) _pick(all, rng),
    ]..shuffle(rng);
    return chars.join();
  }

  static String _pick(String source, Random rng) =>
      source[rng.nextInt(source.length)];
}
