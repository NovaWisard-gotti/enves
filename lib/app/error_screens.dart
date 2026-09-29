import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../widgets/ink_marks.dart';
import '../widgets/paper.dart';
import 'providers.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Cargando Envés',
          child: const CrossGlyph(width: 72, height: 24),
        ),
      ),
    );
  }
}

class StateErrorScreen extends ConsumerWidget {
  const StateErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userStateProvider);
    final error = user.error;
    final newer = error is StateLoadError && error.newer;
    final contentFailed = ref.watch(contentProvider).hasError;

    final String title;
    final String body;
    if (contentFailed) {
      title = 'Algo no cargó bien.';
      body = 'Tus respuestas están a salvo en este teléfono. Intenta abrir Envés de nuevo.';
    } else if (newer) {
      title = 'Tus datos son de una versión más nueva de Envés.';
      body = 'Actualiza la app para seguir. No borraremos nada.';
    } else {
      title = 'No pudimos leer tus respuestas anteriores.';
      body = 'Puedes intentarlo de nuevo o empezar desde cero.';
    }

    return PaperPage(
      showAppBar: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(48),
          const CrossGlyph(),
          const Gap(24),
          Text(title, style: context.text.headlineSmall),
          const Gap(12),
          Text(body, style: context.text.bodyLarge),
          const Gap(32),
          FilledButton(
            onPressed: () {
              ref.invalidate(contentProvider);
              ref.invalidate(userStateProvider);
            },
            child: const Text('Intentar de nuevo'),
          ),
          if (!contentFailed && !newer) ...[
            const Gap(8),
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Empezar de nuevo'),
                    content: const Text('Se borrarán las respuestas que no pudimos leer. Esto no se puede deshacer.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Empezar de nuevo')),
                    ],
                  ),
                );
                if (ok == true) await ref.read(userStateProvider.notifier).resetAfterFailure();
              },
              child: const Text('Empezar de nuevo'),
            ),
          ],
        ],
      ),
    );
  }
}
