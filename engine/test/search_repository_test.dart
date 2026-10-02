import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/repositories/search_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/domain/models/passage_ref.dart';
import 'package:logos_engine/domain/search/search_parser.dart';
import 'package:logos_engine/domain/search/search_query.dart';

import 'support/module_builder.dart';

/// End-to-end search, over modules this test builds.
///
/// The fixture carries text chosen so every operator has an unambiguous answer, including
/// the two that FTS5 cannot express. That is the point: a test that only exercised what the
/// index already does would pass while `CERCA` was broken.
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

  /// A search repository over a tracked [BibleRepository].
  ///
  /// `SearchRepository` has no state of its own; the databases live in the
  /// repository it wraps, so tracking the inner one is enough.
  SearchRepository trackedSearch() {
    final bible = tracked();
    return SearchRepository(bible);
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-search-');
  });

  tearDown(() {
    for (final r in repos.reversed) {
      r.dispose();
    }
    repos.clear();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  final aliases = <String, List<String>>{
    'John': ['jn', 'juan', 'john'],
    'Gen': ['gen'],
  };

  Future<SearchRepository> repositoryFor(List<ModuleBuilder> modules) async {
    final store = ModuleStore(temp);
    final installer = ModuleInstaller(store);
    for (final m in modules) {
      await installer.install(
        m.id,
        bytes: await m.build(),
      );
    }
    return trackedSearch();
  }

  /// A module whose text makes each operator's answer checkable by eye.
  ModuleBuilder scripture({String id = 'TEST', String type = 'bible'}) {
    final b = ModuleBuilder(id, name: 'Test $id', type: type);
    // Adjacent: a proximity of 0.
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'The Word was with God.');
    // "was" sits one word from "beginning".
    b.addVerse('John', 1, 3, 'Alpha beginning was Beta Gamma.');
    // Far apart: twelve words between the two terms.
    b.addVerse('John', 1, 4,
        'Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu Word.');
    // One only.
    b.addVerse('John', 2, 1, 'Nothing of the sort appears in this line.');
    b.addVerse('Gen', 1, 1, 'In the beginning God created.');
    b.addVerse('Gen', 1, 2, 'The earth was formless.');
    b.addVerse('Gen', 2, 1, 'Cristo came and cristo also.');
    return b;
  }

  Future<SearchRun> search(
    SearchRepository repo,
    String query, {
    SearchScope scope = SearchScope.all,
    int limit = 50,
  }) {
    final parser = SearchParser(PassageRefParser(aliases).tryParse);
    return repo.search(parser.parse(query), scope: scope, limit: limit);
  }

  /// The labels of a run's results, for assertions about which rows came back.
  List<String> labels(SearchRun run) => [for (final r in run.results) r.label];

  group('a single term', () {
    test('finds the rows containing it', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Word');

      expect(labels(run), containsAll(['John 1:1', 'John 1:2', 'John 1:4']));
      expect(labels(run), isNot(contains('John 2:1')));
    });

    test('is case and diacritic insensitive', () async {
      final repo = await repositoryFor([scripture()]);
      expect((await search(repo, 'word')).results, hasLength(3));
      expect((await search(repo, 'WORD')).results, hasLength(3));
    });

    test('does not match a substring of a longer word', () async {
      final repo = await repositoryFor([scripture()]);
      expect((await search(repo, 'wor')).results, isEmpty);
    });
  });

  group('Y and O', () {
    test('Y requires both terms', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Word Y beginning');

      // Only John 1:1 has both. 1:3 has "beginning" without "Word" and 1:4 the reverse, so
      // a search that behaved as a disjunction would return all three.
      expect(labels(run), ['John 1:1']);
    });

    test('O accepts either term', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'epsilon O nonexistentterm');

      expect(labels(run), ['John 1:4']);
    });
  });

  group('NO', () {
    test('excludes the second term', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Word NO beginning');

      // 1:2 and 1:4 have "Word" and no "beginning"; 1:1 and 1:3 have both.
      expect(labels(run), containsAll(['John 1:2', 'John 1:4']));
      expect(labels(run), isNot(contains('John 1:1')));
    });
  });

  group('phrases', () {
    test('an exact phrase matches', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, '"the Word was"');

      expect(labels(run), ['John 1:2']);
    });

    test('a non-exact match is excluded', () async {
      final repo = await repositoryFor([scripture()]);
      // "beginning" and "Word" both occur in John 1:1, and a conjunction would match it.
      // The order is the reverse, so the phrase must not.
      expect((await search(repo, '"Word beginning"')).results, isEmpty);
      expect(labels(await search(repo, '"beginning was"')),
          containsAll(['John 1:1', 'John 1:3']));
    });
  });

  group('wildcards', () {
    test('a prefix wildcard matches longer words', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'cris*');

      expect(labels(run), ['Gen 2:1']);
    });

    test('a question mark matches exactly one character', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'cr?sto');

      // Gen 2:1 has "Cristo" and "cristo".
      expect(labels(run), ['Gen 2:1']);
    });

    test('a question mark does not match a different length', () async {
      final repo = await repositoryFor([scripture()]);
      // Gen 2:1 holds "Cristo" and "cristo", six letters. A pattern of a different length
      // cannot match them, and a `?` treated as "any run" would have matched both.
      expect((await search(repo, 'cr?st')).results, isEmpty);
      expect((await search(repo, 'cri?to')).results, isNotEmpty);
    });

    test('a star does not match mid-word', () async {
      final repo = await repositoryFor([scripture()]);
      // Gen 2:1 contains "cristo", where "ris" is not at the start of a word.
      expect((await search(repo, 'ris*')).results, isEmpty);
    });
  });

  group('proximity', () {
    test('CERCA finds terms within the distance', () async {
      final repo = await repositoryFor([scripture()]);
      // John 1:3 has "beginning was" adjacent, and John 1:1 ends "beginning was the Word",
      // so both qualify at distance 0.
      final run = await search(repo, 'beginning CERCA 0 was');
      expect(labels(run), containsAll(['John 1:1', 'John 1:3']));
    });

    test('CERCA excludes terms beyond the distance', () async {
      final repo = await repositoryFor([scripture()]);
      // John 1:4 puts twelve words between alpha and mu.
      expect((await search(repo, 'alpha CERCA 2 mu')).results, isEmpty);
      expect(labels(await search(repo, 'alpha CERCA 12 mu')), ['John 1:4']);
    });

    test('DENTRO n PALABRAS agrees with CERCA n', () async {
      final repo = await repositoryFor([scripture()]);
      for (final n in [0, 1, 5, 12]) {
        final a = await search(repo, 'alpha CERCA $n mu');
        final b = await search(repo, 'alpha DENTRO $n PALABRAS mu');
        expect(labels(a), labels(b), reason: 'at distance $n');
      }
    });

    test('DENTRO n CARACT measures characters', () async {
      final repo = await repositoryFor([scripture()]);
      // "Alpha beta" : the gap between "Alpha" and "beta" is one space.
      expect((await search(repo, 'Alpha DENTRO 1 CARACT beta')).results, isNotEmpty);
      expect((await search(repo, 'Alpha DENTRO 0 CARACT beta')).results, isEmpty);
    });

    test('proximity over a multi-word phrase counts every word of it', () async {
      final repo = await repositoryFor([scripture()]);
      // "The Word" is two words, and "with" is the next one, so one word separates them.
      final run = await search(repo, '"The Word" CERCA 1 with');
      expect(labels(run), ['John 1:2']);
    });
  });

  group('ordering', () {
    test('ANTES matches when the left term comes first', () async {
      final repo = await repositoryFor([scripture()]);
      // Both 1:1 and 1:3 read "beginning was".
      expect(labels(await search(repo, 'beginning ANTES was')),
          containsAll(['John 1:1', 'John 1:3']));
    });

    test('ANTES excludes the reverse order', () async {
      final repo = await repositoryFor([scripture()]);
      expect((await search(repo, 'was ANTES beginning')).results, isEmpty);
    });

    test('DESPUES matches when the left term comes second', () async {
      final repo = await repositoryFor([scripture()]);
      expect(labels(await search(repo, 'was DESPUES beginning')),
          containsAll(['John 1:1', 'John 1:3']));
    });
  });

  group('references', () {
    test('a verse reference returns that verse', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Biblia:"Jn 1:3"');
      expect(labels(run), ['John 1:3']);
    });

    test('a chapter reference returns the whole chapter', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Biblia:"Juan 1"');
      expect(labels(run), containsAll(['John 1:1', 'John 1:2', 'John 1:3', 'John 1:4']));
    });

    test('a reference combined with a term filters it', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Word Y Biblia:"Juan 1"');
      expect(labels(run), containsAll(['John 1:1', 'John 1:2', 'John 1:4']));
    });

    test('an invalid reference is reported before any module is opened', () async {
      final parser = SearchParser(PassageRefParser(aliases).tryParse);
      expect(
        () => parser.parse('Biblia:"Zzz 1:1"'),
        throwsA(isA<SearchSyntaxException>()),
      );
    });
  });

  group('scopes', () {
    test('bible scope searches only scripture', () async {
      final repo = await repositoryFor([scripture(id: 'BIB', type: 'bible')]);
      final run = await search(repo, 'Word', scope: SearchScope.bible);
      expect(run.results, isNotEmpty);
      expect(run.moduleCount, 1);
    });

    test('books scope excludes scripture', () async {
      final repo = await repositoryFor([scripture(id: 'BIB', type: 'bible')]);
      final run = await search(repo, 'Word', scope: SearchScope.books);
      expect(run.results, isEmpty,
          reason: 'a Bible is not a book in the reference\'s sense');
    });

    test('a non-scripture module is searchable in books scope', () async {
      final repo = await repositoryFor([scripture(id: 'COMM', type: 'commentary')]);
      final run = await search(repo, 'Word', scope: SearchScope.books);
      expect(run.moduleCount, 1);
    });

    test('all scope searches every installed module', () async {
      final repo = await repositoryFor([
        scripture(id: 'BIB', type: 'bible'),
        scripture(id: 'COMM', type: 'commentary'),
      ]);
      expect((await search(repo, 'Word', scope: SearchScope.all)).moduleCount, 2);
    });
  });

  group('presentation', () {
    test('matched terms are highlighted', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Word');
      final first = run.results.firstWhere((r) => r.label == 'John 1:2');
      final matched = [
        for (final s in first.segments)
          if (s.matched) s.text
      ];
      expect(matched, ['Word']);
    });

    test('a run of text is split into matched and unmatched segments', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Word');
      final first = run.results.firstWhere((r) => r.label == 'John 1:2');
      expect(
        [for (final s in first.segments) '${s.matched}:${s.text}'],
        ['false:The ', 'true:Word', 'false: was with God.'],
      );
    });

    test('highlighting works across diacritics', () async {
      // Keyed on `John` and named `Juan`: a Spanish module keeps the OSIS code as its
      // identity and the translation's own word as its display name, which is what
      // `tool/build_module.dart` writes from `\toc2`.
      final b = ModuleBuilder('DIA',
          name: 'Diacritics', bookNames: {'John': 'Juan'});
      b.addVerse('John', 1, 1, 'En el principio estaba la Palabra.');
      final repo = await repositoryFor([b]);
      final run = await search(repo, 'palabra');
      final matched = [
        for (final s in run.results.first.segments)
          if (s.matched) s.text
      ];
      expect(matched, ['Palabra']);
    });

    test('the result count reports what was found before the limit', () async {
      final repo = await repositoryFor([scripture()]);
      final run = await search(repo, 'Word', limit: 1);
      expect(run.results, hasLength(1));
      expect(run.totalFound, greaterThan(1));
      expect(run.truncated, isTrue);
    });
  });

  group('no results', () {
    test('an empty library yields an empty run rather than an error', () async {
      final repo = await repositoryFor([]);
      final run = await search(repo, 'anything');
      expect(run.isEmpty, isTrue);
      expect(run.moduleCount, 0);
    });

    test('a term present nowhere yields an empty run', () async {
      final repo = await repositoryFor([scripture()]);
      expect((await search(repo, 'zzznotpresent')).isEmpty, isTrue);
    });

    test('an unreadable module does not fail the whole search', () async {
      // A file that is not a module at all, sitting where a module is expected.
      File('${temp.path}/BROKEN.amod').writeAsBytesSync(List<int>.filled(64, 0));
      final repo = trackedSearch();
      final run = await search(repo, 'Word');
      expect(run.isEmpty, isTrue, reason: 'no crash, no results');
    });
  });
}
