import 'package:flutter/widgets.dart';

/// The Logos brand palette, taken from the 1893 `--bible-study-theme-*` custom
/// properties captured from the live application rather than from a Material seed.
///
/// Regenerate with `tool/generate_theme.dart`; `theme_parity_test.dart` fails if the
/// committed values drift from `docs/research/design-tokens.json`.
@immutable
class LogosColors {
  const LogosColors._();

  static const Color primary = Color(0xFF154AC9);
  static const Color navy = Color(0xFF030B60);
  static const Color link = Color(0xFF1E6AFE);
  static const Color linkHover = Color(0xFF4797FF);

  static const Color infoSoft = Color(0xFFE9F5FF);
  static const Color infoPill = Color(0xFF8BC5FF);

  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF515D72);
  static const Color textTertiary = Color(0xFF63728C);
  static const Color textMuted = Color(0xFF888888);
  static const Color textDisabled = Color(0xFFC7CFDC);

  static const Color border = Color(0xFFE7E7E7);
  static const Color borderStrong = Color(0xFFCCCCCC);

  static const Color surfaceSunken = Color(0xFFEEEEEE);
  static const Color surfaceHover = Color(0xFFF4F4F4);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color danger = Color(0xFFCC3333);
  static const Color success = Color(0xFF55B155);
  static const Color successSoft = Color(0xFFDBF3DB);
  static const Color warningSurface = Color(0xFFFFF4D5);
  static const Color warningIcon = Color(0xFFDBA910);
  static const Color mapAccent = Color(0xFFFF6600);

  /// Minimum touch target. Enforced on every interactive control on touch platforms.
  static const double minTouchTarget = 44;
}

/// The spacing scale. Every gap in the app is a member, so padding cannot drift off
/// the scale as screens are added.
@immutable
class LogosSpacing {
  const LogosSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Fixed metrics copied from the reference application.
@immutable
class LogosMetrics {
  const LogosMetrics._();

  /// The icon rail measures exactly 48dp in the reference.
  static const double iconRailWidth = 48;

  /// The expanded sidebar measures ~207dp.
  static const double sidebarExpandedWidth = 207;

  /// The icon-only sidebar.
  static const double sidebarCollapsedWidth = 56;

  /// Bottom border marking the active toolbar section.
  static const double activeIndicatorHeight = 2;

  /// Sidebar trailing divider.
  static const double sidebarDividerWidth = 1;

  /// Maximum readable measure for body text on wide viewports.
  static const double maxReadingMeasure = 720;
}
