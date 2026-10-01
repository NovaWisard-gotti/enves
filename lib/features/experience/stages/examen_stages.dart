import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/json.dart';
import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../engine/experience/experience_engine.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/hilo_vivo.dart';
import '../../../widgets/margen_vivo.dart';
import '../../../widgets/paper.dart';
import '../../../widgets/tension_widgets.dart';
import '../../deep_dive/deep_dive_sheet.dart';
import '../experience_actions.dart';
import '../widgets/memoria_regresa.dart';
import '../widgets/stage_frame.dart';

/// Hoja «¿Por qué me preguntas esto?»: muestra el origen real del recuerdo.
Future<void> showMemoryOrigin(BuildContext context, ContentBundle content, List<RecordRef> refs) {
  String when(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Por qué te pregunto esto?', style: sheet.text.headlineSmall),
            const Gap(8),
            Text('Esta pregunta sale de algo que elegiste antes:', style: sheet.text.bodySmall),
            const Gap(12),
            for (final r in refs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MarginNote(
                  r.experienceId == 'onboarding' ? 'Al empezar' : content.titleOf(r.experienceId),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('«${r.quote}», ${when(r.at)}', style: sheet.text.bodyLarge),
                  ),
                ),
              ),
            TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cerrar')),
          ],
        ),
      ),
    ),
  );
}

class QuestionStage extends ConsumerWidget {
  const QuestionStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = progress.active;
    final content = ref.watch(contentProvider).valueOrNull;
    final actions = ref.read(experienceActionsProvider(exp.id));
    if (q == null || content == null) {
      return StageFrame(
        experienceId: exp.id,
        title: exp.title,
        stage: progress.stage,
        bottom: FilledButton(onPressed: actions.continueToCruza, child: const Text('Seguir')),
        child: const SizedBox.shrink(),
      );
    }
    final def = exp.questionById(q.questionId);
    final Widget answers;
    if (q.kind == QuestionKind.tension) {
      answers = TensionButtons(onSelected: (id) {
        ref.read(feedbackProvider).light();
        actions.answer(id);
      });
    } else {
      final options = q.kind == QuestionKind.assumption
          ? ExperienceEngine.assumptionAnswers.entries.map((e) => (id: e.key, label: e.value)).toList()
          : [
              ...?def?.answers.map((a) => (id: a.id, label: a.label)),
              (id: 'noAplica', label: 'Esta pregunta no aplica'),
            ];
      answers = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in options)
            RuledOption(
              key: ValueKey('answer_${o.id}'),
              label: o.label,
              serif: o.id != 'noAplica',
              onTap: () => actions.answer(o.id),
            ),
        ],
      );
    }
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(8),
          if (q.refs.isNotEmpty)
            MemoriaRegresa(key: ValueKey('memoria_${q.questionId}'), pregunta: q.text, refs: q.refs)
          else
            Semantics(liveRegion: true, child: Text(q.text, style: context.text.titleLarge)),
          if (q.refs.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('memory_origin'),
                onPressed: () => showMemoryOrigin(context, content, q.refs),
                child: const Text('¿Por qué me preguntas esto?'),
              ),
            ),
          const Gap(24),
          answers,
        ],
      ),
    );
  }
}

class ImplicationStage extends ConsumerWidget {
  const ImplicationStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(engineProvider);
    final user = ref.watch(userStateProvider).valueOrNull;
    final text = (engine != null && user != null) ? engine.implicationText(user, exp.id) : null;
    final actions = ref.read(experienceActionsProvider(exp.id));
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mantienes tu razón.', style: context.text.labelMedium),
          const Gap(12),
          Text(text ?? '¿Aceptas lo que implica en este caso?', style: context.text.titleLarge),
          const Gap(24),
          RuledOption(label: 'Sí, lo acepto', serif: true, onTap: () => actions.answerImplication(true)),
          RuledOption(label: 'No del todo', serif: true, onTap: () => actions.answerImplication(false)),
        ],
      ),
    );
  }
}

class ChooseAfterRejectStage extends ConsumerWidget {
  const ChooseAfterRejectStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(experienceActionsProvider(exp.id));
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Entonces, ¿qué prefieres hacer con esta tensión?', style: context.text.titleLarge),
          const Gap(20),
          RuledOption(
            label: 'Matizar',
            detail: 'Hay una diferencia entre los casos',
            onTap: () => actions.chooseAfterReject(TensionOutcomeKind.matizar),
          ),
          RuledOption(
            label: 'Revisar',
            detail: 'Cambiaría mi posición',
            onTap: () => actions.chooseAfterReject(TensionOutcomeKind.revisar),
          ),
        ],
      ),
    );
  }
}

class DifferenceStage extends ConsumerStatefulWidget {
  const DifferenceStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  ConsumerState<DifferenceStage> createState() => _DifferenceStageState();
}

class _DifferenceStageState extends ConsumerState<DifferenceStage> {
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
    final canSend = _selected != null && (_selected != 'other' || _other.text.trim().isNotEmpty);
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: widget.progress.stage,
      bottom: FilledButton(
        key: const ValueKey('difference_done'),
        onPressed: !canSend
            ? null
            : () => ref.read(experienceActionsProvider(exp.id)).chooseDifference(
                  differenceId: _selected == 'other' ? null : _selected,
                  otherText: _selected == 'other' ? _other.text : null,
                ),
        child: const Text('Seguir'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('¿Qué diferencia ves entre los casos?', style: context.text.headlineSmall)),
          const Gap(16),
          for (final d in exp.differences)
            RuledOption(
              key: ValueKey('difference_${d.id}'),
              label: d.text,
              serif: true,
              selected: _selected == d.id,
              onTap: () => setState(() => _selected = d.id),
            ),
          RuledOption(
            label: 'Otra diferencia',
            selected: _selected == 'other',
            onTap: () => setState(() => _selected = 'other'),
          ),
          if (_selected == 'other')
            TextField(
              controller: _other,
              maxLength: 140,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'La diferencia que ves'),
            ),
        ],
      ),
    );
  }
}

