import '../../core/json.dart';
import 'condition.dart';

class PoleDef {
  const PoleDef({required this.label, required this.short});
  final String label;
  final String short;

  factory PoleDef.fromJson(Object? json) {
    final m = asJson(json);
    final label = asString(m['label']);
    return PoleDef(label: label, short: asString(m['short'], label));
  }
}

class JudgmentDef {
  const JudgmentDef({required this.prompt, required this.left, required this.right});
  final String prompt;
  final PoleDef left;
  final PoleDef right;

  factory JudgmentDef.fromJson(Object? json) {
    final m = asJson(json);
    return JudgmentDef(
      prompt: asString(m['prompt']),
      left: PoleDef.fromJson(m['left']),
      right: PoleDef.fromJson(m['right']),
    );
  }
}

class TwinColumn {
  const TwinColumn({required this.name, required this.lines});
  final String name;
  final List<String> lines;
}

class ScenarioDef {
  const ScenarioDef({required this.layout, required this.paragraphs, required this.twin});
  final String layout;
  final List<String> paragraphs;
  final List<TwinColumn> twin;

  bool get isTwin => layout == 'twin' && twin.length == 2;

  factory ScenarioDef.fromJson(Object? json) {
    final m = asJson(json);
    return ScenarioDef(
      layout: asString(m['layout'], 'single'),
      paragraphs: asStringList(m['paragraphs']),
      twin: asJsonList(m['twin'])
          .map((t) => TwinColumn(name: asString(t['name']), lines: asStringList(t['lines'])))
          .toList(),
    );
  }
}

class MapValue {
  const MapValue({required this.axis, required this.value});
  final String axis;
  final int value;

  static MapValue? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null) return null;
    final axis = asString(m['axis']);
    if (axis.isEmpty) return null;
    return MapValue(axis: axis, value: asInt(m['value']));
  }
}

class ReasonDef {
  const ReasonDef({required this.id, required this.text, required this.tags, required this.aligns, this.map});
  final String id;
  final String text;
  final List<String> tags;
  final String aligns;
  final MapValue? map;

  factory ReasonDef.fromJson(Json m) => ReasonDef(
        id: asString(m['id']),
        text: asString(m['text']),
        tags: asStringList(m['tags']),
        aligns: asString(m['aligns'], 'both'),
        map: MapValue.fromJson(m['map']),
      );
}

class ProbeDef {
  const ProbeDef({required this.id, required this.type, required this.placement, required this.prompt, required this.config});
  final String id;
  final String type;
  final String placement;
  final String prompt;
  final Json config;

  factory ProbeDef.fromJson(Json m) => ProbeDef(
        id: asString(m['id']),
        type: asString(m['type']),
        placement: asString(m['placement'], 'elige'),
        prompt: asString(m['prompt']),
        config: asJson(m['config']),
      );
}

class MemorySpec {
  const MemorySpec({required this.source, this.excludeIfRevised = true});
  final String source;
  final bool excludeIfRevised;

  static MemorySpec? fromJson(Object? json) {
    final m = asJsonOrNull(json);
    if (m == null) return null;
    final source = asString(m['source']);
    if (source.isEmpty) return null;
    return MemorySpec(source: source, excludeIfRevised: asBool(m['excludeIfRevised'], true));
  }

  Json toJson() => {'source': source, 'excludeIfRevised': excludeIfRevised};
}

class TriggerDef {
  const TriggerDef({
    required this.id,
    required this.priority,
    required this.kind,
    required this.questionId,
    required this.condition,
    this.memory,
  });
  final String id;
  final int priority;
  final String kind;
  final String questionId;
  final Condition condition;
  final MemorySpec? memory;

  factory TriggerDef.fromJson(Json m) => TriggerDef(
        id: asString(m['id']),
        priority: asInt(m['priority'], 100),
        kind: asString(m['kind']),
        questionId: asString(m['question']),
        condition: Condition.fromJson(m['condition']),
        memory: MemorySpec.fromJson(m['memory']),
      );
}

class AnswerDef {
  const AnswerDef({required this.id, required this.label, this.next, this.nextCondition = Condition.always, this.map});
  final String id;
  final String label;
  final String? next;
  final Condition nextCondition;
  final MapValue? map;

  factory AnswerDef.fromJson(Json m) => AnswerDef(
        id: asString(m['id']),
        label: asString(m['label']),
        next: asStringOrNull(m['next']),
        nextCondition: Condition.fromJson(m['nextCondition']),
        map: MapValue.fromJson(m['map']),
      );
}

/// Tipos de pregunta socrática.
abstract final class QuestionKind {
  static const tension = 'tension';
  static const assumption = 'assumption';
  static const clarification = 'clarification';
}

