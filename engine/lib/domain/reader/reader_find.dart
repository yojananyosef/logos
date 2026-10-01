import '../../data/repositories/bible_repository.dart';
import '../search/logos_text.dart';

/// One occurrence of a find term inside one verse.
///
/// The offsets are into the verse's own text, not into the rendered chapter, so they stay
/// valid however the chapter is laid out. That matters because the reader has to both
/// highlight the run and scroll to it, and those are two different coordinate systems.
class FindMatch {
  const FindMatch({
    required this.osisCode,
    required this.bookName,
    required this.bookOrder,
    required this.chapter,
    required this.verse,
    required this.start,
    required this.end,
  });

  final String osisCode;
  final String bookName;

  /// The book's position in the canon, which is what orders matches for stepping.
  final int bookOrder;

  final int chapter;
  final int verse;

  /// Inclusive character offset of the first matched character in the verse's text.
  final int start;

  /// Exclusive offset just past the last matched character.
  final int end;

  String get text => '$bookName $chapter:$verse';

  @override
  String toString() => '$text [$start,$end)';
}

/// The outcome of a find: every match in the module, in reading order.
class FindResult {
  const FindResult({required this.term, required this.matches});

  final String term;

  /// Ordered by book, then chapter, then verse, then position in the verse.
  ///
  /// Reading order rather than FTS5 rank: stepping through matches has to walk the Bible
  /// the way the reader would read it, or "next" jumps about unpredictably.
  final List<FindMatch> matches;

  int get count => matches.length;
  bool get isEmpty => matches.isEmpty;

  /// The matches inside one chapter, which is all the reader can highlight at a time.
  List<FindMatch> inChapter(String osisCode, int chapter) => [
        for (final m in matches)
          if (m.osisCode == osisCode && m.chapter == chapter) m,
      ];

  /// The position of [match] within [matches], or -1 if it is not among them.
  ///
  /// Identity rather than equality: a match rebuilt from a freshly-read chapter is the same
  /// occurrence, and comparing fields would fail on any difference in how it was built.
  int indexOf(FindMatch match) {
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      if (m.osisCode == match.osisCode &&
          m.chapter == match.chapter &&
          m.verse == match.verse &&
          m.start == match.start) {
        return i;
      }
    }
    return -1;
  }
}

/// Finds text inside one installed module.
///
/// Two steps, and the split is the design rather than an implementation detail:
///
/// 1. The module's own FTS5 index returns the *verses* that contain the term. It is the
///    only thing fast enough to search 31,000 verses per keystroke, and it is already the
///    thing task 9.3 settled on.
/// 2. Each returned verse's text is scanned for the exact span, because the index answers
///    in tokens. It cannot say where in a verse the match is, and it cannot answer at all
///    for a term that is not a whole word or a prefix — which is exactly what a find bar is
///    asked for.
///
/// The index's candidate set is therefore an upper bound, and step two is what decides.
class ModuleFinder {
  const ModuleFinder(this._repository);

  final BibleRepository _repository;

  /// Matches of [rawTerm] in [moduleId], capped at [limit].
  ///
  /// The cap is on *matches*, not on verses, because one verse can hold several: a limit
  /// applied to the candidate list would stop at a hundredth of the Bible in a repetitive
  /// book while reporting a count nobody can reconcile with the chapter they are reading.
  Future<FindResult> find(
    String moduleId,
    String rawTerm, {
    int limit = 2000,
  }) async {
    final term = rawTerm.trim();
    if (term.isEmpty) return const FindResult(term: '', matches: []);

    final expression = _matchExpression(term);
    if (expression == null) {
      // Nothing FTS5 can be asked. Returning an empty result rather than throwing, because
      // "no matches" is the honest answer for a term made only of punctuation and the user
      // needs a message, not an exception.
      return FindResult(term: term, matches: const []);
    }

    final candidates = await _repository.search(moduleId, expression, limit: 4000);
    final matcher = _TextMatcher(term);
    final matches = <FindMatch>[];

    for (final hit in candidates) {
      for (final span in matcher.spansIn(hit.text)) {
        matches.add(FindMatch(
          osisCode: hit.osisCode,
          bookName: hit.bookName,
          bookOrder: hit.bookOrder,
          chapter: hit.chapter,
          verse: hit.verse,
          start: span.start,
          end: span.end,
        ));
        if (matches.length >= limit) break;
      }
      if (matches.length >= limit) break;
    }

    matches.sort(_inReadingOrder);
    return FindResult(term: term, matches: matches);
  }

