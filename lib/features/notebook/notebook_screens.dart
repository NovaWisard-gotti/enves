import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/records/records.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ink_marks.dart';
import '../../widgets/paper.dart';
import '../deep_dive/deep_dive_sheet.dart';

List<NotebookEntry> _entries(WidgetRef ref, bool demo) {
  if (demo) return ref.watch(demoProfileProvider).valueOrNull?.notebook ?? const [];
  return ref.watch(userStateProvider).valueOrNull?.notebook ?? const [];
}

class NotebookScreen extends ConsumerWidget {
  const NotebookScreen({super.key, required this.demo});
  final bool demo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    final entries = [..._entries(ref, demo)]..sort((a, b) => b.at.compareTo(a.at));
    return PaperPage(
      title: demo ? 'Cuaderno de demostración' : 'Cuaderno',
      onBack: () => context.canPop() ? context.pop() : context.go('/'),
      banner: demo
          ? NoticeBanner(text: 'Demostración: estas no son tus respuestas.', emphasis: true)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Las diferencias que encontraste al matizar, primero con tus palabras.', style: context.text.bodySmall),
          const Gap(16),
          if (entries.isEmpty) ...[
            const Gap(24),
            Text('Tu cuaderno está vacío.', style: context.text.headlineSmall),
            const Gap(8),
            Text(
              'Cuando matices una razón porque ves una diferencia entre dos casos, esa diferencia se guardará aquí.',
              style: context.text.bodyLarge,
            ),
          ],
          for (final n in entries)
            RuledOption(
              key: ValueKey('entry_${n.id}'),
              label: '«${n.userWords}»',
              serif: true,
              detail: [
                n.isOwn ? 'Diferencia propia' : n.everydayName,
                if (content != null) content.titleOf(n.experienceId),
                if (n.firmness == 'dudosa') 'en duda',
              ].where((s) => s.isNotEmpty).join('. '),
              leading: InkDot(style: n.firmness == 'dudosa' ? DotStyle.half : DotStyle.filled, size: 12),
              onTap: () => context.push('/cuaderno/${n.id}${demo ? '?demo=1' : ''}'),
            ),
        ],
      ),
    );
  }
}

class NotebookEntryScreen extends ConsumerWidget {
  const NotebookEntryScreen({super.key, required this.entryId, required this.demo});
  final String entryId;
  final bool demo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    NotebookEntry? entry;
    for (final n in _entries(ref, demo)) {
      if (n.id == entryId) entry = n;
    }
    final back = () => context.canPop() ? context.pop() : context.go('/cuaderno');
    if (entry == null || content == null) {
      return PaperPage(
        title: 'Cuaderno',
        onBack: back,
        child: Text('Esta entrada ya no existe.', style: context.text.bodyLarge),
      );
    }
    final n = entry;
    final distinction = content.distinction(n.distinctionId);
    final refs = content.visibleReferences(n.referenceIds);
    return PaperPage(
      title: 'Cuaderno',
      onBack: back,
      banner: demo ? NoticeBanner(text: 'Demostración: estas no son tus respuestas.', emphasis: true) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus palabras', style: context.text.labelMedium),
          const Gap(6),
          Text('«${n.userWords}»', style: context.text.headlineSmall),
          const Gap(6),
          Text('En «${content.titleOf(n.experienceId)}»', style: context.text.bodySmall),
          if (n.firmness == 'dudosa') Text('La dejaste en duda.', style: context.text.bodySmall),
          const Gap(24),
          if (n.isOwn)
            MarginNote('Diferencia propia: no tiene nombre en nuestro catálogo; es tuya.')
          else ...[
            if (distinction != null) MarginNote(distinction.openingLine),
            const Gap(12),
            Text(n.everydayName, style: context.text.headlineSmall),
            const Gap(8),
            Text(n.shortExplanation, style: context.text.bodyLarge),
            const Gap(12),
            Text('En filosofía suele discutirse al hablar de ${n.philosophicalRelation}.', style: context.text.bodySmall),
            if (distinction != null) ...[
              const Gap(16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => showDistinctionDeepDive(context, content, distinction),
                  child: const Text('Ver el debate'),
                ),
              ),
            ],
            if (refs.isNotEmpty) ...[
              const Gap(16),
              SectionLabel('Fuentes'),
              for (final r in refs)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(r.formatted, style: context.text.bodySmall)),
            ],
          ],
        ],
      ),
    );
  }
}
