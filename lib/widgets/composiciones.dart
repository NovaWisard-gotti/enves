import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/motion.dart';
import 'arte.dart';

/// Hilo limpio: las ilustraciones terminadas usan líneas rectas.
void hilo(Canvas canvas, Offset a, Offset b, Color c, {double w = 1.8, double t = 1}) {
  if (t <= 0) return;
  canvas.drawLine(a, Offset.lerp(a, b, t.clamp(0.0, 1.0))!, linea(c, w));
}

void puntoLleno(Canvas canvas, Offset c, double r, Color color) => canvas.drawCircle(c, r, relleno(color));

void puntoHueco(Canvas canvas, Offset c, double r, Color color, Color papel) {
  canvas.drawCircle(c, r, relleno(papel));
  canvas.drawCircle(c, r - r * 0.22, linea(color, r * 0.44));
}

/// Una composición que entra una sola vez (o aparece completa con
/// movimiento reducido).
class Composicion extends ConsumerWidget {
  const Composicion({super.key, required this.pintor, this.height = 220, this.duracion = const Duration(milliseconds: 1100), this.label});
  final CustomPainter Function(Tinta t, double v) pintor;
  final double height;
  final Duration duracion;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduced = reducedMotion(context, ref);
    final t = Tinta.of(context);
    final child = TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : duracion,
      curve: Motion.settle,
      builder: (context, v, _) => CustomPaint(size: Size(double.infinity, height), painter: pintor(t, v)),
    );
    return label == null
        ? ExcludeSemantics(child: SizedBox(height: height, child: child))
        : Semantics(label: label, excludeSemantics: true, child: SizedBox(height: height, child: child));
  }
}

double _fase(double v, double desde, double hasta) => ((v - desde) / (hasta - desde)).clamp(0.0, 1.0);

// ------------------------------------------------------------- onboarding
/// Dos perspectivas: dos siluetas en lados opuestos del eje. El punto lleno
/// es de una; el hueco, de la otra. Un hilo atraviesa el eje sin fundirlas.
class DosPerspectivasPainter extends CustomPainter {
  DosPerspectivasPainter(this.t, this.v, {this.conHilo = true});
  final Tinta t;
  final double v;
  final bool conHilo;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final enter = _fase(v, 0, 0.45);
    // Planos de collage, asimétricos.
    plano(canvas, Rect.fromLTWH(w * 0.02 - 18 * (1 - enter), h * 0.14, w * 0.42, h * 0.80), t.plane, sombra: t.ink);
    plano(canvas, Rect.fromLTWH(w * 0.58 + 18 * (1 - enter), h * 0.04, w * 0.36, h * 0.66), t.plane2, sombra: t.ink);
    // Figuras.
    final fh = h * 0.84;
    final fw = fh * 100 / 260;
    final op = _fase(v, 0.15, 0.55);
    dibujarSilueta(canvas, Rect.fromLTWH(w * 0.13, h * 0.96 - fh, fw, fh), t.ink.withValues(alpha: op),
        paso: 0.25, atras: t.ink2.withValues(alpha: op), papel: t.plane);
    dibujarSilueta(canvas, Rect.fromLTWH(w * 0.87 - fw, h * 0.96 - fh, fw, fh), t.ink2.withValues(alpha: op),
        derecha: false, paso: 0.25, atras: t.graphite.withValues(alpha: op), papel: t.plane2);
    // El eje.
    final axisT = _fase(v, 0.35, 0.6);
    canvas.drawLine(Offset(w / 2, h * 0.5 - h * 0.48 * axisT), Offset(w / 2, h * 0.5 + h * 0.48 * axisT), linea(t.ink, 3.2));
    // Los puntos y el hilo.
    final y = h * 0.5;
    final a = Offset(w * 0.40, y);
    final b = Offset(w * 0.60, y);
    final dotT = _fase(v, 0.5, 0.7);
    if (dotT > 0) puntoLleno(canvas, a, 8 * dotT, t.ink);
    if (conHilo) {
      final th = _fase(v, 0.62, 0.95);
      // El hilo pasa por el eje; un filo de papel deja ver que no se funden.
      hilo(canvas, a + const Offset(8, 0), b - const Offset(8, 0), t.ink, w: 1.6, t: th);
      if (th > 0.5) canvas.drawLine(Offset(w / 2, y - 7), Offset(w / 2, y + 7), linea(t.ink, 3.2));
      if (th >= 1) puntoHueco(canvas, b, 8, t.saffron, t.paper);
    }
  }

  @override
  bool shouldRepaint(covariant DosPerspectivasPainter old) => old.v != v || old.t != t || old.conHilo != conHilo;
}

