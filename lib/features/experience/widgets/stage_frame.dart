import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/records/records.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/ink_marks.dart';
import '../../../widgets/paper.dart';
import '../experience_actions.dart';

const movements = ['Elige', 'Razona', 'Cruza', 'Vuelve'];

int movementOf(String stage) {
  switch (stage) {
    case Stage.intro:
    case Stage.probe:
    case Stage.judgment:
      return 0;
    case Stage.cruzaSide:
    case Stage.cruzaAnchor:
    case Stage.workshop:
    case Stage.recognition:
    case Stage.strength:
      return 2;
    case Stage.twist:
    case Stage.rejudge:
    case Stage.reflection:
    case Stage.done:
      return 3;
    default:
      return 1;
  }
}

/// Marco común de las etapas: título, indicador de movimiento y pausa.
class StageFrame extends ConsumerWidget {
  const StageFrame({
    super.key,
    required this.experienceId,
    required this.title,
    required this.stage,
    required this.child,
    this.bottom,
    this.reverse = false,
    this.banner,
  });

  final String experienceId;
  final String title;
  final String stage;
  final Widget child;
  final Widget? bottom;
  final bool reverse;
  final Widget? banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = movementOf(stage);
    return PaperPage(
      reverse: reverse,
      title: title,
      banner: banner,
      onBack: () => showPauseSheet(context, ref, experienceId),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Semantics(
            label: 'Movimiento ${current + 1} de 4: ${movements[current]}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < movements.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkDot(
                        style: i < current ? DotStyle.filled : (i == current ? DotStyle.ringed : DotStyle.hollow),
                        size: 10,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(movements[current], style: context.text.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ],
      bottom: bottom,
      child: child,
    );
  }
}

Future<void> showPauseSheet(BuildContext context, WidgetRef ref, String experienceId) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pausa', style: sheetContext.text.headlineSmall),
            const Gap(8),
            Text('Lo que ya elegiste está guardado.', style: sheetContext.text.bodySmall),
            const Gap(12),
            RuledOption(
              label: 'Continuar después',
              detail: 'Vuelves al inicio; la pregunta te espera donde la dejaste',
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/');
              },
            ),
            RuledOption(
              label: 'Omitir esta pregunta',
              detail: 'Se descarta lo que respondiste aquí; puedes hacerla más tarde',
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Omitir esta pregunta'),
                    content: const Text('Lo que respondiste en esta pregunta no se usará. Podrás hacerla más tarde.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Omitir')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(experienceActionsProvider(experienceId)).skip();
                  if (context.mounted) context.go('/');
                }
              },
            ),
            RuledOption(label: 'Seguir aquí', onTap: () => Navigator.pop(sheetContext)),
          ],
        ),
      ),
    ),
  );
}
