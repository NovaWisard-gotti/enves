import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/records/records.dart';
import '../../theme/app_theme.dart';
import '../../widgets/paper.dart';
import 'completed_summary.dart';
import 'stages/cruza_stages.dart';
import 'stages/elige_stages.dart';
import 'stages/examen_stages.dart';
import 'stages/vuelve_stages.dart';
import 'widgets/stage_frame.dart';

/// Contenedor de una experiencia: elige la etapa según el estado guardado.
class ExperienceScreen extends ConsumerWidget {
  const ExperienceScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    final user = ref.watch(userStateProvider).valueOrNull;
    if (content == null || user == null) return const Scaffold(body: SizedBox.shrink());
    final exp = content.byId[id];
    if (exp == null || !content.isAvailable(id)) {
      return PaperPage(
        title: 'Pregunta',
        onBack: () => context.canPop() ? context.pop() : context.go('/'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(24),
            Text('Esta pregunta no está disponible por ahora.', style: context.text.headlineSmall),
            const Gap(8),
            Text('Tus otras respuestas siguen a salvo.', style: context.text.bodyLarge),
          ],
        ),
      );
    }
    final p = user.progress(id);

    if (p.status == ExpStatus.completed) {
      return PaperPage(
        title: exp.title,
        onBack: () => context.canPop() ? context.pop() : context.go('/'),
        child: CompletedSummaryView(experienceId: id),
      );
    }
    if (p.status != ExpStatus.inProgress) {
      return IntroStage(
        exp: exp,
        outOfOrder: ref.watch(progressServiceProvider).isOutOfOrder(content, user, id),
        wasSkipped: p.status == ExpStatus.skipped,
      );
    }

    final Widget stage;
    switch (p.stage) {
      case Stage.probe:
        final probe = exp.eligeProbe;
        stage = probe == null
            ? JudgmentStage(exp: exp, progress: p, rejudge: false)
            : ProbeStage(exp: exp, probe: probe, progress: p);
      case Stage.judgment:
        stage = JudgmentStage(exp: exp, progress: p, rejudge: false);
      case Stage.reason:
        stage = ReasonStage(exp: exp, progress: p);
      case Stage.question:
        stage = QuestionStage(exp: exp, progress: p);
      case Stage.implication:
        stage = ImplicationStage(exp: exp, progress: p);
      case Stage.chooseAfterReject:
        stage = ChooseAfterRejectStage(exp: exp, progress: p);
      case Stage.difference:
        stage = DifferenceStage(exp: exp, progress: p);
      case Stage.differenceTest:
        stage = DifferenceTestStage(exp: exp, progress: p);
      case Stage.revisionTarget:
        stage = RevisionTargetStage(exp: exp, progress: p);
      case Stage.noAplicaWhy:
        stage = NoAplicaStage(exp: exp, progress: p);
      case Stage.fundamento:
        stage = FundamentoStage(exp: exp, progress: p);
      case Stage.discovery:
        stage = DiscoveryStage(exp: exp, progress: p);
      case Stage.cruzaSide:
        stage = CruzaSideStage(exp: exp, progress: p);
      case Stage.cruzaAnchor:
        stage = CruzaAnchorStage(exp: exp, progress: p);
      case Stage.workshop:
        stage = WorkshopStage(exp: exp, progress: p);
      case Stage.recognition:
        stage = RecognitionStage(exp: exp, progress: p);
      case Stage.strength:
        stage = StrengthStage(exp: exp, progress: p);
      case Stage.twist:
        stage = TwistStage(exp: exp, progress: p);
      case Stage.rejudge:
        stage = JudgmentStage(exp: exp, progress: p, rejudge: true);
      case Stage.reflection:
        stage = ReflectionStage(exp: exp, progress: p);
      default:
        stage = JudgmentStage(exp: exp, progress: p, rejudge: false);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showPauseSheet(context, ref, id);
      },
      child: KeyedSubtree(key: ValueKey('${p.stage}_${p.socratic.length}'), child: stage),
    );
  }
}
