import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/bible_repository.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/search_repository.dart';
import 'data/services/module_installer.dart';
import 'domain/models/passage_ref.dart';
import 'ui/features/library/view_models/library_view_model.dart';
import 'ui/features/library/view_models/library_view_preferences.dart';
import 'ui/features/reader/view_models/reader_preferences.dart';
import 'ui/features/reader/view_models/reader_view_model.dart';
import 'ui/features/search/view_models/search_view_model.dart';

/// Dependency wiring.
///
/// Every collaborator the application needs is created here and nowhere else, so a view
/// can be rendered in a test with fakes simply by overriding its provider. That is the
/// practical payoff of the layered structure: the library screen has no idea a file
/// system exists, and the test proves it.

/// Where modules and catalogs live.
///
/// Resolved once and overridden in tests. Resolving it lazily matters because
/// `path_provider` needs the platform channel, which is not available in a plain unit
/// test — so the provider is overridable rather than being a hard dependency.
final modulesDirectoryProvider = Provider<Directory>((ref) {
  throw UnimplementedError(
    'modulesDirectoryProvider must be overridden, or supplied by bootstrap. '
    'It is not resolved automatically so that no view depends on the platform '
    'channel implicitly.',
  );
});

/// Sets the module directory. Called once at startup.
void configureModulesDirectory(Directory dir) {
  _configuredDirectory = dir;
}

Directory? _configuredDirectory;

final moduleStoreProvider = Provider<ModuleStore>((ref) {
  final configured = _configuredDirectory;
  return ModuleStore(configured ?? ref.watch(modulesDirectoryProvider));
});

final bibleRepositoryProvider = Provider<BibleRepository>(
  (ref) => BibleRepository(ref.watch(moduleStoreProvider)),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(bibleRepositoryProvider)),
);

/// Book spellings the reference parser accepts, learned at bootstrap.
///
/// The parser decides whether a token is a *reference* (`Jn 3:16`) or a *term*
/// (`Cristo`), so it has to run before a search does — on the first keystroke, with
/// nothing pending. That rules out loading the table behind a Future inside the parser,
/// which would make every keystroke wait on I/O and turn a typo into a lag. It is
/// therefore learned once during startup and read synchronously from then on, following
/// the same arrangement as [configureModulesDirectory].
///
/// Empty until bootstrap supplies it, which makes a reference unparseable rather than
/// wrong: `Jn 3:16` then searches as ordinary terms and matches nothing, instead of
/// silently resolving to the wrong chapter.
void configureBookAliases(Map<String, List<String>> aliases) {
  _configuredAliases = aliases;
}

Map<String, List<String>>? _configuredAliases;

final passageRefParserProvider = Provider<PassageRefParser>(
  (ref) => PassageRefParser(_configuredAliases ?? const {}),
);

final searchViewModelProvider = ChangeNotifierProvider<SearchViewModel>((ref) {
  return SearchViewModel(
    repository: ref.watch(searchRepositoryProvider),
    referenceParser: ref.watch(passageRefParserProvider),
  );
});

final moduleInstallerProvider = Provider<ModuleInstaller>(
  (ref) => ModuleInstaller(ref.watch(moduleStoreProvider)),
);

final catalogServiceProvider = Provider<CatalogService>(
  (ref) => const CatalogService(),
);

final localModuleSourceProvider = Provider<LocalModuleSource>(
  (ref) => LocalModuleSource(ref.watch(modulesDirectoryProvider)),
);

/// How the module's bytes are fetched.
///
/// Overridable so a build that can reach the network swaps in an HTTP source while the
/// shipped application reads only what the user put there. Resolved through
/// `modulesDirectoryProvider` so overriding the directory in a test also redirects the
/// fetch, which is what lets the whole install path run with no network at all.
final moduleSourceProvider = Provider<ModuleSource>(
  (ref) => ref.watch(localModuleSourceProvider),
);

/// The catalog index the library lists.
///
/// Supplied at startup by `main`, which is the one place allowed to read a bundled asset.
/// A null catalog is a supported state — the library then lists what is installed and
/// offers nothing to install — so this is an override rather than a hard dependency.
final catalogJsonProvider = Provider<String?>((ref) => _catalogJson);

String? _catalogJson;

/// Sets the catalog index. Called once at startup.
void configureCatalog(String? json) => _catalogJson = json;

final libraryViewModelProvider = ChangeNotifierProvider<LibraryViewModel>((ref) {
  final vm = LibraryViewModel(
    repository: ref.watch(bibleRepositoryProvider),
    installer: ref.watch(moduleInstallerProvider),
    source: ref.watch(moduleSourceProvider),
    catalogService: ref.watch(catalogServiceProvider),
    viewPreferences: ref.watch(libraryViewPreferencesStoreProvider),
  );
  // Rebuilding the library when the module directory changes is deliberate: installing a
  // module is what makes it appear, and a stale list would be the bug.
  ref.watch(moduleStoreProvider);
  // Loaded here rather than from the view, because the view has no business knowing when
  // the library should be read and a screen that forgets to call `load` is a spinner that
  // never resolves — which is exactly what this provider used to be.
  unawaited(vm.load(catalogJson: ref.watch(catalogJsonProvider)));
  unawaited(vm.loadViewMode());
  return vm;
});

/// Where the library's view mode is kept. Bootstrap supplies the real store; tests supply
/// an [InMemoryLibraryViewStore].
final libraryViewPreferencesStoreProvider =
    Provider<LibraryViewPreferencesStore>((ref) {
  throw UnimplementedError(
    'libraryViewPreferencesStoreProvider must be overridden, or supplied by bootstrap.',
  );
});

/// The reader's display settings, shared by every open Bible.
///
/// One instance for the whole application rather than one per reader: a text size is a
/// property of the person reading, not of the translation, and a per-reader instance would
/// reset every other Bible the moment the reader switched to it.
///
/// Overridable so a test can supply an in-memory store and assert that a setting survives
/// a navigation without a platform channel.
final readerPreferencesProvider =
    ChangeNotifierProvider<ReaderPreferencesViewModel>((ref) {
  return ReaderPreferencesViewModel(
    ref.watch(readerPreferencesStoreProvider),
  )..load();
});

/// Where settings are kept. Bootstrap supplies the real one; tests supply an
/// [InMemoryReaderStore].
final readerPreferencesStoreProvider = Provider<ReaderPreferencesStore>((ref) {
  throw UnimplementedError(
    'readerPreferencesStoreProvider must be overridden, or supplied by bootstrap.',
  );
});

/// One reader per module id, so switching between two open Bibles does not discard the
/// chapter each was showing.
final readerViewModelProvider =
    ChangeNotifierProvider.family<ReaderViewModel, String>((ref, moduleId) {
  return ReaderViewModel(
    ref.watch(bibleRepositoryProvider),
    ref.watch(readerPreferencesProvider),
  );
});
