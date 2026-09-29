import '../domain/content/content_models.dart';

class ValidationReport {
  ValidationReport(this.byExperience, this.global);
  final Map<String, List<String>> byExperience;
  final List<String> global;

  Set<String> get brokenExperiences =>
      byExperience.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toSet();

  List<String> get issues => [
        ...global,
        for (final e in byExperience.entries)
          for (final i in e.value) '${e.key}: $i',
      ];

  bool get isValid => issues.isEmpty;
}

/// Comprueba la integridad del contenido. Un fallo en una experiencia solo
/// la deja no disponible; nunca bloquea la app completa.
class ContentValidator {
  const ContentValidator();

  static const slots = ['S1', 'S2', 'S3', 'S4'];
  static const memoryKeys = {'titulo', 'razon', 'postura', 'seguridad', 'n', 'k'};
  static const allowedKeys = {...memoryKeys, 'esta_razon', 'esta_postura', 'respuesta'};

  /// Marcadores de trabajo inconcluso. Distingue mayúsculas para no confundir
  /// la palabra española «todo» con el marcador TODO.
  static final RegExp placeholder =
      RegExp(r'\b(TODO|FIXME|TBD|XXX)\b|\b[Ll]orem\b|\b[Ii]psum\b|\b[Pp]laceholder\b');

  /// Palabras que el motor socrático nunca debe usar.
  static final RegExp forbidden = RegExp(
      r'\b(contradicci[oó]n|contradictori[oa]|error|incorrect[oa]|equivocad[oa]|incoherente|ganaste|perdiste)\b',
      caseSensitive: false);

  static final RegExp _keys = RegExp(r'\{([a-z_]+)\}');

