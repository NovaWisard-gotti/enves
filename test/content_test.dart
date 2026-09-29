import 'package:enves/content/content_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('el contenido carga completo y sin problemas', () async {
    final c = await loadContent();
    expect(c.experiences.length, 9);
    expect(c.issues, isEmpty, reason: c.issues.join('\n'));
    expect(c.unavailable, isEmpty);
    expect(c.distinctions.length, 12);
    expect(c.references.where((r) => r.verified).length, greaterThanOrEqualTo(40));
  });

  test('el validador aprueba el contenido real', () async {
    final report = const ContentValidator().validate(await loadContent());
    expect(report.isValid, isTrue, reason: report.issues.join('\n'));
  });

  test('cada lado de CRUZA tiene 4 ranuras, caricaturas, pieza propia y 3 perspectivas', () async {
    final c = await loadContent();
    for (final e in c.experiences) {
      for (final side in ['left', 'right']) {
        final s = e.cruzaSide(side);
        for (final slot in ['S1', 'S2', 'S3', 'S4']) {
          expect(s.pieces.any((p) => p.isValid && p.slots.contains(slot)), isTrue, reason: '${e.id} $side $slot');
        }
        expect(s.pieces.where((p) => p.isCaricature).length, greaterThanOrEqualTo(3));
        expect(s.pieces.any((p) => p.isOwnSide), isTrue);
        expect(s.voices.length, 3);
      }
    }
  });

  test('el detector de textos provisionales no confunde «todo» con TODO', () {
    expect(ContentValidator.placeholder.hasMatch('Da igual: importa todo lo demás'), isFalse);
    expect(ContentValidator.placeholder.hasMatch('TODO: escribir'), isTrue);
    expect(ContentValidator.placeholder.hasMatch('lorem ipsum'), isTrue);
  });

  test('las preguntas socráticas no usan lenguaje de error', () async {
    final c = await loadContent();
    for (final e in c.experiences) {
      for (final q in e.questions) {
        expect(ContentValidator.forbidden.hasMatch(q.text), isFalse, reason: q.id);
      }
    }
  });
}
