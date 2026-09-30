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
  Future<List<AmfSearchHit>> search(String query, {int limit = 50}) async {
    final rows = await _query(
      _db,
      "SELECT b.osisCode, v.chapter, v.verse, "
      "       snippet(verses_fts, 0, char(1), char(2), char(3), 12) AS snip "
      "FROM verses_fts "
      "JOIN verses v ON v.rowid = verses_fts.rowid "
      "JOIN books b ON b.bookId = v.bookId "
      "WHERE verses_fts MATCH ? ORDER BY rank LIMIT ?",
      [query, limit],
    );
    return rows
        .map((r) => AmfSearchHit(
              osisCode: r.as<String>('osisCode'),
              chapter: r.as<int>('chapter'),
              verse: r.as<int>('verse'),
              snippet: (r.values['snip'] as String?) ?? '',
            ))
        .toList(growable: false);
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

class AmfSearchHit {
  const AmfSearchHit({
    required this.osisCode,
    required this.chapter,
    required this.verse,
    required this.snippet,
  });

  final String osisCode;
  final int chapter;
  final int verse;
  final String snippet;
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
