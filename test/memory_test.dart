import 'package:enves/domain/content/content_models.dart';
import 'package:enves/domain/records/records.dart';
import 'package:enves/engine/experience/experience_engine.dart';
import 'package:enves/engine/memory/memory_engine.dart';
import 'package:enves/engine/socratic/socratic_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const e1 = 'e1_mismo_descuido';
const e5 = 'e5_cien_becas';

void main() {
  late ContentBundle c;
  late ExperienceEngine engine;
  setUp(() async {
    c = await loadContent();
    engine = ExperienceEngine(c, clock: fakeClock());
  });

  test('sin registros, la memoria nunca inventa', () {
    final s = UserState.empty();
    expect(const MemoryEngine().bind(c, s, e5, const MemorySpec(source: e1)), isNull);
  });

  test('una experiencia en curso u omitida no alimenta recuerdos', () {
    var s = engine.start(UserState.empty(), e1);
    s = engine.submitProbe(s, e1, 'e1_gemelos', {'ana': 2, 'beto': 3, 'diff': 1});
    s = engine.submitJudgment(s, e1, -2);
    s = engine.submitReason(s, e1, 'e1_r_decision');
    expect(const MemoryEngine().bind(c, s, e5, const MemorySpec(source: e1)), isNull);
    s = engine.skip(s, e1);
    expect(const MemoryEngine().bind(c, s, e5, const MemorySpec(source: e1)), isNull);
  });

  test('la cita es literal y rastreable', () {
    final s = walk(engine, UserState.empty(), e1, stance: -2, reasonId: 'e1_r_decision');
    final b = const MemoryEngine().bind(c, s, e5, const MemorySpec(source: e1))!;
    final text = c.byId[e1]!.reason('e1_r_decision')!.text;
    expect(b.values['razon'], text);
    expect(b.refs['razon']!.quote, text);
    expect(b.refs['razon']!.experienceId, e1);
    expect(b.values['titulo'], c.byId[e1]!.title);
  });

  test('«No sé por qué» y «Otra razón» nunca se citan como razón', () {
    final s = walk(engine, UserState.empty(), e1, stance: -2, reasonId: 'unknown');
    final b = const MemoryEngine().bind(c, s, e5, const MemorySpec(source: e1));
    expect(b?.values['razon'], isNull);
  });

  test('un principio revisado no se usa como recuerdo', () {
    var s = walk(engine, UserState.empty(), e1, stance: -2, reasonId: 'e1_r_decision');
    final p = s.progress(e1);
    s = s.withProgress(p.copyWith(
      tension: TensionOutcome(outcome: TensionOutcomeKind.revisar, revisionTarget: 'principio', at: DateTime(2026)),
    ));
    expect(const MemoryEngine().bind(c, s, e5, const MemorySpec(source: e1)), isNull);
  });

  test('tras borrar el historial no queda nada que recordar', () {
    walk(engine, UserState.empty(), e1, stance: -2, reasonId: 'e1_r_decision');
    final wiped = UserState.empty();
    expect(const MemoryEngine().bind(c, wiped, e5, const MemorySpec(source: e1)), isNull);
    expect(const MemoryEngine().bind(c, wiped, e5, const MemorySpec(source: 'onboarding')), isNull);
  });

  test('Cien becas recupera una decisión real de El mismo descuido', () {
    var s = walk(engine, UserState.empty(), e1, stance: -2, reasonId: 'e1_r_decision');
    final quote = c.byId[e1]!.reason('e1_r_decision')!.text;
    ActiveQuestion? first;
    s = walk(engine, s, e5, stance: 1, reasonId: 'e5_r_costo', onQuestion: (p) => first ??= p.active);
    expect(first, isNotNull);
    expect(first!.text, contains('«$quote»'));
    expect(first!.refs.single.experienceId, e1);
    expect(s.progress(e5).socratic.first.refs.single.quote, quote);
  });

  test('las reglas de memoria de Cien becas cubren cualquier razón de E1', () {
    for (final r in c.byId[e1]!.reasons) {
      final s = walk(ExperienceEngine(c, clock: fakeClock()), UserState.empty(), e1, stance: 1, reasonId: r.id);
      var s5 = engine.start(s, e5);
      s5 = engine.submitProbe(s5, e5, 'e5_simulador', defaultProbeResult(c.byId[e5]!.eligeProbe!));
      s5 = engine.submitJudgment(s5, e5, 1);
      s5 = engine.submitReason(s5, e5, 'e5_r_costo');
      final q = s5.progress(e5).active;
      expect(q, isNotNull, reason: r.id);
      expect(q!.refs, isNotEmpty, reason: r.id);
    }
  });

  test('el motor socrático es determinista y hace como máximo dos preguntas', () {
    for (final e in c.experiences) {
      var a = UserState.empty();
      var b = UserState.empty();
      a = walk(ExperienceEngine(c, clock: fakeClock()), a, e.id, stance: 2, reasonId: e.reasons.first.id);
      b = walk(ExperienceEngine(c, clock: fakeClock()), b, e.id, stance: 2, reasonId: e.reasons.first.id);
      final qa = a.progress(e.id).socratic.map((r) => r.text).toList();
      final qb = b.progress(e.id).socratic.map((r) => r.text).toList();
      expect(qa, qb, reason: e.id);
      final asked = a.progress(e.id).socratic.where((r) => r.kind != 'implication' && r.kind != 'test').length;
      expect(asked, lessThanOrEqualTo(SocraticEngine.maxQuestions), reason: e.id);
    }
  });
}
