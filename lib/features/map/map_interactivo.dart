import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';
import '../../engine/map/map_builder.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/hilo_vivo.dart';
import '../../widgets/ink_marks.dart';
import '../../widgets/paper.dart';

String valorEnEje(AxisDef axis, int v) {
  if (v == 0) return 'No lo sé';
  final pole = v < 0 ? axis.left : axis.right;
  return '$pole (${confidenceLabelFor(v)})';
}

String origenDeMarca(String source) {
  switch (source) {
    case 'stance':
      return 'tu postura al terminar';
    case 'probe':
      return 'lo que elegiste en la exploración';
    case 'socratic':
      return 'tu respuesta a una pregunta';
    case 'reason':
      return 'la razón que diste';
    default:
      return 'una decisión';
  }
}

/// Posiciones de las marcas principales de un eje (las mismas que se dibujan).
List<Offset> posicionesMarcas(AxisView view, Size size) {
  const pad = 12.0;
  final cy = size.height / 2;
  final half = (size.width - pad * 2) / 2;
  final center = size.width / 2;
  final counts = <int, int>{};
  final out = <Offset>[];
  for (final m in view.mainMarks) {
    final n = counts[m.value] ?? 0;
    counts[m.value] = n + 1;
    final dy = cy + (n.isEven ? -1 : 1) * ((n + 1) ~/ 2) * 11.0;
    out.add(Offset(center + m.value / 3 * half, dy));
  }
  return out;
}

/// Una tensión del mapa. Tocar una marca muestra qué decisión la creó y
/// atenúa las demás. No permite cambiar nada: es una vista de comprensión.
class EjeInteractivo extends ConsumerStatefulWidget {
  const EjeInteractivo({super.key, required this.view, required this.onOpen});
  final AxisView view;
  final VoidCallback onOpen;

  @override
  ConsumerState<EjeInteractivo> createState() => _EjeInteractivoState();
}

class _EjeInteractivoState extends ConsumerState<EjeInteractivo> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final view = widget.view;
    final marks = view.mainMarks;
    final sel = _sel != null && _sel! < marks.length ? marks[_sel!] : null;
    final reduced = reducedMotion(context, ref);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                Expanded(child: Text(view.axis.left, style: context.text.labelLarge)),
                const SizedBox(width: 12),
                Expanded(child: Text(view.axis.right, style: context.text.labelLarge, textAlign: TextAlign.right)),
              ],
            ),
          ),
          LayoutBuilder(builder: (context, c) {
            final size = Size(c.maxWidth, 72);
            return Semantics(
              label: '${view.axis.left} frente a ${view.axis.right}. ${view.statement}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final pos = posicionesMarcas(view, size);
                  int? best;
                  var dist = 22.0;
                  for (var i = 0; i < pos.length; i++) {
                    final dd = (pos[i] - d.localPosition).distance;
                    if (dd < dist) {
                      dist = dd;
                      best = i;
                    }
                  }
                  if (best == null) {
                    widget.onOpen();
                    return;
                  }
                  ref.read(feedbackProvider).selection();
                  setState(() => _sel = _sel == best ? null : best);
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0, end: 1),
                  duration: reduced ? Duration.zero : Motion.long,
                  curve: Motion.settle,
                  builder: (context, t, _) => CustomPaint(
                    size: size,
                    painter: EjePainter(
                      view: view,
                      t: t,
                      seleccion: _sel,
                      ink: e.ink,
                      graphite: e.graphite,
                      saffron: e.saffron,
                      divider: e.divider,
                    ),
                  ),
                ),
              ),
            );
          }),
          AnimatedSize(
            duration: reduced ? Duration.zero : Motion.short,
            alignment: Alignment.topLeft,
            child: sel == null
                ? const SizedBox(width: double.infinity)
                : Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: MarginNote(
                        'Esta marca la creó ${origenDeMarca(sel.source)} en ${sel.title}',
                        child: Text(
                          sel.revised && sel.initialValue != null
                              ? '${valorEnEje(view.axis, sel.value)}. Antes: ${valorEnEje(view.axis, sel.initialValue!)}.'
                              : valorEnEje(view.axis, sel.value),
                          style: context.text.bodyLarge,
                        ),
                      ),
                    ),
                  ),
          ),
          Text(view.statement, style: context.text.bodyMedium),
          if (view.contextStatement != null) Text(view.contextStatement!, style: context.text.bodySmall),
          if (marks.isNotEmpty && sel == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Toca una marca para ver qué decisión la creó.', style: context.text.bodySmall),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: widget.onOpen, child: const Text('Ver detalle')),
          ),
        ],
      ),
    );
  }
}

