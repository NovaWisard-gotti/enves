import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';
import '../../engine/map/map_builder.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ink_marks.dart';
import '../../widgets/paper.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.demo});
  final bool demo;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _list = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider).valueOrNull;
    final MapModel? model;
    if (widget.demo) {
      model = ref.watch(demoMapProvider).valueOrNull;
    } else {
      model = ref.watch(mapModelProvider);
    }
    final notes = widget.demo ? const <String, String>{} : (ref.watch(userStateProvider).valueOrNull?.notes ?? const {});
    final back = () => context.canPop() ? context.pop() : context.go('/');

    if (content == null || model == null) {
      return PaperPage(title: 'Tu mapa', onBack: back, child: const SizedBox.shrink());
    }

    return PaperPage(
      title: widget.demo ? 'Mapa de demostración' : 'Tu mapa',
      onBack: back,
      banner: widget.demo
          ? NoticeBanner(
              text: 'Demostración: estas no son tus respuestas. Nada de aquí se guarda.',
              emphasis: true,
              actionLabel: 'Cuaderno',
              onAction: () => context.push('/cuaderno?demo=1'),
            )
          : null,
      child: model.isEmpty
          ? _EmptyMap(onDemo: () => context.push('/mapa?demo=1'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No es un test ni un perfil. Describe decisiones que tomaste en situaciones concretas.',
                  style: context.text.bodySmall,
                ),
                const Gap(12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Mapa')),
                    ButtonSegment(value: true, label: Text('Lista')),
                  ],
                  selected: {_list},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _list = s.first),
                ),
                const Gap(20),
                SectionLabel('Tensiones'),
                for (final a in model.axes)
                  _list
                      ? _AxisText(view: a, onOpen: () => _openAxis(context, content, a, notes[a.key]))
                      : _AxisGraphic(view: a, onOpen: () => _openAxis(context, content, a, notes[a.key])),
                if (model.confidenceStatement != null) ...[
                  const Gap(8),
                  Text(model.confidenceStatement!, style: context.text.bodyLarge),
                ],
                const Gap(28),
                SectionLabel('Del otro lado'),
                if (model.hollowStatement != null) Text(model.hollowStatement!, style: context.text.bodyLarge),
                if (model.strongWithoutAgreement != null) ...[
                  const Gap(6),
                  Text(model.strongWithoutAgreement!, style: context.text.bodyLarge),
                ],
                const Gap(12),
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    for (final h in model.hollows)
                      Semantics(
                        label: '${h.title}: ${content.common.recognition[h.recognition] ?? h.recognition}',
                        excludeSemantics: true,
                        child: Column(
                          children: [
                            InkDot(
                              style: h.recognition == Recognition.fuerte
                                  ? DotStyle.ringed
                                  : (Recognition.isRecognized(h.recognition) ? DotStyle.hollow : DotStyle.dashed),
                              size: 22,
                              color: h.recognition == Recognition.fuerte ? context.enves.saffron : null,
                            ),
                            const Gap(4),
                            SizedBox(
                              width: 76,
                              child: Text(h.title, style: context.text.bodySmall, textAlign: TextAlign.center, maxLines: 2),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (model.threads.isNotEmpty) ...[
                  const Gap(28),
                  SectionLabel('Hilos'),
                  for (final t in model.threads)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MarginNote(
                        t.kind == 'memoria'
                            ? '${content.titleOf(t.from)} volvió en ${content.titleOf(t.to)}'
                            : '${content.titleOf(t.from)} y ${content.titleOf(t.to)} comparten una razón',
                        child: Text(t.label, style: context.text.bodyLarge),
                      ),
                    ),
                ],
                if (model.openQuestions.isNotEmpty) ...[
                  const Gap(28),
                  SectionLabel('Preguntas abiertas'),
                  for (final q in model.openQuestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.question, style: context.text.titleLarge),
                          if (q.stanceLabel.isNotEmpty) Text('Por ahora: ${q.stanceLabel}', style: context.text.bodyLarge),
                          if (q.reasonText.isNotEmpty) Text('Porque: ${q.reasonText}', style: context.text.bodySmall),
                          if (q.recognition != null)
                            Text(
                              'Del otro lado: ${content.common.recognition[q.recognition] ?? ''}',
                              style: context.text.bodySmall,
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  void _openAxis(BuildContext context, ContentBundle content, AxisView view, String? note) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _AxisDetail(view: view, content: content, demo: widget.demo, initialNote: note),
    );
  }
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap({required this.onDemo});
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(40),
        const CrossGlyph(),
        const Gap(20),
        Text('Tu mapa aparecerá cuando termines tu primera pregunta.', style: context.text.headlineSmall),
        const Gap(12),
        Text('Se construye solo con lo que eliges. No hay nada que rellenar.', style: context.text.bodyLarge),
        const Gap(24),
        OutlinedButton(onPressed: onDemo, child: const Text('Ver un recorrido de demostración')),
      ],
    );
  }
}

String _valueText(AxisDef axis, int v) {
  if (v == 0) return 'No lo sé';
  final pole = v < 0 ? axis.left : axis.right;
  return '$pole (${confidenceLabelFor(v)})';
}

