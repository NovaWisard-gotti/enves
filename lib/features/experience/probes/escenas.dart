import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/hilo_vivo.dart';
import '../../../widgets/ilustraciones.dart';
import '../../../widgets/paper.dart';

// ------------------------------------------------------------ E1: la escena
/// La misma escena para Ana y para Beto. [t] = 0 es Ana, 1 es Beto. Lo común
/// (calle, auto, celular) queda quieto; solo aparece el acontecimiento.
class EscenaDescuido extends StatelessWidget {
  const EscenaDescuido({super.key, required this.t, this.height = 150});
  final double t;
  final double height;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _EscenaDescuidoPainter(t, e.ink, e.graphite, e.saffron, e.paper),
      ),
    );
  }
}

class _EscenaDescuidoPainter extends CustomPainter {
  _EscenaDescuidoPainter(this.t, this.ink, this.graphite, this.saffron, this.paper);
  final double t;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final p = tinta(ink, 1.8);
    final g = tinta(graphite, 1.2);
    final top = h * 0.3;
    final bottom = h * 0.96;
    final mid = (top + bottom) / 2;

    // Calle: igual en las dos escenas.
    trazo(canvas, Offset(0, top), Offset(w, top), g, seed: 1);
    trazo(canvas, Offset(0, bottom), Offset(w, bottom), g, seed: 2);
    for (var x = 8.0; x < w; x += 26) {
      canvas.drawLine(Offset(x, mid), Offset(x + 12, mid), g);
    }
    // Auto y conductor: idénticos.
    final carW = math.min(w * 0.4, 190.0);
    final carBase = Offset(w * 0.08, mid + h * 0.12);
    auto(canvas, carBase, carW, p);
    final head = Offset(carBase.dx + carW * 0.42, carBase.dy - carW * 0.32 * 0.68);
    canvas.drawCircle(head, carW * 0.045, p);
    // El celular: tres segundos.
    final phone = Rect.fromCenter(center: head + Offset(carW * 0.1, carW * 0.03), width: carW * 0.045, height: carW * 0.075);
    canvas.drawRRect(RRect.fromRectAndRadius(phone, const Radius.circular(1.5)), tinta(saffron, 1.8));
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: phone.center, radius: phone.height * (0.9 + i * 0.45)),
        -math.pi * 0.35,
        math.pi * 0.25,
        false,
        tinta(saffron, 1.1),
      );
    }
    // Líneas de movimiento.
    for (var i = 0; i < 3; i++) {
      final y = carBase.dy - carW * 0.1 - i * 7;
      canvas.drawLine(Offset(carBase.dx - 22, y), Offset(carBase.dx - 6, y), g);
    }

    // Lo único que cambia.
    if (t > 0.02) {
      final a = t.clamp(0.0, 1.0);
      final childX = math.min(carBase.dx + carW + w * 0.18, w - 24);
      figura(canvas, Offset(childX, bottom - 4), h * 0.34, tinta(ink, 1.8), opacidad: a, seed: 7, brazoArriba: true);
      // Marcas de frenado.
      final brake = Paint()
        ..color = graphite.withValues(alpha: graphite.a * a)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(carBase.dx + carW * 0.1, carBase.dy + 6), Offset(carBase.dx - 30 * a, carBase.dy + 6), brake);
      canvas.drawLine(Offset(carBase.dx + carW * 0.66, carBase.dy + 6), Offset(carBase.dx + carW * 0.5 - 30 * a, carBase.dy + 6), brake);
    }
  }

  @override
  bool shouldRepaint(covariant _EscenaDescuidoPainter old) => old.t != t || old.ink != ink;
}

// ------------------------------------------------------ E2: hilos de la promesa
/// La promesa como un hilo hacia tu hermana; el turno, en otra dirección.
/// Toca cada extremo para ver qué depende de ti y qué de esta decisión.
/// En la variante secreta, el hilo de lo que ella sabe desaparece; la promesa
/// sigue dibujada.
class HilosPromesa extends ConsumerStatefulWidget {
  const HilosPromesa({super.key, this.secreto = false});
  final bool secreto;

