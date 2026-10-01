import '../models/passage_ref.dart';

/// Folds and splits text the way a module's index does.
///
/// Every module is tokenised `unicode61 remove_diacritics 2`, so `Jesus` finds `Jesus`
/// and `principio` finds `principio`. Anything this application decides *after* the
/// index has answered — wildcard shapes, word distances, character distances — has to
/// fold the same way, or a row the index legitimately returned gets discarded here.
///
/// Folding therefore lower-cases and strips Latin diacritics. Latin-1 and Latin
/// Extended-A are mapped explicitly, which covers every script the approved corpus uses
/// (English and Spanish). Outside Latin there is nothing to strip, so a literal
/// comparison is already the right answer, which is why no general decomposition is
/// needed.
///
/// This is deliberately not a general Unicode normaliser. A row can only be *excluded*
/// here if the index returned it, so a character this map does not know simply leaves
/// both sides of the comparison untouched rather than risking a false negative.
class LogosText {
  const LogosText._();

  /// The Latin folds, keyed by the single code unit that is removed.
  static const Map<String, String> _folds = {
// 176 entries
    'À': 'A', 'Á': 'A', 'Â': 'A',
    'Ã': 'A', 'Ä': 'A', 'Å': 'A',
    'Æ': 'AE', 'Ç': 'C', 'È': 'E',
    'É': 'E', 'Ê': 'E', 'Ë': 'E',
    'Ì': 'I', 'Í': 'I', 'Î': 'I',
    'Ï': 'I', 'Ð': 'D', 'Ñ': 'N',
    'Ò': 'O', 'Ó': 'O', 'Ô': 'O',
    'Õ': 'O', 'Ö': 'O', 'Ø': 'O',
    'Ù': 'U', 'Ú': 'U', 'Û': 'U',
    'Ü': 'U', 'Ý': 'Y', 'Þ': 'TH',
    'ß': 'ss', 'à': 'a', 'á': 'a',
    'â': 'a', 'ã': 'a', 'ä': 'a',
    'å': 'a', 'æ': 'ae', 'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e',
    'ë': 'e', 'ì': 'i', 'í': 'i',
    'î': 'i', 'ï': 'i', 'ð': 'd',
    'ñ': 'n', 'ò': 'o', 'ó': 'o',
    'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ø': 'o', 'ù': 'u', 'ú': 'u',
    'û': 'u', 'ü': 'u', 'ý': 'y',
    'þ': 'th', 'ÿ': 'y', 'Ā': 'A',
    'ā': 'a', 'Ă': 'A', 'ă': 'a',
    'Ą': 'A', 'ą': 'a', 'Ć': 'C',
    'ć': 'c', 'Ĉ': 'C', 'ĉ': 'c',
    'Ċ': 'C', 'ċ': 'c', 'Č': 'C',
    'č': 'c', 'Ď': 'D', 'ď': 'd',
    'Ē': 'E', 'ē': 'e', 'Ĕ': 'E',
    'ĕ': 'e', 'Ė': 'E', 'ė': 'e',
    'Ę': 'E', 'ę': 'e', 'Ě': 'E',
    'ě': 'e', 'Ĝ': 'G', 'ĝ': 'g',
    'Ğ': 'G', 'ğ': 'g', 'Ġ': 'G',
    'ġ': 'g', 'Ģ': 'G', 'ģ': 'g',
    'Ĥ': 'H', 'ĥ': 'h', 'Ĩ': 'I',
    'ĩ': 'i', 'Ī': 'I', 'ī': 'i',
    'Ĭ': 'I', 'ĭ': 'i', 'Į': 'I',
    'į': 'i', 'İ': 'I', 'Ĵ': 'J',
    'ĵ': 'j', 'Ķ': 'K', 'ķ': 'k',
    'Ĺ': 'L', 'ĺ': 'l', 'Ļ': 'L',
    'ļ': 'l', 'Ľ': 'L', 'ľ': 'l',
    'Ł': 'L', 'ł': 'l', 'Ń': 'N',
    'ń': 'n', 'Ņ': 'N', 'ņ': 'n',
    'Ň': 'N', 'ň': 'n', 'Ō': 'O',
    'ō': 'o', 'Ŏ': 'O', 'ŏ': 'o',
    'Ő': 'O', 'ő': 'o', 'Œ': 'OE',
    'œ': 'oe', 'Ŕ': 'R', 'ŕ': 'r',
    'Ŗ': 'R', 'ŗ': 'r', 'Ř': 'R',
    'ř': 'r', 'Ś': 'S', 'ś': 's',
    'Ŝ': 'S', 'ŝ': 's', 'Ş': 'S',
    'ş': 's', 'Š': 'S', 'š': 's',
    'Ţ': 'T', 'ţ': 't', 'Ť': 'T',
    'ť': 't', 'Ŧ': 'T', 'ŧ': 't',
    'Ũ': 'U', 'ũ': 'u', 'Ū': 'U',
    'ū': 'u', 'Ŭ': 'U', 'ŭ': 'u',
    'Ů': 'U', 'ů': 'u', 'Ű': 'U',
    'ű': 'u', 'Ų': 'U', 'ų': 'u',
    'Ŵ': 'W', 'ŵ': 'w', 'Ŷ': 'Y',
    'ŷ': 'y', 'Ÿ': 'Y', 'Ź': 'Z',
    'ź': 'z', 'Ż': 'Z', 'ż': 'z',
    'Ž': 'Z', 'ž': 'z',
  };

