import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/arte.dart';
import '../../../widgets/composiciones.dart';
import '../../../widgets/paper.dart';
import '../experience_actions.dart';
import '../widgets/stage_frame.dart';

/// CRUZA: el punto se ancla, aparece el eje, el usuario cruza con un gesto
/// (o con el botón Cruzar) y la hoja cambia de cara. Su punto sigue visible a
/// trasluz y del otro lado aparece el punto hueco.
class CruzaAnchorStage extends ConsumerStatefulWidget {
  const CruzaAnchorStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  ConsumerState<CruzaAnchorStage> createState() => _CruzaAnchorStageState();
}

class _CruzaAnchorStageState extends ConsumerState<CruzaAnchorStage> with TickerProviderStateMixin {
  late final AnimationController _anchor = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _flip = AnimationController(vsync: this, duration: Motion.cross);
  double _drag = 0;
  bool _crossing = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = reducedMotionNow(context, ref);
    _flip.duration = reduced ? Motion.reduced : Motion.cross;
    if (reduced) {
      _anchor.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _anchor.forward().whenComplete(() {
          if (!mounted) return;
          ref.read(feedbackProvider).selection();
          setState(() {});
        });
      });
    }
  }

  @override
  void dispose() {
    _anchor.dispose();
    _flip.dispose();
    super.dispose();
  }

  bool get _anchored => _anchor.isCompleted;

  void _cross() {
    if (_crossing) return;
    setState(() => _crossing = true);
    ref.read(feedbackProvider).cross();
    _flip.forward();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.exp;
    final c = widget.progress.cruza;
    final stance = widget.progress.initialStance;
    final target = exp.pole(c?.target ?? 'left').label;
    final mine = stance == null || stance.value == 0 ? 'No lo sé' : stance.label;
    final e = context.enves;
    final reduced = reducedMotion(context, ref);

    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: widget.progress.stage,
      bottom: AnimatedBuilder(
        animation: Listenable.merge([_anchor, _flip]),
        builder: (context, _) => _flip.isCompleted
            ? FilledButton(
                key: const ValueKey('anchor_done'),
                onPressed: () => ref.read(experienceActionsProvider(exp.id)).anchorDone(),
                child: const Text('Entrar al taller'),
              )
            : FilledButton(
                key: const ValueKey('anchor_cross'),
                onPressed: _anchored && !_crossing ? _cross : null,
                child: const Text('Cruzar'),
              ),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragUpdate: !_anchored || _crossing
              ? null
              : (d) => setState(() => _drag = (_drag + d.delta.dx.abs() / (width * 0.55)).clamp(0.0, 1.0)),
          onHorizontalDragEnd: !_anchored || _crossing
              ? null
              : (_) {
                  if (_drag >= 0.45) {
                    _cross();
                  } else {
                    setState(() => _drag = 0);
                  }
                },
          child: AnimatedBuilder(
            animation: Listenable.merge([_anchor, _flip]),
            builder: (context, _) {
              final t = Motion.turn.transform(_flip.value);
              final flipped = t >= 0.5;
              final anchorT = Motion.settle.transform(_anchor.value);
              final revealT = flipped ? ((t - 0.5) * 2).clamp(0.0, 1.0) : 0.0;
              final face = _Cara(
                color: flipped ? e.reverse : e.paper,
                encabezado: flipped
                    ? 'Desde aquí, ¿cómo se ve?'
                    : (_anchored ? 'Tu postura queda anclada aquí' : 'Anclando tu postura'),
                cita: flipped ? target : mine,
                pie: flipped
                    ? 'A trasluz, tu postura sigue ahí: «$mine»'
                    : (_anchored && !_crossing
                        ? (reduced ? 'Toca Cruzar para pensar desde el otro lado.' : 'Desliza la hoja hacia el eje, o toca Cruzar.')
                        : null),
                painter: _AnclaPainter(
                  anchorT: anchorT,
                  drag: flipped ? 1 : math.max(_drag, _crossing ? 1 : 0),
                  flipped: flipped,
                  revealT: revealT,
                  c: Tinta.of(context),
                  fondo: flipped ? e.reverse : e.paper,
                ),
              );
              final Widget turned;
              if (reduced) {
                turned = Opacity(opacity: flipped ? revealT : (_crossing ? 1 - t * 2 : 1), child: face);
              } else {
                final pre = _crossing ? 0.0 : _drag * 0.35;
                final angle = flipped ? (1 - t) * math.pi : t * math.pi + pre;
                turned = Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(flipped ? -angle : angle),
                  child: face,
                );
              }
              return Semantics(
                liveRegion: true,
                label: flipped
                    ? 'Cruzaste. Desde aquí, ¿cómo se ve? Ahora piensas desde: $target. Tu postura sigue anclada: $mine.'
                    : 'Tu postura queda anclada: $mine. Usa el botón Cruzar para pensar desde el otro lado.',
                child: ExcludeSemantics(child: turned),
              );
            },
          ),
        );
      }),
    );
  }
}

