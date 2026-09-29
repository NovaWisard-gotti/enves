import '../../domain/content/condition.dart';
import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';

/// Resuelve los hechos que consultan las condiciones.
///
/// Los registros de otras experiencias solo se exponen si esa experiencia está
/// completada: así una experiencia abandonada u omitida nunca alimenta un
/// recuerdo. Un hecho inexistente devuelve `null`, nunca un valor inventado.
class FactResolver {
  FactResolver(this.content, this.state, this.currentId);

  final ContentBundle content;
  final UserState state;
  final String currentId;

  Object? call(String fact) {
    final parts = fact.split('.');
    if (parts.isEmpty || parts.first.isEmpty) return null;
    final head = parts.first;
    if (head == 'onboarding') {
      if (parts.length > 1 && parts[1] == 'stance') return state.onboarding?.stance.value;
      return null;
    }
    if (head == 'hollow') {
      final recs = hollowRecords(state, excluding: currentId);
      if (parts.length > 1 && parts[1] == 'count') return recs.length;
      if (parts.length > 1 && parts[1] == 'recognized') {
        return recs.where((p) => Recognition.isRecognized(p.cruza!.finalRecognition)).length;
      }
      return null;
    }
    final isThis = head == 'this';
    final expId = isThis ? currentId : head;
    final p = state.experiences[expId];
    if (parts.length >= 2 && parts[1] == 'status') {
      if (!isThis && !content.byId.containsKey(expId) && content.catalogEntry(expId) == null) return null;
      return (p?.status ?? ExpStatus.notStarted).name;
    }
    if (p == null) return null;
    if (!isThis && p.status != ExpStatus.completed) return null;
    return _field(p, parts.sublist(1));
  }

  Object? _field(ExperienceProgress p, List<String> path) {
    if (path.isEmpty) return null;
    switch (path.first) {
      case 'stance':
        if (path.length < 2) return null;
        if (path[1] == 'initial') return p.initialStance?.value;
        if (path[1] == 'final') return p.finalStance?.value;
        return null;
      case 'reason':
        final r = p.reason;
        if (r == null || path.length < 2) return null;
        if (path[1] == 'id') return r.id;
        if (path[1] == 'tags') return r.tags;
        return null;
      case 'tension':
        final t = p.tension;
        if (t == null || path.length < 2) return null;
        if (path[1] == 'outcome') return t.outcome;
        if (path[1] == 'target') return t.revisionTarget;
        return null;
      case 'probe':
        if (path.length < 3) return null;
        return p.probes[path[1]]?[path[2]];
      case 'answer':
        if (path.length < 2) return null;
        for (final r in p.socratic) {
          if (r.questionId == path[1]) return r.answerId;
        }
        return null;
    }
    return null;
  }
}

/// Experiencias completadas con un punto hueco registrado.
List<ExperienceProgress> hollowRecords(UserState state, {String? excluding}) {
  final list = state.experiences.values
      .where((p) =>
          p.experienceId != excluding &&
          p.status == ExpStatus.completed &&
          p.cruza != null &&
          p.cruza!.finalRecognition != null)
      .toList()
    ..sort((a, b) => a.experienceId.compareTo(b.experienceId));
  return list;
}

class ConditionEvaluator {
  const ConditionEvaluator(this.resolve);

  final Object? Function(String fact) resolve;

  bool eval(Condition c) {
    switch (c.kind) {
      case 'always':
        return true;
      case 'all':
        return c.children.every(eval);
      case 'any':
        return c.children.any(eval);
      case 'not':
        return c.children.isEmpty ? true : !eval(c.children.first);
      default:
        return _leaf(c);
    }
  }

  bool _leaf(Condition c) {
    final fact = c.fact;
    if (fact == null || fact.isEmpty) return false;
    final actual = resolve(fact);
    final op = c.op ?? 'eq';
    if (op == 'exists') return actual != null;
    if (op == 'notExists') return actual == null;
    if (actual == null) return false;
    final expected = c.value;
    switch (op) {
      case 'eq':
        return _eq(actual, expected);
      case 'ne':
        return !_eq(actual, expected);
      case 'in':
        return expected is List && expected.any((e) => _eq(actual, e));
      case 'notIn':
        return expected is List && !expected.any((e) => _eq(actual, e));
      case 'gt':
        return _cmp(actual, expected, (a, b) => a > b);
      case 'gte':
        return _cmp(actual, expected, (a, b) => a >= b);
      case 'lt':
        return _cmp(actual, expected, (a, b) => a < b);
      case 'lte':
        return _cmp(actual, expected, (a, b) => a <= b);
      case 'containsAny':
        return actual is List && expected is List && actual.any((a) => expected.any((e) => _eq(a, e)));
      default:
        return false;
    }
  }

  static bool _eq(Object? a, Object? b) {
    if (a == null || b == null) return false;
    if (a is num && b is num) return a == b;
    return a.toString() == b.toString();
  }

  static bool _cmp(Object a, Object? b, bool Function(num, num) f) => a is num && b is num && f(a, b);
}

/// Sustituye marcadores `{clave}` y `{fact:ruta}`. Si falta un solo valor,
/// devuelve `null`: nunca se muestra un texto incompleto.
class TemplateRenderer {
  static final RegExp pattern = RegExp(r'\{([a-zA-Z_:.0-9]+)\}');

  static Set<String> keys(String template) => pattern.allMatches(template).map((m) => m.group(1)!).toSet();

  static String? render(String template, Map<String, String> values, Object? Function(String) facts) {
    var ok = true;
    final out = template.replaceAllMapped(pattern, (m) {
      final key = m.group(1)!;
      String? v;
      if (key.startsWith('fact:')) {
        v = facts(key.substring(5))?.toString();
      } else {
        v = values[key];
      }
      if (v == null || v.isEmpty) {
        ok = false;
        return '';
      }
      return v;
    });
    return ok ? out : null;
  }
}
