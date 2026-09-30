import '../../data/services/amf_reader.dart';
import '../../data/services/module_installer.dart';
import '../../domain/models/catalog.dart';

/// One installed module, as the application sees it.
class InstalledModule {
  const InstalledModule({
    required this.id,
    required this.name,
    required this.shortName,
    required this.type,
    required this.language,
    required this.license,
    required this.path,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final String shortName;
  final ResourceType type;
  final String language;
  final String license;
  final String path;
  final int sizeBytes;
}

/// The result of opening a module, including anything wrong with it.
///
/// Integrity is reported alongside the module rather than raised as an error, because a
/// module with a data defect is still readable — just not complete, and the user is
/// better served by being told which chapters are affected than by being refused the
/// whole Bible.
class OpenedModule {
  const OpenedModule({
    required this.id,
    required this.books,
    required this.integrity,
    required this.connection,
    required this.reader,
    required this.dao,
  });

  final String id;
  final List<AmfBook> books;
  final IntegrityReport integrity;
  final AmfModuleDatabase connection;
  final AmfModuleReader reader;
  final AmfBibleDao dao;

  bool get isSound => integrity.isValid;
}

/// Reads installed modules and exposes them as domain objects.
///
/// The only place that knows a module is a zip containing SQLite. Everything above it
/// works with books, chapters and verses, which is what lets the reader be written once
/// and used for any catalog.
class BibleRepository {
  BibleRepository(this._store);

  final ModuleStore _store;

  /// Open modules, so a module is not re-unpacked and re-verified on every navigation.
  final Map<String, OpenedModule> _open = {};

  /// Lists what is installed, by reading each module's manifest.
  ///
  /// Manifests are read rather than the database, because a library listing may span
  /// hundreds of resources and opening each one to learn its name would make the list
  /// slower the more content the user had.
  Future<List<InstalledModule>> listInstalled() async {
    final out = <InstalledModule>[];
    for (final file in _store.installedModules()) {
      final id = file.uri.pathSegments.last.replaceAll('.amod', '');
      final manifest = await _installer().readManifest(id);
      out.add(InstalledModule(
        id: id,
        name: manifest?.name.isNotEmpty == true ? manifest!.name : id,
        shortName: manifest?.shortName.isNotEmpty == true ? manifest!.shortName : id,
        type: _resourceType(manifest?.type),
        language: manifest?.language ?? '',
        license: manifest?.license ?? 'PublicDomain',
        path: file.path,
        sizeBytes: file.lengthSync(),
      ));
    }
    return out;
  }

  /// Opens a module, verifying it and checking its integrity.
  ///
  /// [expectedSha256] comes from the catalog. Passing null skips verification, which is
  /// only appropriate for a module the user placed there themselves.
  Future<OpenedModule> open(String id, {String? expectedSha256}) async {
    final cached = _open[id];
    if (cached != null) return cached;

    final file = _store.pathFor(id);
    if (!file.existsSync()) {
      throw StateError('module $id is not installed');
    }

    final reader = AmfModuleReader(expectedSha256: expectedSha256);
    final connection = await reader.openFromFile(file);
    final dao = AmfBibleDao(connection);
    final books = await dao.books();
    final integrity = await const AmfIntegrityChecker().check(connection);

    final opened = OpenedModule(
      id: id,
      books: books,
      integrity: integrity,
      connection: connection,
      reader: reader,
      dao: dao,
    );
    _open[id] = opened;
    return opened;
  }

  Future<List<AmfVerse>> chapter(String id, String osisCode, int chapter) async =>
      (await open(id)).dao.chapter(osisCode, chapter);

  Future<List<AmfVerse>> verse(
          String id, String osisCode, int chapter, int verse) async =>
      (await open(id)).dao.singleVerse(osisCode, chapter, verse);

  Future<List<AmfSearchHit>> search(String id, String query, {int limit = 50}) async =>
      (await open(id)).dao.search(query, limit: limit);

  /// Closes every open module and removes the staged temporary databases.
  void dispose() {
    for (final m in _open.values) {
      m.reader.dispose();
      m.connection.close();
    }
    _open.clear();
  }

  ModuleInstaller _installer() => ModuleInstaller(_store);

  static ResourceType _resourceType(String? raw) {
    for (final t in ResourceType.values) {
      if (t.name == raw) return t;
    }
    return ResourceType.bible;
  }
}
