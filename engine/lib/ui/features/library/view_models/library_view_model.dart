import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/bible_repository.dart';
import '../../../../data/repositories/library_repository.dart';
import '../../../../data/services/module_installer.dart';
import '../../../../domain/models/catalog.dart';
import '../../../../domain/models/license.dart';

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
/// Also the development path: a module dropped into the modules directory appears in the
/// library without a catalog, which is how content gets tested against a real module
/// before it is published.
class LocalModuleSource implements ModuleSource {
  const LocalModuleSource(this.root);

  final Directory root;

  @override
  Future<List<int>> fetch(String url, {String? expectedSha256}) async {
    final file = File(url);
    if (!file.existsSync()) {
      throw StateError('no module at $url');
    }
    return file.readAsBytes();
  }
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
  });

  final BibleRepository repository;
  final ModuleInstaller installer;
  final ModuleSource source;
  final CatalogService catalogService;

  LibraryState _state = const LibraryState();
  LibraryState get state => _state;

  /// Loads the catalog and reconciles it against what is installed.
  ///
  /// The catalog is optional. A user with modules on disk and no catalog — or a corrupt
  /// one — still gets a working library built from what is actually installed, because
  /// installed content is the part that matters and the catalog is only a description of
  /// what else exists.
  Future<void> load({String? catalogJson}) async {
    final installedIds = <String, String>{};
    for (final module in await repository.listInstalled()) {
      installedIds[module.id] = module.path;
    }

    final catalog = catalogJson == null ? null : catalogService.parse(catalogJson);

    if (catalog == null) {
      _state = LibraryState(
        entries: [
          for (final module in await repository.listInstalled())
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
    notifyListeners();
  }

  /// Installs one resource.
  ///
  /// The licence check happens before any bytes are requested, not after. Fetching
  /// first and deciding afterwards would mean the application had already pulled
  /// restricted content onto the device in order to then refuse it.
  Future<void> install(String id) async {
    final entry = _state.entries.where((e) => e.resource.id == id).firstOrNull;
    if (entry == null) return;

    if (!entry.isDistributableNow()) {
      _fail(id, 'still under copyright until ${entry.releaseDate}');
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
