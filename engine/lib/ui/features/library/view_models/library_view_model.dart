import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/bible_repository.dart';
import '../../../../data/repositories/library_repository.dart';
import '../../../../data/services/module_installer.dart';
import '../../../../domain/models/catalog.dart';
import '../../../../domain/models/library_query.dart';
import '../../../../domain/models/license.dart';
import 'library_view_preferences.dart';

/// How a resource is fetched.
///
/// Kept abstract because it is the seam that matters: the library's behaviour must be
/// identical whether a module arrives from a network catalog, a local directory or a
/// test fixture. Tests exercise the whole install path with no network at all, which is
/// only possible because the transport is not baked into the ViewModel.
abstract class ModuleSource {
  Future<List<int>> fetch(String url, {String? expectedSha256});
}

/// Reads modules from the local filesystem.
///
/// A `downloadUrl` may be a `file:` URL or a bare path; both are what a developer typing
/// a path by hand produces, and neither needs a network. A `http:`/`https:` URL is
/// rejected with a message that says so, because otherwise the failure is
/// `no module at https://…` — which reads as a missing file and sends the reader looking
/// in the wrong place.
class LocalModuleSource implements ModuleSource {
  const LocalModuleSource(this.root);

  final Directory root;

  @override
  Future<List<int>> fetch(String url, {String? expectedSha256}) async {
    final file = _resolve(url);
    if (!file.existsSync()) {
      throw StateError('no module at $url (looked in ${file.path})');
    }
    return file.readAsBytes();
  }

  /// Turns a catalog URL into a file.
  ///
  /// A `file:` URL is decoded rather than treated as a path: on Windows a `file:///C:/…`
  /// URL contains percent-encoding and a leading slash the path does not have, and taking
  /// the string literally produces a path that does not exist.
  File _resolve(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      throw StateError(
        'LocalModuleSource cannot fetch $url. It reads the filesystem; a network module '
        'needs a ModuleSource that speaks HTTP.',
      );
    }
    if (url.startsWith('file://')) {
      return File(Uri.parse(url).toFilePath());
    }
    // A relative path is resolved against the module directory rather than the process's
    // working directory, which is somewhere else entirely on a desktop platform.
    final candidate = File(url);
    return candidate.isAbsolute ? candidate : File('${root.path}/$url');
  }
}

/// What the library is doing right now.
enum LibraryStatus {
  /// Before the first read completes. The view shows a progress indicator, because "not
  /// loaded yet" and "loaded and empty" are different states and only one of them is a
  /// reason to wait.
  loading,

  /// The catalog and the installed tree have been read.
  ready,

  /// The read failed. [LibraryViewModel.retry] re-runs it.
  failed,
}

