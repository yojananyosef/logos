import '../../domain/models/catalog.dart';
import '../../domain/models/passage_ref.dart';
import '../../domain/search/search_matcher.dart';
import '../../domain/search/search_query.dart';
import '../../domain/search/search_results.dart';
import '../../domain/search/search_retrieval.dart';
import '../services/amf_reader.dart';
import 'bible_repository.dart';

/// Runs a parsed query against installed modules.
///
/// Two stages, and the split is the whole design:
///
/// 1. **Retrieval.** Each module's own FTS5 index is asked for candidates. This is fast and
///    exact for terms, phrases and boolean combinations, and it is the only stage that
///    touches the index.
/// 2. **Decision.** [SearchMatcher] decides each candidate against the parsed query, because
///    three documented operators — proximity, ordering and wildcard shapes — cannot be
///    expressed to FTS5 in this build at all. `NEAR` silently matches nothing and `?` is a
///    syntax error.
///
/// The alternative of trusting the index for everything would return correct results for
/// `Word Y God` and *no* results for `Word CERCA 5 God`, with nothing to tell the user the
/// second was a working query. The split costs one extra pass over a few hundred candidate
/// rows and buys an operator that behaves.
class SearchRepository {
  const SearchRepository(
    this._bible, {
    this.retrieval = const SearchRetrieval(),
    this.matcher = const SearchMatcher(),
  });

  final BibleRepository _bible;
  final SearchRetrieval retrieval;
  final SearchMatcher matcher;

  /// The most candidates fetched from any one module before deciding.
  ///
  /// A verse is short, so this is generous for scripture. An `entries` row of a commentary
  /// is a paragraph, so a wildcard-heavy query over one of those could exceed it — the
  /// results are then a prefix of the full set rather than a wrong answer, and the count
  /// reported alongside says so.
  static const candidateLimit = 200;

  /// Runs [query] across installed modules, restricted to [scope].
  Future<SearchRun> search(
    SearchNode query, {
    SearchScope scope = SearchScope.all,
    int limit = 50,
  }) async {
    final modules = await _searchableModules(scope);
    if (modules.isEmpty) {
      return SearchRun(results: const [], scope: scope, moduleCount: 0);
    }

    final results = <SearchResult>[];
    for (final module in modules) {
      // Fetched at the candidate limit rather than the display limit: the cap has to be
      // applied once, after merging, or the reported total is the size of the first
      // module's slice rather than the number of results that exist.
      results.addAll(await _searchModule(module, query, candidateLimit));
    }

    // Best first across modules. The index's own ordering is per-module, so merging
    // otherwise would present a whole module's results before another's.
    results.sort((a, b) => b.score.compareTo(a.score));

    return SearchRun(
      results: results.take(limit).toList(growable: false),
      scope: scope,
      moduleCount: modules.length,
      totalFound: results.length,
      truncated: results.length > limit,
    );
  }

  /// Runs [query] against one module.
  Future<List<SearchResult>> _searchModule(
    InstalledModule module,
    SearchNode query,
    int limit,
  ) async {
    final OpenedModule opened;
    try {
      opened = await _bible.open(module.id);
    } on Object {
      // A module that cannot be opened is skipped rather than failing the whole search.
      // One unreadable module must not make the user's other 30,000 verses unreachable.
      return const [];
    }

    final results = <SearchResult>[];

    // A reference query is positional, so it is answered by a direct read. Retrieval cannot
    // express it and the index has no rows to offer.
    final reference = _referenceOf(query);
    if (reference != null) {
      final rows = await _rowsForReference(opened, reference, query);
      for (final row in rows) {
        if (results.length >= limit) break;
        final ref = PassageRef(
          row.osisCode,
          row.chapter,
          row.verse,
          verseEnd: row.verseEnd,
        );
        if (!matcher.matches(query, row.text, reference: ref)) continue;
        results.add(_result(module, ref, row, query));
      }
      return results;
    }

    final match = retrieval.compile(query);
    if (match == null) {
      // No index expression could be built — a query made only of a wildcard with an empty
      // literal head, or a phrase that is nothing but quotes. Scanning every row is the
      // only honest option, and it is bounded by the module's own size.
      final all = await _allRows(opened);
      for (final row in all) {
        if (results.length >= limit) break;
        final ref =
            PassageRef(row.osisCode, row.chapter, row.verse, verseEnd: row.verseEnd);
        if (!matcher.matches(query, row.text, reference: ref)) continue;
        results.add(_result(module, ref, row, query));
      }
      return results;
    }

    final hits = await opened.dao.search(match, limit: candidateLimit);
    for (final hit in hits) {
      if (results.length >= limit) break;
      final ref =
          PassageRef(hit.osisCode, hit.chapter, hit.verse, verseEnd: hit.verseEnd);
      if (!matcher.matches(query, hit.text, reference: ref)) continue;
      results.add(_result(module, ref, hit, query));
    }
    return results;
  }

