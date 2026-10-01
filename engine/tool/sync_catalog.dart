// Copies the catalog index from the content repository into this one, as a bundled asset.
//
//     dart run tool/sync_catalog.dart            # copy
//     dart run tool/sync_catalog.dart --check    # verify, exit 1 on drift
//
// The engine ships the catalog *index* — resource names, licences, hashes, URLs — and not
// the content it points at. That is the distinction this tool exists to keep sharp: an index
// is metadata the application needs before it can show anything, and a payload is scripture
// that must stay in its own repository. D4 separates them; bundling the index does not
// move a line of scripture across the boundary.
//
// The `--check` mode is what `test/catalog_sync_test.dart` runs. A bundled file that nobody
// remembers to regenerate is a bundled file that is wrong within a release, and the failure
// would be invisible: the library would list seventeen resources with hashes for binaries
// that no longer exist, and every install would fail on a checksum.
import 'dart:convert';
import 'dart:io';

/// The content repository, as a sibling of this one. The same relationship the README
/// describes and the same relative path it uses.
const _catalogRepoRelative = '../logos-catalogs';

const _source = '$_catalogRepoRelative/catalog/catalog.json';
const _destination = 'assets/catalog/catalog.json';

Future<int> run(List<String> args) async {
  final check = args.contains('--check');

  final source = File(_source);
  if (!source.existsSync()) {
    stderr.writeln('no catalog at $_source');
    stderr.writeln('The content repository is expected beside this one, at '
        '$_catalogRepoRelative. Clone it, or pass a path.');
    return 66;
  }

  final raw = source.readAsStringSync();

  // Validated before it is copied. Copying an index the engine cannot parse would leave
  // the application with a bundled catalog that silently parses to nothing, and the
  // fallback for that is a library that lists installed modules and installs nothing —
  // the same inert first run this catalog is here to fix.
  try {
    final decoded = jsonDecode(raw);
    final modules = (decoded as Map<String, dynamic>)['modules'] as List<dynamic>?;
    if (modules == null || modules.isEmpty) {
      stderr.writeln('$_source declares no modules');
      return 65;
    }
  } on Object catch (e) {
    stderr.writeln('$_source is not readable as a catalog: $e');
    return 65;
  }

  final target = File(_destination);

  if (check) {
    if (!target.existsSync()) {
      stderr.writeln('$_destination does not exist. Run: dart run tool/sync_catalog.dart');
      return 1;
    }
    if (!_sameContent(target.readAsStringSync(), raw)) {
      stderr.writeln('$_destination has drifted from $_source. '
          'Run: dart run tool/sync_catalog.dart');
      return 1;
    }
    stdout.writeln('$_destination matches $_source');
    return 0;
  }

  target.parent.createSync(recursive: true);
  // Written through a temporary file and renamed, because a half-written catalog that
  // parses to null is indistinguishable from no catalog at all.
  final staged = File('$_destination.tmp')
    ..writeAsStringSync(_normalise(raw), flush: true);
  staged.renameSync(_destination);

  final modules = ((jsonDecode(raw) as Map<String, dynamic>)['modules'] as List).length;
  stdout.writeln('wrote $_destination ($modules resources)');
  return 0;
}

/// Compares two catalogs by value rather than by bytes.
///
/// Byte comparison would fail on trailing whitespace or a CRLF checkout, which are not the
/// kind of drift this tool exists to catch. What matters is that the two files declare the
/// same thing.
bool _sameContent(String a, String b) => _canonical(a) == _canonical(b);

/// The catalog re-encoded with stable key order and two-space indentation.
///
/// Stable because the committed file is meant to be reviewable as a diff, and a re-encoded
/// file that reorders its keys on every run would make every sync a whole-file change.
String _canonical(String raw) {
  final decoded = jsonDecode(raw);
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert(_sorted(decoded))}\n';
}

String _normalise(String raw) => _canonical(raw);

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {
      for (final k in keys) k: _sorted(value[k]),
    };
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}

Future<void> main(List<String> args) async {
  exitCode = await run(args);
}
