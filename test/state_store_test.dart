import 'dart:io';

import 'package:enves/data/state_store.dart';
import 'package:enves/domain/records/prefs.dart';
import 'package:enves/domain/records/records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('enves_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('guarda y carga el mismo estado', () async {
    final store = StateStore(dir);
    expect((await store.load()).status, LoadStatus.fresh);
    final s = UserState.empty(now: DateTime(2026, 9, 1)).copyWith(notes: {'axis:a': 'nota'});
    await store.save(s);
    final loaded = await store.load();
    expect(loaded.status, LoadStatus.loaded);
    expect(loaded.state!.notes['axis:a'], 'nota');
    expect(store.tempFile.existsSync(), isFalse);
  });

  test('si el archivo principal se corrompe, recupera la copia', () async {
    final store = StateStore(dir);
    await store.save(UserState.empty().copyWith(notes: {'k': 'uno'}));
    await store.save(UserState.empty().copyWith(notes: {'k': 'dos'}));
    store.mainFile.writeAsStringSync('{roto');
    final loaded = await store.load();
    expect(loaded.status, LoadStatus.recovered);
    expect(loaded.state!.notes['k'], 'uno');
  });

  test('si todo está ilegible, informa el fallo sin inventar datos', () async {
    final store = StateStore(dir);
    store.mainFile.writeAsStringSync('nada');
    expect((await store.load()).status, LoadStatus.failed);
  });

  test('un esquema más nuevo no se sobrescribe', () async {
    final store = StateStore(dir);
    store.mainFile.writeAsStringSync('{"schemaVersion": 99}');
    expect((await store.load()).status, LoadStatus.newer);
  });

  test('las migraciones se aplican en orden', () {
    final m = Migrations(target: 3, steps: {
      1: (j) => {...j, 'a': 1},
      2: (j) => {...j, 'b': (j['a'] as int) + 1},
    });
    final out = m.apply({'schemaVersion': 1});
    expect(out['b'], 2);
    expect(out['schemaVersion'], 3);
  });

  test('borrar el historial deja solo las preferencias', () async {
    final store = StateStore(dir);
    await store.save(UserState.empty());
    await store.save(UserState.empty());
    await PrefsStore(dir).save(const Prefs(themeMode: 'dark'));
    await store.deleteAll();
    final names = dir.listSync().map((f) => f.uri.pathSegments.last).toList();
    expect(names, ['prefs.json']);
    expect((await PrefsStore(dir).load()).themeMode, 'dark');
  });
}
