import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/json.dart';
import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../engine/fairness/fairness_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/ink_marks.dart';
import '../../../widgets/paper.dart';

typedef ProbeDone = void Function(Json result);

/// Despacha cada tipo de mecánica a su widget.
class ProbeView extends StatelessWidget {
  const ProbeView({super.key, required this.experienceId, required this.probe, required this.onDone});
  final String experienceId;
  final ProbeDef probe;
  final ProbeDone onDone;

  @override
  Widget build(BuildContext context) {
    final c = probe.config;
    final Widget body;
    switch (probe.type) {
      case 'twinCases':
        body = TwinCasesProbe(config: c, onDone: onDone);
      case 'choiceVariant':
        body = ChoiceVariantProbe(config: c, onDone: onDone);
      case 'proximityRings':
        body = ProximityRingsProbe(config: c, onDone: onDone);
      case 'ladder':
        body = LadderProbe(config: c, onDone: onDone);
      case 'fairnessSimulator':
        body = FairnessSimulatorProbe(config: c, onDone: onDone);
      case 'flowMatrix':
        body = FlowMatrixProbe(config: c, onDone: onDone);
      case 'annotatedLetter':
        body = AnnotatedLetterProbe(config: c, onDone: onDone);
      case 'replacementGradient':
        body = ReplacementGradientProbe(config: c, onDone: onDone);
      case 'knowingForms':
        body = KnowingFormsProbe(experienceId: experienceId, config: c, onDone: onDone);
      default:
        body = FilledButton(onPressed: () => onDone(const {}), child: const Text('Seguir'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (probe.prompt.isNotEmpty) ...[
          Semantics(header: true, child: Text(probe.prompt, style: context.text.titleLarge)),
          const Gap(16),
        ],
        body,
      ],
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onPressed, this.label = 'Listo'});
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: FilledButton(key: const ValueKey('probe_done'), onPressed: onPressed, child: Text(label)),
      );
}

// ------------------------------------------------------------- casos gemelos
class TwinCasesProbe extends StatefulWidget {
  const TwinCasesProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  State<TwinCasesProbe> createState() => _TwinCasesProbeState();
}

class _TwinCasesProbeState extends State<TwinCasesProbe> {
  final Map<String, int> _values = {};

  @override
  Widget build(BuildContext context) {
    final subjects = asJsonList(widget.config['subjects']);
    final scale = asStringList(widget.config['scale']);
    final ready = subjects.isNotEmpty && subjects.every((s) => _values.containsKey(asString(s['id'])));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in subjects) ...[
          Text(asString(s['label']), style: context.text.titleMedium),
          const Gap(4),
          FiveStepSelector(
            value: _values[asString(s['id'])] == null ? null : _values[asString(s['id'])]! + 1,
            lowLabel: scale.isNotEmpty ? scale.first : '',
            highLabel: scale.isNotEmpty ? scale.last : '',
            stepLabels: scale.length == 5 ? scale : null,
            semanticsLabel: 'Reproche a ${asString(s['label'])}',
            onChanged: (v) => setState(() => _values[asString(s['id'])] = v - 1),
          ),
          const Gap(16),
        ],
        _DoneButton(
          onPressed: !ready
              ? null
              : () {
                  final ids = subjects.map((s) => asString(s['id'])).toList();
                  final result = <String, dynamic>{for (final id in ids) id: _values[id]};
                  result['diff'] = _values[ids.last]! - _values[ids.first]!;
                  widget.onDone(result);
                },
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ variante simple
class ChoiceVariantProbe extends StatefulWidget {
  const ChoiceVariantProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  State<ChoiceVariantProbe> createState() => _ChoiceVariantProbeState();
}

class _ChoiceVariantProbeState extends State<ChoiceVariantProbe> {
  String? _choice;

  @override
  Widget build(BuildContext context) {
    final options = asJsonList(widget.config['options']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in options)
          RuledOption(
            label: asString(o['label']),
            serif: true,
            selected: _choice == asString(o['id']),
            onTap: () => setState(() => _choice = asString(o['id'])),
          ),
        _DoneButton(onPressed: _choice == null ? null : () => widget.onDone({'choice': _choice})),
      ],
    );
  }
}

// ------------------------------------------------------- círculo de cercanía
class ProximityRingsProbe extends StatefulWidget {
  const ProximityRingsProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  State<ProximityRingsProbe> createState() => _ProximityRingsProbeState();
}

class _ProximityRingsProbeState extends State<ProximityRingsProbe> {
  final Map<String, int> _values = {};

