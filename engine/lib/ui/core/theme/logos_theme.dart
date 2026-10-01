import 'package:flutter/material.dart';

import '../../../domain/models/reader_settings.dart';
import 'logos_colors.dart';
import 'reading_palette.dart';

/// Text styles built on the bundled Source Sans 3 files.
///
/// The sizes and line heights come from the generated [LogosTypeScale], which reads
/// them from the reference's own computed body style. The weights are the three the
/// reference actually loads — the tokens show 400, 600 and 700 in use, with 500 and
/// 800 never appearing.
class LogosTypography {
  const LogosTypography._();

  static const String family = LogosTypeScale.family;

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: LogosTypeScale.bodySize,
    fontWeight: FontWeight.w400,
    color: LogosColors.textPrimary,
    height: LogosTypeScale.bodyLineHeight,
  );

  /// The 20px semibold used for panel and card titles.
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: LogosColors.textPrimary,
  );

  /// The 12px semibold section label, with the wide tracking the reference uses for
  /// its all-caps group headings.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: LogosColors.textSecondary,
  );

  static const TextStyle navItem = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: LogosColors.textPrimary,
  );

  /// Scripture body text. Sized by the reader's zoom rather than fixed, and set looser
  /// than interface text so a chapter reads as prose instead of a list of items.
  static TextStyle scripture(double scale) => TextStyle(
        fontFamily: family,
        fontSize: LogosTypeScale.bodySize * scale,
        fontWeight: FontWeight.w400,
        color: LogosColors.textPrimary,
        height: LogosTypeScale.scriptureLineHeight,
      );

  /// Scripture as the reader has chosen to see it.
  ///
  /// Every setting reaches the text through here, so there is exactly one place where a
  /// preference becomes pixels. The alternative is each view assembling its own `TextStyle`
  /// from the same five fields, which is how a colour scheme ends up applied to the header
  /// and forgotten in the body.
  ///
  /// [fallback] supplies the colours, because the palette a reader picks belongs to the
  /// theme layer; the settings model carries the choice, not the hex.
  static TextStyle scriptureWith(
    ReaderSettings settings,
    ReadingPalette palette, {
    double zoom = 1.0,
  }) =>
      TextStyle(
        fontFamily: settings.font.fontStack,
        fontFamilyFallback: settings.font.fallbackStack,
        fontSize: LogosTypeScale.bodySize * settings.textSize.scale * zoom,
        fontWeight: FontWeight.w400,
        color: palette.foreground,
        height: settings.lineSpacing.height,
      );

  static const TextStyle verseNumber = TextStyle(
    fontFamily: family,
    fontSize: LogosTypeScale.verseNumberSize,
    fontWeight: FontWeight.w600,
    color: LogosColors.primary,
  );

  /// A query example, as the syntax help panel renders it.
  ///
  /// Monospaced and letter-spaced, because these strings are meant to be read as syntax
  /// rather than as prose. An operator written in the same face as the sentence around it
  /// reads as an ordinary word, and `Cristo Y Jesús` looks like a name.
  static const TextStyle code = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Source Sans 3', 'monospace'],
    fontSize: LogosTypeScale.bodySize,
    fontWeight: FontWeight.w500,
    color: LogosColors.textPrimary,
    letterSpacing: 0.2,
  );
}

/// [splashFactory] is overridable because `InkSparkle` cannot work everywhere.
///
/// It compiles a fragment shader at runtime, which needs a pipeline the widget-test VM does
/// not have: the first tap in a test throws `Asset 'shaders/ink_sparkle.frag' manifest could
/// not be decoded`. That is a property of the test environment, not of the application — the
/// shader is supplied by the framework and works on all six targets — so the substitution is
/// a parameter rather than a downgrade of the theme. `InteractiveInkFeatureFactory` is the
/// type `ThemeData.splashFactory` has taken since `SplashFactory` was folded into it.
ThemeData buildLogosTheme({InteractiveInkFeatureFactory? splashFactory}) {
  const scheme = ColorScheme.light(
    primary: LogosColors.primary,
    onPrimary: LogosColors.surface,
    secondary: LogosColors.link,
    onSecondary: LogosColors.surface,
    surface: LogosColors.surface,
    onSurface: LogosColors.textPrimary,
    error: LogosColors.danger,
    onError: LogosColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: LogosTypography.family,
    scaffoldBackgroundColor: LogosColors.surface,
    dividerColor: LogosColors.border,
    splashFactory: splashFactory ?? InkSparkle.splashFactory,
    textTheme: const TextTheme(
      bodyMedium: LogosTypography.body,
      titleMedium: LogosTypography.title,
      labelSmall: LogosTypography.sectionLabel,
    ),
    // Every focusable control must show a visible indicator. The platform default is
    // easy to lose on the sunken toolbar surface, and the reference declares its own
    // 2px ring in `--bible-study-theme-sidebar-menu-item-active-focus-outline`.
    focusColor: LogosColors.focusRing,
    // `CardThemeData`, not `CardTheme`: `ThemeData.cardTheme` was retyped when the theme
    // classes were split from their widgets. The shapes are the same object.
    cardTheme: const CardThemeData(
      color: LogosColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: LogosColors.border),
        borderRadius: BorderRadius.all(
          Radius.circular(LogosDimensions.borderRadiusButton),
        ),
      ),
    ),
  );
}
