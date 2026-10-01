import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/domain/reader/reader_find.dart';
import 'package:logos_engine/domain/search/logos_text.dart';
import 'package:logos_engine/ui/core/theme/logos_theme.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_preferences.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_view_model.dart';
import 'package:logos_engine/ui/features/reader/views/bible_reader_view.dart';

import 'support/module_builder.dart';

/// Task 8.9 — the find bar: highlight, count, and stepping.
///
/// The module here is one Bible with two Testaments' worth of vocabulary, because every part
/// of a find bar is a claim about a whole module rather than about the visible chapter: the
/// count has to be the module's, and stepping has to cross a chapter boundary.
void main() {
  late Directory temp;
  late ReaderPreferencesViewModel preferences;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-find-');
    preferences = ReaderPreferencesViewModel(InMemoryReaderStore());
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  ModuleBuilder fixture() {
    final b = ModuleBuilder('FIND', name: 'Findable');
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'The same was in the beginning with God.');
    b.addVerse('John', 1, 3, 'All things were made by him.');
    b.addVerse('John', 2, 1, 'After this there was a wedding in Cana of Galilee.');
    b.addVerse('Gen', 1, 1, 'In the beginning God created heaven and earth.');
    b.addVerse('Gen', 1, 2, 'And the earth was without form and void.');
    // A verse with the term twice, which is what makes "every occurrence" differ from
    // "every verse".
    b.addVerse('Ps', 23, 1, 'The beginning is wisdom, and the end is wisdom.');
    b.addVerse('Ps', 23, 2, 'The earth is the Lord’s, and the fullness thereof.');
    return b;
  }

  Future<ReaderViewModel> open(ModuleBuilder builder, {String? osisCode, int chapter = 1}) async {
    await builder.writeTo(temp);
    final vm = ReaderViewModel(BibleRepository(ModuleStore(temp)), preferences);
    await vm.open(builder.id, osisCode: osisCode ?? 'John', chapter: chapter);
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

  group('the offsets a find reports', () {
    test('are in the verse’s own text, not the chapter’s', () {
      // The chapter is one string to the reader and several to the module. A highlight
      // computed in chapter coordinates and applied to a verse would be off by every
      // preceding verse — plausible-looking and wrong.
      final spans = LogosText.spansInOriginal('In the beginning was the Word.', 'beginning');
      expect(spans, hasLength(1));
      expect('In the beginning was the Word.'.substring(spans.single.start, spans.single.end),
          'beginning');
    });

    test('count every occurrence in a verse, not just the first', () {
      final spans = LogosText.spansInOriginal(
        'The beginning is wisdom, and the end is wisdom.',
        'wisdom',
      );
      expect(spans, hasLength(2));
    });

    test('count overlapping occurrences', () {
      // `ana` in `banana` occurs twice. A reader stepping through matches has to see both.
      final spans = LogosText.spansInOriginal('banana', 'ana');
      expect(spans, hasLength(2));
    });

    test('find a term regardless of case', () {
      expect(LogosText.spansInOriginal('The Word was with God', 'word'), hasLength(1));
    });

    test('find an accented word from an unaccented query', () {
      // The reason the modules are indexed `remove_diacritics`: this is what people type.
      expect(LogosText.spansInOriginal('Jesús', 'Jesus'), hasLength(1));
    });

    test('not match a term that only differs by an expanding fold', () {
      // `Æ` folds to `ae`, which changes the string's length, so an offset measured on the
      // folded text would index the wrong characters. Reported as no match — a missed hit —
      // rather than as a highlight over the wrong words.
      expect(LogosText.spansInOriginal('Æther', 'ae'), isEmpty);
    });

    test('an empty term matches nothing rather than everything', () {
      expect(LogosText.spansInOriginal('anything', ''), isEmpty);
    });
  });

  group('finding in a module', () {
    test('reports every occurrence across the whole module', () async {
      await open(fixture());
      final finder = ModuleFinder(BibleRepository(ModuleStore(temp)));

      final result = await finder.find('FIND', 'beginning');

      // John 1:1, John 1:2, Gen 1:1, Ps 23:1 — four verses, four occurrences.
      expect(result.count, 4);
    });

    test('counts a term twice in one verse separately', () async {
      await open(fixture());
      final finder = ModuleFinder(BibleRepository(ModuleStore(temp)));

      expect((await finder.find('FIND', 'wisdom')).count, 2);
    });

    test('the matches are in reading order', () async {
      await open(fixture());
      final result = await ModuleFinder(BibleRepository(ModuleStore(temp))).find(
        'FIND',
        'beginning',
      );

      expect(
        result.matches.map((m) => '${m.osisCode} ${m.chapter}:${m.verse}'),
        ['Gen 1:1', 'Ps 23:1', 'John 1:1', 'John 1:2'],
        reason: 'stepping through matches has to walk the Bible the way it is read',
      );
    });

    test('a term with no occurrences returns an empty result', () async {
      await open(fixture());

      final result = await ModuleFinder(BibleRepository(ModuleStore(temp)))
          .find('FIND', 'qabal');

      expect(result.isEmpty, isTrue);
      expect(result.count, 0);
    });

    test('an empty term searches nothing rather than everything', () async {
      await open(fixture());

      final result = await ModuleFinder(BibleRepository(ModuleStore(temp))).find('FIND', '   ');

      expect(result.isEmpty, isTrue);
    });

    test('reports every chapter a term appears in', () async {
      await open(fixture());

      final result = await ModuleFinder(BibleRepository(ModuleStore(temp)))
          .find('FIND', 'earth');

      // Gen 1:1, Gen 1:2 and Ps 23:2 — three chapters in two books. A find that stopped at
      // the first book would look complete next to a count of three.
      expect(result.count, 3);
      expect(
        result.matches.map((m) => '${m.osisCode} ${m.chapter}:${m.verse}'),
        ['Gen 1:1', 'Gen 1:2', 'Ps 23:2'],
      );
    });
  });

  group('the session', () {
    test('carries the term and reports the count', () async {
      final vm = await open(fixture());

      await vm.find('beginning');

      final find = vm.state.find;
      expect(find.term, 'beginning');
      expect(find.matchCount, 4);
      expect(find.hasMatches, isTrue);
    });

    test('the label counts from one, as a person counting would', () async {
      // Opened at Psalms, whose verse carries the term, so the reader lands on that
      // occurrence. In reading order the matches are Gen 1:1, Ps 23:1, John 1:1, John 1:2 —
      // so Psalms is the second, not the third.
      final vm = await open(fixture(), osisCode: 'Ps', chapter: 23);

      await vm.find('beginning');

      expect(vm.state.find.label, '2 de 4',
          reason: 'a count starting at zero reads as though a match were missing, and the '
              'number shown must be the one for the match the reader is actually on');
      expect(vm.state.find.activeMatch!.osisCode, 'Ps');
    });

    test('a term with no matches says so', () async {
      final vm = await open(fixture());

      await vm.find('qabal');

      expect(vm.state.find.label, 'Sin coincidencias');
      expect(vm.state.find.hasMatches, isFalse);
    });

    test('an emptied term clears the session but leaves the bar open', () async {
      // The reader is still typing; closing the bar under them would be a surprise.
      final vm = await open(fixture());
      await vm.find('beginning');

      await vm.find('');

      expect(vm.state.find.matchCount, 0);
      expect(vm.state.find.term, isEmpty);
      expect(vm.state.isFindBarVisible, isTrue);
    });

    test('a trailing wildcard finds the words extending a stem', () async {
      final vm = await open(fixture());

      await vm.find('beginn*');

      expect(vm.state.find.matchCount, 4,
          reason: 'a trailing * is a prefix query, which FTS5 answers directly. It has to '
              'be handed to the engine unquoted — `"beginn" *` is a syntax error there, so '
              'quoting the prefix query would make it match nothing');
    });

    test('a term of punctuation reports nothing rather than failing', () async {
      // `?` is a syntax error in FTS5 and `NEAR` parses and matches nothing. A find bar that
      // surfaced either would report a database failure to someone who merely typed a word.
      final vm = await open(fixture());

      await vm.find('---');

      expect(vm.state.find.matchCount, 0);
      expect(vm.state.find.error, isNull,
          reason: 'no matches is an answer; an exception is not');
    });
  });

  group('stepping', () {
    test('advances through every match and wraps', () async {
      final vm = await open(fixture());
      await vm.find('beginning');
      final total = vm.state.find.matchCount;
      final start = vm.state.find.activeIndex;

      // Walk the whole ring once, checking the label at each step. The expected number is
      // computed rather than written out, because where the search starts depends on where
      // the reader was — and a hand-written sequence would be asserting that, not the ring.
      for (var step = 1; step <= total; step++) {
        await vm.nextMatch();
        final expected = (start + step) % total + 1;
        expect(vm.state.find.label, '$expected de $total');
      }

      expect(vm.state.find.activeIndex, start,
          reason: 'after one full turn the reader is back where they started');
    });

    test('steps backwards and wraps the other way', () async {
      final vm = await open(fixture());
      await vm.find('beginning');
      final start = vm.state.find.activeIndex;
      final total = vm.state.find.matchCount;

      await vm.previousMatch();

      expect(vm.state.find.activeIndex, start == 0 ? total - 1 : start - 1);
      expect(
        vm.state.find.label,
        '${start == 0 ? total : start} de $total',
        reason: 'stepping back from the first match lands on the last',
      );
    });

    test('the active match is the one the reader is looking at', () async {
      final vm = await open(fixture());
      await vm.find('beginning');

      await vm.nextMatch();
      final first = vm.state.find.activeMatch;
      await vm.nextMatch();

      expect(vm.state.find.activeMatch, isNot(first));
    });

    test('finding lands on a match in the chapter the reader is on', () async {
      // The reader is in John 1, which carries two of the four matches. Finding has to leave
      // them there rather than yanking them to Genesis.
      final vm = await open(fixture(), osisCode: 'John', chapter: 1);

      await vm.find('beginning');

      expect(vm.state.find.activeMatch!.osisCode, 'John');
      expect(vm.state.osisCode, 'John');
      expect(vm.state.chapterNumber, 1);
    });

    test('finding moves the reader when the chapter they are on has no match', () async {
      // John 2 mentions neither term, so the find has to take the reader where the matches
      // actually are rather than report a count they cannot get to.
      final vm = await open(fixture(), osisCode: 'John', chapter: 2);

      await vm.find('beginning');

      expect(vm.state.osisCode, isNot('John'),
          reason: 'there is no match in John 2, so the reader is taken to one that exists');
      expect(vm.state.find.activeMatch!.osisCode, vm.state.osisCode);
      expect(vm.state.focusVerse, 1);
    });

    test('stepping on moves to the next match, in another chapter if need be', () async {
      // John 1:1 then John 1:2, then Genesis. Each step changes where the reader is looking.
      final vm = await open(fixture(), osisCode: 'John', chapter: 1);
      await vm.find('beginning');

      expect(vm.state.focusVerse, 1);
      await vm.nextMatch();
      expect(vm.state.focusVerse, 2,
          reason: 'John 1:2 carries the term too, and that is where the reader lands');

      await vm.nextMatch();
      expect(vm.state.osisCode, 'Gen',
          reason: 'the next match is in another book, and the reader follows it');
      expect(vm.state.chapterNumber, 1);
    });

    test('stepping does nothing when there are no matches', () async {
      final vm = await open(fixture());
      await vm.find('qabal');

      await vm.nextMatch();
      await vm.previousMatch();

      expect(vm.state.find.activeMatch, isNull);
      expect(vm.state.osisCode, 'John',
          reason: 'a find that matches nothing must not move the reader');
    });

    test('the reader starts from the passage it is already on', () async {
      // Finding a word the reader can see on screen should land them on that occurrence,
      // not on the first one somewhere else in the Bible.
      final vm = await open(fixture(), osisCode: 'Ps', chapter: 23);
      await vm.find('beginning');

      final active = vm.state.find.activeMatch!;
      expect(active.osisCode, 'Ps');
      expect(active.verse, 1);
    });

    test('every match can be cited', () async {
      await open(fixture());

      final result = await ModuleFinder(BibleRepository(ModuleStore(temp)))
          .find('FIND', 'beginning');

      for (final m in result.matches) {
        expect(m.text, matches(RegExp(r'.+ \d+:\d+$')),
            reason: 'a match must be reportable as a citation');
      }
    });
  });

  group('the bar', () {
    testWidgets('shows the count once a term is typed', (tester) async {
      final vm = await openIn(tester, fixture());
      vm.toggleFindBar();

      await tester.pumpWidget(_harness(vm));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'beginning');
      await settle(tester);

      expect(vm.state.find.matchCount, 4);
      expect(find.text(vm.state.find.label), findsOneWidget,
          reason: 'the count is the load-bearing part of a find bar: without it the reader '
              'cannot tell "that is all of them" from "there may be more"');
    });

    testWidgets('the count follows the match the reader steps onto', (tester) async {
      // Opened at Psalms so the first match is the second of four, and one step is
      // unambiguous rather than a wrap.
      final vm = await openIn(tester, fixture(), osisCode: 'Ps', chapter: 23);
      vm.toggleFindBar();

      await tester.pumpWidget(_harness(vm));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'beginning');
      await settle(tester);
      expect(vm.state.find.label, '2 de 4');

      await tester.tap(find.byTooltip('Coincidencia siguiente'));
      await settle(tester);

      expect(vm.state.find.label, '3 de 4');
      expect(find.text('3 de 4'), findsOneWidget);
    });

    testWidgets('says so when there is nothing to find', (tester) async {
      final vm = await openIn(tester, fixture());
      vm.toggleFindBar();

      await tester.pumpWidget(_harness(vm));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'qabal');
      await settle(tester);

      expect(find.text('Sin coincidencias'), findsOneWidget);
    });

    testWidgets('stepping is disabled with no matches and enabled with some', (tester) async {
      final vm = await openIn(tester, fixture());
      vm.toggleFindBar();

      await tester.pumpWidget(_harness(vm));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'qabal');
      await settle(tester);

      expect(vm.state.find.hasMatches, isFalse);

      await tester.enterText(find.byType(TextField), 'beginning');
      await settle(tester);

      expect(vm.state.find.hasMatches, isTrue);
    });

    testWidgets('the bar can be closed', (tester) async {
      final vm = await openIn(tester, fixture());
      vm.toggleFindBar();

      await tester.pumpWidget(_harness(vm));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar la búsqueda'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(vm.state.isFindBarVisible, isFalse);
    });

    testWidgets('toggling the toolbar control opens and closes the bar', (tester) async {
      final vm = await openIn(tester, fixture());

      await tester.pumpWidget(_harness(vm));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byTooltip('Buscar en este recurso'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget,
          reason: 'an open bar with nothing typed is a state the reader must reach');

      await tester.tap(find.byTooltip('Cerrar la búsqueda'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });  });

  group('highlighting', () {
    test('matches in the visible chapter are the ones highlighted', () async {
      final vm = await open(fixture(), osisCode: 'John', chapter: 1);
      await vm.find('beginning');

      final inChapter = vm.state.find.result!.inChapter('John', 1);

      expect(inChapter.map((m) => m.verse), [1, 2]);
    });

    test('a chapter with no matches highlights nothing', () async {
      final vm = await open(fixture(), osisCode: 'John', chapter: 2);
      await vm.find('qabal');

      expect(vm.state.find.result!.inChapter('John', 2), isEmpty);
    });
  });
}

/// Lets a find finish before asserting on it.
///
/// The search reads SQLite, which cannot complete under the fake clock, and
/// `pumpAndSettle` alone would return before it did — leaving the reader on the previous
/// count and the test asserting about a bar that had not updated yet.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pumpAndSettle();
}

/// The find bar alone, filling the screen.
///
/// The whole reader rather than just the bar: the bar is only meaningful against a chapter
/// it can step through, and a harness that showed the field with nothing behind it would let
/// a broken count pass.
Widget _harness(ReaderViewModel vm) => MaterialApp(
      theme: buildLogosTheme(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: BibleReaderView(viewModel: vm)),
    );
