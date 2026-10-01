import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Formas del Hilo Vivo. Cada una dice algo de la decisión que representa.
///
/// recto: una relación simple. curvo: hubo un cambio de posición.
/// bifurcado: se matizó. reforzado: se mantuvo.
enum HiloForma { recto, curvo, bifurcado, reforzado }

/// Trazo con leve temblor de mano. Determinista: el mismo [seed] dibuja
/// siempre el mismo hilo.
Path inkPath(Offset a, Offset b, {double bend = 0, int seed = 0, double wobble = 1.1}) {
  final path = Path()..moveTo(a.dx, a.dy);
  final d = b - a;
  final len = d.distance;
  if (len == 0) return path;
  final n = Offset(-d.dy / len, d.dx / len);
  final steps = math.max(10, (len / 5).round());
  for (var i = 1; i <= steps; i++) {
    final t = i / steps;
    final base = Offset.lerp(a, b, t)!;
    final arc = math.sin(t * math.pi) * bend;
    final jitter = math.sin(t * 13.0 + seed * 1.7) * wobble * math.sin(t * math.pi);
    final p = base + n * (arc + jitter);
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

/// La fracción [t] de un trazo, para dibujarlo frente al usuario.
Path partialPath(Path path, double t) {
  if (t >= 1) return path;
  final out = Path();
  if (t <= 0) return out;
  for (final m in path.computeMetrics()) {
    out.addPath(m.extractPath(0, m.length * t), Offset.zero);
  }
  return out;
}

/// Trazo punteado: el grafito de lo provisional.
Path dashedPath(Path path, {double dash = 5, double gap = 4}) {
  final out = Path();
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

/// Dibuja un hilo entre dos puntos según su forma y su estado.
void paintHilo(
  Canvas canvas, {
  required Offset from,
  required Offset to,
  required Color color,
  double progress = 1,
  HiloForma forma = HiloForma.recto,
  bool provisional = false,
  double width = 2,
  int seed = 0,
  double bend = 0,
}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = provisional ? width * 0.75 : width
    ..strokeCap = StrokeCap.round;
  final len = (to - from).distance;
  Path path;
  switch (forma) {
    case HiloForma.recto:
      path = inkPath(from, to, seed: seed, bend: bend);
    case HiloForma.curvo:
      path = inkPath(from, to, seed: seed, bend: bend == 0 ? len * 0.22 : bend);
    case HiloForma.reforzado:
      final d = to - from;
      final n = len == 0 ? Offset.zero : Offset(-d.dy / len, d.dx / len) * 1.6;
      path = inkPath(from + n, to + n, seed: seed, bend: bend)
        ..addPath(inkPath(from - n, to - n, seed: seed + 3, bend: bend), Offset.zero);
    case HiloForma.bifurcado:
      final mid = Offset.lerp(from, to, 0.55)!;
      final d = to - from;
      final n = len == 0 ? Offset.zero : Offset(-d.dy / len, d.dx / len) * (len * 0.12);
      path = inkPath(from, mid, seed: seed, bend: bend * 0.5)
        ..addPath(inkPath(mid, to + n, seed: seed + 1), Offset.zero)
        ..addPath(inkPath(mid, to - n, seed: seed + 2), Offset.zero);
  }
  var drawn = partialPath(path, progress);
  if (provisional) drawn = dashedPath(drawn);
  canvas.drawPath(drawn, paint);
}

/// La firma de Envés, viva: ●━━━━┃━━━━○ dibujándose frente al usuario.
///
/// [consolidado] en tinta; si no, en grafito punteado. [hueco] muestra el
/// punto comprendido del otro lado.
class HiloFirma extends ConsumerWidget {
  const HiloFirma({
    super.key,
    this.width = 220,
    this.height = 44,
    this.consolidado = true,
    this.hueco = true,
    this.animar = true,
    this.semanticLabel,
    this.tocable = false,
  });

  final double width;
  final double height;
  final bool consolidado;
  final bool hueco;
  final bool animar;
  final String? semanticLabel;

  /// Tocar el punto lleno dice «tu posición»; el hueco, «posición comprendida».
  final bool tocable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    final painter = TweenAnimationBuilder<double>(
      tween: Tween(begin: (reduced || !animar) ? 1 : 0, end: 1),
      duration: (reduced || !animar) ? Duration.zero : Motion.long * 1.5,
      curve: Motion.settle,
      builder: (context, t, _) => CustomPaint(
        size: Size(width, height),
        painter: _FirmaPainter(
          t: t,
          ink: e.ink,
          graphite: e.graphite,
          saffron: e.saffron,
          paper: e.paper,
          consolidado: consolidado,
          hueco: hueco,
        ),
      ),
    );
    final Widget box = tocable
        ? _FirmaTocable(width: width, height: height, hueco: hueco, child: painter)
        : SizedBox(width: width, height: height, child: painter);
    if (semanticLabel == null) return ExcludeSemantics(child: box);
    return Semantics(label: semanticLabel, excludeSemantics: true, child: box);
  }
}

class _FirmaPainter extends CustomPainter {
  _FirmaPainter({
    required this.t,
    required this.ink,
    required this.graphite,
    required this.saffron,
    required this.paper,
    required this.consolidado,
    required this.hueco,
  });
  final double t;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;
  final bool consolidado;
  final bool hueco;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final r = h * 0.17;
    final cy = h / 2;
    final left = Offset(r + 2, cy);
    final right = Offset(size.width - r - 2, cy);
    final cx = size.width / 2;
    // 1. El punto propio aparece primero.
    final dotT = (t / 0.2).clamp(0.0, 1.0);
    canvas.drawCircle(left, r * dotT, Paint()..color = ink);
    // 2. El eje se traza de arriba abajo.
    final axisT = ((t - 0.15) / 0.25).clamp(0.0, 1.0);
    if (axisT > 0) {
      canvas.drawLine(
        Offset(cx, h * 0.08),
        Offset(cx, h * 0.08 + (h * 0.84) * axisT),
        Paint()
          ..color = ink
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
    }
    // 3. El hilo cruza.
    final threadT = ((t - 0.3) / 0.55).clamp(0.0, 1.0);
    paintHilo(
      canvas,
      from: left + Offset(r, 0),
      to: right - Offset(r, 0),
      color: consolidado ? ink : graphite,
      progress: threadT,
      provisional: !consolidado,
      width: 2,
      seed: 5,
    );
    // 4. Del otro lado, el punto hueco.
    if (hueco) {
      final holT = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
      if (holT > 0) {
        canvas.drawCircle(
          right,
          r * 0.85 * holT,
          Paint()
            ..color = saffron
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.45,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FirmaPainter old) =>
      old.t != t || old.ink != ink || old.consolidado != consolidado || old.hueco != hueco;
}

/// Estado de cada pregunta en el recorrido.
enum NodoEstado { pendiente, enCurso, completa, omitida }

class RecorridoNodo {
  const RecorridoNodo({required this.id, required this.title, required this.estado, this.hueco = false, this.siguiente = false});
  final String id;
  final String title;
  final NodoEstado estado;

  /// Ya cruzó y su reconstrucción fue reconocida.
  final bool hueco;
  final bool siguiente;
}

class RecorridoHilo {
  const RecorridoHilo({required this.from, required this.to, required this.memoria, required this.consolidado});
  final int from;
  final int to;
  final bool memoria;
  final bool consolidado;
}

/// El recorrido como un fragmento de Hilo Vivo: nueve puntos que se llenan de
/// tinta y se conectan con hilos reales. No es una barra de progreso.
class RecorridoHiloVivo extends ConsumerStatefulWidget {
  const RecorridoHiloVivo({super.key, required this.nodos, required this.hilos, this.height = 92});
  final List<RecorridoNodo> nodos;
  final List<RecorridoHilo> hilos;
  final double height;

  @override
  ConsumerState<RecorridoHiloVivo> createState() => _RecorridoHiloVivoState();
}

class _RecorridoHiloVivoState extends ConsumerState<RecorridoHiloVivo> {
  int? _tocado;

  String _estadoTexto(NodoEstado e) {
    switch (e) {
      case NodoEstado.completa:
        return 'completa';
      case NodoEstado.enCurso:
        return 'en curso';
      case NodoEstado.omitida:
        return 'omitida';
      case NodoEstado.pendiente:
        return 'pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    final completas = widget.nodos.where((n) => n.estado == NodoEstado.completa).length;
    final label = 'Tu recorrido: $completas de ${widget.nodos.length} preguntas completas, '
        '${widget.hilos.length} ${widget.hilos.length == 1 ? 'hilo' : 'hilos'} entre ellas.';
    final tocado = _tocado == null || _tocado! >= widget.nodos.length ? null : widget.nodos[_tocado!];
    return Semantics(
      label: label,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final n = widget.nodos.length;
            double xOf(int i) => n <= 1 ? w / 2 : 12 + i * (w - 24) / (n - 1);
            return ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  var best = 0;
                  var dist = double.infinity;
                  for (var i = 0; i < n; i++) {
                    final dd = (xOf(i) - d.localPosition.dx).abs();
                    if (dd < dist) {
                      dist = dd;
                      best = i;
                    }
                  }
                  ref.read(feedbackProvider).selection();
                  setState(() => _tocado = _tocado == best ? null : best);
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0, end: 1),
                  duration: reduced ? Duration.zero : const Duration(milliseconds: 1100),
                  curve: Motion.settle,
                  builder: (context, t, _) => CustomPaint(
                    size: Size(w, widget.height),
                    painter: _RecorridoPainter(
                      nodos: widget.nodos,
                      hilos: widget.hilos,
                      t: t,
                      tocado: _tocado,
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
            child: tocado == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${tocado.title}: ${_estadoTexto(tocado.estado)}${tocado.hueco ? ', cruzaste y comprendiste el otro lado' : ''}.',
                      style: context.text.bodySmall,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecorridoPainter extends CustomPainter {
  _RecorridoPainter({
    required this.nodos,
    required this.hilos,
    required this.t,
    required this.tocado,
    required this.ink,
    required this.graphite,
    required this.saffron,
    required this.paper,
    required this.divider,
  });
  final List<RecorridoNodo> nodos;
  final List<RecorridoHilo> hilos;
  final double t;
  final int? tocado;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;
  final Color divider;

  @override
  void paint(Canvas canvas, Size size) {
    final n = nodos.length;
    if (n == 0) return;
    final cy = size.height * 0.55;
    double xOf(int i) => n <= 1 ? size.width / 2 : 12 + i * (size.width - 24) / (n - 1);

    // Línea base de papel.
    canvas.drawLine(Offset(4, cy), Offset(size.width - 4, cy), Paint()
      ..color = divider
      ..strokeWidth = 1);

    // Hilos: arriba los recuerdos, abajo las razones compartidas.
    for (var k = 0; k < hilos.length; k++) {
      final h = hilos[k];
      if (h.from >= n || h.to >= n) continue;
      final a = Offset(xOf(h.from), cy);
      final b = Offset(xOf(h.to), cy);
      final span = (b.dx - a.dx).abs();
      final lift = math.min(size.height * 0.48, 10 + span * 0.35);
      final highlighted = tocado != null && (h.from == tocado || h.to == tocado);
      final local = ((t - 0.35 - k * 0.05) / 0.5).clamp(0.0, 1.0);
      paintHilo(
        canvas,
        from: a,
        to: b,
        color: h.consolidado || highlighted ? ink : graphite,
        progress: local,
        provisional: !h.consolidado,
        width: highlighted ? 2.4 : 1.6,
        seed: h.from * 7 + h.to,
        bend: h.memoria ? -lift : lift,
      );
    }

    for (var i = 0; i < n; i++) {
      final node = nodos[i];
      final local = ((t - i * 0.03) / 0.3).clamp(0.0, 1.0);
      final c = Offset(xOf(i), cy);
      const r = 7.0;
      final rr = r * local;
      canvas.drawCircle(c, r + 2, Paint()..color = paper);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = node.estado == NodoEstado.pendiente ? graphite : ink;
      switch (node.estado) {
        case NodoEstado.completa:
          canvas.drawCircle(c, rr, Paint()..color = ink);
        case NodoEstado.enCurso:
          canvas.drawCircle(c, rr, stroke);
          canvas.drawArc(Rect.fromCircle(center: c, radius: rr), math.pi / 2, math.pi, true, Paint()..color = ink);
        case NodoEstado.omitida:
          const seg = 8;
          for (var s = 0; s < seg; s++) {
            canvas.drawArc(Rect.fromCircle(center: c, radius: rr), s * 2 * math.pi / seg, math.pi / seg, false, stroke);
          }
        case NodoEstado.pendiente:
          canvas.drawCircle(c, rr * 0.8, stroke);
      }
      if (node.hueco) {
        // El punto comprendido flota sobre el propio: lo que viste del otro lado.
        canvas.drawCircle(c + Offset(0, -r - 8), 3.5 * local, Paint()
          ..color = saffron
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
      }
      if (node.siguiente) {
        canvas.drawCircle(c, (r + 5) * local, Paint()
          ..color = saffron
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
      }
      if (tocado == i) {
        canvas.drawLine(c + const Offset(-9, 14), c + const Offset(9, 14), Paint()
          ..color = ink
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RecorridoPainter old) =>
      old.t != t || old.tocado != tocado || old.ink != ink || old.nodos != nodos || old.hilos != hilos;
}

/// Hilo vertical que conecta dos bloques (por ejemplo, un recuerdo con la
/// pregunta actual). Se dibuja una vez, frente al usuario.
class HiloConector extends ConsumerWidget {
  const HiloConector({super.key, this.height = 36, this.provisional = false, this.forma = HiloForma.curvo, this.visible = true});
  final double height;
  final bool provisional;
  final HiloForma forma;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: visible ? 1 : 0),
        duration: reduced ? Duration.zero : Motion.long,
        curve: Motion.settle,
        builder: (context, t, _) => CustomPaint(
          size: Size(double.infinity, height),
          painter: _ConectorPainter(t: t, color: provisional ? e.graphite : e.ink, provisional: provisional, forma: forma),
        ),
      ),
    );
  }
}

class _ConectorPainter extends CustomPainter {
  _ConectorPainter({required this.t, required this.color, required this.provisional, required this.forma});
  final double t;
  final Color color;
  final bool provisional;
  final HiloForma forma;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final from = Offset(18, 0);
    final to = Offset(34, size.height);
    paintHilo(canvas, from: from, to: to, color: color, progress: t, provisional: provisional, forma: forma, seed: 2, bend: 8);
    if (t >= 1) {
      canvas.drawCircle(to, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ConectorPainter old) => old.t != t || old.color != color;
}

/// Semilla estable a partir de un texto (no depende de String.hashCode).
int semillaDe(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// Una muestra del trazo con que se descubrió una distinción: cada entrada
/// del cuaderno guarda su propia firma de tinta. En duda, queda en grafito.
class TrazoMuestra extends ConsumerWidget {
  const TrazoMuestra({super.key, required this.semilla, this.dudosa = false, this.width = 40, this.height = 20, this.animar = false});
  final String semilla;
  final bool dudosa;
  final double width;
  final double height;
  final bool animar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: (animar && !reduced) ? 0 : 1, end: 1),
        duration: (animar && !reduced) ? const Duration(milliseconds: 900) : Duration.zero,
        curve: Motion.settle,
        builder: (context, t, _) => CustomPaint(
          size: Size(width, height),
          painter: _TrazoPainter(semillaDe(semilla), dudosa ? e.graphite : e.ink, e.saffron, dudosa, t),
        ),
      ),
    );
  }
}

class _TrazoPainter extends CustomPainter {
  _TrazoPainter(this.seed, this.color, this.saffron, this.dudosa, this.t);
  final int seed;
  final Color color;
  final Color saffron;
  final bool dudosa;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = math.Random(seed);
    final path = Path()..moveTo(2, h * (0.4 + r.nextDouble() * 0.3));
    const steps = 4;
    for (var i = 1; i <= steps; i++) {
      final x = 2 + (w - 4) * i / steps;
      final cx = x - (w - 4) / steps / 2;
      final cy = h * (0.1 + r.nextDouble() * 0.8);
      final y = h * (0.3 + r.nextDouble() * 0.4);
      path.quadraticBezierTo(cx, cy, x, y);
    }
    var drawn = partialPath(path, t);
    if (dudosa) drawn = dashedPath(drawn, dash: 3, gap: 2.5);
    canvas.drawPath(drawn, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, h * 0.1)
      ..strokeCap = StrokeCap.round);
    if (t >= 1) canvas.drawCircle(Offset(w - 2, h * 0.5), math.max(1.6, h * 0.08), Paint()..color = saffron);
  }

  @override
  bool shouldRepaint(covariant _TrazoPainter old) => old.t != t || old.seed != seed || old.color != color;
}

class _FirmaTocable extends ConsumerStatefulWidget {
  const _FirmaTocable({required this.width, required this.height, required this.hueco, required this.child});
  final double width;
  final double height;
  final bool hueco;
  final Widget child;

  @override
  ConsumerState<_FirmaTocable> createState() => _FirmaTocableState();
}

class _FirmaTocableState extends ConsumerState<_FirmaTocable> {
  String? _texto;
  bool _derecha = false;
  int _gen = 0;

  void _tap(TapUpDetails d) {
    final derecha = d.localPosition.dx > widget.width * 0.6;
    if (derecha && !widget.hueco) return;
    if (!derecha && d.localPosition.dx > widget.width * 0.4) return;
    ref.read(feedbackProvider).selection();
    final gen = ++_gen;
    setState(() {
      _derecha = derecha;
      _texto = derecha ? 'posición comprendida' : 'tu posición';
    });
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && gen == _gen) setState(() => _texto = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height + 20,
      child: Column(
        crossAxisAlignment: _derecha ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _tap,
            child: SizedBox(width: widget.width, height: widget.height, child: widget.child),
          ),
          SizedBox(
            height: 20,
            child: AnimatedOpacity(
              opacity: _texto == null ? 0 : 1,
              duration: Motion.short,
              child: Text(_texto ?? '', style: context.marginNote.copyWith(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