class EjePainter extends CustomPainter {
  EjePainter({
    required this.view,
    required this.t,
    required this.seleccion,
    required this.ink,
    required this.graphite,
    required this.saffron,
    required this.divider,
  });
  final AxisView view;
  final double t;
  final int? seleccion;
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(pad, cy - 5, size.width - pad, cy + 5), const Radius.circular(5)),
      Paint()..color = divider,
    );
    canvas.drawLine(Offset(center, cy - 20), Offset(center, cy + 20), Paint()
      ..color = ink
      ..strokeWidth = 2.6);
    if (view.decided > 0 && view.min != view.max) {
      // El patrón: tinta si se consolidó; grafito punteado si aún es provisional.
      paintHilo(
        canvas,
        from: Offset(x(view.min), cy),
        to: Offset(x(view.max), cy),
        color: view.consolidated ? ink : graphite,
        provisional: !view.consolidated,
        progress: t,
        width: view.consolidated ? 4 : 2,
        seed: view.axis.id.length,
      );
    }
    final pos = posicionesMarcas(view, size);
    final marks = view.mainMarks;
    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      final dim = seleccion != null && seleccion != i;
      final base = view.consolidated ? ink : graphite;
      final color = dim ? base.withValues(alpha: 0.25) : base;
      final p = pos[i];
      final local = ((t - i * 0.06) / 0.5).clamp(0.0, 1.0);
      if (m.value == 0) {
        canvas.drawCircle(p, 5 * local, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        canvas.drawCircle(p, 8 * local, Paint()..color = color);
      }
      if (m.revised && m.initialValue != null) {
        final from = Offset(x(m.initialValue!), p.dy);
        canvas.drawCircle(from, 5, Paint()
          ..color = dim ? saffron.withValues(alpha: 0.25) : saffron
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        // El hilo se curva: hubo un cambio de posición.
        paintHilo(canvas, from: from, to: p, color: color, forma: HiloForma.curvo, progress: t, width: 1.2, seed: i, bend: -10);
      }
      if (seleccion == i) {
        canvas.drawCircle(p, 11, Paint()
          ..color = saffron
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EjePainter old) => old.view != view || old.t != t || old.seleccion != seleccion || old.ink != ink;
}

/// Los hilos entre preguntas. Tocar un hilo destaca solo las experiencias que
/// lo construyeron; mantenerlo pulsado muestra de dónde viene.
class HilosDelMapa extends ConsumerStatefulWidget {
  const HilosDelMapa({super.key, required this.threads, required this.content, required this.consolidated});
  final List<ThreadView> threads;
  final ContentBundle content;
  final bool consolidated;

  @override
  ConsumerState<HilosDelMapa> createState() => _HilosDelMapaState();
}

class _HilosDelMapaState extends ConsumerState<HilosDelMapa> {
  int? _sel;

  void _select(int i) {
    ref.read(feedbackProvider).selection();
    setState(() => _sel = _sel == i ? null : i);
  }

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final content = widget.content;
    final ordered = [...content.experiences]..sort((a, b) => a.order.compareTo(b.order));
    final index = {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
    final reduced = reducedMotion(context, ref);
    final sel = _sel != null && _sel! < widget.threads.length ? widget.threads[_sel!] : null;

    String titulo(ThreadView t) => t.kind == 'memoria'
        ? '${content.titleOf(t.from)} volvió en ${content.titleOf(t.to)}'
        : '${content.titleOf(t.from)} y ${content.titleOf(t.to)} comparten una razón';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, 110);
          final n = ordered.length;
          double xOf(int i) => n <= 1 ? size.width / 2 : 14 + i * (size.width - 28) / (n - 1);
          return ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                int? best;
                var dist = 26.0;
                for (var i = 0; i < widget.threads.length; i++) {
                  final t = widget.threads[i];
                  final a = index[t.from];
                  final b = index[t.to];
                  if (a == null || b == null) continue;
                  final span = (xOf(b) - xOf(a)).abs();
                  final lift = math.min(size.height * 0.42, 10 + span * 0.35);
                  final mid = Offset((xOf(a) + xOf(b)) / 2, size.height * 0.62 + (t.kind == 'memoria' ? -lift : lift) * 0.75);
                  final dd = (mid - d.localPosition).distance;
                  if (dd < dist) {
                    dist = dd;
                    best = i;
                  }
                }
                if (best != null) _select(best);
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduced ? 1 : 0, end: 1),
                duration: reduced ? Duration.zero : const Duration(milliseconds: 1000),
                curve: Motion.settle,
                builder: (context, t, _) => CustomPaint(
                  size: size,
                  painter: _HilosPainter(
                    n: n,
                    threads: [
                      for (final th in widget.threads)
                        (index[th.from] ?? -1, index[th.to] ?? -1, th.kind == 'memoria'),
                    ],
                    sel: _sel,
                    t: t,
                    consolidated: widget.consolidated,
                    ink: e.ink,
                    graphite: e.graphite,
                    saffron: e.saffron,
                    paper: e.paper,
                    divider: e.divider,
                  ),
                ),
              ),
            ),
          );
        }),
        AnimatedSize(
          duration: reduced ? Duration.zero : Motion.short,
          alignment: Alignment.topLeft,
          child: sel == null
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Este hilo existe por:', style: context.text.labelMedium),
                        Text(content.titleOf(sel.from), style: context.text.titleMedium),
                        Text(content.titleOf(sel.to), style: context.text.titleMedium),
                        const Gap(4),
                        Text(
                          sel.kind == 'memoria' ? 'Lo que dijiste volvió: ${sel.label}' : 'La razón que comparten: ${sel.label}',
                          style: context.text.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        for (var i = 0; i < widget.threads.length; i++)
          Semantics(
            button: true,
            selected: _sel == i,
            label: '${titulo(widget.threads[i])}. ${widget.threads[i].label}',
            hint: 'Destacar las experiencias que construyeron este hilo',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _select(i),
              onLongPress: () => _select(i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 2),
                child: AnimatedOpacity(
                  opacity: _sel == null || _sel == i ? 1 : 0.4,
                  duration: reduced ? Duration.zero : Motion.short,
                  child: MarginNote(titulo(widget.threads[i]), child: Text(widget.threads[i].label, style: context.text.bodyLarge)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HilosPainter extends CustomPainter {
  _HilosPainter({
    required this.n,
    required this.threads,
    required this.sel,
    required this.t,
    required this.consolidated,
    required this.ink,
    required this.graphite,
    required this.saffron,
    required this.paper,
    required this.divider,
  });
  final int n;
  final List<(int, int, bool)> threads;
  final int? sel;
  final double t;
  final bool consolidated;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;
  final Color divider;

  @override
  void paint(Canvas canvas, Size size) {
    if (n == 0) return;
    final cy = size.height * 0.62;
    double xOf(int i) => n <= 1 ? size.width / 2 : 14 + i * (size.width - 28) / (n - 1);
    canvas.drawLine(Offset(4, cy), Offset(size.width - 4, cy), Paint()
      ..color = divider
      ..strokeWidth = 1);
    final involved = <int>{};
    if (sel != null && sel! < threads.length) {
      involved
        ..add(threads[sel!].$1)
        ..add(threads[sel!].$2);
    }
    for (var k = 0; k < threads.length; k++) {
      final (a, b, memoria) = threads[k];
      if (a < 0 || b < 0) continue;
      final span = (xOf(b) - xOf(a)).abs();
      final lift = math.min(size.height * 0.42, 10 + span * 0.35);
      final on = sel == null || sel == k;
      final provisional = !memoria && !consolidated;
      final base = provisional ? graphite : ink;
      paintHilo(
        canvas,
        from: Offset(xOf(a), cy),
        to: Offset(xOf(b), cy),
        color: on ? base : base.withValues(alpha: 0.2),
        progress: ((t - k * 0.06) / 0.7).clamp(0.0, 1.0),
        provisional: provisional,
        width: sel == k ? 2.8 : 1.7,
        seed: a * 5 + b,
        bend: memoria ? -lift : lift,
      );
    }
    for (var i = 0; i < n; i++) {
      final c = Offset(xOf(i), cy);
      final dim = sel != null && !involved.contains(i);
      canvas.drawCircle(c, 8, Paint()..color = paper);
      canvas.drawCircle(c, 6, Paint()..color = dim ? graphite.withValues(alpha: 0.3) : (involved.contains(i) ? ink : graphite));
      if (involved.contains(i)) {
        canvas.drawCircle(c, 10, Paint()
          ..color = saffron
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HilosPainter old) => old.t != t || old.sel != sel || old.ink != ink;
}

/// Los puntos huecos: tocar uno muestra qué decisión lo creó.
class HuecosDelMapa extends ConsumerStatefulWidget {
  const HuecosDelMapa({super.key, required this.hollows, required this.content});
  final List<HollowView> hollows;
  final ContentBundle content;

  @override
  ConsumerState<HuecosDelMapa> createState() => _HuecosDelMapaState();
}

class _HuecosDelMapaState extends ConsumerState<HuecosDelMapa> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final sel = _sel != null && _sel! < widget.hollows.length ? widget.hollows[_sel!] : null;
    final reduced = reducedMotion(context, ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < widget.hollows.length; i++)
              Semantics(
                button: true,
                selected: _sel == i,
                label: '${widget.hollows[i].title}: ${content.common.recognition[widget.hollows[i].recognition] ?? widget.hollows[i].recognition}',
                hint: 'Ver qué decisión lo creó',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () {
                    ref.read(feedbackProvider).selection();
                    setState(() => _sel = _sel == i ? null : i);
                  },
                  child: AnimatedOpacity(
                    opacity: _sel == null || _sel == i ? 1 : 0.4,
                    duration: reduced ? Duration.zero : Motion.short,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          InkDot(
                            style: widget.hollows[i].recognition == Recognition.fuerte
                                ? DotStyle.ringed
                                : (Recognition.isRecognized(widget.hollows[i].recognition) ? DotStyle.hollow : DotStyle.dashed),
                            size: 22,
                            color: widget.hollows[i].recognition == Recognition.fuerte ? context.enves.saffron : null,
                          ),
                          const Gap(4),
                          SizedBox(
                            width: 76,
                            child: Text(widget.hollows[i].title, style: context.text.bodySmall, textAlign: TextAlign.center, maxLines: 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: reduced ? Duration.zero : Motion.short,
          alignment: Alignment.topLeft,
          child: sel == null
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MarginNote(
                      'Lo creó tu reconstrucción en ${sel.title}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('«${sel.targetLabel}»', style: context.text.bodyLarge),
                          Text(content.common.recognition[sel.recognition] ?? sel.recognition, style: context.text.bodySmall),
                          if (sel.strength != null && sel.agreement != null)
                            Text('Fuerza: ${sel.strength} de 5. Acuerdo: ${sel.agreement} de 5.', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
