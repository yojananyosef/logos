import 'package:flutter/material.dart';

import 'logos_colors.dart';

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

  static const TextStyle verseNumber = TextStyle(
    fontFamily: family,
    fontSize: LogosTypeScale.verseNumberSize,
    fontWeight: FontWeight.w600,
    color: LogosColors.primary,
  );
}

ThemeData buildLogosTheme() {
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
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      bodyMedium: LogosTypography.body,
      titleMedium: LogosTypography.title,
      labelSmall: LogosTypography.sectionLabel,
    ),
    // Every focusable control must show a visible indicator. The platform default is
    // easy to lose on the sunken toolbar surface, and the reference declares its own
    // 2px ring in `--bible-study-theme-sidebar-menu-item-active-focus-outline`.
    focusColor: LogosColors.focusRing,
    cardTheme: const CardTheme(
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