  @override
  ConsumerState<HilosPromesa> createState() => _HilosPromesaState();
}

class _HilosPromesaState extends ConsumerState<HilosPromesa> {
  String? _tocado;

  static const _hermana = 'Qué depende de ti: estar ahí. Se lo prometiste y nadie más de la familia puede ir.';
  static const _turno = 'Qué depende de esta decisión: el turno cubriría una deuda urgente de tu familia. Solo puede ser ese sábado.';

  void _tap(String id) {
    ref.read(feedbackProvider).selection();
    setState(() => _tocado = _tocado == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    final show = ilustracionCabe(context);
    Widget boton(String id, String label) => Semantics(
          button: true,
          selected: _tocado == id,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => _tap(id),
            radius: 40,
            child: const SizedBox(width: 72, height: 72),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (show)
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            const h = 200.0;
            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1, end: widget.secreto ? 0 : 1),
                        duration: reduced ? Duration.zero : const Duration(milliseconds: 1600),
                        curve: Motion.settle,
                        builder: (context, saber, _) => CustomPaint(
                          painter: _PromesaPainter(
                            saber: saber,
                            tocado: _tocado,
                            ink: e.ink,
                            graphite: e.graphite,
                            saffron: e.saffron,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(left: w * 0.8 - 36, top: 8, child: boton('hermana', 'Tu hermana: qué depende de ti')),
                  Positioned(left: w * 0.8 - 36, top: h * 0.78 - 36, child: boton('turno', 'El turno extra: qué depende de esta decisión')),
                  Positioned(
                    left: w * 0.5,
                    top: h * 0.08,
                    child: ExcludeSemantics(child: Text('la promesa', style: context.text.bodySmall)),
                  ),
                  Positioned(
                    left: w * 0.5,
                    top: h * 0.86,
                    child: ExcludeSemantics(child: Text('el turno', style: context.text.bodySmall)),
                  ),
                ],
              ),
            );
          })
        else
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: () => _tap('hermana'), child: const Text('Tu hermana')),
              OutlinedButton(onPressed: () => _tap('turno'), child: const Text('El turno extra')),
            ],
          ),
        if (show && _tocado == null)
          Text('Toca a tu hermana o el turno.', style: context.text.bodySmall),
        AnimatedSize(
          duration: reduced ? Duration.zero : Motion.medium,
          child: _tocado == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(liveRegion: true, child: MarginNote(_tocado == 'hermana' ? _hermana : _turno)),
                ),
        ),
        if (widget.secreto) ...[
          const Gap(10),
          Text(
            'Si nunca se enterara, desaparece el hilo de lo que ella sabe. La promesa sigue dibujada.',
            style: context.text.bodyMedium,
          ),
          const Gap(4),
          Text(
            '¿Romper una promesa está mal porque decepciona, o porque rompiste tu palabra?',
            style: context.text.titleMedium,
          ),
        ],
      ],
    );
  }
}

class _PromesaPainter extends CustomPainter {
  _PromesaPainter({required this.saber, required this.tocado, required this.ink, required this.graphite, required this.saffron});
  final double saber;
  final String? tocado;
  final Color ink;
  final Color graphite;
  final Color saffron;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final yo = Offset(w * 0.16, h * 0.92);
    final yoAlto = h * 0.66;
    figura(canvas, yo, yoAlto, tinta(ink, 2), seed: 1);
    final herm = Offset(w * 0.8, h * 0.5);
    final hermAlto = h * 0.36;
    // El escenario de la presentación.
    canvas.drawLine(Offset(herm.dx - 34, herm.dy + 1), Offset(herm.dx + 34, herm.dy + 1), tinta(graphite, 1.2));
    figura(canvas, herm, hermAlto, tinta(ink, 1.8), seed: 2, brazoArriba: true);
    // El turno: un reloj.
    final reloj = Offset(w * 0.8, h * 0.78);
    canvas.drawCircle(reloj, 15, tinta(tocado == 'turno' ? ink : graphite, tocado == 'turno' ? 2.2 : 1.6));
    canvas.drawLine(reloj, reloj + const Offset(0, -9), tinta(graphite, 1.6));
    canvas.drawLine(reloj, reloj + const Offset(7, 0), tinta(graphite, 1.6));

