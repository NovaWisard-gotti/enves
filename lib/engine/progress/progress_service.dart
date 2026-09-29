import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';

class HomeSuggestion {
  const HomeSuggestion({this.experience, this.isContinue = false, this.isRevisit = false, this.allDone = false});
  final ExperienceDef? experience;
  final bool isContinue;
  final bool isRevisit;
  final bool allDone;
}

class ProgressService {
  const ProgressService();

  /// La acción principal del inicio: continuar, la siguiente en orden, o volver
  /// a una pregunta omitida.
  HomeSuggestion next(ContentBundle content, UserState state) {
    final available = content.experiences.where((e) => content.isAvailable(e.id)).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    ExperienceProgress? latest;
    for (final e in available) {
      final p = state.experiences[e.id];
      if (p != null && p.status == ExpStatus.inProgress) {
        if (latest == null || (p.startedAt ?? DateTime(0)).isAfter(latest.startedAt ?? DateTime(0))) latest = p;
      }
    }
    if (latest != null) {
      return HomeSuggestion(experience: content.byId[latest.experienceId], isContinue: true);
    }
    for (final e in available) {
      final status = state.experiences[e.id]?.status ?? ExpStatus.notStarted;
      if (status == ExpStatus.notStarted) return HomeSuggestion(experience: e);
    }
    for (final e in available) {
      if (state.experiences[e.id]?.status == ExpStatus.skipped) {
        return HomeSuggestion(experience: e, isRevisit: true);
      }
    }
    return const HomeSuggestion(allDone: true);
  }

  /// Hay preguntas anteriores sin empezar: se muestra una nota, no se bloquea.
  bool isOutOfOrder(ContentBundle content, UserState state, String id) {
    final exp = content.byId[id];
    if (exp == null) return false;
    return content.experiences.any((e) =>
        e.order < exp.order &&
        content.isAvailable(e.id) &&
        (state.experiences[e.id]?.status ?? ExpStatus.notStarted) == ExpStatus.notStarted);
  }

  int completedCount(UserState state) =>
      state.experiences.values.where((p) => p.status == ExpStatus.completed).length;

  /// Eco de memoria para el inicio: cita literal de la última experiencia.
  String? echo(ContentBundle content, UserState state) {
    ExperienceProgress? last;
    for (final p in state.experiences.values) {
      if (p.status != ExpStatus.completed || p.completedAt == null) continue;
      if (last == null || p.completedAt!.isAfter(last.completedAt!)) last = p;
    }
    if (last == null) return null;
    final title = content.titleOf(last.experienceId);
    final r = last.reason;
    if (r != null && r.isQuotable) return 'En «$title» elegiste «${r.text}».';
    final s = last.finalStance;
    if (s != null) return 'En «$title» elegiste «${s.label}».';
    return null;
  }
}