class QuestionDef {
  const QuestionDef({
    required this.id,
    required this.kind,
    required this.text,
    required this.answers,
    this.implication,
    this.followUp,
  });
  final String id;
  final String kind;
  final String text;
  final List<AnswerDef> answers;
  final String? implication;
  final String? followUp;

  AnswerDef? answer(String id) {
    for (final a in answers) {
      if (a.id == id) return a;
    }
    return null;
  }

  factory QuestionDef.fromJson(Json m) => QuestionDef(
        id: asString(m['id']),
        kind: asString(m['kind'], QuestionKind.clarification),
        text: asString(m['text']),
        answers: asJsonList(m['answers']).map(AnswerDef.fromJson).toList(),
        implication: asStringOrNull(m['implication']),
        followUp: asStringOrNull(m['followUp']),
      );
}

class DifferenceDef {
  const DifferenceDef({required this.id, required this.text, required this.test, this.distinctionId});
  final String id;
  final String text;
  final String test;
  final String? distinctionId;

  factory DifferenceDef.fromJson(Json m) => DifferenceDef(
        id: asString(m['id']),
        text: asString(m['text']),
        test: asString(m['test']),
        distinctionId: asStringOrNull(m['distinction']),
      );
}

abstract final class PieceKind {
  static const valid = 'valid';
  static const caricature = 'caricature';
  static const ownSide = 'ownSide';
}

class PieceDef {
  const PieceDef({
    required this.id,
    required this.text,
    required this.kind,
    required this.slots,
    this.caricatureType,
    this.crack,
    this.respondsTo = const [],
    this.generic = false,
  });
  final String id;
  final String text;
  final String kind;
  final List<String> slots;
  final String? caricatureType;
  final String? crack;
  final List<String> respondsTo;
  final bool generic;

  bool get isCaricature => kind == PieceKind.caricature;
  bool get isOwnSide => kind == PieceKind.ownSide;
  bool get isValid => kind == PieceKind.valid;

  factory PieceDef.fromJson(Json m) => PieceDef(
        id: asString(m['id']),
        text: asString(m['text']),
        kind: asString(m['kind'], PieceKind.valid),
        slots: asStringList(m['slots']),
        caricatureType: asStringOrNull(m['caricatureType']),
        crack: asStringOrNull(m['crack']),
        respondsTo: asStringList(m['respondsTo']),
        generic: asBool(m['generic']),
      );
}

class VoiceDef {
  const VoiceDef({required this.id, required this.descriptor, required this.reactions});
  final String id;
  final String descriptor;
  final Map<String, String> reactions;

  factory VoiceDef.fromJson(Json m) => VoiceDef(
        id: asString(m['id']),
        descriptor: asString(m['descriptor']),
        reactions: asStringMap(m['reactions']),
      );
}

class CruzaSideDef {
  const CruzaSideDef({required this.pieces, required this.voices});
  final List<PieceDef> pieces;
  final List<VoiceDef> voices;

  PieceDef? piece(String id) {
    for (final p in pieces) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory CruzaSideDef.fromJson(Object? json) {
    final m = asJson(json);
    return CruzaSideDef(
      pieces: asJsonList(m['pieces']).map(PieceDef.fromJson).toList(),
      voices: asJsonList(m['voices']).map(VoiceDef.fromJson).toList(),
    );
  }
}

class TwistDef {
  const TwistDef({required this.text, this.probeId});
  final String text;
  final String? probeId;

  factory TwistDef.fromJson(Object? json) {
    final m = asJson(json);
    return TwistDef(text: asString(m['text']), probeId: asStringOrNull(m['probe']));
  }
}

class MapContributionDef {
  const MapContributionDef({
    required this.axis,
    required this.source,
    this.polarity = 1,
    this.probeId,
    this.key,
    this.values = const {},
    this.direct = false,
    this.context,
  });
  final String axis;
  final String source;
  final int polarity;
  final String? probeId;
  final String? key;
  final Map<String, int> values;
  final bool direct;
  final String? context;

  factory MapContributionDef.fromJson(Json m) => MapContributionDef(
        axis: asString(m['axis']),
        source: asString(m['source']),
        polarity: asInt(m['polarity'], 1),
        probeId: asStringOrNull(m['probe']),
        key: asStringOrNull(m['key']),
        values: asIntMap(m['values']),
        direct: asBool(m['direct']),
        context: asStringOrNull(m['context']),
      );
}

class DeepDiveDef {
  const DeepDiveDef({
    required this.problem,
    required this.positions,
    required this.traditions,
    required this.objection,
    required this.referenceIds,
  });
  final String problem;
  final List<String> positions;
  final String traditions;
  final String objection;
  final List<String> referenceIds;

