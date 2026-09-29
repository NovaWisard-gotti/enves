import 'package:enves/domain/content/content_models.dart';
import 'package:enves/domain/records/records.dart';
import 'package:enves/engine/cruza/cruza_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late ContentBundle c;
  const engine = CruzaEngine();
  setUp(() async => c = await loadContent());

  String validFor(CruzaSideDef s, String slot) => s.pieces.firstWhere((p) => p.isValid && p.slots.contains(slot)).id;

  test('la mesa tiene 9 piezas y es determinista', () {
    for (final e in c.experiences) {
      for (final side in ['left', 'right']) {
        final a = engine.composeTable(e, side, e.reasons.first.id);
        final b = engine.composeTable(e, side, e.reasons.first.id);
        expect(a, b);
        expect(a.length, 9, reason: '${e.id} $side');
        expect(a.toSet().length, 9);
      }
    }
  });

  test('las cuatro combinaciones válidas producen el mismo estado en todas las experiencias', () {
    for (final e in c.experiences) {
      for (final side in ['left', 'right']) {
        final s = e.cruzaSide(side);
        final full = {for (final slot in CruzaEngine.slots) slot: validFor(s, slot)};
        expect(engine.evaluate(s, full).state, Recognition.fuerte);
        expect(engine.evaluate(s, Map.of(full)..remove('S4')).state, Recognition.reconocible);
        expect(engine.evaluate(s, Map.of(full)..remove('S2')).state, Recognition.parcial);
        expect(engine.evaluate(s, {'S3': full['S3']!}).state, Recognition.noRepresenta);
      }
    }
  });

  test('una caricatura o una pieza del propio lado nunca representa', () {
    for (final e in c.experiences) {
      final s = e.cruzaSide('left');
      final full = {for (final slot in CruzaEngine.slots) slot: validFor(s, slot)};
      final caricature = s.pieces.firstWhere((p) => p.isCaricature).id;
      final own = s.pieces.firstWhere((p) => p.isOwnSide).id;
      expect(engine.evaluate(s, {...full, 'S1': caricature}).state, Recognition.noRepresenta);
      expect(engine.evaluate(s, {...full, 'S2': own}).state, Recognition.noRepresenta);
    }
  });

  test('una pieza válida en la ranura equivocada deja el argumento parcial', () {
    final s = c.experiences.first.cruzaSide('right');
    final full = {for (final slot in CruzaEngine.slots) slot: validFor(s, slot)};
    expect(engine.evaluate(s, {...full, 'S1': full['S3']!, 'S3': full['S1']!}).state, Recognition.parcial);
  });

  test('solo se puede enviar con dos piezas, una de ellas lo que concluyen', () {
    expect(engine.canSubmit({'S1': 'a'}), isFalse);
    expect(engine.canSubmit({'S1': 'a', 'S2': 'b'}), isFalse);
    expect(engine.canSubmit({'S1': 'a', 'S3': 'b'}), isTrue);
  });

  test('la respuesta de S4 se adapta a la razón del usuario', () {
    final e = c.byId['e1_mismo_descuido']!;
    final right = e.cruzaSide('right');
    expect(engine.responsePiece(right, 'e1_r_decision')!.respondsTo, contains('e1_r_decision'));
    expect(engine.responsePiece(right, 'unknown')!.generic, isTrue);
  });
}
