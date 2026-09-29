import '../../core/json.dart';
import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';
import '../cruza/cruza_engine.dart';
import '../socratic/socratic_engine.dart';

/// Resultado de una acción en el taller: nuevo estado y mensaje opcional.
class WorkshopOutcome {
  const WorkshopOutcome(this.state, this.message);
  final UserState state;
  final String? message;
}

/// Máquina de etapas común a las nueve experiencias. Todas las funciones son
/// puras: reciben un estado y devuelven uno nuevo.
class ExperienceEngine {
  ExperienceEngine(this.content, {DateTime Function()? clock, this.socratic = const SocraticEngine(), this.cruza = const CruzaEngine()})
      : clock = clock ?? DateTime.now;

  final ContentBundle content;
  final DateTime Function() clock;
  final SocraticEngine socratic;
  final CruzaEngine cruza;

  ExperienceDef _exp(String id) {
    final e = content.byId[id];
    if (e == null) throw StateError('Experiencia no disponible: $id');
    return e;
  }

  UserState _put(UserState s, ExperienceProgress p) => s.withProgress(p);

  // ------------------------------------------------------------------ inicio
  /// Empieza (o reinicia si estaba omitida) y deja lista la primera etapa.
  UserState start(UserState s, String id) {
    final exp = _exp(id);
    final current = s.progress(id);
    if (current.status == ExpStatus.inProgress || current.status == ExpStatus.completed) return s;
    final fresh = ExperienceProgress(
      experienceId: id,
      status: ExpStatus.inProgress,
      stage: exp.eligeProbe != null ? Stage.probe : Stage.judgment,
      startedAt: clock(),
      contentVersion: content.contentVersion,
    );
    return _put(_withoutNotebookOf(s, id), fresh);
  }

  /// Omite la pregunta y descarta lo parcial (nunca se usa como recuerdo).
  UserState skip(UserState s, String id) {
    final cleaned = _withoutNotebookOf(s, id);
    return _put(cleaned, ExperienceProgress(experienceId: id, status: ExpStatus.skipped));
  }

  UserState _withoutNotebookOf(UserState s, String id) {
    final p = s.progress(id);
    if (p.status == ExpStatus.completed) return s;
    return s.copyWith(notebook: s.notebook.where((n) => n.experienceId != id).toList());
  }

  // ------------------------------------------------------------------ ELIGE
  UserState submitProbe(UserState s, String id, String probeId, Json result) {
    final exp = _exp(id);
    final p = s.progress(id);
    final probe = exp.probe(probeId);
    if (probe == null) return s;
    final next = probe.placement == 'vuelve' ? Stage.rejudge : Stage.judgment;
    return _put(s, p.copyWith(probes: {...p.probes, probeId: result}, stage: next));
  }

  UserState submitJudgment(UserState s, String id, int value) {
    final exp = _exp(id);
    final p = s.progress(id);
    final v = value.clamp(-3, 3).toInt();
    final record = StanceRecord(value: v, left: exp.judgment.left.label, right: exp.judgment.right.label, at: clock());
    if (p.stage == Stage.rejudge) {
      return _put(s, p.copyWith(finalStance: record, stage: Stage.reflection));
    }
    return _put(s, p.copyWith(initialStance: record, stage: Stage.reason));
  }

  // ----------------------------------------------------------------- RAZONA
  static const otherLabel = 'Otra razón';
  static const unknownLabel = 'No sé por qué';

  UserState submitReason(UserState s, String id, String reasonId, {String? otherText}) {
    final exp = _exp(id);
    final p = s.progress(id);
    final def = exp.reason(reasonId);
    final ReasonRecord record;
    if (def != null) {
      record = ReasonRecord(id: def.id, text: def.text, tags: def.tags, at: clock());
    } else if (reasonId == ReasonRecord.otherId) {
      final t = (otherText ?? '').trim();
      record = ReasonRecord(id: ReasonRecord.otherId, text: otherLabel, tags: const [], other: t.isEmpty ? null : t, at: clock());
    } else {
      record = ReasonRecord(id: ReasonRecord.unknownId, text: unknownLabel, tags: const [], at: clock());
    }
    final withReason = _put(s, p.copyWith(reason: record));
    final q = socratic.selectFirst(content, withReason, id);
    if (q != null) {
      return _put(withReason, withReason.progress(id).copyWith(active: q, stage: Stage.question));
    }
    return _enterCruza(withReason, id);
  }

