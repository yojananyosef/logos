import 'dart:io';

import 'package:archive/archive.dart';
// sqlite3 directly, not drift: this is a fixture, not application code, and drift's
// executor requires an owning database to open it. Building the file with the same
// engine the reader will open it with is also a fairer test.
import 'package:sqlite3/sqlite3.dart';

/// Builds a real AMF module on disk, so the tests exercise the actual format rather than
/// a stand-in for it.
///
/// A hand-built stub would pass while the real reader failed: the reader verifies an
/// `application_id`, unpacks a zip, opens SQLite and joins against an external-content
/// FTS5 index. None of that is exercised by a mock, and all of it is exactly where a
/// format implementation goes wrong.
class ModuleBuilder {
  ModuleBuilder(this.id, {this.name = 'Test Bible', this.type = 'bible'});

  final String id;
  final String name;

  /// The resource type the manifest declares.
  ///
  /// Set to `commentary` or another non-scripture type to exercise the scope rules. A
  /// commentary carries `entries` rather than `verses` in the real format; this builder
  /// always writes verses, so a non-scripture fixture exercises *scoping*, not the
  /// monograph reader, which is not implemented.
  final String type;

  /// `book:chapter:verse` entries keyed by OSIS code, in the order they should appear.
  final Map<String, Map<int, Map<int, String>>> books =
      <String, Map<int, Map<int, String>>>{};

  void addVerse(String osis, int chapter, int verse, String text) {
    books
        .putIfAbsent(osis, () => <int, Map<int, String>>{})
        .putIfAbsent(chapter, () => <int, String>{})[verse] = text;
  }

  /// Adds one entry spanning several verses, the way USFM writes a range.
  ///
  /// [text] covers every verse from [firstVerse] to [lastVerse] and is stored under
  /// [firstVerse] with `verseEnd` set, which is what a correct build does. The upstream
  /// catalog does the same but leaves `verseEnd` NULL, which loses the addressing.
  void addVerseRange(
    String osis,
    int chapter,
    int firstVerse,
    int lastVerse,
    String text,
  ) {
    // Ensure the book exists: a chapter that holds only a span has no entry in `books`,
    // and without one the span would never be written.
    books.putIfAbsent(osis, () => <int, Map<int, String>>{});
    books[osis]!.putIfAbsent(chapter, () => <int, String>{});
    spans
        .putIfAbsent('$osis:$chapter', () => [])
        .add((first: firstVerse, last: lastVerse, text: text));
  }

  /// Ranges to be written, keyed by `book:chapter`.
  final Map<String, List<({int first, int last, String text})>> spans =
      <String, List<({int first, int last, String text})>>{};

  /// Adds a chapter whose verses start at [firstVerse] rather than 1.
  ///
  /// Used to reproduce the upstream defect on purpose: a module missing verse 1, which
  /// is what the KJV and ASV modules of the upstream catalog actually contain.
  void addChapterStartingAt(String osis, int chapter, int firstVerse) {
    for (var v = firstVerse; v < firstVerse + 3; v++) {
      addVerse(osis, chapter, v, 'Verse $v of $osis $chapter.');
    }
  }

  /// Writes the module and returns its bytes.
  ///
  /// Schema, pragmas and FTS5 configuration are copied from a real module so the
  /// generated file is byte-compatible with what the catalog repository produces.
  Future<List<int>> build() async {
    final db = await _buildDatabase();
    final manifest = _manifest();
    final archive = Archive()
      ..addFile(ArchiveFile('manifest.json', manifest.length, manifest.codeUnits))
      ..addFile(ArchiveFile('content.db', db.length, db));

    return ZipEncoder().encode(archive);
  }

  Future<File> writeTo(Directory dir) async {
    final bytes = await build();
    final file = File('${dir.path}/$id.amod')..writeAsBytesSync(bytes);
    return file;
  }

  String _manifest() => '''
{
  "amf": 1,
  "schemaVersion": 1,
  "minReaderVersion": 1,
  "id": "$id",
  "type": "$type",
  "name": "$name",
  "shortName": "$id",
  "language": "en",
  "direction": "ltr",
  "version": "1.0.0",
  "publisher": "Test",
  "license": "PublicDomain",
  "copyright": "Public domain",
  "source": "https://example.org",
  "attribution": "",
  "features": { "hasStrongs": false, "hasMorphology": false, "hasFootnotes": false, "hasHeadings": false },
  "dependencies": []
}
''';

  Future<List<int>> _buildDatabase() async {
    final file = File(
        '${Directory.systemTemp.path}/build-$id-${DateTime.now().microsecondsSinceEpoch}.db');
    final db = sqlite3.open(file.path);

    // Same pragmas a real module carries. The application_id is what distinguishes an
    // AMF module from any other SQLite file, so a test module without it would be
    // rejected by the very reader it exists to test.
    _exec(db, [
      'PRAGMA application_id = 1095585604',
      'PRAGMA user_version = 1',
      'PRAGMA journal_mode = DELETE',
      '''CREATE TABLE books (
        bookId INTEGER PRIMARY KEY, osisCode TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
        abbreviation TEXT NOT NULL, testament TEXT NOT NULL CHECK (testament IN ('OT','NT')),
        bookOrder INTEGER NOT NULL, chapterCount INTEGER NOT NULL
      ) WITHOUT ROWID''',
      '''CREATE TABLE verses (
        bookId INTEGER NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL,
        verseEnd INTEGER, text TEXT NOT NULL, UNIQUE (bookId, chapter, verse)
      )''',
      '''CREATE VIRTUAL TABLE verses_fts USING fts5(
        text, bookId UNINDEXED, chapter UNINDEXED, verse UNINDEXED, verseEnd UNINDEXED,
        content='verses', content_rowid='rowid',
        tokenize='unicode61 remove_diacritics 2'
      )''',
      '''CREATE TRIGGER verses_ai AFTER INSERT ON verses BEGIN
        INSERT INTO verses_fts(rowid, text, bookId, chapter, verse, verseEnd)
        VALUES (new.rowid, new.text, new.bookId, new.chapter, new.verse, new.verseEnd);
      END''',
    ]);

    var order = 0;
    for (final entry in books.entries) {
      order++;
      final osis = entry.key;
      final chapterCount = entry.value.length;
      _exec(db, [
        "INSERT INTO books VALUES ($order, '$osis', '$osis', '${osis.substring(0, 2)}', "
            "'NT', $order, $chapterCount)",
      ]);
      for (final chapter in entry.value.entries) {
        for (final verse in chapter.value.entries) {
          final text = verse.value.replaceAll("'", "''");
          _exec(db, [
            "INSERT INTO verses (bookId, chapter, verse, text) "
                "VALUES ($order, ${chapter.key}, ${verse.key}, '$text')",
          ]);
        }
        for (final span in spans['${entry.key}:${chapter.key}'] ?? const []) {
          final text = span.text.replaceAll("'", "''");
          _exec(db, [
            "INSERT INTO verses (bookId, chapter, verse, verseEnd, text) "
                "VALUES ($order, ${chapter.key}, ${span.first}, ${span.last}, '$text')",
          ]);
        }
      }
    }

    db.dispose();
    final bytes = file.readAsBytesSync();
    file.deleteSync();
    return bytes;
  }

  void _exec(Database db, List<String> statements) {
    for (final s in statements) {
      db.execute(s);
    }
  }
}
