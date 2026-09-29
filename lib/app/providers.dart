import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../content/content_repository.dart';
import '../core/json.dart';
import '../data/state_store.dart';
import '../domain/content/content_models.dart';
import '../domain/records/prefs.dart';
import '../domain/records/records.dart';
import '../engine/experience/experience_engine.dart';
import '../engine/map/map_builder.dart';
import '../engine/progress/progress_service.dart';

class AssetContentSource implements ContentSource {
  const AssetContentSource();
  @override
  Future<String> read(String path) => rootBundle.loadString('assets/content/es/$path');
}

final storageDirProvider = FutureProvider<Directory>((ref) async {
  final base = await getApplicationSupportDirectory();
  return Directory('${base.path}/enves');
});

final contentSourceProvider = Provider<ContentSource>((ref) => const AssetContentSource());

final contentProvider = FutureProvider<ContentBundle>((ref) async {
  return const ContentRepository().load(ref.watch(contentSourceProvider));
});

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Error de lectura del estado, con el tipo de problema.
class StateLoadError implements Exception {
  const StateLoadError(this.newer);
  final bool newer;
}

final recoveryNoticeProvider = StateProvider<bool>((ref) => false);
final saveErrorProvider = StateProvider<bool>((ref) => false);

class UserStateController extends AsyncNotifier<UserState> {
  StateStore? _store;
  Future<void> _queue = Future<void>.value();

  @override
  Future<UserState> build() async {
    final dir = await ref.watch(storageDirProvider.future);
    final store = StateStore(dir);
    _store = store;
    final outcome = await store.load();
    final status = outcome.status;
    if (status == LoadStatus.failed) throw const StateLoadError(false);
    if (status == LoadStatus.newer) throw const StateLoadError(true);
    final loaded = outcome.state;
    if (loaded == null) return UserState.empty(now: ref.read(clockProvider)());
    if (status == LoadStatus.recovered) {
      Future.microtask(() => ref.read(recoveryNoticeProvider.notifier).state = true);
    }
    return loaded;
  }

  /// Aplica un nuevo estado y lo guarda de inmediato (en orden).
  Future<void> commit(UserState next) {
    state = AsyncData(next);
    _queue = _queue.then((_) => _persist(next));
    return _queue;
  }

  Future<void> _persist(UserState s) async {
    final store = _store;
    if (store == null) return;
    const delays = [0, 150, 450];
    for (final d in delays) {
      if (d > 0) await Future<void>.delayed(Duration(milliseconds: d));
      try {
        await store.save(s);
        ref.read(saveErrorProvider.notifier).state = false;
        return;
      } catch (_) {
        // Se reintenta.
      }
    }
    ref.read(saveErrorProvider.notifier).state = true;
  }

  Future<void> retrySave() async {
    final s = state.valueOrNull;
    if (s != null) {
      _queue = _queue.then((_) => _persist(s));
      await _queue;
    }
  }

  /// Borra todo el historial filosófico y vuelve al estado inicial.
  Future<void> wipe() async {
    await _queue;
    final dir = await ref.read(storageDirProvider.future);
    await StateStore(dir).deleteAll();
    state = AsyncData(UserState.empty(now: ref.read(clockProvider)()));
  }

  /// Tras un error de lectura: borra y empieza de cero.
  Future<void> resetAfterFailure() async {
    final dir = await ref.read(storageDirProvider.future);
    await StateStore(dir).deleteAll();
    ref.invalidateSelf();
  }
}

final userStateProvider = AsyncNotifierProvider<UserStateController, UserState>(UserStateController.new);

class PrefsController extends AsyncNotifier<Prefs> {
  @override
  Future<Prefs> build() async {
    final dir = await ref.watch(storageDirProvider.future);
    return PrefsStore(dir).load();
  }

  Future<void> updatePrefs(Prefs Function(Prefs) change) async {
    final current = state.valueOrNull ?? const Prefs();
    final next = change(current);
    state = AsyncData(next);
    try {
      final dir = await ref.read(storageDirProvider.future);
      await PrefsStore(dir).save(next);
    } catch (_) {
      ref.read(saveErrorProvider.notifier).state = true;
    }
  }
}

final prefsProvider = AsyncNotifierProvider<PrefsController, Prefs>(PrefsController.new);

final currentPrefsProvider = Provider<Prefs>((ref) => ref.watch(prefsProvider).valueOrNull ?? const Prefs());

final engineProvider = Provider<ExperienceEngine?>((ref) {
  final content = ref.watch(contentProvider).valueOrNull;
  if (content == null) return null;
  return ExperienceEngine(content, clock: ref.watch(clockProvider));
});

final mapModelProvider = Provider<MapModel?>((ref) {
  final content = ref.watch(contentProvider).valueOrNull;
  final user = ref.watch(userStateProvider).valueOrNull;
  if (content == null || user == null) return null;
  return const MapBuilder().build(content, user);
});

final progressServiceProvider = Provider<ProgressService>((ref) => const ProgressService());

/// Perfil de demostración: solo lectura y nunca mezclado con los datos reales.
final demoProfileProvider = FutureProvider<UserState>((ref) async {
  final raw = await rootBundle.loadString('assets/demo/demo_profile.json');
  return UserState.fromJson(asJson(jsonDecode(raw)));
});

final demoMapProvider = FutureProvider<MapModel>((ref) async {
  final content = await ref.watch(contentProvider.future);
  final demo = await ref.watch(demoProfileProvider.future);
  return const MapBuilder().build(content, demo);
});
