import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/hilo_vivo.dart';
import '../../../widgets/ink_marks.dart';
import '../../../widgets/margen_vivo.dart';
import '../../../widgets/paper.dart';
import '../../deep_dive/deep_dive_sheet.dart';
import '../../onboarding/onboarding_screen.dart' show kOnboardingQuestion;
import '../experience_actions.dart';
import '../widgets/stage_frame.dart';

class ReflectionStage extends ConsumerWidget {
  const ReflectionStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    final user = ref.watch(userStateProvider).valueOrNull;
    final initial = progress.initialStance;
    final last = progress.finalStance;
    final isLast = content != null &&
        user != null &&
        content.experiences.every((e) => e.id == exp.id || user.experiences[e.id]?.status == ExpStatus.completed);
    final axes = exp.map.map((m) => content?.axis(m.axis)).whereType<AxisDef>().toSet().toList();
    final reduced = reducedMotion(context, ref);

    String stanceLine(StanceRecord s) => s.value == 0 ? 'No lo sé' : '${s.label} (${s.confidence})';

    final hollows = user == null
        ? 0
        : user.experiences.values
            .where((p) =>
                p.cruza?.finalRecognition != null && (p.status == ExpStatus.completed || p.experienceId == exp.id))
            .length;

    final reflection = Text(exp.reflection, style: context.text.headlineSmall);

    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (content != null)
            TextButton(
              onPressed: () => showExperienceDeepDive(context, content, exp),
              child: const Text('Profundizar'),
            ),
          FilledButton(
            key: const ValueKey('reflection_finish'),
            onPressed: () async {
              await ref.read(experienceActionsProvider(exp.id)).finish();
              if (context.mounted) context.go('/');
            },
            child: const Text('Terminar'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (initial != null && last != null) ...[
            _AntesDespues(initial: initial, last: last, outcome: progress.tension?.outcome),
            const Gap(8),
            Text('Al entrar', style: context.text.labelMedium),
            Text(stanceLine(initial), style: context.text.bodyLarge),
            const Gap(8),
            Text('Al volver', style: context.text.labelMedium),
            Text(
              initial.value == last.value ? '${stanceLine(last)}. Igual que antes.' : stanceLine(last),
              style: context.text.bodyLarge,
            ),
            const Gap(24),
          ],
          if (exp.deepDive.objection.isNotEmpty)
            VerElEnves(titulo: 'La objeción más fuerte', texto: exp.deepDive.objection, child: reflection)
          else
            reflection,
          const Gap(24),
          if (axes.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // El punto hueco viaja a tu mapa.
                ExcludeSemantics(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduced ? 1 : 0, end: 1),
                    duration: reduced ? Duration.zero : const Duration(milliseconds: 1100),
                    curve: Motion.settle,
                    builder: (context, t, _) => SizedBox(
                      width: 34,
                      height: 30,
                      child: Align(
                        alignment: Alignment(-1 + t * 2, -1 + t),
                        child: InkDot(style: DotStyle.hollow, size: 14, color: context.enves.saffron),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: MarginNote(
                    'Tu mapa cambió',
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final a in axes) Text('${a.left} / ${a.right}', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (exp.openQuestion) ...[
            const Gap(16),
            Text('Esta pregunta queda abierta: también la verás en tu mapa.', style: context.text.bodySmall),
          ],
          if (content != null && content.visibleReferences(exp.deepDive.referenceIds).isNotEmpty) ...[
            const Gap(16),
            MargenVivo(
              marca: 'Lecturas para seguir pensando',
              texto: content.visibleReferences(exp.deepDive.referenceIds).map((r) => r.formatted).join('\n\n'),
            ),
          ],
          if (isLast) ...[
            const Gap(36),
            const HiloFirma(
              width: 260,
              height: 48,
              tocable: true,
              semanticLabel: 'Tu punto, el eje y del otro lado un punto hueco: comprender sin fundirse.',
            ),
            const Gap(16),
            Text('Volviste al principio.', style: context.text.titleLarge),
            const Gap(8),
            Text('Al entrar te preguntamos:', style: context.text.labelMedium),
            const Gap(4),
            Text(kOnboardingQuestion, style: context.text.headlineSmall),
            if (user.onboarding != null) ...[
              const Gap(6),
              Text('Respondiste: «${user.onboarding!.stance.label}».', style: context.text.bodyLarge),
            ],
            const Gap(12),
            Text(
              'Ahora llevas $hollows ${hollows == 1 ? 'vez' : 'veces'} del otro lado. '
              'Tu mapa guarda lo que pensaste y cómo lo pensaste. La pregunta sigue siendo tuya.',
              style: context.text.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}

/// Antes y después sobre una sola línea. El hilo entre ambos dice qué pasó:
/// se refuerza si te mantuviste, se curva si cambiaste, se bifurca si matizaste.
class _AntesDespues extends ConsumerWidget {
  const _AntesDespues({required this.initial, required this.last, this.outcome});
  final StanceRecord initial;
  final StanceRecord last;
  final String? outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    final HiloForma forma;
    if (outcome == TensionOutcomeKind.matizar) {
      forma = HiloForma.bifurcado;
    } else if (initial.value == last.value) {
      forma = HiloForma.reforzado;
    } else {
      forma = HiloForma.curvo;
    }
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: reduced ? Duration.zero : Motion.long,
        curve: Motion.settle,
        builder: (context, t, _) => CustomPaint(
          size: const Size(double.infinity, 54),
          painter: _AntesDespuesPainter(
            a: initial.value,
            b: last.value,
            forma: forma,
            t: t,
            ink: e.ink,
            graphite: e.graphite,
          ),
        ),
      ),
    );
  }
}

class _AntesDespuesPainter extends CustomPainter {
  _AntesDespuesPainter({
    required this.a,
    required this.b,
    required this.forma,
    required this.t,
    required this.ink,
    required this.graphite,
  });
  final int a;
  final int b;
  final HiloForma forma;
  final double t;
  final Color ink;
  final Color graphite;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 20.0;
    final cy = size.height * 0.62;
    final half = (size.width - pad * 2) / 2;
    final cx = size.width / 2;
    double x(int v) => cx + v / 3 * half;
    canvas.drawLine(Offset(pad, cy), Offset(size.width - pad, cy), Paint()
      ..color = graphite
      ..strokeWidth = 1);
    canvas.drawLine(Offset(cx, cy - 14), Offset(cx, cy + 14), Paint()
      ..color = ink
      ..strokeWidth = 2.4);
    final pa = Offset(x(a), cy);
    final pb = Offset(x(b), cy);
    // Antes: un punto en grafito. Si la postura cambió, el grafito se borra
    // suavemente mientras el hilo llega a la nueva.
    final changed = (pb - pa).distance > 2;
    canvas.drawCircle(pa, 7, Paint()
      ..color = changed ? graphite.withValues(alpha: graphite.a * (1 - 0.65 * t)) : graphite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);
    if (changed) {
      paintHilo(canvas, from: pa, to: pb, color: ink, progress: t, forma: forma, seed: 2, bend: -18);
    } else {
      // Se mantuvo: el punto se refuerza con un segundo trazo a su alrededor.
      canvas.drawArc(Rect.fromCircle(center: pa, radius: 12), -1.6, 6.28 * t, false, Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round);
    }
    if (t >= 0.95) canvas.drawCircle(pb, 7, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(covariant _AntesDespuesPainter old) => old.t != t || old.ink != ink;
}