    final mano = Offset(yo.dx + yoAlto * 0.2, yo.dy - yoAlto * 0.45);
    // La promesa: hilo reforzado con un nudo, la palabra dada.
    final hermMano = Offset(herm.dx - hermAlto * 0.2, herm.dy - hermAlto * 0.45);
    paintHilo(
      canvas,
      from: mano,
      to: hermMano,
      color: ink,
      forma: HiloForma.reforzado,
      width: tocado == 'hermana' ? 2.4 : 1.8,
      seed: 3,
      bend: -18,
    );
    final nudo = Offset.lerp(mano, hermMano, 0.5)! + const Offset(0, -12);
    canvas.drawCircle(nudo, 4.5, Paint()..color = saffron);
    // El turno: otra dirección, en grafito.
    paintHilo(canvas, from: mano, to: reloj - const Offset(16, 0), color: graphite, provisional: true, width: 1.8, seed: 4, bend: 12);
    // Lo que ella sabe: un hilo fino de vuelta hacia ti.
    if (saber > 0.01) {
      final cabezaH = Offset(herm.dx, herm.dy - hermAlto + hermAlto * 0.11);
      final cabezaY = Offset(yo.dx, yo.dy - yoAlto + yoAlto * 0.11);
      paintHilo(
        canvas,
        from: cabezaH - const Offset(8, 0),
        to: cabezaY + const Offset(10, 0),
        color: graphite.withValues(alpha: graphite.a * saber),
        provisional: true,
        width: 1.4,
        seed: 6,
        bend: -26,
        progress: saber,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PromesaPainter old) => old.saber != saber || old.tocado != tocado || old.ink != ink;
}

// --------------------------------------------------- E3: círculos de cercanía
class CirculosPainter extends CustomPainter {
  CirculosPainter({
    required this.activo,
    required this.marcas,
    required this.sombra,
    required this.ink,
    required this.graphite,
    required this.saffron,
    required this.paper,
    required this.etiquetas,
    required this.estilo,
  });

  /// Círculo activo (2…n), interpolado durante la animación.
  final double activo;

  /// Círculo → decisión (−1 callar, 0 no sé, 1 contar).
  final Map<int, int?> marcas;

  /// La decisión original, con el hermano.
  final int? sombra;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;
  final List<String> etiquetas;
  final TextStyle estilo;

  static const radios = [0.33, 0.62, 0.92];

  double _radio(double k, double r) {
    final i = (k - 1).clamp(0.0, radios.length - 1.0);
    final lo = i.floor();
    final hi = i.ceil();
    return r * (radios[lo] + (radios[hi] - radios[lo]) * (i - lo));
  }

  static double angulo(int? v) {
    if (v == null) return math.pi * 1.25;
    if (v < 0) return math.pi;
    if (v > 0) return 0;
    return math.pi * 1.5;
  }

