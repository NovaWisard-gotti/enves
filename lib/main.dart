import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  registerFontLicenses();
  runApp(const ProviderScope(child: EnvesApp()));
}

/// Registra las licencias OFL de las tipografías incluidas en la app.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final newsreader = await rootBundle.loadString('assets/fonts/OFL-Newsreader.txt');
    yield LicenseEntryWithLineBreaks(const ['Newsreader'], newsreader);
    final atkinson = await rootBundle.loadString('assets/fonts/OFL-AtkinsonHyperlegibleNext.txt');
    yield LicenseEntryWithLineBreaks(const ['Atkinson Hyperlegible Next'], atkinson);
  });
}
