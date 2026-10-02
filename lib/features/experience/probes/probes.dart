import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/json.dart';
import '../../../domain/content/content_models.dart';
import '../../../domain/records/records.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../widgets/arte.dart';
import '../../../widgets/composiciones.dart';
import '../../../widgets/hilo_vivo.dart';
import '../../../widgets/ilustraciones.dart';
import '../../../widgets/ink_marks.dart';
import '../../../widgets/paper.dart';
import 'becas_probe.dart';
import 'escenas.dart';

export 'becas_probe.dart' show FairnessSimulatorProbe;

typedef ProbeDone = void Function(Json result);

/// Despacha cada tipo de mecánica a su widget. Cada experiencia tiene su
/// propia interacción; todas devuelven los mismos datos que el motor espera.
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
        body = ChoiceVariantProbe(experienceId: experienceId, config: c, onDone: onDone);
      case 'proximityRings':
        body = ProximityRingsProbe(experienceId: experienceId, config: c, onDone: onDone);
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

class ProbeDoneButton extends StatelessWidget {
  const ProbeDoneButton({super.key, required this.onPressed, this.label = 'Listo'});
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: FilledButton(key: const ValueKey('probe_done'), onPressed: onPressed, child: Text(label)),
      );
}

// ------------------------------------------------------- E1: casos gemelos
/// Ana y Beto: la misma escena. Un control horizontal compara antes y
/// después; solo cambia lo que ocurre afuera. Luego, marcas de tinta para el
/// reproche de cada uno.
class TwinCasesProbe extends ConsumerStatefulWidget {
  const TwinCasesProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  ConsumerState<TwinCasesProbe> createState() => _TwinCasesProbeState();
}

class _TwinCasesProbeState extends ConsumerState<TwinCasesProbe> with SingleTickerProviderStateMixin {
  final Map<String, int> _values = {};
  late final AnimationController _cmp = AnimationController(vsync: this, duration: Motion.long, value: 0);
  bool _sawBoth = false;

  @override
  void dispose() {
    _cmp.dispose();
    super.dispose();
  }

