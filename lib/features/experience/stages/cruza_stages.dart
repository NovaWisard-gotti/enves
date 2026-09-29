import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../engine/cruza/cruza_engine.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/ink_marks.dart';
import '../../../widgets/paper.dart';
import '../experience_actions.dart';
import '../widgets/stage_frame.dart';

// ------------------------------------------------------------ elegir lado
class CruzaSideStage extends ConsumerWidget {
  const CruzaSideStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(experienceActionsProvider(exp.id));
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Elegiste «No lo sé».', style: context.text.labelMedium),
          const Gap(8),
          Semantics(
            header: true,
            child: Text('¿Qué lado quieres entender primero?', style: context.text.headlineSmall),
          ),
          const Gap(20),
          RuledOption(
            key: const ValueKey('side_left'),
            label: exp.judgment.left.label,
            serif: true,
            onTap: () => actions.chooseCruzaSide('left'),
          ),
          RuledOption(
            key: const ValueKey('side_right'),
            label: exp.judgment.right.label,
            serif: true,
            onTap: () => actions.chooseCruzaSide('right'),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- cruce anclado
class CruzaAnchorStage extends ConsumerStatefulWidget {
  const CruzaAnchorStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  ConsumerState<CruzaAnchorStage> createState() => _CruzaAnchorStageState();
}

class _CruzaAnchorStageState extends ConsumerState<CruzaAnchorStage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.cross);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final reduced = reducedMotionNow(context, ref);
      _controller.duration = reduced ? Motion.reduced : Motion.cross;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(feedbackProvider).cross();
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.exp;
    final c = widget.progress.cruza;
    final stance = widget.progress.initialStance;
    final target = exp.pole(c?.target ?? 'left').label;
    final mine = stance == null || stance.value == 0 ? 'No lo sé' : stance.label;
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: widget.progress.stage,
      bottom: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => FilledButton(
          key: const ValueKey('anchor_done'),
          onPressed: _controller.isCompleted ? () => ref.read(experienceActionsProvider(exp.id)).anchorDone() : null,
          child: const Text('Entrar al taller'),
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Motion.turn.transform(_controller.value);
          final flipped = t >= 0.5;
          final Widget face;
          if (!flipped) {
            face = _AnchorFace(
              color: e.paper,
              label: 'Tu postura queda anclada aquí',
              quote: mine,
              dot: DotStyle.filled,
              anchorOpacity: 1,
            );
          } else {
            face = _AnchorFace(
              color: e.reverse,
              label: 'Ahora piensa desde el otro lado',
              quote: target,
              dot: DotStyle.hollow,
              anchorOpacity: 0.35,
              anchorQuote: mine,
            );
          }
          final Widget turned;
          if (reduced) {
            turned = Opacity(opacity: flipped ? (t - 0.5) * 2 : 1 - t * 2, child: face);
          } else {
            final angle = flipped ? (1 - t) * math.pi : t * math.pi;
            turned = Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(flipped ? -angle : angle),
              child: face,
            );
          }
          return Semantics(
            liveRegion: true,
            label: flipped
                ? 'Cruzaste. Ahora piensas desde: $target. Tu postura sigue anclada: $mine.'
                : 'Tu postura queda anclada: $mine.',
            child: ExcludeSemantics(child: turned),
          );
        },
      ),
    );
  }
}

