import '../../core/json.dart';

class FairnessBin {
  const FairnessBin({required this.score, required this.n, required this.pos});
  final int score;
  final int n;
  final int pos;
}

class FairnessGroup {
  const FairnessGroup({required this.id, required this.label, required this.bins});
  final String id;
  final String label;
  final List<FairnessBin> bins;
}

/// Métricas de un barrio para un puntaje mínimo dado.
class GroupMetrics {
  const GroupMetrics({
    required this.awarded,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.trueNegatives,
  });
  final int awarded;
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;
  final int trueNegatives;

  /// Entre quienes reciben beca, proporción que termina.
  double? get predictive => awarded == 0 ? null : truePositives / awarded;

  /// Becas negadas por error: quienes habrían terminado y se quedan fuera.
  double get deniedByError {
    final d = truePositives + falseNegatives;
    return d == 0 ? 0 : falseNegatives / d;
  }

  /// Becas dadas por error: quienes no terminarían y la reciben.
  double get grantedByError {
    final d = falsePositives + trueNegatives;
    return d == 0 ? 0 : falsePositives / d;
  }
}

class FairnessResult {
  const FairnessResult({required this.north, required this.south, required this.indicator1, required this.indicator2});
  final GroupMetrics north;
  final GroupMetrics south;
  final bool indicator1;
  final bool indicator2;
}

/// Conjunto de datos fijo y determinista. Los indicadores se calculan de
/// verdad; no hay resultados animados inventados.
class FairnessModel {
  const FairnessModel({required this.groups, required this.tolerance});

  final List<FairnessGroup> groups;
  final double tolerance;

  factory FairnessModel.fromConfig(Json config) {
    final groups = asJsonList(config['groups'])
        .map((g) => FairnessGroup(
              id: asString(g['id']),
              label: asString(g['label']),
              bins: asJsonList(g['bins'])
                  .map((b) => FairnessBin(score: asInt(b['score']), n: asInt(b['n']), pos: asInt(b['pos'])))
                  .toList(),
            ))
        .toList();
    return FairnessModel(groups: groups, tolerance: asDouble(config['tolerance'], 0.03));
  }

  bool get isValid => groups.length == 2 && groups.every((g) => g.bins.isNotEmpty);

  List<int> get thresholds => groups.isEmpty ? const [] : groups.first.bins.map((b) => b.score).toList();

  GroupMetrics metrics(FairnessGroup g, int threshold) {
    var tp = 0, fp = 0, fn = 0, tn = 0;
    for (final b in g.bins) {
      if (b.score >= threshold) {
        tp += b.pos;
        fp += b.n - b.pos;
      } else {
        fn += b.pos;
        tn += b.n - b.pos;
      }
    }
    return GroupMetrics(awarded: tp + fp, truePositives: tp, falsePositives: fp, falseNegatives: fn, trueNegatives: tn);
  }

  FairnessResult evaluate(int northThreshold, int southThreshold) {
    final n = metrics(groups[0], northThreshold);
    final s = metrics(groups[1], southThreshold);
    const eps = 1e-9;
    final pn = n.predictive;
    final ps = s.predictive;
    final i1 = pn != null && ps != null && (pn - ps).abs() <= tolerance + eps;
    final i2 = (n.deniedByError - s.deniedByError).abs() <= tolerance + eps &&
        (n.grantedByError - s.grantedByError).abs() <= tolerance + eps &&
        pn != null &&
        ps != null;
    return FairnessResult(north: n, south: s, indicator1: i1, indicator2: i2);
  }
}
