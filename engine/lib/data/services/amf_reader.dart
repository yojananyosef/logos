import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// The AMF format constants, corrected against the original specification.
///
/// The upstream spec states `application_id = 1096035140`. That decimal is wrong;
/// `0x414D4F44` is `1095585604`. The upstream implementation used the correct value
/// and only the document was wrong, so this is a documentation fix, not a migration.
class AmfFormat {
  AmfFormat._();

  /// "AMOD" in ASCII.
  static const int applicationId = 0x414D4F44;
  static const int schemaVersionV1 = 1;
  static const int schemaVersionV1_1 = 2;

  static const String manifestEntry = 'manifest.json';
  static const String contentEntry = 'content.db';

  /// Reads the format's pragmas off a staged file.
  ///
  /// Read with the raw driver, and before drift is involved at all. Two reasons: drift's
  /// executor refuses to run anything until its owning database has opened it, so the
  /// validation would otherwise have to happen *after* the thing it exists to prevent;
  /// and reading `user_version` first lets drift open the module with a matching schema
  /// version, so it has no reason to attempt a migration on a file that must never be
  /// written.
  static AmfHeader readHeader(File staged) {
    final db = sqlite.sqlite3.open(staged.path, mode: sqlite.OpenMode.readOnly);
    try {
      final appId = db.select('PRAGMA application_id').first.values.first as int? ?? 0;
      final version = db.select('PRAGMA user_version').first.values.first as int? ?? 0;

      if (appId != applicationId) {
        throw AmfFormatException(
          'application_id is $appId, expected $applicationId (0x414D4F44 "AMOD")',
        );
      }
      if (version < schemaVersionV1) {
        throw AmfFormatException('unsupported user_version $version');
      }
      if (version > schemaVersionV1_1) {
        throw AmfFormatException(
          'module requires schemaVersion $version; this reader supports up to '
          '$schemaVersionV1_1. Update the application.',
        );
      }
      return AmfHeader(schemaVersion: version);
    } finally {
      db.dispose();
    }
  }
}

class AmfHeader {
  const AmfHeader({required this.schemaVersion});
  final int schemaVersion;
}

class AmfFormatException implements Exception {
  AmfFormatException(this.message);
  final String message;
  @override
  String toString() => 'AmfFormatException: $message';
}

/// Reads an installed `.amod`: verifies the hash, unpacks, and opens `content.db`
/// read-only.
///
/// The order matters and is the point of the format. Nothing touches the filesystem
/// until the bytes have been checked against the catalog's sha256, and the database is
/// not trusted until its `application_id` and `user_version` confirm the format.
class AmfModuleReader {
  AmfModuleReader({required this.expectedSha256});

  final String? expectedSha256;

  /// Files staged out of module bytes, removed by [dispose].
  final List<File> _staged = [];

  Future<AmfModuleDatabase> openFromFile(File file) async {
    if (!file.existsSync()) {
      throw AmfFormatException('module file not found: ${file.path}');
    }
    return openFromBytes(await file.readAsBytes());
  }