// ----------------------------------------------------------------- viñetas
/// Viñeta editorial de cada experiencia, para el inicio y la entrada.
class VinetaPainter extends CustomPainter {
  VinetaPainter(this.id, this.t, this.v);
  final String id;
  final Tinta t;
  final double v;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final op = _fase(v, 0, 0.6);
    final slide = 14 * (1 - op);
    canvas.save();
    canvas.translate(0, slide);
    switch (id.split('_').first) {
      case 'e1':
        _e1(canvas, w, h);
      case 'e2':
        _e2(canvas, w, h);
      case 'e3':
        _e3(canvas, w, h);
      case 'e4':
        _e4(canvas, w, h);
      case 'e5':
        _e5(canvas, w, h);
      case 'e6':
        _e6(canvas, w, h);
      case 'e7':
        _e7(canvas, w, h);
      case 'e8':
        _e8(canvas, w, h);
      default:
        _e9(canvas, w, h);
    }
    canvas.restore();
  }

  void _e1(Canvas c, double w, double h) {
    plano(c, Rect.fromLTWH(w * 0.04, 0, w * 0.5, h * 0.62), t.plane, sombra: t.ink);
    c.drawRect(Rect.fromLTWH(0, h * 0.68, w, h * 0.32), relleno(t.plane2));
    for (var x = w * 0.66; x < w * 0.9; x += w * 0.045) {
      c.drawRect(Rect.fromLTWH(x, h * 0.70, w * 0.022, h * 0.28), relleno(t.paper));
    }
    final carW = math.min(w * 0.46, h * 1.5);
    final win = dibujarAuto(c, Rect.fromLTWH(w * 0.1, h * 0.84 - carW * 0.42, carW, carW * 0.42), t);
    final b = Rect.fromLTWH(win.left + win.width * 0.08, win.top + win.height * 0.08, win.width * 0.6, win.height * 0.92);
    c.save();
    c.clipRect(win);
    c.drawPath(busto(b), relleno(t.ink2));
    c.restore();
    dibujarTelefono(c, Rect.fromLTWH(win.left + win.width * 0.62, win.top + win.height * 0.32, win.width * 0.16, win.height * 0.5), t.saffron, t.paper);
  }

  void _e2(Canvas c, double w, double h) {
    plano(c, Rect.fromLTWH(w * 0.56, h * 0.06, w * 0.36, h * 0.5), t.plane, sombra: t.ink);
    final fh = h * 0.96;
    dibujarSilueta(c, Rect.fromLTWH(w * 0.12, h - fh, fh * 100 / 260, fh), t.ink, atras: t.ink2, papel: t.paper);
    final sh = h * 0.42;
    dibujarSilueta(c, Rect.fromLTWH(w * 0.7, h * 0.52 - sh, sh * 100 / 260, sh), t.ink, derecha: false, nino: true, gesto: 1, atras: t.ink2);
    c.drawLine(Offset(w * 0.6, h * 0.53), Offset(w * 0.88, h * 0.53), linea(t.ink, 2));
    hilo(c, Offset(w * 0.27, h * 0.44), Offset(w * 0.68, h * 0.3), t.saffron, w: 2.4);
    dibujarReloj(c, Offset(w * 0.66, h * 0.8), h * 0.11, t);
    dibujarRecibo(c, Rect.fromLTWH(w * 0.78, h * 0.64, w * 0.1, h * 0.32), t, giro: 0.12);
  }

  void _e3(Canvas c, double w, double h) {
    final cc = Offset(w * 0.5, h * 0.55);
    final r = h * 0.62;
    for (final (k, col) in [(1.0, t.plane2), (0.68, t.plane), (0.38, t.paper)]) {
      c.drawCircle(cc, r * k, relleno(col));
    }
    c.drawCircle(cc, r * 0.38, linea(t.ink, 1.4));
    final b = h * 0.34;
    c.drawPath(busto(Rect.fromCenter(center: cc, width: b, height: b)), relleno(t.ink));
    c.drawPath(busto(Rect.fromCenter(center: cc + Offset(-r * 0.53, -r * 0.2), width: b * 0.6, height: b * 0.6)), relleno(t.ink2));
    c.drawPath(busto(Rect.fromCenter(center: cc + Offset(r * 0.82, -r * 0.3), width: b * 0.5, height: b * 0.5), derecha: false), relleno(t.graphite));
  }

  void _e4(Canvas c, double w, double h) {
    plano(c, Rect.fromLTWH(w * 0.36, h * 0.18, w * 0.26, h * 0.62), t.paper, sombra: t.ink, giro: -0.05);
    final doc = Rect.fromLTWH(w * 0.36, h * 0.18, w * 0.26, h * 0.62);
    for (var i = 0; i < 4; i++) {
      final y = doc.top + doc.height * (0.22 + i * 0.17);
      c.drawLine(Offset(doc.left + doc.width * 0.15, y), Offset(doc.right - doc.width * (i == 3 ? 0.45 : 0.15), y), linea(t.graphite, 1.4));
    }
    final b = h * 0.78;
    c.drawPath(busto(Rect.fromLTWH(w * 0.04, h - b, b, b)), relleno(t.ink));
    c.drawPath(busto(Rect.fromLTWH(w * 0.96 - b, h - b, b, b), derecha: false), relleno(t.ink2));
    // Lo directo y lo suave.
    c.drawLine(Offset(w * 0.26, h * 0.22), Offset(w * 0.36, h * 0.22), linea(t.ink, 2));
    final wave = Path()..moveTo(w * 0.62, h * 0.22);
    for (var i = 1; i <= 6; i++) {
      wave.quadraticBezierTo(w * (0.62 + (i - 0.5) * 0.02), h * (0.22 + (i.isOdd ? -0.05 : 0.05)), w * (0.62 + i * 0.02), h * 0.22);
    }
    c.drawPath(wave, linea(t.saffron, 2));
  }

  void _e5(Canvas c, double w, double h) {
    plano(c, Rect.fromLTWH(w * 0.03, h * 0.04, w * 0.44, h * 0.92), t.plane, sombra: t.ink);
    plano(c, Rect.fromLTWH(w * 0.53, h * 0.04, w * 0.44, h * 0.92), t.plane2, sombra: t.ink);
    for (var g = 0; g < 2; g++) {
      final ox = g == 0 ? w * 0.07 : w * 0.57;
      for (var r = 0; r < 5; r++) {
        for (var k = 0; k < 7; k++) {
          final o = Offset(ox + k * w * 0.054, h * 0.16 + r * h * 0.17);
          final lleno = (r * 7 + k * 3 + g * 5) % 4 != 0;
          final dim = g == 1 ? r >= 2 : r >= 3;
          final col = dim ? t.graphite : t.ink;
          if (lleno) {
            c.drawCircle(o, h * 0.035, relleno(col));
          } else {
            c.drawCircle(o, h * 0.03, linea(col, 1.4));
          }
        }
      }
      final ty = h * (g == 0 ? 0.6 : 0.43);
      c.drawLine(Offset(ox - 4, ty), Offset(ox + w * 0.36, ty), linea(t.saffron, 2.6));
    }
  }

  void _e6(Canvas c, double w, double h) {
    final cc = Offset(w * 0.5, h * 0.5);
    final nodes = [Offset(w * 0.14, h * 0.24), Offset(w * 0.86, h * 0.24), Offset(w * 0.18, h * 0.82), Offset(w * 0.82, h * 0.82)];
    for (var i = 0; i < nodes.length; i++) {
      hilo(c, cc, nodes[i], i == 0 ? t.saffron : (i == 3 ? t.plane2 : t.ink2), w: i == 0 ? 2.6 : 1.6);
    }
    final ph = h * 0.7;
    plano(c, Rect.fromCenter(center: cc, width: ph * 0.62, height: ph), t.ink, sombra: t.ink);
    dibujarTelefono(c, Rect.fromCenter(center: cc, width: ph * 0.5, height: ph * 0.88), t.ink, t.paper);
    final pin = Path()
      ..moveTo(cc.dx, cc.dy + ph * 0.14)
      ..quadraticBezierTo(cc.dx - ph * 0.12, cc.dy, cc.dx, cc.dy - ph * 0.12)
      ..quadraticBezierTo(cc.dx + ph * 0.12, cc.dy, cc.dx, cc.dy + ph * 0.14);
    c.drawPath(pin, relleno(t.saffron));
    final b = h * 0.3;
    for (var i = 0; i < nodes.length; i++) {
      c.drawPath(busto(Rect.fromCenter(center: nodes[i], width: b, height: b), derecha: i.isEven), relleno(i == 3 ? t.graphite : t.ink));
    }
  }

  void _e7(Canvas c, double w, double h) {
    plano(c, Rect.fromLTWH(w * 0.48, h * 0.24, w * 0.4, h * 0.6), t.plane2, sombra: t.ink, giro: 0.07);
    final env = Rect.fromLTWH(w * 0.48, h * 0.24, w * 0.4, h * 0.6);
    c.save();
    c.translate(env.center.dx, env.center.dy);
    c.rotate(0.07);
    c.translate(-env.center.dx, -env.center.dy);
    c.drawPath(Path()
      ..moveTo(env.left, env.top)
      ..lineTo(env.center.dx, env.center.dy)
      ..lineTo(env.right, env.top), linea(t.ink2, 1.6));
    c.restore();
    final paper = Rect.fromLTWH(w * 0.14, h * 0.04, w * 0.42, h * 0.92);
    plano(c, paper, t.paper, sombra: t.ink, giro: -0.04);
    c.save();
    c.translate(paper.center.dx, paper.center.dy);
    c.rotate(-0.04);
    c.translate(-paper.center.dx, -paper.center.dy);
    c.drawRect(paper, linea(t.plane2, 1.2));
    for (var i = 0; i < 7; i++) {
      final y = paper.top + paper.height * (0.14 + i * 0.11);
      final end = paper.right - paper.width * (0.12 + (i * 7 % 5) * 0.05);
      c.drawLine(Offset(paper.left + paper.width * 0.12, y), Offset(end, y), linea(i == 3 ? t.ink : t.graphite, i == 3 ? 2.2 : 1.4));
      if (i == 3) c.drawLine(Offset(paper.left + paper.width * 0.12, y + 5), Offset(end, y + 5), linea(t.saffron, 2.4));
    }
    c.restore();
  }

  void _e8(Canvas c, double w, double h) {
    plano(c, Rect.fromLTWH(w * 0.5, h * 0.02, w * 0.4, h * 0.96), t.plane, sombra: t.ink);
    final fh = h * 0.96;
    final fw = fh * 100 / 260;
    dibujarSilueta(c, Rect.fromLTWH(w * 0.24, h - fh, fw, fh), t.ink, atras: t.ink2, papel: t.paper);
    figuraRehecha(c, Rect.fromLTWH(w * 0.62, h - fh, fw, fh), t, siluetaPartes, derecha: false, actual: Parte.cabeza);
    c.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), linea(t.ink, 2.4));
  }

  void _e9(Canvas c, double w, double h) {
    plano(c, Rect.fromLTWH(w * 0.04, h * 0.1, w * 0.4, h * 0.88), t.plane, sombra: t.ink);
    plano(c, Rect.fromLTWH(w * 0.56, h * 0.02, w * 0.4, h * 0.8), t.plane2, sombra: t.ink);
    final fh = h * 0.94;
    final fw = fh * 100 / 260;
    dibujarSilueta(c, Rect.fromLTWH(w * 0.16, h - fh, fw, fh), t.ink, atras: t.ink2, papel: t.plane);
    dibujarSilueta(c, Rect.fromLTWH(w * 0.84 - fw, h - fh, fw, fh), t.ink2, derecha: false, atras: t.graphite, papel: t.plane2);
    c.drawLine(Offset(w / 2, 0), Offset(w / 2, h), linea(t.ink, 2.6));
    final y = h * 0.42;
    puntoLleno(c, Offset(w * 0.38, y), h * 0.05, t.ink);
    hilo(c, Offset(w * 0.38, y), Offset(w * 0.62, y), t.ink, w: 1.4);
    puntoHueco(c, Offset(w * 0.62, y), h * 0.05, t.saffron, t.paper);
  }

  @override
  bool shouldRepaint(covariant VinetaPainter old) => old.v != v || old.id != id || old.t != t;
}

