// Renderiza láminas de arte a PNG para revisarlas sin emulador.
// flutter test tool/arte/lamina_test.dart --dart-define=OUT=<carpeta>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:enves/app/providers.dart';
import 'package:enves/domain/records/prefs.dart';
import 'package:enves/theme/app_theme.dart';
import 'package:enves/widgets/arte.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'laminas.dart';

const out = String.fromEnvironment('OUT', defaultValue: 'build/arte');

Future<void> _fonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
    }
    await l.load();
  }

  await load(kSerif, ['assets/fonts/Newsreader-Regular.ttf', 'assets/fonts/Newsreader-Italic.ttf']);
  await load(kSerifDisplay, ['assets/fonts/Newsreader-DisplayMedium.ttf']);
  await load(kSans, ['assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf', 'assets/fonts/AtkinsonHyperlegibleNext-Bold.ttf']);
}

void main() {
  setUpAll(_fonts);
  for (final entry in laminas.entries) {
    for (final dark in [false, true]) {
      testWidgets('${entry.key} ${dark ? 'oscuro' : 'claro'}', (tester) async {
        final size = entry.value.size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(ProviderScope(
          overrides: entry.value.overrides +
              [currentPrefsProvider.overrideWithValue(const Prefs(motion: 'reduced'))],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(dark ? Brightness.dark : Brightness.light),
            home: RepaintBoundary(
              key: key,
              child: Builder(builder: (context) => Material(
                    color: context.enves.paper,
                    child: entry.value.build(context),
                  )),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        Directory(out).createSync(recursive: true);
        File('$out/${entry.key}_${dark ? 'oscuro' : 'claro'}.png').writeAsBytesSync(bytes!);
        expect(Tinta.of(tester.element(find.byKey(key))).ink, isNotNull);
      });
    }
  }
}
