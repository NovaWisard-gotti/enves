import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/margen_vivo.dart';
import '../../../widgets/paper.dart';
import '../experience_actions.dart';
import '../probes/escenas.dart';
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
            if (exp.deepDive.problem.isNotEmpty)
              VerElEnves(
                titulo: 'La pregunta de fondo',
                texto: exp.deepDive.problem,
                child: Text(exp.twist.text, style: context.text.headlineSmall),
              )
            else
              Text(exp.twist.text, style: context.text.headlineSmall),
            const Gap(20),
            if (probe == null && exp.id.startsWith('e8')) ...[
              const DosFiguras(),
              const Gap(12),
            ],
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