  Future<AmfModuleDatabase> openFromBytes(List<int> bytes) async {
    if (expectedSha256 != null) {
      final actual = sha256.convert(bytes).toString();
      if (actual != expectedSha256!.toLowerCase()) {
        throw AmfFormatException(
          'sha256 mismatch: expected $expectedSha256, got $actual',
        );
      }
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    for (final required in [AmfFormat.manifestEntry, AmfFormat.contentEntry]) {
      if (!names.contains(required)) {
        throw AmfFormatException('module is missing $required');
      }
    }

    final dbBytes = _read(archive, AmfFormat.contentEntry);
    // The manifest is read even though the catalog already carries this metadata: a
    // truncated archive must fail here rather than at first read.
    _read(archive, AmfFormat.manifestEntry);

    // drift opens a database from a file, so the bytes are staged to a temp file.
    // `query_only` opens it read-only with no journal, which is what AMF's
    // `journal_mode=DELETE` expects.
    final staged = File(
      '${Directory.systemTemp.path}/amod-${DateTime.now().microsecondsSinceEpoch}.db',
    )..writeAsBytesSync(dbBytes);
    _staged.add(staged);

    // Validate before opening, not after: a module with the wrong magic has to be
    // rejected before anything is able to query it.
    final header = AmfFormat.readHeader(staged);

    return AmfModuleDatabase(
      NativeDatabase(
        staged,
        setup: (raw) {
          raw
            ..execute('PRAGMA query_only = 1')
            ..execute('PRAGMA cache_size = -16000');
        },
      ),
      userVersion: header.schemaVersion,
    );
  }

  /// Removes staged temp databases. Safe to call more than once.
  void dispose() {
    for (final f in _staged) {
      if (f.existsSync()) f.deleteSync();
    }
    _staged.clear();
  }

  static List<int> _read(Archive archive, String name) {
    final file = archive.files.firstWhere((f) => f.name == name);
    if (file.isFile) return file.content as List<int>;
    throw AmfFormatException('$name is a directory, expected a file');
  }
}

/// A read-only drift database over a module.
///
/// drift requires an owning database before its executor will run anything, so a bare
/// `QueryExecutor` cannot be used on its own. This is the smallest thing that satisfies
/// that contract.
///
/// It declares no tables and no migrations, and is opened with `schemaVersion` equal to
/// the module's own `user_version`, so drift finds nothing to do and never attempts to
/// write. `query_only` on the connection is a second line of defence: a reader that could
/// modify installed content would corrupt it in a way no checksum would catch, because
/// the catalog's hash covers the archive and not the extracted file.
class AmfModuleDatabase extends GeneratedDatabase {
  AmfModuleDatabase(super.executor, {required int userVersion})
      : schemaVersion = userVersion;

  /// The module's declared `user_version`, which is also this database's version.
  ///
  /// Matching them is what keeps drift from attempting a migration: with no declared
  /// entities and no version drift there is nothing for it to do, so an installed module
  /// is never written to.

  @override
  final int schemaVersion;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy();
}

/// A row of a raw `SELECT`, addressed by column name.
class _Row {
  const _Row(this.values);
  final Map<String, Object?> values;
  T as<T>(String column) => values[column] as T;
}

/// Runs a raw `SELECT` and addresses the result by column name.
///
/// Uses drift's `customSelect` rather than the executor directly, so the query goes
/// through the same layer that owns the connection. That matters because the module
/// database is the thing that opened the file: bypassing it would mean running statements
/// against a connection the owner has not finished setting up.
Future<List<_Row>> _query(
  AmfModuleDatabase db,
  String sql, [
  List<Object?> args = const [],
]) async {
  final rows = await db
      .customSelect(sql, variables: [for (final a in args) Variable<Object>(a)]).get();
  return [
    for (final r in rows) _Row({for (final e in r.data.entries) e.key: e.value}),
  ];
}

/// Typed access to the tables an AMF bible module exposes.
///
/// Written against the schema in `format/AMF-SPEC.md` §3.2 so the SQL lives in one
/// place rather than being spread across the reader widgets.
class AmfBibleDao {
  AmfBibleDao(this._db);

  final AmfModuleDatabase _db;

  Future<List<AmfBook>> books() async {
    final rows = await _query(
      _db,
      'SELECT bookId, osisCode, name, abbreviation, testament, bookOrder, chapterCount '
      'FROM books ORDER BY bookOrder',
    );
    return rows
        .map((r) => AmfBook(
              bookId: r.as<int>('bookId'),
              osisCode: r.as<String>('osisCode'),
              name: r.as<String>('name'),
              abbreviation: r.as<String>('abbreviation'),
              testament: r.as<String>('testament'),
              bookOrder: r.as<int>('bookOrder'),
              chapterCount: r.as<int>('chapterCount'),
            ))
        .toList(growable: false);
  }

  /// One chapter of one book.
  ///
  /// Both are required. A query that filtered on the book alone would return the whole
  /// book, which is the kind of mistake that looks correct in a book with one chapter and
  /// silently renders every chapter as the first one everywhere else.
  Future<List<AmfVerse>> chapter(String osisCode, int chapter) async {
    final rows = await _query(
      _db,
      'SELECT v.chapter, v.verse, v.verseEnd, v.text FROM verses v '
      'JOIN books b ON b.bookId = v.bookId '
      'WHERE b.osisCode = ? AND v.chapter = ? ORDER BY v.verse',
      [osisCode, chapter],
    );
    return rows.map(_verse).toList(growable: false);
  }

