import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/arte.dart';
import '../../../widgets/composiciones.dart';
import '../../../widgets/hilo_vivo.dart';
import '../../../widgets/ilustraciones.dart';
import '../../../widgets/paper.dart';

// ------------------------------------------------------------ E1: la escena
/// La misma escena para Ana y para Beto, y a la vez el selector: la ficha
/// corre por el borde de la calle. [t] = 0 es Ana, 1 es Beto. Lo común
/// (calle, auto, conductor, teléfono) no se mueve; solo aparece el niño.
class EscenaComparada extends StatelessWidget {
  const EscenaComparada({
    super.key,
    required this.t,
    required this.nombreA,
    required this.nombreB,
    required this.onChanged,
    required this.onSoltar,
    this.height = 190,
  });
  final double t;
  final String nombreA;
  final String nombreB;
  final ValueChanged<double> onChanged;
  final VoidCallback onSoltar;
  final double height;

  static const _pad = 22.0;

  @override
  Widget build(BuildContext context) {
    final tinta = Tinta.of(context);
    final h = ilustracionCabe(context) ? height : 64.0;
    String estado(double v) => v < 0.5 ? '$nombreA: no pasa nada' : '$nombreB: un niño cruza';
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      double valor(double dx) => ((dx - _pad) / (w - _pad * 2)).clamp(0.0, 1.0);
      return Semantics(
        slider: true,
        label: 'Comparar las escenas de $nombreA y $nombreB',
        value: estado(t),
        increasedValue: estado(1),
        decreasedValue: estado(0),
        onIncrease: () => onChanged(1),
        onDecrease: () => onChanged(0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => onChanged(valor(d.localPosition.dx)),
          onHorizontalDragEnd: (_) => onSoltar(),
          onTapUp: (d) {
            onChanged(valor(d.localPosition.dx));
            onSoltar();
          },
          child: CustomPaint(
            size: Size(w, h),
            painter: _EscenaPainter(t, tinta, compacta: h < 100),
          ),
        ),
      );
    });
  }
}

