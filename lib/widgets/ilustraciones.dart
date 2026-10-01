import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'hilo_vivo.dart';

/// Ilustración editorial de línea: tinta, grafito y un único acento azafrán.
/// Sin fotografías, sin personajes caricaturescos, sin iconos agrandados.

Paint tinta(Color c, [double w = 1.8]) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Línea con temblor de mano.
void trazo(Canvas canvas, Offset a, Offset b, Paint p, {int seed = 0, double bend = 0}) {
  canvas.drawPath(inkPath(a, b, seed: seed, bend: bend, wobble: 0.22), p);
}

/// Partes de una figura humana, en el orden en que se dibujan.
const figuraPartes = 10;

/// Figura humana de línea. [pies] es el punto de apoyo y [alto] la estatura.
///
/// [rehecha] indica cuántas partes (de [figuraPartes]) están vueltas a dibujar
/// por otra mano: doble trazo fino. Siempre humana: nunca circuitos.
void figura(
  Canvas canvas,
  Offset pies,
  double alto,
  Paint p, {
  int rehecha = 0,
  double opacidad = 1,
  int seed = 0,
  bool brazoArriba = false,
}) {
  final c = p.color.withValues(alpha: p.color.a * opacidad);
  final orig = tinta(c, p.strokeWidth);
  final doble = tinta(c, math.max(0.9, p.strokeWidth * 0.42));
  final x = pies.dx;
  final top = pies.dy - alto;
  final head = alto * 0.11;
  final cabeza = Offset(x, top + head);
  final cuello = Offset(x, top + head * 2.2);
  final cadera = Offset(x, top + alto * 0.58);
  final hombroL = Offset(x - alto * 0.12, top + alto * 0.3);
  final hombroR = Offset(x + alto * 0.12, top + alto * 0.3);
  final manoL = Offset(x - alto * 0.2, top + alto * 0.55);
  final manoR = brazoArriba ? Offset(x + alto * 0.24, top + alto * 0.16) : Offset(x + alto * 0.2, top + alto * 0.55);
  final codoL = Offset.lerp(hombroL, manoL, 0.5)! + Offset(-alto * 0.03, 0);
  final codoR = Offset.lerp(hombroR, manoR, 0.5)! + Offset(alto * 0.03, 0);
  final pieL = Offset(x - alto * 0.11, pies.dy);
  final pieR = Offset(x + alto * 0.11, pies.dy);
  final rodL = Offset.lerp(cadera, pieL, 0.5)!;
  final rodR = Offset.lerp(cadera, pieR, 0.5)!;

  void parte(int i, void Function(Paint p) draw) {
    if (i < rehecha) {
      // Vuelta a dibujar: dos trazos finos que casi coinciden.
      canvas.save();
      final d = math.max(1.2, p.strokeWidth * 0.75);
      canvas.translate(-d, -d * 0.5);
      draw(doble);
      canvas.translate(d * 2, d);
      draw(doble);
      canvas.restore();
    } else {
      draw(orig);
    }
  }

  parte(0, (q) => canvas.drawCircle(cabeza, head, q));
  parte(1, (q) => trazo(canvas, Offset(x, top + head * 2), cuello, q, seed: seed));
  parte(2, (q) {
    trazo(canvas, hombroL, hombroR, q, seed: seed + 1);
    trazo(canvas, cuello, cadera, q, seed: seed + 2, bend: alto * 0.01);
  });
  parte(3, (q) => trazo(canvas, hombroL, codoL, q, seed: seed + 3));
  parte(4, (q) => trazo(canvas, codoL, manoL, q, seed: seed + 4));
  parte(5, (q) => trazo(canvas, hombroR, codoR, q, seed: seed + 5));
  parte(6, (q) => trazo(canvas, codoR, manoR, q, seed: seed + 6));
  parte(7, (q) => trazo(canvas, cadera, rodL, q, seed: seed + 7));
  parte(8, (q) {
    trazo(canvas, rodL, pieL, q, seed: seed + 8);
    trazo(canvas, cadera, rodR, q, seed: seed + 9);
  });
  parte(9, (q) => trazo(canvas, rodR, pieR, q, seed: seed + 10));
}