  /// One verse, including verses that fall inside a stored span.
  ///
  /// USFM often writes several verses as one run of text under a range marker, so a
  /// module may carry the text of 35–36 as a single row numbered 35 with `verseEnd = 36`.
  /// Matching on `verse` alone would return nothing for 36 while its words are present
  /// and one line above, which is the worst outcome for a study application: the user
  /// is told the passage does not exist and cannot discover that it is on the screen.
  ///
  /// The row is returned with its own numbering, so a caller can see which entry actually
  /// holds the text.
  Future<List<AmfVerse>> singleVerse(
    String osisCode,
    int chapter,
    int verse,
  ) async {
    final rows = await _query(
      _db,
      'SELECT v.chapter, v.verse, v.verseEnd, v.text FROM verses v '
      'JOIN books b ON b.bookId = v.bookId '
      'WHERE b.osisCode = ? AND v.chapter = ? '
      '  AND (v.verse = ? OR (v.verseEnd IS NOT NULL AND v.verse < ? AND v.verseEnd >= ?)) '
      'ORDER BY v.verse',
      [osisCode, chapter, verse, verse, verse],
    );
    return rows.map(_verse).toList(growable: false);
  }

  AmfVerse _verse(_Row r) => AmfVerse(
        chapter: r.as<int>('chapter'),
        verse: r.as<int>('verse'),
        verseEnd: r.values['verseEnd'] as int?,
        text: r.as<String>('text'),
      );

  /// Whether this module carries cross-references at all.
  ///
  /// Feature detection rather than an assumption, because the table was added after the
  /// first modules were built and a module predating it is a normal thing to have
  /// installed. Asking `sqlite_master` costs one indexed lookup and turns "this module has
  /// no references" into an empty list instead of a `no such table` error on every chapter.
  Future<bool> get hasCrossReferences async {
    final rows = await _query(
      _db,
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'crossReferences'",
    );
    return rows.isNotEmpty;
  }

  /// Every cross-reference anchored in one chapter, grouped by verse and then by phrase.
  ///
  /// The whole chapter in one query, because that is the unit the reader shows: opening a
  /// chapter should not issue a query per verse, and a reader that did would be visibly
  /// slower on John 1 than on Obadiah for no reason the user could explain.
  Future<Map<int, List<AmfAnchoredReferences>>> chapterCrossReferences(
    String osisCode,
    int chapter,
  ) async {
    if (!await hasCrossReferences) return const {};

    final rows = await _query(
      _db,
      'SELECT x.fromBookId, x.fromChapter, x.fromVerse, x.toBookId, x.toChapter, '
      '       x.toVerse, x.toVerseEnd, x.anchor, x.sortOrder '
      'FROM crossReferences x '
      'JOIN books b ON b.bookId = x.fromBookId '
      'WHERE b.osisCode = ? AND x.fromChapter = ? '
      'ORDER BY x.fromVerse, x.sortOrder',
      [osisCode, chapter],
    );

    // Keyed by verse, then by anchor, preserving the order rows arrive in. A `Map` alone
    // would lose the source order of two anchors in the same verse, and the reference shows
    // them in the order the translator's source did.
    final byVerse = <int, List<AmfAnchoredReferences>>{};
    final anchorsByVerse = <int, Map<String, List<AmfCrossReference>>>{};

    for (final r in rows) {
      final ref = AmfCrossReference(
        fromBookId: r.as<int>('fromBookId'),
        fromChapter: r.as<int>('fromChapter'),
        fromVerse: r.as<int>('fromVerse'),
        toBookId: r.as<int>('toBookId'),
        toChapter: r.as<int>('toChapter'),
        toVerse: r.as<int>('toVerse'),
        toVerseEnd: r.values['toVerseEnd'] as int?,
        anchor: r.as<String>('anchor'),
        sortOrder: r.as<int>('sortOrder'),
      );
      final verse = ref.fromVerse;
      final groups = anchorsByVerse.putIfAbsent(verse, () => <String, List<AmfCrossReference>>{});
      groups.putIfAbsent(ref.anchor, () => []).add(ref);
    }

    // Converted only once every group is filled. Building the list as rows arrive would
    // capture the first anchor's group and then never add the second, so a verse with two
    // anchored phrases would silently render one of them.
    for (final entry in anchorsByVerse.entries) {
      byVerse[entry.key] = [
        for (final group in entry.value.entries)
          AmfAnchoredReferences(anchor: group.key, references: group.value),
      ];
    }

    return byVerse;
  }

