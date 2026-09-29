import 'package:flutter/material.dart';

import '../domain/records/records.dart';
import '../theme/app_theme.dart';

/// Balanza de postura con 7 zonas: −3…−1 izquierda, 0 «No lo sé», 1…3 derecha.
///
/// Se usa arrastrando, tocando cualquier punto de la línea o con las acciones
/// de aumentar y disminuir de TalkBack. Nunca usa verde ni rojo.
class Balanza extends StatelessWidget {
  const Balanza({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
    required this.prompt,
    this.ghost,
    this.onZoneChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final int? value;
  final int? ghost;
  final ValueChanged<int> onChanged;
  final VoidCallback? onZoneChanged;
  final String prompt;

  static String statusText(int? v, String left, String right) {
    if (v == null) return 'Desliza o toca la línea para tomar postura';
    if (v == 0) return StanceRecord.unknownLabel;
    final label = v < 0 ? left : right;
    final c = confidenceLabelFor(v);
    return '$label. ${c[0].toUpperCase()}${c.substring(1)}';
  }

  void _set(int v) {
    final clamped = v.clamp(-3, 3).toInt();
    if (clamped != value) {
      onZoneChanged?.call();
      onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final status = statusText(value, leftLabel, rightLabel);
    final current = value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(leftLabel, style: context.text.labelLarge)),
              const SizedBox(width: 16),
              Expanded(child: Text(rightLabel, style: context.text.labelLarge, textAlign: TextAlign.right)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          const pad = 24.0;
          final half = (width - pad * 2) / 2;
          final center = width / 2;
          int valueAt(double dx) => ((dx - center) / half * 3).round().clamp(-3, 3).toInt();
          return Semantics(
            slider: true,
            label: prompt,
            value: status,
            increasedValue: statusText((current + 1).clamp(-3, 3).toInt(), leftLabel, rightLabel),
            decreasedValue: statusText((current - 1).clamp(-3, 3).toInt(), leftLabel, rightLabel),
            onIncrease: () => _set(current + 1),
            onDecrease: () => _set(current - 1),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _set(valueAt(d.localPosition.dx)),
              onHorizontalDragUpdate: (d) => _set(valueAt(d.localPosition.dx)),
              child: SizedBox(
                width: width,
                height: 72,
                child: CustomPaint(
                  painter: _BalanzaPainter(
                    value: value,
                    ghost: ghost,
                    ink: e.ink,
                    graphite: e.graphite,
                    saffron: e.saffron,
                    paper: e.paper,
                    pad: pad,
                  ),
                ),
              ),
            ),
          );
        }),
        ExcludeSemantics(
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: value == null ? context.text.bodySmall : context.text.titleMedium,
          ),
        ),
        if (ghost != null && value != null)
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                ghost == value ? 'Igual que antes' : 'Antes: ${statusText(ghost, leftLabel, rightLabel)}',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _BalanzaPainter extends CustomPainter {
  _BalanzaPainter({
    required this.value,
    required this.ghost,
    required this.ink,
    required this.graphite,
    required this.saffron,
    required this.paper,
    required this.pad,
  });

  final int? value;
  final int? ghost;
  final Color ink;
  final Color graphite;
  final Color saffron;
  final Color paper;
  final double pad;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final left = pad;
    final right = size.width - pad;
    final half = (right - left) / 2;
    final center = size.width / 2;
    double xOf(int v) => center + v / 3 * half;

    final track = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, cy), Offset(right, cy), track);
    final tick = Paint()
      ..color = graphite
      ..strokeWidth = 1.5;
    for (var v = -3; v <= 3; v++) {
      if (v == 0) continue;
      canvas.drawLine(Offset(xOf(v), cy - 6), Offset(xOf(v), cy + 6), tick);
    }
    // El eje del desacuerdo.
    canvas.drawLine(Offset(center, cy - 22), Offset(center, cy + 22), Paint()
      ..color = ink
      ..strokeWidth = 3);

    if (ghost != null) {
      final g = Paint()
        ..color = graphite
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      const segments = 12;
      for (var i = 0; i < segments; i++) {
        final start = i * 6.2832 / segments;
        canvas.drawArc(Rect.fromCircle(center: Offset(xOf(ghost!), cy), radius: 13), start, 6.2832 / segments / 2, false, g);
      }
    }

    final v = value;
    final x = xOf(v ?? 0);
    const r = 15.0;
    canvas.drawCircle(Offset(x, cy), r, Paint()..color = paper);
    canvas.drawCircle(
      Offset(x, cy),
      r - 1.5,
      Paint()
        ..color = v == null ? graphite : ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    if (v != null && v != 0) {
      canvas.drawCircle(Offset(x, cy), (r - 4) * v.abs() / 3, Paint()..color = ink);
    }
    if (v == 0) {
      canvas.drawCircle(Offset(x, cy), 3, Paint()..color = saffron);
    }
  }

  @override
  bool shouldRepaint(covariant _BalanzaPainter old) =>
      old.value != value || old.ghost != ghost || old.ink != ink || old.paper != paper;
}
