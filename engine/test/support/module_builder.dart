import 'dart:io';

import 'package:archive/archive.dart';
// sqlite3 directly, not drift: this is a fixture, not application code, and drift's
// executor requires an owning database to open it. Building the file with the same
// engine the reader will open it with is also a fairer test.
import 'package:sqlite3/sqlite3.dart';

import 'package:logos_engine/data/services/amf_reader.dart';

/// The canonical position of each OSIS code in the canon.
///
/// The books table's `bookOrder` is what the reader's book list and every ordered result are
/// sorted by. A fixture that assigned it by insertion order would put John before Genesis,
/// which is not a thing the reader would ever display — and would silently invert the order
/// of any result the test then checked, which is worse than a wrong fixture.
const Map<String, int> canonicalBookOrder = {
  'Gen': 1, 'Exod': 2, 'Lev': 3, 'Num': 4, 'Deut': 5, 'Josh': 6, 'Judg': 7,
  'Ruth': 8, '1Sam': 9, '2Sam': 10, '1Kgs': 11, '2Kgs': 12, '1Chr': 13,
  '2Chr': 14, 'Ezra': 15, 'Neh': 16, 'Esth': 17, 'Job': 18, 'Ps': 19, 'Prov': 20,
  'Eccl': 21, 'Song': 22, 'Isa': 23, 'Jer': 24, 'Lam': 25, 'Ezek': 26, 'Dan': 27,
  'Hos': 28, 'Joel': 29, 'Amos': 30, 'Obad': 31, 'Jonah': 32, 'Mic': 33, 'Nah': 34,
  'Hab': 35, 'Zeph': 36, 'Hag': 37, 'Zech': 38, 'Mal': 39, 'Matt': 40, 'Mark': 41,
  'Luke': 42, 'John': 43, 'Acts': 44, 'Rom': 45, '1Cor': 46, '2Cor': 47, 'Gal': 48,
  'Eph': 49, 'Phil': 50, 'Col': 51, '1Thess': 52, '2Thess': 53, '1Tim': 54,
  '2Tim': 55, 'Titus': 56, 'Phlm': 57, 'Heb': 58, 'Jas': 59, '1Pet': 60,
  '2Pet': 61, '1John': 62, '2John': 63, '3John': 64, 'Jude': 65, 'Rev': 66,
};

/// A `bookId` no `books` row carries, used for references the fixture deliberately leaves
/// dangling.
///
/// 9999 rather than 0 because 0 is a plausible `bookId` and a reference written against it
/// could accidentally resolve.
const int missingBookId = 9999;

/// Builds a real AMF module on disk, so the tests exercise the actual format rather than
/// a stand-in for it.
///
/// A hand-built stub would pass while the real reader failed: the reader verifies an
/// `application_id`, unpacks a zip, opens SQLite and joins against an external-content
/// FTS5 index. None of that is exercised by a mock, and all of it is exactly where a
/// format implementation goes wrong.
class ModuleBuilder {
  ModuleBuilder(this.id, {this.name = 'Test Bible', this.type = 'bible', this.bookNames = const {}});

  final String id;
  final String name;

  /// The display name for each OSIS code, where it differs from the code.
  ///
  /// A Spanish module is keyed by OSIS codes and *named* in Spanish — `John` becomes `Juan`
  /// in the `name` column, exactly as `tool/build_module.dart` writes it from the
  /// translation's own `\toc2`. Using `Juan` as the key instead would give the module a book
  /// the application cannot address: `BibleRepository.bookAliases` looks books up by OSIS,
  /// and the reference parser resolves `Jn 3:16` against them.
  final Map<String, String> bookNames;

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

  /// Cross-references to be written, in the order they should be stored.
  ///
  /// A list rather than a map because two references may share a phrase and a verse, and
  /// the reader renders them in source order — a map keyed on the pair would collapse them
  /// and silently drop one link.
  final List<FixtureCrossReference> crossReferences = [];