  /// Every cross-reference in the module, for the build-time target check.
  Future<List<AmfCrossReference>> allCrossReferences() async {
    if (!await hasCrossReferences) return const [];
    final rows = await _query(_db, CrossReferenceSchema.selectAll);
    return [
      for (final r in rows)
        AmfCrossReference(
          fromBookId: r.as<int>('fromBookId'),
          fromChapter: r.as<int>('fromChapter'),
          fromVerse: r.as<int>('fromVerse'),
          toBookId: r.as<int>('toBookId'),
          toChapter: r.as<int>('toChapter'),
          toVerse: r.as<int>('toVerse'),
          toVerseEnd: r.values['toVerseEnd'] as int?,
          anchor: r.as<String>('anchor'),
          // `selectAll` omits `sortOrder`; the integrity check does not care where a
          // reference sat in the verse, only that it points somewhere real.
          sortOrder: 0,
        ),
    ];
  }

  /// FTS5 search over a module.
  ///
  /// The tokeniser is `unicode61 remove_diacritics 2`, so a query finds a verse whether
  /// or not the text carries diacritics. That is the reason the format chose it: a
  /// Spanish module must be searchable by `Jesus` as well as by `Jesús`, and a
  /// default tokeniser would only answer to whichever form the user happened to type.
  ///
  /// Verified against a real module: `Jesus` returns Matt 1:1.
  ///
  /// `verses_fts` is an external-content table, so its `rowid` is `verses.rowid`; the
  /// join has to go through that rather than through a shared key.
  /// Runs [query] against the module's own index.
  ///
  /// [query] is a raw FTS5 `MATCH` expression, not a user query. The user's query has
  /// already been parsed into a tree, and this is the retrieval half of evaluating it —
  /// the part the index is genuinely good at, which is narrowing 31,000 verses to a few
  /// hundred candidates.
  ///
  /// The caller then applies [SearchMatcher] to the returned text. The two halves are not
  /// redundant: the index cannot express proximity, ordering or wildcard shapes, so a
  /// result that satisfies the index is not yet a result that satisfies the query.
  ///
  /// FTS5 has no `NEAR` in this build — `a NEAR b` parses and matches nothing — and no `?`
  /// at all, where `cr?st` is a syntax error. [buildMatchExpression] is what keeps those
  /// out of the string handed to the engine.
  Future<List<AmfSearchHit>> search(String query, {int limit = 200}) async {
    if (query.trim().isEmpty) return const [];
    final rows = await _query(
      _db,
      'SELECT b.osisCode, b.name AS bookName, b.bookOrder, v.chapter, v.verse, '
      '       v.verseEnd, v.text '
      'FROM verses_fts '
      'JOIN verses v ON v.rowid = verses_fts.rowid '
      'JOIN books b ON b.bookId = v.bookId '
      'WHERE verses_fts MATCH ? ORDER BY rank LIMIT ?',
      [query, limit],
    );
    return [
      for (final r in rows)
        AmfSearchHit(
          osisCode: r.as<String>('osisCode'),
          bookName: r.as<String>('bookName'),
          bookOrder: r.as<int>('bookOrder'),
          chapter: r.as<int>('chapter'),
          verse: r.as<int>('verse'),
          verseEnd: r.values['verseEnd'] as int?,
          text: r.as<String>('text'),
        ),
    ];
  }
}

class AmfBook {
  const AmfBook({
    required this.bookId,
    required this.osisCode,
    required this.name,
    required this.abbreviation,
    required this.testament,
    required this.bookOrder,
    required this.chapterCount,
  });

  final int bookId;
  final String osisCode;
  final String name;
  final String abbreviation;
  final String testament;
  final int bookOrder;
  final int chapterCount;
}

class AmfVerse {
  const AmfVerse({
    required this.chapter,
    required this.verse,
    required this.text,
    this.verseEnd,
  });