  void _texto(Canvas canvas, String s, Offset c) {
    final tp = TextPainter(text: TextSpan(text: s, style: estilo), textDirection: TextDirection.ltr)..layout(maxWidth: 140);
    final rect = Rect.fromCenter(center: c, width: tp.width + 8, height: tp.height + 2);
    canvas.drawRect(rect, Paint()..color = paper);
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    final nRings = math.min(radios.length, etiquetas.length - 1);
    final activoRedondo = activo.round();

    for (var k = 1; k <= nRings; k++) {
      final rr = r * radios[k - 1];
      final isActive = k == activoRedondo;
      canvas.drawCircle(c, rr, tinta(isActive ? ink : graphite, isActive ? 2.2 : 1));
    }
    canvas.drawCircle(c, 6, Paint()..color = ink);

    Offset at(int ring, int? v) {
      final a = angulo(v);
      return c + Offset(math.cos(a), math.sin(a)) * (r * radios[ring - 1]);
    }

    // La sombra: lo que decidiste con tu hermano.
    Offset? sombraPos;
    if (sombra != null) {
      sombraPos = at(1, sombra);
      canvas.drawCircle(sombraPos, 5, Paint()..color = graphite);
      canvas.drawPath(
        dashedPath(Path()..addOval(Rect.fromCircle(center: sombraPos, radius: 9)), dash: 3, gap: 3),
        tinta(graphite, 1.2),
      );
    }

    // Las decisiones en cada círculo, conectadas a la sombra.
    for (final entry in marcas.entries) {
      final v = entry.value;
      if (v == null || entry.key > nRings) continue;
      final pos = at(entry.key, v);
      if (sombraPos != null) {
        paintHilo(canvas, from: sombraPos, to: pos, color: graphite, provisional: true, width: 1.3, seed: entry.key, bend: 10);
      }
      canvas.drawCircle(pos, 6.5, Paint()..color = ink);
    }

    // La situación (el auto rayado) sobre el círculo activo.
    final valorActivo = marcas[activoRedondo];
    final a = angulo(valorActivo);
    final tokenR = _radio(activo, r);
    final token = c + Offset(math.cos(a), math.sin(a)) * tokenR + const Offset(0, -16);
    final rect = Rect.fromCenter(center: token, width: 22, height: 12);
    canvas.drawRect(rect, Paint()..color = paper);
    canvas.drawRect(rect, tinta(saffron, 1.8));
    final scratch = Path()..moveTo(rect.left + 3, rect.center.dy);
    for (var i = 1; i <= 4; i++) {
      scratch.lineTo(rect.left + 3 + i * 4, rect.center.dy + (i.isOdd ? -3 : 3));
    }
    canvas.drawPath(scratch, tinta(saffron, 1.4));

    // Etiquetas: el centro y cada círculo, abajo.
    _texto(canvas, etiquetas.first, c + const Offset(0, 18));
    for (var k = 1; k <= nRings; k++) {
      _texto(canvas, etiquetas[k], c + Offset(0, r * radios[k - 1]));
    }
    _texto(canvas, 'callar', c + Offset(-r * 0.92 + 18, -14));
    _texto(canvas, 'contar', c + Offset(r * 0.92 - 18, -14));
  }

  @override
  bool shouldRepaint(covariant CirculosPainter old) => true;
}

// ------------------------------------------------------- E8: dos supervivientes
/// «El original también sobrevivió»: la página se divide y hay dos figuras
/// completas. Tocar cada una pregunta «¿Cuál eres tú?». No hay respuesta
/// correcta y no se guarda: la decisión real se toma al volver a juzgar.
class DosFiguras extends ConsumerStatefulWidget {
  const DosFiguras({super.key});

  @override
  ConsumerState<DosFiguras> createState() => _DosFigurasState();
}

class _DosFigurasState extends ConsumerState<DosFiguras> {
  String? _tocada;
  String? _respuesta;

  static const opciones = [
    ('a', 'A, la original'),
    ('b', 'B, la que tiene tus recuerdos copiados'),
    ('ambas', 'Las dos'),
    ('ninguna', 'Ninguna'),
    ('nose', 'No lo sé'),
  ];

