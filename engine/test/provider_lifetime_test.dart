import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logos_engine/app_providers.dart';
import 'package:logos_engine/data/services/module_installer.dart';
// riverpod is a transitive dependency of the app, not a direct one. Importing it
// from a test is fine and needs no pubspec change: the analyzer note is about
// declaring a dependency the library declares, and this is the same package the
// app already depends on.
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';

import 'support/module_builder.dart';

/// The repository provider must release what it opened.
///
/// `BibleRepository.open` stages the module to a database file on disk, because
/// drift opens from a path and cannot be handed bytes. `BibleRepository.dispose()`
/// is the only thing that deletes it. The provider is where that call has to
/// happen: `BibleRepository` is not a `ChangeNotifier`, nobody else holds a
/// reference to it, and riverpod is the only owner that knows when it goes away.
///
/// Without `ref.onDispose`, nothing is ever released. This is not a test-only
/// leak: on a desktop it silently fills the disk, and on a phone it fills the
/// user's storage with copies of modules the app has already read and closed.
void main() {
  late Directory installDir;
  late Directory stagedRoot;
  late ProviderContainer container;

  setUp(() {
    installDir = Directory.systemTemp.createTempSync('logos-provider-install-');
    stagedRoot = Directory.systemTemp.createTempSync('logos-provider-staged-');
    container = ProviderContainer(
      overrides: [moduleStoreProvider.overrideWithValue(ModuleStore(installDir))],
    );
  });

  tearDown(() {
    container.dispose();
    for (final dir in [installDir, stagedRoot]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  /// Staged databases inside this test's own root.
  int stagedDatabases() {
    if (!stagedRoot.existsSync()) return 0;
    return stagedRoot
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .length;
  }

  /// Runs [body] with the reader staging into this test's own directory.
  ///
  /// `Directory.systemTemp` is what `amf_reader.dart` stages into and it is
  /// resolved once, so a test cannot redirect it by setting `TMPDIR` —
  /// `Platform.environment` is unmodifiable and the getter is cached. What it can
  /// do is run the code inside an `IOOverrides` zone, which is the seam the SDK
  /// provides for exactly this.
  ///
  /// Counting staged files in the shared system temp instead would make the
  /// answer depend on which other tests happen to run at the same moment. That is
  /// not hypothetical: this test failed once in a full-suite run and passed in
  /// four isolated ones, because another test's leftovers moved the count. A test
  /// whose verdict moves with the scheduler is a test that gets ignored the first
  /// time it is inconvenient.
  Future<T> staged<T>(Future<T> Function() body) {
    return IOOverrides.runZoned(
      body,
      getSystemTempDirectory: () => stagedRoot,
    );
  }

  test('the repository provider hands out a repository', () {
    expect(container.read(bibleRepositoryProvider), isNotNull);
  });

  test('disposing the container removes the modules the repository staged', () async {
    final builder = ModuleBuilder('STAGED', name: 'Staged');
    builder.addVerse('John', 1, 1, 'In the beginning was the Word.');
    await builder.writeTo(installDir);
    expect(ModuleStore(installDir).pathFor('STAGED').existsSync(), isTrue);

    expect(stagedDatabases(), 0, reason: 'this test owns its staging root');

    await staged(() async {
      // Open it through the provider. This is what the reader does on first read.
      final repo = container.read(bibleRepositoryProvider);
      final module = await repo.open('STAGED');
      expect(module.books, isNotEmpty);
      expect(await repo.verse('STAGED', 'John', 1, 1), isNotEmpty);

      // Extracted and staged, so the count has gone up. Without this the rest of
      // the test would pass on a reader that stages nothing at all.
      expect(
        stagedDatabases(),
        greaterThan(0),
        reason: 'opening a module stages a database',
      );
    });

    // Now the part that matters: releasing the provider releases the file.
    final during = stagedDatabases();
    expect(during, greaterThan(0), reason: 'nothing was staged, so nothing to prove');

    container.dispose();
    expect(
      stagedDatabases(),
      0,
      reason: 'dispose() on the provider must remove the staged databases. '
          'Without it every module the reader ever opened stays on disk for the '
          'lifetime of the installation.',
    );

    // Re-create it so tearDown's dispose is not a double.
    container = ProviderContainer(
      overrides: [
        moduleStoreProvider.overrideWithValue(ModuleStore(installDir)),
      ],
    );
  });

  test('a repository the provider never opened leaves nothing', () async {
    // The control: reading the provider without opening a module should not
    // create a staged file. If this ever fails, dispose() has started removing
    // things it should not.
    await staged(() async {
      final before = stagedDatabases();
      container.read(bibleRepositoryProvider);
      container.dispose();
      expect(stagedDatabases(), before);
    });
    container = ProviderContainer(
      overrides: [moduleStoreProvider.overrideWithValue(ModuleStore(installDir))],
    );
  });
}