  final int chapter;
  final int verse;
  final int? verseEnd;
  final String text;
}

/// One row a module's index returned, with the whole text rather than a snippet.
///
/// The full text is fetched because the caller has to measure positions in it: proximity
/// and ordering cannot be decided from a snippet, and highlighting needs the matched words
/// to be in context. Verses are short enough that this costs nothing over a snippet, and
/// an `entries` row of a commentary is a paragraph at worst.
class AmfSearchHit {
  const AmfSearchHit({
    required this.osisCode,
    required this.bookName,
    required this.bookOrder,
    required this.chapter,
    required this.verse,
    required this.text,
    this.verseEnd,
  });

  final String osisCode;
  final String bookName;

  /// The book's canonical position in the canon.
  ///
  /// Carried because a result list has to be in reading order, and `osisCode` sorted as a
  /// string puts Genesis before John and Psalms after both — `Gen` < `John` < `Ps` happens to
  /// be right, but `Exod` < `Gen` < `Isa` < `John` is not, and a search that returns John
  /// before Exodus is not something a reader of scripture can follow.
  final int bookOrder;

  final int chapter;
  final int verse;
  final int? verseEnd;
  final String text;
}

/// The `crossReferences` table, as the reader and every builder create it.
///
/// Kept as one string so the reader, the test fixture builder and the catalog repository's
/// assembler cannot drift: the table is what a link is read out of, and three copies of the
/// DDL would eventually be three slightly different tables, with the mismatch showing up as
/// a missing link rather than as an error.
///
/// `IF NOT EXISTS` because a module may legitimately have none, and `anchor` is required
/// because a reference with nothing to attach it to cannot be rendered in place.
class CrossReferenceSchema {
  const CrossReferenceSchema._();

  static const String create = '''
CREATE TABLE IF NOT EXISTS crossReferences (
  fromBookId INTEGER NOT NULL,
  fromChapter INTEGER NOT NULL,
  fromVerse INTEGER NOT NULL,
  toBookId INTEGER NOT NULL,
  toChapter INTEGER NOT NULL,
  toVerse INTEGER NOT NULL,
  toVerseEnd INTEGER,
  anchor TEXT NOT NULL,
  sortOrder INTEGER NOT NULL
)''';

  /// On the *source* verse, because that is how a chapter is read: every reference the
  /// chapter holds, fetched in one query, ordered by where it falls in the verse.
  static const String index =
      'CREATE INDEX IF NOT EXISTS crossReferences_from ON '
      'crossReferences (fromBookId, fromChapter, fromVerse)';

  /// Every reference in a module, for the build-time check that each target exists.
  static const String selectAll = 'SELECT fromBookId, fromChapter, fromVerse, '
      'toBookId, toChapter, toVerse, toVerseEnd, anchor FROM crossReferences '
      'ORDER BY fromBookId, fromChapter, fromVerse, sortOrder';
}

/// One cross-reference as a module stores it: a phrase in a verse, and a passage it points
/// at.
///
/// Phrase-level rather than verse-level, because that is what the source data is. TSK gives
/// every reference a phrase it hangs off, so `John 1:1` "Word" and the same verse's "with
/// God" are different references to different passages. Storing one row per verse would
/// throw that away and leave the reader guessing where to draw the link.
class AmfCrossReference {
  const AmfCrossReference({
    required this.fromBookId,
    required this.fromChapter,
    required this.fromVerse,
    required this.toBookId,
    required this.toChapter,
    required this.toVerse,
    required this.anchor,
    this.toVerseEnd,
    required this.sortOrder,
  });

  final int fromBookId;
  final int fromChapter;
  final int fromVerse;
  final int toBookId;
  final int toChapter;
  final int toVerse;
  final int? toVerseEnd;

  /// The phrase this reference follows, in the module's own text.
  final String anchor;

  /// Position among the references sharing this anchor, so the reader can render them in
  /// the order the source listed them rather than in whatever order SQLite returns.
  final int sortOrder;
}

/// The cross-references of one verse, grouped by the phrase they hang off.
///
/// The reader draws a link per phrase, not per reference: `Prov 8:22; Mark 13:19` after
/// "beginning" is one visible marker that goes to two passages, which is how the reference
/// presents it. Splitting them into two separate markers would put two link-coloured
/// fragments in the middle of a sentence for no gain the reader can act on.
class AmfAnchoredReferences {
  const AmfAnchoredReferences({required this.anchor, required this.references});

