import 'package:flutter/material.dart';

import 'palette.dart';

const kSerif = 'Newsreader';
const kSerifDisplay = 'NewsreaderDisplay';
const kSans = 'AtkinsonHyperlegibleNext';

/// Roles semánticos de Papel y tinta que no existen en ColorScheme.
class EnvesColors extends ThemeExtension<EnvesColors> {
  const EnvesColors({
    required this.paper,
    required this.reverse,
    required this.ink,
    required this.inkSecondary,
    required this.graphite,
    required this.saffron,
    required this.saffronText,
    required this.divider,
    required this.focus,
  });

  final Color paper;
  final Color reverse;
  final Color ink;
  final Color inkSecondary;
  final Color graphite;
  final Color saffron;
  final Color saffronText;
  final Color divider;
  final Color focus;

  factory EnvesColors.fromPalette(EnvesPalette p) => EnvesColors(
        paper: Color(p.paper),
        reverse: Color(p.reverse),
        ink: Color(p.ink),
        inkSecondary: Color(p.inkSecondary),
        graphite: Color(p.graphite),
        saffron: Color(p.saffron),
        saffronText: Color(p.saffronText),
        divider: Color(p.divider),
        focus: Color(p.focus),
      );

  @override
  EnvesColors copyWith({
    Color? paper,
    Color? reverse,
    Color? ink,
    Color? inkSecondary,
    Color? graphite,
    Color? saffron,
    Color? saffronText,
    Color? divider,
    Color? focus,
  }) =>
      EnvesColors(
        paper: paper ?? this.paper,
        reverse: reverse ?? this.reverse,
        ink: ink ?? this.ink,
        inkSecondary: inkSecondary ?? this.inkSecondary,
        graphite: graphite ?? this.graphite,
        saffron: saffron ?? this.saffron,
        saffronText: saffronText ?? this.saffronText,
        divider: divider ?? this.divider,
        focus: focus ?? this.focus,
      );

  @override
  EnvesColors lerp(ThemeExtension<EnvesColors>? other, double t) {
    if (other is! EnvesColors) return this;
    return EnvesColors(
      paper: Color.lerp(paper, other.paper, t)!,
      reverse: Color.lerp(reverse, other.reverse, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      graphite: Color.lerp(graphite, other.graphite, t)!,
      saffron: Color.lerp(saffron, other.saffron, t)!,
      saffronText: Color.lerp(saffronText, other.saffronText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}

extension EnvesThemeX on BuildContext {
  EnvesColors get enves => Theme.of(this).extension<EnvesColors>()!;
  TextTheme get text => Theme.of(this).textTheme;

  /// Nota al margen: serif cursiva en azafrán legible.
  TextStyle get marginNote => TextStyle(
        fontFamily: kSerif,
        fontStyle: FontStyle.italic,
        fontSize: 16,
        height: 1.4,
        color: enves.saffronText,
      );
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? EnvesPalette.light : EnvesPalette.dark;
  final colors = EnvesColors.fromPalette(p);
  final ink = colors.ink;
  final paper = colors.paper;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: ink,
    onPrimary: paper,
    secondary: colors.saffron,
    onSecondary: brightness == Brightness.light ? ink : paper,
    tertiary: colors.reverse,
    onTertiary: ink,
    error: Color(p.technicalError),
    onError: paper,
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: colors.inkSecondary,
    outline: colors.graphite,
    outlineVariant: colors.divider,
    surfaceContainerLowest: paper,
    surfaceContainerLow: paper,
    surfaceContainer: paper,
    surfaceContainerHigh: colors.reverse,
    surfaceContainerHighest: colors.reverse,
    surfaceTint: Colors.transparent,
    shadow: ink,
    scrim: ink,
    inverseSurface: ink,
    onInverseSurface: paper,
  );

  final labelLarge = TextStyle(fontFamily: kSans, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w700, color: ink);
  final text = TextTheme(
    displaySmall: TextStyle(fontFamily: kSerifDisplay, fontSize: 30, height: 36 / 30, fontWeight: FontWeight.w500, color: ink),
    headlineSmall: TextStyle(fontFamily: kSerifDisplay, fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w500, color: ink),
    titleLarge: TextStyle(fontFamily: kSerif, fontSize: 22, height: 28 / 22, color: ink),
    titleMedium: TextStyle(fontFamily: kSans, fontSize: 16, height: 1.4, fontWeight: FontWeight.w700, color: ink),
    titleSmall: TextStyle(fontFamily: kSans, fontSize: 14, height: 1.4, fontWeight: FontWeight.w700, color: colors.inkSecondary),
    bodyLarge: TextStyle(fontFamily: kSerif, fontSize: 18, height: 1.5, color: ink),
    bodyMedium: TextStyle(fontFamily: kSans, fontSize: 16, height: 1.5, color: ink),
    bodySmall: TextStyle(fontFamily: kSans, fontSize: 14, height: 20 / 14, color: colors.inkSecondary),
    labelLarge: labelLarge,
    labelMedium: TextStyle(fontFamily: kSans, fontSize: 14, height: 1.3, fontWeight: FontWeight.w700, color: colors.inkSecondary),
    labelSmall: TextStyle(fontFamily: kSans, fontSize: 14, height: 1.3, color: colors.inkSecondary),
  );

  const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2)));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    canvasColor: paper,
    fontFamily: kSans,
    textTheme: text,
    extensions: [colors],
    splashFactory: InkRipple.splashFactory,
    dividerTheme: DividerThemeData(color: colors.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: kSans, fontSize: 16, fontWeight: FontWeight.w700, color: ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: paper,
        disabledBackgroundColor: colors.divider,
        disabledForegroundColor: colors.inkSecondary,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: shape,
        elevation: 0,
        textStyle: labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: ink, width: 1),
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: shape,
        textStyle: labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        textStyle: labelLarge.copyWith(decoration: TextDecoration.underline),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: paper,
      modalBackgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: colors.graphite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(fontFamily: kSans, fontSize: 15, color: paper),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: UnderlineInputBorder(borderSide: BorderSide(color: colors.inkSecondary)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.inkSecondary)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ink, width: 2)),
      labelStyle: TextStyle(fontFamily: kSans, color: colors.inkSecondary),
      hintStyle: TextStyle(fontFamily: kSans, color: colors.inkSecondary),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: ink,
      inactiveTrackColor: colors.divider,
      thumbColor: ink,
      overlayColor: colors.divider,
      valueIndicatorColor: ink,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? paper : colors.graphite),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : colors.divider),
      trackOutlineColor: WidgetStateProperty.all(colors.graphite),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.all(BorderSide(color: colors.inkSecondary)),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : paper),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? paper : ink),
        shape: WidgetStateProperty.all(shape),
      ),
    ),
    focusColor: colors.divider,
  );
}
