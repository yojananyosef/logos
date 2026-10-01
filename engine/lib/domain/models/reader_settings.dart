import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show TextAlign;

/// How a verse number is drawn next to its text.
///
/// The reference offers all three in the `Formato` panel and the choice is the reader's
/// own: a study Bible wants visible numbers, a reading Bible wants them out of the way.
enum VerseNumberStyle {
  /// A raised marker, small and in the link colour, the way the reference sets John 1.
  superscript,

  /// Full size, on the baseline, so the number can be read without effort.
  visible,

  /// Nothing at all. The verses run together as prose, which is how a lectionary prints.
  hidden;

  String get label => switch (this) {
        VerseNumberStyle.superscript => 'Superíndice',
        VerseNumberStyle.visible => 'Visible',
        VerseNumberStyle.hidden => 'Oculto',
      };

  /// Whether a verse number is rendered at all.
  bool get isShown => this != VerseNumberStyle.hidden;

  static VerseNumberStyle parse(String? raw) {
    for (final s in VerseNumberStyle.values) {
      if (s.name == raw) return s;
    }
    return VerseNumberStyle.superscript;
  }
}

/// The face scripture is set in.
///
/// The faces scripture can be set in.
///
/// The mapping to a font stack lives in the theme, which is the only place that knows what
/// is bundled.
enum ScriptureFont {
  /// Source Sans 3, the reference's own body face.
  sans,

  /// The platform's serif stack, for readers who want a book rather than a screen.
  serif,

  /// The platform's monospace stack, for aligning verse text against a source text.
  mono;

  String get label => switch (this) {
        ScriptureFont.sans => 'Source Sans',
        ScriptureFont.serif => 'Serif',
        ScriptureFont.mono => 'Monoespaciada',
      };

  /// Whether the application can actually set this face.
  ///
  /// Only faces that resolve are offered. A preference naming a face that failed to load
  /// would render in the platform default, and the reader could not tell that from a
  /// legitimate choice — so the list is the check.
  bool get isBundled => this == ScriptureFont.sans;

  static ScriptureFont parse(String? raw) {
    for (final f in ScriptureFont.values) {
      if (f.name == raw) return f;
    }
    return ScriptureFont.sans;
  }
}

/// Line spacing, as named steps rather than a free number.
///
/// Steps rather than a slider because the reference presents them as choices, and because
/// a slider invites a value that renders a 3000-word chapter unreadably with no way back to
/// a known-good setting other than remembering what it was.
enum LineSpacing {
  compact(1.25),
  snug(1.45),
  comfortable(1.6),
  relaxed(1.85);

  const LineSpacing(this.height);

  /// Multiplier applied to the font size.
  final double height;

  String get label => switch (this) {
        LineSpacing.compact => 'Compacto',
        LineSpacing.snug => 'Cómodo',
        LineSpacing.comfortable => 'Amplio',
        LineSpacing.relaxed => 'Muy amplio',
      };

  static LineSpacing parse(String? raw) {
    for (final s in LineSpacing.values) {
      if (s.name == raw) return s;
    }
    return LineSpacing.comfortable;
  }
}

/// Text size, as named steps.
enum TextSizeStep {
  small(0.85),
  medium(1.0),
  large(1.2),
  extraLarge(1.45),
  huge(1.75);

  const TextSizeStep(this.scale);

  /// Multiplier applied to the reader's base body size.
  final double scale;

  String get label => switch (this) {
        TextSizeStep.small => 'Pequeño',
        TextSizeStep.medium => 'Normal',
        TextSizeStep.large => 'Grande',
        TextSizeStep.extraLarge => 'Muy grande',
        TextSizeStep.huge => 'Enorme',
      };

  static TextSizeStep parse(String? raw) {
    for (final s in TextSizeStep.values) {
      if (s.name == raw) return s;
    }
    return TextSizeStep.medium;
  }
}

