import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum DotStyle { filled, hollow, half, ringed, dashed }

/// Punto de tinta. Lleno = mi postura; hueco = lo comprendido sin ocuparlo.
class InkDot extends StatelessWidget {
  const InkDot({super.key, this.style = DotStyle.filled, this.size = 14, this.color, this.fill});

  final DotStyle style;
  final double size;
  final Color? color;

  /// Proporción de relleno (0…1) para la ficha de la balanza.
  final double? fill;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.enves.ink;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DotPainter(style, c, fill, context.enves.paper)),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.style, this.color, this.fill, this.background);
  final DotStyle style;
  final Color color;
  final double? fill;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = (r * 0.28).clamp(1.5, 4.0).toDouble();
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final solid = Paint()..color = color;
    switch (style) {
      case DotStyle.filled:
        canvas.drawCircle(center, r, solid);
      case DotStyle.hollow:
        canvas.drawCircle(center, r - stroke / 2, line);
        if (fill != null && fill! > 0) {
          canvas.drawCircle(center, (r - stroke) * fill!.clamp(0.0, 1.0), solid);
        }
      case DotStyle.half:
        canvas.drawCircle(center, r - stroke / 2, line);
        canvas.drawArc(Rect.fromCircle(center: center, radius: r - stroke / 2), 1.5708, 3.1416, true, solid);
      case DotStyle.ringed:
        canvas.drawCircle(center, r - stroke / 2, line);
        canvas.drawCircle(center, r * 0.55, solid);
      case DotStyle.dashed:
        const segments = 10;
        for (var i = 0; i < segments; i++) {
          final start = i * 6.2832 / segments;
          canvas.drawArc(Rect.fromCircle(center: center, radius: r - stroke / 2), start, 6.2832 / segments / 2, false, line);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) =>
      old.style != style || old.color != color || old.fill != fill || old.background != background;
}

/// El cruce anclado: ●━┃━○
class CrossGlyph extends StatelessWidget {
  const CrossGlyph({super.key, this.width = 56, this.height = 20});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _CrossPainter(e.ink, e.saffron)),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.ink, this.saffron);
  final Color ink;
  final Color saffron;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final r = h * 0.22;
    final cy = h / 2;
    final ink1 = Paint()
      ..color = ink
      ..strokeWidth = h * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(r, cy), Offset(size.width - r, cy), ink1);
    canvas.drawLine(Offset(size.width / 2, h * 0.05), Offset(size.width / 2, h * 0.95), ink1..strokeWidth = h * 0.1);
    canvas.drawCircle(Offset(r, cy), r, Paint()..color = ink);
    canvas.drawCircle(
      Offset(size.width - r, cy),
      r * 0.8,
      Paint()
        ..color = saffron
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.45,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.ink != ink || old.saffron != saffron;
}

/// Iconos neutrales de Mantener, Matizar y Revisar. Mismo trazo para los tres.
enum TensionGlyphKind { mantener, matizar, revisar }

class TensionGlyph extends StatelessWidget {
  const TensionGlyph(this.kind, {super.key, this.size = 28});
  final TensionGlyphKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _TensionPainter(kind, context.enves.ink)),
        ),
      );
}

class _TensionPainter extends CustomPainter {
  _TensionPainter(this.kind, this.color);
  final TensionGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    switch (kind) {
      case TensionGlyphKind.mantener:
        canvas.drawLine(Offset(w * 0.1, h * 0.62), Offset(w * 0.9, h * 0.62), p);
        canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.13, Paint()..color = color);
      case TensionGlyphKind.matizar:
        canvas.drawLine(Offset(w * 0.1, h * 0.5), Offset(w * 0.45, h * 0.5), p);
        canvas.drawLine(Offset(w * 0.45, h * 0.5), Offset(w * 0.9, h * 0.22), p);
        canvas.drawLine(Offset(w * 0.45, h * 0.5), Offset(w * 0.9, h * 0.78), p);
      case TensionGlyphKind.revisar:
        final path = Path()
          ..moveTo(w * 0.1, h * 0.7)
          ..lineTo(w * 0.45, h * 0.7)
          ..quadraticBezierTo(w * 0.8, h * 0.7, w * 0.85, h * 0.2);
        canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _TensionPainter old) => old.kind != kind || old.color != color;
}