class _AxisGraphic extends StatelessWidget {
  const _AxisGraphic({required this.view, required this.onOpen});
  final AxisView view;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return Semantics(
      button: true,
      label: '${view.axis.left} frente a ${view.axis.right}. ${view.statement}',
      hint: 'Abrir detalle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(view.axis.left, style: context.text.labelLarge)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(view.axis.right, style: context.text.labelLarge, textAlign: TextAlign.right)),
                ],
              ),
              SizedBox(
                height: 64,
                child: CustomPaint(
                  painter: _AxisPainter(
                    view: view,
                    ink: e.ink,
                    graphite: e.graphite,
                    saffron: e.saffron,
                    divider: e.divider,
                  ),
                ),
              ),
              Text(view.statement, style: context.text.bodyMedium),
              if (view.contextStatement != null) Text(view.contextStatement!, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _AxisPainter extends CustomPainter {
  _AxisPainter({required this.view, required this.ink, required this.graphite, required this.saffron, required this.divider});
  final AxisView view;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color divider;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 12.0;
    final cy = size.height / 2;
    final half = (size.width - pad * 2) / 2;
    final center = size.width / 2;
    double x(int v) => center + v / 3 * half;
    canvas.drawLine(Offset(pad, cy), Offset(size.width - pad, cy), Paint()
      ..color = divider
      ..strokeWidth = 2);
    canvas.drawLine(Offset(center, cy - 14), Offset(center, cy + 14), Paint()
      ..color = graphite
      ..strokeWidth = 1.5);
    if (view.consolidated && view.decided > 0) {
      canvas.drawLine(Offset(x(view.min), cy), Offset(x(view.max), cy), Paint()
        ..color = ink
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round);
    }
    final counts = <int, int>{};
    for (final m in view.mainMarks) {
      final n = counts[m.value] ?? 0;
      counts[m.value] = n + 1;
      final dy = cy + (n.isEven ? -1 : 1) * ((n + 1) ~/ 2) * 11.0;
      final color = view.consolidated ? ink : graphite;
      if (m.value == 0) {
        canvas.drawCircle(Offset(x(0), dy), 5, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        canvas.drawCircle(Offset(x(m.value), dy), 6, Paint()..color = color);
      }
      if (m.revised && m.initialValue != null) {
        canvas.drawCircle(Offset(x(m.initialValue!), dy), 5, Paint()
          ..color = saffron
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AxisPainter old) => old.view != view || old.ink != ink;
}

class _AxisText extends StatelessWidget {
  const _AxisText({required this.view, required this.onOpen});
  final AxisView view;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.enves.divider))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${view.axis.left} frente a ${view.axis.right}', style: context.text.titleMedium),
            const Gap(4),
            Text(view.statement, style: context.text.bodyMedium),
            if (view.contextStatement != null) Text(view.contextStatement!, style: context.text.bodySmall),
            for (final m in view.mainMarks)
              Text('${m.title}: ${_valueText(view.axis, m.value)}', style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AxisDetail extends ConsumerStatefulWidget {
  const _AxisDetail({required this.view, required this.content, required this.demo, this.initialNote});
  final AxisView view;
  final ContentBundle content;
  final bool demo;
  final String? initialNote;

  @override
  ConsumerState<_AxisDetail> createState() => _AxisDetailState();
}

class _AxisDetailState extends ConsumerState<_AxisDetail> {
  late final TextEditingController _note = TextEditingController(text: widget.initialNote ?? '');
  bool _saved = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _outcome(String? o) {
    switch (o) {
      case TensionOutcomeKind.mantener:
        return 'Mantuviste tu razón';
      case TensionOutcomeKind.matizar:
        return 'Matizaste';
      case TensionOutcomeKind.revisar:
        return 'Revisaste';
      case TensionOutcomeKind.noAplica:
        return 'Dijiste que no aplicaba';
      default:
        return '';
    }
  }

  Future<void> _save() async {
    final engine = ref.read(engineProvider);
    final user = ref.read(userStateProvider).valueOrNull;
    if (engine == null || user == null) return;
    await ref.read(userStateProvider.notifier).commit(engine.saveNote(user, widget.view.key, _note.text));
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          Text('${v.axis.left} frente a ${v.axis.right}', style: context.text.headlineSmall),
          const Gap(8),
          Text(v.statement, style: context.text.bodyLarge),
          if (v.contextStatement != null) ...[
            const Gap(6),
            Text(v.contextStatement!, style: context.text.bodyMedium),
          ],
          const Gap(20),
          SectionLabel('En cada situación'),
          if (v.marks.isEmpty) Text('Todavía no hay experiencias en esta tensión.', style: context.text.bodySmall),
          for (final m in v.marks)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.enves.divider))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.context == null ? m.title : '${m.title} (${m.context == 'cercanos' ? 'personas cercanas' : 'desconocidos'})',
                    style: context.text.titleMedium,
                  ),
                  Text(_valueText(v.axis, m.value), style: context.text.bodyLarge),
                  if (m.revised) Text('Antes: ${_valueText(v.axis, m.initialValue!)}', style: context.text.bodySmall),
                  if (_outcome(m.outcome).isNotEmpty) Text(_outcome(m.outcome), style: context.text.bodySmall),
                  if (m.distinctionName != null && m.distinctionName!.isNotEmpty)
                    Text('Distinción: ${m.distinctionName}', style: context.text.bodySmall),
                ],
              ),
            ),
          const Gap(20),
          if (!widget.demo) ...[
            SectionLabel('Tu nota (privada)'),
            TextField(
              controller: _note,
              maxLength: 280,
              maxLines: 3,
              onChanged: (_) {
                if (_saved) setState(() => _saved = false);
              },
              decoration: const InputDecoration(hintText: 'Lo que quieras recordar de esta tensión'),
            ),
            Row(
              children: [
                TextButton(onPressed: _save, child: const Text('Guardar nota')),
                if (_saved) Text('Guardada', style: context.text.bodySmall),
              ],
            ),
          ],
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
