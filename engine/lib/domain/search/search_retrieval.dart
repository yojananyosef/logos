import 'logos_text.dart';
import 'search_query.dart';

/// Compiles a parsed query into an FTS5 `MATCH` expression.
///
/// The point of this class is to keep three engine quirks in one place rather than spread
/// through the query language, because each one produces a *silently wrong* answer rather
/// than an error:
///
/// - `NEAR` parses and matches nothing. On SQLite 3.53.4, `Word NEAR beginning` returns 0
///   rows in a table containing `Word beginning`, while `"Word beginning"` returns 1. So
///   proximity is never emitted; it is decided afterwards by `SearchMatcher`.
/// - `?` is a syntax error. `cr?st` is rejected outright, so a wildcard containing `?` is
///   retrieved by its literal prefix and filtered afterwards.
/// - A leading `-term` is read as a column name, not a negation ("no such column").
///   Exclusion is emitted as the `NOT` operator, which works.
///
/// A null result means "the index cannot help here" — a proximity-only query still has to
/// retrieve something, and it does so with the terms the query requires.
class SearchRetrieval {
  const SearchRetrieval();

  /// The `MATCH` string for [node], or null when no index query can help.
  String? compile(SearchNode node) => _compile(node);

  String? _compile(SearchNode node) {
    if (node is SearchTerm) {
      if (node.hasWildcard) {
        final head = _literalHead(node.raw);
        // An empty head means the pattern opens with a wildcard, which is a match-all.
        // Returning null lets the caller fall back to scanning, rather than emitting a
        // query the engine would reject.
        return head.isEmpty ? null : '$head*';
      }
      return _quote(LogosText.fold(node.raw));
    }

    if (node is SearchPhrase) {
      return _quotePhrase(node.text);
    }

    if (node is SearchGroup) {
      return _compile(node.inner);
    }

    if (node is SearchBinary) {
      return _binary(node);
    }

    // A reference is positional, not textual: the index has no way to answer "is this row
    // John 3:16", so retrieval falls through to a direct lookup.
    return null;
  }

  String? _binary(SearchBinary node) {
    final left = _compile(node.left);
    final right = _compile(node.right);

    switch (node.operator) {
      case SearchOperator.either:
        if (left == null && right == null) return null;
        if (left == null) return right;
        if (right == null) return left;
        return '($left OR $right)';

      case SearchOperator.both:
        if (left == null) return right;
        if (right == null) return left;
        return '($left AND $right)';

      case SearchOperator.excluding:
        // `a NOT b` needs a positive left operand. With only a right operand there is
        // nothing to exclude from, so there is nothing to retrieve.
        if (left == null) return null;
        if (right == null) return left;
        return '($left NOT $right)';

      case SearchOperator.before:
      case SearchOperator.after:
      case SearchOperator.near:
      case SearchOperator.withinWords:
      case SearchOperator.withinChars:
        // These need positions. Retrieve on what the query *requires* — both operands
        // must be present for the operator to be satisfiable — and let the matcher decide
        // the actual constraint. FTS5's own NEAR is not used because it matches nothing.
        if (left == null) return right;
        if (right == null) return left;
        return '($left AND $right)';
    }
  }

  /// The literal text before the first wildcard character.
  static String _literalHead(String pattern) {
    final stop = pattern.indexOf(RegExp(r'[*?]'));
    final head = stop < 0 ? pattern : pattern.substring(0, stop);
    return LogosText.fold(head);
  }

  /// Quotes a term so FTS5 treats it as one token.
  ///
  /// A bare word would be reinterpreted as query syntax, so `NOT`, `OR` and `AND` typed as
  /// search terms — all plausible things to look for in scripture — would either be
  /// swallowed as operators or rejected. Double quotes make them literals.
  static String _quote(String term) => '"${term.replaceAll('"', '""')}"';

  /// Wraps a phrase in double quotes, or null when nothing is left to quote.
  ///
  /// FTS5 phrase syntax has no escape for a quote inside a phrase, so a phrase containing
  /// one has that quote replaced by a space. Losing a quote narrows the result; a syntax
  /// error would discard it entirely.
  static String? _quotePhrase(String phrase) {
    final cleaned = phrase.replaceAll('"', ' ').trim();
    if (cleaned.isEmpty) return null;
    return '"$cleaned"';
  }
}
