import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/bible_repository.dart';
import 'package:logos_engine/data/repositories/library_repository.dart';
import 'package:logos_engine/data/services/module_installer.dart';
import 'package:logos_engine/domain/models/catalog.dart';
import 'package:logos_engine/domain/models/license.dart';
import 'package:logos_engine/ui/features/library/view_models/library_view_model.dart';

import 'support/module_builder.dart';

/// A source that serves bytes from memory, so the whole install path runs with no
/// network and no filesystem beyond the store.
class _MemorySource implements ModuleSource {
  _MemorySource(this.payloads);

  /// url to bytes.
  final Map<String, List<int>> payloads;

  /// Urls that were requested. Used to assert that a blocked resource is never fetched,
  /// which is the property that actually matters for a licence gate.
  final requested = <String>[];

  @override
  Future<List<int>> fetch(String url, {String? expectedSha256}) async {
    requested.add(url);
    final bytes = payloads[url];
    if (bytes == null) throw StateError('nothing at $url');
    return bytes;
  }
}

String _catalogJson({
  required String id,
  required String url,
  required String sha256,
  String license = 'PublicDomain',
  String releaseDate = '1970-01-01',
  String type = 'bible',
  String? name,
}) =>
    '''
{
  "format": "amf-catalog",
  "version": "1.0.0",
  "contractMajor": 1,
  "modules": [
    {
      "id": "$id",
      "type": "$type",
      "name": "${name ?? id}",
      "shortName": "$id",
      "language": "en",
      "version": "1.0.0",
      "sha256": "$sha256",
      "sizeBytes": 1,
      "downloadUrl": "$url",
      "granularity": "verse",
      "license": {
        "id": "$license",
        "attribution": "Test",
        "sourceUrl": "https://example.org",
        "releaseDate": "$releaseDate",
        "jurisdictions": [],
        "basis": "Test basis."
      }
    }
  ]
}
''';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('logos-library-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<List<int>> sampleBytes() async {
    final b = ModuleBuilder('SAMPLE', name: 'Sample');
    b.addVerse('John', 1, 1, 'In the beginning was the Word.');
    b.addVerse('John', 1, 2, 'He was in the beginning with God.');
    return b.build();
  }

  /// Builds a ViewModel. Loading is left to the caller.
  ///
  /// Deliberately not chained with `..load(...)`: that starts a real asynchronous read
  /// that nobody awaits, and `pumpEventQueue` does not wait for genuine file I/O, so the
  /// assertions would race the load. Every test awaits [LibraryViewModel.load] itself.
  LibraryViewModel buildViewModel(_MemorySource source) {
    final store = ModuleStore(temp);
    return LibraryViewModel(
      repository: BibleRepository(store),
      installer: ModuleInstaller(store),
      source: source,
      catalogService: const CatalogService(),
    );
  }

  group('catalog parsing', () {
    test('reads resources with their licence', () {
      final catalog = const CatalogService().parse(_catalogJson(
        id: 'WEB',
        url: 'file:///tmp/WEB.amod',
        sha256: 'a' * 64,
        license: 'CC-BY',
      ));

      expect(catalog, isNotNull);
      expect(catalog!.entries, hasLength(1));
      final resource = catalog.entries.first.resource;
      expect(resource.id, 'WEB');
      expect(resource.type, ResourceType.bible);
      expect(resource.license.kind, LicenseKind.ccBy);
    });

    test('an unrecognised licence resolves to unresolved, not public domain', () {
      // Defaulting would be the dangerous direction: a typo in a catalog field would
      // become a declaration that the content is free to redistribute.
      final catalog = const CatalogService().parse(_catalogJson(
        id: 'X',
        url: 'file:///tmp/x.amod',
        sha256: 'a' * 64,
        license: 'PublicDoman',
      ));

      expect(catalog!.entries.first.resource.license.kind, isNull);
      expect(
        catalog.entries.first.resource.license.isDistributable(
          now: DateTime.now().toUtc(),
        ),
        isFalse,
      );
    });

    test('a corrupt catalog yields null rather than throwing', () async {
      // Installed content must survive a broken catalog: the modules on disk do not
      // depend on it, so a user with one must not be left with a broken library.
      expect(const CatalogService().parse('{ not json'), isNull);
    });
  });

  group('library state', () {
    test('with no catalog, installed modules are still listed', () async {
      final bytes = await sampleBytes();
      await ModuleInstaller(ModuleStore(temp)).install('SAMPLE', bytes: bytes);

      final source = _MemorySource({});
      final vm = buildViewModel(source);
      await vm.load();

      expect(vm.state.loaded, isTrue);
      expect(vm.state.installed.map((e) => e.resource.id), ['SAMPLE']);
      // Nothing can be installed without a catalog, and the view must say so rather
      // than presenting an empty list as if it were the full catalogue.
      expect(vm.state.catalogVersion, isNull);
    });

    test('an empty library is a real state, not a loading one', () async {
      final source = _MemorySource({});
      final vm = buildViewModel(source);
      await vm.load(catalogJson: '{"modules":[]}');

      expect(vm.state.loaded, isTrue);
      expect(vm.state.entries, isEmpty);
    });
  });

  group('licensing', () {
    test('a resource under copyright is listed but not installable', () async {
      // The Biblia Platense case, which is the reason the catalog is a separate
      // repository: the app ships, the Spanish text joins a later release.
      final bytes = await sampleBytes();
      final source = _MemorySource({'file:///tmp/PLATENSE.amod': bytes});
      final vm = buildViewModel(source);
      await vm.load(
        catalogJson: _catalogJson(
          id: 'PLATENSE',
          url: 'file:///tmp/PLATENSE.amod',
          sha256: 'a' * 64,
          releaseDate: '2027-01-01',
          name: 'Biblia Platense',
        ),
      );

      expect(vm.state.pending.map((e) => e.resource.id), ['PLATENSE']);
      expect(vm.state.available, isEmpty);
    });

    test('an unlicensed resource is never fetched', () async {
      // The gate has to run before the request, not after. Fetching first and refusing
      // afterwards would mean the application had already pulled restricted content onto
      // the device in order to then decline it.
      final bytes = await sampleBytes();
      final source = _MemorySource({'file:///tmp/PLATENSE.amod': bytes});
      final vm = buildViewModel(source);
      await vm.load(
          catalogJson: _catalogJson(
        id: 'PLATENSE',
        url: 'file:///tmp/PLATENSE.amod',
        sha256: 'a' * 64,
        releaseDate: '2099-01-01',
      ));

      await vm.install('PLATENSE');

      expect(source.requested, isEmpty,
          reason: 'no bytes may be requested for an unlicensed resource');
      expect(vm.state.failures['PLATENSE'], contains('copyright'));
    });

    test('a public-domain resource installs and appears as installed', () async {
      final bytes = await sampleBytes();
      final digest = _sha256(bytes);
      final source = _MemorySource({'file:///tmp/SAMPLE.amod': bytes});
      final vm = buildViewModel(source);
      await vm.load(
          catalogJson: _catalogJson(
        id: 'SAMPLE',
        url: 'file:///tmp/SAMPLE.amod',
        sha256: digest,
      ));

      expect(vm.state.available.map((e) => e.resource.id), ['SAMPLE']);

      await vm.install('SAMPLE');

      expect(vm.state.installed.map((e) => e.resource.id), ['SAMPLE']);
      expect(vm.state.failures, isEmpty);
      expect(ModuleStore(temp).pathFor('SAMPLE').existsSync(), isTrue);
    });

    test('a corrupt download fails with a reason, and installs nothing', () async {
      final bytes = await sampleBytes();
      final source = _MemorySource({'file:///tmp/SAMPLE.amod': bytes});
      final vm = buildViewModel(source);
      await vm.load(
          catalogJson: _catalogJson(
        id: 'SAMPLE',
        url: 'file:///tmp/SAMPLE.amod',
        // A hash that will not match, standing in for a truncated or tampered
        // download.
        sha256: 'c' * 64,
      ));

      await vm.install('SAMPLE');

      expect(vm.state.failures['SAMPLE'], contains('sha256'));
      expect(vm.state.installed, isEmpty);
      expect(ModuleStore(temp).pathFor('SAMPLE').existsSync(), isFalse);
    });

    test('uninstalling returns a resource to the available list', () async {
      final bytes = await sampleBytes();
      final digest = _sha256(bytes);
      final source = _MemorySource({'file:///tmp/SAMPLE.amod': bytes});
      final vm = buildViewModel(source);
      await vm.load(
          catalogJson: _catalogJson(
        id: 'SAMPLE',
        url: 'file:///tmp/SAMPLE.amod',
        sha256: digest,
      ));
      await vm.install('SAMPLE');

      await vm.uninstall('SAMPLE');

      expect(vm.state.installed, isEmpty);
      expect(vm.state.available.map((e) => e.resource.id), ['SAMPLE']);
      expect(ModuleStore(temp).pathFor('SAMPLE').existsSync(), isFalse);
    });
  });

  group('license model', () {
    test('public domain needs no attribution', () {
      final info = LicenseInfo.publicDomain(sourceUrl: 'https://example.org');
      expect(info.kind, LicenseKind.publicDomain);
      expect(info.kind!.requiresAttribution, isFalse);
      expect(info.isDistributable(now: DateTime.utc(2026)), isTrue);
    });

    test('CC BY requires attribution but permits commercial use', () {
      final info = LicenseInfo(
        kind: LicenseKind.ccBy,
        attribution: 'Someone',
        sourceUrl: 'https://example.org',
        releaseDate: DateTime.utc(1970),
        jurisdictions: const {},
      );
      expect(info.kind!.requiresAttribution, isTrue);
      expect(info.kind!.forbidsCommercialUse, isFalse);
      expect(info.kind!.isShareAlike, isFalse);
    });

    test('CC BY-SA is share-alike, which taints a catalog containing it', () {
      final info = LicenseInfo(
        kind: LicenseKind.ccBySa,
        attribution: 'Someone',
        sourceUrl: 'https://example.org',
        releaseDate: DateTime.utc(1970),
        jurisdictions: const {},
      );
      expect(info.kind!.isShareAlike, isTrue);
      // A catalog carrying one share-alike resource is itself share-alike, which is why
      // the build gate refuses to mix one into a closed-distribution target.
      final catalog = Catalog(
        format: 'amf-catalog',
        version: '1',
        entries: [
          CatalogEntry(
            ResourceDescriptor(
              id: 'RCA',
              type: ResourceType.words,
              name: 'Robinson codes',
              shortName: 'RCA',
              language: 'en',
              version: '1',
              license: info,
            ),
          ),
        ],
      );
      expect(catalog.isShareAlike, isTrue);
    });

    test('a future release date is not distributable yet', () {
      final info = LicenseInfo(
        kind: LicenseKind.publicDomain,
        attribution: '',
        sourceUrl: 'https://example.org',
        releaseDate: DateTime.utc(2099),
        jurisdictions: const {},
      );
      expect(info.isDistributable(now: DateTime.utc(2026)), isFalse);
    });
  });
}

/// Computed with the same function the installer uses, so a mismatch in a test would be
/// a real mismatch rather than an artefact of two different hash implementations.
String _sha256(List<int> bytes) => sha256.convert(bytes).toString();
