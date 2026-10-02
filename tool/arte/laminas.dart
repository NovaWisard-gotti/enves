import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enves/widgets/arte.dart';
import 'package:enves/widgets/composiciones.dart';
import 'package:enves/features/experience/probes/escenas.dart';
import 'package:enves/features/experience/probes/probes.dart';

class Lamina {
  const Lamina(this.size, this.build, {this.overrides = const []});
  final Size size;
  final Widget Function(BuildContext context) build;
  final List<Override> overrides;
}

class _P extends CustomPainter {
  _P(this.t, this.fn);
  final Tinta t;
  final void Function(Canvas c, Size s, Tinta t) fn;
  @override
  void paint(Canvas canvas, Size size) => fn(canvas, size, t);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Widget pinta(void Function(Canvas c, Size s, Tinta t) fn) =>
    Builder(builder: (context) => CustomPaint(painter: _P(Tinta.of(context), fn), size: Size.infinite));

final laminas = <String, Lamina>{
  'primitivas': Lamina(const Size(900, 420), (_) => pinta((c, s, t) {
        dibujarSilueta(c, const Rect.fromLTWH(20, 20, 120, 312), t.ink, atras: t.ink2, papel: t.paper);
        dibujarSilueta(c, const Rect.fromLTWH(160, 20, 120, 312), t.ink, derecha: false, paso: 1, atras: t.ink2, papel: t.paper);
        dibujarSilueta(c, const Rect.fromLTWH(300, 120, 90, 234), t.ink, nino: true, paso: 0.8, gesto: 1, atras: t.ink2, papel: t.paper);
        c.drawPath(busto(const Rect.fromLTWH(410, 40, 120, 120)), relleno(t.ink));
        c.drawPath(busto(const Rect.fromLTWH(540, 40, 120, 120), derecha: false), relleno(t.graphite));
        dibujarAuto(c, const Rect.fromLTWH(420, 220, 300, 126), t);
        dibujarReloj(c, const Offset(780, 80), 34, t);
        dibujarRecibo(c, const Rect.fromLTWH(760, 160, 60, 90), t, giro: 0.08);
        final parts = siluetaPartesDe(const Rect.fromLTWH(760, 270, 50, 130));
        for (final p in parts.values) {
          c.drawPath(p, linea(t.ink, 1.2));
        }
        tramar(c, parts[Parte.torso]!, t.ink);
      })),
  'onboarding': Lamina(const Size(390, 260), (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Composicion(height: 240, pintor: (t, v) => DosPerspectivasPainter(t, v)),
      )),
  'vinetas': Lamina(const Size(390, 1500), (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          for (var i = 1; i <= 9; i++) ...[VinetaArte('e$i', height: 140), const SizedBox(height: 18)],
        ]),
      )),
  'escenas': Lamina(const Size(390, 1900), (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          EscenaComparada(t: 0, nombreA: 'Ana', nombreB: 'Beto', onChanged: (_) {}, onSoltar: () {}),
          const SizedBox(height: 16),
          EscenaComparada(t: 1, nombreA: 'Ana', nombreB: 'Beto', onChanged: (_) {}, onSoltar: () {}),
          const SizedBox(height: 16),
          MarcasReproche(nombre: 'Ana', escala: const ['Nada', 'Poco', 'Algo', 'Bastante', 'Mucho'], valor: 2, onChanged: (_) {}),
          MarcasReproche(nombre: 'Beto', escala: const ['Nada', 'Poco', 'Algo', 'Bastante', 'Mucho'], valor: 4, onChanged: (_) {}),
          const SizedBox(height: 16),
          const HilosPromesa(),
          const SizedBox(height: 16),
          SizedBox(height: 330, child: pinta((c, s, t) => CirculosPainter(activo: 2, marcas: const {2: -1, 3: 1}, sombra: -1, c: t,
              etiquetas: const ['Tú', 'Hermano', 'Compañero', 'Desconocido'], estilo: const TextStyle(fontSize: 12)).paint(c, s))),
          const SizedBox(height: 16),
          SizedBox(height: 300, child: pinta((c, s, t) => RedPainter(rows: 4, cols: 3, accepted: const {'0:0', '1:1', '2:0', '3:2'}, active: 0, last: null, lastT: 1,
              positions: const [Offset(0.16, 0.3), Offset(0.84, 0.3), Offset(0.16, 0.74), Offset(0.84, 0.74)], c: t).paint(c, s))),
        ]),
      )),
  'dosfiguras': Lamina(const Size(390, 300), (_) => const Padding(padding: EdgeInsets.all(24), child: DosFiguras())),
};
