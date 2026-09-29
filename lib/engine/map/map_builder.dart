import '../../core/json.dart';
import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';

class MarkView {
  const MarkView({
    required this.experienceId,
    required this.title,
    required this.value,
    required this.source,
    required this.isMain,
    this.initialValue,
    this.context,
    this.outcome,
    this.distinctionName,
  });
  final String experienceId;
  final String title;
  final int value;
  final int? initialValue;
  final String source;
  final bool isMain;
  final String? context;
  final String? outcome;
  final String? distinctionName;

  bool get revised => initialValue != null && initialValue != value;
}

class AxisView {
  const AxisView({
    required this.axis,
    required this.marks,
    required this.decided,
    required this.unknown,
    required this.consolidated,
    required this.min,
    required this.max,
    required this.statement,
    this.contextStatement,
  });
  final AxisDef axis;
  final List<MarkView> marks;

  /// Experiencias con una decisión hacia algún lado en esta tensión.
  final int decided;

  /// Experiencias en las que se eligió «No lo sé».
  final int unknown;
  final bool consolidated;
  final int min;
  final int max;
  final String statement;
  final String? contextStatement;

  String get key => 'axis:${axis.id}';
  List<MarkView> get mainMarks => marks.where((m) => m.isMain).toList();
}

class ThreadView {
  const ThreadView({required this.from, required this.to, required this.label, required this.kind});
  final String from;
  final String to;
  final String label;

  /// memoria | principio
  final String kind;
}

class HollowView {
  const HollowView({
    required this.experienceId,
    required this.title,
    required this.recognition,
    required this.targetLabel,
    this.strength,
    this.agreement,
  });
  final String experienceId;
  final String title;
  final String recognition;
  final String targetLabel;
  final int? strength;
  final int? agreement;
}

class OpenQuestionView {
  const OpenQuestionView({
    required this.experienceId,
    required this.question,
    required this.stanceLabel,
    required this.reasonText,
    required this.recognition,
  });
  final String experienceId;
  final String question;
  final String stanceLabel;
  final String reasonText;
  final String? recognition;
}

class MapModel {
  const MapModel({
    required this.axes,
    required this.threads,
    required this.hollows,
    required this.openQuestions,
    required this.completedCount,
    this.hollowStatement,
    this.strongWithoutAgreement,
    this.confidenceStatement,
  });
  final List<AxisView> axes;
  final List<ThreadView> threads;
  final List<HollowView> hollows;
  final List<OpenQuestionView> openQuestions;
  final int completedCount;
  final String? hollowStatement;
  final String? strongWithoutAgreement;
  final String? confidenceStatement;

  bool get isEmpty => completedCount == 0;
}

/// Calcula el Mapa de Pensamiento. No guarda nada ni infiere personalidad:
/// solo describe patrones observados en decisiones reales.
class MapBuilder {
  const MapBuilder();

  static const minForPattern = 3;
  static const maxThreads = 6;

  MapModel build(ContentBundle content, UserState state) {
    final completed = content.experiences
        .where((e) => state.experiences[e.id]?.status == ExpStatus.completed)
        .toList();
    final axes = content.axes.map((a) => _axis(content, state, completed, a)).toList();
    return MapModel(
      axes: axes,
      threads: _threads(content, state, completed),
      hollows: _hollows(content, state, completed),
      openQuestions: _open(content, state, completed),
      completedCount: completed.length,
      hollowStatement: _hollowStatement(content, state, completed),
      strongWithoutAgreement: _strongStatement(state, completed),
      confidenceStatement: _confidence(state, completed),
    );
  }