  /// Lower-cases and removes Latin diacritics.
  ///
  /// Length is not preserved: `Æ` and `ß` expand, so offsets computed on folded text
  /// index a different string than the original. Callers that need character offsets into
  /// the original must use [occurrences], which folds per character class instead.
  static String fold(String input) {
    final out = StringBuffer();
    for (final unit in input.toLowerCase().codeUnits) {
      final ch = String.fromCharCode(unit);
      out.write(_folds[ch] ?? ch);
    }
    return out.toString();
  }

  /// Whether [input] is entirely outside the Latin ranges this class folds.
  ///
  /// A non-Latin head needs no folding, so a wildcard or a distance measured on it can
  /// be compared literally and is therefore exact.
  static bool isNonLatin(String input) {
    for (final unit in input.codeUnits) {
      if (unit < 0x00C0 || unit > 0x024F) {
        if (!_isLatinBasic(unit)) return true;
      }
    }
    return false;
  }

  static bool _isLatinBasic(int unit) =>
      (unit >= 0x41 && unit <= 0x5A) || // A-Z
      (unit >= 0x61 && unit <= 0x7A) || // a-z
      (unit >= 0x00C0 && unit <= 0x024F); // folded above

  /// A word and the offsets it occupies in [input].
  ///
  /// Offsets are in *folded* units, so they are only meaningful for comparing two words
  /// from the same folded string.
  static List<FoldedWord> words(String input) {
    final folded = fold(input);
    final out = <FoldedWord>[];
    var start = -1;
    for (var i = 0; i < folded.length; i++) {
      final isWordChar = _isWordChar(folded.codeUnitAt(i));
      if (isWordChar && start < 0) {
        start = i;
      } else if (!isWordChar && start >= 0) {
        out.add(FoldedWord(folded.substring(start, i), start, i));
        start = -1;
      }
    }
    if (start >= 0) {
      out.add(FoldedWord(folded.substring(start, folded.length), start, folded.length));
    }
    return out;
  }

  /// Whether a character can appear inside a word.
  ///
  /// Letters, digits and the apostrophe. The apostrophe is included because scripture is
  /// full of elided possessives — the reference's own text shows `LORD 's`, with a space
  /// before the apostrophe, so treating it as a separator would split `LORD` from `s` and
  /// lose the term. A leading apostrophe is dropped, which is how `'`tis` is indexed.
  static bool _isWordChar(int unit) {
    if ((unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A)) return true;
    if (unit >= 0xC0 && unit <= 0x24F) return true; // Latin letters, folded above
    if (unit >= 0x30 && unit <= 0x39) return true; // digits
    return unit == 0x27; // apostrophe
  }

  /// The folded character offsets at which [term] occurs in [input].
  ///
  /// Used for character-distance operators, which must be measured on the original text
  /// rather than on the folded one, because `CARACT` is a property of what the reader
  /// sees. Folding is applied per candidate position, so a term of differing length still
  /// aligns: the search walks the original and folds each window it tries.
  static List<({int start, int end})> occurrences(String input, String term) {
    if (term.isEmpty) return const [];
    final haystack = fold(input);
    final needle = fold(term);
    final out = <({int start, int end})>[];
    var from = 0;
    while (true) {
      final at = haystack.indexOf(needle, from);
      if (at < 0) break;
      out.add((start: at, end: at + needle.length));
      from = at + 1; // overlapping occurrences count
    }
    return out;
  }

  /// The folded character offsets at which [term] occurs in [input], in *input*'s
  /// coordinates.
  ///
  /// [fold] cannot be used for this: it expands `Æ` to `ae` and `ß` to `ss`, so offsets
  /// measured on the folded string index a different string than the caller is about to
  /// slice. Slicing the original at those offsets would highlight the wrong words — and
  /// worse, the wrong words *look* plausible, so nothing would look broken.
  ///
  /// This folds character by character and keeps any character whose fold is longer than
  /// one unit. `Æ` then simply does not match a query for `ae`, which is a missed match in
  /// a language this application does not ship rather than a mis-highlighted verse.
  static List<({int start, int end})> spansInOriginal(String input, String term) {
    if (term.isEmpty) return const [];
    final haystack = _foldKeepingLength(input);
    final needle = _foldKeepingLength(term);
    if (needle.length != term.length) {
      // The term itself contains an expanding fold, so no window of the haystack can line
      // up with it. Reported as no match rather than as a wrong one.
      return const [];
    }

    final out = <({int start, int end})>[];
    var from = 0;
    while (true) {
      final at = haystack.indexOf(needle, from);
      if (at < 0) break;
      out.add((start: at, end: at + needle.length));
      from = at + 1;
    }
    return out;
  }

