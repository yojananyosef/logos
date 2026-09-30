import '../models/passage_ref.dart';
import 'logos_text.dart';
import 'search_query.dart';

/// Decides whether a row of text satisfies a parsed query.
///
/// This is the part FTS5 cannot do. The index answers term and phrase membership, and it
/// is fast and exact at that, but three of the documented operators need positions:
///
/// - `NEAR` and `DENTRO n PALABRAS` need to know how many words separate two terms.
/// - `DENTRO n CARACT` needs character offsets.
/// - `ANTES` and `DESPUES` need to know which of two terms occurs first.
///
/// FTS5 has a `NEAR` operator and it does not work. On SQLite 3.53.4 it parses without
/// error and matches nothing, including a document where the two terms are adjacent:
/// `Word NEAR beginning` returns 0 on a table containing `Word beginning`, while
/// `"Word beginning"` returns 1. Delegating proximity to it would give a search that
/// accepts `CERCA 5` and silently returns no results, which is worse than not offering
/// the operator at all — the user cannot tell the query was wrong from the corpus being
/// silent.
///
/// So the index retrieves candidates and this class decides. The two halves are not
/// redundant: the index narrows 31,000 verses to a few hundred, and the remaining check is
/// cheap.
class SearchMatcher {
  const SearchMatcher();

  /// Whether [text] satisfies [node].
  ///
  /// [reference] is the row's own position, needed for `Biblia:"Jn 3:16"`.
  bool matches(SearchNode node, String text, {PassageRef? reference}) =>
      _eval(node, text, reference);

  /// Every term that should be highlighted in a result for [node].
  List<String> highlightTerms(SearchNode node) => node.highlightTerms;

  bool _eval(SearchNode node, String text, PassageRef? ref) {
    if (node is SearchTerm) {
      return node.matcher.matchesText(text);
    }
    if (node is SearchPhrase) {
      // Matched on the folded text so the phrase ignores case and diacritics, the same
      // way the index does. An exact substring test on the raw text would miss `HOMBRES`
      // for a query of `hombres` and would be inconsistent with what retrieval accepted.
      return LogosText.fold(text).contains(LogosText.fold(node.text));
    }
    if (node is SearchReference) {
      return _referenceMatches(node, ref);
    }
    if (node is SearchGroup) {
      return _eval(node.inner, text, ref);
    }
    if (node is SearchBinary) {
      return _binary(node, text, ref);
    }
    return true;
  }

  bool _binary(SearchBinary node, String text, ref) {
    switch (node.operator) {
      case SearchOperator.either:
        return _eval(node.left, text, ref) || _eval(node.right, text, ref);
      case SearchOperator.both:
        return _eval(node.left, text, ref) && _eval(node.right, text, ref);
      case SearchOperator.excluding:
        return _eval(node.left, text, ref) && !_eval(node.right, text, ref);
      case SearchOperator.before:
        return _ordered(node, text, ref, firstMustComeFirst: true);
      case SearchOperator.after:
        return _ordered(node, text, ref, firstMustComeFirst: false);
      case SearchOperator.near:
      case SearchOperator.withinWords:
        return _withinWords(node, text, ref);
      case SearchOperator.withinChars:
        return _withinChars(node, text, ref);
    }
  }

  /// Whether a reference node accepts the row's position.
  ///
  /// `Biblia:"Juan 3"` accepts every verse of John 3. `Biblia:="Juan 3"` accepts only what
  /// is exactly that chapter, which is the distinction the reference draws and the reason
  /// the `=` form exists.
  bool _referenceMatches(SearchReference node, PassageRef? ref) {
    if (ref == null) return false;
    final want = node.reference;
    if (ref.bookOsis != want.bookOsis) return false;
    if (ref.chapter != want.chapter) return false;

    // A reference with no verse is a whole chapter, which the parser records as verse 0.
    // It has to be treated as "any verse", not as verse zero: comparing against the
    // literal 0 rejects every verse in the chapter, so `Biblia:"Juan 3"` — one of the
    // examples in the help panel — would return nothing while claiming to be valid.
    if (want.verse <= 0) {
      if (node.exact) {
        // The `=` form needs the chapter itself, which is a single row spanning the whole
        // chapter, not any individual verse of it.
        return ref.verse == 1 && ref.verseEnd != null;
      }
      return true;
    }

    if (node.exact) {
      // The `=` form names a range exactly. A row qualifies when its own span equals the
      // requested span, so a verse inside the range does not match it.
      if (want.verseEnd != null) {
        return ref.verse == want.verse && ref.verseEnd == want.verseEnd;
      }
      return ref.verse == want.verse;
    }

    final end = want.verseEnd ?? want.verse;
    final rowEnd = ref.verseEnd ?? ref.verse;
    return ref.verse <= end && rowEnd >= want.verse;
  }

