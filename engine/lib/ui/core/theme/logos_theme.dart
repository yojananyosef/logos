import 'package:flutter/material.dart';

import 'logos_colors.dart';

/// Typography built on Source Sans Pro, the reference typeface.
///
/// The font files are bundled rather than fetched: the reader must work with no
/// network, and a runtime font fetch would also delay first paint.
class LogosTypography {
  const LogosTypography._();

  static const String family = 'SourceSansPro';

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: LogosColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: LogosColors.textPrimary,
  );

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

  /// Scripture body text. Sized by the reader's zoom, not fixed.
  static TextStyle scripture(double scale) => TextStyle(
        fontFamily: family,
        fontSize: 16 * scale,
        fontWeight: FontWeight.w400,
        color: LogosColors.textPrimary,
        height: 1.6,
      );

  static const TextStyle verseNumber = TextStyle(
    fontFamily: family,
    fontSize: 10,
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
    // Every focusable control must show a visible indicator, not rely on the
    // platform default, which is easy to lose on the sunken toolbar surface.
    focusColor: LogosColors.linkHover.withOpacity(0.16),
    cardTheme: const CardTheme(
      color: LogosColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: LogosColors.border),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
  );
}
