import 'license.dart';

/// The resource kinds a catalog may contain.
///
/// Mirrors the AMF `type` discriminator, with `words` added for the per-word
/// Strong's/morphology table that v1.1 of the format introduces.
enum ResourceType { bible, commentary, lexicon, dictionary, crossref, devotion, words }

ResourceType resourceTypeFromString(String raw) {
  for (final t in ResourceType.values) {
    if (t.name == raw) return t;
  }
  throw FormatException('unknown resource type "$raw"');
}

/// A resource as declared by a catalog.
class ResourceDescriptor {
  const ResourceDescriptor({
    required this.id,
    required this.type,
    required this.name,
    required this.shortName,
    required this.language,
    required this.version,
    required this.license,
    this.publisher,
    this.direction = 'ltr',
    this.sha256,
    this.sizeBytes = 0,
    this.downloadUrl,
    this.granularity = Granularity.verse,
    this.genre,
  });

  final String id;
  final ResourceType type;
  final String name;
  final String shortName;
  final String language;
  final String direction;
  final String version;
  final LicenseInfo license;
  final String? publisher;

  /// Content hash. Distribution integrity depends on this, not on transport.
  final String? sha256;
  final int sizeBytes;
  final String? downloadUrl;

  /// At what address the commentary's notes attach. Decides whether the reader can
  /// show notes per verse or only per chapter, and the UI must label it.
  final Granularity granularity;

  /// Critical / expository / homiletic / devotional. Prevents a reader mistaking a
  /// devotional for a critical commentary.
  final String? genre;

  bool get isScripture => type == ResourceType.bible || type == ResourceType.crossref;
}

/// Where a commentary's entries attach.
enum Granularity { verse, chapter, book }

Granularity granularityFromString(String raw) => switch (raw) {
      'verse' => Granularity.verse,
      'chapter' => Granularity.chapter,
      'book' => Granularity.book,
      _ => throw FormatException('unknown granularity "$raw"'),
    };

/// One entry in the catalog index.
class CatalogEntry {
  const CatalogEntry(this.resource, {this.localPath, this.installed = false});

  final ResourceDescriptor resource;

  /// Where the verified `.amod` sits on disk, once installed.
  final String? localPath;
  final bool installed;
}

/// A catalog: a versioned, self-describing set of resources.
class Catalog {
  const Catalog({
    required this.format,
    required this.version,
    required this.entries,
  });

  /// Catalog schema discriminator, e.g. `amf-catalog`.
  final String format;

  final String version;
  final List<CatalogEntry> entries;

  Iterable<ResourceDescriptor> get resources => entries.map((e) => e.resource);

  List<CatalogEntry> byType(ResourceType t) =>
      entries.where((e) => e.resource.type == t).toList(growable: false);

  /// Any resource carrying a share-alike obligation taints the whole catalog.
  bool get isShareAlike =>
      entries.any((e) => e.resource.license.kind?.isShareAlike ?? false);
}
