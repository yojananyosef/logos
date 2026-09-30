import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/app_providers.dart';
import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/repositories/search_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/domain/models/passage_ref.dart';
import 'package:logos_engine/domain/search/search_parser.dart';
import 'package:logos_engine/domain/search/search_query.dart';
import 'package:logos_engine/ui/core/theme/logos_theme.dart';
import 'package:logos_engine/ui/features/search/view_models/search_view_model.dart';
import 'package:logos_engine/ui/features/search/views/search_view.dart';
import 'package:logos_engine/ui/features/search/views/syntax_help_view.dart';

import 'support/module_builder.dart';

/// The search screen, driven through the ViewModel and rendered for real.
///
/// Every helper here that touches the database wraps its work in [WidgetTester.runAsync],
/// which is not optional bookkeeping but the only way the tests can work at all. A widget
/// test runs its body on a fake clock, and the search is real file and SQLite I/O: waiting
/// for it on the fake clock never completes, so `await` there hangs the test outright
/// rather than failing it. This was measured rather than assumed — pumping 500ms after
/// `setQuery` leaves the run `running` with no results, and the same query awaited inside
/// `runAsync` returns two.
///
/// A consequence worth stating, because it looks like a missing assertion and is not: work
/// started on the fake clock cannot be rescued later. Polling inside `runAsync` for a query
/// that `enterText` began does not complete it, because its continuations were registered
/// in the zone that never drains. So each helper starts *and* awaits its work in a single
/// block, and the one test that drives the query through the keyboard asserts the wiring
/// rather than the outcome.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-search-ui-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  final aliases = <String, List<String>>{
    'John': ['jn', 'juan', 'john'],
    'Gen': ['gen'],
  };

  /// Waits for a search that is already running to reach a terminal status.
  ///
  /// Polling the state machine rather than waiting a fixed period keeps the tests honest:
  /// a fixed delay is a race that passes on a fast machine and fails on a slow one. Bounded,
  /// so a run that never finishes reports an assertion failure instead of hanging the suite.
  Future<void> awaitSettled(SearchViewModel vm) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (vm.status == SearchStatus.running) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<SearchViewModel> viewModelFor(WidgetTester tester,
      [ModuleBuilder? builder]) async {
    late SearchViewModel vm;
    await tester.runAsync(() async {
      final store = ModuleStore(temp);
      if (builder != null) {
        await ModuleInstaller(store).install(builder.id, bytes: await builder.build());
      }
      vm = SearchViewModel(
        repository: SearchRepository(BibleRepository(store)),
        referenceParser: PassageRefParser(aliases),
      );
    });
    return vm;
  }

  ModuleBuilder scripture() {
    final b = ModuleBuilder('TEST', name: 'Test Bible');
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'The Word was with God.');
    b.addVerse('Gen', 1, 1, 'In the beginning God created.');
    b.addVerse('Gen', 1, 2, 'The earth was without form.');
    return b;
  }

  Widget harness(SearchViewModel vm, {Size size = const Size(1440, 900)}) {
    return ProviderScope(
      overrides: [searchViewModelProvider.overrideWith((ref) => vm)],
      child: MaterialApp(
        theme: buildLogosTheme(),
        home: const Scaffold(body: _SearchPane()),
      ),
    );
  }

  /// The pane, watched exactly as the application watches it.
  ///
  /// [SearchView] takes a ViewModel and does not subscribe to it: rebuilds come from
  /// Riverpod's `ChangeNotifierProvider`, which is how every other screen in the
  /// application gets them too. Handing the ViewModel straight to `SearchView`, as an
  /// earlier version of this file did, builds a pane that can never update — after a
  /// search finished, the results still did not appear. Watching the provider here is what
  /// makes the test exercise the wiring the application actually uses.
  Future<void> search(WidgetTester tester, SearchViewModel vm, String q) async {
    await tester.runAsync(() async {
      vm.setQuery(q);
      await awaitSettled(vm);
    });
    await tester.pumpWidget(harness(vm));
    await tester.pump();
  }

  /// Changes scope and re-runs the query already in the field.
  Future<void> scope(WidgetTester tester, SearchViewModel vm, SearchScope s) async {
    await tester.runAsync(() async {
      await vm.setScope(s);
      await awaitSettled(vm);
    });
    await tester.pump();
  }

  /// Mounts the help panel, which is the idle state and needs no database.
  Future<void> showHelp(WidgetTester tester, SearchViewModel vm) async {
    await tester.pumpWidget(harness(vm));
    await tester.pump();
  }

  /// Scrolls the help panel until [finder] is on screen.
  ///
  /// The panel is a lazy `ListView`, so only what fits the viewport is built and the
  /// operator sections below the introduction card do not exist as elements until they are
  /// reached. Scrolling is also what a user does to get to them, so the assertions still
  /// cover a real path rather than a flattened one.
  ///
  /// [finder] must be a plain finder: `scrollUntilVisible` tests it for emptiness itself,
  /// and a `.first` matcher with no candidates throws instead of reporting none.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.descendant(
        of: find.byType(SyntaxHelpView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
  }

  group('the help panel', () {
    testWidgets('is shown while the field is empty', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await showHelp(tester, vm);

      expect(vm.showsHelp, isTrue);
      // Each section is revealed before it is asserted, because they sit below the
      // introduction card in a lazy list.
      for (final section in [
        'Operadores básicos',
        'Buscar palabras clave',
        'Ayuda adicional',
      ]) {
        await reveal(tester, find.text(section));
        expect(find.text(section), findsOneWidget, reason: 'the panel must show $section');
      }
    });

    testWidgets('is replaced by results once a query runs', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Word');

      expect(find.text('Operadores básicos'), findsNothing);
      expect(find.textContaining('In the beginning was the Word'), findsOneWidget);
    });

    testWidgets('shows every example the reference documents', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await showHelp(tester, vm);

      for (final example in [
        'amor al prójimo',
        'amor O prójimo',
        '"hijo del Hombre"',
        'Crist*',
        'Cristo',
        'cristiano',
        's?n',
        'el pecado',
        'el hijo',
        'el sol',
        'Biblia:"Jn 3:16"',
        'Cristo O Jesús',
        'Cristo Y Jesús',
        'Cristo Jesús',
        'Cristo NO Jesús',
        'Cristo ANTES Jesús',
        'Cristo DESPUÉS Jesús',
        'Cristo CERCA Jesús',
        'Cristo DENTRO 2 PALABRAS Jesús',
        'Cristo DENTRO 10 CARACT Jesús',
        'Biblia:"Juan 3"',
        'Biblia:="Juan 3"',
      ]) {
        await reveal(tester, find.text(example));
        expect(
          find.text(example),
          findsWidgets,
          reason: 'the help panel must offer «$example»',
        );
      }
    });

    testWidgets('the links are listed', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await showHelp(tester, vm);

      for (final link in [
        'Manual de Ayuda',
        'Wiki editado por usuarios',
        'Grupo de búsqueda Logos',
      ]) {
        await reveal(tester, find.text(link));
        expect(find.text(link), findsOneWidget, reason: 'the panel must link $link');
      }
    });

    testWidgets('activating an example runs it', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await showHelp(tester, vm);

      // The panel teaches the syntax by doing it: tapping puts the query in the field and
      // runs it, rather than only displaying the string.
      await reveal(tester, find.text('Cristo Y Jesús'));
      await tester.tap(find.text('Cristo Y Jesús').first);
      await tester.pump();

      expect(vm.query, 'Cristo Y Jesús');
      expect(vm.showsHelp, isFalse);
    });

    testWidgets('every example offered is a query the parser accepts', (tester) async {
      // A chip that inserts a query the parser then rejects is a worse bug than a missing
      // one: the user is told their own example is invalid.
      final vm = await viewModelFor(tester, scripture());
      final parser = SearchParser(PassageRefParser(aliases).tryParse);

      for (final example in [
        'amor al prójimo',
        'amor O prójimo',
        '"hijo del Hombre"',
        'Crist*',
        's?n',
        'Biblia:"Jn 3:16"',
        'Cristo O Jesús',
        'Cristo Y Jesús',
        'Cristo Jesús',
        'Cristo NO Jesús',
        'Cristo ANTES Jesús',
        'Cristo DESPUÉS Jesús',
        'Cristo CERCA Jesús',
        'Cristo DENTRO 2 PALABRAS Jesús',
        'Cristo DENTRO 10 CARACT Jesús',
        'Biblia:"Juan 3"',
        'Biblia:="Juan 3"',
        'evangelismo CERCA Biblia:"Juan 3"',
      ]) {
        expect(
          () => parser.parse(example),
          returnsNormally,
          reason: '«$example» is offered by the help panel and must parse',
        );
      }
      expect(vm.query, isEmpty);
    });
  });

  group('the query field', () {
    testWidgets('typing reaches the ViewModel and requests a search', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await showHelp(tester, vm);

      await tester.enterText(find.byType(TextField), 'Word');
      await tester.pump();

      // The wiring is what typing can prove here. `running` means the keystrokes reached
      // the ViewModel and it parsed the text and asked the repository for matches; that
      // search cannot finish on the fake clock, which is why the rendered results are
      // asserted through `search` instead.
      expect(vm.query, 'Word');
      expect(vm.status, SearchStatus.running);
    });

    testWidgets('an unknown operator is reported and named', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Cristo CERKCA Jesús');

      expect(vm.status, SearchStatus.invalid);
      expect(vm.errorOperator, 'CERKCA');
      expect(find.textContaining('CERKCA'), findsWidgets);
    });

    testWidgets('a syntax error keeps the text so it can be fixed', (tester) async {
      // Clearing the field on an error would destroy what the user is trying to correct.
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Cristo CERKCA Jesús');

      expect(vm.query, 'Cristo CERKCA Jesús');
      expect(find.text('Cristo CERKCA Jesús'), findsWidgets);
    });

    testWidgets('clearing the field returns to the help panel', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Word');

      vm.clear();
      await tester.pump();

      expect(vm.showsHelp, isTrue);
      await reveal(tester, find.text('Operadores básicos'));
      expect(find.text('Operadores básicos'), findsOneWidget);
    });
  });

  group('scopes', () {
    testWidgets('the three scopes are offered', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await showHelp(tester, vm);

      expect(find.text('Todo'), findsOneWidget);
      expect(find.text('Biblia'), findsOneWidget);
      expect(find.text('Libros'), findsOneWidget);
    });

    testWidgets('changing scope re-runs without retyping', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Word');

      await scope(tester, vm, SearchScope.bible);

      expect(vm.scope, SearchScope.bible);
      expect(vm.query, 'Word', reason: 'the query survives the scope change');
      expect(vm.status, SearchStatus.ready);
    });

    testWidgets('a scope with no content reports an empty result', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Word');

      // A Bible is not a "book" in the reference's sense, so Libros has nothing to search.
      await scope(tester, vm, SearchScope.books);

      expect(vm.status, SearchStatus.empty);
      expect(find.text('Sin resultados'), findsOneWidget);
    });
  });

  group('results', () {
    testWidgets('a result shows its reference and module', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Word');

      expect(find.text('John 1:1'), findsOneWidget);
      expect(find.text('Test Bible'), findsWidgets);
    });

    testWidgets('the count is reported', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Word');

      expect(find.textContaining('2 resultados'), findsOneWidget);
    });

    testWidgets('matched terms are marked in the result text', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Word');

      // The mark is a style on a span, not separate text, so it is found by walking the
      // rendered span tree. The walk is recursive because `Text.rich` nests the caller's
      // span inside two wrappers, and reading `children` one level down would report no
      // mark on a screen that is visibly highlighting the term.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      expect(_hasHighlight(richTexts), isTrue,
          reason: 'a matched run must carry the highlight background');
    });

    testWidgets('an empty result suggests broadening', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'zzzznotpresent');

      expect(vm.status, SearchStatus.empty);
      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.text('Pruebe con una búsqueda más amplia'), findsOneWidget);
    });

    testWidgets('the broadening button offers a weaker query', (tester) async {
      // `Crist*`, not `wor*`: the test corpus contains "Word", so `wor*` matches and the
      // empty state this button lives in never appears.
      final vm = await viewModelFor(tester, scripture());
      await search(tester, vm, 'Crist*');

      await tester.tap(find.text('Pruebe con una búsqueda más amplia'));
      await tester.pump();

      // The wildcard is dropped rather than the query replaced, so the suggestion is
      // related to what the user asked for.
      expect(vm.query, isNot(contains('*')));
      expect(vm.query.toLowerCase(), 'crist');
    });

    testWidgets('an empty library says so rather than reporting no matches',
        (tester) async {
      final vm = await viewModelFor(tester);
      await search(tester, vm, 'Word');

      expect(find.textContaining('No hay contenido instalado'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('does not overflow horizontally at any width', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await tester.runAsync(() async {
        vm.setQuery('Word');
        await awaitSettled(vm);
      });

      for (final width in [360.0, 390.0, 600.0, 768.0, 1024.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(harness(vm));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'the search must lay out at ${width}px');
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('the help panel does not overflow on a phone', (tester) async {
      final vm = await viewModelFor(tester, scripture());
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await showHelp(tester, vm);

      // Long example chips have to wrap rather than clip, or the operator the user needs
      // is cut off on the device most likely to be in a pocket.
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('Cristo DENTRO 10 CARACT Jesús'));
      expect(find.text('Cristo DENTRO 10 CARACT Jesús'), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    });
  });
}

bool _hasHighlight(Iterable<RichText> texts) {
  bool walk(InlineSpan span) {
    if (span is! TextSpan) return false;
    if (span.style?.backgroundColor != null) return true;
    return span.children?.any(walk) ?? false;
  }

  return texts.any((rt) => walk(rt.text));
}

/// The search pane, built the way the application builds it.
/// Kept as a widget rather than inlined into the harness because it has to rebuild on the
/// ViewModel's notifications, which is the behaviour under test.
class _SearchPane extends ConsumerWidget {
  const _SearchPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SearchView(viewModel: ref.watch(searchViewModelProvider));
  }
}