import 'package:flutter/material.dart';

import '../../domain/content/content_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/paper.dart';

Future<void> showExperienceDeepDive(BuildContext context, ContentBundle content, ExperienceDef exp) {
  final d = exp.deepDive;
  return _show(context, [
    Text(exp.question, style: context.text.headlineSmall),
    const Gap(16),
    _Section('El problema', d.problem),
    if (d.positions.isNotEmpty)
      _Block(
        'Posiciones razonables',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in d.positions)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(p, style: context.text.bodyLarge)),
          ],
        ),
      ),
    _Section('Tradiciones y autores', d.traditions),
    _Section('La objeción más fuerte', d.objection),
    _References(content.visibleReferences(d.referenceIds)),
  ]);
}

Future<void> showDistinctionDeepDive(BuildContext context, ContentBundle content, DistinctionDef d) {
  return _show(context, [
    Text(d.everydayName, style: context.text.headlineSmall),
    const Gap(12),
    Text(d.shortExplanation, style: context.text.bodyLarge),
    const Gap(16),
    _Section('En filosofía', 'Suele discutirse al hablar de ${d.philosophicalRelation}.'),
    _Section('Quiénes lo discuten', d.debateAuthors),
    _Section('La objeción más fuerte', d.mainObjection),
    _References(content.visibleReferences(d.referenceIds)),
  ]);
}

Future<void> _show(BuildContext context, List<Widget> children) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text('Profundizar', style: context.text.labelMedium),
          const Gap(8),
          ...children,
          const Gap(8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cerrar')),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) return const SizedBox.shrink();
    return _Block(title, Text(body, style: context.text.bodyLarge));
  }
}

class _Block extends StatelessWidget {
  const _Block(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [SectionLabel(title), child],
        ),
      );
}

class _References extends StatelessWidget {
  const _References(this.refs);
  final List<ReferenceDef> refs;

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) return const SizedBox.shrink();
    return _Block(
      'Fuentes',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in refs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(r.formatted, style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}
