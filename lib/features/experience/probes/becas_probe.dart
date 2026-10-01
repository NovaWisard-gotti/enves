import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/json.dart';
import '../../../engine/fairness/fairness_model.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/hilo_vivo.dart';
import '../../../widgets/ink_marks.dart';
import '../../../widgets/paper.dart';

/// Una persona simplificada del barrio: su puntaje y si terminaría.
class Persona {
  const Persona(this.score, this.termina);
  final int score;
  final bool termina;
}

/// Muestra proporcional de [total] personas por barrio a partir de los datos
/// reales del modelo (mayor resto). Las métricas se siguen calculando con el
/// modelo completo; esto solo es la representación visual.
List<Persona> muestraDe(FairnessGroup g, int total) {
  final sum = g.bins.fold<int>(0, (a, b) => a + b.n);
  if (sum == 0) return const [];
  final raw = [for (final b in g.bins) b.n * total / sum];
  final counts = [for (final r in raw) r.floor()];
  var rest = total - counts.fold<int>(0, (a, b) => a + b);
  final order = List<int>.generate(raw.length, (i) => i)..sort((a, b) => (raw[b] - raw[b].floor()).compareTo(raw[a] - raw[a].floor()));
  for (final i in order) {
    if (rest <= 0) break;
    counts[i]++;
    rest--;
  }
  final out = <Persona>[];
  for (var i = 0; i < g.bins.length; i++) {
    final b = g.bins[i];
    final k = counts[i];
    final fin = b.n == 0 ? 0 : (b.pos / b.n * k).round().clamp(0, k);
    for (var j = 0; j < k; j++) {
      out.add(Persona(b.score, j < fin));
    }
  }
  return out;
}

/// E5 — Cien becas. Cien personas (cincuenta por barrio) se mueven en tiempo
/// real entre «con beca» y «sin beca». Los dos criterios de justicia
/// reaccionan: cuando uno se acerca, el otro se aleja.
class FairnessSimulatorProbe extends ConsumerStatefulWidget {
  const FairnessSimulatorProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final void Function(Json result) onDone;

  @override
  ConsumerState<FairnessSimulatorProbe> createState() => _FairnessSimulatorProbeState();
}

