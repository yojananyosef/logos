// Generates `lib/ui/core/theme/logos_colors.dart` from the captured design tokens.
//
//     dart run tool/generate_theme.dart            # write
//     dart run tool/generate_theme.dart --check    # verify, exit 1 on drift
//
// The point of generating rather than transcribing is that transcription is where a 1:1
// clone quietly stops being 1:1. The active panel tab accent is `#ff6600` in the
// reference — orange, not the brand blue — and reading it by eye gets it wrong. A
// generator makes that class of mistake impossible to make silently, and `--check`
// fails the build when the committed file no longer matches its source.
import 'dart:io';

import 'theme_renderer.dart';
import 'theme_resolver.dart';

/// The captured custom properties, relative to the engine package.
const tokensPath = '../docs/research/design-tokens.json';

/// The generated file, relative to the engine package.
const outputPath = 'lib/ui/core/theme/logos_colors.dart';

Future<int> main(List<String> args) async {
  final check = args.contains('--check');

  final ResolvedTheme theme;
  try {
    theme = resolveTheme(tokensPath);
  } on StateError catch (e) {
    stderr.writeln(e.message);
    stderr.writeln('run this from the engine package directory');
    return 66;
  }

  stdout.writeln('read ${theme.tokens.length} theme tokens from $tokensPath');

  if (theme.missing.isNotEmpty) {
    stderr.writeln('\nFAILED — ${theme.missing.length} bound token(s) do not resolve:');
    for (final m in theme.missing) {
      stderr.writeln('  $m');
    }
    stderr.writeln('\nA missing token means the reference renamed or removed it. '
        'Re-derive the binding in tool/token_bindings.dart rather than deleting it — '
        'silently dropping a colour is how a clone diverges.');
    return 1;
  }

  final generated = renderTheme(theme);
  final outFile = File(outputPath);

  if (!check) {
    outFile.writeAsStringSync(generated);
    stdout.writeln('wrote $outputPath (${theme.colors.length} colours, '
        '${theme.dimensions.length} dimensions)');
    return 0;
  }

  if (!outFile.existsSync()) {
    stderr.writeln('$outputPath does not exist — run without --check');
    return 1;
  }

  final current = outFile.readAsStringSync();
  if (current == generated) {
    stdout.writeln('OK — $outputPath matches $tokensPath');
    return 0;
  }

  stderr
    ..writeln('DRIFT — $outputPath no longer matches $tokensPath')
    ..writeln('run: dart run tool/generate_theme.dart');

  // Point at the first divergence. "Regenerate and diff" without a location sends
  // people looking in the wrong file.
  final a = current.split('\n');
  final b = generated.split('\n');
  final limit = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < limit; i++) {
    if (a[i] != b[i]) {
      stderr
        ..writeln('  first difference at line ${i + 1}:')
        ..writeln('    committed: ${a[i].trim()}')
        ..writeln('    generated: ${b[i].trim()}');
      break;
    }
  }
  return 1;
}
