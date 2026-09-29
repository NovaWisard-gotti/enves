import 'package:enves/engine/fairness/fairness_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('ningún par de puntajes cumple a la vez los dos criterios', () async {
    final c = await loadContent();
    final model = FairnessModel.fromConfig(c.byId['e5_cien_becas']!.eligeProbe!.config);
    expect(model.isValid, isTrue);
    var c1 = 0, c2 = 0, both = 0;
    for (final n in model.thresholds) {
      for (final s in model.thresholds) {
        final r = model.evaluate(n, s);
        if (r.indicator1) c1++;
        if (r.indicator2) c2++;
        if (r.indicator1 && r.indicator2) both++;
      }
    }
    expect(c1, greaterThan(0));
    expect(c2, greaterThan(0));
    expect(both, 0);
  });

  test('las métricas son coherentes con los datos', () async {
    final c = await loadContent();
    final model = FairnessModel.fromConfig(c.byId['e5_cien_becas']!.eligeProbe!.config);
    final m = model.metrics(model.groups.first, 0);
    expect(m.falseNegatives, 0);
    expect(m.awarded, model.groups.first.bins.fold<int>(0, (a, b) => a + b.n));
  });
}