  @override
  Widget build(BuildContext context) {
    final rings = asJsonList(widget.config['rings']);
    final choices = asJsonList(widget.config['choices']);
    final ready = rings.every((r) => _values.containsKey(asString(r['id'])));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rings.length; i++) ...[
          Row(
            children: [
              ExcludeSemantics(child: _Rings(level: i + 2)),
              const SizedBox(width: 10),
              Expanded(child: Text(asString(rings[i]['label']), style: context.text.titleMedium)),
            ],
          ),
          for (final c in choices)
            RuledOption(
              label: asString(c['label']),
              selected: _values[asString(rings[i]['id'])] == asInt(c['value']),
              onTap: () => setState(() => _values[asString(rings[i]['id'])] = asInt(c['value'])),
            ),
          const Gap(16),
        ],
        _DoneButton(onPressed: ready ? () => widget.onDone(Map<String, dynamic>.from(_values)) : null),
      ],
    );
  }
}

class _Rings extends StatelessWidget {
  const _Rings({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        height: 32,
        child: CustomPaint(painter: _RingsPainter(level, context.enves.ink, context.enves.graphite)),
      );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.level, this.ink, this.graphite);
  final int level;
  final Color ink;
  final Color graphite;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        c,
        size.width / 2 * i / 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == level ? 2.5 : 1
          ..color = i == level ? ink : graphite,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.level != level || old.ink != ink;
}

// ----------------------------------------------------------------- escalera
class LadderProbe extends StatefulWidget {
  const LadderProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  State<LadderProbe> createState() => _LadderProbeState();
}

class _LadderProbeState extends State<LadderProbe> {
  int? _line;

  @override
  Widget build(BuildContext context) {
    final rungs = asStringList(widget.config['rungs']);
    final never = asString(widget.config['never'], 'Nunca');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('De menos a más grave. Elige el primer peldaño en el que mentir te parecería aceptable.',
            style: context.text.bodySmall),
        const Gap(8),
        for (var i = 0; i < rungs.length; i++)
          RuledOption(
            label: rungs[i],
            detail: 'Peldaño ${i + 1}',
            serif: true,
            selected: _line == i + 1,
            leading: InkDot(
              style: _line != null && _line != 0 && i + 1 >= _line! ? DotStyle.filled : DotStyle.hollow,
              size: 12.0 + i * 3,
            ),
            onTap: () => setState(() => _line = i + 1),
          ),
        RuledOption(label: never, selected: _line == 0, onTap: () => setState(() => _line = 0)),
        _DoneButton(onPressed: _line == null ? null : () => widget.onDone({'line': _line})),
      ],
    );
  }
}

// --------------------------------------------------------- simulador becas
class FairnessSimulatorProbe extends StatefulWidget {
  const FairnessSimulatorProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  State<FairnessSimulatorProbe> createState() => _FairnessSimulatorProbeState();
}

class _FairnessSimulatorProbeState extends State<FairnessSimulatorProbe> {
  late final FairnessModel _model = FairnessModel.fromConfig(widget.config);
  int _north = 5;
  int _south = 5;
  bool _same = true;
  int _moves = 0;
  bool _reached1 = false;
  bool _reached2 = false;
  bool _revealed = false;

  List<int> get _thresholds => _model.thresholds;

  void _change({int? north, int? south}) {
    setState(() {
      if (north != null) {
        _north = north;
        if (_same) _south = north;
      }
      if (south != null) {
        _south = south;
        if (_same) _north = south;
      }
      _moves++;
      final r = _model.evaluate(_thresholds[_north], _thresholds[_south]);
      _reached1 = _reached1 || r.indicator1;
      _reached2 = _reached2 || r.indicator2;
      if ((_moves >= 3 && (_reached1 || _reached2)) || _moves >= 8) _revealed = true;
    });
  }

  String _pct(double? v) => v == null ? 'sin becas' : '${(v * 100).round()} %';

