import 'dart:math' as math;

/// Tokens de color de Papel y tinta. Es el único archivo del proyecto con
/// valores de color; los widgets los obtienen del tema.
///
/// Se guardan como enteros ARGB para poder verificar el contraste en pruebas
/// sin depender de la API de `Color`.
class EnvesPalette {
  const EnvesPalette({
    required this.paper,
    required this.reverse,
    required this.ink,
    required this.inkSecondary,
    required this.graphite,
    required this.saffron,
    required this.saffronText,
    required this.divider,
    required this.focus,
    required this.technicalError,
  });

  final int paper;
  final int reverse;
  final int ink;
  final int inkSecondary;
  final int graphite;
  final int saffron;
  final int saffronText;
  final int divider;
  final int focus;
  final int technicalError;

  static const light = EnvesPalette(
    paper: 0xFFF5F0E6,
    reverse: 0xFFE4E7E1,
    ink: 0xFF1F2433,
    inkSecondary: 0xFF4A4F5C,
    graphite: 0xFF6F747F,
    saffron: 0xFFA06A0E,
    saffronText: 0xFF7A4F00,
    divider: 0xFFCFC6B6,
    focus: 0xFF1F2433,
    technicalError: 0xFF8C3B2E,
  );

  static const dark = EnvesPalette(
    paper: 0xFF16181F,
    reverse: 0xFF1E2327,
    ink: 0xFFECE5D8,
    inkSecondary: 0xFFB9B3A8,
    graphite: 0xFF8A8F99,
    saffron: 0xFFE0A93F,
    saffronText: 0xFFE0A93F,
    divider: 0xFF2E323B,
    focus: 0xFFECE5D8,
    technicalError: 0xFFE39A88,
  );
}

/// Contraste WCAG entre dos colores ARGB.
double contrastRatio(int a, int b) {
  double channel(int v) {
    final c = v / 255.0;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  double luminance(int argb) {
    final r = channel((argb >> 16) & 0xFF);
    final g = channel((argb >> 8) & 0xFF);
    final b = channel(argb & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  final la = luminance(a);
  final lb = luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
