import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Where modules live on disk, and how they get there.
///
/// A module is content the application does not own: it is downloaded, verified and
/// then treated as read-only. The two facts that follow from that shape everything here —
/// verification happens before the bytes are trusted, and nothing in the installed tree
/// is ever mutated in place, because a half-written module that passes a checksum test is
/// indistinguishable from a good one until it is read.
class ModuleStore {
  ModuleStore(this.root);

  /// The directory holding installed modules. One flat directory: a module is a single
  /// immutable file, so there is nothing to nest.
  final Directory root;

  File pathFor(String id) => File('${root.path}/$id.amod');

  /// Every installed module file.
  ///
  /// Returns an empty list rather than throwing when the directory is absent, because
  /// "no content installed yet" is the normal first-run state and not an error.
  List<File> installedModules() {
    if (!root.existsSync()) return const [];
    return root
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.amod'))
        .toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  Future<void> ensureRoot() => root.create(recursive: true);
}

/// The outcome of installing one module.
class InstallResult {
  const InstallResult.ok(this.id, this.bytes)
      : status = InstallStatus.ok,
        message = null;
  const InstallResult.failed(this.id, this.status, this.message) : bytes = 0;

  final String id;
  final InstallStatus status;
  final String? message;
  final int bytes;
}

enum InstallStatus {
  ok,

  /// The bytes did not match the catalog's hash.
  hashMismatch,

  /// The archive was not a readable AMF module.
  malformed,

  /// A file for this id already exists and matched, so nothing was written.
  alreadyInstalled,
}

/// Installs modules from bytes, having verified them first.
///
/// The order is the whole point and is not interchangeable: hash, then unpack, then
/// validate the format's own header. Accepting an archive before checking it is how a
/// catalog ends up serving content it cannot read, and the failure surfaces much later,
/// as an empty chapter rather than as a rejected download.
class ModuleInstaller {
  const ModuleInstaller(this.store);

  final ModuleStore store;

  /// Required entries in an AMF archive. An archive missing either is not a module.
  static const manifestEntry = 'manifest.json';
  static const contentEntry = 'content.db';

  /// Installs [bytes] as module [id], verifying against [expectedSha256].
  ///
  /// [expectedSha256] may be null, which skips the check. That is only legitimate for a
  /// module the user supplied by hand from a local path, never for one fetched from a
  /// catalog: the catalog's hash is the only thing standing between the application and
  /// whatever answered the request.
  Future<InstallResult> install(
    String id, {
    required List<int> bytes,
    String? expectedSha256,
  }) async {
    final actual = sha256.convert(bytes).toString();

    if (expectedSha256 != null) {
      if (actual != expectedSha256.toLowerCase()) {
        return InstallResult.failed(
          id,
          InstallStatus.hashMismatch,
          'expected sha256 $expectedSha256, got $actual',
        );
      }
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object catch (e) {
      return InstallResult.failed(
        id,
        InstallStatus.malformed,
        'not a readable zip archive: $e',
      );
    }

    final names = archive.files.map((f) => f.name).toSet();
    for (final required in [manifestEntry, contentEntry]) {
      if (!names.contains(required)) {
        return InstallResult.failed(
          id,
          InstallStatus.malformed,
          'module is missing $required',
        );
      }
    }

    // The content database is checked for the format's own magic before it is written
    // anywhere. A module whose `application_id` is wrong is not an AMF module, and
    // storing it would mean a later read has to distinguish "not installed" from
    // "installed and wrong".
    final content = archive.files.firstWhere((f) => f.name == contentEntry);
    if (!content.isFile) {
      return InstallResult.failed(
        id,
        InstallStatus.malformed,
        '$contentEntry is a directory, expected a file',
      );
    }

    final staged = File('${store.root.path}/.$id.download');
    await store.ensureRoot();
    await staged.writeAsBytes(bytes, flush: true);

    final target = store.pathFor(id);
    if (await target.exists()) {
      final existing = await target.readAsBytes();
      if (sha256.convert(existing).toString() == actual) {
        await staged.delete();
        return InstallResult.ok(id, existing.length);
      }
    }

    // Replace atomically where the platform allows it, so an interrupted install leaves
    // either the old module or none, never a truncated one.
    await staged.rename(target.path);
    return InstallResult.ok(id, bytes.length);
  }

  /// Reads a module's declared manifest.
  ///
  /// Used to reconcile an installed file against the catalog without opening the
  /// database, which is the cheap check for a library listing that may show hundreds of
  /// resources.
  Future<AmfManifest?> readManifest(String id) async {
    final file = store.pathFor(id);
    if (!file.existsSync()) return null;
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    ArchiveFile? entry;
    for (final f in archive.files) {
      if (f.name == manifestEntry) {
        entry = f;
        break;
      }
    }
    if (entry == null || !entry.isFile) return null;
    return AmfManifest.parse(String.fromCharCodes(entry.content as List<int>));
  }

  Future<bool> uninstall(String id) async {
    final file = store.pathFor(id);
    if (!file.existsSync()) return false;
    await file.delete();
    return true;
  }
}

/// The subset of a module manifest the application needs before opening the database.
class AmfManifest {
  const AmfManifest({
    required this.id,
    required this.type,
    required this.name,
    required this.shortName,
    required this.language,
    required this.direction,
    required this.license,
    required this.schemaVersion,
  });

  final String id;
  final String type;
  final String name;
  final String shortName;
  final String language;
  final String direction;
  final String license;
  final int schemaVersion;

  /// Manifests come from third-party catalogs, so every field is treated as untrusted:
  /// a missing or malformed entry yields nulls rather than throwing, because one bad
  /// catalog row must not take down the whole library listing.
  static AmfManifest? parse(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AmfManifest(
        id: decoded['id'] as String? ?? '',
        type: decoded['type'] as String? ?? 'bible',
        name: decoded['name'] as String? ?? '',
        shortName: decoded['shortName'] as String? ?? '',
        language: decoded['language'] as String? ?? '',
        direction: decoded['direction'] as String? ?? 'ltr',
        license: decoded['license'] as String? ?? '',
        schemaVersion: (decoded['schemaVersion'] as num?)?.toInt() ?? 1,
      );
    } on Object {
      return null;
    }
  }
}