  @override
  Widget build(BuildContext context) {
    if (!_model.isValid) {
      return _DoneButton(onPressed: () => widget.onDone({'attempts': 0}), label: 'Seguir');
    }
    final g = _model.groups;
    final t = _thresholds;
    _north = _north.clamp(0, t.length - 1).toInt();
    _south = _south.clamp(0, t.length - 1).toInt();
    final r = _model.evaluate(t[_north], t[_south]);
    final i1Help = asString(widget.config['indicator1Help']);
    final i2Help = asString(widget.config['indicator2Help']);

    Widget slider(String label, int value, ValueChanged<int> onChanged) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: puntaje mínimo ${t[value]}', style: context.text.titleMedium),
            Slider(
              value: value.toDouble(),
              min: 0,
              max: (t.length - 1).toDouble(),
              divisions: t.length - 1,
              label: '${t[value]}',
              semanticFormatterCallback: (v) => 'Puntaje mínimo ${t[v.round()]}',
              onChanged: (v) {
                if (v.round() != value) onChanged(v.round());
              },
            ),
          ],
        );

    Widget groupLine(FairnessGroup group, GroupMetrics m) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '${group.label}: ${m.awarded} becas, de las que terminarían ${m.truePositives}. '
            'Quedan fuera ${m.falseNegatives} que sí habrían terminado.',
            style: context.text.bodySmall,
          ),
        );

    Widget indicator(String title, String help, bool met, String detail) => Semantics(
          liveRegion: true,
          label: '$title: ${met ? 'se cumple' : 'no se cumple'}. $detail',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 12),
                  child: InkDot(style: met ? DotStyle.filled : DotStyle.hollow, size: 18),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleMedium),
                      Text(met ? 'Se cumple' : 'No se cumple', style: context.text.labelMedium),
                      Text(detail, style: context.text.bodySmall),
                      if (help.isNotEmpty) Text(help, style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Mismo puntaje mínimo en ambos barrios', style: context.text.bodyMedium),
          value: _same,
          onChanged: (v) => setState(() {
            _same = v;
            if (v) _south = _north;
          }),
        ),
        slider(g[0].label, _north, (v) => _change(north: v)),
        slider(g[1].label, _south, (v) => _change(south: v)),
        const Gap(8),
        groupLine(g[0], r.north),
        groupLine(g[1], r.south),
        const Divider(),
        indicator(
          asString(widget.config['indicator1']),
          i1Help,
          r.indicator1,
          '${g[0].label}: ${_pct(r.north.predictive)}. ${g[1].label}: ${_pct(r.south.predictive)}.',
        ),
        indicator(
          asString(widget.config['indicator2']),
          i2Help,
          r.indicator2,
          'Negadas por error: ${_pct(r.north.deniedByError)} y ${_pct(r.south.deniedByError)}. '
              'Dadas por error: ${_pct(r.north.grantedByError)} y ${_pct(r.south.grantedByError)}.',
        ),
        if (!_revealed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Intenta que se cumplan los dos criterios.', style: context.text.bodySmall),
          ),
        if (_revealed) ...[
          const Gap(12),
          MarginNote(asString(widget.config['reveal'])),
        ],
        _DoneButton(
          label: 'Seguir',
          onPressed: !_revealed
              ? null
              : () => widget.onDone({
                    'attempts': _moves,
                    'north': t[_north],
                    'south': t[_south],
                    'reachedI1': _reached1,
                    'reachedI2': _reached2,
                    'bothEver': false,
                  }),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ mapa de flujos
class FlowMatrixProbe extends StatefulWidget {
  const FlowMatrixProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  State<FlowMatrixProbe> createState() => _FlowMatrixProbeState();
}

class _FlowMatrixProbeState extends State<FlowMatrixProbe> {
  final Set<String> _accepted = {};

  @override
  Widget build(BuildContext context) {
    final rows = asStringList(widget.config['rows']);
    final cols = asStringList(widget.config['columns']);
    final total = rows.length * cols.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          Text(rows[r], style: context.text.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (var c = 0; c < cols.length; c++)
                _ToggleBox(
                  label: cols[c],
                  semantics: '${rows[r]}, ${cols[c]}',
                  checked: _accepted.contains('$r:$c'),
                  onTap: () => setState(() {
                    final key = '$r:$c';
                    if (!_accepted.remove(key)) _accepted.add(key);
                  }),
                ),
            ],
          ),
          const Gap(12),
        ],
        Text('Marcaste ${_accepted.length} de $total.', style: context.text.bodySmall),
        _DoneButton(
          onPressed: () {
            final accepted = _accepted.length;
            final level = total == 0 ? 0 : ((accepted / total) * 4 - 2).round();
            widget.onDone({
              'accepted': accepted,
              'total': total,
              'contextual': accepted > 0 && accepted < total,
              'level': level,
              'cells': _accepted.toList()..sort(),
            });
          },
        ),
      ],
    );
  }
}

