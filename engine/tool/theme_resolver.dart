// Resolves Dart constant names to values from the captured design tokens.
//
// Shared by `generate_theme.dart` and `test/theme_parity_test.dart` so the parity test
// exercises the real resolution rather than a copy of it. A test that reimplemented the
// lookup would keep passing if the generator broke.

import 'dart:convert';
import 'dart:io';

import 'token_bindings.dart';

/// The captured custom-property prefix, stripped so bindings read as concepts.
const tokenPrefix = '--bible-study-theme-';

/// Outcome of resolving the token file.
class ResolvedTheme {
  const ResolvedTheme({
    required this.tokens,
    required this.colors,
    required this.dimensions,
    required this.missing,
  });

  /// Every `--bible-study-theme-*` custom property, by name.
  final Map<String, String> tokens;

  /// Dart name to `RRGGBBAA` (no leading `#`), for every bound colour.
  final Map<String, String> colors;

  /// Dart name to its numeric string, for every bound dimension.
  final Map<String, String> dimensions;

  /// Bindings whose source token is absent or unparseable. Non-empty means the
  /// reference renamed or removed the token.
  final List<String> missing;
}

/// Loads and resolves the token file at [path].
ResolvedTheme resolveTheme(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('design tokens not found at $path');
  }
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final raw = (decoded['variables'] as Map<String, dynamic>?) ?? const {};

  final tokens = <String, String>{
    for (final entry in raw.entries)
      if (entry.key.startsWith(tokenPrefix) && entry.value is String)
        entry.key.substring(tokenPrefix.length): (entry.value as String).trim(),
  };

  final missing = <String>[];
  final colors = <String, String>{};
  for (final entry in colorBindings.entries) {
    final token = tokens[entry.value];
    if (token == null) {
      missing.add('LogosColors.${entry.key} -> ${entry.value} (token absent)');
      continue;
    }
    final hex = toArgb(token);
    if (hex == null) {
      missing.add('LogosColors.${entry.key} -> ${entry.value} = "$token" '
          '(not a hex colour)');
      continue;
    }
    colors[entry.key] = hex;
  }

  final dimensions = <String, String>{};
  for (final entry in dimensionBindings.entries) {
    final token = tokens[entry.value];
    if (token == null) {
      missing.add('LogosDimensions.${entry.key} -> ${entry.value} (token absent)');
      continue;
    }
    final m = RegExp(r'^(-?[\d.]+)px$').firstMatch(token);
    if (m == null) {
      missing.add('LogosDimensions.${entry.key} -> ${entry.value} = "$token" '
          '(not a single px length)');
      continue;
    }
    dimensions[entry.key] = m.group(1)!;
  }

  return ResolvedTheme(
    tokens: tokens,
    colors: colors,
    dimensions: dimensions,
    missing: missing,
  );
}

/// Normalises `#rgb`, `#rrggbb`, `#rrggbbaa` and `#rrggbbaa` to uppercase `RRGGBBAA`,
/// which is the order `Color(0x...)` expects.
///
/// Returns null for anything that is not a concrete hex value, including `rgb()` and
/// `rgba()`. An alpha-bearing token is refused rather than approximated: silently
/// dropping an alpha produces a colour that looks right on the surface it was measured
/// on and wrong everywhere else.
String? toArgb(String raw) {
  var v = raw.trim();
  if (!v.startsWith('#')) return null;
  v = v.substring(1);
  if (RegExp(r'^[0-9a-fA-F]{3}$').hasMatch(v)) {
    v = v.split('').map((c) => '$c$c').join();
  }
  if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(v)) return null;
  final rgb = v.substring(0, 6).toUpperCase();
  // CSS `#rrggbbaa` is already the order Flutter wants.
  return v.length == 8 ? '$rgb${v.substring(6).toUpperCase()}' : '${rgb}FF';
}