  AxisView _axis(ContentBundle content, UserState state, List<ExperienceDef> completed, AxisDef axis) {
    final marks = <MarkView>[];
    for (final e in completed) {
      final p = state.experiences[e.id]!;
      final candidates = <MarkView>[];
      final entryName = _entryName(state, p);
      for (final c in e.map.where((m) => m.axis == axis.id)) {
        if (c.source == 'stance' && p.finalStance != null) {
          candidates.add(MarkView(
            experienceId: e.id,
            title: e.title,
            value: (p.finalStance!.value * c.polarity).clamp(-3, 3).toInt(),
            initialValue: p.initialStance == null ? null : (p.initialStance!.value * c.polarity).clamp(-3, 3).toInt(),
            source: 'stance',
            isMain: false,
            context: c.context,
            outcome: p.tension?.outcome,
            distinctionName: entryName,
          ));
        } else if (c.source == 'probe' && c.probeId != null && c.key != null) {
          final raw = p.probes[c.probeId!]?[c.key!];
          int? v;
          if (raw != null) {
            v = c.direct ? asIntOrNull(raw) : c.values[raw.toString()];
          }
          if (v != null) {
            candidates.add(MarkView(
              experienceId: e.id,
              title: e.title,
              value: v.clamp(-3, 3).toInt(),
              source: 'probe',
              isMain: false,
              context: c.context,
            ));
          }
        }
      }
      for (final r in p.socratic) {
        final a = e.questionById(r.questionId)?.answer(r.answerId);
        if (a?.map != null && a!.map!.axis == axis.id) {
          candidates.add(MarkView(experienceId: e.id, title: e.title, value: a.map!.value, source: 'socratic', isMain: false));
        }
      }
      final reasonDef = p.reason == null ? null : e.reason(p.reason!.id);
      if (reasonDef?.map != null && reasonDef!.map!.axis == axis.id) {
        candidates.add(MarkView(experienceId: e.id, title: e.title, value: reasonDef.map!.value, source: 'reason', isMain: false));
      }
      if (candidates.isEmpty) continue;
      const priority = ['stance', 'probe', 'socratic', 'reason'];
      var mainIndex = 0;
      for (var i = 1; i < candidates.length; i++) {
        final a = priority.indexOf(candidates[i].source);
        final b = priority.indexOf(candidates[mainIndex].source);
        final aCtx = candidates[i].context == null || candidates[i].context == 'cercanos';
        final bCtx = candidates[mainIndex].context == null || candidates[mainIndex].context == 'cercanos';
        if ((aCtx && !bCtx) || (aCtx == bCtx && a < b)) mainIndex = i;
      }
      for (var i = 0; i < candidates.length; i++) {
        final m = candidates[i];
        marks.add(MarkView(
          experienceId: m.experienceId,
          title: m.title,
          value: m.value,
          initialValue: m.initialValue,
          source: m.source,
          isMain: i == mainIndex,
          context: m.context,
          outcome: m.outcome,
          distinctionName: m.distinctionName,
        ));
      }
    }

    final mains = marks.where((m) => m.isMain).toList();
    final decided = mains.where((m) => m.value != 0).toList();
    final unknown = mains.where((m) => m.value == 0).length;
    final consolidated = decided.length >= minForPattern;
    var min = 0, max = 0;
    if (decided.isNotEmpty) {
      min = decided.map((m) => m.value).reduce((a, b) => a < b ? a : b);
      max = decided.map((m) => m.value).reduce((a, b) => a > b ? a : b);
    }
    String statement;
    if (mains.isEmpty) {
      statement = 'Todavía no hay experiencias en esta tensión.';
    } else if (!consolidated) {
      statement = 'Aún no hay suficientes experiencias para ver un patrón (${decided.length} de $minForPattern).';
    } else {
      final left = decided.where((m) => m.value < 0).length;
      final right = decided.length - left;
      final k = left >= right ? left : right;
      if (k * 3 >= decided.length * 2) {
        final pole = left >= right ? axis.left : axis.right;
        statement = 'En $k de ${decided.length} situaciones donde «${axis.left}» y «${axis.right}» '
            'entraron en conflicto, diste más peso a «$pole».';
      } else {
        statement = 'En estas ${decided.length} situaciones, tus decisiones fueron hacia ambos lados.';
      }
    }
    if (unknown > 0 && mains.isNotEmpty) {
      statement += unknown == 1 ? ' En una elegiste «No lo sé».' : ' En $unknown elegiste «No lo sé».';
    }

    String? contextStatement;
    final near = marks.where((m) => m.context == 'cercanos' && m.value != 0).toList();
    final far = marks.where((m) => m.context == 'desconocidos' && m.value != 0).toList();
    if (near.isNotEmpty && far.isNotEmpty) {
      final differs = near.any((a) => far.any((b) => a.value.sign != b.value.sign));
      contextStatement = differs
          ? 'Con personas cercanas y con desconocidos, tus decisiones fueron diferentes.'
          : 'Con personas cercanas y con desconocidos, tus decisiones fueron en la misma dirección.';
    }

    return AxisView(
      axis: axis,
      marks: marks,
      decided: decided.length,
      unknown: unknown,
      consolidated: consolidated,
      min: min,
      max: max,
      statement: statement,
      contextStatement: contextStatement,
    );
  }

  String? _entryName(UserState state, ExperienceProgress p) {
    final id = p.tension?.notebookEntryId;
    if (id == null) return null;
    for (final n in state.notebook) {
      if (n.id == id) return n.isOwn ? n.userWords : n.everydayName;
    }
    return null;
  }

