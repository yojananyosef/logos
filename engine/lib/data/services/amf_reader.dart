import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

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

  /// Reads the format's SQLite pragmas off an open connection.
  static Future<AmfHeader> readHeader(QueryExecutor db) async {
    final appId = await _pragmaInt(db, 'PRAGMA application_id');
    final version = await _pragmaInt(db, 'PRAGMA user_version');

    if (appId != applicationId) {
      throw AmfFormatException(
        'application_id is $appId, expected $applicationId (0x414D4F44 "AMOD")',
      );
    }
    if (version < schemaVersionV1) {
      throw AmfFormatException('unsupported user_version $version');
    }
    return AmfHeader(schemaVersion: version);
  }

  static Future<int> _pragmaInt(QueryExecutor db, String pragma) async {
    final rows = await db.runSelect(pragma, const []);
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    return v is int ? v : 0;
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

  Future<QueryExecutor> openFromFile(File file) async {
    if (!file.existsSync()) {
      throw AmfFormatException('module file not found: ${file.path}');
    }
    return openFromBytes(await file.readAsBytes());
  }

  Future<QueryExecutor> openFromBytes(List<int> bytes) async {
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

    final executor = NativeDatabase(
      staged,
      setup: (raw) {
        raw
          ..execute('PRAGMA query_only = 1')
          ..execute('PRAGMA cache_size = -16000');
      },
    );

    final header = await AmfFormat.readHeader(executor);
    if (header.schemaVersion > AmfFormat.schemaVersionV1_1) {
      throw AmfFormatException(
        'module requires schemaVersion ${header.schemaVersion}; '
        'this reader supports up to ${AmfFormat.schemaVersionV1_1}. Update the app.',
      );
    }
    return executor;
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

/// A row of a raw `SELECT`, addressed by column name.
class _Row {
  const _Row(this.values);
  final Map<String, Object?> values;
  T as<T>(String column) => values[column] as T;
}

Future<List<_Row>> _query(
  QueryExecutor db,
  String sql, [
  List<Object?> args = const [],
]) async {
  final rows = await db.runSelect(sql, args);
  return rows.map((r) => _Row(Map<String, Object?>.from(r))).toList(growable: false);
}

/// Typed access to the tables an AMF bible module exposes.
///
/// Written against the schema in `format/AMF-SPEC.md` §3.2 so the SQL lives in one
/// place rather than being spread across the reader widgets.
class AmfBibleDao {
  AmfBibleDao(this._db);

  final QueryExecutor _db;

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

  Future<List<AmfVerse>> chapter(String osisCode) async {
    final rows = await _query(
      _db,
      'SELECT v.chapter, v.verse, v.verseEnd, v.text FROM verses v '
      'JOIN books b ON b.bookId = v.bookId '
      'WHERE b.osisCode = ? ORDER BY v.chapter, v.verse',
      [osisCode],
    );
    return rows.map(_verse).toList(growable: false);
  }

  Future<List<AmfVerse>> singleVerse(
    String osisCode,
    int chapter,
    int verse,
  ) async {
    final rows = await _query(
      _db,
      'SELECT v.chapter, v.verse, v.verseEnd, v.text FROM verses v '
      'JOIN books b ON b.bookId = v.bookId '
      'WHERE b.osisCode = ? AND v.chapter = ? AND v.verse = ?',
      [osisCode, chapter, verse],
    );
    return rows.map(_verse).toList(growable: false);
  }

  AmfVerse _verse(_Row r) => AmfVerse(
        chapter: r.as<int>('chapter'),
        verse: r.as<int>('verse'),
        verseEnd: r.values['verseEnd'] as int?,
        text: r.as<String>('text'),
      );

  /// FTS5 search over a module. The tokeniser is `unicode61 remove_diacritics 2`, so
  /// `Jesus` finds `Jesús` — the reason the format chose that tokeniser.
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

  Future<IntegrityReport> check(QueryExecutor db) async {
    final rows = await _query(
      db,
      'SELECT b.osisCode AS osis, v.chapter AS chapter, v.verse AS verse '
      'FROM verses v JOIN books b ON b.bookId = v.bookId '
      'ORDER BY b.bookOrder, v.chapter, v.verse',
    );

    final chapters = <String, List<int>>{};
    var total = 0;
    for (final r in rows) {
      total++;
      chapters
          .putIfAbsent('${r.as<String>('osis')}:${r.as<int>('chapter')}', () => [])
          .add(r.as<int>('verse'));
    }

    final failures = <IntegrityFailure>[];
    chapters.forEach((key, verses) {
      if (verses.isEmpty) return;
      final sorted = [...verses]..sort();
      if (sorted.first != 1) {
        failures.add(IntegrityFailure(key, 'starts at verse ${sorted.first}, expected 1'));
        return;
      }
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i] != sorted[i - 1] + 1) {
          failures.add(IntegrityFailure(
            key,
            'gap between verse ${sorted[i - 1]} and ${sorted[i]}',
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