  /// By the canon's order, not by the OSIS code as a string.
  ///
  /// Sorting by code puts Exodus before Genesis before Isaiah before John — which is right
  /// by accident for those four and wrong for every book whose code does not start with its
  /// position's initial. Stepping through matches has to walk the Bible the way it is read,
  /// or "next" jumps somewhere the reader cannot predict.
  static int _inReadingOrder(FindMatch a, FindMatch b) {
    final byBook = a.bookOrder.compareTo(b.bookOrder);
    if (byBook != 0) return byBook;
    final byChapter = a.chapter.compareTo(b.chapter);
    if (byChapter != 0) return byChapter;
    final byVerse = a.verse.compareTo(b.verse);
    if (byVerse != 0) return byVerse;
    return a.start.compareTo(b.start);
  }

  /// The FTS5 expression for [term], or null when there is nothing to ask.
  ///
  /// A multi-word term becomes a phrase, and a term ending in `*` stays a prefix query.
  /// Anything else — an empty term, or one FTS5 would reject as syntax — returns null so
  /// the caller can report no matches instead of surfacing a SQLite error to a reader who
  /// merely typed a question mark.
  static String? _matchExpression(String term) {
    final folded = LogosText.fold(term).trim();
    if (folded.isEmpty) return null;

    final isPrefix = folded.endsWith('*');
    final head = isPrefix ? folded.substring(0, folded.length - 1) : folded;

    // FTS5 treats a trailing `*` as a prefix operator on the token it follows, and a quoted
    // token does not take one: `"beginn" *` is a syntax error there. So a prefix query is
    // built from the bare head and only a plain term is quoted.
    //
    // Quoting the plain case is what keeps a term that merely looks like an operator from
    // being read as one: someone searching for `OR` in a commentary should find the word,
    // not get a query that means something else.
    if (isPrefix) {
      return head.isEmpty ? null : '$head*';
    }

    final body = head
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '"${w.replaceAll('"', '""')}"')
        .join(' ');

    return body.isEmpty ? null : '($body)';
  }
}

/// Locates a term's spans inside one verse's text.
///
/// A class rather than a call to [LogosText.spansInOriginal] because the two halves of a
/// find ask the index and the text different things. The index understands a prefix; the
/// text has to be walked word by word, because `beginn*` is not a substring that appears
/// anywhere. Passing the term through verbatim to a substring search is how a wildcard
/// reports zero matches for a word the reader can see.
class _TextMatcher {
  _TextMatcher(String rawTerm) : _term = rawTerm.trim();

  final String _term;

  /// Whether the term ends in `*`, making it a prefix.
  bool get _isPrefix => _term.endsWith('*');

  /// The term with any wildcard marker removed.
  String get _stem => _isPrefix ? _term.substring(0, _term.length - 1) : _term;

  bool get _isWordTerm => _stem.isNotEmpty && !_stem.contains(' ');

  /// Where the term occurs in [text], in that text's own coordinates.
  List<({int start, int end})> spansIn(String text) {
    if (_stem.isEmpty) return const [];

    if (!_isPrefix) {
      // A phrase with a space is a substring search, not a word search: `in the` is
      // something a reader types, and finding it inside a longer word would be wrong.
      return LogosText.spansInOriginal(text, _stem);
    }

    if (!_isWordTerm) return const [];
    return _prefixSpans(text, _stem);
  }

  /// Every word in [text] starting with [stem].
  ///
  /// Folding per candidate rather than on the whole string, because folding can change
  /// length and an offset measured on the folded string would not index [text]. That is the
  /// same reason [LogosText.spansInOriginal] folds that way.
  List<({int start, int end})> _prefixSpans(String text, String stem) {
    final out = <({int start, int end})>[];
    final needle = LogosText.fold(stem);
    if (needle.isEmpty) return out;

    // Advancing by the word just consumed, not by one character at the end of it. The two
    // differ wherever a non-word character is preceded by another non-word character —
    // `wisdom, and`, `Word.` at the end of a verse — and there "start a word" produces an
    // empty word that leaves the position unchanged, so the loop never terminates. Real
    // scripture is full of that; a fixture of single-word verses is not, which is why a
    // four-word test verse would never have found it.
    var i = 0;
    while (i < text.length) {
      if (!_isWordChar(text.codeUnitAt(i))) {
        i++;
        continue;
      }
      final start = i;
      while (i < text.length && _isWordChar(text.codeUnitAt(i))) {
        i++;
      }
      if (LogosText.fold(text.substring(start, i)).startsWith(needle)) {
        out.add((start: start, end: i));
      }
    }
    return out;
  }

  /// The same character class [LogosText] indexes on: letters, digits and the apostrophe.
  ///
  /// Duplicated rather than exposed because `LogosText`'s is private, and a second,
  /// different definition here would make a prefix match on words the index never contained.
  static bool _isWordChar(int unit) {
    if ((unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A)) return true;
    if (unit >= 0xC0 && unit <= 0x24F) return true;
    if (unit >= 0x30 && unit <= 0x39) return true;
    return unit == 0x27;
  }
}