  factory DeepDiveDef.fromJson(Object? json) {
    final m = asJson(json);
    return DeepDiveDef(
      problem: asString(m['problem']),
      positions: asStringList(m['positions']),
      traditions: asString(m['traditions']),
      objection: asString(m['objection']),
      referenceIds: asStringList(m['references']),
    );
  }
}

class ExperienceDef {
  const ExperienceDef({
    required this.id,
    required this.order,
    required this.tramo,
    required this.title,
    required this.question,
    required this.sensitive,
    required this.sensitiveNote,
    required this.scenario,
    required this.probes,
    required this.judgment,
    required this.reasons,
    required this.triggers,
    required this.questions,
    required this.differences,
    required this.cruzaLeft,
    required this.cruzaRight,
    required this.twist,
    required this.reflection,
    required this.map,
    required this.openQuestion,
    required this.deepDive,
  });

  final String id;
  final int order;
  final int tramo;
  final String title;
  final String question;
  final bool sensitive;
  final String sensitiveNote;
  final ScenarioDef scenario;
  final List<ProbeDef> probes;
  final JudgmentDef judgment;
  final List<ReasonDef> reasons;
  final List<TriggerDef> triggers;
  final List<QuestionDef> questions;
  final List<DifferenceDef> differences;
  final CruzaSideDef cruzaLeft;
  final CruzaSideDef cruzaRight;
  final TwistDef twist;
  final String reflection;
  final List<MapContributionDef> map;
  final bool openQuestion;
  final DeepDiveDef deepDive;

  ProbeDef? probe(String id) {
    for (final p in probes) {
      if (p.id == id) return p;
    }
    return null;
  }

  ProbeDef? get eligeProbe {
    for (final p in probes) {
      if (p.placement == 'elige') return p;
    }
    return null;
  }

  ProbeDef? get twistProbe => twist.probeId == null ? null : probe(twist.probeId!);

  QuestionDef? questionById(String id) {
    for (final q in questions) {
      if (q.id == id) return q;
    }
    return null;
  }

  ReasonDef? reason(String id) {
    for (final r in reasons) {
      if (r.id == id) return r;
    }
    return null;
  }

  DifferenceDef? difference(String id) {
    for (final d in differences) {
      if (d.id == id) return d;
    }
    return null;
  }

  CruzaSideDef cruzaSide(String side) => side == 'left' ? cruzaLeft : cruzaRight;

  PoleDef pole(String side) => side == 'left' ? judgment.left : judgment.right;

  factory ExperienceDef.fromJson(Json m) {
    final cruza = asJson(m['cruza']);
    return ExperienceDef(
      id: asString(m['id']),
      order: asInt(m['order']),
      tramo: asInt(m['tramo'], 1),
      title: asString(m['title']),
      question: asString(m['question']),
      sensitive: asBool(m['sensitive']),
      sensitiveNote: asString(m['sensitiveNote']),
      scenario: ScenarioDef.fromJson(m['scenario']),
      probes: asJsonList(m['probes']).map(ProbeDef.fromJson).toList(),
      judgment: JudgmentDef.fromJson(m['judgment']),
      reasons: asJsonList(m['reasons']).map(ReasonDef.fromJson).toList(),
      triggers: asJsonList(m['triggers']).map(TriggerDef.fromJson).toList(),
      questions: asJsonList(m['questions']).map(QuestionDef.fromJson).toList(),
      differences: asJsonList(m['differences']).map(DifferenceDef.fromJson).toList(),
      cruzaLeft: CruzaSideDef.fromJson(cruza['left']),
      cruzaRight: CruzaSideDef.fromJson(cruza['right']),
      twist: TwistDef.fromJson(m['twist']),
      reflection: asString(m['reflection']),
      map: asJsonList(m['map']).map(MapContributionDef.fromJson).toList(),
      openQuestion: asBool(m['openQuestion']),
      deepDive: DeepDiveDef.fromJson(m['deepDive']),
    );
  }
}

class CatalogEntry {
  const CatalogEntry({required this.id, required this.title, required this.question, required this.tramo, required this.order});
  final String id;
  final String title;
  final String question;
  final int tramo;
  final int order;
}

class TramoDef {
  const TramoDef({required this.id, required this.title});
  final int id;
  final String title;
}

class AxisDef {
  const AxisDef({required this.id, required this.left, required this.right});
  final String id;
  final String left;
  final String right;
}

class PrincipleDef {
  const PrincipleDef({required this.id, required this.label});
  final String id;
  final String label;
}

class DistinctionDef {
  const DistinctionDef({
    required this.id,
    required this.everydayName,
    required this.shortExplanation,
    required this.philosophicalRelation,
    required this.openingLine,
    required this.debateAuthors,
    required this.mainObjection,
    required this.referenceIds,
  });
  final String id;
  final String everydayName;
  final String shortExplanation;
  final String philosophicalRelation;
  final String openingLine;
  final String debateAuthors;
  final String mainObjection;
  final List<String> referenceIds;

