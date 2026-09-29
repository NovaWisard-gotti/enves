import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/records/prefs.dart';

/// Duraciones del sistema de movimiento. Sin animaciones en bucle.
abstract final class Motion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const long = Duration(milliseconds: 600);
  static const cross = Duration(milliseconds: 1200);
  static const back = Duration(milliseconds: 900);
  static const reduced = Duration(milliseconds: 200);

  static const settle = Curves.easeOutCubic;
  static const turn = Curves.easeInOutCubic;
}

/// Movimiento reducido: por el sistema o por la preferencia de la app.
bool reducedMotion(BuildContext context, WidgetRef ref) {
  final prefs = ref.watch(currentPrefsProvider);
  return MediaQuery.maybeDisableAnimationsOf(context) == true || prefs.motion == 'reduced';
}

/// Háptica sutil y sonido opcional; ambos respetan las preferencias.
class SensoryFeedback {
  const SensoryFeedback(this.prefs);
  final Prefs prefs;

  void selection() {
    if (prefs.haptics) HapticFeedback.selectionClick();
  }

  void light() {
    if (prefs.haptics) HapticFeedback.lightImpact();
  }

  Future<void> discovery() async {
    if (prefs.haptics) {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.lightImpact();
    }
    sound();
  }

  void cross() {
    light();
    sound();
  }

  void sound() {
    if (prefs.sound) SystemSound.play(SystemSoundType.click);
  }
}

final feedbackProvider = Provider<SensoryFeedback>((ref) => SensoryFeedback(ref.watch(currentPrefsProvider)));

/// Igual que [reducedMotion], pero sin suscribirse (para usar fuera de build).
bool reducedMotionNow(BuildContext context, WidgetRef ref) {
  final prefs = ref.read(currentPrefsProvider);
  return MediaQuery.maybeDisableAnimationsOf(context) == true || prefs.motion == 'reduced';
}