  SearchResult _result(
    InstalledModule module,
    PassageRef ref,
    AmfSearchHit hit,
    SearchNode query,
  ) =>
      SearchResult(
        moduleId: module.id,
        moduleName: module.name,
        reference: ref,
        bookName: hit.bookName,
        text: hit.text,
        segments: highlight(hit.text, query),
      );

  /// The reference a query names, if it is only a reference.
  ///
  /// A reference combined with other terms is a *constraint* on a text search, not a lookup,
  /// and is handled by the matcher during the text pass.
  SearchReference? _referenceOf(SearchNode node) {
    if (node is SearchReference) return node;
    if (node is SearchGroup) return _referenceOf(node.inner);
    return null;
  }

  Future<List<AmfSearchHit>> _rowsForReference(
    OpenedModule opened,
    SearchReference node,
    SearchNode query,
  ) async {
    final ref = node.reference;
    final rows = <AmfSearchHit>[];

    if (ref.verse <= 0) {
      // A whole chapter. The chapter reader filters on the chapter number, so this is one
      // read rather than a scan.
      final book = opened.books.where((b) => b.osisCode == ref.bookOsis).firstOrNull;
      if (book == null) return rows;
      final verses = await opened.dao.chapter(ref.bookOsis, ref.chapter);
      for (final v in verses) {
        rows.add(AmfSearchHit(
          osisCode: ref.bookOsis,
          bookName: book.name,
          bookOrder: book.bookOrder,
          chapter: v.chapter,
          verse: v.verse,
          verseEnd: v.verseEnd,
          text: v.text,
        ));
      }
      return rows;
    }

    final verses = await opened.dao.singleVerse(ref.bookOsis, ref.chapter, ref.verse);
    final book = opened.books.where((b) => b.osisCode == ref.bookOsis).firstOrNull;
    for (final v in verses) {
      rows.add(AmfSearchHit(
        osisCode: ref.bookOsis,
        bookName: book?.name ?? ref.bookOsis,
        bookOrder: book?.bookOrder ?? 0,
        chapter: v.chapter,
        verse: v.verse,
        verseEnd: v.verseEnd,
        text: v.text,
      ));
    }
    return rows;
  }

  /// Every row of a module, for a query the index cannot help with.
  ///
  /// Reached only by a query the index cannot express at all — a wildcard opening with `*`,
  /// or a phrase that is nothing but quote characters. It walks the module chapter by
  /// chapter, which is slow but correct; treating it as an error would be worse than slow,
  /// and pretending the index handled it would return nothing.
  Future<List<AmfSearchHit>> _allRows(OpenedModule opened) async {
    final rows = <AmfSearchHit>[];
    for (final book in opened.books) {
      for (var chapter = 1; chapter <= book.chapterCount; chapter++) {
        final verses = await opened.dao.chapter(book.osisCode, chapter);
        for (final v in verses) {
          rows.add(AmfSearchHit(
            osisCode: book.osisCode,
            bookName: book.name,
            bookOrder: book.bookOrder,
            chapter: v.chapter,
            verse: v.verse,
            verseEnd: v.verseEnd,
            text: v.text,
          ));
        }
      }
    }
    return rows;
  }

  /// The installed modules a scope covers.
  ///
  /// The scripture and non-scripture distinction is made on the resource type, not on
  /// whether a table exists. A commentary carries `entries` rather than `verses`, and the
  /// reader implemented so far addresses verses, so a commentary is searchable in the
  /// `Libros` scope by name but contributes no passages to `Biblia`.
  Future<List<InstalledModule>> _searchableModules(SearchScope scope) async {
    final installed = await _bible.listInstalled();
    return [
      for (final m in installed)
        if (_inScope(m, scope)) m,
    ];
  }

  bool _inScope(InstalledModule m, SearchScope scope) => switch (scope) {
        SearchScope.all => true,
        SearchScope.bible => m.type == ResourceType.bible,
        // Everything that is not scripture, which is what "Libros" means in the reference.
        SearchScope.books => m.type != ResourceType.bible,
      };
}

/// The outcome of one search.
class SearchRun {
  const SearchRun({
    required this.results,
    required this.scope,
    required this.moduleCount,
    this.totalFound = 0,
    this.truncated = false,
  });

  final List<SearchResult> results;
  final SearchScope scope;

  /// How many modules were searched, so the interface can say "in 2 modules".
  final int moduleCount;

  /// How many results were found before the limit was applied.
  final int totalFound;

  /// Whether more results exist than were shown.
  final bool truncated;

  bool get isEmpty => results.isEmpty;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