/// ViewModel for the library.
///
/// Holds presentation state and commands only. It does not open a database, verify a
/// hash, or parse a catalog — those belong to the services and repositories injected
/// here, which is what keeps the view testable without any content on disk.
class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    required this.repository,
    required this.installer,
    required this.source,
    required this.catalogService,
    LibraryViewPreferencesStore? viewPreferences,
  }) : _viewPreferences = viewPreferences;

  final BibleRepository repository;
  final ModuleInstaller installer;
  final ModuleSource source;
  final CatalogService catalogService;
  final LibraryViewPreferencesStore? _viewPreferences;

  LibraryState _state = const LibraryState();
  LibraryState get state => _state;

  LibraryStatus _status = LibraryStatus.loading;
  LibraryStatus get status => _status;

  /// Why the last load failed, when it did.
  String? _error;
  String? get error => _error;

  LibraryQuery _query = const LibraryQuery();
  LibraryQuery get query => _query;

  /// The catalog JSON the last successful load used, kept so [retry] and [refresh] can
  /// repeat it without the caller having to hold on to it.
  String? _catalogJson;

  /// The rows the current query selects, in order.
  ///
  /// The single answer to "what does the list show", which the view's count and the view's
  /// rows both read. Computing it twice would let them disagree, and a count that does not
  /// match the number of rows below it is worse than no count.
  List<LibraryEntry> get visible => _query.apply(_state.entries);

  /// How many of everything the catalog knows about, before the query narrows it.
  ///
  /// Separate from [visible] because the two answer different questions: one is "how much
  /// could I have", the other is "how many am I looking at". Only the second is the
  /// filter's fault.
  int get totalCount => _state.entries.length;

  /// Loads the catalog and reconciles it against what is installed.
  ///
  /// The catalog is optional. A user with modules on disk and no catalog — or a corrupt
  /// one — still gets a working library built from what is actually installed, because
  /// installed content is the part that matters and the catalog is only a description of
  /// what else exists. A corrupt catalog is therefore *not* an error: it degrades to the
  /// installed set, which is a working library, and treating it as a failure would show an
  /// error screen over content the user can already read.
  ///
  /// What *is* an error is being unable to read the installed tree at all, because that is
  /// the content itself. That one is reported, with [retry].
  Future<void> load({String? catalogJson}) async {
    _catalogJson = catalogJson;
    _status = LibraryStatus.loading;
    _error = null;
    notifyListeners();

    List<InstalledModule> installed;
    try {
      installed = await repository.listInstalled();
    } on Object catch (e) {
      // The installed set could not be read. Nothing can be shown that is not in it, and
      // unlike a corrupt catalog this is not recoverable by falling back — there is no
      // fallback, because this *is* the fallback's source.
      _state = const LibraryState(loaded: true);
      _status = LibraryStatus.failed;
      _error = 'No se pudo leer el contenido instalado: $e';
      notifyListeners();
      return;
    }

    final installedIds = <String, String>{};
    for (final module in installed) {
      installedIds[module.id] = module.path;
    }

    final catalog = catalogJson == null ? null : catalogService.parse(catalogJson);

    if (catalog == null) {
      _state = LibraryState(
        entries: [
          for (final module in installed)
            LibraryEntry(
              resource: ResourceDescriptor(
                id: module.id,
                type: module.type,
                name: module.name,
                shortName: module.shortName,
                language: module.language,
                version: 'installed',
                license: LicenseInfo.publicDomain(
                  sourceUrl: '',
                  basis:
                      'Installed locally; licence recorded by the catalog it came from.',
                ),
              ),
              localPath: module.path,
              installed: true,
            ),
        ],
        catalogVersion: null,
        loaded: true,
      );
      _status = LibraryStatus.ready;
      notifyListeners();
      return;
    }

    _state = LibraryState(
      entries: [
        for (final entry in catalog.entries)
          LibraryEntry(
            resource: entry.resource,
            localPath: installedIds[entry.resource.id],
            installed: installedIds.containsKey(entry.resource.id),
          ),
      ],
      catalogVersion: catalog.version,
      loaded: true,
    );
    _status = LibraryStatus.ready;
    notifyListeners();
  }

  /// Re-runs the last load, after a failure or after the module directory changed.
  Future<void> retry() => load(catalogJson: _catalogJson);

  /// Re-reads the installed tree, keeping the catalog.
  ///
  /// What the workspace calls after an install performed by other means, so the library
  /// cannot keep showing a resource that is already on disk as not installed.
  Future<void> refresh() => load(catalogJson: _catalogJson);

  void setScope(LibraryScope scope) => _setQuery(_query.copyWith(scope: scope));

  void setSort(LibrarySort sort) => _setQuery(_query.copyWith(sort: sort));

  /// Filters as the user types.
  void setSearchText(String text) => _setQuery(_query.copyWith(text: text));

  /// Switches between grid and list, and remembers the choice.
  ///
  /// The write is fire-and-forget for the same reason the reader's is: blocking the toggle
  /// on storage would make changing a view mode feel like saving a document, and a failed
  /// write costs the next session a preference and nothing else.
  void setViewMode(LibraryViewMode mode) {
    _setQuery(_query.copyWith(viewMode: mode));
    _viewPreferences?.write(mode).catchError(
      (Object e) => debugPrint('library view mode could not be written: $e'),
    );
  }

  /// Reads the stored view mode and applies it.
  ///
  /// Called once at startup, alongside [load]. A read failure is not surfaced: the library
  /// works without it, and a storage error must not be the reason a Bible cannot be
  /// opened. The in-memory default leaves the user on the list view, which is the mode
  /// that is readable at every width — a stored grid on a phone would open into a single
  /// column that looks like a list with extra steps.
  Future<void> loadViewMode() async {
    final store = _viewPreferences;
    if (store == null) return;
    try {
      final stored = await store.read();
      if (stored != null && stored != _query.viewMode) {
        _query = _query.copyWith(viewMode: stored);
        notifyListeners();
      }
    } on Object catch (e) {
      debugPrint('library view mode could not be read, using the default: $e');
    }
  }

  void _setQuery(LibraryQuery next) {
    if (next == _query) return;
    _query = next;
    notifyListeners();
  }

  /// Installs one resource.
  ///
  /// Both gates run before any bytes are requested, not after. Fetching first and deciding
  /// afterwards would mean the application had already pulled restricted content — or
  /// content it could not verify — onto the device in order to then refuse it.
  Future<void> install(String id) async {
    final entry = _state.entries.where((e) => e.resource.id == id).firstOrNull;
    if (entry == null) return;

    if (!entry.isDistributableNow()) {
      _fail(id, 'still under copyright until ${entry.releaseDate}');
      return;
    }

    if (!entry.hasVerifiableSource) {
      _fail(id, 'the catalog gives no sha256 for this resource, so a download of it '
          'could not be verified');
      return;
    }

    final url = entry.resource.downloadUrl;
    if (url == null || url.isEmpty) {
      _fail(id, 'the catalog gives no source for this resource');
      return;
    }

    _stage(id, InstallStage.verifying);
    try {
      final bytes = await source.fetch(url, expectedSha256: entry.resource.sha256);
      _stage(id, InstallStage.extracting);
      final result = await installer.install(
        id,
        bytes: bytes,
        expectedSha256: entry.resource.sha256,
      );

      if (result.status == InstallStatus.ok) {
        final path = installer.store.pathFor(id).path;
        _state = LibraryState(
          entries: [
            for (final e in _state.entries)
              e.resource.id == id
                  ? LibraryEntry(
                      resource: e.resource,
                      localPath: path,
                      installed: true,
                    )
                  : e,
          ],
          inProgress: {..._state.inProgress}..remove(id),
          failures: {..._state.failures}..remove(id),
          catalogVersion: _state.catalogVersion,
          loaded: true,
        );
      } else {
        _fail(id, result.message ?? result.status.name);
      }
    } on Object catch (e) {
      _fail(id, '$e');
    }
    notifyListeners();
  }

  Future<void> uninstall(String id) async {
    await installer.uninstall(id);
    _state = LibraryState(
      entries: [
        for (final e in _state.entries)
          e.resource.id == id ? LibraryEntry(resource: e.resource) : e,
      ],
      catalogVersion: _state.catalogVersion,
      loaded: true,
    );
    notifyListeners();
  }

  void _stage(String id, InstallStage stage) {
    _state = LibraryState(
      entries: _state.entries,
      inProgress: {..._state.inProgress, id: InstallProgress(id: id, stage: stage)},
      failures: _state.failures,
      catalogVersion: _state.catalogVersion,
      loaded: true,
    );
    notifyListeners();
  }

  void _fail(String id, String message) {
    _state = LibraryState(
      entries: _state.entries,
      inProgress: {..._state.inProgress}..remove(id),
      failures: {..._state.failures, id: message},
      catalogVersion: _state.catalogVersion,
      loaded: true,
    );
    notifyListeners();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
