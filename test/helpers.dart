import 'dart:io';

import 'package:enves/content/content_repository.dart';
import 'package:enves/core/json.dart';
import 'package:enves/domain/content/content_models.dart';
import 'package:enves/domain/records/records.dart';
import 'package:enves/engine/experience/experience_engine.dart';

/// Lee el contenido real desde disco (las pruebas corren en la raíz del proyecto).
class FileContentSource implements ContentSource {
  const FileContentSource();
  @override
  Future<String> read(String path) => File('assets/content/es/$path').readAsString();
}

ContentBundle? _cache;

Future<ContentBundle> loadContent() async => _cache ??= await const ContentRepository().load(const FileContentSource());

/// Reloj controlado: cada llamada avanza un minuto.
DateTime Function() fakeClock() {
  var t = DateTime(2026, 9, 1, 12);
  return () => t = t.add(const Duration(minutes: 1));
}

Json defaultProbeResult(ProbeDef p) {
  switch (p.type) {
    case 'twinCases':
      return {'ana': 2, 'beto': 3, 'diff': 1};
    case 'choiceVariant':
      return {'choice': 'falle'};
    case 'proximityRings':
      return {'companero': -1, 'desconocido': 1};
    case 'ladder':
      return {'line': 2};
    case 'fairnessSimulator':
      return {'attempts': 5, 'north': 55, 'south': 55, 'reachedI1': true, 'reachedI2': false, 'bothEver': false};
    case 'flowMatrix':
      return {'accepted': 6, 'total': 12, 'contextual': true, 'level': 0};
    case 'annotatedLetter':
      return {'marked': 2, 'revealed': true};
    case 'replacementGradient':
      return {'stop': 60};
    default:
      return {'items': 1, 'que': 1, 'porque': 0, 'siente': 0};
  }
}

/// Recorre una experiencia completa con decisiones por defecto.
UserState walk(
  ExperienceEngine engine,
  UserState state,
  String id, {
  required int stance,
  required String reasonId,
  String tensionAnswer = 'mantener',
  bool acceptImplication = true,
  int? finalStance,
  List<String> slots = const ['S1', 'S2', 'S3', 'S4'],
  void Function(ExperienceProgress p)? onQuestion,
}) {
  final exp = engine.content.byId[id]!;
  var s = engine.start(state, id);
  for (var i = 0; i < 60; i++) {
    final p = s.progress(id);
    if (p.status == ExpStatus.completed) return s;
    switch (p.stage) {
      case Stage.probe:
        final probe = exp.eligeProbe!;
        s = engine.submitProbe(s, id, probe.id, defaultProbeResult(probe));
      case Stage.judgment:
        s = engine.submitJudgment(s, id, stance);
      case Stage.reason:
        s = engine.submitReason(s, id, reasonId);
      case Stage.question:
        onQuestion?.call(p);
        final q = p.active!;
        final String answer;
        if (q.kind == QuestionKind.tension) {
          answer = tensionAnswer;
        } else if (q.kind == QuestionKind.assumption) {
          answer = 'si';
        } else {
          answer = exp.questionById(q.questionId)!.answers.first.id;
        }
        s = engine.answerQuestion(s, id, answer);
      case Stage.implication:
        s = engine.answerImplication(s, id, acceptImplication);
      case Stage.chooseAfterReject:
        s = engine.chooseAfterReject(s, id, TensionOutcomeKind.matizar);
      case Stage.difference:
        s = engine.chooseDifference(s, id, differenceId: exp.differences.first.id);
      case Stage.differenceTest:
        s = engine.answerDifferenceTest(s, id, true);
      case Stage.revisionTarget:
        s = engine.chooseRevisionTarget(s, id, 'juicio');
      case Stage.noAplicaWhy:
        s = engine.submitNoAplica(s, id, null);
      case Stage.fundamento:
      case Stage.discovery:
        s = engine.continueToCruza(s, id);
      case Stage.cruzaSide:
        s = engine.chooseCruzaSide(s, id, 'left');
      case Stage.cruzaAnchor:
        s = engine.anchorDone(s, id);
      case Stage.workshop:
        final side = engine.targetSide(s, id);
        for (final slot in slots) {
          final piece = side.pieces.firstWhere((x) => x.isValid && x.slots.contains(slot));
          s = engine.placePiece(s, id, slot, piece.id).state;
        }
        s = engine.submitWorkshop(s, id);
      case Stage.recognition:
        s = engine.continueFromRecognition(s, id);
      case Stage.strength:
        s = engine.submitStrength(s, id, 4, 2);
      case Stage.twist:
        final probe = exp.twistProbe;
        s = probe == null ? engine.continueTwist(s, id) : engine.submitProbe(s, id, probe.id, defaultProbeResult(probe));
      case Stage.rejudge:
        s = engine.submitJudgment(s, id, finalStance ?? stance);
      case Stage.reflection:
        s = engine.finish(s, id);
      default:
        throw StateError('Etapa inesperada ${p.stage}');
    }
  }
  throw StateError('La experiencia $id no terminó');
}
