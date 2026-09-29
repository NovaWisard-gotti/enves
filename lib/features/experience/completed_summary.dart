import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/records/records.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ink_marks.dart';
import '../../widgets/paper.dart';
import '../deep_dive/deep_dive_sheet.dart';

Future<void> showCompletedSummary(BuildContext context, String experienceId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: CompletedSummaryView(experienceId: experienceId),
      ),
    ),
  );
}

/// Resumen de una experiencia completada: solo citas de lo que elegiste.
class CompletedSummaryView extends ConsumerWidget {
  const CompletedSummaryView({super.key, required this.experienceId});
  final String experienceId;

  static String outcomeLabel(TensionOutcome? t) {
    switch (t?.outcome) {
      case TensionOutcomeKind.mantener:
        return 'Mantuviste tu razón.';
      case TensionOutcomeKind.matizar:
        return 'Matizaste: «${t!.differenceText ?? ''}».';
      case TensionOutcomeKind.revisar:
        return t!.revisionTarget == 'principio' ? 'Revisaste la razón que diste.' : 'Revisaste tu juicio sobre el caso.';
      case TensionOutcomeKind.noAplica:
        return 'Dijiste que la pregunta no aplicaba.';
      default:
        return 'No hubo tensión que examinar.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    final user = ref.watch(userStateProvider).valueOrNull;
    final exp = content?.byId[experienceId];
    if (content == null || user == null || exp == null) return const SizedBox.shrink();
    final p = user.progress(experienceId);
    final r = p.reason;
    final c = p.cruza;

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelMedium),
              const Gap(2),
              Text(value, style: context.text.bodyLarge),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exp.question, style: context.text.headlineSmall),
        const Gap(20),
        if (p.initialStance != null) line('Al entrar', p.initialStance!.label),
        if (r != null) line('Tu razón', r.isQuotable ? r.text : (r.other ?? r.text)),
        line('Ante la tensión', outcomeLabel(p.tension)),
        if (c != null)
          line(
            'Del otro lado',
            '«${exp.pole(c.target).label}». ${content.common.recognition[c.finalRecognition] ?? ''}',
          ),
        if (p.finalStance != null)
          line(
            'Al volver',
            p.initialStance?.value == p.finalStance!.value ? '${p.finalStance!.label}. Igual que antes.' : p.finalStance!.label,
          ),
        const Gap(8),
        Row(children: [
          const InkDot(style: DotStyle.filled, size: 12),
          const SizedBox(width: 8),
          Text('Tu postura', style: context.text.bodySmall),
          const SizedBox(width: 20),
          const InkDot(style: DotStyle.hollow, size: 12),
          const SizedBox(width: 8),
          Text('Lo que comprendiste', style: context.text.bodySmall),
        ]),
        const Gap(16),
        TextButton(onPressed: () => showExperienceDeepDive(context, content, exp), child: const Text('Profundizar')),
      ],
    );
  }
}