class _FairnessSimulatorProbeState extends ConsumerState<FairnessSimulatorProbe> with SingleTickerProviderStateMixin {
  late final FairnessModel _model = FairnessModel.fromConfig(widget.config);
  late final List<List<Persona>> _gente = _model.isValid ? [muestraDe(_model.groups[0], 50), muestraDe(_model.groups[1], 50)] : const [];
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);
  int _north = 5;
  int _south = 5;
  bool _same = true;
  int _moves = 0;
  bool _reached1 = false;
  bool _reached2 = false;
  bool _revealed = false;
  int _prevNorth = 5;
  int _prevSouth = 5;
  String? _tension;
  int _tensions = 0;

  List<int> get _thresholds => _model.thresholds;

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  static double gap1(FairnessResult r) {
    final a = r.north.predictive;
    final b = r.south.predictive;
    if (a == null || b == null) return 0.5;
    return (a - b).abs();
  }

  static double gap2(FairnessResult r) {
    if (r.north.predictive == null || r.south.predictive == null) return 0.5;
    return math.max((r.north.deniedByError - r.south.deniedByError).abs(), (r.north.grantedByError - r.south.grantedByError).abs());
  }

  void _change({int? north, int? south}) {
    final t = _thresholds;
    final before = _model.evaluate(t[_north], t[_south]);
    setState(() {
      _prevNorth = _north;
      _prevSouth = _south;
      if (north != null) {
        _north = north;
        if (_same) _south = north;
      }
      if (south != null) {
        _south = south;
        if (_same) _north = south;
      }
      _moves++;
      final r = _model.evaluate(t[_north], t[_south]);
      _reached1 = _reached1 || r.indicator1;
      _reached2 = _reached2 || r.indicator2;
      final d1 = gap1(r) - gap1(before);
      final d2 = gap2(r) - gap2(before);
      if ((d1 < -0.004 && d2 > 0.004) || (d1 > 0.004 && d2 < -0.004)) {
        _tension = d1 < 0 ? 'El primer criterio se acerca; el segundo se aleja.' : 'El segundo criterio se acerca; el primero se aleja.';
        _tensions++;
      } else {
        _tension = null;
      }
      final wasRevealed = _revealed;
      if ((_moves >= 3 && (_reached1 || _reached2)) || _moves >= 8 || _tensions >= 3) _revealed = true;
      if (_revealed && !wasRevealed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(feedbackProvider).discovery();
        });
      }
    });
    ref.read(feedbackProvider).selection();
    if (reducedMotionNow(context, ref)) {
      _move.value = 1;
    } else {
      _move.forward(from: 0);
    }
  }

  String _pct(double? v) => v == null ? 'sin becas' : '${(v * 100).round()} %';

  @override
  Widget build(BuildContext context) {
    if (!_model.isValid) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: FilledButton(onPressed: () => widget.onDone({'attempts': 0}), child: const Text('Seguir')),
      );
    }
    final g = _model.groups;
    final t = _thresholds;
    _north = _north.clamp(0, t.length - 1).toInt();
    _south = _south.clamp(0, t.length - 1).toInt();
    final r = _model.evaluate(t[_north], t[_south]);
    final i1Help = asString(widget.config['indicator1Help']);
    final i2Help = asString(widget.config['indicator2Help']);
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    final becadosN = _gente[0].where((p) => p.score >= t[_north]).length;
    final becadosS = _gente[1].where((p) => p.score >= t[_south]).length;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Mismo puntaje mínimo en ambos barrios', style: context.text.bodyMedium),
          value: _same,
          onChanged: (v) {
            setState(() => _same = v);
            if (v && _south != _north) _change(north: _north);
          },
        ),
        Semantics(
          label: 'Cien personas. ${g[0].label}: $becadosN de 50 con beca. ${g[1].label}: $becadosS de 50 con beca. '
              'Punto lleno: terminaría sus estudios. Punto hueco: no los terminaría.',
          excludeSemantics: true,
          child: AnimatedBuilder(
            animation: _move,
            builder: (context, _) => CustomPaint(
              size: const Size(double.infinity, 250),
              painter: BecasPainter(
                gente: _gente,
                umbrales: [t[_north], t[_south]],
                previos: [t[_prevNorth], t[_prevSouth]],
                t: Motion.settle.transform(_move.value),
                etiquetas: [g[0].label, g[1].label],
                ink: e.ink,
                graphite: e.graphite,
                saffron: e.saffron,
                paper: e.paper,
                divider: e.divider,
                estilo: context.text.bodySmall!,
                estiloFuerte: context.text.labelMedium!,
              ),
            ),
          ),
        ),
        const Gap(6),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              InkDot(size: 10, color: e.ink),
              const SizedBox(width: 6),
              Flexible(child: Text('terminaría sus estudios', style: context.text.bodySmall)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              InkDot(style: DotStyle.hollow, size: 10, color: e.ink),
              const SizedBox(width: 6),
              Flexible(child: Text('no los terminaría', style: context.text.bodySmall)),
            ]),
          ],
        ),
        const Gap(12),
        slider(g[0].label, _north, (v) => _change(north: v)),
        slider(g[1].label, _south, (v) => _change(south: v)),
        const Gap(16),
        const Divider(),
        _Criterio(
          titulo: asString(widget.config['indicator1']),
          ayuda: i1Help,
          cumple: r.indicator1,
          gap: gap1(r),
          tolerancia: _model.tolerance,
          detalle: '${g[0].label}: ${_pct(r.north.predictive)}. ${g[1].label}: ${_pct(r.south.predictive)}.',
          reduced: reduced,
        ),
        _Criterio(
          titulo: asString(widget.config['indicator2']),
          ayuda: i2Help,
          cumple: r.indicator2,
          gap: gap2(r),
          tolerancia: _model.tolerance,
          detalle: 'Negadas por error: ${_pct(r.north.deniedByError)} y ${_pct(r.south.deniedByError)}. '
              'Dadas por error: ${_pct(r.north.grantedByError)} y ${_pct(r.south.grantedByError)}.',
          reduced: reduced,
        ),
        AnimatedSize(
          duration: reduced ? Duration.zero : Motion.short,
          child: _tension == null
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_tension!, style: context.text.labelMedium?.copyWith(color: e.saffronText)),
                  ),
                ),
        ),
        const Gap(8),
        Text(
          '${g[0].label}: ${r.north.awarded} becas, de las que terminarían ${r.north.truePositives}; '
          'quedan fuera ${r.north.falseNegatives} que sí habrían terminado. '
          '${g[1].label}: ${r.south.awarded} becas, de las que terminarían ${r.south.truePositives}; '
          'quedan fuera ${r.south.falseNegatives}.',
          style: context.text.bodySmall,
        ),
        if (!_revealed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Intenta que se cumplan los dos criterios.', style: context.text.bodySmall),
          ),
        if (_revealed) ...[
          const Gap(20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduced ? 1 : 0, end: 1),
            duration: reduced ? Duration.zero : const Duration(milliseconds: 900),
            curve: Motion.settle,
            builder: (context, k, child) => Opacity(
              opacity: k,
              child: Transform.translate(offset: Offset(0, 16 * (1 - k)), child: child),
            ),
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HiloFirma(width: 160, height: 32, hueco: false),
                  const Gap(14),
                  Text('El problema no eres tú.', style: context.text.displaySmall),
                  const Gap(10),
                  Text(
                    'No existe una combinación que cumpla ambos criterios en estas condiciones.',
                    style: context.text.headlineSmall,
                  ),
                  const Gap(14),
                  MarginNote(asString(widget.config['reveal'])),
                ],
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: FilledButton(
            key: const ValueKey('probe_done'),
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
            child: const Text('Seguir'),
          ),
        ),
      ],
    );
  }
}

