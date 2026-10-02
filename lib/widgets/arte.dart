import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dirección de arte de Envés: collage editorial contemporáneo.
///
/// Siluetas sólidas, planos recortados, contraste de escala y líneas limpias.
/// Todo se dibuja con los tokens del tema, así que funciona igual en claro y
/// en oscuro sin invertir nada.

/// Colores de una ilustración, tomados del tema.
class Tinta {
  const Tinta({
    required this.ink,
    required this.ink2,
    required this.graphite,
    required this.saffron,
    required this.paper,
    required this.plane,
    required this.plane2,
  });

  factory Tinta.of(BuildContext context) {
    final e = context.enves;
    return Tinta(
      ink: e.ink,
      ink2: e.inkSecondary,
      graphite: e.graphite,
      saffron: e.saffron,
      paper: e.paper,
      plane: e.reverse,
      plane2: e.divider,
    );
  }

  final Color ink;
  final Color ink2;
  final Color graphite;
  final Color saffron;
  final Color paper;

  /// Plano de papel recortado (más suave que la tinta).
  final Color plane;

  /// Segundo plano, un poco más denso: calle, mesa, suelo.
  final Color plane2;

  @override
  bool operator ==(Object other) =>
      other is Tinta && other.ink == ink && other.paper == paper && other.saffron == saffron && other.plane == plane;

  @override
  int get hashCode => Object.hash(ink, paper, saffron, plane);
}

Paint relleno(Color c) => Paint()..color = c;

