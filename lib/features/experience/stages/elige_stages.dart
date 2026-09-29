import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../engine/experience/experience_engine.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/balanza.dart';
import '../../../widgets/paper.dart';
import '../experience_actions.dart';
import '../probes/probes.dart';
import '../widgets/stage_frame.dart';

/// Situación del caso, simple o en dos columnas gemelas.
class ScenarioView extends StatelessWidget {
  const ScenarioView(this.scenario, {super.key});
  final ScenarioDef scenario;

  @override
  Widget build(BuildContext context) {
    final paragraphs = [
      for (final p in scenario.paragraphs)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(p, style: context.text.bodyLarge)),
    ];
    if (!scenario.isTwin) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: paragraphs);
    }
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    Widget column(TwinColumn c) => Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name, style: context.text.titleMedium),
              const Gap(6),
              for (final line in c.lines)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: context.text.bodyLarge)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...paragraphs,
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth / 2 < 150 * scale) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [column(scenario.twin[0]), const Divider(), const Gap(8), column(scenario.twin[1])],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: column(scenario.twin[0])),
                const VerticalDivider(width: 24),
                Expanded(child: column(scenario.twin[1])),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class IntroStage extends ConsumerWidget {
  const IntroStage({super.key, required this.exp, required this.outOfOrder, required this.wasSkipped});
  final ExperienceDef exp;
  final bool outOfOrder;
  final bool wasSkipped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(experienceActionsProvider(exp.id));
    return PaperPage(
      title: exp.title,
      onBack: () => context.canPop() ? context.pop() : context.go('/'),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(key: const ValueKey('intro_start'), onPressed: actions.start, child: const Text('Empezar')),
          if (!wasSkipped)
            TextButton(
              onPressed: () async {
                await actions.skip();
                if (context.mounted) context.go('/');
              },
              child: const Text('Omitir esta pregunta'),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(24),
          Semantics(header: true, child: Text(exp.question, style: context.text.displaySmall)),
          const Gap(24),
          if (exp.sensitive && exp.sensitiveNote.isNotEmpty) ...[
            MarginNote('${exp.sensitiveNote} Puedes omitirla.'),
            const Gap(16),
          ],
          if (outOfOrder) ...[
            MarginNote('Esta pregunta suele venir más adelante. Algunas conexiones pueden no aparecer.'),
            const Gap(16),
          ],
          if (wasSkipped) ...[
            Text('La omitiste antes. Puedes hacerla ahora.', style: context.text.bodySmall),
            const Gap(16),
          ],
        ],
      ),
    );
  }
}

class ProbeStage extends ConsumerWidget {
  const ProbeStage({super.key, required this.exp, required this.probe, required this.progress});
  final ExperienceDef exp;
  final ProbeDef probe;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScenarioView(exp.scenario),
          const Gap(12),
          ProbeView(
            experienceId: exp.id,
            probe: probe,
            onDone: (result) => ref.read(experienceActionsProvider(exp.id)).submitProbe(probe.id, result),
          ),
        ],
      ),
    );
  }
}

class JudgmentStage extends ConsumerStatefulWidget {
  const JudgmentStage({super.key, required this.exp, required this.progress, required this.rejudge});
  final ExperienceDef exp;
  final ExperienceProgress progress;
  final bool rejudge;

  @override
  ConsumerState<JudgmentStage> createState() => _JudgmentStageState();
}

class _JudgmentStageState extends ConsumerState<JudgmentStage> {
  int? _value;

  @override
  void initState() {
    super.initState();
    if (widget.rejudge) _value = widget.progress.initialStance?.value;
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.exp;
    final ghost = widget.rejudge ? widget.progress.initialStance?.value : null;
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: widget.progress.stage,
      bottom: FilledButton(
        key: const ValueKey('judgment_done'),
        onPressed: _value == null
            ? null
            : () {
                ref.read(feedbackProvider).light();
                ref.read(experienceActionsProvider(exp.id)).submitJudgment(_value!);
              },
        child: const Text('Listo'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.rejudge) ...[
            Text('Vuelves a tu lado', style: context.text.labelMedium),
            const Gap(8),
            Text(exp.twist.text, style: context.text.bodyLarge),
            const Gap(20),
          ] else if (exp.eligeProbe == null) ...[
            ScenarioView(exp.scenario),
            const Gap(8),
          ],
          Semantics(header: true, child: Text(exp.judgment.prompt, style: context.text.headlineSmall)),
          const Gap(24),
          Balanza(
            leftLabel: exp.judgment.left.label,
            rightLabel: exp.judgment.right.label,
            value: _value,
            ghost: ghost,
            prompt: exp.judgment.prompt,
            onZoneChanged: ref.read(feedbackProvider).selection,
            onChanged: (v) => setState(() => _value = v),
          ),
          if (widget.rejudge) ...[
            const Gap(16),
            Text('Mantenerte o moverte: las dos cosas están bien.', style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class ReasonStage extends ConsumerStatefulWidget {
  const ReasonStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  ConsumerState<ReasonStage> createState() => _ReasonStageState();
}

class _ReasonStageState extends ConsumerState<ReasonStage> {
  String? _selected;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.exp;
    final stance = widget.progress.initialStance;
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: widget.progress.stage,
      bottom: FilledButton(
        key: const ValueKey('reason_done'),
        onPressed: _selected == null
            ? null
            : () => ref
                .read(experienceActionsProvider(exp.id))
                .submitReason(_selected!, otherText: _selected == ReasonRecord.otherId ? _other.text : null),
        child: const Text('Seguir'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stance != null) Text('Elegiste: ${stance.label}', style: context.text.bodySmall),
          const Gap(12),
          Semantics(header: true, child: Text('¿Qué te lleva a pensarlo?', style: context.text.headlineSmall)),
          const Gap(16),
          for (final r in exp.reasons)
            RuledOption(
              key: ValueKey('reason_${r.id}'),
              label: r.text,
              serif: true,
              selected: _selected == r.id,
              onTap: () => setState(() => _selected = r.id),
            ),
          RuledOption(
            key: const ValueKey('reason_other'),
            label: ExperienceEngine.otherLabel,
            selected: _selected == ReasonRecord.otherId,
            onTap: () => setState(() => _selected = ReasonRecord.otherId),
          ),
          if (_selected == ReasonRecord.otherId)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _other,
                maxLength: 140,
                decoration: const InputDecoration(labelText: 'Tu razón, en pocas palabras (solo la ves tú)'),
              ),
            ),
          RuledOption(
            key: const ValueKey('reason_unknown'),
            label: ExperienceEngine.unknownLabel,
            detail: 'También es una respuesta honesta',
            selected: _selected == ReasonRecord.unknownId,
            onTap: () => setState(() => _selected = ReasonRecord.unknownId),
          ),
        ],
      ),
    );
  }
}
