import '../../core/json.dart';
import '../content/content_models.dart';

const Object _unset = Object();

/// Versión del esquema del archivo state.json.
const int kSchemaVersion = 1;

enum ExpStatus { notStarted, inProgress, completed, skipped }

ExpStatus expStatusFrom(Object? v) {
  final s = asString(v);
  for (final e in ExpStatus.values) {
    if (e.name == s) return e;
  }
  return ExpStatus.notStarted;
}

/// Etiqueta de seguridad sin marca de género.
String confidenceLabelFor(int value) {
  switch (value.abs()) {
    case 0:
      return 'sin inclinarme';
    case 1:
      return 'me inclino';
    case 2:
      return 'con bastante seguridad';
    default:
      return 'con mucha seguridad';
  }
}

/// Postura en la balanza: −3…−1 izquierda, 0 «No lo sé», 1…3 derecha.
class StanceRecord {
  const StanceRecord({required this.value, required this.left, required this.right, required this.at});
  final int value;
  final String left;
  final String right;
  final DateTime at;

  static const unknownLabel = 'No lo sé';

  String get label => value == 0 ? unknownLabel : (value < 0 ? left : right);
  String get confidence => confidenceLabelFor(value);
  String? get side => value == 0 ? null : (value < 0 ? 'left' : 'right');

  Json toJson() => {'value': value, 'left': left, 'right': right, 'at': dateToJson(at)};

  static StanceRecord? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null || !m.containsKey('value')) return null;
    return StanceRecord(
      value: asInt(m['value']).clamp(-3, 3).toInt(),
      left: asString(m['left']),
      right: asString(m['right']),
      at: asDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ReasonRecord {
  const ReasonRecord({required this.id, required this.text, required this.tags, required this.at, this.other});
  final String id;
  final String text;
  final List<String> tags;
  final String? other;
  final DateTime at;

  static const otherId = 'other';
  static const unknownId = 'unknown';

  /// «Otra razón» y «No sé por qué» nunca se citan como razón.
  bool get isQuotable => id != otherId && id != unknownId;

  Json toJson() => {'id': id, 'text': text, 'tags': tags, 'other': other, 'at': dateToJson(at)};

  static ReasonRecord? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null || asString(m['id']).isEmpty) return null;
    return ReasonRecord(
      id: asString(m['id']),
      text: asString(m['text']),
      tags: asStringList(m['tags']),
      other: asStringOrNull(m['other']),
      at: asDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Referencia rastreable a un registro real del usuario.
class RecordRef {
  const RecordRef({required this.experienceId, required this.field, required this.at, required this.quote});
  final String experienceId;
  final String field;
  final DateTime at;
  final String quote;

  String get key => '$experienceId/$field';

  Json toJson() => {'exp': experienceId, 'field': field, 'at': dateToJson(at), 'quote': quote};

  static RecordRef? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null) return null;
    return RecordRef(
      experienceId: asString(m['exp']),
      field: asString(m['field']),
      at: asDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      quote: asString(m['quote']),
    );
  }
}

List<RecordRef> _refs(Object? json) =>
    (json is List ? json : const []).map(RecordRef.fromJson).whereType<RecordRef>().toList();

class ActiveQuestion {
  const ActiveQuestion({
    required this.triggerId,
    required this.questionId,
    required this.kind,
    required this.text,
    required this.refs,
    required this.followUp,
    this.memory,
  });
  final String triggerId;
  final String questionId;
  final String kind;
  final String text;
  final List<RecordRef> refs;
  final bool followUp;
  final MemorySpec? memory;

  Json toJson() => {
        'trigger': triggerId,
        'question': questionId,
        'kind': kind,
        'text': text,
        'refs': refs.map((r) => r.toJson()).toList(),
        'followUp': followUp,
        'memory': memory?.toJson(),
      };

  static ActiveQuestion? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null || asString(m['question']).isEmpty) return null;
    return ActiveQuestion(
      triggerId: asString(m['trigger']),
      questionId: asString(m['question']),
      kind: asString(m['kind']),
      text: asString(m['text']),
      refs: _refs(m['refs']),
      followUp: asBool(m['followUp']),
      memory: MemorySpec.fromJson(m['memory']),
    );
  }
}

