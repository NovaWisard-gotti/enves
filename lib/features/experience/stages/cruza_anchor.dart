import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/hilo_vivo.dart';
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
                  ink: e.ink,
                  graphite: e.graphite,
                  saffron: e.saffron,
                  paper: flipped ? e.reverse : e.paper,
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
          SizedBox(height: 96, width: double.infinity, child: CustomPaint(painter: painter)),
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

/// El punto que cae y se ancla, el eje que se traza, el hilo que se tensa con
/// el gesto y, del otro lado, el punto hueco con el propio a trasluz.
class _AnclaPainter extends CustomPainter {
  _AnclaPainter({
    required this.anchorT,
    required this.drag,
    required this.flipped,
    required this.revealT,
    required this.ink,
    required this.graphite,
    required this.saffron,
    required this.paper,
  });
  final double anchorT;
  final double drag;
  final bool flipped;
  final double revealT;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height * 0.55;
    final cx = size.width / 2;
    const r = 11.0;
    final left = Offset(28, cy);
    final right = Offset(size.width - 28, cy);
    final axis = Paint()
      ..color = ink
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    if (!flipped) {
      // El punto cae y se ancla.
      final dropT = (anchorT / 0.5).clamp(0.0, 1.0);
      final dot = Offset(left.dx, cy - 30 * (1 - dropT));
      canvas.drawCircle(dot, r, Paint()..color = ink);
      if (dropT >= 1) {
        canvas.drawLine(Offset(left.dx - 10, cy + r + 6), Offset(left.dx + 10, cy + r + 6), Paint()
          ..color = ink
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
      }
      // El eje aparece.
      final axisT = ((anchorT - 0.4) / 0.6).clamp(0.0, 1.0);
      if (axisT > 0) {
        final half = size.height * 0.45 * axisT;
        canvas.drawLine(Offset(cx, cy - half), Offset(cx, cy + half), axis);
      }
      // El hilo se tensa hacia el eje con el gesto.
      if (drag > 0) {
        paintHilo(canvas, from: left + const Offset(r, 0), to: Offset(cx - 4, cy), color: ink, progress: drag, seed: 3);
      }
      // Del otro lado, todavía en grafito.
      if (axisT >= 1) {
        const seg = 10;
        final g = Paint()
          ..color = graphite
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        for (var i = 0; i < seg; i++) {
          canvas.drawArc(Rect.fromCircle(center: right, radius: r - 2), i * 2 * math.pi / seg, math.pi / seg, false, g);
        }
      }
      return;
    }

    // Otra cara: el eje sigue; el propio punto se ve a trasluz, invertido.
    canvas.drawLine(Offset(cx, cy - size.height * 0.45), Offset(cx, cy + size.height * 0.45), axis);
    canvas.drawCircle(right, r, Paint()..color = ink.withValues(alpha: 0.22));
    paintHilo(
      canvas,
      from: right - const Offset(r, 0),
      to: Offset(cx + 4, cy),
      color: ink.withValues(alpha: 0.22),
      seed: 3,
    );
    // El hilo atraviesa el eje y llega al punto hueco.
    paintHilo(canvas, from: Offset(cx - 4, cy), to: left + const Offset(r, 0), color: ink, progress: revealT, seed: 4);
    if (revealT > 0.6) {
      final k = ((revealT - 0.6) / 0.4).clamp(0.0, 1.0);
      canvas.drawCircle(left, (r - 2) * k, Paint()
        ..color = saffron
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4);
    }
  }

  @override
  bool shouldRepaint(covariant _AnclaPainter old) =>
      old.anchorT != anchorT || old.drag != drag || old.flipped != flipped || old.revealT != revealT || old.ink != ink;
}
