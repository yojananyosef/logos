import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'support/module_builder.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/services/amf_reader.dart';
import 'package:logos_engine/data/services/module_installer.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-modules-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  ModuleBuilder sampleModule(String id) {
    final b = ModuleBuilder(id, name: 'Sample $id');
    // A complete chapter, so the normal path is covered.
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'He was in the beginning with God.');
    b.addVerse('John', 1, 3, 'All things were made through him.');
    b.addVerse('John', 2, 1, 'On the third day, a wedding took place.');
    b.addVerse('John', 2, 2, 'The mother of Jesus was there.');
    b.addVerse('Gen', 1, 1, 'In the beginning God created heaven and earth.');
    return b;
  }

  group('module format', () {
    test('reads a module that matches the format', () async {
      await sampleModule('SAMPLE').writeTo(temp);

      final module = await BibleRepository(ModuleStore(temp)).open('SAMPLE');

      expect(module.books.map((b) => b.osisCode), containsAll(['John', 'Gen']));
      expect(module.integrity.isValid, isTrue,
          reason: 'a module built without the off-by-one should be sound');
    });

    test('rejects a module whose application_id is wrong', () async {
      // A SQLite file that is not an AMF module. Accepting it would mean the library
      // could list something the reader cannot open.
      final bytes = await _plainSqlite();
      final file = File('${temp.path}/NOTAMOD.amod')..writeAsBytesSync(bytes);

      final reader = AmfModuleReader(expectedSha256: null);
      expect(
        () => reader.openFromFile(file),
        throwsA(isA<AmfFormatException>()),
      );
    });

    test('rejects bytes that do not match the catalog hash', () async {
      final file = await sampleModule('SAMPLE').writeTo(temp);
      expect(file.existsSync(), isTrue);

      final reader = AmfModuleReader(
        expectedSha256: 'a' * 64,
      );
      await expectLater(
        reader.openFromFile(file),
        throwsA(isA<AmfFormatException>().having(
          (e) => e.message,
          'message',
          contains('sha256'),
        )),
      );
    });
  });

  group('installing', () {
    test('writes a verified module and lists it', () async {
      final builder = sampleModule('SAMPLE');
      final bytes = await builder.build();
      final digest = _sha256(bytes);

      final store = ModuleStore(temp);
      final installer = ModuleInstaller(store);

      final result = await installer.install(
        'SAMPLE',
        bytes: bytes,
        expectedSha256: digest,
      );

      expect(result.status, InstallStatus.ok);
      expect(store.pathFor('SAMPLE').existsSync(), isTrue);
      expect(await BibleRepository(store).listInstalled(), hasLength(1));
    });

    test('refuses a module whose hash does not match, and writes nothing', () async {
      final bytes = await sampleModule('SAMPLE').build();
      final store = ModuleStore(temp);

      final result = await ModuleInstaller(store).install(
        'SAMPLE',
        bytes: bytes,
        expectedSha256: 'b' * 64,
      );

      expect(result.status, InstallStatus.hashMismatch);
      // The important half: a rejected module must leave no file behind, or a later
      // install would see a partial module and skip it as already present.
      expect(store.pathFor('SAMPLE').existsSync(), isFalse);
      expect(temp.listSync().whereType<File>(), isEmpty);
    });

    test('refuses an archive that is not a module', () async {
      final store = ModuleStore(temp);
      final zip = ZipEncoder().encode(Archive()
        ..addFile(
          ArchiveFile('readme.txt', 5, 'hello'.codeUnits),
        ));

      final result = await ModuleInstaller(store).install('JUNK', bytes: zip);

      expect(result.status, InstallStatus.malformed);
      expect(result.message, contains('manifest.json'));
      expect(store.pathFor('JUNK').existsSync(), isFalse);
    });

    test('uninstall removes the module', () async {
      final bytes = await sampleModule('SAMPLE').build();
      final store = ModuleStore(temp);
      final installer = ModuleInstaller(store);
      await installer.install('SAMPLE', bytes: bytes);

      expect(await installer.uninstall('SAMPLE'), isTrue);
      expect(store.pathFor('SAMPLE').existsSync(), isFalse);
      expect(await installer.uninstall('SAMPLE'), isFalse);
    });
  });

  group('reading', () {
    test('returns a whole chapter in order', () async {
      await sampleModule('SAMPLE').writeTo(temp);
      final repo = BibleRepository(ModuleStore(temp));

      final verses = await repo.chapter('SAMPLE', 'John', 1);

      expect(verses.map((v) => v.verse), [1, 2, 3]);
      expect(verses.first.text, startsWith('In the beginning'));
    });

    test('returns a single verse', () async {
      await sampleModule('SAMPLE').writeTo(temp);
      final repo = BibleRepository(ModuleStore(temp));

      final verses = await repo.verse('SAMPLE', 'John', 1, 2);

      expect(verses, hasLength(1));
      expect(verses.single.verse, 2);
    });

    test('an absent verse returns empty rather than throwing', () async {
      await sampleModule('SAMPLE').writeTo(temp);
      final repo = BibleRepository(ModuleStore(temp));

      // John 99 does not exist. A reader that throws here shows an error instead of an
      // empty chapter, and the user cannot tell the two apart.
      expect(await repo.verse('SAMPLE', 'John', 99, 1), isEmpty);
      expect(await repo.chapter('SAMPLE', 'NoSuchBook', 1), isEmpty);
    });

    test('finds text through the FTS5 index', () async {
      await sampleModule('SAMPLE').writeTo(temp);
      final repo = BibleRepository(ModuleStore(temp));

      final hits = await repo.search('SAMPLE', 'beginning');

      expect(hits, isNotEmpty);
      expect(hits.first.osisCode, 'John');
      expect(hits.first.chapter, 1);
    });

    test('search matches across diacritics', () async {
      // The reason the format chose `remove_diacritics 2`: a Spanish module has to be
      // searchable by the unaccented form, because that is what most people type.
      //
      // Keyed on `John` and named `Juan`, because that is how a Spanish module is built: the
      // OSIS code is what the application addresses the book by, and the display name is the
      // translation's own. A module keyed on `Juan` would be a book the reference parser
      // cannot resolve `Jn 3:16` against.
      final b = ModuleBuilder('ES', bookNames: {'John': 'Juan'});
      b.addVerse(
          'John', 1, 1, 'En el principio era el Verbo, y el Verbo estaba con Dios.');
      await b.writeTo(temp);
      final repo = BibleRepository(ModuleStore(temp));

      expect(await repo.search('ES', 'principio'), isNotEmpty);
    });
  });

  group('spans', () {
    test('a verse inside a stored span is found', () async {
      // USFM writes `\\v 35-36` as one run of text, so a correct module stores it as one
      // row numbered 35 with verseEnd 36. A lookup of 36 must still find it: telling the
      // user the passage does not exist while its words are on screen is the worst
      // outcome a reader can produce.
      final b = ModuleBuilder('SPAN');
      b.addVerseRange('Luke', 17, 35, 36, 'Two will be taken; one will be left.');
      await b.writeTo(temp);
      final repo = BibleRepository(ModuleStore(temp));

      expect(await repo.verse('SPAN', 'Luke', 17, 35), hasLength(1));
      final second = await repo.verse('SPAN', 'Luke', 17, 36);
      expect(second, hasLength(1));
      expect(second.single.text, contains('one will be left'));
      // The row keeps its own numbering, so a caller can see what actually holds it.
      expect(second.single.verse, 35);
      expect(second.single.verseEnd, 36);
    });

    test('a verse outside a span is not matched', () async {
      final b = ModuleBuilder('SPAN');
      b.addVerseRange('Luke', 17, 35, 36, 'Two will be taken.');
      await b.writeTo(temp);
      final repo = BibleRepository(ModuleStore(temp));

      expect(await repo.verse('SPAN', 'Luke', 17, 34), isEmpty);
      expect(await repo.verse('SPAN', 'Luke', 17, 37), isEmpty);
    });

    test('a span is not reported as a gap', () async {
      // 35-36 stored as one row must not read as a missing 36, so a contiguous chapter
      // containing a span still passes. Comparing against `verse + 1` instead of against
      // what the row covers would flag every correctly-built range as defective.
      final b = ModuleBuilder('SPAN');
      for (var v = 1; v <= 34; v++) {
        b.addVerse('Luke', 17, v, 'Verse $v.');
      }
      b.addVerseRange('Luke', 17, 35, 36, 'Two will be taken; one will be left.');
      b.addVerse('Luke', 17, 37, 'Where, Lord?');
      await b.writeTo(temp);

      final module = await BibleRepository(ModuleStore(temp)).open('SPAN');
      expect(module.integrity.isValid, isTrue, reason: '${module.integrity.failures}');
    });
  });

  group('integrity', () {
    test('a module missing verse 1 is reported, not silently accepted', () async {
      // This is the upstream defect, reproduced deliberately. The KJV and ASV modules
      // are missing verse 1 in 260 chapters each, John 1:1 among them, and their own
      // end-to-end test passed because it read Genesis 1:1.
      final b = ModuleBuilder('BROKEN');
      b.addVerse('John', 1, 2, 'He was in the beginning with God.');
      b.addVerse('John', 1, 3, 'All things were made through him.');
      b.addChapterStartingAt('John', 2, 2);
      await b.writeTo(temp);

      final module = await BibleRepository(ModuleStore(temp)).open('BROKEN');

      expect(module.isSound, isFalse);
      expect(module.integrity.failures.map((f) => f.chapterKey), contains('John:1'));
      expect(module.integrity.failures.first.reason, contains('expected 1'));
    });

    test('the module still opens, so the user can read what is there', () async {
      // Refusing the whole Bible over a data defect would be worse than showing it with
      // a warning. The defect is reported; the content is not withheld.
      final b = ModuleBuilder('BROKEN');
      b.addVerse('John', 1, 2, 'He was in the beginning with God.');
      await b.writeTo(temp);

      final repo = BibleRepository(ModuleStore(temp));
      final module = await repo.open('BROKEN');

      expect(module.integrity.isValid, isFalse);
      expect(await repo.chapter('BROKEN', 'John', 1), hasLength(1));
    });
  });

  group('listing', () {
    test('lists installed modules with their manifest metadata', () async {
      await sampleModule('SAMPLE').writeTo(temp);
      final installed = await BibleRepository(ModuleStore(temp)).listInstalled();

      expect(installed, hasLength(1));
      expect(installed.single.id, 'SAMPLE');
      expect(installed.single.name, 'Sample SAMPLE');
    });

    test('an absent directory is an empty library, not an error', () async {
      // "No content installed yet" is the normal first-run state.
      final missing = Directory('${temp.path}/does-not-exist');
      expect(await BibleRepository(ModuleStore(missing)).listInstalled(), isEmpty);
    });
  });
}

/// A plain SQLite database, which is not an AMF module.
Future<List<int>> _plainSqlite() async {
  final file = File(
    '${Directory.systemTemp.path}/plain-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final db = sqlite3.open(file.path);
  db.execute('CREATE TABLE t (a INTEGER)');
  db.dispose();
  final bytes = file.readAsBytesSync();
  file.deleteSync();
  return bytes;
}

/// Computed through the same function the installer uses, so a mismatch in a test would
/// be a real mismatch rather than an artefact of two different hash implementations.
String _sha256(List<int> bytes) => sha256.convert(bytes).toString();
