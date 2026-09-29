import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/paper.dart';

/// Todas las fuentes verificadas que usa el contenido.
class ReferencesScreen extends ConsumerWidget {
  const ReferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    final refs = [...?content?.references.where((r) => r.verified)]
      ..sort((a, b) => a.authors.compareTo(b.authors));
    return PaperPage(
      title: 'Fuentes',
      onBack: () => context.canPop() ? context.pop() : context.go('/ajustes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Las ideas de Envés vienen de estos trabajos. Las perspectivas del otro lado se sintetizaron a partir de ellos; '
            'no son citas ni testimonios de personas reales.',
            style: context.text.bodySmall,
          ),
          const Gap(16),
          for (final r in refs)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.enves.divider))),
              child: Text(r.formatted, style: context.text.bodyMedium),
            ),
        ],
      ),
    );
  }
}