class _Cara extends StatelessWidget {
  const _Cara({required this.color, required this.encabezado, required this.cita, required this.painter, this.pie});
  final Color color;
  final String encabezado;
  final String cita;
  final String? pie;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 340),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: color, border: Border.all(color: context.enves.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 290, width: double.infinity, child: CustomPaint(painter: painter)),
          const Gap(20),
          Text(encabezado, style: context.text.labelMedium),
          const Gap(8),
          Text('«$cita»', style: context.text.headlineSmall),
          if (pie != null) ...[
            const Gap(20),
            Text(pie!, style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Dos bustos a cada lado del eje. Tu punto cae y se ancla junto a ti; el
/// hilo se tensa con el gesto. Del otro lado, la otra perspectiva pasa de
/// contorno a figura, y la tuya queda a trasluz.
class _AnclaPainter extends CustomPainter {
  _AnclaPainter({
    required this.anchorT,
    required this.drag,
    required this.flipped,
    required this.revealT,
    required this.c,
    required this.fondo,
  });
  final double anchorT;
  final double drag;
  final bool flipped;
  final double revealT;
  final Tinta c;
  final Color fondo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final b = math.min(h * 0.86, w * 0.38);
    final left = Rect.fromLTWH(0, h - b, b, b);
    final right = Rect.fromLTWH(w - b, h - b, b, b);
    final y = h - b * 0.66;
    // Un plano de papel detrás de quien ocupa este lado.
    plano(canvas, Rect.fromLTWH(left.left + b * 0.08, h * 0.12, w * 0.4, h * 0.88), flipped ? c.plane2 : c.plane, sombra: c.ink);
    const r = 11.0;
    final axis = linea(c.ink, 3.2);

    if (!flipped) {
      // Tú, sólido; la otra perspectiva, solo contorno.
      canvas.drawPath(busto(left), relleno(c.ink));
      final otra = busto(right, derecha: false);
      canvas.drawPath(otra, relleno(fondo));
      canvas.drawPath(otra, linea(c.ink2, 1.6));
      final dropT = (anchorT / 0.5).clamp(0.0, 1.0);
      final dot = Offset(left.right + 14, y - 26 * (1 - dropT));
      canvas.drawCircle(dot, r, relleno(c.ink));
      final axisT = ((anchorT - 0.4) / 0.6).clamp(0.0, 1.0);
      if (axisT > 0) canvas.drawLine(Offset(cx, h * 0.5 - h * 0.5 * axisT), Offset(cx, h * 0.5 + h * 0.5 * axisT), axis);
      if (drag > 0) hilo(canvas, dot + const Offset(r, 0), Offset(cx - 5, y), c.ink, w: 1.8, t: drag);
      return;
    }

    // Otra cara: la otra perspectiva ocupa tu lugar; tú quedas a trasluz.
    final mia = busto(right, derecha: false);
    canvas.drawPath(mia, relleno(c.ink.withValues(alpha: 0.16)));
    final otraT = revealT;
    canvas.drawPath(busto(left), relleno(Color.lerp(fondo, c.ink2, otraT)!));
    canvas.drawLine(Offset(cx, 0), Offset(cx, h), axis);
    final mine = Offset(right.left - 14, y);
    canvas.drawCircle(mine, r, relleno(c.ink.withValues(alpha: 0.2)));
    hilo(canvas, mine - const Offset(r, 0), Offset(cx + 5, y), c.ink.withValues(alpha: 0.2), w: 1.8);
    final hollow = Offset(left.right + 14, y);
    hilo(canvas, Offset(cx - 5, y), hollow + const Offset(r, 0), c.ink, w: 1.8, t: revealT);
    if (revealT > 0.6) puntoHueco(canvas, hollow, r * ((revealT - 0.6) / 0.4).clamp(0.0, 1.0), c.saffron, fondo);
  }

  @override
  bool shouldRepaint(covariant _AnclaPainter old) =>
      old.anchorT != anchorT || old.drag != drag || old.flipped != flipped || old.revealT != revealT || old.c != c;
}
