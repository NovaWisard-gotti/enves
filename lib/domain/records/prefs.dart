import '../../core/json.dart';

class Prefs {
  const Prefs({
    this.themeMode = 'system',
    this.motion = 'system',
    this.haptics = true,
    this.sound = false,
    this.discreet = false,
  });

  /// system | light | dark
  final String themeMode;

  /// system | reduced
  final String motion;
  final bool haptics;
  final bool sound;

  /// Oculta el eco de memoria en el inicio.
  final bool discreet;

  Prefs copyWith({String? themeMode, String? motion, bool? haptics, bool? sound, bool? discreet}) => Prefs(
        themeMode: themeMode ?? this.themeMode,
        motion: motion ?? this.motion,
        haptics: haptics ?? this.haptics,
        sound: sound ?? this.sound,
        discreet: discreet ?? this.discreet,
      );

  Json toJson() => {
        'themeMode': themeMode,
        'motion': motion,
        'haptics': haptics,
        'sound': sound,
        'discreet': discreet,
      };

  factory Prefs.fromJson(Json m) {
    String pick(Object? v, List<String> allowed, String fallback) {
      final s = asString(v);
      return allowed.contains(s) ? s : fallback;
    }

    return Prefs(
      themeMode: pick(m['themeMode'], const ['system', 'light', 'dark'], 'system'),
      motion: pick(m['motion'], const ['system', 'reduced'], 'system'),
      haptics: asBool(m['haptics'], true),
      sound: asBool(m['sound'], false),
      discreet: asBool(m['discreet'], false),
    );
  }
}