/// Un criterio de justicia: dos puntos (Norte y Sur) unidos por un hilo. Si
/// la diferencia cabe en la tolerancia, el hilo se anuda; si no, se estira.
class _Criterio extends StatelessWidget {
  const _Criterio({
    required this.titulo,
    required this.ayuda,
    required this.cumple,
    required this.gap,
    required this.tolerancia,
    required this.detalle,
    required this.reduced,
  });
  final String titulo;
  final String ayuda;
  final bool cumple;
  final double gap;
  final double tolerancia;
  final String detalle;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return Semantics(
      liveRegion: true,
      label: '$titulo: ${cumple ? 'se cumple' : 'no se cumple'}. $detalle',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkDot(style: cumple ? DotStyle.filled : DotStyle.hollow, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(titulo, style: context.text.titleMedium)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(cumple ? 'Se cumple' : 'No se cumple', style: context.text.labelMedium),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: gap),
              duration: reduced ? Duration.zero : const Duration(milliseconds: 480),
              curve: Motion.settle,
              builder: (context, g, _) => CustomPaint(
                size: const Size(double.infinity, 36),
                painter: _CriterioPainter(gap: g, tolerancia: tolerancia, ink: e.ink, graphite: e.graphite, saffron: e.saffron),
              ),
            ),
            Text(detalle, style: context.text.bodySmall),
            if (ayuda.isNotEmpty) Text(ayuda, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CriterioPainter extends CustomPainter {
  _CriterioPainter({required this.gap, required this.tolerancia, required this.ink, required this.graphite, required this.saffron});
  final double gap;
  final double tolerancia;
  final Color ink;
  final Color graphite;
  final Color saffron;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final half = size.width / 2 - 16;
    final d = (gap / 0.25).clamp(0.0, 1.0) * half;
    final met = gap <= tolerancia + 1e-9;
    // La zona donde ambos coinciden.
    final tolW = math.max(6.0, tolerancia / 0.25 * half);
    canvas.drawLine(Offset(cx - tolW, cy + 12), Offset(cx + tolW, cy + 12), Paint()
      ..color = saffron
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);
    final a = Offset(cx - d - 6, cy);
    final b = Offset(cx + d + 6, cy);
    paintHilo(
      canvas,
      from: a,
      to: b,
      color: met ? ink : graphite,
      provisional: !met,
      forma: met ? HiloForma.reforzado : HiloForma.recto,
      width: 2,
      seed: 4,
    );
    canvas.drawCircle(a, 6, Paint()..color = ink);
    canvas.drawCircle(b, 6, Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _CriterioPainter old) => old.gap != gap || old.ink != ink;
}

/// Cien personas en dos barrios, moviéndose entre «con beca» y «sin beca».
class BecasPainter extends CustomPainter {
  BecasPainter({
    required this.gente,
    required this.umbrales,
    required this.previos,
    required this.t,
    required this.etiquetas,
    required this.ink,
    required this.graphite,
    required this.saffron,
    required this.paper,
    required this.divider,
    required this.estilo,
    required this.estiloFuerte,
  });

  final List<List<Persona>> gente;
  final List<int> umbrales;
  final List<int> previos;
  final double t;
  final List<String> etiquetas;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;
  final Color divider;
  final TextStyle estilo;
  final TextStyle estiloFuerte;

  static const cols = 10;

  void _texto(Canvas canvas, String s, Offset at, TextStyle st, {double maxWidth = 200}) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')
      ..layout(maxWidth: maxWidth);
    tp.paint(canvas, at);
  }

  /// Posición de cada persona en su panel para un umbral dado.
  List<Offset> _layout(List<Persona> ps, int umbral, Rect panel, double step, double zoneTop, double zoneBottom) {
    final idx = List<int>.generate(ps.length, (i) => i)..sort((a, b) => ps[b].score.compareTo(ps[a].score));
    final out = List<Offset>.filled(ps.length, Offset.zero);
    var con = 0;
    var sin = 0;
    for (final i in idx) {
      final becado = ps[i].score >= umbral;
      final k = becado ? con++ : sin++;
      final row = k ~/ cols;
      final col = k % cols;
      final y = becado ? zoneTop + row * step : zoneBottom + row * step;
      out[i] = Offset(panel.left + step / 2 + col * step, y + step / 2);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const gapX = 18.0;
    final pw = (size.width - gapX) / 2;
    final step = math.min(pw / cols, 17.0);
    const labelH = 22.0;
    final zone = step * 5;
    final zoneTop = labelH + 16;
    final zoneBottom = zoneTop + zone + 22;

    for (var gi = 0; gi < gente.length && gi < 2; gi++) {
      final panel = Rect.fromLTWH(gi * (pw + gapX), 0, pw, size.height);
      _texto(canvas, etiquetas[gi], Offset(panel.left, 0), estiloFuerte, maxWidth: pw);
      final ps = gente[gi];
      final becados = ps.where((p) => p.score >= umbrales[gi]).length;
      _texto(canvas, 'Con beca: $becados', Offset(panel.left, labelH - 2), estilo, maxWidth: pw);
      // La línea del umbral.
      final lineY = zoneTop + zone + 8;
      paintHilo(canvas, from: Offset(panel.left, lineY), to: Offset(panel.left + cols * step, lineY), color: saffron, width: 2, seed: gi + 1);
      _texto(canvas, 'Sin beca · mínimo ${umbrales[gi]}', Offset(panel.left, lineY + 3), estilo, maxWidth: pw);

      final from = _layout(ps, previos[gi], panel, step, zoneTop, zoneBottom + 6);
      final to = _layout(ps, umbrales[gi], panel, step, zoneTop, zoneBottom + 6);
      final r = step * 0.3;
      for (var i = 0; i < ps.length; i++) {
        final pos = Offset.lerp(from[i], to[i], t)!;
        final becado = ps[i].score >= umbrales[gi];
        final c = becado ? ink : graphite;
        if (ps[i].termina) {
          canvas.drawCircle(pos, r, Paint()..color = c);
        } else {
          canvas.drawCircle(pos, r - 0.6, Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
        }
      }
    }
    // El eje entre barrios.
    canvas.drawLine(Offset(pw + gapX / 2, 4), Offset(pw + gapX / 2, size.height - 4), Paint()
      ..color = divider
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant BecasPainter old) =>
      old.t != t || old.umbrales != umbrales || old.previos != previos || old.ink != ink;
}