/// Figura cuyas primeras [rehechas] partes fueron vueltas a dibujar: contorno
/// y tramado en lugar de tinta sólida. La parte [actual] va en azafrán.
void figuraRehecha(
  Canvas c,
  Rect r,
  Tinta t,
  int rehechas, {
  bool derecha = true,
  Parte? actual,
}) {
  final parts = siluetaPartesDe(r, derecha: derecha);
  final order = Parte.values;
  final grosor = math.max(1.2, r.width * 0.025);
  for (var i = 0; i < order.length; i++) {
    final p = parts[order[i]]!;
    final back = order[i] == Parte.brazoAtras || order[i] == Parte.piernaAtras;
    if (i < rehechas) {
      final col = order[i] == actual ? t.saffron : t.ink;
      c.drawPath(p, relleno(t.paper));
      tramar(c, p, col, paso: math.max(3.5, r.width * 0.07), grosor: grosor * 0.8);
      c.drawPath(p, linea(col, grosor));
    } else {
      c.drawPath(p, relleno(back ? t.ink2 : t.ink));
    }
  }
}

/// Viñeta de una experiencia como widget.
class VinetaArte extends StatelessWidget {
  const VinetaArte(this.experienceId, {super.key, this.height = 150});
  final String experienceId;
  final double height;

