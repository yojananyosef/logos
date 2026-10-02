import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/repositories/library_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/ui/features/library/view_models/library_view_model.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_preferences.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_view_model.dart';

/// Smoke tests against real published modules.
///
/// The other module tests build their fixtures, which is right for testing behaviour but
/// proves nothing about whether the reader agrees with what the catalog repository
/// actually produces. This file closes that gap.
///
/// It is opt-in because the modules are 3MB each and are not vendored into the
/// repository — the catalog is a separate project, and its artefacts are fetched, not
/// committed. Point `LOGOS_MODULE_DIR` at a directory of `.amod` files to run it:
///
///     LOGOS_MODULE_DIR=/path/to/dist flutter test test/real_modules_test.dart
///
/// Both findings below are defects in the upstream catalog, reproduced deliberately.
/// They are asserted as *expected defects* so that a future rebuild which fixes them
/// fails this test and forces the expectations to be revisited — which is the only way a
/// test keeps telling the truth about data it does not own.
void main() {
  final dir = Platform.environment['LOGOS_MODULE_DIR'];

  if (dir == null || !Directory(dir).existsSync()) {
    test('real modules are not present', () {}, skip: true);
    return;
  }

  late BibleRepository repo;
  final installed = <String>[];
  // El directorio donde el `setUpAll` instala los modulos. Se guarda aparte del
  // `dir` de arriba, que es `LOGOS_MODULE_DIR`: los modulos de origen. Borrar ese
  // por confunsion destruiria la unica copia de lo que hay que probar, y desde
  // el repositorio equivocado nadie lo notaria.
  late Directory installRoot;

  setUpAll(() async {
    final source = Directory(dir);
    installRoot = ModuleStore(
      Directory.systemTemp.createTempSync('logos-real-'),
    ).root;
    for (final file in source.listSync().whereType<File>()) {
      if (!file.path.endsWith('.amod')) continue;
      final id = file.uri.pathSegments.last.replaceAll('.amod', '');
      final result = await ModuleInstaller(ModuleStore(installRoot)).install(
        id,
        bytes: file.readAsBytesSync(),
      );
      if (result.status == InstallStatus.ok) installed.add(id);
    }
    repo = BibleRepository(ModuleStore(installRoot));
  });

  // `BibleRepository.open` extrae cada `.amod` a una base temporal de unos 39 MB y
  // solo la borra en `dispose()`. Sin esto, 17 tests contra el módulo de
  // referencia dejan 663 MB en el tmpfs del sistema, que en esta máquina son
  // 3,7 GB en total: el arnés era lo que llenaba el disco y lo que hacia fallar
  // la suite siguiente por `No space left on device`.
  //
  // No es un detalle del arnés. En la app, `app_providers.dart` construye el
  // repositorio igual que aquí y depende de que riverpod llame a `dispose()` al
  // cerrar el provider; si algún camino lo pierde, es la app la que se come el
  // disco, y en un móvil eso no es un tmpfs de 3,7 GB sino el almacenamiento que
  // el usuario tiene.
  tearDownAll(() {
    repo.dispose();
    if (installRoot.existsSync()) installRoot.deleteSync(recursive: true);
  });

  test('a real module opens, lists its books and answers a verse lookup', () async {
    final id = installed.first;
    final module = await repo.open(id);

    expect(module.books, isNotEmpty, reason: '$id reports no books');
    // A module with fewer than 66 books has lost part of the canon.
    expect(module.books.length, greaterThanOrEqualTo(66));

    final first = module.books.firstWhere((b) => b.osisCode == 'John');
    final verses = await repo.chapter(id, 'John', 1);

    expect(verses.map((v) => v.verse), containsAllInOrder([1, 2, 3]));
    expect(verses.first.verse, 1,
        reason: '$id must contain John 1:1, or the reader cannot cite it');
    expect(verses.first.text, isNotEmpty);
    expect(first.chapterCount, greaterThan(0));
  });

  test('full-text search works on a real module', () async {
    final id = installed.first;

    final hits = await repo.search(id, 'Jesus');

    expect(hits, isNotEmpty, reason: '$id returned nothing for "Jesus"');
    expect(hits.first.osisCode, isNotEmpty);
    expect(hits.first.chapter, greaterThan(0));
    expect(hits.first.verse, greaterThan(0));
  });

  test('search matches across diacritics on a real module', () async {
    // The reason the format chose `remove_diacritics 2`. A module with accented text
    // has to answer to the unaccented query, because that is what people type.
    final id = installed.first;

    expect(await repo.search(id, 'Jesus'), isNotEmpty);
  });

  test('a module built by tool/build_module.dart has no off-by-one', () async {
    if (!installed.contains('KJV')) {
      expect(installed, isNotEmpty, reason: 'no modules at all in $dir');
      return;
    }

    final module = await repo.open('KJV');

    // This assertion used to expect the defect: 260 chapters starting at a verse other
    // than 1, so John 1:1 did not exist, because the upstream ETL indexed a chapter's
    // lines as `lines[verse - 1]` while the first line of a chapter is the chapter
    // marker. Its end-to-end test read Genesis 1:1, in the unaffected Old Testament, and
    // passed.
    //
    // It is inverted now because `UsfmExtractor` captures the implicit `\v 1` and
    // `tool/build_module.dart` builds through it. The expectation is now the contract: a
    // module this repository builds must address verse 1 of every chapter. If a rebuild
    // ever ships the upstream behaviour again, this fails, which is what it is for.
    expect(module.integrity.isValid, isTrue,
        reason: 'a module built by build_module.dart must have no integrity failures, '
            'got ${module.integrity.failures.length}');
    expect(await repo.verse('KJV', 'John', 1, 1), isNotEmpty,
        reason: 'John 1:1 must exist, or the reader cannot cite it');
  });

  test('cross-references are present and readable on a real module', () async {
    final id = installed.firstWhere((i) => i == 'KJV', orElse: () => installed.first);

    // John 1:1 carries four anchored phrases — "the beginning", "the Word", "with" and
    // "the Word was" — and TSK gives different passages for each. A module that stored them
    // at verse granularity would report one group here; the phrase-level shape is what the
    // reader places them by, and it is what this asserts survives the build.
    final references = await repo.crossReferences(id, 'John', 1);

    expect(references, isNotEmpty, reason: '$id carries no cross-references in John 1');
    expect(references[1]!.length, greaterThan(1),
        reason: 'TSK anchors John 1:1 on several phrases; one would mean the phrase-level '
            'shape was flattened in the build');
    expect(references[1]!.map((g) => g.anchor),
        containsAll(['the beginning', 'the Word']));
  });

  test('every cross-reference on a real module points somewhere the module contains',
      () async {
    final id = installed.firstWhere((i) => i == 'KJV', orElse: () => installed.first);
    final module = await repo.open(id);

    // The integrity check reports dangling targets. Asserting on it directly here is what
    // turns "the links exist" into "the links work": 336,829 of them is not a thing to spot
    // check by eye, and one that points at a verse the module lacks is invisible until
    // somebody follows it.
    final xrefFailures = module.integrity.failures
        .where((f) => f.chapterKey == 'crossReferences')
        .toList();

    expect(xrefFailures, isEmpty,
        reason: 'dangling cross-references: ${xrefFailures.map((f) => f.reason).join('; ')}');
  });

  test('a find reports every occurrence of a term across a real module', () async {
    final id = installed.firstWhere((i) => i == 'KJV', orElse: () => installed.first);
    final vm = ReaderViewModel(repo, ReaderPreferencesViewModel(InMemoryReaderStore()));

    // The term has to suit the module. This test used to hard-code the English "Word",
    // which passes when the directory happens to hold the KJV and reports zero matches
    // when it holds a Spanish one — so it was really asserting that the directory held
    // an English Bible, which is not what its name says.
    //
    // Each term is the same word in that language and appears in John 1:1 and 1:14, so
    // both modules answer the same question. "Verbo" was checked against the built
    // Reina-Valera module rather than assumed: two occurrences in John, at 1:1 and 1:14.
    final term = id == 'KJV' ? 'Word' : 'Verbo';

    await vm.open(id, osisCode: 'John', chapter: 1);
    await vm.find(term);

    // The point is not the exact count — it is that the count is the module's and the
    // matches are ordered by the canon.
    expect(vm.state.find.matchCount, greaterThanOrEqualTo(2),
        reason: 'John 1:1 and 1:14 both have "$term" capitalised in $id');
    expect(vm.state.find.activeMatch!.chapter, 1,
        reason: 'the reader opened in John 1, so the search starts where they are rather '
            'than at the first "$term" in the canon, which is in Genesis');
    expect(vm.state.osisCode, 'John');

    final orders = vm.state.find.result!.matches.map((m) => m.bookOrder).toList();
    expect(orders, equals([...orders]..sort()),
        reason: 'matches are in reading order, or stepping jumps about unpredictably');
  });

  test('a cross-reference followed on a real module lands on real text', () async {
    final id = installed.firstWhere((i) => i == 'KJV', orElse: () => installed.first);
    final vm = ReaderViewModel(repo, ReaderPreferencesViewModel(InMemoryReaderStore()));

    await vm.open(id, osisCode: 'John', chapter: 1);
    final references = await repo.crossReferences(id, 'John', 1);
    expect(references, isNotEmpty);

    // Follow the first reference of the first phrase, through the same path the view takes.
    final group = references.values.first.first;
    final books = (await repo.open(id)).books;
    final target = books.firstWhere((b) => b.bookId == group.references.first.toBookId);

    await vm.followCrossReference(
      group.references.first,
      toBook: target.osisCode,
    );

    expect(vm.state.status, ReaderStatus.ready);
    expect(vm.state.osisCode, target.osisCode);
    expect(vm.state.chapter, isNotNull);
    expect(vm.state.chapter!.verses, isNotEmpty,
        reason: 'the reference must lead to text, not to an empty chapter');
    expect(vm.state.canGoBack, isTrue);

    await vm.goBack();
    expect(vm.state.osisCode, 'John', reason: 'and the reader can come back');
  });

  test('the upstream merged-verse defect is still present in WEB', () async {
    if (!installed.contains('WEB')) return;

    final module = await repo.open('WEB');

    // A second, distinct defect. Four chapters contain merged verses: the ETL puts a
    // multi-verse segment's text under the first verse number and never populates
    // `verseEnd`, so Luke 17:36's text sits inside 17:35. Every chapter still *starts*
    // at verse 1, which is why a check for that alone reports the module as sound.
    expect(module.integrity.failures, hasLength(4));
    expect(
      module.integrity.failures.map((f) => f.chapterKey),
      containsAll(['Luke:17', 'Acts:8', 'Acts:15', 'Acts:24']),
    );

    // The text is present, just misaddressed — which is worse for a study application
    // than a missing chapter, because a search for the merged verse returns nothing
    // while its words are visible one line above.
    final merged = await repo.verse('WEB', 'Luke', 17, 35);
    expect(merged, hasLength(1));
    expect(merged.single.text, contains('the other will be left'),
        reason: 'Luke 17:36 text is carried inside 17:35');
    expect(await repo.verse('WEB', 'Luke', 17, 36), isEmpty);
  });

  // Spanish is the application's first language, not a later addition, so a module built
  // from the Reina-Valera 1909 is exercised on the same terms as the English one. These
  // are skipped when no Spanish module is present, exactly as the file's other
  // module-specific tests are.
  group('a Spanish module', () {
    const spanish = 'RV1909';
    bool have() => installed.contains(spanish);

    test('opens, lists all 66 books, and answers a verse lookup', () async {
      if (!have()) {
        expect(installed, isNotEmpty, reason: 'no modules at all in $dir');
        return;
      }
      final module = await repo.open(spanish);

      expect(module.books, hasLength(66),
          reason: 'a Spanish Bible with 65 books is missing one');
      expect(module.books.first.osisCode, 'Gen',
          reason: 'books are addressed by OSIS, whatever the translation calls them');
      expect(module.books.last.osisCode, 'Rev');

      final john = await repo.chapter(spanish, 'John', 1);
      expect(john.map((v) => v.verse), containsAllInOrder([1, 2, 3]));
      expect(john.first.verse, 1, reason: 'Juan 1:1 must be addressable');
    });

    test('carries Spanish text, not an English fallback', () async {
      if (!have()) return;

      // The specific regression a Spanish module exists to prevent: a build that
      // silently produced an empty or English chapter would still pass every structural
      // assertion above, because a row of any text satisfies them.
      //
      // The capitalisation is the source's, not a normalisation this build applied.
      // Reina-Valera opens both of these in full capitals — Génesis 1:1 is "EN el
      // principio" — and sets Juan 2:1 as "Y AL tercer día". The expectation reproduces
      // it deliberately, so that a change which lower-cases the whole module would have
      // to be a decision rather than an accident.
      final john11 = await repo.verse(spanish, 'John', 1, 1);
      expect(john11.single.text, 'EN el principio era el Verbo, y el Verbo era con Dios, '
          'y el Verbo era Dios.');

      final gen11 = await repo.verse(spanish, 'Gen', 1, 1);
      expect(gen11.single.text, 'EN el principio crió Dios los cielos y la tierra.');

      final john316 = await repo.verse(spanish, 'John', 3, 16);
      expect(john316.single.text, startsWith('Porque de tal manera amó Dios al mundo'));
    });

    test('names its books in Spanish while addressing them by OSIS', () async {
      if (!have()) return;
      final module = await repo.open(spanish);

      // Both halves matter. A Spanish reader wants to see "Génesis", and the reference
      // parser needs `Gen` to resolve `Gén. 1:1`. A module that stored the display name
      // in the addressable column would break one of the two.
      String nameOf(String osis) =>
          module.books.firstWhere((b) => b.osisCode == osis).name;

      expect(nameOf('Gen'), 'Génesis');
      expect(nameOf('John'), 'Juan');
      expect(nameOf('Rev'), 'Apocalipsis');
      expect(nameOf('Song'), 'Cantar de los Cantares');
    });

    test('searches Spanish text and folds the accents', () async {
      if (!have()) return;

      // Spanish orthography is accented and people do not always type it. "principio"
      // must find "principio" and "Dios" must be reachable either way.
      expect(await repo.search(spanish, 'principio'), isNotEmpty);
      expect(await repo.search(spanish, 'Verbo'), isNotEmpty);
      expect(await repo.search(spanish, 'camino'), isNotEmpty,
          reason: 'Génesis 3:8 is "el camino del Señor"');
    });

    test('every chapter begins at verse 1, in Spanish as in English', () async {
      if (!have()) return;
      final module = await repo.open(spanish);

      // The off-by-one that lost verse 1 of 260 chapters upstream was never
      // language-specific, and this is the assertion that would have caught it in a
      // Spanish build as readily as in an English one.
      expect(module.integrity.isValid, isTrue,
          reason: 'integrity failures: ${module.integrity.failures.length}');
      expect(module.integrity.failures.map((f) => f.chapterKey),
          isNot(contains('Juan:1')));
    });

    test('carries the same cross-reference set as the English module', () async {
      if (!have()) return;
      final references = await repo.crossReferences(spanish, 'John', 1);

      expect(references, isNotEmpty);
      expect(references[1]!, isNotEmpty);
      // TSK's anchors are English phrases, because the cross-reference set is keyed to
      // the KJV versification. The links are what transfer; the anchor text does not, and
      // the reader has to cope with a Spanish verse carrying an English anchor rather than
      // dropping the group.
      expect(references[1]!.map((g) => g.anchor), isNotEmpty);
      final target = references[1]!.first.references.first;
      final books = (await repo.open(spanish)).books;
      final landing = books.firstWhere((b) => b.bookId == target.toBookId);
      expect(await repo.chapter(spanish, landing.osisCode, target.toChapter), isNotEmpty,
          reason: 'a Spanish cross-reference must lead to Spanish text');
    });
  });

  group('the library installs the real module', () {
    // The rest of this file proves the reader can *read* a real module. These prove the
    // user can get one — which is the gap this section closed. A reader that can open a
    // KJV nobody is able to install is a reader with no way to reach it.
    late Directory installDir;

    setUp(() {
      installDir = Directory.systemTemp.createTempSync('logos-real-install-');
    });

    tearDown(() {
      if (installDir.existsSync()) installDir.deleteSync(recursive: true);
    });

    /// Serves the `.amod` files in [dir] as if they were the catalog's download URLs.
    ///
    /// Reading them from disk rather than from memory is deliberate: the catalog's own
    /// URLs are `https://`, and a test that fetched one would make the suite depend on a
    /// third party being up. The bytes, the hash and the installer are all real; only the
    /// transport is local.
    ModuleSource localSource(Directory dir) => _DirectorySource(dir);

    test('a module the catalog vouches for installs and opens', () async {
      final source = Directory(dir);
      final file = source.listSync().whereType<File>().firstWhere(
            (f) => f.path.endsWith('.amod'),
          );
      final id = file.uri.pathSegments.last.replaceAll('.amod', '');

      final store = ModuleStore(installDir);
      // `LibraryViewModel` no dispose: no es un `ChangeNotifier` con vida propia.
      // El repositorio lo libera quien lo crea, y en produccion es el provider de
      // riverpod. Aqui no hay provider, asi que lo suelta el test — sin esto cada
      // `open` deja una copia de 39 MB en el tmpfs que sobrevive al test.
      final viewRepo = BibleRepository(store);
      final vm = LibraryViewModel(
        repository: viewRepo,
        installer: ModuleInstaller(store),
        source: localSource(source),
        catalogService: const CatalogService(),
      );

      // A catalog carrying this module's real digest, which is what makes it installable
      // rather than merely listed.
      final bytes = file.readAsBytesSync();
      await vm.load(catalogJson: jsonEncode({
        'format': 'amf-catalog',
        'version': '1.0.0',
        'modules': [
          {
            'id': id,
            'type': 'bible',
            'name': 'King James Version',
            'shortName': id,
            'language': 'en',
            'version': '1.0.0',
            'sha256': sha256.convert(bytes).toString(),
            'sizeBytes': bytes.length,
            'downloadUrl': '$id.amod',
            'license': {
              'id': 'PublicDomain',
              'attribution': 'Public domain',
              'sourceUrl': 'https://example.org',
              'releaseDate': '1970-01-01',
              'jurisdictions': <String>[],
              'basis': 'Public domain by age.',
            },
          }
        ],
      }));

      expect(vm.state.entries.single.isInstallable, isTrue,
          reason: 'a real digest and a public-domain licence');

      await vm.install(id);

      expect(vm.state.failures, isEmpty,
          reason: 'the real module must install: ${vm.state.failures}');
      expect(vm.state.installed.map((e) => e.resource.id), [id]);
      expect(ModuleStore(installDir).pathFor(id).existsSync(), isTrue);

      // And the installed copy is a working Bible, not just a file on disk.
      //
      // One repository for both assertions. `BibleRepository.open` extracts the
      // module to a ~39 MB temp database and only `dispose()` removes it, so a
      // second inline repository here is 39 MB that outlives the test — and a
      // suite that runs 17 real-module tests leaves hundreds of megabytes of
      // orphaned copies behind for whatever runs next.
      final installed = BibleRepository(ModuleStore(installDir));
      final opened = await installed.open(id);
      expect(opened.books.length, greaterThanOrEqualTo(66));
      expect(opened.integrity.isValid, isTrue,
          reason: 'an installed module should be the sound one the catalog describes');
      expect(await installed.verse(id, 'John', 1, 1), isNotEmpty,
          reason: 'John 1:1 is the verse the reader cites by name');
      installed.dispose();
    });

    test('a module whose bytes do not match the catalog is refused', () async {
      final source = Directory(dir);
      final file = source.listSync().whereType<File>().firstWhere(
            (f) => f.path.endsWith('.amod'),
          );
      final id = file.uri.pathSegments.last.replaceAll('.amod', '');

      final store = ModuleStore(installDir);
      final viewRepo = BibleRepository(store);
      final vm = LibraryViewModel(
        repository: viewRepo,
        installer: ModuleInstaller(store),
        source: localSource(source),
        catalogService: const CatalogService(),
      );

      await vm.load(catalogJson: jsonEncode({
        'format': 'amf-catalog',
        'version': '1.0.0',
        'modules': [
          {
            'id': id,
            'type': 'bible',
            'name': 'Wrong digest',
            'shortName': id,
            'language': 'en',
            'version': '1.0.0',
            // A digest that is well-formed and wrong. The point of the hash is that this
            // is rejected, and a real eleven-megabyte module is what makes the check
            // worth having: a mismatch caught after the download is the whole mechanism.
            'sha256': '0' * 64,
            'sizeBytes': 1,
            'downloadUrl': '$id.amod',
            'license': {
              'id': 'PublicDomain',
              'attribution': 'Public domain',
              'sourceUrl': 'https://example.org',
              'releaseDate': '1970-01-01',
              'jurisdictions': <String>[],
              'basis': 'Public domain by age.',
            },
          }
        ],
      }));

      await vm.install(id);

      expect(vm.state.failures[id], contains('sha256'));
      expect(vm.state.installed, isEmpty);
      expect(ModuleStore(installDir).pathFor(id).existsSync(), isFalse,
          reason: 'a refused module must leave nothing behind');
      viewRepo.dispose();
    });
  });
}

/// Reads a module from a directory of `.amod` files, standing in for the catalog's
/// download URLs.
class _DirectorySource implements ModuleSource {
  const _DirectorySource(this.root);

  final Directory root;

  @override
  Future<List<int>> fetch(String url, {String? expectedSha256}) async {
    final file = File('${root.path}/$url');
    if (!file.existsSync()) throw StateError('no module at $url');
    return file.readAsBytes();
  }
}