/// The colour schemes the reading area can be set to.
///
/// The enum is domain because it is a preference; the colours that satisfy it live in
/// `ui/core/theme/reading_palette.dart`, which records where each one came from. This split
/// is not ceremony: the domain layer must not reach into the theme, or swapping the palette
/// becomes a change to the model of what the user chose.
enum ReadingColourScheme {
  claro,
  gris,
  crema;

  String get label => switch (this) {
        ReadingColourScheme.claro => 'Claro',
        ReadingColourScheme.gris => 'Gris',
        ReadingColourScheme.crema => 'Crema',
      };

  static ReadingColourScheme parse(String? raw) {
    for (final s in ReadingColourScheme.values) {
      if (s.name == raw) return s;
    }
    return ReadingColourScheme.claro;
  }
}

/// Everything about how scripture is set that the reader can choose.
///
/// Immutable and JSON-serialisable, because it outlives the widget that edits it: the
/// store writes it, and a future session reads it back. Every field has a parse function
/// that falls back to a default, so a preference file written by a later version — or
/// corrupted — degrades to a readable reader instead of throwing during startup.
@immutable
class ReaderSettings {
  const ReaderSettings({
    this.verseNumbers = VerseNumberStyle.superscript,
    this.font = ScriptureFont.sans,
    this.textSize = TextSizeStep.medium,
    this.lineSpacing = LineSpacing.comfortable,
    this.colourScheme = ReadingColourScheme.claro,
    this.alignment = TextAlign.start,
  });

  final VerseNumberStyle verseNumbers;
  final ScriptureFont font;
  final TextSizeStep textSize;
  final LineSpacing lineSpacing;
  final ReadingColourScheme colourScheme;

  /// `TextAlign.start` rather than `TextAlign.left`, so a right-to-left module aligns to
  /// its own start edge instead of being pinned left.
  final TextAlign alignment;

  ReaderSettings copyWith({
    VerseNumberStyle? verseNumbers,
    ScriptureFont? font,
    TextSizeStep? textSize,
    LineSpacing? lineSpacing,
    ReadingColourScheme? colourScheme,
    TextAlign? alignment,
  }) =>
      ReaderSettings(
        verseNumbers: verseNumbers ?? this.verseNumbers,
        font: font ?? this.font,
        textSize: textSize ?? this.textSize,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        colourScheme: colourScheme ?? this.colourScheme,
        alignment: alignment ?? this.alignment,
      );

  Map<String, Object?> toJson() => {
        'verseNumbers': verseNumbers.name,
        'font': font.name,
        'textSize': textSize.name,
        'lineSpacing': lineSpacing.name,
        'colourScheme': colourScheme.name,
        'alignment': alignment.name,
      };

  /// Reads settings, substituting a default for anything absent or unrecognised.
  ///
  /// Total rather than partial on purpose: a stored value this version does not know about
  /// is a version skew, and the honest response is to use the default rather than to refuse
  /// to start.
  factory ReaderSettings.fromJson(Map<String, Object?> json) => ReaderSettings(
        verseNumbers: VerseNumberStyle.parse(json['verseNumbers'] as String?),
        font: ScriptureFont.parse(json['font'] as String?),
        textSize: TextSizeStep.parse(json['textSize'] as String?),
        lineSpacing: LineSpacing.parse(json['lineSpacing'] as String?),
        colourScheme: ReadingColourScheme.parse(json['colourScheme'] as String?),
        alignment: TextAlign.values.firstWhere(
          (a) => a.name == json['alignment'],
          orElse: () => TextAlign.start,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.verseNumbers == verseNumbers &&
      other.font == font &&
      other.textSize == textSize &&
      other.lineSpacing == lineSpacing &&
      other.colourScheme == colourScheme &&
      other.alignment == alignment;

  @override
  int get hashCode => Object.hash(
        verseNumbers,
        font,
        textSize,
        lineSpacing,
        colourScheme,
        alignment,
      );
}
