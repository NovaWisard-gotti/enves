import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/records/records.dart';
import '../../engine/map/map_builder.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hilo_vivo.dart';
import '../../widgets/composiciones.dart';
import '../../widgets/ilustraciones.dart';
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

    final ordered = [...content.experiences]..sort((a, b) => a.order.compareTo(b.order));
    final index = {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
    NodoEstado estadoDe(String id) {
      switch (user.experiences[id]?.status) {
        case ExpStatus.completed:
          return NodoEstado.completa;
        case ExpStatus.inProgress:
          return NodoEstado.enCurso;
        case ExpStatus.skipped:
          return NodoEstado.omitida;
        default:
          return NodoEstado.pendiente;
      }
    }

    final nodos = [
      for (final e in ordered)
        RecorridoNodo(
          id: e.id,
          title: e.title,
          estado: estadoDe(e.id),
          hueco: user.experiences[e.id]?.status == ExpStatus.completed &&
              Recognition.isRecognized(user.experiences[e.id]?.cruza?.finalRecognition),
          siguiente: !suggestion.allDone && suggestion.experience?.id == e.id,
        ),
    ];
    final hilos = [
      for (final t in map?.threads ?? const <ThreadView>[])
        if (index.containsKey(t.from) && index.containsKey(t.to))
          RecorridoHilo(
            from: index[t.from]!,
            to: index[t.to]!,
            memoria: t.kind == 'memoria',
            consolidado: t.kind == 'memoria' || completed >= MapBuilder.minForPattern,
          ),
    ];

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
              const HiloFirma(width: 64, height: 22, animar: false),
              const SizedBox(width: 10),
              Expanded(child: Text('Envés', style: context.text.titleMedium)),
              IconButton(
                tooltip: 'Ajustes',
                icon: const Icon(Icons.tune),
                onPressed: () => context.push('/ajustes'),
              ),
            ],
          ),
          const Gap(28),
          if (!suggestion.allDone && ilustracionCabe(context, hasta: 1.3)) ...[
            VinetaArte(suggestion.experience!.id, height: 160),
            const Gap(16),
          ],
          Text(eyebrow, style: context.text.labelMedium),
          const Gap(10),
          Semantics(header: true, child: Text(headline, style: context.text.displaySmall)),
          const Gap(28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(key: const ValueKey('home_primary'), onPressed: onAction, child: Text(action)),
          ),
          const Gap(32),
          RecorridoHiloVivo(nodos: nodos, hilos: hilos),
          const Gap(12),
          const Divider(),
          if (echo != null) ...[
            const Gap(16),
            Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: context.enves.saffron, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('La última vez', style: context.text.labelMedium),
                  const Gap(4),
                  Text(echo, style: context.marginNote.copyWith(fontSize: 19, height: 1.35)),
                ],
              ),
            ),
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