  /// Whether the left term occurs before (or after) the right one.
  bool _ordered(SearchBinary node, String text, ref, {required bool firstMustComeFirst}) {
    final leftPositions = _positionsOf(node.left, text);
    final rightPositions = _positionsOf(node.right, text);
    if (leftPositions.isEmpty || rightPositions.isEmpty) return false;

    for (final a in leftPositions) {
      for (final b in rightPositions) {
        final ordered = firstMustComeFirst ? a < b : a > b;
        if (ordered) return true;
      }
    }
    return false;
  }

  /// Whether two terms occur within the requested number of words.
  ///
  /// The distance counts words *between* the two terms, so `CERCA 0` means adjacent and
  /// `CERCA 5` means at most five words in between. Counting the gap rather than the
  /// distance between start positions is what makes `CERCA 0` mean "touching", which is
  /// the reading that makes the operator useful at all.
  bool _withinWords(SearchBinary node, String text, ref) {
    final left = _wordSpansOf(node.left, text);
    final right = _wordSpansOf(node.right, text);
    if (left.isEmpty || right.isEmpty) return false;

    final limit = node.distance ?? SearchOperator.defaultDistance;
    for (final a in left) {
      for (final b in right) {
        final gap = _wordsBetween(a, b, text);
        if (gap <= limit) return true;
      }
    }
    return false;
  }

  /// Whether two terms occur within the requested number of characters.
  bool _withinChars(SearchBinary node, String text, ref) {
    final left = _charSpansOf(node.left, text);
    final right = _charSpansOf(node.right, text);
    if (left.isEmpty || right.isEmpty) return false;

    final limit = node.distance ?? SearchOperator.defaultDistance;
    for (final a in left) {
      for (final b in right) {
        final gap = LogosText.charactersBetween(a.$1, a.$2, b.$1, b.$2);
        if (gap <= limit) return true;
      }
    }
    return false;
  }

  /// Word indices at which [node] occurs.
  List<int> _positionsOf(SearchNode node, String text) {
    final spans = _wordSpansOf(node, text);
    return [for (final s in spans) s.$1];
  }

  /// The folded word indices a term occupies.
  List<(int, int)> _wordSpansOf(SearchNode node, String text) {
    final words = LogosText.words(text);
    if (node is SearchPhrase) {
      return _phraseWordSpans(node.text, words);
    }
    if (node is SearchTerm) {
      final matcher = node.matcher;
      return [
        for (var i = 0; i < words.length; i++)
          if (matcher.matchesWord(words[i].text)) (i, i),
      ];
    }
    return const [];
  }

  /// The word indices each word of a phrase occupies.
  ///
  /// A phrase must be found in order and adjacently, so this returns a list of spans one
  /// per phrase word rather than a single index. Returning one index for the whole phrase
  /// would make `CERCA` treat a five-word phrase as occupying a single word, and then
  /// `"a b" CERCA "b c"` would report a zero-word gap for two spans that overlap.
  List<(int, int)> _phraseWordSpans(String phrase, List<FoldedWord> words) {
    final needle = LogosText.words(phrase);
    if (needle.isEmpty) return const [];
    final out = <(int, int)>[];
    for (var start = 0; start + needle.length <= words.length; start++) {
      var matches = true;
      for (var k = 0; k < needle.length; k++) {
        if (words[start + k].text != needle[k].text) {
          matches = false;
          break;
        }
      }
      if (matches) out.add((start, start + needle.length - 1));
    }
    return out;
  }

  /// Character spans at which [node] occurs.
  List<(int, int)> _charSpansOf(SearchNode node, String text) {
    if (node is SearchTerm) {
      final literal = LogosText.fold(node.raw);
      if (literal.isEmpty) return const [];
      return [
        for (final o in LogosText.occurrences(text, literal)) (o.start, o.end),
      ];
    }
    if (node is SearchPhrase) {
      final literal = LogosText.fold(node.text);
      if (literal.isEmpty) return const [];
      return [
        for (final o in LogosText.occurrences(text, literal)) (o.start, o.end),
      ];
    }
    return const [];
  }

  /// The number of whole words between two word spans.
  ///
  /// Overlapping spans are a gap of 0 rather than a negative number: a phrase matching
  /// itself, or two terms sharing a word, is as close as text can get.
  int _wordsBetween((int, int) a, (int, int) b, String text) {
    if (a.$2 < b.$1) return b.$1 - a.$2 - 1;
    if (b.$2 < a.$1) return a.$1 - b.$2 - 1;
    return 0;
  }
}