class SocraticRecord {
  const SocraticRecord({
    required this.triggerId,
    required this.questionId,
    required this.kind,
    required this.text,
    required this.refs,
    required this.answerId,
    required this.answerLabel,
    required this.followUp,
    required this.at,
  });
  final String triggerId;
  final String questionId;
  final String kind;
  final String text;
  final List<RecordRef> refs;
  final String answerId;
  final String answerLabel;
  final bool followUp;
  final DateTime at;

  Json toJson() => {
        'trigger': triggerId,
        'question': questionId,
        'kind': kind,
        'text': text,
        'refs': refs.map((r) => r.toJson()).toList(),
        'answer': answerId,
        'answerLabel': answerLabel,
        'followUp': followUp,
        'at': dateToJson(at),
      };

  static SocraticRecord? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null) return null;
    return SocraticRecord(
      triggerId: asString(m['trigger']),
      questionId: asString(m['question']),
      kind: asString(m['kind']),
      text: asString(m['text']),
      refs: _refs(m['refs']),
      answerId: asString(m['answer']),
      answerLabel: asString(m['answerLabel']),
      followUp: asBool(m['followUp']),
      at: asDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

abstract final class TensionOutcomeKind {
  static const mantener = 'mantener';
  static const matizar = 'matizar';
  static const revisar = 'revisar';
  static const noAplica = 'noAplica';
}

class TensionOutcome {
  const TensionOutcome({
    required this.outcome,
    required this.at,
    this.differenceId,
    this.differenceText,
    this.firmness,
    this.notebookEntryId,
    this.revisionTarget,
    this.noAplicaText,
  });
  final String outcome;
  final String? differenceId;
  final String? differenceText;
  final String? firmness;
  final String? notebookEntryId;
  final String? revisionTarget;
  final String? noAplicaText;
  final DateTime at;

  bool get revisedPrinciple => outcome == TensionOutcomeKind.revisar && revisionTarget == 'principio';

  Json toJson() => {
        'outcome': outcome,
        'difference': differenceId,
        'differenceText': differenceText,
        'firmness': firmness,
        'notebookEntry': notebookEntryId,
        'revisionTarget': revisionTarget,
        'noAplicaText': noAplicaText,
        'at': dateToJson(at),
      };

  static TensionOutcome? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null || asString(m['outcome']).isEmpty) return null;
    return TensionOutcome(
      outcome: asString(m['outcome']),
      differenceId: asStringOrNull(m['difference']),
      differenceText: asStringOrNull(m['differenceText']),
      firmness: asStringOrNull(m['firmness']),
      notebookEntryId: asStringOrNull(m['notebookEntry']),
      revisionTarget: asStringOrNull(m['revisionTarget']),
      noAplicaText: asStringOrNull(m['noAplicaText']),
      at: asDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

abstract final class Recognition {
  static const noRepresenta = 'noRepresenta';
  static const parcial = 'parcial';
  static const reconocible = 'reconocible';
  static const fuerte = 'fuerte';

  static bool isRecognized(String? s) => s == reconocible || s == fuerte;
}

class CaricatureEvent {
  const CaricatureEvent({required this.pieceId, required this.mode, required this.at});
  final String pieceId;
  final String mode; // placed | binned
  final DateTime at;

  Json toJson() => {'piece': pieceId, 'mode': mode, 'at': dateToJson(at)};

  static CaricatureEvent? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null) return null;
    return CaricatureEvent(
      pieceId: asString(m['piece']),
      mode: asString(m['mode']),
      at: asDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CruzaAttempt {
  const CruzaAttempt({required this.placement, required this.state, required this.missing, required this.at});
  final Map<String, String> placement;
  final String state;
  final List<String> missing;
  final DateTime at;

  Json toJson() => {'placement': placement, 'state': state, 'missing': missing, 'at': dateToJson(at)};

  static CruzaAttempt? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null) return null;
    return CruzaAttempt(
      placement: asStringMap(m['placement']),
      state: asString(m['state']),
      missing: asStringList(m['missing']),
      at: asDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CruzaRecord {
  const CruzaRecord({
    required this.target,
    required this.chosenByUser,
    this.table = const [],
    this.placement = const {},
    this.discarded = const [],
    this.events = const [],
    this.note,
    this.attempts = const [],
    this.finalRecognition,
    this.strength,
    this.agreement,
    this.completedAt,
  });
  final String target;
  final bool chosenByUser;
  final List<String> table;
  final Map<String, String> placement;
  final List<String> discarded;
  final List<CaricatureEvent> events;
  final String? note;
  final List<CruzaAttempt> attempts;
  final String? finalRecognition;
  final int? strength;
  final int? agreement;
  final DateTime? completedAt;

  bool get isComplete => completedAt != null && finalRecognition != null;

  CruzaRecord copyWith({
    List<String>? table,
    Map<String, String>? placement,
    List<String>? discarded,
    List<CaricatureEvent>? events,
    Object? note = _unset,
    List<CruzaAttempt>? attempts,
    Object? finalRecognition = _unset,
    Object? strength = _unset,
    Object? agreement = _unset,
    Object? completedAt = _unset,
  }) =>
      CruzaRecord(
        target: target,
        chosenByUser: chosenByUser,
        table: table ?? this.table,
        placement: placement ?? this.placement,
        discarded: discarded ?? this.discarded,
        events: events ?? this.events,
        note: identical(note, _unset) ? this.note : note as String?,
        attempts: attempts ?? this.attempts,
        finalRecognition:
            identical(finalRecognition, _unset) ? this.finalRecognition : finalRecognition as String?,
        strength: identical(strength, _unset) ? this.strength : strength as int?,
        agreement: identical(agreement, _unset) ? this.agreement : agreement as int?,
        completedAt: identical(completedAt, _unset) ? this.completedAt : completedAt as DateTime?,
      );

  Json toJson() => {
        'target': target,
        'chosen': chosenByUser,
        'table': table,
        'placement': placement,
        'discarded': discarded,
        'events': events.map((e) => e.toJson()).toList(),
        'note': note,
        'attempts': attempts.map((a) => a.toJson()).toList(),
        'final': finalRecognition,
        'strength': strength,
        'agreement': agreement,
        'completedAt': dateToJson(completedAt),
      };

  static CruzaRecord? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null) return null;
    final target = asString(m['target']);
    if (target != 'left' && target != 'right') return null;
    return CruzaRecord(
      target: target,
      chosenByUser: asBool(m['chosen']),
      table: asStringList(m['table']),
      placement: asStringMap(m['placement']),
      discarded: asStringList(m['discarded']),
      events: (m['events'] is List ? m['events'] as List : const [])
          .map(CaricatureEvent.fromJson)
          .whereType<CaricatureEvent>()
          .toList(),
      note: asStringOrNull(m['note']),
      attempts: (m['attempts'] is List ? m['attempts'] as List : const [])
          .map(CruzaAttempt.fromJson)
          .whereType<CruzaAttempt>()
          .toList(),
      finalRecognition: asStringOrNull(m['final']),
      strength: asIntOrNull(m['strength']),
      agreement: asIntOrNull(m['agreement']),
      completedAt: asDate(m['completedAt']),
    );
  }
}

/// Etapas de una experiencia.
abstract final class Stage {
  static const intro = 'intro';
  static const probe = 'probe';
  static const judgment = 'judgment';
  static const reason = 'reason';
  static const question = 'question';
  static const implication = 'implication';
  static const chooseAfterReject = 'chooseAfterReject';
  static const difference = 'difference';
  static const differenceTest = 'differenceTest';
  static const revisionTarget = 'revisionTarget';
  static const noAplicaWhy = 'noAplicaWhy';
  static const fundamento = 'fundamento';
  static const discovery = 'discovery';
  static const cruzaSide = 'cruzaSide';
  static const cruzaAnchor = 'cruzaAnchor';
  static const workshop = 'workshop';
  static const recognition = 'recognition';
  static const strength = 'strength';
  static const twist = 'twist';
  static const rejudge = 'rejudge';
  static const reflection = 'reflection';
  static const done = 'done';
}

class ExperienceProgress {
  const ExperienceProgress({
    required this.experienceId,
    this.status = ExpStatus.notStarted,
    this.stage = Stage.intro,
    this.startedAt,
    this.completedAt,
    this.contentVersion = '',
    this.probes = const {},
    this.initialStance,
    this.reason,
    this.socratic = const [],
    this.active,
    this.tension,
    this.pendingDifference,
    this.cruza,
    this.finalStance,
  });

  final String experienceId;
  final ExpStatus status;
  final String stage;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String contentVersion;
  final Map<String, Json> probes;
  final StanceRecord? initialStance;
  final ReasonRecord? reason;
  final List<SocraticRecord> socratic;
  final ActiveQuestion? active;
  final TensionOutcome? tension;
  final Json? pendingDifference;
  final CruzaRecord? cruza;
  final StanceRecord? finalStance;

  bool get isCompleted => status == ExpStatus.completed;

  ExperienceProgress copyWith({
    ExpStatus? status,
    String? stage,
    Object? startedAt = _unset,
    Object? completedAt = _unset,
    String? contentVersion,
    Map<String, Json>? probes,
    Object? initialStance = _unset,
    Object? reason = _unset,
    List<SocraticRecord>? socratic,
    Object? active = _unset,
    Object? tension = _unset,
    Object? pendingDifference = _unset,
    Object? cruza = _unset,
    Object? finalStance = _unset,
  }) =>
      ExperienceProgress(
        experienceId: experienceId,
        status: status ?? this.status,
        stage: stage ?? this.stage,
        startedAt: identical(startedAt, _unset) ? this.startedAt : startedAt as DateTime?,
        completedAt: identical(completedAt, _unset) ? this.completedAt : completedAt as DateTime?,
        contentVersion: contentVersion ?? this.contentVersion,
        probes: probes ?? this.probes,
        initialStance: identical(initialStance, _unset) ? this.initialStance : initialStance as StanceRecord?,
        reason: identical(reason, _unset) ? this.reason : reason as ReasonRecord?,
        socratic: socratic ?? this.socratic,
        active: identical(active, _unset) ? this.active : active as ActiveQuestion?,
        tension: identical(tension, _unset) ? this.tension : tension as TensionOutcome?,
        pendingDifference:
            identical(pendingDifference, _unset) ? this.pendingDifference : pendingDifference as Json?,
        cruza: identical(cruza, _unset) ? this.cruza : cruza as CruzaRecord?,
        finalStance: identical(finalStance, _unset) ? this.finalStance : finalStance as StanceRecord?,
      );

  Json toJson() => {
        'id': experienceId,
        'status': status.name,
        'stage': stage,
        'startedAt': dateToJson(startedAt),
        'completedAt': dateToJson(completedAt),
        'contentVersion': contentVersion,
        'probes': probes,
        'initialStance': initialStance?.toJson(),
        'reason': reason?.toJson(),
        'socratic': socratic.map((s) => s.toJson()).toList(),
        'active': active?.toJson(),
        'tension': tension?.toJson(),
        'pendingDifference': pendingDifference,
        'cruza': cruza?.toJson(),
        'finalStance': finalStance?.toJson(),
      };

  static ExperienceProgress? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null || asString(m['id']).isEmpty) return null;
    final probes = <String, Json>{};
    asJson(m['probes']).forEach((k, v) => probes[k] = asJson(v));
    return ExperienceProgress(
      experienceId: asString(m['id']),
      status: expStatusFrom(m['status']),
      stage: asString(m['stage'], Stage.intro),
      startedAt: asDate(m['startedAt']),
      completedAt: asDate(m['completedAt']),
      contentVersion: asString(m['contentVersion']),
      probes: probes,
      initialStance: StanceRecord.fromJson(m['initialStance']),
      reason: ReasonRecord.fromJson(m['reason']),
      socratic: (m['socratic'] is List ? m['socratic'] as List : const [])
          .map(SocraticRecord.fromJson)
          .whereType<SocraticRecord>()
          .toList(),
      active: ActiveQuestion.fromJson(m['active']),
      tension: TensionOutcome.fromJson(m['tension']),
      pendingDifference: asJsonOrNull(m['pendingDifference']),
      cruza: CruzaRecord.fromJson(m['cruza']),
      finalStance: StanceRecord.fromJson(m['finalStance']),
    );
  }
}

