import 'dart:convert';
import 'dart:io';

import '../core/json.dart';
import '../domain/records/prefs.dart';
import '../domain/records/records.dart';

/// Migraciones de esquema: cada paso lleva el JSON de la versión N a la N+1.
class Migrations {
  const Migrations({this.steps = const {}, this.target = kSchemaVersion});

  final Map<int, Json Function(Json)> steps;
  final int target;

  Json apply(Json json) {
    var version = asInt(json['schemaVersion'], 1);
    var current = json;
    while (version < target) {
      final step = steps[version];
      if (step != null) current = step(current);
      version++;
      current = {...current, 'schemaVersion': version};
    }
    return current;
  }
}

enum LoadStatus { fresh, loaded, recovered, failed, newer }

class LoadOutcome {
  const LoadOutcome(this.status, [this.state]);
  final LoadStatus status;
  final UserState? state;
}

/// Guarda los datos filosóficos en `state.json`, con copia `state.json.bak`.
class StateStore {
  StateStore(this.dir, {this.migrations = const Migrations()});

  final Directory dir;
  final Migrations migrations;

  File get mainFile => File('${dir.path}/state.json');
  File get backupFile => File('${dir.path}/state.json.bak');
  File get tempFile => File('${dir.path}/state.json.tmp');

  UserState _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('estado no es un objeto');
    final json = asJson(decoded);
    final version = asInt(json['schemaVersion'], 1);
    if (version > migrations.target) throw _NewerSchema();
    return UserState.fromJson(migrations.apply(json));
  }

  Future<LoadOutcome> load() async {
    final hasMain = await mainFile.exists();
    final hasBackup = await backupFile.exists();
    if (!hasMain && !hasBackup) return const LoadOutcome(LoadStatus.fresh);
    if (hasMain) {
      try {
        return LoadOutcome(LoadStatus.loaded, _decode(await mainFile.readAsString()));
      } on _NewerSchema {
        return const LoadOutcome(LoadStatus.newer);
      } catch (_) {
        // Se intenta la copia de respaldo.
      }
    }
    if (hasBackup) {
      try {
        return LoadOutcome(LoadStatus.recovered, _decode(await backupFile.readAsString()));
      } on _NewerSchema {
        return const LoadOutcome(LoadStatus.newer);
      } catch (_) {
        return const LoadOutcome(LoadStatus.failed);
      }
    }
    return const LoadOutcome(LoadStatus.failed);
  }

  /// Escritura atómica: archivo temporal → copia de respaldo → renombrado.
  Future<void> save(UserState state) async {
    await dir.create(recursive: true);
    final data = jsonEncode(state.toJson());
    await tempFile.writeAsString(data, flush: true);
    if (await mainFile.exists()) {
      await mainFile.copy(backupFile.path);
    }
    await tempFile.rename(mainFile.path);
  }

  /// Borra todos los datos filosóficos, incluidos respaldo y temporales.
  Future<void> deleteAll() async {
    for (final f in [mainFile, backupFile, tempFile]) {
      if (await f.exists()) await f.delete();
    }
  }
}

class _NewerSchema implements Exception {}

/// Preferencias en `prefs.json`. No contienen datos filosóficos.
class PrefsStore {
  PrefsStore(this.dir);
  final Directory dir;

  File get file => File('${dir.path}/prefs.json');

  Future<Prefs> load() async {
    try {
      if (!await file.exists()) return const Prefs();
      return Prefs.fromJson(asJson(jsonDecode(await file.readAsString())));
    } catch (_) {
      return const Prefs();
    }
  }

  Future<void> save(Prefs prefs) async {
    await dir.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(prefs.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}
