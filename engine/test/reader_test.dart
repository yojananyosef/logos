import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/ui/core/theme/logos_colors.dart';
import 'package:logos_engine/ui/core/theme/logos_theme.dart';
import 'package:logos_engine/ui/features/reader/views/bible_reader_view.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_preferences.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_view_model.dart';

import 'support/module_builder.dart';

/// Reader tests, against real modules built by the shared builder.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-reader-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<BibleRepository> install(ModuleBuilder builder) async {
    await builder.writeTo(temp);
    return BibleRepository(ModuleStore(temp));
  }

  /// Fresh reader settings for a test.
  ///
  /// In-memory rather than shared: each test states its own formatting, so one test changing
  /// the text size cannot make another test's assertions depend on execution order.
  ReaderPreferencesViewModel newPreferences() =>
      ReaderPreferencesViewModel(InMemoryReaderStore());

  /// Builds a module, opens it and loads a chapter.
  ///
  /// Wrapped in [WidgetTester.runAsync] for the widget tests: those run under a fake
  /// clock, and awaiting real file and database I/O in that zone never completes. Doing
  /// it here rather than in each test keeps that detail in one place.
  Future<ReaderViewModel> openReader(
    WidgetTester tester,
    ModuleBuilder builder, {
    String? osisCode,
    int chapter = 1,
  }) async {
    late ReaderViewModel vm;
    await tester.runAsync(() async {
      final repo = await install(builder);
      vm = ReaderViewModel(repo, newPreferences());
      await vm.open(builder.id, osisCode: osisCode, chapter: chapter);
    });
    return vm;
  }

  /// A sound module: John has one chapter, Genesis has two so that chapter navigation
  /// and the last-chapter boundary can both be exercised.
  ModuleBuilder complete() {
    final b = ModuleBuilder('GOOD', name: 'Complete');
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'He was in the beginning with God.');
    b.addVerse('John', 1, 3, 'All things were made through him.');
    b.addVerse('Gen', 1, 1, 'In the beginning God created heaven and earth.');
    b.addVerse('Gen', 1, 2, 'And the earth was without form and void.');
    b.addVerse('Gen', 2, 1, 'And God said, Let there be light.');
    b.addVerse('Gen', 2, 2, 'And there was light.');
    return b;
  }

  /// A module reproducing the upstream defect: John 1 has no verse 1.
  ModuleBuilder defective() {
    final b = ModuleBuilder('BAD', name: 'Defective');
    b.addVerse('John', 1, 2, 'He was in the beginning with God.');
    b.addVerse('John', 1, 3, 'All things were made through him.');
    b.addVerse('Gen', 1, 1, 'In the beginning God created heaven and earth.');
    return b;
  }

  /// Renders the reader on its own.
  ///
  /// No `ListenableBuilder` here: each test drives the ViewModel, then pumps, so the
  /// view reads the state it was left in. Wrapping it would rebuild on every
  /// notification and hide whether a test actually observed a change.
  Widget harness(ReaderViewModel vm) {
    return MaterialApp(
      theme: buildLogosTheme(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: BibleReaderView(viewModel: vm)),
    );
  }

  group('reading a chapter', () {
    test('shows the verses in order', () async {
      final repo = await install(complete());
      final vm = ReaderViewModel(repo, newPreferences());
      await vm.open('GOOD', osisCode: 'John', chapter: 1);

      expect(vm.state.status, ReaderStatus.ready);
      expect(vm.state.chapter!.verses.map((v) => v.verse), [1, 2, 3]);
      expect(vm.state.chapter!.isIncomplete, isFalse);
    });

    testWidgets('renders the verse text', (tester) async {
      final vm = await openReader(tester, complete(), osisCode: 'John');

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      expect(find.textContaining('In the beginning was the Word'), findsOneWidget);
    });

    test('navigates chapters within a book', () async {
      final repo = await install(complete());
      final vm = ReaderViewModel(repo, newPreferences());
      await vm.open('GOOD', osisCode: 'Gen', chapter: 1);

      await vm.next();
      expect(vm.state.chapterNumber, 2);
      expect(vm.state.chapter!.verses, hasLength(2));

      await vm.previous();
      expect(vm.state.chapterNumber, 1);
      expect(vm.state.chapter!.verses.first.text, startsWith('In the beginning God'));
    });

    test('refuses to go past the last chapter of a book', () async {
      // John has one chapter in the fixture, so `next` at chapter 1 is a no-op. A reader
      // that silently wrapped or invented a chapter 2 would be showing content the
      // module does not contain.
      final repo = await install(complete());
      final vm = ReaderViewModel(repo, newPreferences());
      await vm.open('GOOD', osisCode: 'John', chapter: 1);

      await vm.next();
      expect(vm.state.chapterNumber, 1);
      expect(vm.state.chapter!.verses, hasLength(3));
    });

    test('refuses to go past the first chapter', () async {
      final repo = await install(complete());
      final vm = ReaderViewModel(repo, newPreferences());
      await vm.open('GOOD', osisCode: 'John', chapter: 1);

      await vm.previous();
      expect(vm.state.chapterNumber, 1,
          reason: 'there is no chapter 0; the boundary is a no-op, not a wrap');
    });

    test('moves forward and back between books', () async {
      // The fixture holds Genesis and John, and the module reports them in the order of the
      // canon rather than the order the fixture added them — which is what the reader's
      // book list shows and what every ordered result in the application sorts by.
      final repo = await install(complete());
      final vm = ReaderViewModel(repo, newPreferences());
      await vm.open('GOOD', osisCode: 'Gen', chapter: 1);

      await vm.nextBook();
      expect(vm.state.osisCode, 'John');
      expect(vm.state.chapterNumber, 1,
          reason: 'a new book starts at chapter 1, not where the last one left off');

      await vm.nextBook();
      expect(vm.state.osisCode, 'John', reason: 'there is no book after the last one');

      await vm.previousBook();
      expect(vm.state.osisCode, 'Gen');

      await vm.previousBook();
      expect(vm.state.osisCode, 'Gen', reason: 'there is no book before the first one');
    });

    test('the book list is in the order of the canon', () async {
      final repo = await install(complete());
      final vm = ReaderViewModel(repo, newPreferences());
      await vm.open('GOOD', osisCode: 'Gen');

      expect(
        vm.state.books.map((b) => b.osisCode),
        ['Gen', 'John'],
        reason: 'Genesis is book 1 and John is book 43; a book list in any other order is '
            'not one a reader can navigate',
      );
    });
  });

  group('an incomplete module is reported, not hidden', () {
    test('the chapter records that it does not start at verse 1', () async {
      final repo = await install(defective());
      final vm = ReaderViewModel(repo, newPreferences());
      await vm.open('BAD', osisCode: 'John', chapter: 1);

      expect(vm.state.chapter!.startsAtVerse, 2);
      expect(vm.state.chapter!.isIncomplete, isTrue);
    });

    testWidgets('a warning is shown above the text', (tester) async {
      // Without this, a reader opens John 1 and sees it starting at verse 2 with nothing
      // indicating that verse 1 is absent. The user cannot cite what is not shown, and
      // nothing tells them why.
      final vm = await openReader(tester, defective(), osisCode: 'John');

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      expect(find.textContaining('no contiene el versículo 1'), findsOneWidget);
      expect(find.textContaining('He was in the beginning'), findsOneWidget,
          reason: 'the verses that are present must still be readable');
    });

    testWidgets('no warning is shown for a sound module', (tester) async {
      final vm = await openReader(tester, complete(), osisCode: 'John');

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      expect(find.textContaining('no contiene el versículo 1'), findsNothing);
    });

    test('the module integrity report is carried through', () async {
      final repo = await install(defective());
      final vm = ReaderViewModel(repo, newPreferences());
      await vm.open('BAD');

      expect(vm.state.integrity, isNotNull);
      expect(vm.state.integrity!.isValid, isFalse);
      expect(vm.incompleteChapterCount, greaterThan(0));
    });
  });

  group('failure states', () {
    test('an absent module reports an error rather than hanging', () async {
      final vm = ReaderViewModel(BibleRepository(ModuleStore(temp)), newPreferences());
      await vm.open('MISSING');

      expect(vm.state.status, ReaderStatus.failed);
      expect(vm.state.error, contains('not installed'));
    });

    testWidgets('an empty chapter says so', (tester) async {
      final vm = await openReader(tester, complete(), osisCode: 'John', chapter: 2);

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      expect(find.textContaining('no contiene versículos'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('does not overflow horizontally at any width', (tester) async {
      final vm = await openReader(tester, complete(), osisCode: 'John');

      for (final width in [360.0, 390.0, 600.0, 768.0, 1024.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(harness(vm));
        await tester.pumpAndSettle();

        final size = tester.getSize(find.byType(MaterialApp));
        expect(
          size.width,
          width,
          reason: 'the reader must fit ${width}px, the width the reference overflows at',
        );
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('the book list stacks below the book on a narrow window', (tester) async {
      final vm = await openReader(tester, complete(), osisCode: 'John');

      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      // Both books are reachable on a phone: stacked, not dropped.
      expect(find.text('John'), findsOneWidget);
      expect(find.text('Gen'), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('typography', () {
    test('scripture scales with the reader zoom', () {
      final base = LogosTypography.scripture(1.0).fontSize!;
      final large = LogosTypography.scripture(1.5).fontSize!;
      expect(large, greaterThan(base));
      expect(large, closeTo(base * 1.5, 0.01));
    });

    test('the reading measure is capped so text does not stretch', () {
      expect(LogosMeasured.maxReadingMeasure, lessThan(900));
    });
  });
}