  void _goTo(double v) {
    ref.read(feedbackProvider).selection();
    if (reducedMotionNow(context, ref)) {
      _cmp.value = v;
    } else {
      _cmp.animateTo(v, curve: Motion.turn);
    }
    if (v >= 1) setState(() => _sawBoth = true);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = asJsonList(widget.config['subjects']);
    final scale = asStringList(widget.config['scale']);
    final ready = subjects.isNotEmpty && subjects.every((s) => _values.containsKey(asString(s['id'])));
    final names = subjects.map((s) => asString(s['label'])).toList();
    final a = names.isNotEmpty ? names.first : 'Ana';
    final b = names.length > 1 ? names[1] : 'Beto';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _cmp,
          builder: (context, _) {
            final t = _cmp.value;
            final beto = t >= 0.5;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // La escena es el selector: la ficha corre por el borde de la calle.
                EscenaComparada(
                  t: t,
                  nombreA: a,
                  nombreB: b,
                  onChanged: (v) {
                    _cmp.value = v;
                    if (v >= 0.95 && !_sawBoth) setState(() => _sawBoth = true);
                  },
                  onSoltar: () => _goTo(_cmp.value >= 0.5 ? 1 : 0),
                ),
                Row(
                  children: [
                    _NombreEscena(nombre: a, activo: !beto, onTap: () => _goTo(0)),
                    const Spacer(),
                    _NombreEscena(nombre: b, activo: beto, onTap: () => _goTo(1)),
                  ],
                ),
                Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('La conducta es la misma.', style: context.text.titleMedium),
                      Text(
                        beto ? 'Solo cambia lo que ocurre: un niño cruza.' : 'No pasa nada.',
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        if (!_sawBoth)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Desliza de $a a $b: mira qué se queda quieto y qué cambia.', style: context.text.bodySmall),
          ),
        const Gap(28),
        for (final s in subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: MarcasReproche(
              nombre: asString(s['label']),
              escala: scale,
              valor: _values[asString(s['id'])],
              onChanged: (v) {
                ref.read(feedbackProvider).selection();
                setState(() => _values[asString(s['id'])] = v);
              },
            ),
          ),
        ProbeDoneButton(
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

class _NombreEscena extends StatelessWidget {
  const _NombreEscena({required this.nombre, required this.activo, required this.onTap});
  final String nombre;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      label: 'Ver la escena de $nombre',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              nombre,
              style: context.text.titleMedium?.copyWith(
                color: activo ? context.enves.ink : context.enves.inkSecondary,
                decoration: activo ? TextDecoration.underline : null,
                decorationColor: context.enves.saffron,
                decorationThickness: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reproche como conteo de tinta: trazos alineados que se acumulan; el
/// quinto cruza a los cuatro y cierra el grupo.
class MarcasReproche extends StatelessWidget {
  const MarcasReproche({
    super.key,
    required this.nombre,
    required this.escala,
    required this.valor,
    required this.onChanged,
  });
  final String nombre;
  final List<String> escala;
  final int? valor;
  final ValueChanged<int> onChanged;

  String _label(int i) => escala.length == 5 ? escala[i] : '${i + 1} de 5';

  @override
  Widget build(BuildContext context) {
    final t = Tinta.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: context.text.titleMedium),
              Text(valor == null ? 'Sin marcar' : _label(valor!), style: context.text.labelMedium),
            ],
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 60,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: valor == null ? 0 : valor! + 1.0),
                      duration: const Duration(milliseconds: 260),
                      curve: Motion.settle,
                      builder: (context, v, _) => CustomPaint(painter: ConteoPainter(v, t)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: valor == i,
                          label: 'Reproche a $nombre: ${_label(i)}',
                          excludeSemantics: true,
                          child: InkResponse(onTap: () => onChanged(i), radius: 26, child: const SizedBox.expand()),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// [v] marcas (0…5, con decimales mientras se dibuja).
class ConteoPainter extends CustomPainter {
  ConteoPainter(this.v, this.t);
  final double v;
  final Tinta t;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / 5;
    final top = size.height * 0.18;
    final bottom = size.height * 0.82;
    final lean = slot * 0.18;
    // Renglón de papel donde se apoyan las marcas.
    canvas.drawLine(Offset(0, bottom + 4), Offset(size.width, bottom + 4), linea(t.plane2, 1.2));
    for (var i = 0; i < 4; i++) {
      final x = slot * (i + 0.5);
      final a = Offset(x - lean, bottom);
      final b = Offset(x + lean, top);
      final k = (v - i).clamp(0.0, 1.0);
      canvas.drawLine(a, b, linea(t.plane2, 3));
      if (k > 0) canvas.drawLine(a, Offset.lerp(a, b, k)!, linea(t.ink, 4.2));
    }
    // El quinto: cruza a los cuatro.
    final k5 = (v - 4).clamp(0.0, 1.0);
    final a5 = Offset(slot * 0.15, bottom - size.height * 0.12);
    final b5 = Offset(slot * 4.85, top + size.height * 0.18);
    if (k5 <= 0) {
      final x = slot * 4.5;
      canvas.drawLine(Offset(x - lean, bottom), Offset(x + lean, top), linea(t.plane2, 3));
    } else {
      canvas.drawLine(a5, Offset.lerp(a5, b5, k5)!, linea(t.ink, 4.2));
    }
  }

  @override
  bool shouldRepaint(covariant ConteoPainter old) => old.v != v || old.t != t;
}

// ------------------------------------------------------- E2: variante simple
class ChoiceVariantProbe extends ConsumerStatefulWidget {
  const ChoiceVariantProbe({super.key, required this.experienceId, required this.config, required this.onDone});
  final String experienceId;
  final Json config;
  final ProbeDone onDone;

  @override
  ConsumerState<ChoiceVariantProbe> createState() => _ChoiceVariantProbeState();
}

class _ChoiceVariantProbeState extends ConsumerState<ChoiceVariantProbe> {
  String? _choice;

  @override
  Widget build(BuildContext context) {
    final options = asJsonList(widget.config['options']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.experienceId.startsWith('e2')) ...[
          const HilosPromesa(secreto: true),
          const Gap(16),
        ],
        for (final o in options)
          RuledOption(
            label: asString(o['label']),
            serif: true,
            selected: _choice == asString(o['id']),
            onTap: () {
              ref.read(feedbackProvider).selection();
              setState(() => _choice = asString(o['id']));
            },
          ),
        ProbeDoneButton(onPressed: _choice == null ? null : () => widget.onDone({'choice': _choice})),
      ],
    );
  }
}

// ---------------------------------------------------- E3: círculos de cercanía
/// La misma situación, movida entre círculos de cercanía. La decisión que
/// tomaste con tu hermano queda como sombra en el primer círculo.
class ProximityRingsProbe extends ConsumerStatefulWidget {
  const ProximityRingsProbe({super.key, required this.experienceId, required this.config, required this.onDone});
  final String experienceId;
  final Json config;
  final ProbeDone onDone;

  @override
  ConsumerState<ProximityRingsProbe> createState() => _ProximityRingsProbeState();
}

class _ProximityRingsProbeState extends ConsumerState<ProximityRingsProbe> {
  final Map<String, int> _values = {};
  int _active = 0;

  void _setActive(int i, int count) {
    final v = i.clamp(0, count - 1).toInt();
    if (v == _active) return;
    ref.read(feedbackProvider).selection();
    setState(() => _active = v);
  }

  @override
  Widget build(BuildContext context) {
    final rings = asJsonList(widget.config['rings']);
    final choices = asJsonList(widget.config['choices']);
    if (rings.isEmpty) return ProbeDoneButton(onPressed: () => widget.onDone(const {}));
    final ready = rings.every((r) => _values.containsKey(asString(r['id'])));
    final user = ref.watch(userStateProvider).valueOrNull;
    final stance = user?.progress(widget.experienceId).initialStance;
    final int? sombra = stance?.value.sign;
    final activeId = asString(rings[_active]['id']);
    final activeLabel = asString(rings[_active]['label']);

    String choiceLabel(int? v) {
      for (final c in choices) {
        if (asInt(c['value']) == v) return asString(c['label']);
      }
      return 'sin decidir';
    }

    // Círculo 1: el hermano (la decisión original). Desde el 2: las variantes.
    final marks = <int, int?>{for (var i = 0; i < rings.length; i++) i + 2: _values[asString(rings[i]['id'])]};
    final resumen = [
      if (sombra != null) 'Con tu hermano: ${stance!.label.toLowerCase()}',
      for (var i = 0; i < rings.length; i++)
        if (_values.containsKey(asString(rings[i]['id'])))
          '${asString(rings[i]['label'])}: ${choiceLabel(_values[asString(rings[i]['id'])]).toLowerCase()}',
    ].join('. ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ilustracionCabe(context))
          LayoutBuilder(builder: (context, c) {
            final size = c.maxWidth.clamp(0.0, 340.0);
            return Center(
              child: Semantics(
                label: 'Círculos de cercanía. En el centro, tú. $resumen',
                excludeSemantics: true,
                child: GestureDetector(
                  onTapUp: (d) {
                    final center = Offset(size / 2, size / 2);
                    final dist = (d.localPosition - center).distance / (size / 2);
                    // Círculo 1: hermano (fijo). 2 y 3: las variantes.
                    if (dist > 0.45) _setActive(dist > 0.78 ? rings.length - 1 : 0, rings.length);
                  },
                  onPanUpdate: (d) {
                    final center = Offset(size / 2, size / 2);
                    final dist = (d.localPosition - center).distance / (size / 2);
                    if (dist > 0.45) _setActive(dist > 0.78 ? rings.length - 1 : 0, rings.length);
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _active.toDouble()),
                    duration: reducedMotion(context, ref) ? Duration.zero : Motion.medium,
                    curve: Motion.settle,
                    builder: (context, ringPos, _) => CustomPaint(
                      size: Size(size, size),
                      painter: CirculosPainter(
                        activo: ringPos + 2,
                        marcas: marks,
                        sombra: sombra,
                        c: Tinta.of(context),
                        etiquetas: ['Tú', 'Hermano', for (final r in rings) asString(r['label'])],
                        estilo: context.text.bodySmall!,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        const Gap(12),
        Text('Mueve la situación a otro círculo: toca un círculo o elige aquí.', style: context.text.bodySmall),
        const Gap(8),
        SegmentedButton<int>(
          segments: [
            for (var i = 0; i < rings.length; i++) ButtonSegment(value: i, label: Text(asString(rings[i]['label']))),
          ],
          selected: {_active},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _setActive(s.first, rings.length),
        ),
        const Gap(12),
        Text('Si hubiera sido ${activeLabel.toLowerCase()}:', style: context.text.titleMedium),
        for (final c in choices)
          RuledOption(
            label: asString(c['label']),
            selected: _values[activeId] == asInt(c['value']),
            onTap: () {
              ref.read(feedbackProvider).selection();
              setState(() {
                _values[activeId] = asInt(c['value']);
                if (_active < rings.length - 1 && !_values.containsKey(asString(rings[_active + 1]['id']))) {
                  _active++;
                }
              });
            },
          ),
        if (resumen.isNotEmpty) ...[
          const Gap(12),
          Semantics(liveRegion: true, child: MarginNote(resumen)),
        ],
        ProbeDoneButton(onPressed: ready ? () => widget.onDone(Map<String, dynamic>.from(_values)) : null),
      ],
    );
  }
}

// ------------------------------------------------------- E4: escalera
/// Escalera de gravedad: una línea que se arrastra entre peldaños. Por encima,
/// tinta sólida; por debajo, grafito. Nunca verde ni rojo.
class LadderProbe extends ConsumerStatefulWidget {
  const LadderProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  ConsumerState<LadderProbe> createState() => _LadderProbeState();
}

class _LadderProbeState extends ConsumerState<LadderProbe> {
  int? _line;
  double _dragAcc = 0;

  /// La línea tras moverla [delta] peldaños. Orden de abajo hacia arriba:
  /// 1, 2, …, n, 0 (nunca).
  int _after(int delta, int n) {
    final order = [for (var i = 1; i <= n; i++) i, 0];
    final idx = order.indexOf(_line ?? 1);
    return order[(idx + delta).clamp(0, order.length - 1)];
  }

  /// Sube la línea (más estricto). 4 → 0 (nunca).
  void _move(int delta, int n) {
    final next = _after(delta, n);
    if (next != _line) {
      ref.read(feedbackProvider).selection();
      setState(() => _line = next);
    }
  }

  String _lineText(int? line, List<String> rungs, String never) {
    if (line == null) return 'Sin línea todavía';
    if (line == 0) return never;
    return 'Desde el peldaño $line: «${rungs[line - 1]}»';
  }

  @override
  Widget build(BuildContext context) {
    final rungs = asStringList(widget.config['rungs']);
    final never = asString(widget.config['never'], 'Nunca');
    final n = rungs.length;
    final e = context.enves;
    final reduced = reducedMotion(context, ref);

    Widget marker(bool visible) => AnimatedSize(
          duration: reduced ? Duration.zero : Motion.medium,
          curve: Motion.settle,
          child: !visible
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  slider: true,
                  label: 'Aquí trazaría mi línea',
                  value: _lineText(_line, rungs, never),
                  increasedValue: _lineText(_after(1, n), rungs, never),
                  decreasedValue: _lineText(_after(-1, n), rungs, never),
                  onIncrease: () => _move(1, n),
                  onDecrease: () => _move(-1, n),
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) {
                      _dragAcc += d.delta.dy;
                      if (_dragAcc < -36) {
                        _dragAcc = 0;
                        _move(1, n);
                      } else if (_dragAcc > 36) {
                        _dragAcc = 0;
                        _move(-1, n);
                      }
                    },
                    onVerticalDragEnd: (_) => _dragAcc = 0,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.drag_handle, color: e.saffronText, size: 22),
                          const SizedBox(width: 6),
                          Expanded(
                            child: CustomPaint(
                              size: const Size(double.infinity, 6),
                              painter: _LineaPainter(e.saffron),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            child: Text('Aquí trazaría mi línea', style: context.text.labelMedium?.copyWith(color: e.saffronText)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );

    Widget rung(int i) {
      final level = i + 1;
      final accepted = _line != null && _line != 0 && level >= _line!;
      return Semantics(
        button: true,
        selected: _line == level,
        label: 'Peldaño $level: ${rungs[i]}. ${accepted ? 'Mentir sería aceptable' : 'No mentirías'}',
        excludeSemantics: true,
        child: InkWell(
          onTap: () {
            ref.read(feedbackProvider).selection();
            setState(() => _line = level);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: accepted ? 1 : 0),
                  duration: reduced ? Duration.zero : Motion.medium,
                  builder: (context, t, _) => CustomPaint(
                    size: const Size(76, 40),
                    painter: _PeldanoPainter(nivel: level, total: n, t: t, c: Tinta.of(context)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: reduced ? Duration.zero : Motion.medium,
                    style: context.text.bodyLarge!.copyWith(color: accepted ? e.ink : e.inkSecondary),
                    child: Text(rungs[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Arriba, lo más grave. Traza tu línea: desde ahí hacia arriba, mentir te parecería aceptable.',
          style: context.text.bodySmall,
        ),
        const Gap(8),
        marker(_line == 0),
        for (var i = n - 1; i >= 0; i--) ...[
          rung(i),
          marker(_line == i + 1),
        ],
        RuledOption(
          label: never,
          selected: _line == 0,
          onTap: () {
            ref.read(feedbackProvider).selection();
            setState(() => _line = 0);
          },
        ),
        if (_line == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Toca un peldaño para trazar la línea; después puedes arrastrarla.', style: context.text.bodySmall),
          ),
        ProbeDoneButton(onPressed: _line == null ? null : () => widget.onDone({'line': _line})),
      ],
    );
  }
}

class _LineaPainter extends CustomPainter {
  _LineaPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    paintHilo(canvas, from: Offset(0, size.height / 2), to: Offset(size.width, size.height / 2), color: color, width: 2.4, seed: 7);
  }

  @override
  bool shouldRepaint(covariant _LineaPainter old) => old.color != color;
}

class _PeldanoPainter extends CustomPainter {
  _PeldanoPainter({required this.nivel, required this.total, required this.t, required this.c});
  final int nivel;
  final int total;
  final double t;
  final Tinta c;

  @override
  void paint(Canvas canvas, Size size) {
    // Un peldaño: bloque sólido que crece con la gravedad del caso.
    final w = size.width * (0.28 + 0.72 * nivel / total);
    final rect = Rect.fromLTWH(0, size.height * 0.3, w, size.height * 0.6);
    canvas.drawRect(rect.shift(const Offset(2, 3)), relleno(c.ink.withValues(alpha: 0.08)));
    canvas.drawRect(rect, relleno(c.plane2));
    if (t > 0) canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width * t, rect.height), relleno(c.ink));
  }

  @override
  bool shouldRepaint(covariant _PeldanoPainter old) => old.t != t || old.c != c;
}

// ------------------------------------------------------- E6: red de información
/// La ubicación en el centro; alrededor, quienes podrían verla. Cada modo
/// (siempre, de noche, en emergencias) dibuja un tipo de línea distinto.
class FlowMatrixProbe extends ConsumerStatefulWidget {
  const FlowMatrixProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  ConsumerState<FlowMatrixProbe> createState() => _FlowMatrixProbeState();
}

class _FlowMatrixProbeState extends ConsumerState<FlowMatrixProbe> with SingleTickerProviderStateMixin {
  final Set<String> _accepted = {};
  int _col = 0;
  String? _last;
  late final AnimationController _anim = AnimationController(vsync: this, duration: Motion.long, value: 1);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle(int r) {
    final key = '$r:$_col';
    final adding = !_accepted.contains(key);
    ref.read(feedbackProvider).selection();
    setState(() {
      _last = key;
      if (adding) _accepted.add(key);
    });
    if (reducedMotionNow(context, ref)) {
      if (!adding) setState(() => _accepted.remove(key));
      return;
    }
    if (adding) {
      _anim.forward(from: 0);
    } else {
      _anim.reverse(from: 1).whenComplete(() {
        if (mounted) setState(() => _accepted.remove(key));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = asStringList(widget.config['rows']);
    final cols = asStringList(widget.config['columns']);
    final total = rows.length * cols.length;
    final e = context.enves;
    const positions = [Offset(0.16, 0.3), Offset(0.84, 0.3), Offset(0.16, 0.74), Offset(0.84, 0.74)];

    String rowState(int r) {
      final on = [for (var c = 0; c < cols.length; c++) if (_accepted.contains('$r:$c')) cols[c].toLowerCase()];
      return on.isEmpty ? 'sin acceso' : on.join(', ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Primero elige cuándo; luego toca a quién conectas con su ubicación.', style: context.text.bodySmall),
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var c = 0; c < cols.length; c++)
              Semantics(
                button: true,
                selected: _col == c,
                label: 'Modo: ${cols[c]}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () {
                    ref.read(feedbackProvider).selection();
                    setState(() => _col = c);
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _col == c ? e.ink : e.divider, width: _col == c ? 2.5 : 1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(size: const Size(28, 10), painter: _ModoMuestraPainter(c, e.ink)),
                        const SizedBox(width: 8),
                        Flexible(child: Text(cols[c], style: _col == c ? context.text.labelLarge : context.text.bodyMedium)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Gap(12),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final h = (w * 0.9).clamp(280.0, 360.0);
          return SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => CustomPaint(
                        painter: RedPainter(
                          rows: rows.length,
                          cols: cols.length,
                          accepted: _accepted,
                          active: _col,
                          last: _last,
                          lastT: _anim.value,
                          positions: positions,
                          c: Tinta.of(context),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: w / 2 - 60,
                  top: h / 2 + 20,
                  width: 120,
                  child: ExcludeSemantics(
                    child: Center(
                      child: Container(
                        color: e.paper,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('Su ubicación', textAlign: TextAlign.center, style: context.text.labelMedium),
                      ),
                    ),
                  ),
                ),
                for (var r = 0; r < rows.length && r < positions.length; r++)
                  // El punto lo dibuja la red; aquí van la etiqueta (hacia afuera) y el área táctil.
                  Positioned(
                    left: (positions[r].dx * w - 66).clamp(0.0, w - 132),
                    width: 132,
                    top: positions[r].dy < 0.5 ? null : positions[r].dy * h - 24,
                    bottom: positions[r].dy < 0.5 ? h - positions[r].dy * h - 24 : null,
                    child: Semantics(
                      button: true,
                      checked: _accepted.contains('$r:$_col'),
                      label: '${rows[r]}, ${cols[_col]}',
                      hint: 'Ahora: ${rowState(r)}',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => _toggle(r),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          verticalDirection: positions[r].dy < 0.5 ? VerticalDirection.up : VerticalDirection.down,
                          children: [
                            const SizedBox(height: 48),
                            Text(rows[r], textAlign: TextAlign.center, style: context.text.labelMedium?.copyWith(color: e.ink)),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const Gap(8),
        Semantics(
          liveRegion: true,
          child: Text('Marcaste ${_accepted.length} de $total conexiones.', style: context.text.bodySmall),
        ),
        ProbeDoneButton(
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

/// Muestra del trazo de cada modo: continuo, discontinuo, punteado.
Path modoPath(Path base, int mode) {
  switch (mode) {
    case 0:
      return base;
    case 1:
      return dashedPath(base, dash: 8, gap: 5);
    default:
      return dashedPath(base, dash: 1.5, gap: 5);
  }
}

class _ModoMuestraPainter extends CustomPainter {
  _ModoMuestraPainter(this.mode, this.ink);
  final int mode;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    canvas.drawPath(modoPath(base, mode), Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = mode == 0 ? 2.6 : 2.2
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _ModoMuestraPainter old) => old.mode != mode || old.ink != ink;
}

class RedPainter extends CustomPainter {
  RedPainter({
    required this.rows,
    required this.cols,
    required this.accepted,
    required this.active,
    required this.last,
    required this.lastT,
    required this.positions,
    required this.c,
  });
  final int rows;
  final int cols;
  final Set<String> accepted;
  final int active;
  final String? last;
  final double lastT;
  final List<Offset> positions;
  final Tinta c;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ph = size.height * 0.36;
    final phone = Rect.fromCenter(center: center, width: ph * 0.56, height: ph);
    for (var r = 0; r < rows && r < positions.length; r++) {
      final node = Offset(positions[r].dx * size.width, positions[r].dy * size.height);
      final d = node - center;
      final len = d.distance;
      final n = len == 0 ? Offset.zero : Offset(-d.dy / len, d.dx / len);
      for (var k = 0; k < cols; k++) {
        final key = '$r:$k';
        if (!accepted.contains(key)) continue;
        final off = n * ((k - (cols - 1) / 2) * 7);
        final from = center + off + d / len * (ph * 0.42);
        final to = node + off - d / len * 22;
        final t = key == last ? lastT : 1.0;
        final end = Offset.lerp(from, to, t)!;
        final base = Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(end.dx, end.dy);
        // Lo seleccionado ahora, en azafrán; lo demás, en tinta suave.
        canvas.drawPath(modoPath(base, k), linea(k == active ? c.saffron : c.ink2, k == active ? 2.8 : 1.6));
      }
    }
    // El teléfono, al centro: la ubicación de tu hermana.
    plano(canvas, phone.inflate(10), c.plane, sombra: c.ink);
    dibujarTelefono(canvas, phone, c.ink, c.paper);
    final pc = phone.center;
    final pr = ph * 0.13;
    final pin = Path()
      ..moveTo(pc.dx, pc.dy + pr * 1.3)
      ..quadraticBezierTo(pc.dx - pr, pc.dy, pc.dx, pc.dy - pr)
      ..quadraticBezierTo(pc.dx + pr, pc.dy, pc.dx, pc.dy + pr * 1.3);
    canvas.drawPath(pin, relleno(c.saffron));
    canvas.drawCircle(pc - Offset(0, pr * 0.1), pr * 0.35, relleno(c.paper));
    // Las personas: bustos sólidos si están conectadas en este modo.
    const b = 36.0;
    for (var r = 0; r < rows && r < positions.length; r++) {
      final node = Offset(positions[r].dx * size.width, positions[r].dy * size.height);
      final on = accepted.contains('$r:$active');
      final path = busto(Rect.fromCenter(center: node, width: b, height: b), derecha: positions[r].dx < 0.5);
      canvas.drawPath(path, relleno(on ? c.ink : c.paper));
      if (!on) canvas.drawPath(path, linea(c.ink2, 1.6));
    }
  }

  @override
  bool shouldRepaint(covariant RedPainter old) => true;
}

// ------------------------------------------------------------ E7: la carta
/// Una carta normal. Las frases que suenan a comprensión reciben una marca de
/// tinta. Al revelar quién la escribió, las líneas se alinean como patrones,
/// sin cambiar a una estética tecnológica.
class AnnotatedLetterProbe extends ConsumerStatefulWidget {
  const AnnotatedLetterProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  ConsumerState<AnnotatedLetterProbe> createState() => _AnnotatedLetterProbeState();
}

class _AnnotatedLetterProbeState extends ConsumerState<AnnotatedLetterProbe> with SingleTickerProviderStateMixin {
  final Set<int> _marked = {};
  bool _revealed = false;
  int? _asking;
  late final AnimationController _align = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _align.dispose();
    super.dispose();
  }

  static String _patron(String phrase) {
    final p = phrase.toLowerCase();
    if (p.contains('luna')) return 'dato: el nombre';
    if (p.contains('años')) return 'dato: los años';
    if (p.contains('me acuerdo') || p.contains('recuerdo')) return 'dato: un recuerdo';
    return 'fórmula';
  }

  void _reveal() {
    ref.read(feedbackProvider).discovery();
    setState(() => _revealed = true);
    if (reducedMotionNow(context, ref)) {
      _align.value = 1;
    } else {
      _align.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final phrases = asStringList(widget.config['phrases']);
    final e = context.enves;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _align,
          builder: (context, _) {
            final a = Motion.settle.transform(_align.value);
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
              decoration: BoxDecoration(
                color: e.paper,
                border: Border.all(color: e.divider),
                boxShadow: [BoxShadow(color: e.divider, offset: const Offset(3, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < phrases.length; i++)
                    _LineaCarta(
                      texto: phrases[i],
                      marcada: _marked.contains(i),
                      alineado: a,
                      jitter: ((i * 37) % 11 - 5) / 5.0,
                      patron: _patron(phrases[i]),
                      preguntando: _asking == i,
                      revealed: _revealed,
                      onTap: () {
                        ref.read(feedbackProvider).selection();
                        setState(() {
                          if (!_revealed) {
                            if (!_marked.remove(i)) _marked.add(i);
                          } else if (_marked.contains(i)) {
                            _asking = _asking == i ? null : i;
                          }
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
        const Gap(8),
        Text(
          _revealed
              ? 'Toca de nuevo una frase que marcaste.'
              : 'Marcaste ${_marked.length} ${_marked.length == 1 ? 'frase' : 'frases'}.',
          style: context.text.bodySmall,
        ),
        const Gap(12),
        if (_revealed)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reducedMotion(context, ref) ? 1 : 0, end: 1),
            duration: Motion.long,
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: Semantics(liveRegion: true, child: MarginNote(asString(widget.config['reveal']))),
          ),
        ProbeDoneButton(
          label: _revealed ? 'Seguir' : 'Ya la leí',
          onPressed: _revealed ? () => widget.onDone({'marked': _marked.length, 'revealed': true}) : _reveal,
        ),
      ],
    );
  }
}

class _LineaCarta extends StatelessWidget {
  const _LineaCarta({
    required this.texto,
    required this.marcada,
    required this.alineado,
    required this.jitter,
    required this.patron,
    required this.preguntando,
    required this.revealed,
    required this.onTap,
  });
  final String texto;
  final bool marcada;
  final double alineado;
  final double jitter;
  final String patron;
  final bool preguntando;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final free = 1 - alineado;
    return Semantics(
      button: true,
      selected: marcada,
      label: texto,
      hint: revealed
          ? (marcada ? 'Volver a mirar esta frase' : null)
          : 'Marcar como frase que suena a comprensión',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      child: AnimatedOpacity(
                        opacity: marcada ? 1 : 0,
                        duration: Motion.short,
                        child: CustomPaint(size: const Size(14, 14), painter: _TildePainter(e.ink)),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(jitter * 6 * free, 0),
                        child: Transform.rotate(
                          angle: jitter * 0.012 * free,
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: marcada ? 1 : 0),
                            duration: Motion.medium,
                            builder: (context, t, child) => CustomPaint(
                              foregroundPainter: _SubrayadoPainter(t, e.saffron),
                              child: child,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6, top: 4),
                              child: Text(
                                texto,
                                style: context.text.bodyLarge?.copyWith(
                                  fontStyle: alineado < 0.5 ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (alineado > 0)
                      Opacity(
                        opacity: alineado,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: Text('[$patron]', style: context.text.bodySmall),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (preguntando)
                Padding(
                  padding: const EdgeInsets.only(left: 18, bottom: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: MarginNote('¿Cambió lo que estas palabras significan para ti?'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubrayadoPainter extends CustomPainter {
  _SubrayadoPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final y = size.height - 2;
    canvas.drawPath(
      partialPath(inkPath(Offset(0, y), Offset(size.width * 0.96, y - 1), seed: size.width.round()), t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SubrayadoPainter old) => old.t != t || old.color != color;
}

class _TildePainter extends CustomPainter {
  _TildePainter(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(1, size.height * 0.55)
      ..lineTo(size.width * 0.4, size.height - 1)
      ..lineTo(size.width - 1, 1);
    canvas.drawPath(p, Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _TildePainter old) => old.ink != ink;
}

// --------------------------------------------------- E8: gradiente de reemplazo
/// Una figura humana que se vuelve a dibujar parte por parte. Siempre humana:
/// sin circuitos, sin robots.
class ReplacementGradientProbe extends ConsumerStatefulWidget {
  const ReplacementGradientProbe({super.key, required this.config, required this.onDone});
  final Json config;
  final ProbeDone onDone;

  @override
  ConsumerState<ReplacementGradientProbe> createState() => _ReplacementGradientProbeState();
}

class _ReplacementGradientProbeState extends ConsumerState<ReplacementGradientProbe> {
  double _value = 50;
  bool _never = false;
  bool _touched = false;
  int _lastParts = -1;

  @override
  Widget build(BuildContext context) {
    final min = asDouble(widget.config['min'], 10);
    final max = asDouble(widget.config['max'], 100);
    final step = asDouble(widget.config['step'], 10);
    final divisions = ((max - min) / step).round();
    final shown = _value;
    final parts = _never ? 0 : (shown / 100 * siluetaPartes).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ilustracionCabe(context))
          Center(
            child: Semantics(
              label: _never
                  ? 'La figura se queda como está.'
                  : 'Figura humana con el ${shown.round()} por ciento vuelto a dibujar.',
              excludeSemantics: true,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: parts.toDouble()),
                duration: reducedMotion(context, ref) ? Duration.zero : Motion.medium,
                builder: (context, p, _) => CustomPaint(
                  size: const Size(240, 250),
                  painter: _FiguraReemplazoPainter(partes: p.round(), c: Tinta.of(context)),
                ),
              ),
            ),
          ),
        const Gap(8),
        Text(
          _never
              ? 'Nunca dejarías de ser tú'
              : (_touched ? 'Dejarías de ser tú al reemplazar el ${_value.round()} %' : 'Mueve el control: la figura se vuelve a dibujar parte por parte'),
          style: context.text.titleMedium,
        ),
        if (!_never && _touched && _value >= max)
          Text('La figura está completa, dibujada otra vez de punta a punta.', style: context.text.bodySmall),
        Slider(
          value: _value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${_value.round()} %',
          semanticFormatterCallback: (v) => '${v.round()} por ciento reemplazado',
          onChanged: _never
              ? null
              : (v) {
                  final newParts = (v / 100 * siluetaPartes).round();
                  if (newParts != _lastParts) {
                    _lastParts = newParts;
                    ref.read(feedbackProvider).selection();
                  }
                  setState(() {
                    _value = v;
                    _touched = true;
                  });
                },
        ),
        RuledOption(
          label: asString(widget.config['never'], 'Nunca dejaría de ser yo'),
          selected: _never,
          onTap: () => setState(() {
            _never = !_never;
            _touched = true;
          }),
        ),
        ProbeDoneButton(
          onPressed: !_touched ? null : () => widget.onDone(_never ? {'never': true} : {'stop': _value.round()}),
        ),
      ],
    );
  }
}

class _FiguraReemplazoPainter extends CustomPainter {
  _FiguraReemplazoPainter({required this.partes, required this.c});
  final int partes;
  final Tinta c;

  @override
  void paint(Canvas canvas, Size size) {
    final fh = size.height * 0.96;
    final fw = fh * 100 / 260;
    plano(canvas, Rect.fromLTWH(size.width * 0.18, size.height * 0.08, size.width * 0.64, size.height * 0.8), c.plane, sombra: c.ink);
    final actual = partes > 0 && partes <= siluetaPartes ? Parte.values[partes - 1] : null;
    figuraRehecha(canvas, Rect.fromLTWH(size.width / 2 - fw / 2, size.height - fh, fw, fh), c, partes, actual: actual);
  }

  @override
  bool shouldRepaint(covariant _FiguraReemplazoPainter old) => old.partes != partes || old.c != c;
}

// ------------------------------------------------- E9: tres formas de saber
/// Cierre del recorrido: los puntos huecos que conseguiste aparecen, y un hilo
/// une ambos lados del eje sin fusionarlos.
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
    final items = <({String id, String title, String position, bool recognized})>[];
    for (final e in content.experiences) {
      final p = user.experiences[e.id];
      final c = p?.cruza;
      if (p == null || c == null || c.finalRecognition == null) continue;
      final include = p.status == ExpStatus.completed || e.id == widget.experienceId;
      if (!include) continue;
      items.add((
        id: e.id,
        title: e.title,
        position: e.pole(c.target).label,
        recognized: Recognition.isRecognized(c.finalRecognition),
      ));
    }
    final options = asJsonList(widget.config['options']);
    final ready = items.every((i) => _answers.containsKey(i.id));
    final reduced = reducedMotion(context, ref);
    final ec = context.enves;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ilustracionCabe(context))
          Semantics(
            label: 'Tú a un lado del eje, quien piensa distinto al otro. '
                'Aparecen ${items.length} puntos huecos: las posiciones que reconstruiste. Un hilo une ambos lados sin fundirlos.',
            excludeSemantics: true,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reduced ? 1 : 0, end: 1),
              duration: reduced ? Duration.zero : Duration(milliseconds: 900 + items.length * 260),
              builder: (context, t, _) => CustomPaint(
                size: const Size(double.infinity, 230),
                painter: _RecorridoFinalPainter(
                  t: t,
                  huecos: [for (final i in items) i.recognized],
                  c: Tinta.of(context),
                ),
              ),
            ),
          ),
        const Gap(16),
        for (final item in items) ...[
          Row(
            children: [
              InkDot(style: item.recognized ? DotStyle.hollow : DotStyle.dashed, size: 14, color: item.recognized ? ec.saffron : null),
              const SizedBox(width: 10),
              Expanded(child: Text(item.title, style: context.text.labelMedium)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text('«${item.position}»', style: context.text.bodyLarge),
          ),
          for (final o in options)
            RuledOption(
              label: asString(o['label']),
              selected: _answers[item.id] == asString(o['id']),
              onTap: () {
                ref.read(feedbackProvider).selection();
                setState(() => _answers[item.id] = asString(o['id']));
              },
            ),
          const Gap(16),
        ],
        ProbeDoneButton(
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

class _RecorridoFinalPainter extends CustomPainter {
  _RecorridoFinalPainter({required this.t, required this.huecos, required this.c});
  final double t;
  final List<bool> huecos;
  final Tinta c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final suelo = h * 0.78;
    final enter = (t / 0.3).clamp(0.0, 1.0);
    plano(canvas, Rect.fromLTWH(w * 0.02 - 14 * (1 - enter), h * 0.1, w * 0.4, suelo - h * 0.1), c.plane, sombra: c.ink);
    plano(canvas, Rect.fromLTWH(w * 0.58 + 14 * (1 - enter), h * 0.02, w * 0.4, suelo - h * 0.12), c.plane2, sombra: c.ink);
    final fh = suelo * 0.96;
    final fw = fh * 100 / 260;
    dibujarSilueta(canvas, Rect.fromLTWH(w * 0.12, suelo - fh, fw, fh), c.ink, atras: c.ink2, papel: c.plane);
    dibujarSilueta(canvas, Rect.fromLTWH(w * 0.88 - fw, suelo - fh, fw, fh), c.ink2, derecha: false, atras: c.graphite, papel: c.plane2);
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, suelo + 6), linea(c.ink, 3));

    // Los puntos huecos que conseguiste llegan uno a uno.
    final n = huecos.length;
    final span = n <= 1 ? 0.0 : (w * 0.6) / (n - 1);
    final y0 = h * 0.92;
    for (var i = 0; i < n; i++) {
      final k = (t * (n + 3) - i - 1).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final pos = Offset(n <= 1 ? w / 2 : w * 0.2 + i * span, y0);
      if (huecos[i]) {
        puntoHueco(canvas, pos, 7 * k, c.saffron, c.paper);
      } else {
        canvas.drawCircle(pos, 6 * k, linea(c.graphite, 1.6));
      }
    }

    // El hilo une ambos lados y atraviesa el eje sin fundirlos.
    final th = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    final y = suelo - fh * 0.55;
    final a = Offset(w * 0.36, y);
    final b = Offset(w * 0.64, y);
    if (th > 0) puntoLleno(canvas, a, 7, c.ink);
    hilo(canvas, a, b, c.ink, w: 1.6, t: th);
    if (th >= 1) puntoHueco(canvas, b, 7, c.saffron, c.paper);
  }

  @override
  bool shouldRepaint(covariant _RecorridoFinalPainter old) => old.t != t || old.c != c;
}
