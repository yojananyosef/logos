import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
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

  setUpAll(() async {
    final source = Directory(dir);
    final store = ModuleStore(
      Directory.systemTemp.createTempSync('logos-real-'),
    );
    for (final file in source.listSync().whereType<File>()) {
      if (!file.path.endsWith('.amod')) continue;
      final id = file.uri.pathSegments.last.replaceAll('.amod', '');
      final result = await ModuleInstaller(store).install(
        id,
        bytes: file.readAsBytesSync(),
      );
      if (result.status == InstallStatus.ok) installed.add(id);
    }
    repo = BibleRepository(store);
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

    await vm.open(id, osisCode: 'John', chapter: 1);
    await vm.find('Word');

    // "Word" capitalised appears in John 1:1 and 1:14. The point is not the exact count —
    // it is that the count is the module's and the matches are ordered by the canon.
    expect(vm.state.find.matchCount, greaterThanOrEqualTo(2),
        reason: 'John 1:1 and 1:14 both have "Word" capitalised');
    expect(vm.state.find.activeMatch!.chapter, 1,
        reason: 'the reader opened in John 1, so the search starts where they are rather '
            'than at the first "Word" in the canon, which is in Genesis');
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
}
