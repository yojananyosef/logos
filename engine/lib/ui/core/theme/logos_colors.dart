// GENERATED FILE — do not edit by hand.
//
//     dart run tool/generate_theme.dart
//
// Source: ../docs/research/design-tokens.json — the 1890
// `--bible-study-theme-*` custom properties captured from the live application.
// `test/theme_parity_test.dart` regenerates this in memory and fails if the
// committed values drift from the source.
//
// The values are machine-transcribed from the reference rather than written by eye.
// That distinction is not pedantic: the active tab accent is #ff6600 in the
// reference, orange rather than the brand blue, and reading it by hand gets it
// wrong.

import 'package:flutter/widgets.dart';

/// The Logos palette, transcribed from the reference application's own custom
/// properties rather than from a Material seed.
///
/// Every value below names the token it came from. The reference exposes 1890
/// of them, many sharing a value, so binding by name rather than by value is
/// what keeps the brand colour from being coupled to whichever component
/// happened to be captured first.
@immutable
class LogosColors {
  const LogosColors._();

  /// #154AC9 — app-toolbar-button-active-icon-color
  static const Color primary = Color(0xFF154AC9);

  /// #030B60 — app-edition-badge-subscriber-background-color
  static const Color navy = Color(0xFF030B60);

  /// #FF6600 — panel-tab-active-border-color
  static const Color tabActiveAccent = Color(0xFFFF6600);

  /// #1E6AFE — link-color
  static const Color link = Color(0xFF1E6AFE);

  /// #4797FF — link-hover-color
  static const Color linkHover = Color(0xFF4797FF);

  /// #1E6AFE80 — link-disabled-color
  static const Color linkDisabled = Color(0x801E6AFE);

  /// #4797FF — sidebar-menu-item-active-focus-outline-color
  static const Color focusRing = Color(0xFF4797FF);

  /// #1E6AFE — link-focus-outline-color
  static const Color linkFocusRing = Color(0xFF1E6AFE);

  /// #333333 — app-toolbar-text-color
  static const Color textPrimary = Color(0xFF333333);

  /// #515D72 — app-toolbar-icon-color
  static const Color textSecondary = Color(0xFF515D72);

  /// #63728C — button-borderless-icon-color
  static const Color textTertiary = Color(0xFF63728C);

  /// #888888 — app-toolbar-button-decorator-icon-color
  static const Color textMuted = Color(0xFF888888);

  /// #919CAE — button-badge-count-background-color
  static const Color textDisabled = Color(0xFF919CAE);

  /// #FFFFFF — app-toolbar-button-active-background-color
  static const Color textInverted = Color(0xFFFFFFFF);

  /// #000000 — ui-font-color
  static const Color textBrand = Color(0xFF000000);

  /// #AAAAAA — ui-font-color-light
  static const Color textBrandLight = Color(0xFFAAAAAA);

  /// #666666 — ui-font-color-medium
  static const Color textBrandMedium = Color(0xFF666666);

  /// #FFFFFF — toolbar-background-color
  static const Color surface = Color(0xFFFFFFFF);

  /// #EEEEEE — toolbar-separator-color
  static const Color surfaceSunken = Color(0xFFEEEEEE);

  /// #F4F4F4 — item-filled-background-color
  static const Color surfaceHover = Color(0xFFF4F4F4);

  /// #EEEEEE — app-toolbar-button-background-color
  static const Color surfacePressed = Color(0xFFEEEEEE);

  /// #EAEDF2 — app-edition-badge-free-edition-background-color
  static const Color surfaceInverted = Color(0xFFEAEDF2);

  /// #E7E7E7 — border-color
  static const Color border = Color(0xFFE7E7E7);

  /// #CCCCCC — border-color-heavy
  static const Color borderStrong = Color(0xFFCCCCCC);

  /// #919CAE — panel-tab-close-button-color
  static const Color tabCloseIcon = Color(0xFF919CAE);

  /// #515D72 — panel-tab-close-button-hover-color
  static const Color tabCloseIconHover = Color(0xFF515D72);

  /// #CC3333 — icon-alert-color
  static const Color danger = Color(0xFFCC3333);

  /// #FFE9E9 — notification-bar-error-background-color
  static const Color dangerSurface = Color(0xFFFFE9E9);

  /// #FFF4D5 — bar-alert-background-color
  static const Color warningSurface = Color(0xFFFFF4D5);

  /// #DBA910 — bar-alert-icon-color
  static const Color warningIcon = Color(0xFFDBA910);

  /// #1E6AFE — bar-alert-link-color
  static const Color warningLink = Color(0xFF1E6AFE);

  /// #E9F5FF — notification-bar-info-background-color
  static const Color infoSurface = Color(0xFFE9F5FF);

  /// #154AC9 — notification-bar-info-icon-color
  static const Color infoIcon = Color(0xFF154AC9);

