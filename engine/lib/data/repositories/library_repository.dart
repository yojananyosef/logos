import 'dart:convert';
import 'dart:io';

import '../../domain/models/catalog.dart';
import '../../domain/models/license.dart';

/// A catalog entry paired with its installation state.
class LibraryEntry {
  const LibraryEntry({
    required this.resource,
    this.localPath,
    this.installed = false,
  });

  final ResourceDescriptor resource;
  final String? localPath;
  final bool installed;

  /// Whether the resource may be shown at all right now.
  ///
  /// A resource whose licence has not expired is not merely "not available yet" — it
  /// must not appear as something the user can install, because a catalogue that lists
  /// content it is not permitted to distribute is misleading about itself. The engine
  /// has no way to enforce this by accident, so the state is computed and the view
  /// filters on it.
  bool isDistributableNow() =>
      resource.license.isDistributable(now: DateTime.now().toUtc());

  /// When the resource becomes distributable, if it ever does.
  DateTime? get releaseDate {
    final d = resource.license.releaseDate;
    return d.year <= 1970 ? null : d;
  }
}

/// The state of one install in progress.
class InstallProgress {
  const InstallProgress({
    required this.id,
    required this.stage,
    this.detail,
  });

  final String id;

  /// Coarse, because the underlying steps are not worth distinguishing in a list row.
  final InstallStage stage;
  final String? detail;
}

enum InstallStage { queued, verifying, extracting, done, failed }

/// The library: the catalog, what is installed, and the transition between them.
class LibraryState {
  const LibraryState({
    this.entries = const [],
    this.inProgress = const {},
    this.failures = const {},
    this.catalogVersion,
    this.loaded = false,
  });

  /// Catalog entries, installed or not.
  final List<LibraryEntry> entries;

  final Map<String, InstallProgress> inProgress;
  final Map<String, String> failures;
  final String? catalogVersion;

  /// False until the first read completes, so the view can distinguish "loading" from
  /// "loaded and empty" — a genuinely empty library is a real state a user reaches.
  final bool loaded;

  List<LibraryEntry> get installed => entries.where((e) => e.installed).toList();

  List<LibraryEntry> get available =>
      entries.where((e) => !e.installed && e.isDistributableNow()).toList();

  /// Catalogued but not yet distributable. Shown, but not installable.
  List<LibraryEntry> get pending =>
      entries.where((e) => !e.installed && !e.isDistributableNow()).toList();

  List<LibraryEntry> byType(ResourceType t) =>
      entries.where((e) => e.resource.type == t).toList(growable: false);
}

/// Reads catalog files and reports their licensing state.
///
/// A catalog is data from another repository, and this repository's own gate has already
/// decided what may ship. The engine's job here is narrower but still load-bearing: it
/// must not offer to install something its licence does not permit today.
class CatalogService {
  const CatalogService();

  /// Parses a catalog index.
  ///
  /// Returns null on anything unreadable rather than throwing. A corrupt catalog must
  /// leave the user with their already-installed content, not with a broken library and
  /// an error screen — the installed modules are independent of the catalog and remain
  /// perfectly usable.
  Catalog? parse(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final modules = (decoded['modules'] as List<dynamic>?) ?? const [];
      return Catalog(
        format: decoded['format'] as String? ?? '',
        version: decoded['version'] as String? ?? '0.0.0',
        entries: [
          for (final m in modules) CatalogEntry(_resource(m as Map<String, dynamic>)),
        ],
      );
    } on Object {
      return null;
    }
  }

  Catalog? parseFile(File file) {
    if (!file.existsSync()) return null;
    return parse(file.readAsStringSync());
  }

  ResourceDescriptor _resource(Map<String, dynamic> m) {
    final lic = m['license'] as Map<String, dynamic>? ?? const {};
    return ResourceDescriptor(
      id: m['id'] as String? ?? '',
      type: _type(m['type'] as String?),
      name: m['name'] as String? ?? '',
      shortName: m['shortName'] as String? ?? m['id'] as String? ?? '',
      language: m['language'] as String? ?? '',
      direction: m['direction'] as String? ?? 'ltr',
      version: m['version'] as String? ?? '0.0.0',
      publisher: m['publisher'] as String?,
      sha256: m['sha256'] as String?,
      sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
      downloadUrl: m['downloadUrl'] as String?,
      granularity: _granularity(m['granularity'] as String?),
      genre: m['genre'] as String?,
      license: LicenseInfo(
        kind: _license(lic['id'] as String?),
        attribution: lic['attribution'] as String? ?? '',
        sourceUrl: lic['sourceUrl'] as String? ?? '',
        releaseDate:
            DateTime.tryParse(lic['releaseDate'] as String? ?? '') ?? DateTime.utc(1970),
        jurisdictions: ((lic['jurisdictions'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString().toUpperCase())
            .toSet(),
        basis: lic['basis'] as String?,
      ),
    );
  }

  static ResourceType _type(String? raw) {
    for (final t in ResourceType.values) {
      if (t.name == raw) return t;
    }
    return ResourceType.bible;
  }

  static Granularity _granularity(String? raw) => switch (raw) {
        'verse' => Granularity.verse,
        'chapter' => Granularity.chapter,
        'book' => Granularity.book,
        _ => Granularity.verse,
      };

  /// An unrecognised licence resolves to null rather than defaulting to public domain.
  ///
  /// Defaulting would be the dangerous direction: a catalog with a typo in a licence
  /// field would be treated as giving away content freely.
  static LicenseKind? _license(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v == 'publicdomain' || v == 'public domain') return LicenseKind.publicDomain;
    for (final k in LicenseKind.values) {
      if (k.spdxSuffix.toLowerCase() == v) return k;
      if (k.name.toLowerCase() == v) return k;
    }
    return null;
  }
}