Paint linea(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Un plano recortado con una sombra muy sutil, como papel pegado.
void plano(Canvas canvas, Rect r, Color color, {Color? sombra, double giro = 0}) {
  canvas.save();
  if (giro != 0) {
    canvas.translate(r.center.dx, r.center.dy);
    canvas.rotate(giro);
    canvas.translate(-r.center.dx, -r.center.dy);
  }
  if (sombra != null) {
    canvas.drawRect(r.shift(const Offset(3, 4)), relleno(sombra.withValues(alpha: 0.10)));
  }
  canvas.drawRect(r, relleno(color));
  canvas.restore();
}

/// Une formas en una sola silueta (sin costuras donde se superponen).
Path unir(Iterable<Path> paths) {
  Path? out;
  for (final p in paths) {
    out = out == null ? p : Path.combine(PathOperation.union, out, p);
  }
  return out ?? Path();
}

/// Extremidad sólida que se afina: un segmento con extremos redondeados.
Path _tramo(Offset a, Offset b, double wa, double wb) {
  final p = Path();
  final d = b - a;
  final len = d.distance;
  if (len == 0) return p;
  final n = Offset(-d.dy / len, d.dx / len);
  final quad = Path()
    ..moveTo(a.dx + n.dx * wa / 2, a.dy + n.dy * wa / 2)
    ..lineTo(b.dx + n.dx * wb / 2, b.dy + n.dy * wb / 2)
    ..lineTo(b.dx - n.dx * wb / 2, b.dy - n.dy * wb / 2)
    ..lineTo(a.dx - n.dx * wa / 2, a.dy - n.dy * wa / 2)
    ..close();
  return unir([
    quad,
    Path()..addOval(Rect.fromCircle(center: a, radius: wa / 2)),
    Path()..addOval(Rect.fromCircle(center: b, radius: wb / 2)),
  ]);
}

/// Partes de una silueta de pie, en el orden en que se reemplazarían.
enum Parte { pies, piernaAtras, piernaFrente, brazoAtras, brazoFrente, torso, cabeza }

const siluetaPartes = 7;

/// Silueta editorial de cuerpo entero, de perfil tres cuartos, mirando a la
/// derecha. Diseñada en una caja de 100 × 260 y escalada a [r].
///
/// [paso] abre la zancada (0 quieto, 1 caminando). [nino] cambia las
/// proporciones. [gesto] levanta el brazo delantero.
Map<Parte, Path> siluetaPartesDe(Rect r, {bool derecha = true, double paso = 0, bool nino = false, double gesto = 0}) {
  final sx = r.width / 100;
  final sy = r.height / 260;
  Offset o(double x, double y) => Offset(r.left + (derecha ? x : 100 - x) * sx, r.top + y * sy);
  double w(double v) => v * (sx + sy) / 2;
  // Un niño: cabeza más grande, hombros y cadera más abajo en la misma caja.
  final k = nino ? 1.25 : 1.0;
  final hy = 22.0 * k;
  final sh = nino ? 60.0 : 46.0;
  final hip = nino ? 146.0 : 132.0;
  final waist = sh + (hip - sh) * 0.48;

  final cabeza = unir([
    Path()..addOval(Rect.fromCenter(center: o(54, hy), width: w(27 * k), height: w(31 * k))),
    Path()..addOval(Rect.fromCircle(center: o(48, hy - 3 * k), radius: w(13 * k))),
    Path()..addOval(Rect.fromCircle(center: o(54 + 12.6 * k, hy + 2 * k), radius: w(2.4 * k))),
    _tramo(o(52, hy + 12 * k), o(52, sh + 2), w(10), w(12)),
  ]);

  Offset q(double x, double y) => o(x, y);
  final torso = Path()
    ..moveTo(q(31, sh + 7).dx, q(31, sh + 7).dy)
    ..quadraticBezierTo(q(50, sh - 6).dx, q(50, sh - 6).dy, q(71, sh + 6).dx, q(71, sh + 6).dy)
    ..cubicTo(q(77, sh + 15).dx, q(77, sh + 27).dy, q(77, sh + 27).dx, q(77, sh + 27).dy, q(73, waist).dx, q(73, waist).dy)
    ..lineTo(q(76, hip + 2).dx, q(76, hip + 2).dy)
    ..quadraticBezierTo(q(54, hip + 9).dx, q(54, hip + 9).dy, q(32, hip + 2).dx, q(32, hip + 2).dy)
    ..lineTo(q(35, waist).dx, q(35, waist).dy)
    ..cubicTo(q(30, sh + 27).dx, q(30, sh + 27).dy, q(29, sh + 15).dx, q(29, sh + 15).dy, q(31, sh + 7).dx, q(31, sh + 7).dy)
    ..close();

  final brazoAtras = unir([
    _tramo(o(35, sh + 10), o(31, sh + 50), w(13), w(11)),
    _tramo(o(31, sh + 50), o(34, hip - 2), w(11), w(9.5)),
  ]);
  final codo = Offset.lerp(o(77, sh + 48), o(82, sh + 26), gesto)!;
  final mano = Offset.lerp(o(73, hip - 2), o(90, sh - 8), gesto)!;
  final brazoFrente = unir([
    _tramo(o(68, sh + 10), codo, w(13), w(11)),
    _tramo(codo, mano, w(11), w(9.5)),
  ]);

  final rodA = o(44 - 10 * paso, 190);
  final pieA = o(42 - 20 * paso, 244);
  final rodF = o(61 + 9 * paso, 190);
  final pieF = o(63 + 19 * paso, 244);
  final piernaAtras = unir([
    _tramo(o(44, hip - 2), rodA, w(18), w(14)),
    _tramo(rodA, pieA, w(14), w(11)),
  ]);
  final piernaFrente = unir([
    _tramo(o(61, hip - 2), rodF, w(18), w(14)),
    _tramo(rodF, pieF, w(14), w(11)),
  ]);

  final dir = derecha ? 1.0 : -1.0;
  RRect pie(Offset c) => RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + Offset(dir * w(6), w(4)), width: w(23), height: w(10)),
        Radius.circular(w(5)),
      );
  final pies = Path()
    ..addRRect(pie(pieA))
    ..addRRect(pie(pieF));

  return {
    Parte.pies: pies,
    Parte.piernaAtras: piernaAtras,
    Parte.piernaFrente: piernaFrente,
    Parte.brazoAtras: brazoAtras,
    Parte.brazoFrente: brazoFrente,
    Parte.torso: torso,
    Parte.cabeza: cabeza,
  };
}

