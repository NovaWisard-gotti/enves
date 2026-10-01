import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import 'hilo_vivo.dart';
import 'paper.dart';

/// Margen vivo: una marca pequeña junto al texto. Al tocarla, la anotación se
/// despliega desde el lateral, como si alguien hubiera escrito junto a tu
/// pensamiento. Funciona con TalkBack como un botón expandible.
class MargenVivo extends ConsumerStatefulWidget {
  const MargenVivo({
    super.key,
    required this.marca,
    required this.texto,
    this.child,
    this.abierto = false,
    this.onAbrir,
  });

  /// Lo que se lee junto a la marca antes de abrirla.
  final String marca;
  final String texto;
  final Widget? child;
  final bool abierto;
  final VoidCallback? onAbrir;

  @override
  ConsumerState<MargenVivo> createState() => _MargenVivoState();
}

class _MargenVivoState extends ConsumerState<MargenVivo> {
  late bool _open = widget.abierto;

  void _toggle() {
    ref.read(feedbackProvider).selection();
    setState(() => _open = !_open);
    if (_open) widget.onAbrir?.call();
  }

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    final d = reduced ? Duration.zero : Motion.medium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: widget.marca,
          hint: _open ? 'Cerrar la anotación' : 'Abrir la anotación al margen',
          excludeSemantics: true,
          child: InkWell(
            onTap: _toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  _MarcaMargen(abierta: _open),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.marca, style: context.marginNote.copyWith(fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: d,
          curve: Motion.settle,
          alignment: Alignment.topLeft,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0, end: 1),
                  duration: d,
                  curve: Motion.settle,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(offset: Offset(-24 * (1 - t), 0), child: child),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(left: 6, top: 2, bottom: 8),
                      padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: e.saffron, width: 2))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.texto, style: context.text.bodyLarge),
                          if (widget.child != null) widget.child!,
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

/// La marca al margen: un trazo azafrán que se cierra al abrir.
class _MarcaMargen extends StatelessWidget {
  const _MarcaMargen({required this.abierta});
  final bool abierta;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _MarcaPainter(abierta, e.saffron, e.ink)),
    );
  }
}

class _MarcaPainter extends CustomPainter {
  _MarcaPainter(this.abierta, this.saffron, this.ink);
  final bool abierta;
  final Color saffron;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = saffron
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(3, 2), Offset(3, size.height - 2), p);
    if (abierta) {
      canvas.drawLine(Offset(8, size.height / 2), Offset(size.width - 2, size.height / 2), p);
    } else {
      // Una pequeña anotación cerrada: dos rayas de mano.
      canvas.drawPath(inkPath(Offset(8, 8), Offset(size.width - 3, 7), seed: 1, wobble: 0.6), p);
      canvas.drawPath(inkPath(Offset(8, 14), Offset(size.width - 7, 14), seed: 2, wobble: 0.6), p);
    }
  }

  @override
  bool shouldRepaint(covariant _MarcaPainter old) => old.abierta != abierta || old.saffron != saffron;
}

/// Ver el envés: mantener pulsado (o tocar el doblez) da vuelta la hoja y
/// muestra la otra cara del asunto. No cambia ninguna postura.
class VerElEnves extends ConsumerStatefulWidget {
  const VerElEnves({super.key, required this.titulo, required this.texto, required this.child, this.etiqueta = 'Ver el envés'});

  /// Qué hay del otro lado: «La pregunta de fondo», «La objeción», etc.
  final String titulo;
  final String texto;
  final Widget child;
  final String etiqueta;

  @override
  ConsumerState<VerElEnves> createState() => _VerElEnvesState();
}

class _VerElEnvesState extends ConsumerState<VerElEnves> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.long);
  bool _vuelta = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    final reduced = reducedMotionNow(context, ref);
    _c.duration = reduced ? Motion.reduced : Motion.long;
    ref.read(feedbackProvider).light();
    setState(() => _vuelta = !_vuelta);
    if (_vuelta) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final reduced = reducedMotion(context, ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onLongPress: _toggle,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Motion.turn.transform(_c.value);
              final back = t >= 0.5;
              final face = back
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: e.reverse, border: Border.all(color: e.divider)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.titulo, style: context.text.labelMedium),
                          const Gap(8),
                          Text(widget.texto, style: context.text.bodyLarge),
                        ],
                      ),
                    )
                  : widget.child;
              if (reduced) {
                return Opacity(opacity: back ? (t - 0.5) * 2 : 1 - t * 2, child: face);
              }
              final angle = back ? (1 - t) * math.pi : t * math.pi;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0011)
                  ..rotateY(back ? -angle : angle),
                child: face,
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            label: _vuelta ? 'Volver al derecho' : '${widget.etiqueta}: ${widget.titulo}',
            excludeSemantics: true,
            child: InkWell(
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(_vuelta ? 'Volver al derecho' : widget.etiqueta, style: context.text.labelMedium)),
                      const SizedBox(width: 8),
                      CustomPaint(size: const Size(20, 20), painter: _DoblezPainter(e.ink, e.reverse, _vuelta)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// La esquina doblada de la hoja.
class _DoblezPainter extends CustomPainter {
  _DoblezPainter(this.ink, this.reverse, this.vuelta);
  final Color ink;
  final Color reverse;
  final bool vuelta;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final corner = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.6, 0)
      ..lineTo(w, w * 0.4)
      ..lineTo(w, w)
      ..lineTo(0, w)
      ..close();
    canvas.drawPath(corner, p);
    final fold = Path()
      ..moveTo(w * 0.6, 0)
      ..lineTo(w * 0.6, w * 0.4)
      ..lineTo(w, w * 0.4)
      ..close();
    canvas.drawPath(fold, Paint()..color = vuelta ? ink : reverse);
    canvas.drawPath(fold, p);
  }

  @override
  bool shouldRepaint(covariant _DoblezPainter old) => old.vuelta != vuelta || old.ink != ink;
}
