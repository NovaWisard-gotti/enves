import 'dart:io';

import 'package:enves/theme/palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contrastes de la paleta en claro y oscuro', () {
    for (final p in [EnvesPalette.light, EnvesPalette.dark]) {
      for (final bg in [p.paper, p.reverse]) {
        expect(contrastRatio(p.ink, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.inkSecondary, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.saffronText, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.technicalError, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.graphite, bg), greaterThanOrEqualTo(3.0));
        expect(contrastRatio(p.saffron, bg), greaterThanOrEqualTo(3.0));
      }
    }
  });

  test('el código no tiene colores sueltos ni trabajo pendiente', () {
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      if (!f.path.endsWith('palette.dart')) {
        expect(src.contains('Color(0x'), isFalse, reason: f.path);
      }
      expect(RegExp(r'\b(TODO|FIXME|UnimplementedError)\b').hasMatch(src), isFalse, reason: f.path);
    }
  });

  test('la versión release no pide permiso de internet', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    if (!manifest.existsSync()) return;
    final src = manifest.readAsStringSync();
    expect(src.contains('android.permission.INTERNET'), isFalse);
    expect(src.contains('android:allowBackup="false"'), isTrue);
  });
}
