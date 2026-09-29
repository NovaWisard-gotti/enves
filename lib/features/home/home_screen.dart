import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ink_marks.dart';
import '../../widgets/paper.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    final user = ref.watch(userStateProvider).valueOrNull;
    if (content == null || user == null) return const SizedBox.shrink();
    final prefs = ref.watch(currentPrefsProvider);
    final progress = ref.watch(progressServiceProvider);
    final suggestion = progress.next(content, user);
    final map = ref.watch(mapModelProvider);
    final echo = prefs.discreet ? null : progress.echo(content, user);
    final completed = progress.completedCount(user);
    final recovered = ref.watch(recoveryNoticeProvider);
    final saveError = ref.watch(saveErrorProvider);

    final String eyebrow;
    final String headline;
    final String action;
    VoidCallback onAction;
    if (suggestion.allDone) {
      eyebrow = 'Terminaste el recorrido';
      headline = 'Tu mapa está completo, por ahora.';
      action = 'Ver tu mapa';
      onAction = () => context.push('/mapa');
    } else {
      final exp = suggestion.experience!;
      eyebrow = suggestion.isContinue
          ? 'Continuar'
          : (suggestion.isRevisit ? 'Vuelve a una pregunta' : 'Siguiente pregunta');
      headline = exp.question;
      action = suggestion.isContinue ? 'Continuar' : 'Entrar';
      onAction = () => context.push('/experiencia/${exp.id}');
    }

    Widget? banner;
    if (saveError) {
      banner = NoticeBanner(
        text: 'No pudimos guardar el último paso. Lo intentaremos de nuevo.',
        actionLabel: 'Reintentar',
        onAction: () => ref.read(userStateProvider.notifier).retrySave(),
      );
    } else if (recovered) {
      banner = NoticeBanner(
        text: 'Recuperamos tus respuestas de una copia reciente. Puede faltar el último paso.',
        actionLabel: 'Entendido',
        onAction: () => ref.read(recoveryNoticeProvider.notifier).state = false,
      );
    }

    return PaperPage(
      showAppBar: false,
      banner: banner,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CrossGlyph(),
              const SizedBox(width: 10),
              Text('Envés', style: context.text.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Ajustes',
                icon: const Icon(Icons.tune),
                onPressed: () => context.push('/ajustes'),
              ),
            ],
          ),
          const Gap(40),
          Text(eyebrow, style: context.text.labelMedium),
          const Gap(10),
          Semantics(header: true, child: Text(headline, style: context.text.displaySmall)),
          const Gap(28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(key: const ValueKey('home_primary'), onPressed: onAction, child: Text(action)),
          ),
          const Gap(36),
          const Divider(),
          if (echo != null) ...[
            const Gap(16),
            Text('La última vez', style: context.text.labelMedium),
            const Gap(6),
            Text(echo, style: context.text.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
            const Gap(16),
            const Divider(),
          ],
          _HomeLink(
            label: 'Tu mapa',
            detail: completed == 0
                ? 'Empieza con tu primera pregunta'
                : '${map?.threads.length ?? 0} ${map?.threads.length == 1 ? 'hilo' : 'hilos'} entre preguntas',
            onTap: () => context.push('/mapa'),
          ),
          _HomeLink(
            label: 'Preguntas',
            detail: '$completed de ${content.catalog.length} completadas',
            onTap: () => context.push('/preguntas'),
          ),
          _HomeLink(
            label: 'Cuaderno',
            detail: user.notebook.isEmpty
                ? 'Todavía sin distinciones'
                : '${user.notebook.length} ${user.notebook.length == 1 ? 'distinción' : 'distinciones'}',
            onTap: () => context.push('/cuaderno'),
          ),
        ],
      ),
    );
  }
}

class _HomeLink extends StatelessWidget {
  const _HomeLink({required this.label, required this.detail, required this.onTap});
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RuledOption(
      label: label,
      detail: detail,
      onTap: onTap,
      leading: const InkDot(style: DotStyle.hollow, size: 12),
    );
  }
}
