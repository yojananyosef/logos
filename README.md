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

**One deliberate divergence.** The reference application is not responsive — below 600
logical pixels it keeps a 207px sidebar and the document overflows horizontally. This clone is
identical on desktop and genuinely adaptive below that, in four layout classes resolved from
available space.

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
| `logos-flutter-clone` | Foundation: shell, adaptive layout, design system, library, reader, search, dashboard, tools | 94, 21 done |
| `logos-full-parity` | Feature parity: guides, workflows, notes, original languages, reference data, AI, sermon, reading programs, documents, media, layouts, settings, export, catalog | 271, 13 done |

Honest progress: **34 of 365 tasks.** The foundation runs and is tested; the rest of the
parity surface is specified but not built. The task lists mark only what is verified.

## Verification at this commit

```
engine              flutter analyze clean,  19/19 tests
logos-catalogs      dart analyze clean,      7/7 and 16/16 tests
openspec            both changes valid in strict mode
```

## Documentation worth reading

- `docs/research/ANALYSIS.md` — how the reference app works, and the two findings that shaped this
- `docs/research/EXISTING-REPOS-EVALUATION.md` — audit of `aletheia-platform` and `aletheia-catalog`, what was reused and what was rebuilt
- `docs/licensing/CONTENT-DECISIONS.md` — which texts, which commentaries, and the expiry analysis behind each
- `docs/licensing/PD-RESOURCES-INVENTORY.md` — 18 licensing traps, 12 items marked unverified
- `docs/research/FEATURE-INVENTORY.md` — the full Logos feature inventory, used as the scope contract

## Toolchain

Flutter 3.24.5 · Dart 3.5.4. `drift` is pinned to 2.23.x because 2.31 requires Dart 3.7.
