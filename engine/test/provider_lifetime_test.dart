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
  late Directory temp;
  late ProviderContainer container;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-provider-');
    container = ProviderContainer(
      overrides: [moduleStoreProvider.overrideWithValue(ModuleStore(temp))],
    );
  });

  tearDown(() {
    container.dispose();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Staged databases on disk right now, which is the thing that must not grow
  /// without bound.
  int stagedDatabases() =>
      Directory.systemTemp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('${Platform.pathSeparator}amod-'))
          .where((f) => f.path.endsWith('.db'))
          .length;

  test('the repository provider hands out a repository', () {
    expect(container.read(bibleRepositoryProvider), isNotNull);
  });

  test('disposing the container removes the modules the repository staged', () async {
    final before = stagedDatabases();

    final builder = ModuleBuilder('STAGED', name: 'Staged');
    builder.addVerse('John', 1, 1, 'In the beginning was the Word.');
    await builder.writeTo(temp);
    expect(ModuleStore(temp).pathFor('STAGED').existsSync(), isTrue);

    // Open it through the provider. This is what the reader does on first read.
    final repo = container.read(bibleRepositoryProvider);
    final module = await repo.open('STAGED');
    expect(module.books, isNotEmpty);
    expect(await repo.verse('STAGED', 'John', 1, 1), isNotEmpty);

    // Extracted and staged, so the count has gone up.
    expect(
      stagedDatabases(),
      greaterThan(before),
      reason: 'opening a module stages a database; without this the rest of the '
          'test proves nothing',
    );

    // Now the part that matters: releasing the provider releases the file.
    final during = stagedDatabases();
    container.dispose();
    expect(
      stagedDatabases(),
      lessThan(during),
      reason: 'dispose() on the provider must remove the staged databases. '
          'Without it every module the reader ever opened stays on disk for '
          'the lifetime of the installation.',
    );

    // Re-create it so tearDown's dispose is not a double.
    container = ProviderContainer(
      overrides: [moduleStoreProvider.overrideWithValue(ModuleStore(temp))],
    );
  });

  test('a repository the provider never opened leaves nothing', () {
    // The control: reading the provider without opening a module should not
    // create a staged file. If this ever fails, dispose() has started removing
    // things it should not.
    final before = stagedDatabases();
    container.read(bibleRepositoryProvider);
    container.dispose();
    expect(stagedDatabases(), before);
    container = ProviderContainer(
      overrides: [moduleStoreProvider.overrideWithValue(ModuleStore(temp))],
    );
  });
}
