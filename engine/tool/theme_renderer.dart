// Renders a `ResolvedTheme` into the generated Dart file.
//
// Shared by `generate_theme.dart` and `test/theme_parity_test.dart` so the parity test
// renders exactly what the generator renders. A test that reimplemented the rendering
// would keep passing after the generator broke, which is the opposite of what a parity
// test is for.

import 'theme_resolver.dart';
import 'token_bindings.dart';

/// Renders the whole generated file.
///
/// Pure string building over the resolved values, so the parity test can call it and
/// compare against what is committed rather than shelling out to the generator.
String renderTheme(ResolvedTheme theme) {
  final out = StringBuffer()..writeln(_header(theme.tokens.length));

  _emitClass(
    out,
    'LogosColors',
    'The Logos palette, transcribed from the reference application\'s own custom\n'
        '/// properties rather than from a Material seed.\n'
        '///\n'
        '/// Every value below names the token it came from. The reference exposes '
        '${theme.tokens.length}\n'
        '/// of them, many sharing a value, so binding by name rather than by value is\n'
        '/// what keeps the brand colour from being coupled to whichever component\n'
        '/// happened to be captured first.',
    theme.colors.entries,
    isColor: true,
  );

  _emitClass(
    out,
    'LogosDimensions',
    'Lengths from the captured custom properties.',
    theme.dimensions.entries,
    isColor: false,
  );

  _emitMeasured(out);
  _emitTypeScale(out);

  return out.toString();
}

void _emitClass(
  StringBuffer out,
  String className,
  String doc,
  Iterable<MapEntry<String, String>> values, {
  required bool isColor,
}) {
  out
    ..writeln('/// $doc')
    ..writeln('@immutable')
    ..writeln('class $className {')
    ..writeln('  const $className._();')
    ..writeln();

  // A blank line between every declaration, which is what `dart format` produces for a
  // doc-commented member. Emitting it here rather than only at group boundaries means
  // running the formatter over this file is a no-op, so formatting the project cannot
  // silently break theme parity.
  final body = StringBuffer();
  for (final entry in values) {
    final token = isColor ? colorBindings[entry.key] : dimensionBindings[entry.key];
    // The resolver yields `RRGGBBAA`, following CSS. `Color(0x...)` wants `AARRGGBB`,
    // so the alpha has to move from the end to the front. Getting this wrong rotates
    // every channel and turns #ff6600 into #6600ff — a plausible-looking colour that
    // is not the reference's, which is why the parity test compares committed bytes
    // rather than eyeballing swatches.
    final value = isColor ? 'Color(0x${_toArgbLiteral(entry.value)})' : entry.value;
    body
      ..writeln('  /// ${isColor ? '#${_asCssHex(entry.value)}' : entry.value} — $token')
      ..writeln('  static const ${isColor ? 'Color' : 'double'} '
          '${entry.key} = $value;')
      ..writeln();
  }

  // The blank after the last member would otherwise sit against the closing brace.
  out.write(body.toString().trimRight());
  out
    ..writeln()
    ..writeln('}')
    ..writeln();
}

/// `RRGGBBAA` to `AARRGGBB`.
String _toArgbLiteral(String rrggbbaa) {
  final rgb = rrggbbaa.substring(0, 6);
  final alpha = rrggbbaa.length == 8 ? rrggbbaa.substring(6) : 'FF';
  return '$alpha$rgb';
}

/// Renders `RRGGBBAA` the way CSS writes it, dropping a fully opaque alpha so the
/// committed file stays readable.
String _asCssHex(String rrggbbaa) {
  if (rrggbbaa.length == 8 && rrggbbaa.substring(6) == 'FF') {
    return rrggbbaa.substring(0, 6);
  }
  return rrggbbaa;
}

void _emitMeasured(StringBuffer out) {
  out
    ..writeln('/// Metrics measured from the rendered reference rather than read from a')
    ..writeln('/// custom property.')
    ..writeln('///')
    ..writeln(
        '/// The reference hardcodes most of these in CSS and never exposes them as')
    ..writeln('/// tokens, so listing them beside token-derived values would imply a')
    ..writeln('/// provenance they do not have. Each records where it was measured so it')
    ..writeln('/// can be re-measured rather than trusted indefinitely.')
    ..writeln('@immutable')
    ..writeln('class LogosMeasured {')
    ..writeln('  const LogosMeasured._();')
    ..writeln();

  var first = true;
  for (final entry in measuredMetrics.entries) {
    final m = entry.value;
    if (!first) out.writeln();
    first = false;
    out.writeln('  /// ${_trimNum(m.value)} — ${m.source}');
    if (m.note.isNotEmpty) {
      out.writeln('  ///');
      for (final line in _wrap(m.note, 70)) {
        out.writeln('  /// $line');
      }
    }
    out.writeln('  static const double ${entry.key} = ${_trimNum(m.value)};');
  }
  out
    ..writeln('}')
    ..writeln();
}

void _emitTypeScale(StringBuffer out) {
  const brand = "'BrandLogos', 'Alaska', 'Source Sans Pro', sans-serif";
  out
    ..writeln("/// The type scale, read from the reference's own computed body style.")
    ..writeln('///')
    ..writeln('/// The reference declares `$brand`. Its first two faces, BrandLogos and')
    ..writeln('/// Alaska, are Logos display faces that cannot be redistributed, so the')
    ..writeln(
        "/// third entry is substituted. Source Sans Pro is the reference's own body")
    ..writeln('/// face, so the substitution affects display type only.')
    ..writeln('///')
    ..writeln(
        '/// Adobe renamed Source Sans Pro to Source Sans 3 upstream; it is the same')
    ..writeln(
        '/// typeface continued, and is bundled here under that name. The files are')
    ..writeln('/// SIL Open Font License 1.1, in `assets/fonts/OFL.txt`.')
    ..writeln('@immutable')
    ..writeln('class LogosTypeScale {')
    ..writeln('  const LogosTypeScale._();')
    ..writeln()
    ..writeln("  static const String family = 'SourceSansPro';")
    ..writeln()
    ..writeln('  /// 16px, weight 400, 1.5 line height, from the computed style of the')
    ..writeln("  /// reference's document body element.")
    ..writeln('  static const double bodySize = 16;')
    ..writeln('  static const double bodyLineHeight = 1.5;')
    ..writeln()
    ..writeln('  /// Scripture is set looser than interface text, so a chapter reads as')
    ..writeln('  /// prose rather than as a list of labelled items.')
    ..writeln('  static const double scriptureLineHeight = 1.6;')
    ..writeln()
    ..writeln('  /// The superscript verse marker.')
    ..writeln('  static const double verseNumberSize = 10;')
    ..writeln('}');
}

String _trimNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

List<String> _wrap(String text, int width) {
  final lines = <String>[];
  var current = '';
  for (final w in text.split(' ')) {
    if (current.isEmpty) {
      current = w;
    } else if (current.length + 1 + w.length <= width) {
      current = '$current $w';
    } else {
      lines.add(current);
      current = w;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

String _header(int tokenCount) => '''
// GENERATED FILE — do not edit by hand.
//
//     dart run tool/generate_theme.dart
//
// Source: ../docs/research/design-tokens.json — the $tokenCount
// `--bible-study-theme-*` custom properties captured from the live application.
// `test/theme_parity_test.dart` regenerates this in memory and fails if the
// committed values drift from the source.
//
// The values are machine-transcribed from the reference rather than written by eye.
// That distinction is not pedantic: the active tab accent is #ff6600 in the
// reference, orange rather than the brand blue, and reading it by hand gets it
// wrong.

import 'package:flutter/widgets.dart';
''';
