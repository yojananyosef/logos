import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/domain/models/passage_ref.dart';
import 'package:logos_engine/domain/search/logos_text.dart';
import 'package:logos_engine/domain/search/search_matcher.dart';
import 'package:logos_engine/domain/search/search_parser.dart';
import 'package:logos_engine/domain/search/search_query.dart';

/// The matcher decides what FTS5 cannot.
///
/// Every case here is one the index provably gets wrong or cannot express. The suite
/// exists because the tempting alternative — delegate proximity to FTS5's `NEAR` — silently
/// returns nothing on SQLite 3.53.4, and a search that accepts `CERCA 5` and returns
/// nothing is worse than one that never offered the operator.
void main() {
  final parser = SearchParser(
    const PassageRefParser({
      'John': ['jn', 'juan'],
      'Gen': ['gen']
    }).tryParse,
  );
  const matcher = SearchMatcher();

  bool ok(String query, String text, {PassageRef? ref}) =>
      matcher.matches(parser.parse(query), text, reference: ref);

  const john1v1 = 'In the beginning was the Word, and the Word was with God, '
      'and the Word was God.';
  const john316 = 'For God so loved the world, that he gave his only begotten Son, '
      'that whoever believes in him should not perish.';

  group('terms', () {
    test('a whole word matches', () {
      expect(ok('Word', john1v1), isTrue);
      expect(ok('Word', john316), isFalse);
    });

    test('matching ignores case and diacritics', () {
      // The index folds both, so the post-filter has to as well or it would discard rows
      // the index legitimately returned.
      expect(ok('word', john1v1), isTrue);
      expect(ok('WORD', john1v1), isTrue);
      expect(ok('palabra', 'La Palabra'), isTrue);
    });

    test('a term inside a longer word does not match', () {
      expect(ok('wor', john1v1), isFalse);
      expect(ok('or', john1v1), isFalse);
    });

    test('a word split by punctuation is matched whole', () {
      expect(ok('begging', 'For the remission of their sins'), isFalse);
      expect(ok('remission', 'For the remission of their sins'), isTrue);
    });
  });

  group('phrases', () {
    test('an exact phrase matches', () {
      expect(ok('"the Word"', john1v1), isTrue);
    });

    test('a non-exact match is excluded', () {
      // The words are all present but the order is wrong, so this must not match. A
      // conjunction of terms would match, which is exactly the difference between a
      // phrase and two words.
      expect(ok('"Word the"', john1v1), isFalse);
    });

    test('a phrase with words missing is excluded', () {
      expect(ok('"the Word with Christ"', john1v1), isFalse);
    });

    test('a phrase ignores case and diacritics', () {
      expect(ok('"LA PALABRA"', 'la palabra'), isTrue);
    });
  });

  group('O — either', () {
    test('matches when only the left term is present', () {
      expect(ok('Word O nonexistent', john1v1), isTrue);
    });

    test('matches when only the right term is present', () {
      expect(ok('nonexistent O Word', john1v1), isTrue);
    });

    test('does not match when neither is present', () {
      expect(ok('nonexistent O missing', john1v1), isFalse);
    });
  });

  group('Y — both', () {
    test('matches when both are present', () {
      expect(ok('Word Y God', john1v1), isTrue);
    });

    test('does not match when one is absent', () {
      expect(ok('Word Y nonexistent', john1v1), isFalse);
    });

    test('two adjacent words mean both', () {
      expect(ok('Word God', john1v1), isTrue);
      expect(ok('Word nonexistent', john1v1), isFalse);
    });
  });

  group('NO — excluding', () {
    test('matches the first and not the second', () {
      expect(ok('Word NO nonexistent', john1v1), isTrue);
    });

    test('does not match when both are present', () {
      expect(ok('Word NO God', john1v1), isFalse);
    });

    test('does not match when the first is absent', () {
      expect(ok('nonexistent NO God', john1v1), isFalse);
    });
  });

  group('ANTES and DESPUES — ordering', () {
    test('ANTES matches when the left term comes first', () {
      expect(ok('Word ANTES God', john1v1), isTrue);
    });

    test('ANTES does not match when the left term only comes second', () {
      // A text with one occurrence of each, so the answer is unambiguous.
      expect(ok('second ANTES first', 'the first and the second'), isFalse);
    });

    test('DESPUES matches when the left term comes second', () {
      expect(ok('God DESPUES Word', john1v1), isTrue);
    });

    test('DESPUES does not match when the left term only comes first', () {
      expect(ok('first DESPUES second', 'the first and the second'), isFalse);
    });

    test('the accented spelling behaves the same', () {
      expect(ok('God DESPUÉS Word', john1v1), isTrue);
    });

    test('any occurrence counts, not only the first', () {
      // "Word" appears three times and "God" twice in John 1:1, so there is a Word before
      // a God even though the text also has God before Word. Checking only the first
      // occurrence of each would get this backwards.
      expect(ok('Word ANTES God', john1v1), isTrue);
      expect(ok('God ANTES Word', john1v1), isTrue);
    });

    test('ordering is decided on the folded text', () {
      expect(ok('palabra ANTES dios', 'La palabra de Dios'), isTrue);
    });
  });

  group('CERCA — proximity', () {
    test('terms within the distance match', () {
      // "Word ... God" is four words apart in John 1:1.
      expect(ok('Word CERCA 5 God', john1v1), isTrue);
    });

    test('terms beyond the distance do not match', () {
      expect(ok('Word CERCA 0 God', john1v1), isFalse);
    });

    test('CERCA 0 means adjacent', () {
      expect(ok('Word CERCA 0 beginning', john1v1), isFalse);
      expect(ok('Word CERCA 1 beginning', john1v1), isFalse);
      expect(ok('Word CERCA 2 beginning', john1v1), isTrue,
          reason: '"was the" is two words between them');
    });

    test('a bare CERCA uses a default distance', () {
      expect(ok('Word CERCA God', john1v1), isTrue);
      expect(ok('Word CERCA nonexistent', john1v1), isFalse);
    });

    test('a negative distance is refused', () {
      expect(() => parser.parse('a CERCA -5 b'), throwsA(isA<SearchSyntaxException>()));
    });

    test('proximity works on the pair that FTS5 NEAR silently misses', () {
      // `Word NEAR beginning` returns 0 rows in FTS5 even for this adjacent pair, which
      // is why proximity is decided here instead of being delegated.
      expect(ok('Word CERCA 0 beginning', 'Word beginning'), isTrue);
    });
  });

  group('DENTRO n PALABRAS', () {
    test('a word distance is measured between the terms', () {
      // "a b c d" : a and d have "b c" — two words — between them.
      expect(ok('a DENTRO 2 PALABRAS d', 'a b c d'), isTrue);
      expect(ok('a DENTRO 1 PALABRAS d', 'a b c d'), isFalse);
      // b and c are adjacent.
      expect(ok('b DENTRO 0 PALABRAS c', 'a b c d'), isTrue);
    });

    test('it is the same as CERCA with that distance', () {
      const text = 'Word was with God';
      expect(ok('Word CERCA 2 God', text), ok('Word DENTRO 2 PALABRAS God', text));
      expect(ok('Word CERCA 1 God', text), ok('Word DENTRO 1 PALABRAS God', text));
    });

    test('a unit typo is reported rather than guessed', () {
      expect(
        () => parser.parse('a DENTRO 5 PÁGINAS b'),
        throwsA(isA<SearchSyntaxException>()),
      );
    });
  });

  group('DENTRO n CARACT', () {
    test('a character distance is measured between the terms', () {
      // "Word, and God": the characters between the two terms are ", and ".
      const text = 'Word, and God';
      expect(text.indexOf('God') - (text.indexOf('Word') + 4), 6,
          reason: 'fixture offsets, so the expectation cannot drift from the text');
      expect(ok('Word DENTRO 6 CARACT God', text), isTrue);
      expect(ok('Word DENTRO 5 CARACT God', text), isFalse);
    });

    test('the unit is required', () {
      expect(
        () => parser.parse('a DENTRO 10 b'),
        throwsA(isA<SearchSyntaxException>()),
      );
    });
  });

  group('wildcards', () {
    test('a trailing star matches any suffix', () {
      expect(ok('Crist*', 'Cristo came'), isTrue);
      expect(ok('Crist*', 'Cristiano and Cristología'), isTrue);
      expect(ok('Crist*', 'the Christian'), isFalse);
    });

    test('a star is not a global match', () {
      // The spec calls this out explicitly. `Crist*` must not match a word where Crist is
      // not at the start, which is what a substring implementation would do.
      expect(ok('Crist*', 'sancristerno'), isFalse);
      expect(ok('Crist*', 'acristianismo'), isFalse);
      expect(ok('Crist*', 'Cristerna'), isTrue,
          reason: 'a longer word still starting with Crist must match');
      expect(ok('Crist*', 'Cris'), isFalse,
          reason: 'the star stands for any suffix, not for a missing letter');
    });

    test('a question mark matches exactly one character', () {
      expect(ok('s?n', 'sin'), isTrue);
      expect(ok('s?n', 'son'), isTrue);
      expect(ok('s?n', 'san'), isTrue);
      expect(ok('s?n', 'sino'), isFalse);
      expect(ok('s?n', 's'), isFalse);
    });

    test('a wildcard matches across diacritics', () {
      expect(ok('cr?st*', 'Cristóbal'), isTrue);
    });

    test('a wildcard does not match a phrase', () {
      expect(ok('cr?st*', 'un crisol'), isFalse);
    });
  });

  group('references', () {
    const jn316 = PassageRef('John', 3, 16);

    test('an exact verse reference matches that verse', () {
      expect(ok('Biblia:"Jn 3:16"', john316, ref: jn316), isTrue);
    });

    test('an exact verse reference rejects another verse', () {
      const jn317 = PassageRef('John', 3, 17);
      expect(ok('Biblia:"Jn 3:16"', john316, ref: jn317), isFalse);
    });

    test('a chapter reference accepts every verse of the chapter', () {
      const jn310 = PassageRef('John', 3, 10);
      expect(ok('Biblia:"Juan 3"', john316, ref: jn310), isTrue);
    });

    test('a chapter reference rejects another chapter', () {
      const jn416 = PassageRef('John', 4, 16);
      expect(ok('Biblia:"Juan 3"', john316, ref: jn416), isFalse);
    });

    test('a verse range covers the verses inside it', () {
      const inRange = PassageRef('John', 3, 17);
      expect(ok('Biblia:"Jn 3:16-18"', john316, ref: inRange), isTrue);
    });

    test('a verse range excludes verses outside it', () {
      const outside = PassageRef('John', 3, 20);
      expect(ok('Biblia:"Jn 3:16-18"', john316, ref: outside), isFalse);
    });

    test('a reference rejects a row with no position', () {
      // A search over a resource whose rows are not addressed by reference must not
      // report every row as a match just because it cannot disprove one.
      expect(ok('Biblia:"Jn 3:16"', john316), isFalse);
    });

    test('a reference combines with a term', () {
      const jn316 = PassageRef('John', 3, 16);
      expect(ok('loved Y Biblia:"Jn 3:16"', john316, ref: jn316), isTrue);
      expect(ok('nonexistent Y Biblia:"Jn 3:16"', john316, ref: jn316), isFalse);
    });

    test('the = form requires the range itself, not a member verse', () {
      // This is the distinction the reference draws: `Biblia:"Juan 3"` finds the chapter,
      // `Biblia:="Juan 3"` finds only the thing that is exactly that chapter.
      const wholeChapter = PassageRef('John', 3, 1, verseEnd: 16);
      const oneVerse = PassageRef('John', 3, 16);
      expect(ok('Biblia:="Juan 3"', 'text', ref: wholeChapter), isTrue);
      expect(ok('Biblia:="Juan 3"', 'text', ref: oneVerse), isFalse);
    });
  });

  group('grouping', () {
    test('a group is evaluated as a unit', () {
      expect(ok('(Word O nonexistent) Y God', john1v1), isTrue);
      expect(ok('(nonexistent O missing) Y God', john1v1), isFalse);
    });

    test('grouping changes the meaning against precedence', () {
      // Without parentheses, `O` binds loosest, so this would be `a O (b Y c)`.
      expect(ok('(Word O nonexistent) Y God', john1v1), isTrue);
      expect(ok('Word O (nonexistent Y God)', john1v1), isTrue);
    });
  });

  group('highlight terms', () {
    test('terms and phrases are reported for highlighting', () {
      expect(matcher.highlightTerms(parser.parse('Word Y "the Word"')),
          ['Word', 'the Word']);
    });

    test('an operator contributes both sides', () {
      expect(matcher.highlightTerms(parser.parse('Word CERCA God')), ['Word', 'God']);
    });
  });

  group('text folding', () {
    test('folding removes diacritics and case', () {
      expect(LogosText.fold('Jesús'), 'jesus');
      expect(LogosText.fold('NIÑO'), 'nino');
      expect(LogosText.fold('Æsop'), 'aesop');
    });

    test('folding splits into words with offsets', () {
      final words = LogosText.words('In the beginning');
      expect(words.map((w) => w.text), ['in', 'the', 'beginning']);
      expect(words.first.start, 0);
      expect(words[1].start, 3);
    });

    test('an elided possessive stays one word', () {
      // The reference's own text contains `LORD 's`, with a space before the apostrophe.
      // Treating the apostrophe as a separator would lose `s` as a searchable token.
      expect(LogosText.fold("LORD's"), "lord's");
      expect(LogosText.words("LORD's").map((w) => w.text), ["lord's"]);
    });

    test('occurrences report every match, including overlapping ones', () {
      final found = LogosText.occurrences('aaaa', 'aa');
      expect(found.length, greaterThanOrEqualTo(2));
    });

    test('character distance between overlapping spans is zero', () {
      expect(LogosText.charactersBetween(0, 5, 3, 8), 0);
      expect(LogosText.charactersBetween(0, 3, 4, 8), 1);
      expect(LogosText.charactersBetween(4, 8, 0, 3), 1);
    });
  });
}