  // ----------------------------------------------------------------- EXAMEN
  /// Respuestas estándar de cada tipo de pregunta.
  static const tensionAnswers = {
    'mantener': 'Mantener',
    'matizar': 'Matizar',
    'revisar': 'Revisar',
    'noAplica': 'Esta pregunta no aplica',
  };
  static const assumptionAnswers = {
    'si': 'Sí, lo creo',
    'noDelTodo': 'No del todo',
    'fundamento': 'Así lo valoro, sin más',
    'noAplica': 'Esta pregunta no aplica',
  };

  String answerLabel(String expId, ActiveQuestion q, String answerId) {
    if (q.kind == QuestionKind.tension) return tensionAnswers[answerId] ?? answerId;
    if (q.kind == QuestionKind.assumption) return assumptionAnswers[answerId] ?? answerId;
    if (answerId == 'noAplica') return 'Esta pregunta no aplica';
    final def = content.byId[expId]?.questionById(q.questionId)?.answer(answerId);
    return def?.label ?? answerId;
  }

  SocraticRecord _record(ActiveQuestion q, String answerId, String label) => SocraticRecord(
        triggerId: q.triggerId,
        questionId: q.questionId,
        kind: q.kind,
        text: q.text,
        refs: q.refs,
        answerId: answerId,
        answerLabel: label,
        followUp: q.followUp,
        at: clock(),
      );

  UserState answerQuestion(UserState s, String id, String answerId) {
    final p = s.progress(id);
    final q = p.active;
    if (q == null) return s;
    final label = answerLabel(id, q, answerId);
    final recorded = p.copyWith(socratic: [...p.socratic, _record(q, answerId, label)], active: null);
    var next = _put(s, recorded);

    if (answerId == 'noAplica') {
      if (q.kind == QuestionKind.tension) {
        return _put(next, recorded.copyWith(stage: Stage.noAplicaWhy));
      }
      return _enterCruza(next, id);
    }

    switch (q.kind) {
      case QuestionKind.tension:
        switch (answerId) {
          case 'mantener':
            final def = _exp(id).questionById(q.questionId);
            final canAsk = recorded.socratic.length < SocraticEngine.maxQuestions && (def?.implication ?? '').isNotEmpty;
            if (canAsk) {
              return _put(next, recorded.copyWith(stage: Stage.implication, pendingDifference: {'question': q.questionId}));
            }
            next = _put(next, recorded.copyWith(tension: TensionOutcome(outcome: TensionOutcomeKind.mantener, at: clock())));
            return _enterCruza(next, id);
          case 'matizar':
            return _put(next, recorded.copyWith(stage: Stage.difference, pendingDifference: null));
          case 'revisar':
            return _put(next, recorded.copyWith(stage: Stage.revisionTarget));
        }
        return _enterCruza(next, id);
      case QuestionKind.assumption:
        if (answerId == 'fundamento') return _put(next, recorded.copyWith(stage: Stage.fundamento));
        final follow = socratic.followUpFor(content, next, id, q, answerId);
        if (follow != null) return _put(next, recorded.copyWith(active: follow, stage: Stage.question));
        return _enterCruza(next, id);
      default:
        final follow = socratic.followUpFor(content, next, id, q, answerId);
        if (follow != null) return _put(next, recorded.copyWith(active: follow, stage: Stage.question));
        return _enterCruza(next, id);
    }
  }

