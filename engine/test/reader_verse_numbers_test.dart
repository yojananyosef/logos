import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/domain/models/reader_settings.dart';
import 'package:logos_engine/ui/core/theme/logos_colors.dart';
import 'package:logos_engine/ui/core/theme/logos_theme.dart';
import 'package:logos_engine/ui/core/theme/reading_palette.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_preferences.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_view_model.dart';
import 'package:logos_engine/ui/features/reader/views/bible_reader_view.dart';
import 'package:logos_engine/ui/features/reader/views/reader_format_panel.dart';

import 'support/module_builder.dart';

/// Task 8.2 — inline verse numbers, in the three styles the reference offers.
///
/// Read off the rendered `RichText` rather than off the ViewModel, because the question
/// this answers is what the reader sees: a number present in state and absent from the
/// chapter is still a missing number.
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
  late ReaderViewModel vm;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-verse-numbers-');
    preferences = ReaderPreferencesViewModel(InMemoryReaderStore());
  });

  tearDown(() {
    for (final r in repos.reversed) {
      r.dispose();
    }
    repos.clear();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  ModuleBuilder fixture() {
    final b = ModuleBuilder('NUM', name: 'Numbered');
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'He was in the beginning with God.');
    b.addVerse('John', 1, 3, 'All things were made through him.');
    return b;
  }

  /// Writes the module and loads a chapter.
  ///
  /// Inside [WidgetTester.runAsync] because these tests are widget tests, and awaiting real
  /// file and database I/O under the fake clock never completes — the microtask queue is not
  /// drained while the test is awaiting, so the read hangs rather than failing.
  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      await fixture().writeTo(temp);
      vm = ReaderViewModel(
        tracked(),
        preferences,
      );
      await vm.open('NUM', osisCode: 'John', chapter: 1);
    });
  }

  Widget harness() => MaterialApp(
        theme: buildLogosTheme(splashFactory: InkRipple.splashFactory),
        home: Scaffold(body: BibleReaderView(viewModel: vm)),
      );

  /// The chapter's span tree.
  ///
  /// Found by key rather than by position. The reader draws several rich texts — the toolbar
  /// readout, the chapter header, the book list — and picking "the last one" reads whichever
  /// the tree happened to order last, which is how an earlier version of this file asserted
  /// against the book list and found no scripture in it.
  ///
  /// The key is on the `Text` widget; the `RichText` below it is what lays the spans out.
  InlineSpan chapterSpan(WidgetTester tester) {
    final text = tester.widget<Text>(find.byKey(const ValueKey('chapter-rich-text')));
    final span = text.textSpan;
    expect(span, isNotNull, reason: 'the chapter must be rich text, not a plain string');
    return span!;
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  /// The chapter's spans, as plain text.
  Future<String> chapterText(WidgetTester tester) async {
    await pump(tester);
    return chapterSpan(tester).toPlainText();
  }

  /// The runs the chapter is actually drawn in.
  Future<List<({String text, TextStyle? style})>> chapterRuns(
    WidgetTester tester,
  ) async {
    await pump(tester);
    final runs = <({String text, TextStyle? style})>[];
    chapterSpan(tester).visitChildren((span) {
      if (span is TextSpan) {
        runs.add((text: span.text ?? '', style: span.style));
      }
      return true;
    });
    return runs;
  }

  group('superscript', () {
    testWidgets('numbers each verse in a small raised style', (tester) async {
      await open(tester);
      preferences.setVerseNumbers(VerseNumberStyle.superscript);

      final runs = await chapterRuns(tester);
      final numbers = runs.where((r) => r.style?.fontSize == LogosTypeScale.verseNumberSize);

      // One number per verse, not one per chapter and not one per word.
      expect(numbers.map((r) => r.text.trim()), ['1', '2', '3']);
    });

    testWidgets('the number sits before its verse text', (tester) async {
      await open(tester);

      final text = await chapterText(tester);
      expect(
        text.indexOf('1'),
        lessThan(text.indexOf('In the beginning was the Word')),
        reason: 'the number introduces its verse; after it, the reader reads it as a footnote',
      );
    });
  });

  group('visible', () {
    testWidgets('numbers are full size and on the baseline', (tester) async {
      await open(tester);
      preferences.setVerseNumbers(VerseNumberStyle.visible);

      final runs = await chapterRuns(tester);
      final scripture = LogosTypography.scriptureWith(
        preferences.settings,
        ReadingPalette.of(preferences.settings.colourScheme),
      );

      final numbers = runs
          .where((r) => ['1', '2', '3'].contains(r.text.trim()))
          .toList();

      expect(numbers, hasLength(3));
      for (final n in numbers) {
        expect(n.style?.fontSize, scripture.fontSize,
            reason: 'a visible number is set like the text, not raised above it');
      }
    });

    testWidgets('a visible number is the link colour', (tester) async {
      await open(tester);
      preferences.setVerseNumbers(VerseNumberStyle.visible);

      final runs = await chapterRuns(tester);
      final numbers =
          runs.where((r) => ['1', '2', '3'].contains(r.text.trim())).toList();

      for (final n in numbers) {
        expect(n.style?.color, LogosColors.link);
      }
    });
  });

  group('hidden', () {
    testWidgets('no number is drawn at all', (tester) async {
      await open(tester);
      preferences.setVerseNumbers(VerseNumberStyle.hidden);

      final text = await chapterText(tester);

      // The verses run together, so no standalone number precedes any of them.
      expect(text.contains(' 1 '), isFalse,
          reason: 'the chapter still holds verse 1; the number simply is not drawn');
      expect(text.contains('In the beginning was the Word'), isTrue,
          reason: 'hiding the numbers must not hide the text');
    });

    testWidgets('every verse is still present in full', (tester) async {
      await open(tester);
      preferences.setVerseNumbers(VerseNumberStyle.hidden);

      final text = await chapterText(tester);
      expect(text, contains('In the beginning was the Word'));
      expect(text, contains('He was in the beginning with God'));
      expect(text, contains('All things were made through him'));
    });
  });

  group('switching style', () {
    testWidgets('re-renders without reloading the text', (tester) async {
      // The requirement is explicit: changing the style must not reload. The chapter object
      // is replaced on every load, so identity is the test — a reload would give a new one.
      await open(tester);
      final before = vm.state.chapter;

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      preferences.setVerseNumbers(VerseNumberStyle.hidden);
      await tester.pumpAndSettle();
      expect(identical(vm.state.chapter, before), isTrue);

      preferences.setVerseNumbers(VerseNumberStyle.visible);
      await tester.pumpAndSettle();
      expect(identical(vm.state.chapter, before), isTrue,
          reason: 'two style changes must still not have touched the loaded chapter');
    });

    testWidgets('the reader keeps its position when the style changes', (tester) async {
      await open(tester);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      preferences.setVerseNumbers(VerseNumberStyle.hidden);
      await tester.pumpAndSettle();

      expect(vm.state.osisCode, 'John');
      expect(vm.state.chapterNumber, 1);
    });
  });

  group('from the format panel', () {
    testWidgets('choosing a style re-renders the chapter', (tester) async {
      await open(tester);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // Held so the assertion below is about the *loaded* chapter, not a fresh one. Every
      // load replaces the object, so identity is what "did not reload" means here.
      final loaded = vm.state.chapter;

      // Deliberately not awaited: the returned future completes when the dialog is dismissed,
      // so awaiting it here would wait for the very interaction the test is about to perform.
      // Unawaited rather than ignored, so the analyzer still sees it as handled.
      unawaited(
        ReaderFormatPanel.show(
          tester.element(find.byType(BibleReaderView)),
          preferences,
        ),
      );
      await tester.pumpAndSettle();

      // The panel scrolls: `Oculto` sits below the fold at the default test surface, and a
      // tap that misses because the widget is off screen is a silent no-op, not a failure.
      await tester.ensureVisible(find.text(VerseNumberStyle.hidden.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(VerseNumberStyle.hidden.label));
      await tester.pumpAndSettle();

      expect(preferences.settings.verseNumbers, VerseNumberStyle.hidden,
          reason: 'choosing a style in the panel must change the shared setting');

      // The chapter behind the dialog re-renders with it, which is what "applied without
      // reloading the text" means in practice: no load, a re-render.
      expect(identical(vm.state.chapter, loaded), isTrue,
          reason: 'the panel changes how the text is drawn, not what is loaded');
      expect(vm.state.chapter!.verses, hasLength(3));

      // Scrolled into view first: the close control is in the panel's header, and choosing a
      // style near the bottom scrolls it out of the viewport. A tap on an off-screen widget
      // is a silent no-op rather than a failure, which would have made this assert nothing.
      await tester.ensureVisible(find.byTooltip('Cerrar el formato'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar el formato'));
      await tester.pumpAndSettle();

      expect(find.byType(ReaderFormatPanel), findsNothing,
          reason: 'closing the panel returns to the reader');
      expect(find.textContaining('In the beginning was the Word'), findsOneWidget,
          reason: 'and the chapter is still readable behind it');
    });
  });
}
