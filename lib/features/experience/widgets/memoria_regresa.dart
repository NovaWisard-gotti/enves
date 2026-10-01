import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/records/records.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/hilo_vivo.dart';
import '../../../widgets/paper.dart';

String fechaCorta(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _queFue(String field) {
  switch (field) {
    case 'reason':
      return 'La razón que diste';
    case 'stance.final':
      return 'Tu postura al terminar';
    case 'stance.initial':
      return 'Tu postura al empezar';
    case 'onboarding':
      return 'Tu respuesta al entrar a Envés';
    case 'cruza':
      return 'Lo que reconstruiste del otro lado';
    default:
      return 'Algo que elegiste';
  }
}

/// Tu respuesta regresa: la frase que dijiste antes llega escrita desde el
/// margen. Al tocarla se despliega dónde, cuándo y con qué postura la dijiste,
/// y un hilo la conecta con la pregunta de ahora.
///
/// Solo cita registros reales ([RecordRef]); nunca interpreta.
class MemoriaRegresa extends ConsumerStatefulWidget {
  const MemoriaRegresa({super.key, required this.pregunta, required this.refs});
  final String pregunta;
  final List<RecordRef> refs;

  @override
  ConsumerState<MemoriaRegresa> createState() => _MemoriaRegresaState();
}

class _MemoriaRegresaState extends ConsumerState<MemoriaRegresa> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  bool _abierta = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reducedMotionNow(context, ref)) {
      _c.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _c.forward().whenComplete(() {
          if (mounted) ref.read(feedbackProvider).selection();
        });
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider).valueOrNull;
    final user = ref.watch(userStateProvider).valueOrNull;
    final e = context.enves;
    final first = widget.refs.first;
    final dondeFirst = first.experienceId == 'onboarding' ? 'al empezar' : 'en «${content?.titleOf(first.experienceId) ?? ''}»';

    String? posturaDe(RecordRef r) {
      if (r.experienceId == 'onboarding') return user?.onboarding?.stance.label;
      final p = user?.experiences[r.experienceId];
      return (p?.finalStance ?? p?.initialStance)?.label;
    }

    final anotacion = Semantics(
      button: true,
      expanded: _abierta,
      label: 'Lo dijiste $dondeFirst: «${first.quote}»',
      hint: _abierta ? 'Ocultar de dónde viene' : 'Ver dónde y cuándo lo dijiste',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('memory_note'),
        onTap: () {
          ref.read(feedbackProvider).selection();
          setState(() => _abierta = !_abierta);
        },
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: e.saffron, width: 2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lo dijiste $dondeFirst', style: context.text.labelMedium),
              const Gap(4),
              Text(
                '«${first.quote}»',
                style: context.marginNote.copyWith(fontSize: 20, height: 1.35),
              ),
              const Gap(4),
              Row(
                children: [
                  Flexible(child: Text(_abierta ? 'Ocultar' : 'Toca para ver de dónde viene', style: context.text.bodySmall)),
                  const SizedBox(width: 6),
                  Icon(_abierta ? Icons.expand_less : Icons.expand_more, size: 18, color: e.inkSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final detalle = AnimatedSize(
      duration: reducedMotion(context, ref) ? Duration.zero : Motion.medium,
      curve: Motion.settle,
      alignment: Alignment.topLeft,
      child: !_abierta
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in widget.refs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Linea('Dónde', r.experienceId == 'onboarding' ? 'Al empezar Envés' : (content?.titleOf(r.experienceId) ?? '')),
                          _Linea('Qué era', _queFue(r.field)),
                          if (posturaDe(r) != null && r.field != 'stance.final' && r.field != 'stance.initial' && r.field != 'onboarding')
                            _Linea('Tu postura entonces', posturaDe(r)!),
                          _Linea('Cuándo', fechaCorta(r.at)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final inT = Motion.settle.transform((v / 0.4).clamp(0.0, 1.0));
        final threadVisible = v >= 0.35;
        final qT = ((v - 0.6) / 0.4).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: inT,
              child: Transform.translate(
                offset: Offset(-40 * (1 - inT), 0),
                child: Transform.rotate(angle: -0.012 * (1 - inT), alignment: Alignment.centerLeft, child: anotacion),
              ),
            ),
            detalle,
            HiloConector(height: 34, visible: threadVisible),
            Opacity(
              opacity: 0.25 + 0.75 * qT,
              child: Semantics(liveRegion: true, child: Text(widget.pregunta, style: context.text.titleLarge)),
            ),
          ],
        );
      },
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.titulo, this.valor);
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$titulo: ', style: context.text.labelMedium),
            TextSpan(text: valor, style: context.text.bodyMedium),
          ]),
        ),
      );
}
