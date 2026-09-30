import '../models/passage_ref.dart';
import 'logos_text.dart';
import 'search_query.dart';

/// One search result, as the interface presents it.
class SearchResult {
  const SearchResult({
    required this.moduleId,
    required this.moduleName,
    required this.reference,
    required this.bookName,
    required this.text,
    required this.segments,
    this.score = 0,
  });

  final String moduleId;
  final String moduleName;
  final PassageRef reference;
  final String bookName;
  final String text;

  /// The text split into matched and unmatched runs, for rendering.
  final List<SearchSegment> segments;

  /// The index's relevance, used for ordering within a module.
  final double score;

  /// The label shown above the text, e.g. `Juan 3:16`.
  String get label => _format(reference, bookName);

  static String _format(PassageRef ref, String book) {
    final head = ref.verse <= 0
        ? book
        : (ref.verseEnd != null && ref.verseEnd! > ref.verse
            ? '$book ${ref.chapter}:${ref.verse}-${ref.verseEnd}'
            : '$book ${ref.chapter}:${ref.verse}');
    return head;
  }
}

/// A run of result text, either matched or not.
class SearchSegment {
  const SearchSegment(this.text, {required this.matched});

  final String text;
  final bool matched;

  /// Whether the segment is worth rendering at all.
  ///
  /// A highlight that splits a word into an empty run would draw an empty box, and
  /// adjacent matched runs would render as two marks where one is meant.
  bool get isRenderable => text.isNotEmpty;
}

/// Marks the query terms inside a result's text.
///
/// Highlights are computed here rather than taken from FTS5's `highlight()` for two
/// reasons. The index only knows about the terms it retrieved, so a wildcard's matched
/// shape or a phrase inside a positional operator would be missing from its markers. And
/// `highlight()` returns HTML with `char(1)`/`char(2)` sentinels, which every caller then
/// has to parse — the same information as data, not as markup.
List<SearchSegment> highlight(String text, SearchNode query) {
  final terms = _literalTerms(query);
  if (terms.isEmpty || text.isEmpty) {
    return [SearchSegment(text, matched: false)];
  }
  return _segment(text, terms);
}

List<String> _literalTerms(SearchNode node) {
  final out = <String>[];
  void visit(SearchNode n) {
    if (n is SearchTerm) {
      out.add(LogosText.fold(n.raw));
    } else if (n is SearchPhrase) {
      out.add(LogosText.fold(n.text));
    } else if (n is SearchGroup) {
      visit(n.inner);
    } else if (n is SearchBinary) {
      visit(n.left);
      visit(n.right);
    }
  }

  visit(node);
  return [
    for (final t in out)
      if (t.isNotEmpty) t
  ];
}

/// Splits [text] into matched and unmatched runs.
///
/// Matching is done on the folded text and the offsets are mapped back, so a search for
/// `palabra` highlights `Palabra` and a search for `jesus` highlights `Jesús`. Walking the
/// folded string alone would not give usable offsets, because folding changes length.
List<SearchSegment> _segment(String text, List<String> terms) {
  final folded = LogosText.fold(text);

  // Fold one character of the original at a time, accumulating the folded index, so every
  // folded offset can be traced to an original one.
  final foldedToOriginal = List<int>.filled(folded.length + 1, 0);
  var f = 0;
  for (var o = 0; o < text.length; o++) {
    final piece = LogosText.fold(text[o]);
    for (var k = 0; k < piece.length; k++) {
      if (f < foldedToOriginal.length) foldedToOriginal[f] = o;
      f++;
    }
  }
  if (f < foldedToOriginal.length) foldedToOriginal[f] = text.length;
  foldedToOriginal[f] = text.length;

  final marks = List<bool>.filled(text.length, false);
  var any = false;
  for (final term in terms) {
    var from = 0;
    while (true) {
      final at = folded.indexOf(term, from);
      if (at < 0) break;
      final startOriginal = foldedToOriginal[at];
      final endOriginal = foldedToOriginal[at + term.length];
      for (var o = startOriginal; o < endOriginal && o < text.length; o++) {
        marks[o] = true;
      }
      any = true;
      from = at + 1;
    }
  }

  if (!any) return [SearchSegment(text, matched: false)];

  final out = <SearchSegment>[];
  var runStart = 0;
  for (var i = 1; i <= text.length; i++) {
    final atEnd = i == text.length;
    if (atEnd || marks[i] != marks[runStart]) {
      out.add(SearchSegment(
        text.substring(runStart, i),
        matched: marks[runStart],
      ));
      runStart = i;
    }
  }
  return out;
}