  void _tap(String id) {
    ref.read(feedbackProvider).selection();
    setState(() => _tocada = id);
  }

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    final show = ilustracionCabe(context);
    Widget boton(String id, String label) => Semantics(
          button: true,
          selected: _tocada == id,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => _tap(id),
            radius: 60,
            child: const SizedBox(width: 110, height: 190),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (show)
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            const h = 200.0;
            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: reduced ? 1 : 0, end: 1),
                        duration: reduced ? Duration.zero : const Duration(milliseconds: 1400),
                        curve: Motion.settle,
                        builder: (context, t, _) => CustomPaint(
                          painter: _DosFigurasPainter(t: t, tocada: _tocada, ink: e.ink, graphite: e.graphite, saffron: e.saffron),
                        ),
                      ),
                    ),
                  ),
                  Positioned(left: w * 0.27 - 55, top: 0, child: boton('a', 'Figura A, la original')),
                  Positioned(left: w * 0.73 - 55, top: 0, child: boton('b', 'Figura B, con tus recuerdos')),
                ],
              ),
            );
          })
        else
          Wrap(spacing: 8, children: [
            OutlinedButton(onPressed: () => _tap('a'), child: const Text('Figura A')),
            OutlinedButton(onPressed: () => _tap('b'), child: const Text('Figura B')),
          ]),
        if (_tocada == null)
          Text('Toca cada figura.', style: context.text.bodySmall)
        else ...[
          const Gap(8),
          Semantics(
            liveRegion: true,
            child: Text(
              _tocada == 'a'
                  ? 'A: el cuerpo original. Sobrevivió.'
                  : 'B: tus recuerdos, tu carácter y tus proyectos, en un cuerpo sano.',
              style: context.text.bodyMedium,
            ),
          ),
          const Gap(8),
          Text('¿Cuál eres tú?', style: context.text.headlineSmall),
          const Gap(4),
          for (final o in opciones)
            RuledOption(
              label: o.$2,
              selected: _respuesta == o.$1,
              onTap: () {
                ref.read(feedbackProvider).selection();
                setState(() => _respuesta = o.$1);
              },
            ),
          if (_respuesta != null) ...[
            const Gap(8),
            MarginNote('No hay respuesta correcta. Esto no se guarda: lo que decidas al volver a tu lado, sí.'),
          ],
        ],
      ],
    );
  }
}

class _DosFigurasPainter extends CustomPainter {
  _DosFigurasPainter({required this.t, required this.tocada, required this.ink, required this.graphite, required this.saffron});
  final double t;
  final String? tocada;
  final Color ink;
  final Color graphite;
  final Color saffron;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final suelo = h - 22;
    // La página se divide.
    final split = (t / 0.4).clamp(0.0, 1.0);
    canvas.drawLine(Offset(w / 2, h / 2 - (h / 2 - 4) * split), Offset(w / 2, h / 2 + (h / 2 - 4) * split), tinta(graphite, 1.2));
    final apart = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
    final xa = w / 2 - (w * 0.23) * apart;
    final xb = w / 2 + (w * 0.23) * apart;
    final alto = h - 40;
    figura(canvas, Offset(xa, suelo), alto, tinta(ink, tocada == 'a' ? 2.8 : 2.2), seed: 4);
    figura(canvas, Offset(xb, suelo), alto, tinta(ink, tocada == 'b' ? 2.8 : 2.2), rehecha: figuraPartes, seed: 4, opacidad: apart);
    canvas.drawCircle(Offset(xa, suelo + 12), 4, Paint()..color = ink);
    canvas.drawCircle(Offset(xb, suelo + 12), 4, Paint()..color = ink.withValues(alpha: apart));
    if (tocada != null) {
      final x = tocada == 'a' ? xa : xb;
      canvas.drawLine(Offset(x - 16, suelo + 20), Offset(x + 16, suelo + 20), tinta(saffron, 2.4));
    }
  }

  @override
  bool shouldRepaint(covariant _DosFigurasPainter old) => old.t != t || old.tocada != tocada || old.ink != ink;
}