  /// Texto de la pregunta de implicación tras «Mantener».
  String? implicationText(UserState s, String id) {
    final p = s.progress(id);
    final qid = asStringOrNull(p.pendingDifference?['question']) ??
        (p.socratic.isEmpty ? null : p.socratic.last.questionId);
    if (qid == null) return null;
    return _exp(id).questionById(qid)?.implication;
  }

  UserState answerImplication(UserState s, String id, bool accept) {
    final p = s.progress(id);
    final text = implicationText(s, id) ?? '';
    final record = SocraticRecord(
      triggerId: p.socratic.isEmpty ? '' : p.socratic.last.triggerId,
      questionId: 'implication',
      kind: 'implication',
      text: text,
      refs: const [],
      answerId: accept ? 'acepto' : 'noDelTodo',
      answerLabel: accept ? 'Sí, lo acepto' : 'No del todo',
      followUp: true,
      at: clock(),
    );
    final updated = p.copyWith(socratic: [...p.socratic, record], pendingDifference: null);
    if (accept) {
      final next = _put(s, updated.copyWith(tension: TensionOutcome(outcome: TensionOutcomeKind.mantener, at: clock())));
      return _enterCruza(next, id);
    }
    return _put(s, updated.copyWith(stage: Stage.chooseAfterReject));
  }

  UserState chooseAfterReject(UserState s, String id, String choice) {
    final p = s.progress(id);
    if (choice == TensionOutcomeKind.revisar) return _put(s, p.copyWith(stage: Stage.revisionTarget));
    return _put(s, p.copyWith(stage: Stage.difference));
  }

  /// Elige la diferencia al matizar. Si todavía cabe una pregunta, se prueba.
  UserState chooseDifference(UserState s, String id, {String? differenceId, String? otherText}) {
    final p = s.progress(id);
    final pending = <String, dynamic>{'id': differenceId, 'text': (otherText ?? '').trim()};
    final withPending = p.copyWith(pendingDifference: pending);
    final def = differenceId == null ? null : _exp(id).difference(differenceId);
    if (def != null && p.socratic.length < SocraticEngine.maxQuestions) {
      return _put(s, withPending.copyWith(stage: Stage.differenceTest));
    }
    return _finishMatizar(_put(s, withPending), id, firmness: 'sostenida');
  }

  UserState answerDifferenceTest(UserState s, String id, bool holds) {
    final p = s.progress(id);
    final diffId = asStringOrNull(p.pendingDifference?['id']);
    final def = diffId == null ? null : _exp(id).difference(diffId);
    final record = SocraticRecord(
      triggerId: p.socratic.isEmpty ? '' : p.socratic.last.triggerId,
      questionId: 'test:${diffId ?? 'own'}',
      kind: 'test',
      text: def?.test ?? '',
      refs: const [],
      answerId: holds ? 'sostengo' : 'dudo',
      answerLabel: holds ? 'Sí, lo sostengo' : 'No estoy seguro',
      followUp: true,
      at: clock(),
    );
    final next = _put(s, p.copyWith(socratic: [...p.socratic, record]));
    return _finishMatizar(next, id, firmness: holds ? 'sostenida' : 'dudosa');
  }

  UserState _finishMatizar(UserState s, String id, {required String firmness}) {
    final exp = _exp(id);
    final p = s.progress(id);
    final diffId = asStringOrNull(p.pendingDifference?['id']);
    final otherText = asString(p.pendingDifference?['text']);
    final def = diffId == null ? null : exp.difference(diffId);
    final distinction = content.distinction(def?.distinctionId);
    final now = clock();
    final words = def?.text ?? (otherText.isEmpty ? 'Una diferencia propia' : otherText);
    final entry = NotebookEntry(
      id: 'n_${now.microsecondsSinceEpoch}_${s.notebook.length}',
      distinctionId: distinction?.id ?? 'own',
      experienceId: id,
      userWords: words,
      everydayName: distinction?.everydayName ?? '',
      shortExplanation: distinction?.shortExplanation ?? '',
      philosophicalRelation: distinction?.philosophicalRelation ?? '',
      referenceIds: distinction?.referenceIds ?? const [],
      firmness: firmness,
      at: now,
    );
    final tension = TensionOutcome(
      outcome: TensionOutcomeKind.matizar,
      differenceId: def?.id,
      differenceText: words,
      firmness: firmness,
      notebookEntryId: entry.id,
      at: now,
    );
    final withEntry = s.copyWith(notebook: [...s.notebook, entry]);
    return _put(withEntry, p.copyWith(tension: tension, stage: Stage.discovery));
  }