/// Silueta de cuerpo entero como una sola forma.
Path silueta(Rect r, {bool derecha = true, double paso = 0, bool nino = false, double gesto = 0}) =>
    unir(siluetaPartesDe(r, derecha: derecha, paso: paso, nino: nino, gesto: gesto).values);

/// Dibuja una silueta sólida. El brazo y la pierna de atrás van en un tono
/// más suave para dar profundidad, y un filo de papel separa el brazo
/// delantero del torso.
void dibujarSilueta(
  Canvas canvas,
  Rect r,
  Color color, {
  bool derecha = true,
  double paso = 0,
  bool nino = false,
  double gesto = 0,
  Color? atras,
  Color? papel,
}) {
  final parts = siluetaPartesDe(r, derecha: derecha, paso: paso, nino: nino, gesto: gesto);
  final back = atras ?? color;
  canvas.drawPath(parts[Parte.brazoAtras]!, relleno(back));
  canvas.drawPath(parts[Parte.piernaAtras]!, relleno(back));
  canvas.drawPath(unir([parts[Parte.pies]!, parts[Parte.piernaFrente]!, parts[Parte.torso]!, parts[Parte.cabeza]!]), relleno(color));
  if (papel != null) {
    canvas.drawPath(parts[Parte.brazoFrente]!, linea(papel, math.max(1.2, r.width * 0.03)));
  }
  canvas.drawPath(parts[Parte.brazoFrente]!, relleno(color));
}

/// Busto editorial (cabeza y hombros) en una caja de 100 × 100.
Path busto(Rect r, {bool derecha = true}) {
  final sx = r.width / 100;
  final sy = r.height / 100;
  Offset o(double x, double y) => Offset(r.left + (derecha ? x : 100 - x) * sx, r.top + y * sy);
  final s = (sx + sy) / 2;
  final a = o(8, 100);
  final b = o(12, 70);
  final c = o(50, 60);
  final d = o(88, 70);
  final e = o(92, 100);
  final hombros = Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(a.dx, b.dy, b.dx, c.dy, c.dx, c.dy)
    ..cubicTo(d.dx, c.dy, e.dx, d.dy, e.dx, e.dy)
    ..close();
  return unir([
    Path()..addOval(Rect.fromCenter(center: o(53, 31), width: 30 * s, height: 35 * s)),
    Path()..addOval(Rect.fromCircle(center: o(47, 27), radius: 15 * s)),
    Path()..addOval(Rect.fromCircle(center: o(67.5, 34), radius: 2.8 * s)),
    _tramo(o(51, 44), o(51, 62), 13 * s, 16 * s),
    hombros,
  ]);
}

/// Auto de perfil con volumen: carrocería sólida, ventanas recortadas en
/// papel, ruedas y sombra. Mira a la derecha. Devuelve el rectángulo de la
/// ventana delantera (para el conductor).
Rect dibujarAuto(Canvas canvas, Rect r, Tinta t) {
  double x(double f) => r.left + f * r.width;
  double y(double f) => r.top + f * r.height;
  // Sombra en el suelo.
  canvas.drawOval(
    Rect.fromCenter(center: Offset(x(0.5), y(0.97)), width: r.width * 1.02, height: r.height * 0.12),
    relleno(t.ink.withValues(alpha: 0.12)),
  );
  final body = Path()
    ..moveTo(x(0.02), y(0.84))
    ..lineTo(x(0.02), y(0.56))
    ..quadraticBezierTo(x(0.02), y(0.46), x(0.11), y(0.45))
    ..lineTo(x(0.27), y(0.42))
    ..lineTo(x(0.39), y(0.12))
    ..quadraticBezierTo(x(0.41), y(0.06), x(0.48), y(0.06))
    ..lineTo(x(0.70), y(0.06))
    ..quadraticBezierTo(x(0.75), y(0.06), x(0.79), y(0.12))
    ..lineTo(x(0.89), y(0.42))
    ..quadraticBezierTo(x(0.98), y(0.45), x(0.98), y(0.56))
    ..lineTo(x(0.98), y(0.84))
    ..close();
  canvas.drawPath(body, relleno(t.ink));
  // Línea de luz sobre la carrocería: volumen sin degradados.
  canvas.drawLine(Offset(x(0.06), y(0.58)), Offset(x(0.94), y(0.58)), linea(t.paper.withValues(alpha: 0.22), r.height * 0.025));
  final rear = Path()
    ..moveTo(x(0.43), y(0.16))
    ..lineTo(x(0.57), y(0.16))
    ..lineTo(x(0.57), y(0.40))
    ..lineTo(x(0.33), y(0.40))
    ..close();
  final front = Path()
    ..moveTo(x(0.61), y(0.16))
    ..lineTo(x(0.73), y(0.16))
    ..lineTo(x(0.84), y(0.40))
    ..lineTo(x(0.61), y(0.40))
    ..close();
  canvas.drawPath(rear, relleno(t.plane));
  canvas.drawPath(front, relleno(t.plane));
  // Ruedas: el arco se recorta en papel y la rueda queda sólida.
  final wr = r.height * 0.17;
  for (final cx in [x(0.23), x(0.77)]) {
    final c = Offset(cx, y(0.84));
    canvas.drawCircle(c, wr * 1.22, relleno(t.paper));
    canvas.drawCircle(c, wr, relleno(t.ink));
    canvas.drawCircle(c, wr * 0.42, relleno(t.plane2));
  }
  return Rect.fromLTRB(x(0.61), y(0.16), x(0.84), y(0.40));
}

