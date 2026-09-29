import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/json.dart';
import '../../domain/records/records.dart';
import '../../engine/experience/experience_engine.dart';

/// ViewModel de una experiencia: los widgets solo llaman a estas acciones;
/// las reglas viven en [ExperienceEngine].
class ExperienceActions {
  ExperienceActions(this.ref, this.id);

  final Ref ref;
  final String id;

  Future<void> _apply(UserState Function(ExperienceEngine e, UserState s) change) async {
    final engine = ref.read(engineProvider);
    final state = ref.read(userStateProvider).valueOrNull;
    if (engine == null || state == null) return;
    await ref.read(userStateProvider.notifier).commit(change(engine, state));
  }

  Future<String?> _applyWithMessage(WorkshopOutcome Function(ExperienceEngine e, UserState s) change) async {
    final engine = ref.read(engineProvider);
    final state = ref.read(userStateProvider).valueOrNull;
    if (engine == null || state == null) return null;
    final outcome = change(engine, state);
    await ref.read(userStateProvider.notifier).commit(outcome.state);
    return outcome.message;
  }

  Future<void> start() => _apply((e, s) => e.start(s, id));
  Future<void> skip() => _apply((e, s) => e.skip(s, id));
  Future<void> submitProbe(String probeId, Json result) => _apply((e, s) => e.submitProbe(s, id, probeId, result));
  Future<void> submitJudgment(int value) => _apply((e, s) => e.submitJudgment(s, id, value));
  Future<void> submitReason(String reasonId, {String? otherText}) =>
      _apply((e, s) => e.submitReason(s, id, reasonId, otherText: otherText));
  Future<void> answer(String answerId) => _apply((e, s) => e.answerQuestion(s, id, answerId));
  Future<void> answerImplication(bool accept) => _apply((e, s) => e.answerImplication(s, id, accept));
  Future<void> chooseAfterReject(String choice) => _apply((e, s) => e.chooseAfterReject(s, id, choice));
  Future<void> chooseDifference({String? differenceId, String? otherText}) =>
      _apply((e, s) => e.chooseDifference(s, id, differenceId: differenceId, otherText: otherText));
  Future<void> answerDifferenceTest(bool holds) => _apply((e, s) => e.answerDifferenceTest(s, id, holds));
  Future<void> chooseRevisionTarget(String target) => _apply((e, s) => e.chooseRevisionTarget(s, id, target));
  Future<void> submitNoAplica(String? text) => _apply((e, s) => e.submitNoAplica(s, id, text));
  Future<void> continueToCruza() => _apply((e, s) => e.continueToCruza(s, id));
  Future<void> chooseCruzaSide(String side) => _apply((e, s) => e.chooseCruzaSide(s, id, side));
  Future<void> anchorDone() => _apply((e, s) => e.anchorDone(s, id));
  Future<String?> placePiece(String slot, String pieceId) =>
      _applyWithMessage((e, s) => e.placePiece(s, id, slot, pieceId));
  Future<void> removeFromSlot(String slot) => _apply((e, s) => e.removeFromSlot(s, id, slot));
  Future<String?> binPiece(String pieceId) => _applyWithMessage((e, s) => e.binPiece(s, id, pieceId));
  Future<void> submitWorkshop() => _apply((e, s) => e.submitWorkshop(s, id));
  Future<void> retryWorkshop() => _apply((e, s) => e.retryWorkshop(s, id));
  Future<void> continueFromRecognition() => _apply((e, s) => e.continueFromRecognition(s, id));
  Future<void> submitStrength(int strength, int agreement) =>
      _apply((e, s) => e.submitStrength(s, id, strength, agreement));
  Future<void> continueTwist() => _apply((e, s) => e.continueTwist(s, id));
  Future<void> finish() => _apply((e, s) => e.finish(s, id));
}

final experienceActionsProvider = Provider.family<ExperienceActions, String>((ref, id) => ExperienceActions(ref, id));