class OnboardingRecord {
  const OnboardingRecord({required this.stance, required this.completedAt});
  final StanceRecord stance;
  final DateTime completedAt;

  Json toJson() => {'stance': stance.toJson(), 'completedAt': dateToJson(completedAt)};

  static OnboardingRecord? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null) return null;
    final stance = StanceRecord.fromJson(m['stance']);
    if (stance == null) return null;
    return OnboardingRecord(stance: stance, completedAt: asDate(m['completedAt']) ?? stance.at);
  }
}

class NotebookEntry {
  const NotebookEntry({
    required this.id,
    required this.distinctionId,
    required this.experienceId,
    required this.userWords,
    required this.everydayName,
    required this.shortExplanation,
    required this.philosophicalRelation,
    required this.referenceIds,
    required this.firmness,
    required this.at,
  });
  final String id;
  final String distinctionId; // 'own' para diferencias propias
  final String experienceId;
  final String userWords;
  final String everydayName;
  final String shortExplanation;
  final String philosophicalRelation;
  final List<String> referenceIds;
  final String firmness; // sostenida | dudosa
  final DateTime at;

  bool get isOwn => distinctionId == 'own';

  Json toJson() => {
        'id': id,
        'distinctionId': distinctionId,
        'experienceId': experienceId,
        'userWords': userWords,
        'everydayName': everydayName,
        'shortExplanation': shortExplanation,
        'philosophicalRelation': philosophicalRelation,
        'referenceIds': referenceIds,
        'firmness': firmness,
        'at': dateToJson(at),
      };

