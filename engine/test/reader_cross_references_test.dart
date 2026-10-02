import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/domain/models/reader_settings.dart';
import 'package:logos_engine/ui/core/theme/logos_colors.dart';
import 'package:logos_engine/ui/core/theme/reading_palette.dart';
import 'package:logos_engine/ui/features/reader/reader_chapter_layout.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_preferences.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_view_model.dart';
import 'package:logos_engine/ui/features/reader/views/bible_reader_view.dart';

import 'support/module_builder.dart';

void main() {
  late Directory temp;
  // Repositorios entregados a los view models de cada test. Ninguno tiene
  // `dispose` — no son `ChangeNotifier` con vida propia — asi que sin esta
  // lista el test que abre un modulo deja su copia entera (39 MB para el KJV)
  // en el tmpfs del sistema, para siempre.
  final repos = <BibleRepository>[];

  /// A repository over the test's modules, released when the test ends.
  ///
  /// `BibleRepository.open` extracts the module to a database file on disk and
  /// only `dispose()` removes it, so an inline
  /// `BibleRepository(ModuleStore(temp))` reads as if it were free and leaks a copy of the module per call. Every
  /// repository this suite builds goes through here.
  BibleRepository tracked() {
    final repo = BibleRepository(ModuleStore(temp));
    repos.add(repo);
    return repo;
  }
  late ReaderPreferencesViewModel preferences;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-xref-');
    preferences = ReaderPreferencesViewModel(InMemoryReaderStore());
  });

  tearDown(() {
    for (final r in repos.reversed) {
      r.dispose();
    }
    repos.clear();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A module whose verse text contains the phrases its references hang off.
  ///
  /// Every target book's verses are present, so no reference points outside the module —
  /// that case is a separate test below.
  ModuleBuilder linked() {
    final b = ModuleBuilder('XREF', name: 'Linked');
    b.addVerse('Gen', 1, 1, 'In the beginning God created heaven and earth.');
    b.addVerse('Gen', 1, 2, 'And the earth was without form and void.');
    b.addVerse('Exod', 1, 1, 'Remember the sabbath day to keep it holy.');
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'The same was in the beginning with God.');
    b.addVerse('John', 1, 3, 'All things were made by him.');
    b.addVerse('Prov', 8, 22, 'The Lord possessed me in the beginning of his way.');

    // `beginning` in Gen 1:1 points at four passages, three of them in John.
    b.addCrossReference(
      fromBook: 'Gen',
      fromChapter: 1,
      fromVerse: 1,
      anchor: 'beginning',
      targets: ['Prov:8:22', 'John:1:1', 'John:1:2', 'John:1:3'],
    );
    // A second phrase in the same verse, pointing somewhere else entirely. This is the case
    // a verse-level model cannot represent at all.
    b.addCrossReference(
      fromBook: 'Gen',
      fromChapter: 1,
      fromVerse: 1,
      anchor: 'God',
      targets: ['Exod:1:1'],
    );
    b.addCrossReference(
      fromBook: 'John',
      fromChapter: 1,
      fromVerse: 1,
      anchor: 'beginning',
      targets: ['Gen:1:1'],
    );
    return b;
  }

  /// A module whose reference names a phrase its text does not contain: what a module gets
  /// when the cross-reference set was written against a different edition of the same
  /// translation.
  ModuleBuilder drifted() {
    final b = ModuleBuilder('DRIFT', name: 'Drifted');
    b.addVerse('Gen', 1, 1, 'In the beginning God created heaven and earth.');
    b.addVerse('Job', 38, 7, 'And the morning stars sang together.');
    b.addCrossReference(
      fromBook: 'Gen',
      fromChapter: 1,
      fromVerse: 1,
      anchor: 'when the morning sang',
      targets: ['Job:38:7'],
    );
    return b;
  }

  /// Writes the module and loads a chapter, without a tester.
  ///
  /// The widget tests wrap this in [WidgetTester.runAsync], because awaiting real file and
  /// database I/O under the fake clock never completes. The plain tests call it directly.
  Future<ReaderViewModel> open(
    ModuleBuilder builder, {
    String? osisCode,
    int chapter = 1,
  }) async {
    await builder.writeTo(temp);
    final vm = ReaderViewModel(tracked(), preferences);
    await vm.open(builder.id, osisCode: osisCode ?? 'Gen', chapter: chapter);
    return vm;
  }

  Future<ReaderViewModel> openIn(
    WidgetTester tester,
    ModuleBuilder builder, {
    String? osisCode,
    int chapter = 1,
  }) async {
    late ReaderViewModel vm;
    await tester.runAsync(
      () async => vm = await open(builder, osisCode: osisCode, chapter: chapter),
    );
    return vm;
  }

  Widget harness(ReaderViewModel vm) =>
      MaterialApp(home: Scaffold(body: BibleReaderView(viewModel: vm)));

  /// Lets real I/O finish after a gesture.
  ///
  /// Following a reference reads the target chapter from SQLite, and that cannot complete
  /// under the test's fake clock — the test would see the reader still on the old chapter and
  /// conclude the link is dead. [WidgetTester.runAsync] is the only place a widget test can
  /// hand control back to the real event loop.
  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  /// The cross-reference markers the reader is actually showing.
  ///
  /// Taken from the *rendered* span tree rather than from the layout the reader computes for
  /// itself. A reference that is in the model but has no recognizer in the tree is a link
  /// the reader cannot click, and only the rendered tree shows that.
  List<TextSpan> renderedReferences(WidgetTester tester) {
    final span = tester
        .widget<Text>(find.byKey(const ValueKey('chapter-rich-text')))
        .textSpan!;
    final found = <TextSpan>[];
    span.visitChildren((child) {
      if (child is TextSpan && child.recognizer != null) found.add(child);
      return true;
    });
    return found;
  }

  /// Activates the marker whose text contains [needle].
  ///
  /// The recognizer is fired directly rather than tapped by coordinate. A tap lands on the
  /// centre of the paragraph's box, which is body text rather than the link — the marker is a
  /// short run inside a long line, so a coordinate tap either misses or tests something else.
  /// Firing the recognizer is also what the gesture arena does once a real tap wins, so it
  /// exercises the same path without depending on where the text happens to wrap.
  Future<void> activate(WidgetTester tester, String needle) async {
    final match = renderedReferences(tester)
        .where((s) => (s.text ?? '').contains(needle))
        .toList();
    expect(match, hasLength(1),
        reason: 'expected exactly one marker containing "$needle"; the chapter shows '
            '${renderedReferences(tester).map((s) => s.text)}');

    (match.single.recognizer! as dynamic).onTap();
    await settleIo(tester);
  }

  /// The layout the chapter is drawn from.
  ChapterLayout layoutOf(ReaderViewModel vm) {
    final state = vm.state;
    return buildChapterLayout(state.chapter!, vm.settings, books: state.books);
  }

  List<CrossReferenceRun> referencesIn(ChapterLayout layout) => [
        for (final s in layout.segments)
          if (s.crossReference != null) s.crossReference!,
      ];

  /// The chapter as one string, in drawing order.
  String flattened(ChapterLayout layout) =>
      layout.segments.map((s) => s.text).join();

  group('reading the module', () {
    test('a chapter reports every reference anchored in it', () async {
      // The reader opens at Gen 1, so this is Gen's count. John 1:1's own reference belongs
      // to that chapter and is reported when John is opened.
      final vm = await open(linked());

      expect(vm.state.chapter!.crossReferenceCount, 5,
          reason: 'Gen 1:1 has four from "beginning" and one from "God"');
    });

    test('a different chapter reports its own references', () async {
      final vm = await open(linked(), osisCode: 'John');

      expect(vm.state.chapter!.crossReferenceCount, 1);
      expect(vm.state.chapter!.referencesFor(1).single.anchor, 'beginning');
    });

    test('references are grouped by the phrase they hang off', () async {
      final vm = await open(linked());
      final groups = vm.state.chapter!.referencesFor(1);

      expect(groups.map((g) => g.anchor), ['beginning', 'God']);
      expect(groups.first.references, hasLength(4));
      expect(groups.last.references, hasLength(1));
    });

    test('a module whose references outlived its text still opens', () async {
      final vm = await open(drifted());

      expect(vm.state.status, ReaderStatus.ready,
          reason: 'an unresolvable reference is not a reason to refuse the chapter');
    });
  });

  group('placement', () {
    test('a marker follows the phrase it belongs to', () async {
      final vm = await open(linked());
      final text = flattened(layoutOf(vm));

      // `beginning` is at the start of Gen 1:1, so its marker comes after the word and before
      // the rest of the verse. `God` comes later in the same verse, so its marker must come
      // after that instead — which is the whole reason the references are phrase-level.
      expect(text.indexOf('(Prov'), greaterThan(text.indexOf('beginning')));
      expect(text.indexOf('(Exod'), greaterThan(text.indexOf(' God ')));
      expect(text.indexOf('(Exod'), greaterThan(text.indexOf('(Prov')));
    });

    test('a marker comes before the rest of its verse, not after it', () async {
      final vm = await open(linked());
      final text = flattened(layoutOf(vm));

      expect(
        text.indexOf('(Prov'),
        lessThan(text.indexOf('created heaven and earth')),
        reason: 'a marker appended to the verse would be half a sentence from the word it '
            'belongs to',
      );
    });

    test('one marker holds every passage its phrase points at', () async {
      final vm = await open(linked());
      final beginning =
          referencesIn(layoutOf(vm)).firstWhere((r) => r.label.contains('Prov'));

      expect(beginning.targets, hasLength(4),
          reason: 'a phrase with four passages is one marker, not four');
      expect(beginning.label.trim(), '(Prov 8:22; John 1:1; John 1:2; John 1:3)');
    });

    test('a phrase the module does not contain still gets its link', () async {
      final vm = await open(drifted());
      final runs = referencesIn(layoutOf(vm));

      expect(runs, hasLength(1));
      expect(runs.single.label.trim(), '(Job 38:7)');
    });

    test('no character of the verse text is lost or repeated', () async {
      // The layout splits and rejoins the verse around its markers, so this is where a slice
      // written twice or dropped shows up. Markers are stripped first: they are inserted
      // *inside* the text, which is the point of phrase-level references and the reason the
      // verse's own words are no longer contiguous.
      final vm = await open(linked());
      final layout = layoutOf(vm);

      final drawn = layout.segments
          .where((s) => s.role == SegmentRole.body || s.role == SegmentRole.verseNumber)
          .map((s) => s.text)
          .join()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final expected = vm.state.chapter!.verses
          .map((v) => ' ${v.verse} ${v.text} ')
          .join()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      expect(drawn, expected);
    });
  });

  group('appearance', () {
    test('a cross-reference uses the link colour', () {
      const settings = ReaderSettings();
      final style = ChapterLayoutProbe.layout.styleFor(
        ChapterSegmentProbe.reference,
        settings,
        ReadingPalette.of(settings.colourScheme),
      );

      expect(style.color, LogosColors.link);
      expect(style.color?.toARGB32(), 0xFF1E6AFE,
          reason: 'link-color, the token the requirement names');
    });

    test('a cross-reference is distinguishable without relying on hue alone', () {
      // A reader who cannot distinguish that blue from every other blue on the page still has
      // to be able to tell these are links.
      const settings = ReaderSettings();
      final palette = ReadingPalette.of(settings.colourScheme);
      const layout = ChapterLayoutProbe.layout;

      final reference = layout.styleFor(ChapterSegmentProbe.reference, settings, palette);
      final body = layout.styleFor(ChapterSegmentProbe.body, settings, palette);

      expect(reference.decoration, isNotNull);
      expect(body.decoration, isNull);
      expect(reference.color, isNot(body.color));
    });

    testWidgets('every rendered marker carries a recognizer', (tester) async {
      final vm = await openIn(tester, linked());

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      // Three markers in Gen 1:1's chapter: two phrases in verse 1, one in John. Wait — this
      // module opens at Gen 1, so only its two markers are on screen.
      expect(renderedReferences(tester), hasLength(2),
          reason: 'a marker drawn without a recognizer is not a link');
    });
  });

  group('following and returning', () {
    testWidgets('activating a reference navigates to it', (tester) async {
      final vm = await openIn(tester, linked());

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      await activate(tester, '(Prov 8:22');

      // The marker names four passages; following it goes to the first, in the module's own
      // order. The rest are listed in the marker's own text.
      expect(vm.state.osisCode, 'Prov');
      expect(vm.state.chapterNumber, 8);
      expect(vm.state.focusVerse, 22);
    });

    testWidgets('the previous position is restored on the way back', (tester) async {
      // The requirement's second half, and the half that is easy to leave out: without it,
      // following a reference is a one-way door.
      final vm = await openIn(tester, linked(), osisCode: 'Gen');
      expect(vm.state.canGoBack, isFalse,
          reason: 'nothing has been followed yet, so there is nowhere to return to');

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      await activate(tester, '(Prov 8:22');
      expect(vm.state.osisCode, 'Prov');

      await tester.runAsync(() => vm.goBack());
      await settleIo(tester);

      expect(vm.state.osisCode, 'Gen',
          reason: 'returning must land on the book the reader came from');
      expect(vm.state.chapterNumber, 1);
      expect(vm.state.canGoBack, isFalse,
          reason: 'and unwind the history rather than walk forward down it');
    });

    testWidgets('back restores the verse, not just the chapter', (tester) async {
      final vm = await openIn(tester, linked(), osisCode: 'Gen');

      await tester.runAsync(() => vm.show('John', 1, verse: 3));
      await settleIo(tester);
      expect(vm.state.focusVerse, 3);

      await tester.runAsync(() => vm.show('Gen', 1));
      await settleIo(tester);
      await tester.runAsync(() => vm.show('John', 1, verse: 2));
      await settleIo(tester);

      await tester.runAsync(() => vm.goBack());
      await settleIo(tester);

      expect(vm.state.osisCode, 'Gen',
          reason: 'the reader was last on Gen 1 before moving to John');
    });

    testWidgets('going back repeatedly unwinds a chain', (tester) async {
      final vm = await openIn(tester, linked(), osisCode: 'Gen');

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      await activate(tester, '(Prov 8:22');
      expect(vm.state.osisCode, 'Prov');

      // Two more moves, so the history is Gen → Prov → John → Prov. The last one is a
      // deliberate no-op in the view: it re-opens the passage already showing, which must not
      // add an entry of its own.
      await tester.runAsync(() => vm.show('John', 1));
      await settleIo(tester);
      await tester.runAsync(() => vm.show('Prov', 8));
      await settleIo(tester);

      await tester.runAsync(() => vm.goBack());
      await settleIo(tester);
      expect(vm.state.osisCode, 'John', reason: 'the most recent move is undone first');

      await tester.runAsync(() => vm.goBack());
      await settleIo(tester);
      expect(vm.state.osisCode, 'Prov',
          reason: 'unwinding walks down the history, not back up to where we came from');

      await tester.runAsync(() => vm.goBack());
      await settleIo(tester);
      expect(vm.state.osisCode, 'Gen');
      expect(vm.state.canGoBack, isFalse,
          reason: 'the history is exhausted, and the control says so');
    });

    testWidgets('the back control is offered only once there is somewhere to go',
        (tester) async {
      final vm = await openIn(tester, linked());

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Volver a la posición anterior'), findsOneWidget);
      expect(vm.state.canGoBack, isFalse);

      await activate(tester, '(Prov 8:22');
      expect(vm.state.canGoBack, isTrue,
          reason: 'having followed a reference, the reader needs a way back');
    });

    testWidgets('following a reference into the passage already open does not stack history',
        (tester) async {
      // Unwinding a self-reference would make the back control appear to do nothing.
      final vm = await openIn(tester, linked(), osisCode: 'John');

      await tester.runAsync(() => vm.show('John', 1));
      await settleIo(tester);

      await tester.runAsync(() => vm.show('Gen', 1));
      await settleIo(tester);
      await tester.runAsync(() => vm.show('John', 1));
      await settleIo(tester);

      final depth = vm.state.canGoBack;
      await tester.runAsync(() => vm.show('John', 1));
      await settleIo(tester);

      expect(vm.state.canGoBack, depth,
          reason: 'moving to the position already open must not add a history entry');
    });
  });

  group('references that cannot be followed', () {
    test('a target in a book the module lacks is still drawn', () async {
      // The reader may have another translation installed that has it, so hiding the link
      // would remove information the reader could still act on elsewhere.
      final b = linked();
      b.addCrossReference(
        fromBook: 'Gen',
        fromChapter: 1,
        fromVerse: 1,
        anchor: 'God',
        targets: ['Rev:22:21'],
        allowMissingTargetBook: true,
      );
      final vm = await open(b);

      final runs = referencesIn(layoutOf(vm));
      final unknown = runs
          .expand((r) => r.targets)
          .firstWhere((t) => !t.isPresent);

      expect(unknown.osisCode, unknownBook,
          reason: 'the row names a bookId the module does not declare, so there is no name '
              'to write; the marker says so rather than inventing one');
      expect(unknown.isPresent, isFalse);
      expect(runs.firstWhere((r) => r.targets.contains(unknown)).isNavigable, isFalse);
      expect(runs, hasLength(2),
          reason: 'the reference is still drawn; the reader just cannot click it');
    });

    testWidgets('a dangling reference does not stop the reader rendering its links',
        (tester) async {
      final b = linked();
      b.addCrossReference(
        fromBook: 'Gen',
        fromChapter: 1,
        fromVerse: 1,
        anchor: 'God',
        targets: ['Rev:22:21'],
        allowMissingTargetBook: true,
      );
      final vm = await openIn(tester, b);

      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();

      expect(renderedReferences(tester), hasLength(2),
          reason: 'a marker the reader cannot follow is still a marker the reader sees');
      expect(vm.state.status, ReaderStatus.ready);
    });

    test('a target verse absent from the module does not stop the chapter loading', () async {
      // A versification difference between the reference set and this translation: the
      // reference is real, the passage it names is not in this module.
      final b = linked();
      b.addCrossReference(
        fromBook: 'Gen',
        fromChapter: 1,
        fromVerse: 1,
        anchor: 'beginning',
        targets: ['John:1:99'],
      );
      final vm = await open(b);

      expect(vm.state.status, ReaderStatus.ready);
      expect(vm.state.chapter!.crossReferenceCount, greaterThan(0));
    });
  });
}

/// Segments for the styling assertions, which need a layout but not a module.
///
/// Built by hand because the question being asked is what style one role is drawn in, and
/// answering it should not require a chapter of scripture on disk.
class ChapterLayoutProbe {
  const ChapterLayoutProbe._();

  /// One body run and one cross-reference, which is all the styling questions need.
  static const ChapterLayout layout = ChapterLayout(segments: [
    ChapterSegmentProbe.body,
    ChapterSegmentProbe.reference,
  ]);
}

class ChapterSegmentProbe {
  const ChapterSegmentProbe._();

  static const CrossReferenceRun _run = CrossReferenceRun(
    label: '(John 1:1)',
    targets: [
      CrossReferenceTarget(
        osisCode: 'John',
        label: 'John 1:1',
        chapter: 1,
        verse: 1,
      ),
    ],
  );

  static const ChapterSegment reference = ChapterSegment(
    role: SegmentRole.crossReference,
    text: '(John 1:1)',
    start: 18,
    verse: 1,
    crossReference: _run,
  );

  static const ChapterSegment body = ChapterSegment(
    role: SegmentRole.body,
    text: 'In the beginning ',
    start: 0,
    verse: 1,
  );
}