  UserState chooseRevisionTarget(UserState s, String id, String target) {
    final p = s.progress(id);
    final t = target == 'principio' ? 'principio' : 'juicio';
    final next = _put(s, p.copyWith(tension: TensionOutcome(outcome: TensionOutcomeKind.revisar, revisionTarget: t, at: clock())));
    return _enterCruza(next, id);
  }

  UserState submitNoAplica(UserState s, String id, String? text) {
    final p = s.progress(id);
    final t = (text ?? '').trim();
    final next = _put(
        s, p.copyWith(tension: TensionOutcome(outcome: TensionOutcomeKind.noAplica, noAplicaText: t.isEmpty ? null : t, at: clock())));
    return _enterCruza(next, id);
  }

  UserState continueToCruza(UserState s, String id) => _enterCruza(s, id);

  // ------------------------------------------------------------------ CRUZA
  UserState _enterCruza(UserState s, String id) {
    final exp = _exp(id);
    final p = s.progress(id);
    final stance = p.initialStance?.value ?? 0;
    if (stance == 0) {
      return _put(s, p.copyWith(stage: Stage.cruzaSide, active: null, cruza: null));
    }
    final target = stance < 0 ? 'right' : 'left';
    final table = cruza.composeTable(exp, target, p.reason?.id);
    return _put(s, p.copyWith(
      stage: Stage.cruzaAnchor,
      active: null,
      cruza: CruzaRecord(target: target, chosenByUser: false, table: table),
    ));
  }

  UserState chooseCruzaSide(UserState s, String id, String side) {
    final exp = _exp(id);
    final p = s.progress(id);
    final target = side == 'left' ? 'left' : 'right';
    final table = cruza.composeTable(exp, target, p.reason?.id);
    return _put(s, p.copyWith(stage: Stage.cruzaAnchor, cruza: CruzaRecord(target: target, chosenByUser: true, table: table)));
  }

  UserState anchorDone(UserState s, String id) {
    final p = s.progress(id);
    if (p.stage != Stage.cruzaAnchor) return s;
    return _put(s, p.copyWith(stage: Stage.workshop));
  }

  CruzaSideDef targetSide(UserState s, String id) {
    final c = s.progress(id).cruza;
    return _exp(id).cruzaSide(c?.target ?? 'left');
  }

  WorkshopOutcome placePiece(UserState s, String id, String slot, String pieceId) {
    final p = s.progress(id);
    final c = p.cruza;
    if (c == null || !CruzaEngine.slots.contains(slot)) return WorkshopOutcome(s, null);
    final piece = targetSide(s, id).piece(pieceId);
    if (piece == null) return WorkshopOutcome(s, null);
    if (piece.isCaricature) {
      final msg = 'Quien piensa así tampoco lo diría así: ${piece.crack ?? ''}';
      final updated = c.copyWith(
        discarded: c.discarded.contains(pieceId) ? c.discarded : [...c.discarded, pieceId],
        events: [...c.events, CaricatureEvent(pieceId: pieceId, mode: 'placed', at: clock())],
        placement: Map.of(c.placement)..removeWhere((k, v) => v == pieceId),
        note: msg,
      );
      return WorkshopOutcome(_put(s, p.copyWith(cruza: updated)), msg);
    }
    final placement = Map.of(c.placement)..removeWhere((k, v) => v == pieceId);
    placement[slot] = pieceId;
    return WorkshopOutcome(_put(s, p.copyWith(cruza: c.copyWith(placement: placement, note: null))), null);
  }