  /// Adds one cross-reference: a phrase in a verse, and the passages it points at.
  ///
  /// [targets] are `book:chapter:verse` strings in OSIS terms. Written as strings because
  /// that is what the source data looks like, and parsing them here means a fixture cannot
  /// accidentally express a reference the format could not store.
  ///
  /// Set [allowMissingTargetBook] to write a reference into a book the fixture lacks. That is
  /// how a damaged or partial module looks, and the reader has a defined answer for it.
  void addCrossReference({
    required String fromBook,
    required int fromChapter,
    required int fromVerse,
    required String anchor,
    required List<String> targets,
    bool allowMissingTargetBook = false,
  }) {
    for (final t in targets) {
      final parts = t.split(':');
      if (parts.length != 3) {
        throw ArgumentError('target "$t" must be book:chapter:verse in OSIS terms');
      }
      crossReferences.add(FixtureCrossReference(
        fromBook: fromBook,
        fromChapter: fromChapter,
        fromVerse: fromVerse,
        anchor: anchor,
        toBook: parts[0],
        toChapter: int.parse(parts[1]),
        toVerse: int.parse(parts[2]),
        allowMissingTargetBook: allowMissingTargetBook,
      ));
    }
  }

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
      // Present whether or not any reference is added, because the table's *absence* is
      // itself a case the reader has to handle: a module built before cross-references
      // existed has none, and a query that assumed it would fail on every chapter.
      CrossReferenceSchema.create,
      CrossReferenceSchema.index,
    ]);

    var bookId = 0;
    final bookIds = <String, int>{};
    for (final entry in books.entries) {
      bookId++;
      final osis = entry.key;
      // The highest chapter number present, not how many chapters are present. They differ
      // as soon as a fixture holds a book from the middle — Proverbs chapter 8 alone would
      // otherwise report `chapterCount = 1`, and the reader would refuse to navigate to it
      // because it believed the book ended at chapter 1.
      final chapterCount = entry.value.keys.isEmpty
          ? 0
          : entry.value.keys.reduce((a, b) => a > b ? a : b);

      // `bookOrder` is the book's position in the canon, not the order the fixture happened
      // to add it. Every ordered result in the application is sorted by this column, so a
      // fixture that reported John before Genesis would invert the reading order of any
      // search or find that spans both — and the mistake is invisible until a test asserts
      // on an order, which is exactly the test that would then be blamed.
      final canonical = canonicalBookOrder[osis];
      if (canonical == null) {
        throw StateError(
          'fixture names "$osis", which is not one of the 66 OSIS codes. A book outside '
          'the canon cannot be given a canonical order, so the module would order its '
          'results arbitrarily.',
        );
      }

      bookIds[osis] = bookId;
      _exec(db, [
        // The abbreviation is the OSIS code, as `tool/build_module.dart` writes it. Using a
        // short form here instead would make every fixture disagree with every real module on
        // how a cross-reference marker reads — `(Jn 1:1)` against `(Jo 1:1)` — and the
        // difference would only show up once a test asserted on a marker's text.
        "INSERT INTO books VALUES ($bookId, '$osis', '${bookNames[osis] ?? osis}', '$osis', "
            "'${canonical <= 39 ? 'OT' : 'NT'}', $canonical, $chapterCount)",
      ]);
      for (final chapter in entry.value.entries) {
        for (final verse in chapter.value.entries) {
          final text = verse.value.replaceAll("'", "''");
          _exec(db, [
            "INSERT INTO verses (bookId, chapter, verse, text) "
                "VALUES ($bookId, ${chapter.key}, ${verse.key}, '$text')",
          ]);
        }
        for (final span in spans['${entry.key}:${chapter.key}'] ?? const []) {
          final text = span.text.replaceAll("'", "''");
          _exec(db, [
            "INSERT INTO verses (bookId, chapter, verse, verseEnd, text) "
                "VALUES ($bookId, ${chapter.key}, ${span.first}, ${span.last}, '$text')",
          ]);
        }
      }
    }

    // Cross-references are written last because they address books and verses by id, and
    // those ids are only assigned as the books above are inserted. The integrity check the
    // reader runs would catch a reference written before its target existed.
    final insertXref = db.prepare(
      'INSERT INTO crossReferences (fromBookId, fromChapter, fromVerse, toBookId, '
      'toChapter, toVerse, toVerseEnd, anchor, sortOrder) VALUES (?,?,?,?,?,?,NULL,?,?)',
    );
    final sortOrder = <String, int>{};
    for (final ref in crossReferences) {
      final from = bookIds[ref.fromBook];
      if (from == null) {
        throw StateError(
          'cross-reference is anchored in a book the fixture does not contain: '
          '${ref.fromBook}',
        );
      }

      // A target book the fixture lacks is written against an id no `books` row carries,
      // which is exactly the shape of a module whose references outlived its text. The
      // reader resolves book ids against `books`, so it finds nothing and marks the marker
      // unfollowable — the behaviour the test is after.
      final to = bookIds[ref.toBook] ??
          (ref.allowMissingTargetBook ? missingBookId : null);
      if (to == null) {
        throw StateError(
          'cross-reference names a book the fixture does not contain: ${ref.toBook}. '
          'Pass allowMissingTargetBook: true if that is what you mean.',
        );
      }
      // Grouped by source verse and phrase, so two targets under one phrase share a
      // sortOrder block and the reader renders them in the order they were declared.
      final key = '$from:${ref.fromChapter}:${ref.fromVerse}:${ref.anchor}';
      final next = (sortOrder[key] ?? -1) + 1;
      sortOrder[key] = next;
      insertXref.execute([
        from,
        ref.fromChapter,
        ref.fromVerse,
        to,
        ref.toChapter,
        ref.toVerse,
        ref.anchor.replaceAll("'", "''"),
        next,
      ]);
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

/// One cross-reference a fixture asks for, still addressed by OSIS code.
///
/// Resolved to the module's own `bookId`s only when the rows are written, so a fixture
/// names books the way the rest of the fixture API does rather than in the database's
/// internal numbering.
class FixtureCrossReference {
  const FixtureCrossReference({
    required this.fromBook,
    required this.fromChapter,
    required this.fromVerse,
    required this.toBook,
    required this.toChapter,
    required this.toVerse,
    required this.anchor,
    this.allowMissingTargetBook = false,
  });

  final String fromBook;
  final int fromChapter;
  final int fromVerse;
  final String toBook;
  final int toChapter;
  final int toVerse;
  final String anchor;

  /// Lets this one reference name a book the fixture does not contain.
  ///
  /// Off by default because it is nearly always a fixture mistake, and a reference to a
  /// missing book is exactly the sort of defect the builder's own check exists to catch. It
  /// is opt-in for the tests that are specifically about how the *reader* copes with a
  /// module that has one.
  final bool allowMissingTargetBook;
}