  final String anchor;
  final List<AmfCrossReference> references;
}

/// Verifies that every chapter in a module is contiguous 1..N with no duplicates and
/// no gaps.
///
/// This is the check the upstream catalog was missing. Its end-to-end test read
/// Genesis 1:1, which is in the Old Testament and was unaffected, so a systematic
/// New Testament defect — 260 chapters with no verse 1, including John 1:1 — reached
/// users unnoticed. Verse-level navigation makes this a correctness requirement, not a
/// nicety.
class AmfIntegrityChecker {
  const AmfIntegrityChecker();

  Future<IntegrityReport> check(AmfModuleDatabase db) async {
    final dao = AmfBibleDao(db);
    final rows = await _query(
      db,
      'SELECT b.osisCode AS osis, v.chapter AS chapter, v.verse AS verse, '
      '       v.verseEnd AS verseEnd '
      'FROM verses v JOIN books b ON b.bookId = v.bookId '
      'ORDER BY b.bookOrder, v.chapter, v.verse',
    );

    // Each entry records the verse a row starts at and the last verse it covers. Those
    // are the same number unless the row stores a span, which is the difference between a
    // correct build and the upstream defect.
    final chapters = <String, List<({int from, int to})>>{};
    var total = 0;
    for (final r in rows) {
      total++;
      final verse = r.as<int>('verse');
      chapters
          .putIfAbsent('${r.as<String>('osis')}:${r.as<int>('chapter')}', () => [])
          .add((from: verse, to: r.values['verseEnd'] as int? ?? verse));
    }

    final failures = <IntegrityFailure>[];
    chapters.forEach((key, entries) {
      if (entries.isEmpty) return;
      final sorted = [...entries]..sort((a, b) => a.from.compareTo(b.from));
      if (sorted.first.from != 1) {
        failures.add(IntegrityFailure(
          key,
          'starts at verse ${sorted.first.from}, expected 1',
        ));
        return;
      }
      for (var i = 1; i < sorted.length; i++) {
        // A row storing 35-36 is followed by 37, not 36, so the expected next verse is
        // one past whatever the previous row *covers*. Comparing against `verse + 1`
        // reports every correctly-built range as a gap, which is how a sound module gets
        // flagged as defective.
        final expected = sorted[i - 1].to + 1;
        if (sorted[i].from != expected) {
          failures.add(IntegrityFailure(
            key,
            'gap between verse ${sorted[i - 1].to} and ${sorted[i].from}',
          ));
          return;
        }
      }
    });

    // A cross-reference pointing at a verse the module does not contain is a link that goes
    // nowhere, and it is invisible until someone follows it — which is the worst moment to
    // discover a build mistake. Checked here rather than trusted from the source.
    //
    // `chapters` is already keyed `osis:chapter`, so a target's chapter is checked against
    // the same set the verse-contiguity check just built.
    if (await dao.hasCrossReferences) {
      final osisByBookId = <int, String>{
        for (final b in await dao.books()) b.bookId: b.osisCode,
      };

      final dangling = <String>[];
      for (final ref in await dao.allCrossReferences()) {
        final from = osisByBookId[ref.fromBookId];
        final to = osisByBookId[ref.toBookId];
        if (from == null || to == null) {
          dangling.add('references a book id the module does not declare '
              '(${ref.fromBookId} -> ${ref.toBookId})');
          continue;
        }
        if (!chapters.containsKey('$to:${ref.toChapter}')) {
          dangling.add('$from ${ref.fromChapter}:${ref.fromVerse} points at '
              '${ref.toChapter}:${ref.toVerse} in $to, which the module does not contain');
        }
      }
      if (dangling.isNotEmpty) {
        failures.add(IntegrityFailure(
          'crossReferences',
          '${dangling.length} of them point outside the module. '
              'The first is: ${dangling.first}',
        ));
      }
    }

    return IntegrityReport(
      chaptersChecked: chapters.length,
      versesChecked: total,
      failures: failures,
    );
  }
}

class IntegrityFailure {
  const IntegrityFailure(this.chapterKey, this.reason);
  final String chapterKey;
  final String reason;
  @override
  String toString() => '$chapterKey: $reason';
}

class IntegrityReport {
  const IntegrityReport({
    required this.chaptersChecked,
    required this.versesChecked,
    required this.failures,
  });

  final int chaptersChecked;
  final int versesChecked;
  final List<IntegrityFailure> failures;

  bool get isValid => failures.isEmpty;
}