  ValidationReport validate(ContentBundle c) {
    final global = <String>[];
    final refIds = c.references.map((r) => r.id).toSet();
    final distIds = c.distinctions.map((d) => d.id).toSet();
    final axisIds = c.axes.map((a) => a.id).toSet();
    final expIds = c.catalog.map((e) => e.id).toSet();

    if (c.common.slots.length != 4) global.add('CRUZA debe tener 4 ranuras');
    for (final d in c.distinctions) {
      for (final r in d.referenceIds) {
        if (!refIds.contains(r)) global.add('${d.id}: referencia inexistente $r');
      }
    }

    final byExp = <String, List<String>>{};
    for (final e in c.experiences) {
      final out = <String>[];
      byExp[e.id] = out;
      final qIds = e.questions.map((q) => q.id).toSet();
      final probeIds = e.probes.map((p) => p.id).toSet();
      final reasonIds = e.reasons.map((r) => r.id).toSet();

      if (e.title.isEmpty || e.question.isEmpty) out.add('sin título o pregunta');
      if (e.reasons.length < 2) out.add('razones insuficientes');
      if (e.reflection.isEmpty) out.add('sin reflexión');
      if (e.twist.text.isEmpty) out.add('sin giro');
      for (final t in _texts(e)) {
        if (placeholder.hasMatch(t)) out.add('texto provisional: $t');
      }
      if (!e.triggers.any((t) => t.memory == null)) {
        out.add('sin disparador independiente de la memoria');
      }
      for (final t in e.triggers) {
        if (!qIds.contains(t.questionId)) out.add('disparador ${t.id} sin pregunta');
        for (final f in t.condition.facts) {
          final head = f.split('.').first;
          if (!{'this', 'onboarding', 'hollow'}.contains(head) && !expIds.contains(head)) {
            out.add('hecho desconocido $f');
          }
        }
        if (t.memory != null) {
          final q = e.questionById(t.questionId);
          final keys = q == null ? <String>{} : _keys.allMatches(q.text).map((m) => m.group(1)!).toSet();
          if (keys.intersection(memoryKeys).isEmpty) out.add('recuerdo sin cita: ${t.id}');
          final src = t.memory!.source;
          if (src != 'onboarding' && src != 'hollow' && !expIds.contains(src)) {
            out.add('fuente de memoria desconocida $src');
          }
        }
      }
      for (final q in e.questions) {
        if (forbidden.hasMatch(q.text) || forbidden.hasMatch(q.implication ?? '')) {
          out.add('lenguaje no permitido en ${q.id}');
        }
        for (final m in _keys.allMatches(q.text)) {
          if (!allowedKeys.contains(m.group(1))) out.add('marcador ${m.group(1)} en ${q.id}');
        }
        if (q.kind == QuestionKind.tension && (q.implication ?? '').isEmpty) {
          out.add('tensión sin implicación ${q.id}');
        }
        if (q.followUp != null && !qIds.contains(q.followUp)) out.add('followUp inexistente ${q.followUp}');
        for (final a in q.answers) {
          if (a.next != null && !qIds.contains(a.next)) out.add('next inexistente ${a.next}');
          if (a.map != null && !axisIds.contains(a.map!.axis)) out.add('eje inexistente ${a.map!.axis}');
        }
      }
      for (final d in e.differences) {
        if (d.distinctionId != null && !distIds.contains(d.distinctionId)) {
          out.add('distinción inexistente ${d.distinctionId}');
        }
        if (d.test.isEmpty) out.add('diferencia sin prueba ${d.id}');
      }
      for (final side in ['left', 'right']) {
        final s = e.cruzaSide(side);
        for (final slot in slots) {
          if (!s.pieces.any((p) => p.isValid && p.slots.contains(slot))) out.add('CRUZA $side: $slot vacía');
        }
        if (s.pieces.where((p) => p.isCaricature).length < 3) out.add('CRUZA $side: faltan caricaturas');
        if (s.pieces.any((p) => p.isCaricature && (p.crack ?? '').isEmpty)) {
          out.add('CRUZA $side: caricatura sin explicación');
        }
        if (!s.pieces.any((p) => p.isOwnSide)) out.add('CRUZA $side: sin pieza del propio lado');
        if (!s.pieces.any((p) => p.generic)) out.add('CRUZA $side: sin respuesta genérica');
        if (s.voices.length != 3) out.add('CRUZA $side: se necesitan 3 perspectivas');
        for (final v in s.voices) {
          for (final state in const ['noRepresenta', 'parcial', 'reconocible', 'fuerte']) {
            if ((v.reactions[state] ?? '').isEmpty) out.add('perspectiva ${v.id} sin $state');
          }
        }
        for (final p in s.pieces) {
          for (final r in p.respondsTo) {
            if (!reasonIds.contains(r)) out.add('pieza ${p.id} responde a razón inexistente $r');
          }
        }
      }
      for (final m in e.map) {
        if (!axisIds.contains(m.axis)) out.add('eje inexistente ${m.axis}');
        if (m.source == 'probe' && !probeIds.contains(m.probeId)) out.add('mecánica inexistente ${m.probeId}');
      }
      if (e.twist.probeId != null && !probeIds.contains(e.twist.probeId)) out.add('giro sin mecánica');
      for (final r in e.deepDive.referenceIds) {
        if (!refIds.contains(r)) out.add('referencia inexistente $r');
      }
    }
    for (final entry in c.catalog) {
      if (!c.byId.containsKey(entry.id)) byExp[entry.id] = ['no se pudo leer'];
    }
    return ValidationReport(byExp, global);
  }

  Iterable<String> _texts(ExperienceDef e) sync* {
    yield e.title;
    yield e.question;
    yield* e.scenario.paragraphs;
    for (final t in e.scenario.twin) {
      yield* t.lines;
    }
    for (final r in e.reasons) {
      yield r.text;
    }
    for (final q in e.questions) {
      yield q.text;
      if (q.implication != null) yield q.implication!;
      for (final a in q.answers) {
        yield a.label;
      }
    }
    for (final d in e.differences) {
      yield d.text;
      yield d.test;
    }
    for (final side in ['left', 'right']) {
      final s = e.cruzaSide(side);
      for (final p in s.pieces) {
        yield p.text;
        if (p.crack != null) yield p.crack!;
      }
      for (final v in s.voices) {
        yield v.descriptor;
        yield* v.reactions.values;
      }
    }
    yield e.twist.text;
    yield e.reflection;
  }
}