  factory DistinctionDef.fromJson(Json m) => DistinctionDef(
        id: asString(m['id']),
        everydayName: asString(m['everydayName']),
        shortExplanation: asString(m['shortExplanation']),
        philosophicalRelation: asString(m['philosophicalRelation']),
        openingLine: asString(m['openingLine'], 'Otras personas también pensaron en esta diferencia.'),
        debateAuthors: asString(m['debateAuthors']),
        mainObjection: asString(m['mainObjection']),
        referenceIds: asStringList(m['referenceIds']),
      );
}

class ReferenceDef {
  const ReferenceDef({
    required this.id,
    required this.authors,
    required this.year,
    required this.title,
    required this.container,
    required this.locator,
    required this.verified,
  });
  final String id;
  final String authors;
  final String year;
  final String title;
  final String container;
  final String locator;
  final bool verified;

  /// Formato legible, sin inventar datos que no existen.
  String get formatted {
    final parts = <String>[];
    final head = [if (authors.isNotEmpty) authors, if (year.isNotEmpty) '($year)'].join(' ');
    if (head.isNotEmpty) parts.add(head);
    parts.add(title);
    if (container.isNotEmpty) parts.add(container);
    if (locator.isNotEmpty) parts.add(locator);
    return '${parts.join('. ')}.';
  }

  factory ReferenceDef.fromJson(Json m) => ReferenceDef(
        id: asString(m['id']),
        authors: asString(m['authors']),
        year: asString(m['year']),
        title: asString(m['title']),
        container: asString(m['container']),
        locator: asString(m['locator']),
        verified: asBool(m['verified']),
      );
}

class SlotDef {
  const SlotDef({required this.id, required this.title, required this.hint, required this.missing});
  final String id;
  final String title;
  final String hint;
  final String missing;
}

class CruzaCommon {
  const CruzaCommon({
    required this.disclosure,
    required this.simulationNote,
    required this.slots,
    required this.recognition,
    required this.caricatureTypes,
  });
  final String disclosure;
  final String simulationNote;
  final List<SlotDef> slots;
  final Map<String, String> recognition;
  final Map<String, String> caricatureTypes;

  SlotDef slot(String id) => slots.firstWhere((s) => s.id == id,
      orElse: () => SlotDef(id: id, title: id, hint: '', missing: ''));

  factory CruzaCommon.fromJson(Object? json) {
    final m = asJson(json);
    return CruzaCommon(
      disclosure: asString(m['disclosure']),
      simulationNote: asString(m['simulationNote']),
      slots: asJsonList(m['slots'])
          .map((s) => SlotDef(
                id: asString(s['id']),
                title: asString(s['title']),
                hint: asString(s['hint']),
                missing: asString(s['missing']),
              ))
          .toList(),
      recognition: asStringMap(m['recognition']),
      caricatureTypes: asStringMap(m['caricatureTypes']),
    );
  }
}

/// Todo el contenido cargado, ya validado.
class ContentBundle {
  ContentBundle({
    required this.contentVersion,
    required this.catalog,
    required this.tramos,
    required this.experiences,
    required this.axes,
    required this.principles,
    required this.distinctions,
    required this.references,
    required this.common,
    this.unavailable = const {},
    this.issues = const [],
  }) : byId = {for (final e in experiences) e.id: e};

  final String contentVersion;
  final List<CatalogEntry> catalog;
  final List<TramoDef> tramos;
  final List<ExperienceDef> experiences;
  final Map<String, ExperienceDef> byId;
  final List<AxisDef> axes;
  final List<PrincipleDef> principles;
  final List<DistinctionDef> distinctions;
  final List<ReferenceDef> references;
  final CruzaCommon common;
  final Set<String> unavailable;
  final List<String> issues;

  bool isAvailable(String id) => byId.containsKey(id) && !unavailable.contains(id);

  DistinctionDef? distinction(String? id) {
    if (id == null) return null;
    for (final d in distinctions) {
      if (d.id == id) return d;
    }
    return null;
  }

  ReferenceDef? reference(String id) {
    for (final r in references) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Solo referencias verificadas; las demás no se muestran.
  List<ReferenceDef> visibleReferences(Iterable<String> ids) =>
      ids.map(reference).whereType<ReferenceDef>().where((r) => r.verified).toList();

  AxisDef? axis(String id) {
    for (final a in axes) {
      if (a.id == id) return a;
    }
    return null;
  }

  String principleLabel(String id) {
    for (final p in principles) {
      if (p.id == id) return p.label;
    }
    return id;
  }

  CatalogEntry? catalogEntry(String id) {
    for (final c in catalog) {
      if (c.id == id) return c;
    }
    return null;
  }

  String titleOf(String id) => byId[id]?.title ?? catalogEntry(id)?.title ?? '';
}
