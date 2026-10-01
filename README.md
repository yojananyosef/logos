# Logos

A 1:1 rebuild of the Logos Bible Software workspace in Flutter, with the content kept in a
separate repository behind a licensing gate.

Two repositories, on purpose:

| Repository | What it is |
|---|---|
| **`logos`** (this one) | The engine and the application. Flutter, six platforms. Contains no scripture text. |
| **`logos-catalogs`** | The content: the module format contract, the build-time licensing gate, and the extraction tooling. |

They are separate because **content changes on licence timelines and code changes on release
cadence**. The chosen Spanish text is still under copyright until 2027; coupling content to
the application binary would have forced either a three-month stall or shipping infringing
text.

## Why the split is load-bearing, not stylistic

The Biblia Platense (Straubinger, 1948) is the most rigorous scholarly Spanish Bible, and it
enters the public domain on **1 January 2027** — Straubinger died in 1956, and life+70 under
Ley 17.336 article 10 expires at the end of 2026. The United States runs to 2043.

So the application ships and runs now, with whatever catalog exists or with none at all, and
the Spanish catalog joins a later release on the date the licence permits. The validator in
the catalogs repository enforces that:

```
$ dart run tool/validate_catalog.dart catalog/catalog.json --jurisdiction=CL
BLOCKED — 1 violation(s):
  [release-date] PLATENSE: not distributable until 2027-01-01 (copyright still in force)

$ dart run tool/validate_catalog.dart catalog/catalog.json --jurisdiction=CL --now=2027-01-01
OK — catalog may be distributed.
```

## What is built

The workspace shell, reproduced 1:1 from the reference: a 48dp icon rail with the
`Pasaje o tema` field, a collapsible sidebar with the nine destinations and the quick-actions
section, the resource tab strip, the six-section toolbar and sub-toolbar, split panes, and
the dashboard with its four observed card types.

A reader that opens a real KJV: 66 books, 31,102 verses, phrase-level cross-references to
336,829 TSK passages, three verse-number styles, four colour schemes, find, and a layout that
reflows by layout class.

And a library that can put one there. The `Suyos` / `Tienda` scopes, the `por Título` sort,
search-as-you-type over titles and subtitles, grid and list with the choice persisted, and a
refusing install path — see **Three defects the install path was hiding** below.

**One deliberate divergence.** The reference application is not responsive — below 600
logical pixels it keeps a 207px sidebar and the document overflows horizontally. This clone is
identical on desktop and genuinely adaptive below that, in four layout classes resolved from
available space.

## Three defects the install path was hiding

Building the library meant building a path from the user to an installed Bible for the first
time. Three real defects were on that path, and all three are recorded here because none of
them was visible from a test suite that never pressed the button.

**`build_module.dart` produced unreproducible hashes.** `ArchiveFile` defaults `lastModTime`
to the wall clock, and the tool never pinned it, so two builds of byte-identical content
produced different `sha256` values. The AMF contract requires the opposite. This is the
mechanism by which the catalog came to be wrong: a digest nobody can reproduce cannot be
checked by anyone — not by a rebuild, not by a CI double build, not by a user comparing a
download against the index. It could only be taken on faith. The rule now lives in
`logos-catalogs/lib/module_archive.dart` and is a unit test, including a control that proves
the property comes from the pin and not from the encoder being well behaved.

**The catalog's KJV entry described a module that was never published.** It declared
`38a18117…` (11,054,177 bytes) — the rebuilt module with cross-references — beside a
`downloadUrl` serving `c3b094c6…` (3,553,961 bytes), the old upstream build with no
`crossReferences` table and 27 chapters missing verse 1. An install would have failed on the
checksum, so the one real resource in the catalog could not be fetched. The entry now carries
the digest this repository actually builds — `6dbf144e…`, 11,054,191 bytes, reproducible —
which is the first digest here that anybody can verify.

**Seventeen of eighteen entries were installable on faith.** `sha256: "PLACEHOLDER_*"` is not
a hash, so there is no reference value to verify a download against — and the library offered
an `Instalar` button on every one. `isInstallable` now requires a cleared licence *and* a
well-formed digest, and refuses before the request, the same ordering the licence gate
already used. An integrity guarantee that is only a guarantee by faith is worse than none,
because it looks like one.

## Where things are

```
engine/            the Flutter application
logos-catalogs/    separate repository, linked as a sibling
docs/research/     analysis of the reference app, 12 captures, 1893 design tokens
docs/licensing/    the licensing audit and the content decisions
openspec/          spec-driven plan: 21 capabilities, 254 requirements, 603 scenarios
```

Read `docs/research/ANALYSIS.md` first — it is the index into everything else.

## The plan

Two OpenSpec changes, both validating in strict mode:

| Change | Scope | Tasks |
|---|---|---|
| `logos-flutter-clone` | Foundation: shell, adaptive layout, design system, library, reader, search, dashboard, tools | 94, 37 done |
| `logos-full-parity` | Feature parity: guides, workflows, notes, original languages, reference data, AI, sermon, reading programs, documents, media, layouts, settings, export, catalog | 271, 13 done |

Honest progress: **50 of 365 tasks.** The foundation runs and is tested; the rest of the
parity surface is specified but not built. The task lists mark only what is verified.

## Verification at this commit

```
engine              flutter analyze clean,  381/381 tests, 11 opt-in against the real KJV
logos-catalogs      dart analyze clean,      37/37 tests
openspec            both changes valid in strict mode
```

The opt-in tests run against a KJV built by the content repository from eBible's USFM and
CrossReferences' TSK export:

```
cd logos-catalogs
dart run tool/build_module.dart --usfm eng-kjv2006_usfm.zip --id KJV \
  --name "King James Version" --out dist \
  --xrefs crossreferences_kjv.tsv
cd ../engine
LOGOS_MODULE_DIR=../logos-catalogs/dist flutter test test/real_modules_test.dart
```

## Documentation worth reading

- `docs/research/ANALYSIS.md` — how the reference app works, and the two findings that shaped this
- `docs/research/EXISTING-REPOS-EVALUATION.md` — audit of `aletheia-platform` and `aletheia-catalog`, what was reused and what was rebuilt
- `docs/licensing/CONTENT-DECISIONS.md` — which texts, which commentaries, and the expiry analysis behind each
- `docs/licensing/PD-RESOURCES-INVENTORY.md` — 18 licensing traps, 12 items marked unverified
- `docs/research/FEATURE-INVENTORY.md` — the full Logos feature inventory, used as the scope contract

## Toolchain

Flutter 3.47.5 · Dart 3.13.4. `drift` resolves to 2.31.x; the `^2.23.0` floor in
`pubspec.yaml` is kept for the reader's API surface, not because 2.31 is out of reach.
The web build compiles clean and bundles the typeface.