  @override
  Widget build(BuildContext context) => Composicion(
        height: height,
        duracion: const Duration(milliseconds: 700),
        pintor: (t, v) => VinetaPainter(experienceId, t, v),
      );
}


/// Portada del mapa: a un lado, tú y un punto por cada decisión tomada; al
/// otro, quien piensa distinto y un punto hueco por cada posición
/// comprendida. Los números son los del mapa, no decoración.
class PortadaMapaPainter extends CustomPainter {
  PortadaMapaPainter(this.t, this.v, {required this.decisiones, required this.comprendidas});
  final Tinta t;
  final double v;
  final int decisiones;
  final int comprendidas;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    plano(canvas, Rect.fromLTWH(0, h * 0.08, w * 0.47, h * 0.9), t.plane, sombra: t.ink);
    plano(canvas, Rect.fromLTWH(w * 0.53, 0, w * 0.47, h * 0.84), t.plane2, sombra: t.ink);
    final fh = h * 0.86;
    final fw = fh * 100 / 260;
    dibujarSilueta(canvas, Rect.fromLTWH(w * 0.12, h - fh, fw, fh), t.ink, atras: t.ink2, papel: t.plane);
    dibujarSilueta(canvas, Rect.fromLTWH(w * 0.88 - fw, h - fh - h * 0.06, fw, fh), t.ink2,
        derecha: false, atras: t.graphite, papel: t.plane2);
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), linea(t.ink, 3));
    // Puntos en una cuadrícula a cada lado del eje.
    const cols = 3;
    final step = math.min(w * 0.055, h * 0.13);
    Offset at(int i, bool izquierda) {
      final c = i % cols;
      final r = i ~/ cols;
      final x = izquierda ? w * 0.44 - c * step : w * 0.56 + c * step;
      return Offset(x, h * 0.22 + r * step);
    }

    final shown = (v * (decisiones + comprendidas + 2)).floor();
    for (var i = 0; i < decisiones && i < 9; i++) {
      if (i >= shown) break;
      puntoLleno(canvas, at(i, true), step * 0.3, t.ink);
    }
    for (var i = 0; i < comprendidas && i < 9; i++) {
      if (decisiones + i >= shown) break;
      puntoHueco(canvas, at(i, false), step * 0.32, t.saffron, t.plane2);
    }
    if (decisiones > 0 && comprendidas > 0 && v >= 1) {
      hilo(canvas, at(0, true), at(0, false), t.ink, w: 1.4);
    }
  }

  @override
  bool shouldRepaint(covariant PortadaMapaPainter old) =>
      old.v != v || old.t != t || old.decisiones != decisiones || old.comprendidas != comprendidas;
}
