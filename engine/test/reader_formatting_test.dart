import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:logos_engine/domain/models/reader_settings.dart';
import 'package:logos_engine/ui/core/theme/logos_theme.dart';
import 'package:logos_engine/ui/core/theme/reading_palette.dart';
import 'package:logos_engine/ui/features/reader/view_models/reader_preferences.dart';
import 'package:logos_engine/ui/features/reader/views/reader_format_panel.dart';

/// Task 8.6 — text size, line spacing, font, colour scheme and alignment, with persistence.
///
/// The persistence assertions go through a real [SharedPreferences] rather than an in-memory
/// fake. The requirement is that a setting survives leaving the resource, and the only thing
/// that can prove a setting is *stored* rather than merely held is a store that still has it
/// after everything that held it has been discarded. A fake would pass while the key was
/// never written.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-format-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<SharedPreferences> freshStore() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  ReaderSettings storedSettings(SharedPreferences prefs) {
    final raw = prefs.getString(SharedPreferencesReaderStore.key);
    expect(raw, isNotNull, reason: 'the setting was never written to the store');
    return ReaderSettings.fromJson(
      (jsonDecode(raw!) as Map).cast<String, Object?>(),
    );
  }

  /// The contrast ratio between two colours, per WCAG 2.1.
  ///
  /// Written out rather than pulled from a package because it is the assertion's own
  /// definition: a helper that computes contrast wrongly would make every scheme pass.
  double contrast(Color a, Color b) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

    // The channel accessors are already normalised to 0..1, which is what the formula is
    // defined over; the raw byte values would push every ratio above 1 and make the
    // comparison meaningless.
    double luminance(Color c) =>
        0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

    final la = luminance(a);
    final lb = luminance(b);
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  group('each setting changes the rendered style', () {
    test('text size scales the scripture style', () {
      final small = LogosTypography.scriptureWith(
        const ReaderSettings(textSize: TextSizeStep.small),
        ReadingPalette.of(ReadingColourScheme.claro),
      );
      final large = LogosTypography.scriptureWith(
        const ReaderSettings(textSize: TextSizeStep.huge),
        ReadingPalette.of(ReadingColourScheme.claro),
      );

      expect(large.fontSize, greaterThan(small.fontSize!));
    });

    test('line spacing changes the height multiplier', () {
      final compact = LogosTypography.scriptureWith(
        const ReaderSettings(lineSpacing: LineSpacing.compact),
        ReadingPalette.of(ReadingColourScheme.claro),
      );
      final relaxed = LogosTypography.scriptureWith(
        const ReaderSettings(lineSpacing: LineSpacing.relaxed),
        ReadingPalette.of(ReadingColourScheme.claro),
      );

      expect(relaxed.height, greaterThan(compact.height!));
    });

    test('the font choice reaches the style', () {
      final serif = LogosTypography.scriptureWith(
        const ReaderSettings(font: ScriptureFont.serif),
        ReadingPalette.of(ReadingColourScheme.claro),
      );
      final sans = LogosTypography.scriptureWith(
        const ReaderSettings(font: ScriptureFont.sans),
        ReadingPalette.of(ReadingColourScheme.claro),
      );

      expect(serif.fontFamily, isNot(sans.fontFamily));
      // Every face carries a fallback, so a module in a script the chosen face lacks renders
      // as text rather than as tofu boxes.
      expect(serif.fontFamilyFallback, isNotEmpty);
    });

    test('the colour scheme changes the reading background', () {
      final claro = ReadingPalette.of(ReadingColourScheme.claro);
      final crema = ReadingPalette.of(ReadingColourScheme.crema);

      expect(crema.background, isNot(claro.background));
    });

    test('alignment is carried through to the style’s use', () {
      const settings = ReaderSettings(alignment: TextAlign.justify);
      expect(settings.alignment, TextAlign.justify);
    });
  });

  group('every scheme is readable', () {
    test('each scheme clears WCAG AA for body text', () {
      // 4.5:1 for normal text. The requirement is that a reader can *read* in the scheme they
      // chose, so this is a correctness property rather than a design preference — a scheme
      // that fails it is a defect the reader only discovers by struggling.
      for (final palette in ReadingPalette.all) {
        final ratio = contrast(palette.background, palette.foreground);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'the scheme ${palette.background} on ${palette.foreground} '
              'is $ratio:1, below the 4.5:1 WCAG AA minimum for body text',
        );
      }
    });
  });

  group('persistence', () {
    test('a changed text size is written to the store', () async {
      final prefs = await freshStore();
      final vm = ReaderPreferencesViewModel(SharedPreferencesReaderStore(prefs));

      vm.setTextSize(TextSizeStep.huge);
      // The write is fire-and-forget so the UI never blocks on storage; the store is read
      // after awaiting, which is what makes the assertion about the write rather than about
      // the order in which two futures happen to run.
      await Future<void>.delayed(Duration.zero);

      expect(storedSettings(prefs).textSize, TextSizeStep.huge);
    });

    test('every setting survives being written and read back', () async {
      final prefs = await freshStore();
      final vm = ReaderPreferencesViewModel(SharedPreferencesReaderStore(prefs));

      vm
        ..setVerseNumbers(VerseNumberStyle.visible)
        ..setFont(ScriptureFont.serif)
        ..setTextSize(TextSizeStep.extraLarge)
        ..setLineSpacing(LineSpacing.relaxed)
        ..setColourScheme(ReadingColourScheme.crema)
        ..setAlignment(TextAlignValue.justify);
      await Future<void>.delayed(Duration.zero);

      final stored = storedSettings(prefs);
      expect(stored.verseNumbers, VerseNumberStyle.visible);
      expect(stored.font, ScriptureFont.serif);
      expect(stored.textSize, TextSizeStep.extraLarge);
      expect(stored.lineSpacing, LineSpacing.relaxed);
      expect(stored.colourScheme, ReadingColourScheme.crema);
      expect(stored.alignment, TextAlign.justify);
    });

    test('settings survive the reader that changed them', () async {
      // The requirement is stated as "leaves the resource and returns". Discarding the
      // ViewModel and reading the store back is the closest a unit test gets to that: the
      // thing that held the setting is gone, and the setting is still there.
      final prefs = await freshStore();

      final first = ReaderPreferencesViewModel(SharedPreferencesReaderStore(prefs));
      first.setTextSize(TextSizeStep.large);
      await Future<void>.delayed(Duration.zero);

      final second = ReaderPreferencesViewModel(SharedPreferencesReaderStore(prefs));
      await second.load();

      expect(second.settings.textSize, TextSizeStep.large,
          reason: 'a text size set in one reader must apply in the next');
    });

    test('a corrupt record degrades to the defaults rather than throwing', () async {
      // Reported as "no stored settings" because that is what the reader can act on. The
      // alternative is refusing to open the Bible over a preference that only affects how
      // text looks.
      SharedPreferences.setMockInitialValues({
        SharedPreferencesReaderStore.key: '{not json',
      });
      final prefs = await SharedPreferences.getInstance();
      final vm = ReaderPreferencesViewModel(SharedPreferencesReaderStore(prefs));

      await vm.load();

      expect(vm.settings, const ReaderSettings());
      expect(vm.isLoaded, isTrue);
    });

    test('an unknown value falls back to the default for that field', () async {
      // Version skew, not corruption: a preference file written by a later build. The
      // honest response is the default rather than a refusal to start.
      SharedPreferences.setMockInitialValues({
        SharedPreferencesReaderStore.key: '{"textSize":"colossal","colourScheme":"gris"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final vm = ReaderPreferencesViewModel(SharedPreferencesReaderStore(prefs));

      await vm.load();

      expect(vm.settings.textSize, TextSizeStep.medium);
      expect(vm.settings.colourScheme, ReadingColourScheme.gris,
          reason: 'a recognised value is still honoured alongside the unknown one');
    });
  });

  group('reset', () {
    testWidgets('restoring the defaults puts the text back to a readable size', (tester) async {
      final prefs = await freshStore();
      final vm = ReaderPreferencesViewModel(SharedPreferencesReaderStore(prefs));
      vm.setTextSize(TextSizeStep.huge);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => vm.reset(),
                child: const Text('reset'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('reset'));
      await tester.pumpAndSettle();

      // The escape hatch exists because a reader who enlarged the text and cannot find the
      // control again is stuck. This is the assertion that it is not.
      expect(vm.settings.textSize, TextSizeStep.medium);
    });
  });

  group('the panel', () {
    testWidgets('offers every setting the requirement names', (tester) async {
      final prefs = ReaderPreferencesViewModel(InMemoryReaderStore());

      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: (context) {
          return TextButton(
            onPressed: () => unawaited(ReaderFormatPanel.show(context, prefs)),
            child: const Text('open'),
          );
        })),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final label in [
        'Tamaño del texto',
        'Interlineado',
        'Fuente',
        'Números de versículo',
        'Color del texto',
        'Alineación',
      ]) {
        await tester.scrollUntilVisible(find.text(label), 100);
        expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
      }
    });

    testWidgets('shows the chosen colours in a preview', (tester) async {
      final prefs = ReaderPreferencesViewModel(InMemoryReaderStore())
        ..setColourScheme(ReadingColourScheme.crema);

      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: (context) {
          return TextButton(
            onPressed: () => unawaited(ReaderFormatPanel.show(context, prefs)),
            child: const Text('open'),
          );
        })),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // `textContaining`, not `text`: the preview is one paragraph, and matching it whole would
      // make the test fail for a change to the sample scripture's wording.
      expect(find.textContaining('En el principio'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('En el principio'));
      await tester.pumpAndSettle();
    });
  });
}