/// Teléfono en vertical: cuerpo sólido, pantalla de papel.
void dibujarTelefono(Canvas canvas, Rect r, Color body, Color screen) {
  canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.18)), relleno(body));
  canvas.drawRRect(
    RRect.fromRectAndRadius(r.deflate(r.width * 0.12), Radius.circular(r.width * 0.08)),
    relleno(screen),
  );
}

/// Reloj sólido: disco de tinta con manecillas de papel.
void dibujarReloj(Canvas canvas, Offset c, double r, Tinta t) {
  canvas.drawCircle(c, r, relleno(t.ink));
  canvas.drawLine(c, c + Offset(0, -r * 0.62), linea(t.paper, r * 0.14));
  canvas.drawLine(c, c + Offset(r * 0.45, 0), linea(t.paper, r * 0.14));
}

/// Recibo: tira de papel con borde dentado y renglones.
void dibujarRecibo(Canvas canvas, Rect r, Tinta t, {double giro = 0}) {
  canvas.save();
  canvas.translate(r.center.dx, r.center.dy);
  canvas.rotate(giro);
  canvas.translate(-r.center.dx, -r.center.dy);
  final teeth = 6;
  final p = Path()
    ..moveTo(r.left, r.top)
    ..lineTo(r.right, r.top)
    ..lineTo(r.right, r.bottom);
  for (var i = teeth; i >= 0; i--) {
    final xx = r.left + r.width * i / teeth;
    p.lineTo(xx, i.isEven ? r.bottom : r.bottom - r.width / teeth * 0.6);
  }
  p.close();
  canvas.drawPath(p.shift(const Offset(2, 3)), relleno(t.ink.withValues(alpha: 0.10)));
  canvas.drawPath(p, relleno(t.paper));
  canvas.drawPath(p, linea(t.ink, 1.2));
  for (var i = 0; i < 4; i++) {
    final yy = r.top + r.height * (0.2 + i * 0.16);
    canvas.drawLine(Offset(r.left + r.width * 0.18, yy), Offset(r.right - r.width * (i == 3 ? 0.45 : 0.18), yy), linea(t.ink, 1.4));
  }
  canvas.restore();
}

/// Tramado diagonal dentro de una forma: lo «vuelto a dibujar».
void tramar(Canvas canvas, Path forma, Color color, {double paso = 5, double grosor = 1.4}) {
  final b = forma.getBounds();
  canvas.save();
  canvas.clipPath(forma);
  final p = linea(color, grosor);
  for (var d = -b.height; d < b.width + b.height; d += paso) {
    canvas.drawLine(Offset(b.left + d, b.bottom), Offset(b.left + d + b.height, b.top), p);
  }
  canvas.restore();
}