class DifferenceTestStage extends ConsumerWidget {
  const DifferenceTestStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diffId = asStringOrNull(progress.pendingDifference?['id']);
    final def = diffId == null ? null : exp.difference(diffId);
    final actions = ref.read(experienceActionsProvider(exp.id));
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (def != null) ...[
            Text('«${def.text}»', style: context.text.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
            const Gap(16),
          ],
          Text(def?.test ?? '¿Sostienes esa diferencia?', style: context.text.titleLarge),
          const Gap(24),
          RuledOption(label: 'Sí, lo sostengo', serif: true, onTap: () => actions.answerDifferenceTest(true)),
          RuledOption(label: 'No estoy seguro', serif: true, onTap: () => actions.answerDifferenceTest(false)),
        ],
      ),
    );
  }
}

class RevisionTargetStage extends ConsumerWidget {
  const RevisionTargetStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(experienceActionsProvider(exp.id));
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('¿Qué revisas?', style: context.text.headlineSmall)),
          const Gap(16),
          RuledOption(
            label: 'La razón que di',
            detail: 'Ya no creo que valga igual en todos los casos',
            onTap: () => actions.chooseRevisionTarget('principio'),
          ),
          RuledOption(
            label: 'Mi juicio sobre este caso',
            detail: 'La razón sigue en pie, pero aquí juzgaría distinto',
            onTap: () => actions.chooseRevisionTarget('juicio'),
          ),
        ],
      ),
    );
  }
}

class NoAplicaStage extends ConsumerStatefulWidget {
  const NoAplicaStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  ConsumerState<NoAplicaStage> createState() => _NoAplicaStageState();
}

class _NoAplicaStageState extends ConsumerState<NoAplicaStage> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StageFrame(
      experienceId: widget.exp.id,
      title: widget.exp.title,
      stage: widget.progress.stage,
      bottom: FilledButton(
        onPressed: () => ref.read(experienceActionsProvider(widget.exp.id)).submitNoAplica(_text.text),
        child: const Text('Seguir'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Anotado: esta pregunta no aplica a tu caso.', style: context.text.titleLarge),
          const Gap(16),
          TextField(
            controller: _text,
            maxLength: 140,
            decoration: const InputDecoration(labelText: '¿Por qué no aplica? (opcional, solo lo ves tú)'),
          ),
        ],
      ),
    );
  }
}

class FundamentoStage extends ConsumerWidget {
  const FundamentoStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      bottom: FilledButton(
        onPressed: () => ref.read(experienceActionsProvider(exp.id)).continueToCruza(),
        child: const Text('Ver el otro lado'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(8),
          MarginNote('Llegaste a algo que valoras por sí mismo. Eso tiene nombre: un fundamento.'),
          const Gap(16),
          Text(
            'Muchas personas razonables tienen fundamentos distintos. ¿Quieres ver cuál es el de quien piensa lo contrario?',
            style: context.text.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class DiscoveryStage extends ConsumerStatefulWidget {
  const DiscoveryStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  ConsumerState<DiscoveryStage> createState() => _DiscoveryStageState();
}

class _DiscoveryStageState extends ConsumerState<DiscoveryStage> {
  bool _announced = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider).valueOrNull;
    final user = ref.watch(userStateProvider).valueOrNull;
    final entryId = widget.progress.tension?.notebookEntryId;
    NotebookEntry? entry;
    for (final n in user?.notebook ?? const <NotebookEntry>[]) {
      if (n.id == entryId) entry = n;
    }
    final distinction = content?.distinction(entry?.distinctionId);
    if (!_announced) {
      _announced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(feedbackProvider).discovery());
    }
    final reduced = reducedMotion(context, ref);
    return StageFrame(
      experienceId: widget.exp.id,
      title: widget.exp.title,
      stage: widget.progress.stage,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (distinction != null && content != null)
            TextButton(
              onPressed: () => showDistinctionDeepDive(context, content, distinction),
              child: const Text('Ver el debate'),
            ),
          FilledButton(
            key: const ValueKey('discovery_continue'),
            onPressed: () => ref.read(experienceActionsProvider(widget.exp.id)).continueToCruza(),
            child: const Text('Seguir'),
          ),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: reduced ? Duration.zero : Motion.long,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry != null) ...[
              Row(
                children: [
                  TrazoMuestra(semilla: entry.id, dudosa: entry.firmness == 'dudosa', width: 96, height: 32, animar: true),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Una distinción, anotada al margen.', style: context.text.labelMedium)),
                ],
              ),
              const Gap(14),
            ],
            DiscoveryNote(
              userWords: entry?.userWords ?? '',
              openingLine: distinction?.openingLine ?? '',
              everydayName: entry?.everydayName ?? '',
              explanation: entry?.shortExplanation ?? '',
              relation: entry?.philosophicalRelation ?? '',
              isOwn: entry?.isOwn ?? true,
              doubtful: entry?.firmness == 'dudosa',
            ),
            const Gap(16),
            Text('Guardado en tu cuaderno.', style: context.text.bodySmall),
            if (entry != null && content != null && content.visibleReferences(entry.referenceIds).isNotEmpty) ...[
              const Gap(8),
              MargenVivo(
                marca: 'Dónde se discute esta distinción',
                texto: content.visibleReferences(entry.referenceIds).map((r) => r.formatted).join('\n\n'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
