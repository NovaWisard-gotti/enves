import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/ink_marks.dart';
import '../../../widgets/paper.dart';
import '../../deep_dive/deep_dive_sheet.dart';
import '../experience_actions.dart';
import '../probes/probes.dart';
import '../widgets/stage_frame.dart';

class TwistStage extends ConsumerWidget {
  const TwistStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(experienceActionsProvider(exp.id));
    final probe = exp.twistProbe;
    final reduced = reducedMotion(context, ref);
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      bottom: probe == null
          ? FilledButton(
              key: const ValueKey('twist_continue'),
              onPressed: actions.continueTwist,
              child: const Text('Seguir'),
            )
          : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: reduced ? Duration.zero : Motion.back,
        curve: Motion.settle,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text('Vuelves a tu lado, con algo más.', style: context.text.labelMedium),
            ),
            const Gap(12),
            Text(exp.twist.text, style: context.text.headlineSmall),
            const Gap(20),
            if (probe != null)
              ProbeView(
                experienceId: exp.id,
                probe: probe,
                onDone: (result) => actions.submitProbe(probe.id, result),
              ),
          ],
        ),
      ),
    );
  }
}

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

    String stanceLine(StanceRecord s) =>
        s.value == 0 ? 'No lo sé' : '${s.label} (${s.confidence})';

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
          Text(exp.reflection, style: context.text.headlineSmall),
          const Gap(24),
          if (axes.isNotEmpty)
            MarginNote(
              'Tu mapa cambió',
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in axes)
                      Text('${a.left} / ${a.right}', style: context.text.bodySmall),
                  ],
                ),
              ),
            ),
          if (exp.openQuestion) ...[
            const Gap(16),
            Text('Esta pregunta queda abierta: también la verás en tu mapa.', style: context.text.bodySmall),
          ],
          if (isLast) ...[
            const Gap(32),
            const CrossGlyph(),
            const Gap(12),
            Text('Terminaste el recorrido.', style: context.text.titleLarge),
            const Gap(6),
            Text(
              'Nueve preguntas, nueve veces del otro lado. Tu mapa guarda lo que pensaste y cómo lo pensaste.',
              style: context.text.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}