  UserState removeFromSlot(UserState s, String id, String slot) {
    final p = s.progress(id);
    final c = p.cruza;
    if (c == null) return s;
    final placement = Map.of(c.placement)..remove(slot);
    return _put(s, p.copyWith(cruza: c.copyWith(placement: placement, note: null)));
  }

  static const binValidMessage = 'Esta sí podrían decirla. Vuelve a la mesa.';

  WorkshopOutcome binPiece(UserState s, String id, String pieceId) {
    final p = s.progress(id);
    final c = p.cruza;
    if (c == null) return WorkshopOutcome(s, null);
    final piece = targetSide(s, id).piece(pieceId);
    if (piece == null) return WorkshopOutcome(s, null);
    if (piece.isCaricature) {
      final msg = 'Quien piensa así tampoco lo diría así: ${piece.crack ?? ''}';
      final updated = c.copyWith(
        discarded: c.discarded.contains(pieceId) ? c.discarded : [...c.discarded, pieceId],
        events: [...c.events, CaricatureEvent(pieceId: pieceId, mode: 'binned', at: clock())],
        placement: Map.of(c.placement)..removeWhere((k, v) => v == pieceId),
        note: msg,
      );
      return WorkshopOutcome(_put(s, p.copyWith(cruza: updated)), msg);
    }
    return WorkshopOutcome(_put(s, p.copyWith(cruza: c.copyWith(note: binValidMessage))), binValidMessage);
  }

  UserState submitWorkshop(UserState s, String id) {
    final p = s.progress(id);
    final c = p.cruza;
    if (c == null || !cruza.canSubmit(c.placement)) return s;
    final result = cruza.evaluate(targetSide(s, id), c.placement);
    final attempt = CruzaAttempt(placement: Map.of(c.placement), state: result.state, missing: result.missing, at: clock());
    return _put(s, p.copyWith(
      stage: Stage.recognition,
      cruza: c.copyWith(attempts: [...c.attempts, attempt], finalRecognition: result.state, note: null),
    ));
  }

  UserState retryWorkshop(UserState s, String id) {
    final p = s.progress(id);
    return _put(s, p.copyWith(stage: Stage.workshop));
  }

  UserState continueFromRecognition(UserState s, String id) {
    final p = s.progress(id);
    return _put(s, p.copyWith(stage: Stage.strength));
  }

  UserState submitStrength(UserState s, String id, int strength, int agreement) {
    final p = s.progress(id);
    final c = p.cruza;
    if (c == null) return s;
    return _put(s, p.copyWith(
      stage: Stage.twist,
      cruza: c.copyWith(strength: strength.clamp(1, 5).toInt(), agreement: agreement.clamp(1, 5).toInt(), completedAt: clock()),
    ));
  }

  // ----------------------------------------------------------------- VUELVE
  UserState continueTwist(UserState s, String id) {
    final p = s.progress(id);
    return _put(s, p.copyWith(stage: Stage.rejudge));
  }

  UserState finish(UserState s, String id) {
    final p = s.progress(id);
    if (p.finalStance == null) return s;
    return _put(s, p.copyWith(status: ExpStatus.completed, stage: Stage.done, completedAt: clock(), active: null));
  }

  // ------------------------------------------------------------ onboarding
  UserState completeOnboarding(UserState s, int value) {
    final record = StanceRecord(value: value.clamp(-3, 3).toInt(), left: 'No', right: 'Sí', at: clock());
    return s.copyWith(onboarding: OnboardingRecord(stance: record, completedAt: clock()));
  }

  // ----------------------------------------------------------------- notas
  UserState saveNote(UserState s, String key, String text) {
    final notes = Map.of(s.notes);
    final t = text.trim();
    if (t.isEmpty) {
      notes.remove(key);
    } else {
      notes[key] = t.length > 280 ? t.substring(0, 280) : t;
    }
    return s.copyWith(notes: notes);
  }
}
