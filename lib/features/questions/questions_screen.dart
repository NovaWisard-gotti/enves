import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/records/records.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ink_marks.dart';
import '../../widgets/paper.dart';
import '../experience/completed_summary.dart';

class QuestionsScreen extends ConsumerWidget {
  const QuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    final user = ref.watch(userStateProvider).valueOrNull;
    if (content == null || user == null) return const SizedBox.shrink();
    final next = ref.watch(progressServiceProvider).next(content, user).experience?.id;
    final threads = ref.watch(mapModelProvider)?.threads ?? const [];

    return PaperPage(
      title: 'Preguntas',
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dónde has pensado. Puedes entrar en cualquier pregunta.', style: context.text.bodySmall),
          const Gap(20),
          for (final tramo in content.tramos) ...[
            SectionLabel(tramo.title),
            for (final entry in content.catalog.where((c) => c.tramo == tramo.id)) ...[
              _QuestionRow(
                question: entry.question,
                available: content.isAvailable(entry.id),
                status: user.experiences[entry.id]?.status ?? ExpStatus.notStarted,
                isNext: entry.id == next,
                onTap: () {
                  if (!content.isAvailable(entry.id)) return;
                  final status = user.experiences[entry.id]?.status;
                  if (status == ExpStatus.completed) {
                    showCompletedSummary(context, entry.id);
                  } else {
                    context.push('/experiencia/${entry.id}');
                  }
                },
              ),
            ],
            const Gap(24),
          ],
          if (threads.isNotEmpty) ...[
            SectionLabel('Hilos entre preguntas'),
            for (final t in threads)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: MarginNote(
                  '${content.titleOf(t.from)} y ${content.titleOf(t.to)}: ${t.label}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.available,
    required this.status,
    required this.isNext,
    required this.onTap,
  });

  final String question;
  final bool available;
  final ExpStatus status;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final String label;
    final Widget dot;
    if (!available) {
      label = 'No disponible por ahora';
      dot = InkDot(style: DotStyle.dashed, size: 16, color: e.graphite);
    } else if (status == ExpStatus.completed) {
      label = 'Completada';
      dot = const InkDot(style: DotStyle.filled, size: 16);
    } else if (status == ExpStatus.inProgress) {
      label = 'En curso';
      dot = const InkDot(style: DotStyle.half, size: 16);
    } else if (status == ExpStatus.skipped) {
      label = 'Omitida. Puedes hacerla cuando quieras';
      dot = InkDot(style: DotStyle.dashed, size: 16, color: e.graphite);
    } else if (isNext) {
      label = 'Siguiente';
      dot = InkDot(style: DotStyle.ringed, size: 16, color: e.saffron);
    } else {
      label = 'Por hacer';
      dot = InkDot(style: DotStyle.hollow, size: 16, color: e.graphite);
    }
    return RuledOption(
      label: question,
      detail: label,
      serif: true,
      leading: dot,
      onTap: available ? onTap : null,
      selected: false,
    );
  }
}
