import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show Color;

import '../../../domain/models/reader_settings.dart';
import 'logos_colors.dart';

/// The two colours a reading scheme is made of.
///
/// A scheme is a pair, not a single colour, because a background chosen without a
/// foreground to go with it is how a reader ends up with cream paper and grey text at 4:1.
/// Carrying both together makes the pairing impossible to get wrong, and lets the contrast
/// test walk every scheme without knowing which one it is looking at.
@immutable
class ReadingPalette {
  const ReadingPalette({required this.background, required this.foreground});

  /// The surface behind the text.
  final Color background;

  /// The body text colour on that surface.
  final Color foreground;

  /// The surface the chapter header and the find bar sit on.
  ///
  /// [background] lifted by nothing at all: the schemes are all light, so a header that
  /// matched the page would disappear. The one token that does this job without inventing
  /// a shade is `text-box-background-color`, one step off `surface`.
  Color get chromeBackground => LogosColors.surfaceHover;

  /// The colour a find-bar hit is painted in.
  ///
  /// `search-hit-default-background-color` rather than a shade invented for the reader: it
  /// is the mark this application already uses for a matched run of text, and a highlight
  /// that looked different here and different in search results would be worse than one
  /// colour used consistently.
  Color get findHit => LogosColors.searchHitBackground;

  /// The hit the reader is currently standing on.
  Color get findActiveHit => LogosColors.searchHitActiveBackground;

  /// The border of the chrome, which has to read against both the page and the surface.
  Color get chromeBorder => LogosColors.border;

  /// The palette for [scheme].
  ///
  /// **Provenance is mixed and recorded here rather than presented as parity.** `claro` and
  /// `gris` are transcribed from the captured token set. The reference's own sepia is *not*
  /// in that capture — the 1890 captured custom properties came from the workspace shell,
  /// and none of them is a reading-surface background — so `crema` reuses the warm surface
  /// the application does declare. That is a project choice, stated as one.
  ///
  /// There is no night scheme for the reason D2 gives: inventing a dark palette would be a
  /// guess wearing the reference's clothes.
  factory ReadingPalette.of(ReadingColourScheme scheme) => switch (scheme) {
        ReadingColourScheme.claro => const ReadingPalette(
            background: LogosColors.surface,
            foreground: LogosColors.textPrimary,
          ),
        ReadingColourScheme.gris => const ReadingPalette(
            background: LogosColors.surfaceHover,
            foreground: LogosColors.textPrimary,
          ),
        ReadingColourScheme.crema => const ReadingPalette(
            background: LogosColors.warningSurface,
            foreground: LogosColors.textPrimary,
          ),
      };

  /// Every scheme, for the contrast test to walk.
  static List<ReadingPalette> get all => [
        for (final s in ReadingColourScheme.values) ReadingPalette.of(s),
      ];
}

/// The font stack each [ScriptureFont] preference resolves to.
///
/// Lives in the theme because this is the only place that knows which files are bundled:
/// `sans` names the Source Sans 3 family in `assets/fonts/`, and the other two are the
/// platform stacks Flutter resolves on each of the six targets.
extension ScriptureFontStack on ScriptureFont {
  String get fontStack => switch (this) {
        ScriptureFont.sans => 'SourceSansPro',
        ScriptureFont.serif => 'serif',
        ScriptureFont.mono => 'monospace',
      };

  /// What to try when [fontStack] has no glyphs for the text being set.
  ///
  /// Not empty. A module in a script the preferred face lacks would otherwise render as
  /// tofu boxes, and the fallback chain is what turns that back into readable text.
  List<String> get fallbackStack => switch (this) {
        ScriptureFont.sans => const ['serif'],
        ScriptureFont.serif => const ['SourceSansPro'],
        ScriptureFont.mono => const ['SourceSansPro', 'monospace'],
      };
}
