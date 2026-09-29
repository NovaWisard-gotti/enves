import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';
import '../memory/memory_engine.dart';
import '../rules/rules.dart';

/// Selecciona y redacta preguntas socráticas a partir de reglas escritas en
/// el contenido. No usa IA: el mismo estado produce siempre la misma pregunta.
class SocraticEngine {
  const SocraticEngine({this.memory = const MemoryEngine()});

  static const maxQuestions = 2;

  final MemoryEngine memory;

  /// Primera pregunta aplicable, o `null` si ninguna aplica.
  ActiveQuestion? selectFirst(ContentBundle content, UserState state, String expId) {
    final exp = content.byId[expId];
    if (exp == null) return null;
    final facts = FactResolver(content, state, expId);
    final evaluator = ConditionEvaluator(facts.call);
    final triggers = [...exp.triggers]..sort((a, b) => a.priority.compareTo(b.priority));
    for (final t in triggers) {
      if (!evaluator.eval(t.condition)) continue;
      final q = exp.questionById(t.questionId);
      if (q == null) continue;
      final rendered = render(content, state, expId, q, triggerId: t.id, memorySpec: t.memory, followUp: false);
      if (rendered != null) return rendered;
    }
    return null;
  }

  /// Redacta una pregunta. Devuelve `null` si falta algún dato: nunca se
  /// muestra un recuerdo incompleto ni sin registro de origen.
  ActiveQuestion? render(
    ContentBundle content,
    UserState state,
    String expId,
    QuestionDef q, {
    required String triggerId,
    required MemorySpec? memorySpec,
    required bool followUp,
    Map<String, String> extra = const {},
  }) {
    final facts = FactResolver(content, state, expId);
    final p = state.progress(expId);
    final values = <String, String>{...extra};
    final reason = p.reason;
    if (reason != null && reason.isQuotable && reason.text.isNotEmpty) values['esta_razon'] = reason.text;
    final stance = p.initialStance;
    if (stance != null) values['esta_postura'] = stance.label;

    MemoryBinding? binding;
    if (memorySpec != null) {
      binding = memory.bind(content, state, expId, memorySpec);
      if (binding == null) return null;
      values.addAll(binding.values);
    }
    final text = TemplateRenderer.render(q.text, values, facts.call);
    if (text == null) return null;

    final used = TemplateRenderer.keys(q.text);
    final refs = binding == null ? <RecordRef>[] : binding.refsFor(used);
    final usesMemory = used.any(MemoryEngine.memoryKeys.contains);
    if (usesMemory && refs.isEmpty) return null;
    if (!followUp && memorySpec != null && !usesMemory) return null;

    return ActiveQuestion(
      triggerId: triggerId,
      questionId: q.id,
      kind: q.kind,
      text: text,
      refs: refs,
      followUp: followUp,
      memory: memorySpec,
    );
  }

  /// Pregunta de seguimiento tras una respuesta, si corresponde.
  ActiveQuestion? followUpFor(
    ContentBundle content,
    UserState state,
    String expId,
    ActiveQuestion answered,
    String answerId,
  ) {
    final exp = content.byId[expId];
    if (exp == null) return null;
    final p = state.progress(expId);
    if (p.socratic.length >= maxQuestions) return null;
    final q = exp.questionById(answered.questionId);
    if (q == null) return null;

    String? nextId;
    String answerLabel = '';
    if (q.kind == QuestionKind.assumption) {
      if (answerId == 'noDelTodo') nextId = q.followUp;
    } else {
      final a = q.answer(answerId);
      if (a == null) return null;
      answerLabel = a.label;
      if (a.next != null) {
        final evaluator = ConditionEvaluator(FactResolver(content, state, expId).call);
        if (evaluator.eval(a.nextCondition)) nextId = a.next;
      }
    }
    if (nextId == null) return null;
    final next = exp.questionById(nextId);
    if (next == null) return null;
    return render(
      content,
      state,
      expId,
      next,
      triggerId: answered.triggerId,
      memorySpec: answered.memory,
      followUp: true,
      extra: {if (answerLabel.isNotEmpty) 'respuesta': answerLabel},
    );
  }
}
