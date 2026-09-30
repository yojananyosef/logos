import '../models/passage_ref.dart';
import 'logos_text.dart';

/// A parsed search query.
///
/// The grammar is the one the reference documents, and every node here corresponds to
/// something the help panel shows. The tree is built before any module is touched, so a
/// query that cannot be understood fails in a millisecond instead of after an index scan.
sealed class SearchNode {
  const SearchNode();

  /// The terms this node requires to be present, in the order they appear.
  ///
  /// Used to highlight results. A phrase contributes one entry; a wildcard contributes
  /// its pattern.
  List<String> get highlightTerms => const [];

  /// Whether this node can be answered by the module's index alone.
  ///
  /// False for anything needing word or character positions, which the index cannot supply
  /// — FTS5's `NEAR` operator parses without error and matches nothing in SQLite 3.53.4,
  /// so proximity has to be measured here instead of delegated.
  bool get indexable => true;
}

/// A single word, possibly containing wildcards.
class SearchTerm extends SearchNode {
  const SearchTerm(this.raw);

  /// Exactly what the user typed, minus quotes.
  final String raw;

  bool get hasWildcard => raw.contains('*') || raw.contains('?');

  TermMatcher get matcher =>
      hasWildcard ? WildcardTermMatcher(raw) : ExactTermMatcher(LogosText.fold(raw));

  @override
  List<String> get highlightTerms => [raw];

  @override
  bool get indexable => !hasWildcard;
}

/// A phrase in double quotes. Matched exactly, in order.
class SearchPhrase extends SearchNode {
  const SearchPhrase(this.text);

  final String text;

  @override
  List<String> get highlightTerms => [text];
}

/// `Biblia:"Jn 3:16"` or `Biblia:="Juan 3"`.
class SearchReference extends SearchNode {
  const SearchReference(this.reference, {this.exact = false});

  final PassageRef reference;

  /// True for the `=` form, which requires the passage itself rather than a superset.
  ///
  /// `Biblia:"Juan 3"` finds the whole chapter; `Biblia:="Juan 3"` finds only what is
  /// exactly that chapter, which excludes verses that merely mention it.
  final bool exact;

  @override
  bool get indexable => false;
}

/// Any operator the reference documents.
enum SearchOperator {
  /// `O` — either term.
  either('O', 'una palabra u otra'),

  /// `Y` — both terms. Two adjacent words mean the same thing.
  both('Y', 'ambas palabras'),

  /// `NO` — the first term but not the second.
  excluding('NO', 'una palabra, pero no la otra'),

  /// `ANTES` — the first occurs before the second.
  before('ANTES', 'una palabra antes que otra'),

  /// `DESPUÉS` — the first occurs after the second.
  after('DESPUES', 'una palabra después de otra'),

  /// `CERCA` — the terms are near each other, within an optional word count.
  near('CERCA', 'una palabra cerca de otra'),

  /// `DENTRO n PALABRAS` — within n words.
  withinWords('DENTRO', 'dentro de n palabras'),

  /// `DENTRO n CARACT` — within n characters.
  withinChars('CARACT', 'dentro de n caracteres');

  const SearchOperator(this.keyword, this.description);

  /// The upper-case keyword, as the user types it.
  final String keyword;

  /// The reference's own wording for this row of the help panel.
  final String description;

  /// How far apart two terms may be, for the operators that take a distance.
  bool get takesDistance =>
      this == SearchOperator.near ||
      this == SearchOperator.withinWords ||
      this == SearchOperator.withinChars;

  /// The default distance for `CERCA` when the user gives none.
  ///
  /// Matches FTS5's own `NEAR` default. Chosen because the help panel shows bare
  /// `Cristo CERCA Jesús`, so the no-number form has to mean something specific.
  static const defaultDistance = 10;

  /// Parses a keyword, accepting the accented and unaccented spellings.
  ///
  /// `DESPUES` in the spec and `DESPUÉS` in the interface are the same operator; a user
  /// who types either must get results rather than a syntax error.
  static SearchOperator? tryParse(String word) {
    final upper = word.toUpperCase();
    for (final op in SearchOperator.values) {
      if (op.keyword == upper) return op;
    }
    if (upper == 'DESPUÉS') return SearchOperator.after;
    return null;
  }
}

/// A binary operator applied to two nodes.
class SearchBinary extends SearchNode {
  const SearchBinary(this.operator, this.left, this.right, {this.distance});

  final SearchOperator operator;
  final SearchNode left;
  final SearchNode right;

  /// The word or character distance, for operators that take one.
  final int? distance;

  @override
  List<String> get highlightTerms => [...left.highlightTerms, ...right.highlightTerms];

  /// Proximity and ordering need positions, which the index does not supply.
  @override
  bool get indexable =>
      left.indexable &&
      right.indexable &&
      operator != SearchOperator.before &&
      operator != SearchOperator.after &&
      operator != SearchOperator.near &&
      operator != SearchOperator.withinWords &&
      operator != SearchOperator.withinChars;
}

/// A parenthesised group, kept so `(` and `)` survive into the tree.
///
/// Evaluation treats a group as its contents; the node exists to make an error message
/// able to point at the offending bracket.
class SearchGroup extends SearchNode {
  const SearchGroup(this.inner);

  final SearchNode inner;

  @override
  List<String> get highlightTerms => inner.highlightTerms;

  @override
  bool get indexable => inner.indexable;
}

/// A query that could not be understood.
class SearchSyntaxException implements Exception {
  const SearchSyntaxException(this.message, {this.operator, this.position});

  final String message;

  /// The operator or keyword at fault, when there is one.
  ///
  /// Reported separately from [message] so the interface can point at the token rather
  /// than only describing it in a sentence. A user who typed `CERKCA` needs to be told
  /// which word was wrong, not just that something was.
  final String? operator;

  /// Where in the query the problem is, when known.
  final int? position;

  @override
  String toString() => message;
}

/// Which content a search covers.
enum SearchScope {
  /// Everything installed: scripture and books.
  all('Todo'),

  /// Scripture only.
  bible('Biblia'),

  /// Non-scripture resources only.
  books('Libros');

  const SearchScope(this.label);

  /// The tab label, as the reference shows it.
  final String label;
}