  static NotebookEntry? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null || asString(m['id']).isEmpty) return null;
    return NotebookEntry(
      id: asString(m['id']),
      distinctionId: asString(m['distinctionId'], 'own'),
      experienceId: asString(m['experienceId']),
      userWords: asString(m['userWords']),
      everydayName: asString(m['everydayName']),
      shortExplanation: asString(m['shortExplanation']),
      philosophicalRelation: asString(m['philosophicalRelation']),
      referenceIds: asStringList(m['referenceIds']),
      firmness: asString(m['firmness'], 'sostenida'),
      at: asDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Única fuente de verdad de los datos filosóficos del usuario.
class UserState {
  const UserState({
    required this.schemaVersion,
    required this.contentVersion,
    required this.createdAt,
    this.onboarding,
    this.experiences = const {},
    this.notebook = const [],
    this.notes = const {},
  });

  final int schemaVersion;
  final String contentVersion;
  final DateTime createdAt;
  final OnboardingRecord? onboarding;
  final Map<String, ExperienceProgress> experiences;
  final List<NotebookEntry> notebook;
  final Map<String, String> notes;

  factory UserState.empty({String contentVersion = '', DateTime? now}) => UserState(
        schemaVersion: kSchemaVersion,
        contentVersion: contentVersion,
        createdAt: now ?? DateTime.now(),
      );

  ExperienceProgress progress(String id) => experiences[id] ?? ExperienceProgress(experienceId: id);

  UserState withProgress(ExperienceProgress p) =>
      copyWith(experiences: {...experiences, p.experienceId: p});

  UserState copyWith({
    Object? onboarding = _unset,
    Map<String, ExperienceProgress>? experiences,
    List<NotebookEntry>? notebook,
    Map<String, String>? notes,
    String? contentVersion,
  }) =>
      UserState(
        schemaVersion: schemaVersion,
        contentVersion: contentVersion ?? this.contentVersion,
        createdAt: createdAt,
        onboarding: identical(onboarding, _unset) ? this.onboarding : onboarding as OnboardingRecord?,
        experiences: experiences ?? this.experiences,
        notebook: notebook ?? this.notebook,
        notes: notes ?? this.notes,
      );

  Json toJson() => {
        'schemaVersion': schemaVersion,
        'contentVersion': contentVersion,
        'createdAt': dateToJson(createdAt),
        'onboarding': onboarding?.toJson(),
        'experiences': experiences.map((k, v) => MapEntry(k, v.toJson())),
        'notebook': notebook.map((n) => n.toJson()).toList(),
        'notes': notes,
      };

  factory UserState.fromJson(Json m) {
    final exps = <String, ExperienceProgress>{};
    asJson(m['experiences']).forEach((k, v) {
      final p = ExperienceProgress.fromJson(v);
      if (p != null) exps[k] = p;
    });
    return UserState(
      schemaVersion: asInt(m['schemaVersion'], kSchemaVersion),
      contentVersion: asString(m['contentVersion']),
      createdAt: asDate(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      onboarding: OnboardingRecord.fromJson(m['onboarding']),
      experiences: exps,
      notebook: (m['notebook'] is List ? m['notebook'] as List : const [])
          .map(NotebookEntry.fromJson)
          .whereType<NotebookEntry>()
          .toList(),
      notes: asStringMap(m['notes']),
    );
  }
}
