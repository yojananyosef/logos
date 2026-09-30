import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/domain/models/passage_ref.dart';
import 'package:logos_engine/domain/search/logos_text.dart';
import 'package:logos_engine/domain/search/search_parser.dart';
import 'package:logos_engine/domain/search/search_query.dart';

/// Resolves references the way the real reader does, using a small alias table.
///
/// Injected rather than constructed inside the parser so the parser has no opinion about
/// which abbreviations exist — a test cannot tell whether `Jn` resolved because the parser
/// is right or because the table happens to contain it.
final _aliases = <String, List<String>>{
  'John': ['jn', 'john', 'juan'],
  'Gen': ['gen', 'genesis'],
  'Ps': ['ps', 'psalm', 'salmos'],
};

void main() {
  // The reader's own resolver, given a small alias table. Adapting it here rather than
  // reimplementing resolution keeps the test honest about what the application does.
  final refParser = PassageRefParser(_aliases);
  final parser = SearchParser(refParser.tryParse);

  SearchNode parse(String q) => parser.parse(q);

  /// The operator a single-operator query parsed to.
  SearchBinary binary(String q) {
    final node = parse(q);
    expect(node, isA<SearchBinary>(), reason: 'not a binary: $q -> $node');
    return node as SearchBinary;
  }

  group('lexing', () {
    test('two adjacent words are an implicit AND', () {
      // The help panel lists `Cristo Jesús` beside `Cristo Y Jesús` as the same query, so
      // adjacency has to mean conjunction rather than a phrase.
      final node = binary('amor prójimo');
      expect(node.operator, SearchOperator.both);
      expect(node.left, isA<SearchTerm>());
      expect(node.right, isA<SearchTerm>());
    });

    test('a quoted phrase is one term, not two', () {
      final node = parse('"hijo del Hombre"');
      expect(node, isA<SearchPhrase>());
      expect((node as SearchPhrase).text, 'hijo del Hombre');
    });

    test('parentheses group', () {
      final node = parse('(amor OOdio) Y paz');
      expect(node, isA<SearchBinary>());
      expect((node as SearchBinary).left, isA<SearchGroup>());
    });

    test('a bare number is searchable, not a syntax error', () {
      // "666" is a legitimate thing to search for in scripture.
      final node = parse('666');
      expect(node, isA<SearchTerm>());
      expect((node as SearchTerm).raw, '666');
    });

    test('accents survive lexing', () {
      final node = parse('José');
      expect((node as SearchTerm).raw, 'José');
    });
  });

  group('operators', () {
    test('every documented operator is recognised', () {
      expect(binary('a O b').operator, SearchOperator.either);
      expect(binary('a Y b').operator, SearchOperator.both);
      expect(binary('a NO b').operator, SearchOperator.excluding);
      expect(binary('a ANTES b').operator, SearchOperator.before);
      expect(binary('a DESPUES b').operator, SearchOperator.after);
      expect(binary('a DESPUÉS b').operator, SearchOperator.after);
      expect(binary('a CERCA b').operator, SearchOperator.near);
    });

    test('DESPUES is accepted with and without its accent', () {
      // The spec writes `DESPUES`, the interface writes `DESPUÉS`. A user who types
      // either must get results, not a syntax error.
      expect(SearchOperator.tryParse('DESPUES'), SearchOperator.after);
      expect(SearchOperator.tryParse('DESPUÉS'), SearchOperator.after);
      expect(SearchOperator.tryParse('después'), SearchOperator.after);
    });

    test('CERCA takes an optional word distance', () {
      expect(binary('a CERCA b').distance, SearchOperator.defaultDistance);
      expect(binary('a CERCA 5 b').distance, 5);
      expect(binary('a CERCA 0 b').distance, 0);
    });

    test('DENTRO n PALABRAS is a word distance', () {
      final node = binary('a DENTRO 2 PALABRAS b');
      expect(node.operator, SearchOperator.withinWords);
      expect(node.distance, 2);
    });

    test('DENTRO n CARACT is a character distance', () {
      final node = binary('a DENTRO 10 CARACT b');
      expect(node.operator, SearchOperator.withinChars);
      expect(node.distance, 10);
    });

    test('DENTRO without a number is reported', () {
      expect(
        () => parse('a DENTRO PALABRAS b'),
        throwsA(isA<SearchSyntaxException>().having(
          (e) => e.message,
          'message',
          contains('número'),
        )),
      );
    });

    test('DENTRO with an unknown unit is reported', () {
      // Inferring the unit would let a typo search the wrong distance silently.
      expect(
        () => parse('a DENTRO 5 PÁGINAS b'),
        throwsA(isA<SearchSyntaxException>().having(
          (e) => e.message,
          'message',
          contains('PALABRAS o CARACT'),
        )),
      );
    });

    test('a negative distance is refused', () {
      expect(
        () => parse('a CERCA -5 b'),
        throwsA(isA<SearchSyntaxException>()),
      );
    });
  });

  group('precedence', () {
    test('DENTRO binds tighter than CERCA', () {
      // a DENTRO 2 PALABRAS b CERCA c  ==  (a DENTRO 2 PALABRAS b) CERCA c
      final node = binary('a DENTRO 2 PALABRAS b CERCA c');
      expect(node.operator, SearchOperator.near);
      expect(node.left, isA<SearchBinary>());
      expect((node.left as SearchBinary).operator, SearchOperator.withinWords);
    });

    test('CERCA binds tighter than ANTES', () {
      final node = binary('a CERCA b ANTES c');
      expect(node.operator, SearchOperator.before);
      expect((node.left as SearchBinary).operator, SearchOperator.near);
    });

    test('ordering binds tighter than NO', () {
      final node = binary('a ANTES b NO c');
      expect(node.operator, SearchOperator.excluding);
      expect((node.left as SearchBinary).operator, SearchOperator.before);
    });

    test('NO binds tighter than Y', () {
      final node = binary('a NO b Y c');
      expect(node.operator, SearchOperator.both);
      expect((node.left as SearchBinary).operator, SearchOperator.excluding);
    });

    test('Y binds tighter than O', () {
      // a O b Y c  ==  a O (b Y c)
      final node = binary('a O b Y c');
      expect(node.operator, SearchOperator.either);
      expect((node.right as SearchBinary).operator, SearchOperator.both);
    });

    test('parentheses override precedence', () {
      final node = binary('(a O b) Y c');
      expect(node.operator, SearchOperator.both);
      expect((node.left as SearchGroup).inner, isA<SearchBinary>());
      expect(((node.left as SearchGroup).inner as SearchBinary).operator,
          SearchOperator.either);
    });

    test('a chain of one operator is left-associative', () {
      // a O b O c  ==  (a O b) O c, which for disjunction is the same as a O (b O c).
      final node = binary('a O b O c');
      expect(node.operator, SearchOperator.either);
      expect(node.left, isA<SearchBinary>());
      expect((node.left as SearchBinary).operator, SearchOperator.either);
    });
  });

  group('unknown operators', () {
    test('an unknown all-caps word between terms is reported by name', () {
      // The user has to learn *which* word was wrong. "Invalid operator" alone leaves them
      // scanning the whole query.
      expect(
        () => parse('Cristo CERKCA Jesús'),
        throwsA(isA<SearchSyntaxException>()
            .having((e) => e.operator, 'operator', 'CERKCA')
            .having((e) => e.message, 'message', contains('CERKCA'))),
      );
    });

    test('the error names the operator so the field can point at it', () {
      try {
        parse('a ZZZ b');
        fail('should have thrown');
      } on SearchSyntaxException catch (e) {
        expect(e.operator, 'ZZZ');
        expect(e.position, isNotNull);
      }
    });

    test('a lowercase word is a search term, not an operator', () {
      // Only all-caps words are treated as operator attempts, so an ordinary word that
      // happens to look like one is still searchable.
      final node = parse('cerkca');
      expect(node, isA<SearchTerm>());
    });

    test('an all-caps word with no left operand is a term', () {
      // "O" alone is the Spanish conjunction, and someone searching for a title in caps
      // should not get a syntax error.
      final node = parse('BIBLIA');
      expect(node, isA<SearchTerm>());
    });
  });

  group('references', () {
    test('a quoted reference resolves', () {
      final node = parse('Biblia:"Jn 3:16"');
      expect(node, isA<SearchReference>());
      final ref = (node as SearchReference).reference;
      expect(ref.bookOsis, 'John');
      expect(ref.chapter, 3);
      expect(ref.verse, 16);
    });

    test('a chapter reference has no verse', () {
      final node = parse('Biblia:"Juan 3"') as SearchReference;
      // The parser's resolver produces verse 0 for a chapter-only reference, which is
      // what marks "the whole chapter" rather than a specific verse.
      expect(node.reference.chapter, 3);
      expect(node.reference.verse, 0);
    });

    test('the = form is marked exact', () {
      final plain = parse('Biblia:"Juan 3"') as SearchReference;
      final exact = parse('Biblia:="Juan 3"') as SearchReference;
      expect(plain.exact, isFalse);
      expect(exact.exact, isTrue);
    });

    test('a verse range resolves', () {
      final node = parse('Biblia:"Jn 3:16-18"') as SearchReference;
      expect(node.reference.verse, 16);
      expect(node.reference.verseEnd, 18);
    });

    test('an invalid reference is reported', () {
      expect(
        () => parse('Biblia:"Zzzzz 3:16"'),
        throwsA(isA<SearchSyntaxException>().having(
          (e) => e.message,
          'message',
          contains('no es válida'),
        )),
      );
    });

    test('a bare Biblia stays a searchable word', () {
      // The prefix only means a reference when a quoted reference follows it. "Biblia" on
      // its own is the ordinary Spanish noun.
      final node = parse('Biblia');
      expect(node, isA<SearchTerm>());
    });

    test('a reference combines with terms', () {
      final node = binary('evangelismo CERCA Biblia:"Juan 3"');
      expect(node.operator, SearchOperator.near);
      expect(node.right, isA<SearchReference>());
    });
  });

  group('wildcards', () {
    test('a trailing star is a prefix wildcard', () {
      final node = parse('Crist*') as SearchTerm;
      expect(node.hasWildcard, isTrue);
      expect(node.matcher, isA<WildcardTermMatcher>());
    });

    test('a question mark is a wildcard', () {
      final node = parse('s?n') as SearchTerm;
      expect(node.hasWildcard, isTrue);
    });

    test('a plain term is not a wildcard', () {
      final node = parse('Cristo') as SearchTerm;
      expect(node.hasWildcard, isFalse);
    });

    test('only a trailing star is answerable by the index alone', () {
      // FTS5 treats a trailing * as a prefix but has no `?` at all — `cr?st` is a syntax
      // error there. Getting this wrong would make `s?n` an error the user cannot act on.
      expect((parse('crist*') as SearchTerm).matcher.isSimplePrefix, isTrue);
      expect((parse('s?n') as SearchTerm).matcher.isSimplePrefix, isFalse);
      expect((parse('cr?st') as SearchTerm).matcher.isSimplePrefix, isFalse);
    });
  });

  group('indexability', () {
    test('terms, phrases and boolean combinations are indexable', () {
      expect((parse('crist*') as SearchTerm).indexable, isFalse,
          reason: 'a wildcard needs the text, not just the index');
      expect((parse('cristo') as SearchTerm).indexable, isTrue);
      expect((parse('"la palabra"') as SearchPhrase).indexable, isTrue);
      expect(parse('a O b').indexable, isTrue);
      expect(parse('a Y b').indexable, isTrue);
      expect(parse('a NO b').indexable, isTrue);
    });

    test('proximity and ordering are not indexable', () {
      // This is the assertion that keeps the retrieval honest: if these ever claim to be
      // indexable, the search would delegate to FTS5's broken NEAR and return nothing.
      expect(parse('a CERCA b').indexable, isFalse);
      expect(parse('a ANTES b').indexable, isFalse);
      expect(parse('a DESPUES b').indexable, isFalse);
      expect(parse('a DENTRO 2 PALABRAS b').indexable, isFalse);
      expect(parse('a DENTRO 10 CARACT b').indexable, isFalse);
    });

    test('a reference is not indexable', () {
      expect(parse('Biblia:"Jn 3:16"').indexable, isFalse);
    });
  });

  group('syntax errors', () {
    test('an empty query is refused', () {
      expect(() => parse('   '), throwsA(isA<SearchSyntaxException>()));
    });

    test('an unclosed quote is refused', () {
      expect(
        () => parse('"la palabra'),
        throwsA(isA<SearchSyntaxException>().having(
          (e) => e.message,
          'message',
          contains('comilla'),
        )),
      );
    });

    test('an unclosed parenthesis is refused', () {
      expect(
        () => parse('(a O b'),
        throwsA(isA<SearchSyntaxException>().having(
          (e) => e.message,
          'message',
          contains('paréntesis'),
        )),
      );
    });

    test('a closing parenthesis with no opening is refused', () {
      expect(
        () => parse('a) O b'),
        throwsA(isA<SearchSyntaxException>().having(
          (e) => e.message,
          'message',
          contains('cierre sin abrir'),
        )),
      );
    });

    test('a dangling operator is refused', () {
      expect(() => parse('a O'), throwsA(isA<SearchSyntaxException>()));
    });

    test('tryParse returns null instead of throwing', () {
      // The field is parsed on every keystroke; a half-typed query must not throw.
      expect(parser.tryParse('a O'), isNull);
      expect(parser.tryParse('a O b'), isNotNull);
    });
  });
}