class _ToggleBox extends StatelessWidget {
  const _ToggleBox({required this.label, required this.semantics, required this.checked, required this.onTap});
  final String label;
  final String semantics;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      label: semantics,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: checked ? context.enves.ink : context.enves.graphite, width: checked ? 2 : 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkDot(style: checked ? DotStyle.filled : DotStyle.hollow, size: 12),
              const SizedBox(width: 8),
              Text(label, style: context.text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- carta anotada
class AnnotatedLetterProbe extends StatefulWidget {
  const AnnotatedLetterProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  State<AnnotatedLetterProbe> createState() => _AnnotatedLetterProbeState();
}

class _AnnotatedLetterProbeState extends State<AnnotatedLetterProbe> {
  final Set<int> _marked = {};
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final phrases = asStringList(widget.config['phrases']);
    final e = context.enves;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < phrases.length; i++)
          Semantics(
            button: true,
            selected: _marked.contains(i),
            label: phrases[i],
            hint: 'Marcar como frase que suena a comprensión',
            excludeSemantics: true,
            child: InkWell(
              onTap: _revealed
                  ? null
                  : () => setState(() {
                        if (!_marked.remove(i)) _marked.add(i);
                      }),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: _marked.contains(i) ? e.saffron : e.divider, width: 3)),
                ),
                child: Text(
                  phrases[i],
                  style: context.text.bodyLarge?.copyWith(
                    decoration: _marked.contains(i) ? TextDecoration.underline : null,
                    decorationColor: e.saffron,
                  ),
                ),
              ),
            ),
          ),
        const Gap(12),
        if (_revealed) MarginNote(asString(widget.config['reveal'])),
        _DoneButton(
          label: _revealed ? 'Seguir' : 'Ya la leí',
          onPressed: _revealed
              ? () => widget.onDone({'marked': _marked.length, 'revealed': true})
              : () => setState(() => _revealed = true),
        ),
      ],
    );
  }
}

// ---------------------------------------------------- gradiente de reemplazo
class ReplacementGradientProbe extends StatefulWidget {
  const ReplacementGradientProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  State<ReplacementGradientProbe> createState() => _ReplacementGradientProbeState();
}

class _ReplacementGradientProbeState extends State<ReplacementGradientProbe> {
  double _value = 50;
  bool _never = false;
  bool _touched = false;

  @override
  Widget build(BuildContext context) {
    final min = asDouble(widget.config['min'], 10);
    final max = asDouble(widget.config['max'], 100);
    final step = asDouble(widget.config['step'], 10);
    final divisions = ((max - min) / step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_never ? 'Nunca dejarías de ser tú' : 'Dejarías de ser tú al reemplazar el ${_value.round()} %',
            style: context.text.titleMedium),
        Slider(
          value: _value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${_value.round()} %',
          semanticFormatterCallback: (v) => '${v.round()} por ciento reemplazado',
          onChanged: _never
              ? null
              : (v) => setState(() {
                    _value = v;
                    _touched = true;
                  }),
        ),
        RuledOption(
          label: asString(widget.config['never'], 'Nunca dejaría de ser yo'),
          selected: _never,
          onTap: () => setState(() {
            _never = !_never;
            _touched = true;
          }),
        ),
        _DoneButton(
          onPressed: !_touched
              ? null
              : () => widget.onDone(_never ? {'never': true} : {'stop': _value.round()}),
        ),
      ],
    );
  }
}

// ------------------------------------------------------ tres formas de saber
class KnowingFormsProbe extends ConsumerStatefulWidget {
  const KnowingFormsProbe({super.key, required this.experienceId, required this.config, required this.onDone});
  final String experienceId;
  final Json config;
  final ProbeDone onDone;

  @override
  ConsumerState<KnowingFormsProbe> createState() => _KnowingFormsProbeState();
}

class _KnowingFormsProbeState extends ConsumerState<KnowingFormsProbe> {
  final Map<String, String> _answers = {};

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider).valueOrNull;
    final user = ref.watch(userStateProvider).valueOrNull;
    if (content == null || user == null) return const SizedBox.shrink();
    final items = <({String id, String title, String position})>[];
    for (final e in content.experiences) {
      final p = user.experiences[e.id];
      final c = p?.cruza;
      if (p == null || c == null || c.finalRecognition == null) continue;
      final include = p.status == ExpStatus.completed || e.id == widget.experienceId;
      if (!include) continue;
      items.add((id: e.id, title: e.title, position: e.pole(c.target).label));
    }
    final options = asJsonList(widget.config['options']);
    final ready = items.every((i) => _answers.containsKey(i.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          Text(item.title, style: context.text.labelMedium),
          Text('«${item.position}»', style: context.text.bodyLarge),
          for (final o in options)
            RuledOption(
              label: asString(o['label']),
              selected: _answers[item.id] == asString(o['id']),
              onTap: () => setState(() => _answers[item.id] = asString(o['id'])),
            ),
          const Gap(16),
        ],
        _DoneButton(
          onPressed: !ready
              ? null
              : () {
                  final counts = <String, dynamic>{'items': items.length};
                  for (final o in options) {
                    final id = asString(o['id']);
                    counts[id] = _answers.values.where((v) => v == id).length;
                  }
                  widget.onDone(counts);
                },
        ),
      ],
    );
  }
}