/// Auto de perfil, en línea.
void auto(Canvas canvas, Offset base, double w, Paint p) {
  final h = w * 0.32;
  final body = Path()
    ..moveTo(base.dx, base.dy - h * 0.3)
    ..lineTo(base.dx + w * 0.18, base.dy - h * 0.38)
    ..lineTo(base.dx + w * 0.32, base.dy - h * 0.95)
    ..lineTo(base.dx + w * 0.7, base.dy - h * 0.95)
    ..lineTo(base.dx + w * 0.86, base.dy - h * 0.42)
    ..lineTo(base.dx + w, base.dy - h * 0.36)
    ..lineTo(base.dx + w, base.dy - h * 0.05)
    ..lineTo(base.dx, base.dy - h * 0.05)
    ..close();
  canvas.drawPath(body, p);
  canvas.drawLine(Offset(base.dx + w * 0.51, base.dy - h * 0.95), Offset(base.dx + w * 0.51, base.dy - h * 0.4), p);
  final wheel = tinta(p.color, p.strokeWidth);
  canvas.drawCircle(Offset(base.dx + w * 0.22, base.dy), h * 0.2, Paint()..color = p.color);
  canvas.drawCircle(Offset(base.dx + w * 0.78, base.dy), h * 0.2, Paint()..color = p.color);
  canvas.drawCircle(Offset(base.dx + w * 0.22, base.dy), h * 0.2, wheel);
}

// ---------------------------------------------------------------- viñetas
/// Viñeta pequeña de una experiencia, para el inicio y el catálogo.
class Vineta extends StatelessWidget {
  const Vineta(this.experienceId, {super.key, this.width = 132, this.height = 84});
  final String experienceId;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, height),
        painter: _VinetaPainter(experienceId, e.ink, e.graphite, e.saffron, e.paper),
      ),
    );
  }
}

