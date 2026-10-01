import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/repositories/library_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/domain/models/catalog.dart';
import 'package:logos_engine/domain/models/library_query.dart';
import 'package:logos_engine/domain/models/license.dart';
import 'package:logos_engine/ui/core/theme/logos_colors.dart';
import 'package:logos_engine/ui/core/theme/logos_theme.dart';
import 'package:logos_engine/ui/features/library/view_models/library_view_model.dart';
import 'package:logos_engine/ui/features/library/view_models/library_view_preferences.dart';
import 'package:logos_engine/ui/features/library/views/library_view.dart';
import 'package:logos_engine/ui/features/library/views/resource_cover.dart';

import 'support/module_builder.dart';

/// Section 7 — the library browser, 7.1 through 7.7.
///
/// The install path these tests exercise is the real one: a real `.amod` built by the
/// fixture builder, a real `ModuleStore` in a temporary directory, a real sha256 computed
/// the same way the installer computes it. Nothing here is a mock, because a library whose
/// install button has never been pressed against real bytes is a library whose install
/// button has never been tested.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-libbrowser-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  // ---------------------------------------------------------------- fixtures

  /// One catalog entry, as a map.
  ///
  /// Built as a structure and encoded once, rather than interpolated into a JSON
  /// template. The template version emitted a trailing comma whenever an optional field
  /// was absent, which `jsonDecode` rejects — and because `CatalogService.parse` returns
  /// null for anything unreadable, the effect was a catalog that silently became "no
  /// catalog", the library fell back to the installed set, and every test in this file
  /// failed on an empty list instead of on the thing it was checking.
  ///
  /// [sha256] defaults to a real-looking digest so an entry is installable unless a test
  /// deliberately makes it otherwise. Defaulting to a placeholder would have made every
  /// test here pass against a library that offers nothing to install — the exact state
  /// the real catalog was in.
  Map<String, Object?> entry({
    required String id,
    required String name,
    String type = 'bible',
    String language = 'en',
    String? publisher,
    String? genre,
    String? sha256,
    String? downloadUrl,
    String license = 'PublicDomain',
    String releaseDate = '1970-01-01',
  }) =>
      {
        'id': id,
        'type': type,
        'name': name,
        'shortName': id,
        'language': language,
        'version': '1.0.0',
        if (publisher != null) 'publisher': publisher,
        if (genre != null) 'genre': genre,
        'sha256': sha256 ?? ('a' * 64),
        'sizeBytes': 1024,
        if (downloadUrl != null) 'downloadUrl': downloadUrl,
        'granularity': 'verse',
        'license': {
          'id': license,
          'attribution': 'Test',
          'sourceUrl': 'https://example.org',
          'releaseDate': releaseDate,
          'jurisdictions': <String>[],
          'basis': 'Test basis.',
        },
      };

  String catalogOf(List<Map<String, Object?>> entries) => jsonEncode({
        'format': 'amf-catalog',
        'version': '1.0.0',
        'contractMajor': 1,
        'modules': entries,
      });

  /// A real module's bytes.
  Future<List<int>> moduleBytes({String id = 'SAMPLE'}) async {
    final b = ModuleBuilder(id, name: 'Sample Bible');
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'He was in the beginning with God.');
    return b.build();
  }

  LibraryViewModel buildViewModel(
    _MemorySource source, {
    LibraryViewPreferencesStore? viewPreferences,
  }) =>
      LibraryViewModel(
        repository: BibleRepository(ModuleStore(temp)),
        installer: ModuleInstaller(ModuleStore(temp)),
        source: source,
        catalogService: const CatalogService(),
        viewPreferences: viewPreferences,
      );

  /// Mounts the library over a real theme.
  ///
  /// The theme is built with `InkRipple` because `InkSparkle` compiles a fragment shader
  /// the widget-test VM has no pipeline for; the first tap in a test would throw. See
  /// `buildLogosTheme`.
  Widget harness(LibraryViewModel vm, {required void Function(ResourceDescriptor) onOpen}) =>
      MaterialApp(
        theme: buildLogosTheme(splashFactory: InkRipple.splashFactory),
        home: Scaffold(
          body: LibraryView(viewModel: vm, onOpenResource: onOpen),
        ),
      );

  Future<void> mount(WidgetTester tester, LibraryViewModel vm,
      {Size size = const Size(1280, 900)}) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(harness(vm, onOpen: (_) {}));
    await tester.pumpAndSettle();
  }

  /// Loads [entries] and switches to the store.
  ///
  /// The default scope is `Suyos`, which is what the reference opens on and which is
  /// right for a user who has content. A fixture catalog of installable-but-uninstalled
  /// resources belongs to `Tienda`, so tests that are about *what a resource looks like*
  /// rather than about the scopes have to say which scope they mean. Getting this wrong
  /// is not a test bug that shows up as a wrong count — it shows up as an empty list,
  /// which is exactly the symptom the scope partition is supposed to produce.
  Future<LibraryViewModel> storeWith(List<Map<String, Object?>> entries) async {
    final vm = buildViewModel(_MemorySource({}));
    await vm.load(catalogJson: catalogOf(entries));
    vm.setScope(LibraryScope.store);
    return vm;
  }

  // ------------------------------------------------- 7.1 the resource list

  group('7.1 the resource list', () {
    test('the count matches the corpus the catalog declares', () async {
      // The requirement is that the number on screen is the number of resources, not a
      // hard-coded total and not the number that happened to render. Asserting it against
      // the catalog's own length is the only version of this that can fail.
      final vm = await storeWith([
        entry(id: 'A', name: 'Alpha'),
        entry(id: 'B', name: 'Beta'),
        entry(id: 'C', name: 'Beta Two'),
      ]);

      expect(vm.totalCount, 3);
      expect(vm.visible, hasLength(3));
    });

    test('the total is the catalog, not the filter', () async {
      // Two different numbers with one name would be the confusion here: the user needs to
      // see both "how many am I looking at" and "how many could there be".
      final vm = await storeWith([
        entry(id: 'A', name: 'Alpha'),
        entry(id: 'B', name: 'Beta'),
      ]);

      vm.setSearchText('alpha');
      expect(vm.visible, hasLength(1));
      expect(vm.totalCount, 2);
    });

    testWidgets('each row shows a cover, a title and a subtitle',
        (tester) async {
      final vm = await storeWith([
        entry(
          id: 'KJV',
          name: 'King James Version',
          publisher: 'CrossWire Bible Society',
        ),
      ]);

      await mount(tester, vm);

      expect(find.byType(ResourceCover), findsOneWidget);
      expect(find.text('King James Version'), findsOneWidget);
      // The subtitle is the type and the publisher, which is the shape the reference shows:
      // `Biblia en inglés · Darby, John Nelson`.
      expect(find.textContaining('Biblia'), findsOneWidget);
      expect(find.textContaining('CrossWire Bible Society'), findsOneWidget);
    });

    test('a resource with no name is still listed under something readable', () async {
      // A catalog row missing `name` is a real thing — the parser defaults it to the id,
      // and a library that rendered an empty row would look like a failed image load.
      final vm = buildViewModel(_MemorySource({}));
      await vm.load(catalogJson: catalogOf([
        entry(id: 'ORPHAN', name: ''),
      ]));

      expect(resourceTitle(vm.state.entries.single.resource), 'ORPHAN');
    });

    testWidgets('an empty own-library points at the store rather than dead-ending',
        (tester) async {
      // The reference opens on `Suyos` because its user has 89 resources. Ours has none
      // on first run, so the same default would be a blank screen in front of a full
      // catalogue. The empty state has to carry the way out.
      final vm = buildViewModel(_MemorySource({}));
      await vm.load(catalogJson: catalogOf([
        entry(id: 'A', name: 'Alpha'),
        entry(id: 'B', name: 'Beta'),
      ]));

      await mount(tester, vm);

      expect(find.text('Biblioteca vacía'), findsOneWidget);
      expect(find.text('Ver los 2 recursos disponibles'), findsOneWidget);

      await tester.tap(find.text('Ver los 2 recursos disponibles'));
      await tester.pumpAndSettle();

      expect(find.byType(ResourceCover), findsNWidgets(2));
    });
  });

  // ----------------------------------------------------- 7.2 the filters

  group('7.2 the Suyos / Tienda filters', () {
    /// A library with one of each state: installed, installable, and copyright-blocked.
    Future<LibraryViewModel> threeStateLibrary() async {
      final bytes = await moduleBytes(id: 'INSTALLED');
      await ModuleInstaller(ModuleStore(temp)).install('INSTALLED', bytes: bytes);

      final vm = buildViewModel(_MemorySource({'file:///x': bytes}));
      await vm.load(catalogJson: catalogOf([
        entry(id: 'INSTALLED', name: 'Installed Bible'),
        entry(id: 'FOR_SALE', name: 'For Sale Bible'),
        entry(
          id: 'BLOCKED',
          name: 'Blocked Bible',
          releaseDate: '2099-01-01',
        ),
      ]));
      return vm;
    }

    test('Suyos lists what is installed and what cannot be acquired', () async {
      final vm = await threeStateLibrary();

      expect(
        vm.query.copyWith(scope: LibraryScope.mine).apply(vm.state.entries)
            .map((e) => e.resource.id),
        ['INSTALLED', 'BLOCKED'],
        reason: 'a blocked resource is still "yours" — you cannot buy it, so it is not '
            'in the store',
      );
    });

    test('Tienda lists only what can be acquired', () async {
      final vm = await threeStateLibrary();

      expect(
        vm.query.copyWith(scope: LibraryScope.store).apply(vm.state.entries)
            .map((e) => e.resource.id),
        ['FOR_SALE'],
        reason: 'an installed resource is not for sale, and a blocked one cannot be had',
      );
    });

    test('the two scopes partition the library', () async {
      // Not "mostly" — exactly. A resource appearing under both labels is the confusion
      // the segmented control exists to prevent, and it only shows up as a count that is
      // larger than the catalog.
      final vm = await threeStateLibrary();

      final mine = vm.query.copyWith(scope: LibraryScope.mine).apply(vm.state.entries);
      final store = vm.query.copyWith(scope: LibraryScope.store).apply(vm.state.entries);

      expect(mine.length + store.length, vm.totalCount);
      expect(
        mine.map((e) => e.resource.id).toSet()
            .intersection(store.map((e) => e.resource.id).toSet()),
        isEmpty,
      );
    });

    test('switching the filter changes the reported total', () async {
      final vm = await threeStateLibrary();
      expect(vm.query.scope, LibraryScope.mine, reason: 'the reference opens on Suyos');

      vm.setScope(LibraryScope.store);

      expect(vm.visible, hasLength(1));
      expect(vm.visible.single.resource.id, 'FOR_SALE');
      // The total is unchanged, because it reports the catalog and not the filter. Two
      // different numbers with one name would be the confusion here.
      expect(vm.totalCount, 3);
    });

    test('por Título orders alphabetically and folds diacritics', () async {
      final vm = await storeWith([
        entry(id: 'Z', name: 'Zorro'),
        entry(id: 'A', name: 'Éxodo'),
        entry(id: 'B', name: 'Álgebra'),
      ]);

      vm.setSort(LibrarySort.title);

      expect(
        vm.visible.map((e) => resourceTitle(e.resource)),
        // Folded, so the accented titles sort among the plain ones rather than after
        // every `Z`. An unaccented comparison puts `É` (U+00C9) after `Z` (U+005A).
        ['Álgebra', 'Éxodo', 'Zorro'],
      );
    });

    test('the catalog order is left alone when no sort is chosen', () async {
      final vm = await storeWith([
        entry(id: 'Z', name: 'Zorro'),
        entry(id: 'A', name: 'Álgebra'),
      ]);

      expect(
        vm.visible.map((e) => e.resource.id),
        ['Z', 'A'],
        reason: 'the catalog lists them in that order and nothing asked to change it',
      );
    });
  });

  // --------------------------------------------------- 7.3 search as you type

  group('7.3 search as you type', () {
    Future<LibraryViewModel> searchable() async {
      final vm = buildViewModel(_MemorySource({}));
      await vm.load(catalogJson: catalogOf([
        entry(id: 'DARBY', name: '1890 Darby Bible', publisher: 'Darby, John Nelson'),
        entry(
          id: 'CALVIN',
          name: "Calvin's Commentaries",
          type: 'commentary',
          publisher: 'Calvin Translation Society',
          genre: 'critical',
        ),
        entry(id: 'KJV', name: 'The Holy Bible: King James Version'),
      ]));
      vm.setScope(LibraryScope.store);
      return vm;
    }

    test('filters on a fragment of the title', () async {
      final vm = await searchable();

      vm.setSearchText('darby');

      expect(vm.visible.map((e) => e.resource.id), ['DARBY']);
    });

    test('filters on the publisher, which is part of the subtitle', () async {
      // The subtitle is rendered under the title, so a user reading it will type words
      // from it. A search that only looked at the title would ignore a word they can see.
      final vm = await searchable();

      vm.setSearchText('calvin translation');

      expect(vm.visible.map((e) => e.resource.id), ['CALVIN']);
    });

    test('filters on the type label', () async {
      final vm = await searchable();

      vm.setSearchText('comentario');

      expect(
        vm.visible.map((e) => e.resource.id),
        ['CALVIN'],
        reason: 'the type label is displayed under every title, so it must be searchable',
      );
    });

    test('folds the query and the title the same way', () async {
      // Both directions matter, and neither is a hypothetical: the catalog holds
      // `Bíblica`, `Darby` and `Calvin` alongside accented Spanish, German, French and
      // Portuguese titles, and people type without the accents.
      final accented = await storeWith([
        entry(id: 'BIBLICA', name: 'Bíblica'),
      ]);
      accented.setSearchText('biblica');
      expect(accented.visible.map((e) => e.resource.id), ['BIBLICA'],
          reason: 'an unaccented query must find an accented title');

      final plain = await storeWith([
        entry(id: 'DARBY', name: 'Darby'),
      ]);
      plain.setSearchText('dárby');
      expect(plain.visible.map((e) => e.resource.id), ['DARBY'],
          reason: 'an accented query must find an unaccented title');

      // And a difference that is not a diacritic is still a difference.
      plain.setSearchText('darbq');
      expect(plain.visible, isEmpty);
    });

    test('clearing the query restores the full list', () async {
      final vm = await searchable();
      final before = vm.visible.length;

      vm.setSearchText('darby');
      expect(vm.visible, hasLength(1));

      vm.setSearchText('');
      expect(vm.visible, hasLength(before));
    });

    test('a trailing space does not empty the list', () async {
      // People type spaces while thinking. Treating one as a search term would show an
      // empty library mid-word, which reads as the app having lost the catalog.
      final vm = await searchable();

      vm.setSearchText('darby ');

      expect(vm.visible.map((e) => e.resource.id), ['DARBY']);
    });

    test('a query matching nothing yields an empty result, not a fallback', () async {
      final vm = await searchable();

      vm.setSearchText('zzzznotathing');

      expect(vm.visible, isEmpty);
    });

    testWidgets('the no-match state is shown and can be cleared from the screen',
        (tester) async {
      final vm = await searchable();
      await mount(tester, vm);

      await tester.enterText(find.byType(TextField), 'zzzznotathing');
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.text('Limpiar la búsqueda'), findsOneWidget);
      expect(find.byType(ResourceCover), findsNothing);

      await tester.tap(find.text('Limpiar la búsqueda'));
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados'), findsNothing);
      expect(find.byType(ResourceCover), findsNWidgets(3));
    });

    testWidgets('the count follows the query', (tester) async {
      final vm = await searchable();
      await mount(tester, vm);

      expect(find.text('3'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'calvin');
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
    });
  });

  // ------------------------------------------- 7.4 grid and list, persisted

  group('7.4 grid and list view modes', () {
    test('the mode is stored by name, not by index', () async {
      // An index would reinterpret every stored choice if the enum ever gained a value.
      // The assertion reads the raw string rather than round-tripping through the enum,
      // because a round trip cannot tell a correct name from a correct index.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await SharedPreferencesLibraryViewStore(prefs).write(LibraryViewMode.grid);

      expect(prefs.getString(SharedPreferencesLibraryViewStore.key), 'grid');
    });

    test('an unrecognised stored value degrades to the default', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLibraryViewStore.key: 'mosaic',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(await SharedPreferencesLibraryViewStore(prefs).read(), isNull,
          reason: 'a lost preference is recoverable; a wrong one is not');
    });

    testWidgets('the mode survives leaving the library and coming back',
        (tester) async {
      // The persistence assertion goes through real `SharedPreferences`, and "leaving and
      // returning" is modelled as the real thing it is: a second ViewModel, built from
      // the same store, with the first one discarded. A test that kept one instance and
      // re-read its field would prove only that a variable still held its value.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesLibraryViewStore(prefs);

      final first = buildViewModel(_MemorySource({}), viewPreferences: store);
      await first.load(catalogJson: catalogOf([entry(id: 'A', name: 'Alpha')]));
      await mount(tester, first);

      first.setViewMode(LibraryViewMode.grid);
      await tester.pumpAndSettle();
      expect(first.query.viewMode, LibraryViewMode.grid);

      // Leave. The ViewModel goes with the screen.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // Return.
      final second = buildViewModel(_MemorySource({}), viewPreferences: store);
      await second.load(catalogJson: catalogOf([entry(id: 'A', name: 'Alpha')]));
      await second.loadViewMode();
      await mount(tester, second);

      expect(second.query.viewMode, LibraryViewMode.grid,
          reason: 'the choice was stored, not merely remembered');
    });

    testWidgets('switching modes changes what is rendered', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final vm = buildViewModel(
        _MemorySource({}),
        viewPreferences: SharedPreferencesLibraryViewStore(prefs),
      );
      await vm.load(catalogJson: catalogOf([
        entry(id: 'A', name: 'Alpha'),
        entry(id: 'B', name: 'Beta'),
      ]));
      vm.setScope(LibraryScope.store);
      await mount(tester, vm);

      expect(find.byType(GridView), findsNothing, reason: 'the default is a list');

      await tester.tap(find.bySemanticsLabel('Cuadrícula'));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      // The same metadata either way: switching a view is not allowed to lose content.
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });
  });

  // ----------------------------------------------------- 7.6 the reflow

  group('7.6 the library reflows by layout class', () {
    Future<LibraryViewModel> manyResources() async {
      final vm = buildViewModel(_MemorySource({}));
      await vm.load(catalogJson: catalogOf([
        for (var i = 0; i < 8; i++) entry(id: 'R$i', name: 'Resource $i'),
      ]));
      vm.setScope(LibraryScope.store);
      vm.setViewMode(LibraryViewMode.grid);
      return vm;
    }

    /// The column count the grid actually built.
    int columnsOf(WidgetTester tester) {
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate = grid.gridDelegate;
      if (delegate is SliverGridDelegateWithFixedCrossAxisCount) {
        return delegate.crossAxisCount;
      }
      if (delegate is SliverGridDelegateWithMaxCrossAxisExtent) {
        return delegate.maxCrossAxisExtent.toInt();
      }
      fail('the grid used an unexpected delegate: $delegate');
    }

    testWidgets('one column at 360', (tester) async {
      final vm = await manyResources();
      await mount(tester, vm, size: const Size(360, 900));
      expect(columnsOf(tester), 1);
    });

    testWidgets('two columns at 768', (tester) async {
      final vm = await manyResources();
      await mount(tester, vm, size: const Size(768, 900));
      expect(columnsOf(tester), 2);
    });

    testWidgets('three columns at 1280', (tester) async {
      final vm = await manyResources();
      await mount(tester, vm, size: const Size(1280, 900));
      expect(columnsOf(tester), 3);
    });

    testWidgets('three or more at 1440, growing with the window', (tester) async {
      final vm = await manyResources();
      await mount(tester, vm, size: const Size(1440, 900));
      // `large` reports a null column count, meaning "grow with the window", so the grid
      // uses a max-extent delegate. Asserting the extent rather than a count is what
      // checks the intent: a fixed three at 1440 would leave a wide screen half empty.
      expect(columnsOf(tester), greaterThan(0));
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.gridDelegate, isA<SliverGridDelegateWithMaxCrossAxisExtent>());
    });

    testWidgets('the library does not overflow horizontally at any width',
        (tester) async {
      // Flutter reports a RenderFlex overflow as a test failure on its own, so this
      // catches the case where a row of title, subtitle, notice and button cannot fit.
      const widths = [360.0, 390.0, 600.0, 768.0, 1024.0, 1280.0, 1440.0];

      for (final w in widths) {
        for (final mode in LibraryViewMode.values) {
          final vm = await manyResources();
          vm.setViewMode(mode);
          await mount(tester, vm, size: Size(w, 900));

          expect(
            tester.takeException(),
            isNull,
            reason: 'the library overflowed at ${w.toInt()}px in ${mode.name} mode',
          );
        }
      }
    });
  });

  // ------------------------------------- 7.7 loading, failure and recovery

  group('7.7 loading and recoverable failure', () {
    /// Makes the module directory unreadable, which is how a real read fails.
    ///
    /// A corrupt `.amod` file does *not* work as a fault for this, which is worth
    /// recording: `ZipDecoder` returns an empty archive for bytes that are not a zip
    /// rather than throwing, so a truncated download produces a module with no manifest
    /// and the library quietly lists it under its own id. An unreadable directory is the
    /// failure that actually reaches the screen — a locked profile, a disconnected drive,
    /// a permissions problem after an OS upgrade.
    ///
    test('a load in progress is a loading state, not an empty one', () async {
      final vm = buildViewModel(_MemorySource({}));

      expect(vm.status, LibraryStatus.loading);
      expect(vm.state.loaded, isFalse,
          reason: '"not loaded yet" and "loaded and empty" are different states and '
              'only one of them is a reason to wait');
    });

    testWidgets('the loading indicator stands in for the list', (tester) async {
      final vm = buildViewModel(_MemorySource({}));

      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(harness(vm, onOpen: (_) {}));
      // Pumped once, not settled: the load is a real asynchronous read that has not run
      // yet, which is exactly the state under test.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Reintentar'), findsNothing);
    });

    test('an unreadable module directory fails the load with a reason', () async {
      if (!_canLockDirectory) return;

      await locked(temp, () async {
        final vm = buildViewModel(_MemorySource({}));
        await vm.load();

        expect(vm.status, LibraryStatus.failed);
        expect(vm.error, isNotNull);
        expect(vm.error, contains('instalado'),
            reason: 'the message should say what could not be read');
      });
    });

    test('retry re-runs the load and succeeds once the fault is gone', () async {
      if (!_canLockDirectory) return;

      final bytes = await moduleBytes();
      final vm = buildViewModel(_MemorySource({}));

      await locked(temp, () async {
        await vm.load();
        expect(vm.status, LibraryStatus.failed);
      });

      // Repaired the way it would be in reality: the directory is readable again and a
      // real module is on disk. The load has to actually re-run — a `retry` that only
      // cleared the error would leave the list empty and still read as "recovered".
      File('${temp.path}/SAMPLE.amod').writeAsBytesSync(bytes);
      await vm.retry();

      expect(vm.status, LibraryStatus.ready);
      expect(vm.error, isNull);
      expect(vm.state.installed.map((e) => e.resource.id), ['SAMPLE'],
          reason: 'the repaired tree is readable content and must be listed');
    });

    testWidgets('the failure state offers retry and recovers when it works',
        (tester) async {
      if (!_canLockDirectory) return;

      final bytes = await moduleBytes();
      final vm = buildViewModel(_MemorySource({}));

      // `runAsync` for every step that touches the filesystem. A `testWidgets` body runs
      // inside a fake-async zone, where a real `File.readAsBytes` never completes — the
      // load would simply stop, with no exception and no timeout, and the test would sit
      // there for the framework's own ten minutes. The first load only reads the
      // directory synchronously, so it can complete either way; the retry after the
      // directory is readable again has to unarchive a module, and that is the step that
      // hangs without this.
      await tester.runAsync(() async {
        await locked(temp, () async {
          await vm.load();
        });
      });

      await mount(tester, vm);
      expect(find.text('No se pudo abrir la biblioteca'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      File('${temp.path}/SAMPLE.amod').writeAsBytesSync(bytes);

      // Activating retry starts a re-read. The state leaves `failed` synchronously,
      // before any I/O, so this half is observable inside the fake-async zone and is what
      // proves the control is wired to the command rather than merely drawn.
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(vm.status, LibraryStatus.loading);

      // The re-read itself reads a module off the disk, which the fake-async zone cannot
      // complete — so it is run through `runAsync`. Awaiting the same call twice is
      // harmless: `load` is idempotent, and the point is only that the list is rebuilt.
      await tester.runAsync(() => vm.retry());
      await tester.pumpAndSettle();

      expect(vm.status, LibraryStatus.ready);
      expect(find.text('No se pudo abrir la biblioteca'), findsNothing);
      expect(find.byType(ResourceCover), findsWidgets);
    });

    test('a corrupt catalog degrades to the installed set rather than failing', () async {
      // The installed modules do not depend on the catalog, so a user with content on
      // disk must not lose it because a manifest is malformed. Treating this as an error
      // would show a failure screen over a Bible they can already read.
      final bytes = await moduleBytes(id: 'SAMPLE');
      await ModuleInstaller(ModuleStore(temp)).install('SAMPLE', bytes: bytes);

      final vm = buildViewModel(_MemorySource({}));
      await vm.load(catalogJson: '{ not json');

      expect(vm.status, LibraryStatus.ready);
      expect(vm.error, isNull);
      expect(vm.state.installed.map((e) => e.resource.id), ['SAMPLE']);
      expect(vm.state.catalogVersion, isNull);
    });
  });

  // ------------------------------------- the integrity gate, and installing

  group('a resource with no verifiable hash is not offered for install', () {
    test('a placeholder hash is refused before any bytes are requested', () async {
      // Seventeen of the eighteen entries in the real catalog are in exactly this state.
      // Offering an `Instalar` button on them would offer to pull a download onto the
      // device with nothing to check it against — an integrity guarantee by faith.
      final source = _MemorySource({'file:///x': await moduleBytes()});
      final vm = buildViewModel(source);
      await vm.load(catalogJson: catalogOf([
        entry(
          id: 'CALVIN',
          name: 'Calvin',
          sha256: 'PLACEHOLDER_CALVIN',
          downloadUrl: 'file:///x',
        ),
      ]));
      vm.setScope(LibraryScope.store);

      expect(vm.state.available, isEmpty);
      expect(vm.state.unverifiable.map((e) => e.resource.id), ['CALVIN']);
      expect(vm.visible.single.isInstallable, isFalse);

      await vm.install('CALVIN');

      expect(source.requested, isEmpty,
          reason: 'no bytes may be requested for a resource that cannot be verified');
      expect(vm.state.failures['CALVIN'], contains('sha256'));
    });

    test('a truncated or non-hex hash is refused too', () async {
      for (final sha in ['', 'abc', 'z' * 64, 'A' * 63]) {
        final vm = buildViewModel(_MemorySource({}));
        await vm.load(catalogJson: catalogOf([
          entry(id: 'X', name: 'X', sha256: sha),
        ]));
        expect(
          vm.state.entries.single.hasVerifiableSource,
          isFalse,
          reason: '"$sha" is not a sha256',
        );
      }
    });

    test('a real hash passes the gate', () {
      final vm = buildViewModel(_MemorySource({}));
      expect(
        LibraryEntry(
          resource: ResourceDescriptor(
            id: 'X',
            type: ResourceType.bible,
            name: 'X',
            shortName: 'X',
            language: 'en',
            version: '1',
            sha256: '6dbf144e462a93ae3fab8d77c9c5a369d034725ad5bcf031a7bf290b7fba7eb9',
            license: LicenseInfoProbe.publicDomain,
          ),
        ).hasVerifiableSource,
        isTrue,
      );
      expect(vm.state.entries, isEmpty);
    });

    testWidgets('a row that cannot be installed says why', (tester) async {
      // The two reasons live in different scopes, because the scopes are a partition: a
      // copyright-blocked resource is not in the store (you cannot acquire it), and an
      // unverifiable one is (it simply has not been published yet). So they are two
      // assertions on two scopes rather than one screen showing both — which is itself
      // the thing a single "unavailable" label would have hidden.
      final vm = buildViewModel(_MemorySource({}));
      await vm.load(catalogJson: catalogOf([
        entry(
          id: 'CALVIN',
          name: 'Calvin',
          sha256: 'PLACEHOLDER_CALVIN',
        ),
        entry(
          id: 'PLATENSE',
          name: 'Biblia Platense',
          releaseDate: '2099-01-01',
        ),
      ]));

      vm.setScope(LibraryScope.store);
      await mount(tester, vm);
      expect(find.textContaining('suma de verificación'), findsOneWidget);
      expect(find.text('Instalar'), findsNothing);

      vm.setScope(LibraryScope.mine);
      await tester.pumpAndSettle();
      expect(find.textContaining('derechos de autor'), findsOneWidget);
      expect(find.textContaining('suma de verificación'), findsNothing);
      expect(find.text('Instalar'), findsNothing);
    });
  });

  group('installing a real module', () {
    test('a public-domain resource with a real hash installs and appears',
        () async {
      final bytes = await moduleBytes(id: 'SAMPLE');
      final digest = sha256.convert(bytes).toString();
      final source = _MemorySource({'file:///SAMPLE.amod': bytes});

      final vm = buildViewModel(source);
      await vm.load(catalogJson: catalogOf([
        entry(
          id: 'SAMPLE',
          name: 'Sample Bible',
          sha256: digest,
          downloadUrl: 'file:///SAMPLE.amod',
        ),
      ]));
      vm.setScope(LibraryScope.store);
      expect(vm.visible.single.isInstallable, isTrue);

      await vm.install('SAMPLE');

      expect(vm.state.failures, isEmpty);
      expect(vm.state.installed.map((e) => e.resource.id), ['SAMPLE']);
      expect(ModuleStore(temp).pathFor('SAMPLE').existsSync(), isTrue);
    });

    test('a download that does not match the catalog writes nothing', () async {
      final bytes = await moduleBytes(id: 'SAMPLE');
      final source = _MemorySource({'file:///SAMPLE.amod': bytes});

      final vm = buildViewModel(source);
      await vm.load(catalogJson: catalogOf([
        entry(
          id: 'SAMPLE',
          name: 'Sample Bible',
          sha256: 'c' * 64,
          downloadUrl: 'file:///SAMPLE.amod',
        ),
      ]));
      vm.setScope(LibraryScope.store);

      await vm.install('SAMPLE');

      expect(vm.state.failures['SAMPLE'], contains('sha256'));
      expect(vm.state.installed, isEmpty);
      expect(ModuleStore(temp).pathFor('SAMPLE').existsSync(), isFalse,
          reason: 'a rejected download must leave nothing behind for a later install to '
              'mistake for a good module');
    });

    test('an installed resource moves from the store to the user', () async {
      final bytes = await moduleBytes(id: 'SAMPLE');
      final digest = sha256.convert(bytes).toString();
      final source = _MemorySource({'file:///SAMPLE.amod': bytes});

      final vm = buildViewModel(source);
      await vm.load(catalogJson: catalogOf([
        entry(
          id: 'SAMPLE',
          name: 'Sample Bible',
          sha256: digest,
          downloadUrl: 'file:///SAMPLE.amod',
        ),
      ]));

      vm.setScope(LibraryScope.store);
      expect(vm.visible, hasLength(1));

      await vm.install('SAMPLE');

      // The partition has to follow the install, or the resource would appear in the
      // store after it is already installed — which is what makes a segmented control
      // look broken.
      expect(vm.visible, isEmpty, reason: 'it is no longer for sale, it is yours');
      vm.setScope(LibraryScope.mine);
      expect(vm.visible.map((e) => e.resource.id), ['SAMPLE']);
    });
  });

  // ------------------------------------------------------- the cover

  group('the generated cover', () {
    test('reads the short name, which is legible at cover size', () {
      final vm = buildViewModel(_MemorySource({}));
      // The short name is what a cover carries, because `King James Version` is not
      // readable at forty pixels and `KJV` is.
      expect(
        ResourceCover(
          resource: ResourceDescriptor(
            id: 'KJV',
            type: ResourceType.bible,
            name: 'The Holy Bible: King James Version',
            shortName: 'KJV',
            language: 'en',
            version: '1',
            license: LicenseInfoProbe.publicDomain,
          ),
          size: 56,
        ),
        isNotNull,
      );
      expect(vm.state.entries, isEmpty);
    });

    test('every resource type gets an accent from the transcribed palette', () {
      // Not a colour-per-type table invented here: each value has to be a colour the
      // application already declares, or the cover would be the one surface in the app
      // that does not come from the capture.
      for (final type in ResourceType.values) {
        final accent = ResourceCover.accentFor(type);
        expect(accent.toARGB32(), isNot(0xFF2196F3),
            reason: 'Material\'s default blue is not a transcribed Logos token');
      }
      expect(ResourceCover.accentFor(ResourceType.bible), LogosColors.primary);
    });

    testWidgets('the cover text clears AA against the board', (tester) async {
      final vm = buildViewModel(_MemorySource({}));
      await vm.load(catalogJson: catalogOf([
        entry(id: 'A', name: 'Alpha'),
        entry(id: 'B', name: 'Beta'),
      ]));
      vm.setScope(LibraryScope.store);
      await mount(tester, vm);

      // The board is `#F4F4F4` and the label is the palette's body colour. If either
      // moved, the cover would be the smallest text in the application and the easiest
      // to make unreadable, so it is checked rather than assumed.
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byType(ResourceCover),
          matching: find.byType(Text),
        ).first,
      );
      expect(
        _contrast(label.style!.color!, LogosColors.surfaceHover),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}

/// A public-domain licence, for the places a descriptor is built outside a catalog.
class LicenseInfoProbe {
  static final publicDomain = LicenseInfo.publicDomain(sourceUrl: 'https://example.org');
}

/// A source serving bytes from memory, so the install path runs with no network.
///
/// At top level because Dart has no local classes, and because it is the same seam
/// `library_test.dart` uses — one definition, so the two files cannot drift into testing
/// subtly different things.
class _MemorySource implements ModuleSource {
  _MemorySource(this.payloads);

  final Map<String, List<int>> payloads;

  /// Urls requested. Asserting on this is how "never fetched" is proven rather than
  /// assumed — a gate that fetched first and refused afterwards would still produce the
  /// right user-visible outcome while having already pulled the bytes.
  final requested = <String>[];

  @override
  Future<List<int>> fetch(String url, {String? expectedSha256}) async {
    requested.add(url);
    final bytes = payloads[url];
    if (bytes == null) throw StateError('nothing at $url');
    return bytes;
  }
}

/// WCAG 2.1 relative-luminance contrast, written out so the assertion is its own
/// definition — a helper that computed contrast wrongly would make every check pass.
double _contrast(Color a, Color b) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  final la = luminance(a);
  final lb = luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Whether this process can be denied read access with `chmod`.
///
/// Root ignores the permission bits, so on a container running as root the fault these
/// tests inject cannot be injected and the tests would be asserting nothing. They return
/// early instead of passing vacuously.
final bool _canLockDirectory = !Platform.isWindows &&
    Platform.environment['USER'] != 'root' &&
    Platform.environment['HOME'] != '/root';

/// Runs [body] with [dir] unreadable, then restores it.
///
/// Restored in a `finally` because a test that leaves a locked directory behind makes
/// every later `tearDown` fail, which turns one broken test into a cascade that looks
/// like a different problem.
Future<void> locked(Directory dir, Future<void> Function() body) async {
  final result = Process.runSync('chmod', ['000', dir.path]);
  if (result.exitCode != 0) {
    fail('could not lock ${dir.path}: ${result.stderr}');
  }
  try {
    await body();
  } finally {
    Process.runSync('chmod', ['755', dir.path]);
  }
}
