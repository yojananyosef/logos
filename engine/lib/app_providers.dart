import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/bible_repository.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/search_repository.dart';
import 'data/services/module_installer.dart';
import 'domain/models/passage_ref.dart';
import 'ui/features/library/view_models/library_view_model.dart';
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

final libraryViewModelProvider = ChangeNotifierProvider<LibraryViewModel>((ref) {
  final vm = LibraryViewModel(
    repository: ref.watch(bibleRepositoryProvider),
    installer: ref.watch(moduleInstallerProvider),
    source: ref.watch(localModuleSourceProvider),
    catalogService: ref.watch(catalogServiceProvider),
  );
  // Rebuilding the library when the module directory changes is deliberate: installing a
  // module is what makes it appear, and a stale list would be the bug.
  ref.watch(moduleStoreProvider);
  return vm;
});

/// One reader per module id, so switching between two open Bibles does not discard the
/// chapter each was showing.
final readerViewModelProvider =
    ChangeNotifierProvider.family<ReaderViewModel, String>((ref, moduleId) {
  return ReaderViewModel(ref.watch(bibleRepositoryProvider));
});