class _VinetaPainter extends CustomPainter {
  _VinetaPainter(this.id, this.ink, this.graphite, this.saffron, this.paper);
  final String id;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final p = tinta(ink, 1.6);
    final g = tinta(graphite, 1.2);
    final a = tinta(saffron, 1.8);
    final suelo = h * 0.86;
    switch (id.split('_').first) {
      case 'e1':
        trazo(canvas, Offset(0, suelo), Offset(w, suelo), g, seed: 1);
        for (var x = 6.0; x < w; x += 16) {
          canvas.drawLine(Offset(x, h * 0.94), Offset(x + 7, h * 0.94), g);
        }
        auto(canvas, Offset(w * 0.08, suelo - 4), w * 0.5, p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.27, suelo - w * 0.17, 6, 10), const Radius.circular(1.5)),
          a,
        );
        figura(canvas, Offset(w * 0.82, suelo), h * 0.42, tinta(graphite, 1.3), seed: 2);
      case 'e2':
        figura(canvas, Offset(w * 0.2, suelo), h * 0.72, p, seed: 3);
        figura(canvas, Offset(w * 0.62, suelo), h * 0.46, p, seed: 4, brazoArriba: true);
        paintHilo(canvas, from: Offset(w * 0.27, h * 0.48), to: Offset(w * 0.56, h * 0.62), color: saffron, width: 1.6, seed: 2, bend: -6);
        canvas.drawRect(Rect.fromLTWH(w * 0.8, h * 0.3, w * 0.16, h * 0.22), g);
        canvas.drawLine(Offset(w * 0.8, h * 0.37), Offset(w * 0.96, h * 0.37), g);
      case 'e3':
        trazo(canvas, Offset(0, suelo), Offset(w, suelo), g, seed: 1);
        auto(canvas, Offset(w * 0.05, suelo - 4), w * 0.55, p);
        final scratch = Path()..moveTo(w * 0.36, suelo - 18);
        for (var i = 1; i <= 5; i++) {
          scratch.lineTo(w * 0.36 + i * 5, suelo - 18 + (i.isOdd ? -4 : 2));
        }
        canvas.drawPath(scratch, a);
        figura(canvas, Offset(w * 0.84, suelo), h * 0.62, p, seed: 5);
      case 'e4':
        figura(canvas, Offset(w * 0.22, suelo), h * 0.62, p, seed: 6);
        figura(canvas, Offset(w * 0.7, suelo), h * 0.62, p, seed: 7);
        final bubble = Path()
          ..moveTo(w * 0.32, h * 0.2)
          ..quadraticBezierTo(w * 0.45, h * 0.02, w * 0.58, h * 0.2)
          ..quadraticBezierTo(w * 0.45, h * 0.34, w * 0.36, h * 0.28)
          ..lineTo(w * 0.31, h * 0.34)
          ..close();
        canvas.drawPath(bubble, g);
        final wave = Path()..moveTo(w * 0.38, h * 0.19);
        for (var i = 1; i <= 6; i++) {
          wave.lineTo(w * 0.38 + i * w * 0.025, h * 0.19 + (i.isOdd ? -3 : 3));
        }
        canvas.drawPath(wave, a);
      case 'e5':
        for (var gi = 0; gi < 2; gi++) {
          final ox = gi == 0 ? w * 0.04 : w * 0.54;
          for (var r = 0; r < 4; r++) {
            for (var c = 0; c < 6; c++) {
              final o = Offset(ox + c * w * 0.07 + 3, h * 0.2 + r * h * 0.18);
              final filled = (r * 6 + c + gi * 3) % 3 != 0;
              if (filled) {
                canvas.drawCircle(o, 2.6, Paint()..color = ink);
              } else {
                canvas.drawCircle(o, 2.4, g);
              }
            }
          }
        }
        trazo(canvas, Offset(0, h * 0.47), Offset(w * 0.46, h * 0.47), a, seed: 1);
        trazo(canvas, Offset(w * 0.5, h * 0.65), Offset(w, h * 0.65), a, seed: 2);
      case 'e6':
        final c = Offset(w * 0.5, h * 0.5);
        final pin = Path()
          ..moveTo(c.dx, c.dy + 12)
          ..quadraticBezierTo(c.dx - 10, c.dy - 2, c.dx, c.dy - 10)
          ..quadraticBezierTo(c.dx + 10, c.dy - 2, c.dx, c.dy + 12);
        canvas.drawPath(pin, a);
        final nodes = [Offset(w * 0.12, h * 0.18), Offset(w * 0.88, h * 0.18), Offset(w * 0.12, h * 0.84), Offset(w * 0.88, h * 0.84)];
        for (var i = 0; i < nodes.length; i++) {
          canvas.drawCircle(nodes[i], 5, i == 3 ? g : p);
          paintHilo(canvas, from: nodes[i], to: c, color: i == 3 ? graphite : ink, provisional: i >= 2, width: 1.3, seed: i);
        }
      case 'e7':
        final r = Rect.fromLTWH(w * 0.18, h * 0.12, w * 0.64, h * 0.76);
        canvas.drawRect(r, p);
        for (var i = 0; i < 5; i++) {
          final y = r.top + 12 + i * 11.0;
          trazo(canvas, Offset(r.left + 10, y), Offset(r.right - 10 - (i * 7 % 20), y), g, seed: i);
        }
        trazo(canvas, Offset(r.left + 10, r.top + 37), Offset(r.right - 24, r.top + 37), a, seed: 9);
      case 'e8':
        figura(canvas, Offset(w * 0.3, suelo), h * 0.74, p, seed: 8);
        figura(canvas, Offset(w * 0.7, suelo), h * 0.74, p, rehecha: figuraPartes, seed: 8);
        canvas.drawLine(Offset(w * 0.5, h * 0.12), Offset(w * 0.5, suelo), g);
      default:
        canvas.drawLine(Offset(w * 0.5, h * 0.06), Offset(w * 0.5, suelo), tinta(ink, 2.2));
        figura(canvas, Offset(w * 0.2, suelo), h * 0.62, p, seed: 9);
        figura(canvas, Offset(w * 0.8, suelo), h * 0.62, p, seed: 10);
        paintHilo(canvas, from: Offset(w * 0.28, h * 0.5), to: Offset(w * 0.46, h * 0.5), color: ink, width: 1.4, seed: 1);
        paintHilo(canvas, from: Offset(w * 0.54, h * 0.5), to: Offset(w * 0.72, h * 0.5), color: ink, width: 1.4, seed: 2);
        canvas.drawCircle(Offset(w * 0.72, h * 0.5), 3.5, a);
    }
  }

  @override
  bool shouldRepaint(covariant _VinetaPainter old) => old.id != id || old.ink != ink;
}

/// La ilustración cede espacio al texto: a escala grande se reduce o se oculta.
bool ilustracionCabe(BuildContext context, {double hasta = 1.6}) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 <= hasta;