class _AnchorFace extends StatelessWidget {
  const _AnchorFace({
    required this.color,
    required this.label,
    required this.quote,
    required this.dot,
    required this.anchorOpacity,
    this.anchorQuote,
  });
  final Color color;
  final String label;
  final String quote;
  final DotStyle dot;
  final double anchorOpacity;
  final String? anchorQuote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color, border: Border.all(color: context.enves.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(opacity: anchorOpacity, child: const CrossGlyph(width: 88, height: 30)),
          const Gap(28),
          Text(label, style: context.text.labelMedium),
          const Gap(8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 6, right: 12), child: InkDot(style: dot, size: 18)),
              Expanded(child: Text('«$quote»', style: context.text.headlineSmall)),
            ],
          ),
          if (anchorQuote != null) ...[
            const Gap(24),
            Text('A trasluz, tu postura sigue ahí: «$anchorQuote»', style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- taller
class WorkshopStage extends ConsumerStatefulWidget {
  const WorkshopStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  ConsumerState<WorkshopStage> createState() => _WorkshopStageState();
}

class _WorkshopStageState extends ConsumerState<WorkshopStage> {
  String? _selected;

  ExperienceActions get _actions => ref.read(experienceActionsProvider(widget.exp.id));

  Future<void> _place(String slot, String pieceId) async {
    final msg = await _actions.placePiece(slot, pieceId);
    if (!mounted) return;
    setState(() => _selected = null);
    if (msg != null) {
      ref.read(feedbackProvider).light();
    } else {
      ref.read(feedbackProvider).selection();
    }
  }

  Future<void> _bin(String pieceId) async {
    await _actions.binPiece(pieceId);
    if (!mounted) return;
    setState(() => _selected = null);
    ref.read(feedbackProvider).selection();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider).valueOrNull;
    final c = widget.progress.cruza;
    if (content == null || c == null) return const SizedBox.shrink();
    final side = widget.exp.cruzaSide(c.target);
    final common = content.common;
    final placed = c.placement.values.toSet();
    final table = c.table.where((id) => !placed.contains(id) && !c.discarded.contains(id)).toList();
    final canSubmit = const CruzaEngine().canSubmit(c.placement);
    final String? hint = canSubmit
        ? null
        : (c.placement.length < 2 ? 'Coloca al menos dos piezas.' : common.slot('S3').missing);
    final target = widget.exp.pole(c.target).label;

    return StageFrame(
      experienceId: widget.exp.id,
      title: widget.exp.title,
      stage: widget.progress.stage,
      reverse: true,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(hint, style: context.text.bodySmall, textAlign: TextAlign.center),
            ),
          FilledButton(
            key: const ValueKey('workshop_submit'),
            onPressed: canSubmit ? _actions.submitWorkshop : null,
            child: const Text('Mostrar a quienes piensan así'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reconstruye la mejor versión de:', style: context.text.labelMedium),
          const Gap(4),
          Text('«$target»', style: context.text.headlineSmall),
          const Gap(8),
          Text(
            'Arrastra las piezas a su lugar o tócalas y luego toca el lugar. Hay piezas que nadie de ese lado diría así.',
            style: context.text.bodySmall,
          ),
          const Gap(16),
          for (final slot in CruzaEngine.slots)
            _SlotView(
              def: common.slot(slot),
              piece: c.placement[slot] == null ? null : side.piece(c.placement[slot]!),
              armed: _selected != null,
              onAccept: (id) => _place(slot, id),
              onTapEmpty: _selected == null ? null : () => _place(slot, _selected!),
              onRemove: () => _actions.removeFromSlot(slot),
            ),
          if (c.note != null) ...[
            const Gap(8),
            MarginNote(c.note!),
          ],
          const Gap(20),
          SectionLabel('Piezas sobre la mesa'),
          if (table.isEmpty) Text('No quedan piezas en la mesa.', style: context.text.bodySmall),
          for (final id in table)
            if (side.piece(id) != null)
              _PieceView(
                piece: side.piece(id)!,
                selected: _selected == id,
                onTap: () => setState(() => _selected = _selected == id ? null : id),
              ),
          const Gap(12),
          _BinView(
            armed: _selected != null,
            onAccept: _bin,
            onTap: _selected == null ? null : () => _bin(_selected!),
          ),
          if (c.discarded.isNotEmpty) ...[
            const Gap(16),
            SectionLabel('Descartadas'),
            for (final id in c.discarded)
              if (side.piece(id) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MarginNote(
                    common.caricatureTypes[side.piece(id)!.caricatureType] ?? 'No lo dirían así',
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            side.piece(id)!.text,
                            style: context.text.bodySmall?.copyWith(decoration: TextDecoration.lineThrough),
                          ),
                          if ((side.piece(id)!.crack ?? '').isNotEmpty)
                            Text(side.piece(id)!.crack!, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _PieceBox extends StatelessWidget {
  const _PieceBox({required this.text, this.selected = false, this.width});
  final String text;
  final bool selected;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: e.paper,
        border: Border.all(color: selected ? e.ink : e.graphite, width: selected ? 2 : 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text, style: context.text.bodyLarge),
    );
  }
}

class _PieceView extends StatelessWidget {
  const _PieceView({required this.piece, required this.selected, required this.onTap});
  final PieceDef piece;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(builder: (context, constraints) {
        return LongPressDraggable<String>(
          data: piece.id,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.9, child: _PieceBox(text: piece.text, selected: true, width: constraints.maxWidth)),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: _PieceBox(text: piece.text)),
          child: Semantics(
            button: true,
            selected: selected,
            label: piece.text,
            hint: selected ? 'Seleccionada. Toca un lugar del argumento o la papelera.' : 'Seleccionar pieza',
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('piece_${piece.id}'),
              onTap: onTap,
              child: _PieceBox(text: piece.text, selected: selected),
            ),
          ),
        );
      }),
    );
  }
}

class _SlotView extends StatelessWidget {
  const _SlotView({
    required this.def,
    required this.piece,
    required this.armed,
    required this.onAccept,
    required this.onTapEmpty,
    required this.onRemove,
  });
  final SlotDef def;
  final PieceDef? piece;
  final bool armed;
  final ValueChanged<String> onAccept;
  final VoidCallback? onTapEmpty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return DragTarget<String>(
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Semantics(
          button: onTapEmpty != null,
          label: '${def.title}. ${piece == null ? 'Vacío. ${def.hint}' : 'Contiene: ${piece!.text}'}',
          child: InkWell(
            key: ValueKey('slot_${def.id}'),
            onTap: onTapEmpty,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: hovering || armed ? e.ink : e.graphite,
                  width: hovering ? 2.5 : (armed ? 1.5 : 1),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.title, style: context.text.labelMedium),
                    const Gap(4),
                    if (piece == null)
                      Text(def.hint, style: context.text.bodySmall)
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(piece!.text, style: context.text.bodyLarge)),
                          IconButton(
                            tooltip: 'Devolver a la mesa',
                            icon: const Icon(Icons.close),
                            onPressed: onRemove,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BinView extends StatelessWidget {
  const _BinView({required this.armed, required this.onAccept, required this.onTap});
  final bool armed;
  final ValueChanged<String> onAccept;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return DragTarget<String>(
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, _) => Semantics(
        button: true,
        label: 'No lo dirían así: descartar la pieza seleccionada',
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('workshop_bin'),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: candidates.isNotEmpty || armed ? e.ink : e.graphite),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                Icon(Icons.do_not_disturb_alt_outlined, color: e.inkSecondary, size: 20),
                const SizedBox(width: 10),
                Text('No lo dirían así', style: context.text.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ reconocimiento
class RecognitionStage extends ConsumerWidget {
  const RecognitionStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  static DotStyle dotFor(String? state) {
    switch (state) {
      case Recognition.fuerte:
        return DotStyle.ringed;
      case Recognition.reconocible:
        return DotStyle.hollow;
      case Recognition.parcial:
        return DotStyle.half;
      default:
        return DotStyle.dashed;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).valueOrNull;
    final c = progress.cruza;
    if (content == null || c == null) return const SizedBox.shrink();
    final state = c.finalRecognition ?? Recognition.noRepresenta;
    final side = exp.cruzaSide(c.target);
    final common = content.common;
    final last = c.attempts.isEmpty ? null : c.attempts.last;
    final hasOwnSide = c.placement.values.any((id) {
      final p = side.piece(id);
      return p != null && (p.isOwnSide || p.isCaricature);
    });
    final actions = ref.read(experienceActionsProvider(exp.id));
    final label = common.recognition[state] ?? state;

    return StageFrame(
      experienceId: exp.id,
      title: exp.title,
      stage: progress.stage,
      reverse: true,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state != Recognition.fuerte)
            OutlinedButton(
              key: const ValueKey('recognition_retry'),
              onPressed: actions.retryWorkshop,
              child: const Text('Probar otra vez'),
            ),
          const Gap(8),
          FilledButton(
            key: const ValueKey('recognition_continue'),
            onPressed: actions.continueFromRecognition,
            child: const Text('Seguir'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            label: 'Resultado: $label',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  InkDot(style: dotFor(state), size: 24, color: state == Recognition.fuerte ? context.enves.saffron : null),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, key: const ValueKey('recognition_state'), style: context.text.headlineSmall)),
                ],
              ),
            ),
          ),
          const Gap(8),
          Text('Así reaccionarían quienes piensan así.', style: context.text.bodySmall),
          const Gap(16),
          for (final v in side.voices)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.descriptor, style: context.text.labelMedium),
                  const Gap(4),
                  Text('«${v.reactions[state] ?? ''}»', style: context.text.bodyLarge),
                ],
              ),
            ),
          if (hasOwnSide) MarginNote('Hay una pieza que no es de su lado: suena a tu postura o a una caricatura de la suya.'),
          if (last != null && last.missing.isNotEmpty && state != Recognition.noRepresenta) ...[
            const Gap(8),
            for (final s in last.missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(common.slot(s).missing, style: context.text.bodySmall),
              ),
          ],
          const Gap(16),
          const Divider(),
          const Gap(8),
          Text(common.disclosure, style: context.text.bodySmall),
          const Gap(4),
          Text(common.simulationNote, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- fuerza
class StrengthStage extends ConsumerStatefulWidget {
  const StrengthStage({super.key, required this.exp, required this.progress});
  final ExperienceDef exp;
  final ExperienceProgress progress;

  @override
  ConsumerState<StrengthStage> createState() => _StrengthStageState();
}

class _StrengthStageState extends ConsumerState<StrengthStage> {
  int? _strength;
  int? _agreement;

  static String? messageFor(int? strength, int? agreement) {
    if (strength == null || agreement == null) return null;
    if (strength >= 4 && agreement <= 2) {
      return 'Encontraste fuerte un argumento con el que no estás de acuerdo. Eso es comprender sin ceder.';
    }
    if (strength >= 4 && agreement >= 4) {
      return 'Te parece fuerte y también te convence. Al volver a tu lado verás si algo se movió.';
    }
    if (strength <= 2) {
      return 'Todavía te parece débil. Puede que falte una pieza, o que de verdad lo sea.';
    }
    return 'Anotado. Una fuerza intermedia también es una respuesta.';
  }

  @override
  Widget build(BuildContext context) {
    final msg = messageFor(_strength, _agreement);
    return StageFrame(
      experienceId: widget.exp.id,
      title: widget.exp.title,
      stage: widget.progress.stage,
      reverse: true,
      bottom: FilledButton(
        key: const ValueKey('strength_done'),
        onPressed: _strength == null || _agreement == null
            ? null
            : () => ref.read(experienceActionsProvider(widget.exp.id)).submitStrength(_strength!, _agreement!),
        child: const Text('Volver a mi lado'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fuerza y acuerdo son cosas distintas.', style: context.text.headlineSmall),
          const Gap(20),
          Text('¿Qué tan fuerte te parece este argumento?', style: context.text.titleMedium),
          const Gap(8),
          FiveStepSelector(
            value: _strength,
            lowLabel: 'Muy débil',
            highLabel: 'Muy fuerte',
            semanticsLabel: 'Fuerza del argumento',
            onChanged: (v) => setState(() => _strength = v),
          ),
          const Gap(24),
          Text('¿Qué tan de acuerdo estás con él?', style: context.text.titleMedium),
          const Gap(8),
          FiveStepSelector(
            value: _agreement,
            lowLabel: 'Nada',
            highLabel: 'Totalmente',
            semanticsLabel: 'Acuerdo con el argumento',
            onChanged: (v) => setState(() => _agreement = v),
          ),
          if (msg != null) ...[
            const Gap(24),
            Semantics(liveRegion: true, child: MarginNote(msg)),
          ],
        ],
      ),
    );
  }
}
