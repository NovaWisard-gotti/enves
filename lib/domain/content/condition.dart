import '../../core/json.dart';

/// Condición declarativa escrita en el contenido.
///
/// Formas admitidas: `{}` (siempre verdadera), `{"all": [...]}`,
/// `{"any": [...]}`, `{"not": {...}}` y hojas `{"fact": ..., "op": ..., "value": ...}`.
class Condition {
  const Condition._(this.kind, {this.children = const [], this.fact, this.op, this.value});

  static const Condition always = Condition._('always');

  final String kind;
  final List<Condition> children;
  final String? fact;
  final String? op;
  final Object? value;

  factory Condition.fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null || m.isEmpty) return always;
    if (m['all'] is List) {
      return Condition._('all', children: (m['all'] as List).map((e) => Condition.fromJson(e)).toList());
    }
    if (m['any'] is List) {
      return Condition._('any', children: (m['any'] as List).map((e) => Condition.fromJson(e)).toList());
    }
    if (m.containsKey('not')) {
      return Condition._('not', children: [Condition.fromJson(m['not'])]);
    }
    return Condition._('leaf', fact: asString(m['fact']), op: asString(m['op'], 'eq'), value: m['value']);
  }

  /// Todos los hechos que la condición consulta (para validación).
  List<String> get facts {
    if (kind == 'leaf') return [fact ?? ''];
    return children.expand((c) => c.facts).toList();
  }
}