  /// [fold], but never changing the length of the string.
  ///
  /// Every Latin letter this class folds is one-to-one except `Æ`/`æ`, `Œ`/`œ`, `Þ`/`þ`
  /// and `ß`, which expand. Those are returned unchanged so offsets stay valid.
  static String _foldKeepingLength(String input) {
    final out = StringBuffer();
    for (final unit in input.toLowerCase().codeUnits) {
      final ch = String.fromCharCode(unit);
      final folded = _folds[ch] ?? ch;
      out.write(folded.length == 1 ? folded : ch);
    }
    return out.toString();
  }

  /// The number of characters strictly between two spans, or 0 if they overlap.
  ///
  /// Takes the distance between the spans rather than the text, because both spans come
  /// from the same folded string (see [occurrences]) and comparing them against the
  /// original text would mix two coordinate systems. Callers that need a character
  /// distance to reflect what the reader sees must map the folded offsets back through a
  /// single pass, which is what `SearchPlan` does for `CARACT` operators.
  static int charactersBetween(int startA, int endA, int startB, int endB) {
    if (endA <= startB) return startB - endA;
    if (endB <= startA) return startA - endB;
    return 0; // overlapping
  }
}

/// A word and where it sits in the folded text it came from.
class FoldedWord {
  const FoldedWord(this.text, this.start, this.end);

  final String text;
  final int start;
  final int end;
}

/// One term of a query, and how it should be matched.
sealed class TermMatcher {
  const TermMatcher(this.literal);

  /// The text the user typed, minus any wildcard characters.
  final String literal;

  /// Whether this matcher needs positions to decide, which means the index alone cannot
  /// answer it and the row text has to be consulted.
  bool get needsText;

  /// Whether the index can answer this on its own.
  ///
  /// True for a whole-word term, where the index's inverted list is exactly the answer.
  /// False for a wildcard, whose shape has to be checked against the text.
  bool get isSimplePrefix;

  bool matchesWord(String word);
  bool matchesText(String text);
}

/// A plain term, matched as a whole word.
class ExactTermMatcher extends TermMatcher {
  const ExactTermMatcher(super.literal);

  @override
  bool get needsText => false;

  @override
  bool get isSimplePrefix => true;

  @override
  bool matchesWord(String word) => word == literal;

  @override
  bool matchesText(String text) => LogosText.words(text).any((w) => matchesWord(w.text));
}

/// A term containing `*` or `?`.
///
/// `*` is zero or more characters and `?` is exactly one, both inside a word. The index
/// answers the literal head as a prefix, and this matcher then checks the shape, because
/// FTS5 has no `?` at all — `cr?st` is a syntax error there, not a zero result.
class WildcardTermMatcher extends TermMatcher {
  WildcardTermMatcher(this.pattern) : super(_headOf(pattern)) {
    _expression = RegExp(
      '^${pattern.split('').map(_escapeSegment).join()}\$',
      caseSensitive: false,
    );
  }

  final String pattern;
  late final RegExp _expression;

  /// The literal run before the first wildcard, which is what the index can answer.
  ///
  /// Empty when the pattern opens with a wildcard, in which case the index cannot narrow
  /// anything and the whole table is scanned.
  static String _headOf(String pattern) {
    final stop = pattern.indexOf(RegExp(r'[*?]'));
    final head = stop < 0 ? pattern : pattern.substring(0, stop);
    return head.toLowerCase();
  }

  /// Whether the pattern can be answered by a prefix query alone.
  ///
  /// `crist*` can: FTS5 treats the trailing `*` as a prefix. `cr?st` cannot, because `?`
  /// is a syntax error in FTS5, so the index is asked for `cr` and the shape is checked
  /// here. Getting this backwards would make `s?n` an error the user cannot act on.
  @override
  bool get isSimplePrefix =>
      pattern.endsWith('*') && !pattern.substring(0, pattern.length - 1).contains('*');

  @override
  bool get needsText => true;

  @override
  bool matchesWord(String word) =>
      _expression.hasMatch(word) || _expression.hasMatch(LogosText.fold(word));

  @override
  bool matchesText(String text) => LogosText.words(text).any((w) => matchesWord(w.text));

  /// Translates one pattern character into a regex fragment.
  ///
  /// `*` becomes `.*` and `?` becomes `.`; everything else is literal. A `*` that is not
  /// at the end of a word must still be able to match across nothing, which `.*` does.
  static String _escapeSegment(String ch) =>
      ch == '*' ? '.*' : (ch == '?' ? '.' : RegExp.escape(ch));
}

/// The literal text of a reference, already split into its parts.
class ReferenceTarget {
  const ReferenceTarget(this.reference, {this.exact = false});

  final PassageRef reference;

  /// The `=` form: the passage must be exactly this one, not a superset.
  final bool exact;
}