class _EscenaPainter extends CustomPainter {
  _EscenaPainter(this.t, this.c, {this.compacta = false});
  final double t;
  final Tinta c;
  final bool compacta;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final roadTop = compacta ? 0.0 : h * 0.6;
    final roadBottom = compacta ? h * 0.7 : h * 0.9;
    if (!compacta) {
      // Plano de fondo: un recorte de papel detrás del auto.
      plano(canvas, Rect.fromLTWH(w * 0.05, h * 0.12, w * 0.5, h * 0.5), c.plane, sombra: c.ink);
      // La calle: un gran plano.
      canvas.drawRect(Rect.fromLTRB(0, roadTop, w, roadBottom), relleno(c.plane2));
      canvas.drawLine(Offset(0, roadTop), Offset(w, roadTop), linea(c.ink, 2));
      // Línea central y paso peatonal, iguales en las dos escenas.
      final mid = (roadTop + roadBottom) / 2;
      for (var x = 6.0; x < w * 0.6; x += 34) {
        canvas.drawRect(Rect.fromLTWH(x, mid - 1.5, 18, 3), relleno(c.paper));
      }
      for (var x = w * 0.66; x < w * 0.95; x += w * 0.045) {
        canvas.drawRect(Rect.fromLTWH(x, roadTop + 4, w * 0.024, roadBottom - roadTop - 8), relleno(c.paper));
      }
      // Auto, conductor y teléfono: la conducta, idéntica.
      final carW = math.min(w * 0.58, (roadBottom - h * 0.06) * 2.2);
      final carH = carW * 0.42;
      final win = dibujarAuto(canvas, Rect.fromLTWH(w * 0.07, roadBottom - 10 - carH, carW, carH), c);
      canvas.save();
      canvas.clipRect(win);
      canvas.drawPath(
        busto(Rect.fromLTWH(win.left + win.width * 0.04, win.top + win.height * 0.06, win.width * 0.66, win.height * 1.0)),
        relleno(c.ink2),
      );
      canvas.restore();
      final phone = Rect.fromLTWH(win.left + win.width * 0.66, win.top + win.height * 0.34, win.width * 0.15, win.height * 0.46);
      dibujarTelefono(canvas, phone, c.saffron, c.paper);
      for (var i = 0; i < 2; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: phone.topCenter, radius: phone.height * (0.55 + i * 0.4)),
          -math.pi * 0.85,
          math.pi * 0.7,
          false,
          linea(c.saffron, 1.6),
        );
      }
      // Lo único que cambia: un niño en el paso peatonal.
      if (t > 0.01) {
        final fh = (roadBottom - h * 0.06) * 0.5;
        final fw = fh * 100 / 260;
        final x = w * 0.8 - fw / 2 + 24 * (1 - t);
        final col = c.ink.withValues(alpha: t);
        dibujarSilueta(canvas, Rect.fromLTWH(x, roadBottom - 6 - fh, fw, fh), col,
            derecha: false, nino: true, paso: 0.9, atras: c.ink2.withValues(alpha: t), papel: c.plane2);
      }
    }
    // El recorrido de la ficha, sobre el borde inferior de la calle.
    const pad = EscenaComparada._pad;
    final ty = compacta ? h * 0.35 : roadBottom + (h - roadBottom) / 2;
    canvas.drawLine(Offset(pad, ty), Offset(w - pad, ty), linea(c.ink, 2));
    canvas.drawLine(Offset(pad, ty - 6), Offset(pad, ty + 6), linea(c.ink, 2));
    canvas.drawLine(Offset(w - pad, ty - 6), Offset(w - pad, ty + 6), linea(c.ink, 2));
    final x = pad + (w - pad * 2) * t;
    canvas.drawCircle(Offset(x, ty), 12, relleno(c.paper));
    canvas.drawCircle(Offset(x, ty), 10.5, linea(c.ink, 3));
    canvas.drawCircle(Offset(x, ty), 4, relleno(c.ink));
  }

  @override
  bool shouldRepaint(covariant _EscenaPainter old) => old.t != t || old.c != c || old.compacta != compacta;
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
            const h = 230.0;
            final hermana = _PromesaPainter.hermanaEn(Size(w, h));
            final turno = _PromesaPainter.turnoEn(Size(w, h));
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
                          painter: _PromesaPainter(saber: saber, tocado: _tocado, c: Tinta.of(context)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(left: hermana.dx - 36, top: hermana.dy - 36, child: boton('hermana', 'Tu hermana: qué depende de ti')),
                  Positioned(left: turno.dx - 36, top: turno.dy - 36, child: boton('turno', 'El turno extra: qué depende de esta decisión')),
                  Positioned(
                    left: w * 0.3,
                    top: h * 0.12,
                    child: ExcludeSemantics(child: Text('la promesa', style: context.text.labelMedium?.copyWith(color: e.saffronText))),
                  ),
                  Positioned(
                    left: w * 0.36,
                    top: h * 0.86,
                    child: ExcludeSemantics(child: Text('el turno', style: context.text.labelMedium)),
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
  _PromesaPainter({required this.saber, required this.tocado, required this.c});
  final double saber;
  final String? tocado;
  final Tinta c;

  static Offset hermanaEn(Size s) => Offset(s.width * 0.76, s.height * 0.24);
  static Offset turnoEn(Size s) => Offset(s.width * 0.68, s.height * 0.8);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    // El escenario de la presentación: un plano recortado arriba a la derecha.
    final stage = Rect.fromLTWH(w * 0.56, h * 0.02, w * 0.4, h * 0.46);
    plano(canvas, stage, c.plane, sombra: c.ink);
    canvas.drawLine(Offset(stage.left + 8, stage.bottom - 10), Offset(stage.right - 8, stage.bottom - 10), linea(c.ink, 2.4));
    // Tú, grande, a la izquierda.
    final fh = h * 0.96;
    final fw = fh * 100 / 260;
    final me = Rect.fromLTWH(w * 0.06, h - fh, fw, fh);
    dibujarSilueta(canvas, me, c.ink, atras: c.ink2, papel: c.paper);
    // Tu hermana, en escena.
    final sh = stage.height * 0.8;
    final sister = Rect.fromLTWH(w * 0.76 - sh * 0.2, stage.bottom - 10 - sh, sh * 100 / 260, sh);
    dibujarSilueta(canvas, sister, c.ink, derecha: false, nino: true, gesto: 1, atras: c.ink2, papel: c.plane);
    // El turno: reloj y recibo de la deuda.
    final clock = turnoEn(s);
    dibujarReloj(canvas, clock, h * 0.085, c);
    dibujarRecibo(canvas, Rect.fromLTWH(w * 0.8, h * 0.6, w * 0.12, h * 0.34), c, giro: 0.1);

    final mano = Offset(me.left + me.width * 0.78, me.top + me.height * 0.52);
    final manoH = Offset(sister.left + sister.width * 0.1, sister.top + sister.height * 0.2);
    // La promesa: el hilo azafrán, tenso. Si la tocas, se engrosa.
    canvas.drawLine(mano, manoH, linea(c.saffron, tocado == 'hermana' ? 3.6 : 2.6));
    canvas.drawCircle(Offset.lerp(mano, manoH, 0.5)!, 5, relleno(c.saffron));
    // El turno: otra dirección, en tinta suave.
    canvas.drawLine(mano, clock - Offset(h * 0.09, 0), linea(tocado == 'turno' ? c.ink : c.ink2, tocado == 'turno' ? 2.6 : 1.8));
    // Lo que ella sabe: un hilo fino de vuelta hacia ti, que se apaga.
    if (saber > 0.01) {
      final cabezaH = Offset(sister.left + sister.width * 0.4, sister.top + sister.height * 0.08);
      final cabezaY = Offset(me.left + me.width * 0.62, me.top + me.height * 0.08);
      canvas.drawPath(
        dashedPath(Path()
          ..moveTo(cabezaH.dx, cabezaH.dy)
          ..quadraticBezierTo((cabezaH.dx + cabezaY.dx) / 2, cabezaY.dy - h * 0.1, cabezaY.dx, cabezaY.dy), dash: 4, gap: 4),
        linea(c.graphite.withValues(alpha: saber), 1.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PromesaPainter old) => old.saber != saber || old.tocado != tocado || old.c != c;
}

// --------------------------------------------------- E3: círculos de cercanía
/// Círculos de cercanía como planos de papel. En el centro tú; en cada
/// círculo, la persona. La decisión con tu hermano queda como sombra.
class CirculosPainter extends CustomPainter {
  CirculosPainter({
    required this.activo,
    required this.marcas,
    required this.sombra,
    required this.c,
    required this.etiquetas,
    required this.estilo,
  });

  /// Círculo activo (2…n), interpolado durante la animación.
  final double activo;

  /// Círculo → decisión (−1 callar, 0 no sé, 1 contar).
  final Map<int, int?> marcas;

  /// La decisión original, con el hermano.
  final int? sombra;
  final Tinta c;
  final List<String> etiquetas;
  final TextStyle estilo;

  static const radios = [0.36, 0.64, 0.94];

  static double angulo(int? v) {
    if (v == null) return math.pi * 1.25;
    if (v < 0) return math.pi;
    if (v > 0) return 0;
    return math.pi * 1.5;
  }

  void _texto(Canvas canvas, String s, Offset at) {
    final tp = TextPainter(text: TextSpan(text: s, style: estilo), textDirection: TextDirection.ltr)..layout(maxWidth: 140);
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cc = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;
    final n = math.min(radios.length, etiquetas.length - 1);
    final act = activo.round();
    // Planos concéntricos, del más lejano al más cercano.
    for (var k = n; k >= 1; k--) {
      canvas.drawCircle(cc, r * radios[k - 1], relleno(k.isOdd ? c.plane : c.plane2));
      canvas.drawCircle(cc, r * radios[k - 1], k == act ? linea(c.ink, 2.4) : linea(c.ink2, 0.8));
    }
    Offset at(int ring, int? v) {
      final a = angulo(v);
      return cc + Offset(math.cos(a), math.sin(a)) * (r * radios[ring - 1]);
    }

    // Tú, al centro.
    final b = r * 0.36;
    canvas.drawPath(busto(Rect.fromCenter(center: cc + Offset(0, -b * 0.08), width: b, height: b)), relleno(c.ink));
    // Las personas de cada círculo, abajo.
    for (var k = 1; k <= n; k++) {
      final p = cc + Offset(0, r * radios[k - 1]);
      final bb = b * (0.62 - k * 0.08);
      canvas.drawPath(busto(Rect.fromCenter(center: p - Offset(0, bb * 0.62), width: bb, height: bb)), relleno(k == act ? c.ink : c.ink2));
      _texto(canvas, etiquetas[k], p + const Offset(0, 9));
    }
    // La sombra: lo que decidiste con tu hermano.
    Offset? sombraPos;
    if (sombra != null) {
      sombraPos = at(1, sombra);
      canvas.drawCircle(sombraPos, 7, relleno(c.graphite));
    }
    for (final e in marcas.entries) {
      if (e.value == null || e.key > n) continue;
      final pos = at(e.key, e.value);
      if (sombraPos != null) canvas.drawLine(sombraPos, pos, linea(c.graphite, 1.4));
      canvas.drawCircle(pos, 8, relleno(c.ink));
    }
    // La situación (el auto rayado), sobre el círculo activo.
    final ia = (activo - 1).clamp(0.0, radios.length - 1.0);
    final lo = ia.floor();
    final hi = ia.ceil();
    final tokenR = r * (radios[lo] + (radios[hi] - radios[lo]) * (ia - lo));
    final a = angulo(marcas[act]);
    final tok = cc + Offset(math.cos(a), math.sin(a)) * tokenR + const Offset(0, -18);
    final rect = Rect.fromCenter(center: tok, width: 30, height: 15);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.shift(const Offset(2, 2)), const Radius.circular(3)), relleno(c.ink.withValues(alpha: 0.12)));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), relleno(c.ink));
    final scratch = Path()..moveTo(rect.left + 5, rect.center.dy);
    for (var i = 1; i <= 4; i++) {
      scratch.lineTo(rect.left + 5 + i * 5, rect.center.dy + (i.isOdd ? -3.5 : 3.5));
    }
    canvas.drawPath(scratch, linea(c.saffron, 2));
    _texto(canvas, 'callar', cc + Offset(-r * radios[n - 1] + 26, -12));
    _texto(canvas, 'contar', cc + Offset(r * radios[n - 1] - 26, -12));
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
            const h = 230.0;
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
                          painter: _DosFigurasPainter(t: t, tocada: _tocada, c: Tinta.of(context)),
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
  _DosFigurasPainter({required this.t, required this.tocada, required this.c});
  final double t;
  final String? tocada;
  final Tinta c;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    // La página se divide en dos planos.
    final split = (t / 0.4).clamp(0.0, 1.0);
    plano(canvas, Rect.fromLTWH(w * 0.5 - w * 0.46 * split, h * 0.06, w * 0.44 * split, h * 0.9), c.plane, sombra: c.ink);
    plano(canvas, Rect.fromLTWH(w * 0.52, h * 0.02, w * 0.44 * split, h * 0.86), c.plane2, sombra: c.ink);
    final apart = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
    final fh = h * 0.92;
    final fw = fh * 100 / 260;
    final xa = w / 2 - fw / 2 - w * 0.23 * apart;
    final xb = w / 2 - fw / 2 + w * 0.23 * apart;
    final ra = Rect.fromLTWH(xa, h - fh, fw, fh);
    final rb = Rect.fromLTWH(xb, h - fh, fw, fh);
    dibujarSilueta(canvas, ra, c.ink, atras: c.ink2, papel: c.plane);
    if (apart > 0.05) figuraRehecha(canvas, rb, c, siluetaPartes, derecha: false);
    canvas.drawLine(Offset(w / 2, h * 0.5 - h * 0.5 * split), Offset(w / 2, h * 0.5 + h * 0.5 * split), linea(c.ink, 2.4));
    if (tocada != null) {
      final r = tocada == 'a' ? ra : rb;
      canvas.drawLine(Offset(r.center.dx - 22, h - 3), Offset(r.center.dx + 22, h - 3), linea(c.saffron, 3));
    }
  }

  @override
  bool shouldRepaint(covariant _DosFigurasPainter old) => old.t != t || old.tocada != tocada || old.c != c;
}
