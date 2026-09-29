import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ink_marks.dart';
import 'paper.dart';

/// Las tres salidas legítimas ante una tensión. Mismo tamaño, mismo estilo,
/// ninguna celebrada ni presentada como error.
class TensionButtons extends StatelessWidget {
  const TensionButtons({super.key, required this.onSelected, this.showNoAplica = true});

  final ValueChanged<String> onSelected;
  final bool showNoAplica;

  static const options = [
    (id: 'mantener', label: 'Mantener', detail: 'Mi razón sigue aplicándose', kind: TensionGlyphKind.mantener),
    (id: 'matizar', label: 'Matizar', detail: 'Hay una diferencia entre los casos', kind: TensionGlyphKind.matizar),
    (id: 'revisar', label: 'Revisar', detail: 'Cambiaría mi posición', kind: TensionGlyphKind.revisar),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth / 3 < 118 * scale;
      final buttons = [
        for (final o in options)
          _TensionButton(
            key: ValueKey('tension_${o.id}'),
            label: o.label,
            detail: o.detail,
            kind: o.kind,
            onTap: () => onSelected(o.id),
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stacked)
            ...[for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 8), child: b)]
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: buttons[i]),
                  ],
                ],
              ),
            ),
          if (showNoAplica)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('tension_noAplica'),
                onPressed: () => onSelected('noAplica'),
                child: const Text('Esta pregunta no aplica'),
              ),
            ),
        ],
      );
    });
  }
}

class _TensionButton extends StatelessWidget {
  const _TensionButton({super.key, required this.label, required this.detail, required this.kind, required this.onTap});
  final String label;
  final String detail;
  final TensionGlyphKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $detail',
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12), alignment: Alignment.topLeft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TensionGlyph(kind),
            const SizedBox(height: 6),
            Text(label, style: context.text.labelLarge),
            const SizedBox(height: 2),
            Text(detail, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Descubrimiento: primero las palabras del usuario, después el nombre.
class DiscoveryNote extends StatelessWidget {
  const DiscoveryNote({
    super.key,
    required this.userWords,
    required this.openingLine,
    required this.everydayName,
    required this.explanation,
    required this.relation,
    required this.isOwn,
    required this.doubtful,
  });

  final String userWords;
  final String openingLine;
  final String everydayName;
  final String explanation;
  final String relation;
  final bool isOwn;
  final bool doubtful;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus palabras', style: context.text.labelMedium),
          const Gap(6),
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: e.ink, width: 1.5))),
            child: Text('«$userWords»', key: const ValueKey('discovery_words'), style: context.text.titleLarge),
          ),
          const Gap(18),
          if (isOwn)
            MarginNote('Diferencia propia: no tiene nombre en nuestro catálogo; es tuya.')
          else ...[
            MarginNote(openingLine),
            const Gap(18),
            Text(everydayName, key: const ValueKey('discovery_name'), style: context.text.headlineSmall),
            const Gap(8),
            Text(explanation, style: context.text.bodyLarge),
            const Gap(12),
            Text('En filosofía suele discutirse al hablar de $relation.', style: context.text.bodySmall),
          ],
          if (doubtful) ...[
            const Gap(12),
            Text('La dejaste en duda. Mucha gente también lo hace.', style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}