  /// #55B155 — icon-biblical-places-natural-feature-color
  static const Color success = Color(0xFF55B155);

  /// #8BC5FF — text-alignment-document-primary-link-color
  static const Color documentLink = Color(0xFF8BC5FF);

  /// #C1E4FF — text-alignment-document-secondary-link-color
  static const Color documentLinkMuted = Color(0xFFC1E4FF);

  /// #FFD86A — text-alignment-document-primary-selected-color
  static const Color documentSelected = Color(0xFFFFD86A);

  /// #80C980 — text-alignment-document-note-private-indicator-color
  static const Color documentNotePrivate = Color(0xFF80C980);

  /// #FF6600 — text-alignment-document-note-public-indicator-color
  static const Color documentNotePublic = Color(0xFFFF6600);

  /// #EEEEEE — text-alignment-document-segment-excused-color
  static const Color segmentExcused = Color(0xFFEEEEEE);

  /// #DBF3DB — text-alignment-document-segment-approved-color
  static const Color segmentApproved = Color(0xFFDBF3DB);

  /// #F4F4F4 — text-box-background-color
  static const Color textBoxBackground = Color(0xFFF4F4F4);

  /// #FF0000 — red-letters-font-color
  static const Color redLetters = Color(0xFFFF0000);

  /// #000000 — search-hit-font-color
  static const Color searchHit = Color(0xFF000000);
}

/// Lengths from the captured custom properties.
@immutable
class LogosDimensions {
  const LogosDimensions._();

  /// 4 — button-border-radius
  static const double borderRadiusButton = 4;

  /// 8 — card-stock-border-radius
  static const double borderRadiusCard = 8;

  /// 2 — sidebar-menu-item-active-focus-outline-width
  static const double focusRingWidth = 2;

  /// 1 — sidebar-border-right-width
  static const double sidebarBorderRightWidth = 1;

  /// 3 — generic-tab-active-border-top-width
  static const double tabActiveBorderTopWidth = 3;
}

/// Metrics measured from the rendered reference rather than read from a
/// custom property.
///
/// The reference hardcodes most of these in CSS and never exposes them as
/// tokens, so listing them beside token-derived values would imply a
/// provenance they do not have. Each records where it was measured so it
/// can be re-measured rather than trusted indefinitely.
@immutable
class LogosMeasured {
  const LogosMeasured._();

  /// 48 — computed style of the left icon rail element
  ///
  /// Confirmed in the capture as an exact 48px column.
  static const double iconRailWidth = 48;

  /// 207 — computed style of the expanded left sidebar
  ///
  /// The reference keeps this width at every viewport, which is why it
  /// overflows below 600px. The clone collapses it instead.
  static const double sidebarExpandedWidth = 207;

  /// 56 — computed style of the collapsed left sidebar
  static const double sidebarCollapsedWidth = 56;

  /// 1 — sidebar-border-right-width token
  ///
  /// This one does have a token; it is listed here only because it is a
  /// chrome metric rather than a component style.
  static const double sidebarDividerWidth = 1;

  /// 2 — computed border of the active toolbar section
  ///
  /// The reference uses two different indicators: a 3px top border on a
  /// generic tab and a 1px right border on a panel tab. The toolbar section
  /// marker matches the 2px sidebar active-item outline, so 2 is used for
  /// the toolbar and the token-derived 3px for tabs.
  static const double activeIndicatorHeight = 2;

  /// 44 — platform accessibility guidance
  ///
  /// Not a Logos value. The reference ships a desktop-only layout and never
  /// declares one, so the clone has to choose.
  static const double minTouchTarget = 44;

  /// 720 — typographic convention
  ///
  /// Not a Logos value. The reference stretches text to the full pane
  /// width.
  static const double maxReadingMeasure = 720;
}

/// The type scale, read from the reference's own computed body style.
///
/// The reference declares `'BrandLogos', 'Alaska', 'Source Sans Pro', sans-serif`. Its first two faces, BrandLogos and
/// Alaska, are Logos display faces that cannot be redistributed, so the
/// third entry is substituted. Source Sans Pro is the reference's own body
/// face, so the substitution affects display type only.
///
/// Adobe renamed Source Sans Pro to Source Sans 3 upstream; it is the same
/// typeface continued, and is bundled here under that name. The files are
/// SIL Open Font License 1.1, in `assets/fonts/OFL.txt`.
@immutable
class LogosTypeScale {
  const LogosTypeScale._();

  static const String family = 'SourceSansPro';

  /// 16px, weight 400, 1.5 line height, from the computed style of the
  /// reference's document body element.
  static const double bodySize = 16;
  static const double bodyLineHeight = 1.5;

  /// Scripture is set looser than interface text, so a chapter reads as
  /// prose rather than as a list of labelled items.
  static const double scriptureLineHeight = 1.6;

  /// The superscript verse marker.
  static const double verseNumberSize = 10;
}
