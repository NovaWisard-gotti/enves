import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';
import '../rules/rules.dart';

/// Valores de un recuerdo y el registro real del que sale cada uno.
class MemoryBinding {
  const MemoryBinding(this.values, this.refs);

  /// Marcador → texto literal.
  final Map<String, String> values;

  /// Marcador → registro de origen.
  final Map<String, RecordRef> refs;

  List<RecordRef> refsFor(Iterable<String> usedKeys) {
    final out = <RecordRef>[];
    for (final k in usedKeys) {
      final r = refs[k];
      if (r != null && !out.any((x) => x.key == r.key)) out.add(r);
    }
    return out;
  }
}

/// Construye recuerdos solo a partir de registros confirmados.
///
/// Regla central: se cita, no se interpreta. Cada valor es una copia literal
/// de lo que el usuario vio y eligió.
class MemoryEngine {
  const MemoryEngine();

  static const memoryKeys = {'titulo', 'razon', 'postura', 'seguridad', 'n', 'k'};

  MemoryBinding? bind(ContentBundle content, UserState state, String currentId, MemorySpec spec) {
    switch (spec.source) {
      case 'onboarding':
        return _onboarding(state);
      case 'hollow':
        return _hollow(content, state, currentId);
      default:
        return _experience(content, state, spec);
    }
  }

  MemoryBinding? _onboarding(UserState state) {
    final o = state.onboarding;
    if (o == null) return null;
    final ref = RecordRef(
      experienceId: 'onboarding',
      field: 'onboarding',
      at: o.completedAt,
      quote: o.stance.label,
    );
    return MemoryBinding(
      {'postura': o.stance.label, 'seguridad': o.stance.confidence},
      {'postura': ref, 'seguridad': ref},
    );
  }

  MemoryBinding? _hollow(ContentBundle content, UserState state, String currentId) {
    final recs = hollowRecords(state, excluding: currentId);
    if (recs.isEmpty) return null;
    final recognized = recs.where((p) => Recognition.isRecognized(p.cruza!.finalRecognition)).length;
    final ref = RecordRef(
      experienceId: recs.first.experienceId,
      field: 'cruza',
      at: recs.first.cruza!.completedAt ?? recs.first.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      quote: recs.map((p) => content.titleOf(p.experienceId)).join(', '),
    );
    return MemoryBinding(
      {'n': '${recs.length}', 'k': '$recognized'},
      {'n': ref, 'k': ref},
    );
  }

  MemoryBinding? _experience(ContentBundle content, UserState state, MemorySpec spec) {
    final p = state.experiences[spec.source];
    if (p == null || p.status != ExpStatus.completed) return null;
    if (spec.excludeIfRevised && (p.tension?.revisedPrinciple ?? false)) return null;
    final title = content.titleOf(spec.source);
    if (title.isEmpty) return null;
    final values = <String, String>{};
    final refs = <String, RecordRef>{};
    final stance = p.finalStance ?? p.initialStance;
    if (stance != null) {
      final ref = RecordRef(
        experienceId: spec.source,
        field: p.finalStance != null ? 'stance.final' : 'stance.initial',
        at: stance.at,
        quote: stance.label,
      );
      values['titulo'] = title;
      values['postura'] = stance.label;
      values['seguridad'] = stance.confidence;
      refs['postura'] = ref;
      refs['seguridad'] = ref;
    }
    final reason = p.reason;
    if (reason != null && reason.isQuotable && reason.text.isNotEmpty) {
      final ref = RecordRef(experienceId: spec.source, field: 'reason', at: reason.at, quote: reason.text);
      values['titulo'] = title;
      values['razon'] = reason.text;
      refs['razon'] = ref;
    }
    if (values.isEmpty) return null;
    return MemoryBinding(values, refs);
  }
}
