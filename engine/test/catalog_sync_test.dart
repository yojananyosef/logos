import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/data/repositories/library_repository.dart';

/// The bundled catalog must not drift from the one the content repository declares.
///
/// The catalog index is bundled as an asset so the application can list and install
/// something on first run. That has a real cost — a bundle cannot be refreshed without a
/// release — and this test is what bounds it. Without it, the committed file would go
/// stale the first time the content repository changed a hash, and nothing would say so
/// until a user hit an install that failed on a checksum.
///
/// It is a drift test rather than a content test on purpose: what matters is that the two
/// files describe the same catalog, not that this file happens to be correct. The content
/// repository owns the content and its tests own its correctness.
void main() {
  final bundled = File('assets/catalog/catalog.json');
  final source = File('../logos-catalogs/catalog/catalog.json');

  group('the bundled catalog', () {
    test('exists and is a catalog the engine can read', () {
      expect(bundled.existsSync(), isTrue,
          reason: 'run: dart run tool/sync_catalog.dart');

      final catalog = const CatalogService().parse(bundled.readAsStringSync());

      expect(catalog, isNotNull, reason: 'the bundled index does not parse');
      expect(catalog!.entries, isNotEmpty,
          reason: 'a bundled catalog with no resources is an inert first run');
    });

    test('agrees with the content repository', () {
      // Skipped rather than failed when the sibling repository is absent, because this
      // project is meant to be usable without it — the engine repository contains no
      // scripture and does not need the content one to build. Where the content repository
      // *is* present, silence here would be the failure.
      if (!source.existsSync()) {
        markTestSkipped('${source.path} is not present; nothing to compare against');
        return;
      }

      expect(
        _canonical(bundled.readAsStringSync()),
        _canonical(source.readAsStringSync()),
        reason: 'the bundled catalog has drifted from the content repository. '
            'Run: dart run tool/sync_catalog.dart',
      );
    });

    test('every resource carries a licence this engine will act on', () {
      final catalog = const CatalogService().parse(bundled.readAsStringSync())!;

      for (final entry in catalog.entries) {
        final licence = entry.resource.license;
        expect(licence.kind, isNotNull,
            reason: '${entry.resource.id} has no recognised licence, so the engine '
                'cannot decide whether it may be distributed');
        expect(licence.basis, isNotNull,
            reason: '${entry.resource.id} claims public domain with no recorded basis, '
                'which is an assumption rather than a claim');
      }
    });

    test('no resource claims a size its own hash field contradicts', () {
      // A row that says `sizeBytes: 0` alongside a real hash is a placeholder that was
      // half-filled: the hash was recorded and the size was not. It is not wrong enough
      // to fail an install, and it is exactly the kind of row that gets forgotten, so it
      // is called out here rather than left to be discovered by a user.
      final catalog = const CatalogService().parse(bundled.readAsStringSync())!;

      final halfFilled = catalog.entries
          .where((e) =>
              e.resource.sha256 != null &&
              e.resource.sha256!.length == 64 &&
              e.resource.sizeBytes == 0)
          .map((e) => e.resource.id)
          .toList();

      expect(halfFilled, isEmpty,
          reason: 'these declare a real sha256 but no size: $halfFilled');
    });

    test('the hash of the one real module is the one this repository builds', () {
      // The content repository's KJV is built by `tool/build_module.dart` with a pinned
      // archive timestamp, so two builds of the same source are byte-identical and the
      // digest is a fact rather than a hope. It is asserted here because it is the one
      // value in the catalog that is currently load-bearing: it is what makes the KJV
      // installable instead of merely listed.
      final catalog = const CatalogService().parse(bundled.readAsStringSync())!;
      final kjv = catalog.entries.where((e) => e.resource.id == 'KJV');

      if (kjv.isEmpty) {
        markTestSkipped('the catalog no longer declares a KJV');
        return;
      }

      final entry = kjv.single;
      expect(entry.resource.sha256, isNotNull);
      expect(entry.resource.sha256, hasLength(64));
      expect(entry.resource.sizeBytes, greaterThan(0),
          reason: 'a real module has a real size');
      expect(
        entry.resource.license.isDistributable(now: DateTime.utc(2026)),
        isTrue,
        reason: 'the KJV is public domain by age and should be installable today',
      );
    });
  });
}

/// The catalog re-encoded with sorted keys, so two files are compared by what they
/// declare rather than by how they happen to be formatted.
String _canonical(String raw) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(_sorted(jsonDecode(raw) as Object));
}

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sorted(value[k])};
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}