  List<ThreadView> _threads(ContentBundle content, UserState state, List<ExperienceDef> completed) {
    final memory = <({ThreadView view, DateTime at})>[];
    final seen = <String>{};
    for (final e in completed) {
      final p = state.experiences[e.id]!;
      for (final r in p.socratic) {
        for (final ref in r.refs) {
          // Los recuerdos agregados (piezas reconstruidas) no son un hilo entre dos preguntas.
          if (ref.field == 'cruza') continue;
          if (ref.experienceId == e.id || !content.byId.containsKey(ref.experienceId)) continue;
          final key = '${ref.experienceId}>${e.id}';
          if (seen.contains(key)) continue;
          seen.add(key);
          memory.add((
            view: ThreadView(from: ref.experienceId, to: e.id, label: '«${ref.quote}»', kind: 'memoria'),
            at: r.at,
          ));
        }
      }
    }
    memory.sort((a, b) => b.at.compareTo(a.at));
    final out = memory.map((m) => m.view).toList();

    final shared = <ThreadView>[];
    for (var i = 0; i < completed.length; i++) {
      for (var j = i + 1; j < completed.length; j++) {
        final a = state.experiences[completed[i].id]!;
        final b = state.experiences[completed[j].id]!;
        if (a.reason == null || b.reason == null) continue;
        if ((a.tension?.revisedPrinciple ?? false) || (b.tension?.revisedPrinciple ?? false)) continue;
        final common = a.reason!.tags.where(b.reason!.tags.contains).toList();
        if (common.isEmpty) continue;
        final key1 = '${a.experienceId}>${b.experienceId}';
        final key2 = '${b.experienceId}>${a.experienceId}';
        if (seen.contains(key1) || seen.contains(key2)) continue;
        seen.add(key1);
        shared.add(ThreadView(
          from: a.experienceId,
          to: b.experienceId,
          label: content.principleLabel(common.first),
          kind: 'principio',
        ));
      }
    }
    out.addAll(shared);
    return out.take(maxThreads).toList();
  }

  List<HollowView> _hollows(ContentBundle content, UserState state, List<ExperienceDef> completed) {
    final out = <HollowView>[];
    for (final e in completed) {
      final c = state.experiences[e.id]!.cruza;
      if (c == null || c.finalRecognition == null) continue;
      out.add(HollowView(
        experienceId: e.id,
        title: e.title,
        recognition: c.finalRecognition!,
        targetLabel: e.pole(c.target).label,
        strength: c.strength,
        agreement: c.agreement,
      ));
    }
    return out;
  }

  String? _hollowStatement(ContentBundle content, UserState state, List<ExperienceDef> completed) {
    final hs = _hollows(content, state, completed);
    if (hs.isEmpty) return null;
    final k = hs.where((h) => Recognition.isRecognized(h.recognition)).length;
    return 'Tus reconstrucciones fueron reconocidas como justas en $k de ${hs.length} '
        '${hs.length == 1 ? 'experiencia' : 'experiencias'}.';
  }

  String? _strongStatement(UserState state, List<ExperienceDef> completed) {
    var x = 0;
    for (final e in completed) {
      final c = state.experiences[e.id]!.cruza;
      if (c != null && (c.strength ?? 0) >= 4 && (c.agreement ?? 5) <= 2) x++;
    }
    if (x == 0) return null;
    return x == 1
        ? 'En una experiencia encontraste fuerte un argumento con el que no estabas de acuerdo.'
        : 'En $x experiencias encontraste fuerte un argumento con el que no estabas de acuerdo.';
  }

  String? _confidence(UserState state, List<ExperienceDef> completed) {
    var n = 0, changed = 0;
    for (final e in completed) {
      final p = state.experiences[e.id]!;
      if (p.initialStance == null || p.finalStance == null) continue;
      n++;
      if (p.initialStance!.value != p.finalStance!.value) changed++;
    }
    if (n < minForPattern) return null;
    return 'Tu postura o tu seguridad cambiaron después de cruzar en $changed de $n experiencias.';
  }

  List<OpenQuestionView> _open(ContentBundle content, UserState state, List<ExperienceDef> completed) {
    final out = <OpenQuestionView>[];
    for (final e in completed.where((e) => e.openQuestion)) {
      final p = state.experiences[e.id]!;
      final r = p.reason;
      out.add(OpenQuestionView(
        experienceId: e.id,
        question: e.question,
        stanceLabel: p.finalStance?.label ?? '',
        reasonText: r == null ? '' : (r.isQuotable ? r.text : (r.other ?? r.text)),
        recognition: p.cruza?.finalRecognition,
      ));
    }
    return out;
  }
}
