# Design

## Context

Greenfield project. Nothing exists in the repo yet except the OpenSpec change and
`docs/research/`, which holds the analysis of the real application, 12 reference screenshots and
the 1893 CSS custom properties captured from `app.logos.com`.

Constraints that shape the approach:

- **The reference is a desktop web app that does not scale.** Verified at 360–1440 px: below
  600 px the sidebar holds 207 px and the document overflows horizontally. The clone must be
  pixel-faithful on desktop and deliberately *not* faithful on mobile.
- **Corpus is off-limits until its license permits.** ~250 000 Logos titles are licensed by
  Faithlife and are permanently out of scope. The chosen Spanish text, the Biblia Platense, is
  itself under copyright until **1 January 2027**. The app must therefore build and run with a
  catalog that is absent, partial, or swapped — see D4.
- **One codebase, six platforms.** Android, iOS, Web, Linux, macOS, Windows.
- Flutter 3.47.5 / Dart 3.13.4. The project was written against 3.24.5 / 3.5.4 and moved to
  the current stable when the pinned SDK was no longer the one installed; the differences that
  mattered were `CardTheme` → `CardThemeData` in `ThemeData`, and `withOpacity` → `withValues`
  for alpha.

## Goals / Non-Goals

**Goals:**

- Desktop layout matches the reference exactly: same regions, same order, same metrics, same colours.
- Mobile is genuinely usable, which the reference is not.
- Content access sits behind one interface so the corpus can be replaced without UI churn.
- Deterministic, testable state: every navigation and layout decision lives in pure functions
  of state + viewport.

**Non-Goals:**

- Reproducing Logos' proprietary content, search index, AI assistant backend or account system.
- Byte-identical CSS cascade. Visual parity is the target, not DOM parity.
- Offline sync, multi-user collaboration, or any server component in this change.

## Decisions

### D1 — Adaptive shell over three separate layouts

**Choice:** one declarative shell driven by a `LayoutClass` computed from width, with
`compact | medium | expanded | large`, and per-class slot policies.

**Alternatives considered:**
- *Three independent screen trees.* Rejected: triples the UI surface and guarantees drift.
- *Flutter's built-in `LayoutBuilder` + `MediaQuery` only.* Rejected: it answers "what is the
  width" but not "what belongs in the rail versus the bottom bar versus the drawer". The
  reference has a genuine ambiguity — the sidebar, the rail and the bottom bar all compete for
  the same destinations on a phone — and an explicit slot policy is the only way to resolve it
  consistently.

The slot policy per class:

| Region | compact | medium | expanded | large |
|---|---|---|---|---|
| Icon rail | — | collapsed | full (48 px) | full |
| Sidebar | drawer overlay | collapsible | visible | visible |
| Bottom nav | yes | — | — | — |
| Panes | stacked | stacked | side by side | side by side |
| Card columns | 1 | 2 | 3 | 3+ |

**Consequence:** every widget must declare how it behaves per class. Enforced by a single
`LayoutClass` value threaded through providers, so no widget reaches for `MediaQuery` directly.

### D2 — Token-first theming from the captured CSS variables

**Choice:** generate the Flutter theme from `design-tokens.json` rather than hand-picking colours.

The source app exposes `--bible-study-theme-*` variables. 1893 of them, with exact hex values for
every state of every component. Hand-transcribing a subset would guarantee drift at the first
hover or disabled state. A generation step maps them into a `LogosColors` class plus
`ThemeData`, and the mapping is checked in so the build does not depend on the scraper.

*Alternative:* copy Material's seed-colour scheme. Rejected — it produces the wrong blue, the
wrong greys, and the wrong tab underline.

Dark mode is **not** generated: the source app ships a light theme only, and inventing a dark
palette would be a guess presented as parity. `ThemeMode.system` resolves to light until a
captured dark token set exists.

### D3 — Source Sans Pro bundled, not fetched

**Choice:** bundle the font files as assets.

*Alternatives:* `google_fonts` runtime fetch (breaks offline, adds a network dependency to
first paint, and the spec requires the reader to work with no network); system fallback only
(loses typography parity). Bundling is the only option that satisfies both parity and the
offline corpus requirement. `google_fonts` is still useful in dev to regenerate the files.

### D4 — Decoupled catalog in a separate repository

**Choice:** the app depends on a **versioned catalog contract**; the catalog lives in a
**separate repository** (`logos-catalogs`) alongside a CLI that validates licenses. The app
repository contains no scripture text.

*Alternatives:*
- *Content as app assets.* Rejected — content would be frozen into the binary, unable to update
  without an app release, and the user could not bring their own licensed books.
- *Monorepo with four packages.* Rejected in favour of two repos: content changes on license
  timelines, not on code cadence, and the two need independent release cycles.
- *A remote content service.* Rejected for now — it would make every feature require a network.

This is not a stylistic preference. The chosen Spanish text — the Biblia Platense, Straubinger
(d. 1956), published 1948 — **is not in public domain until 1 January 2027** under life+70. That
applies in Chile (Ley 17.336 art. 10), Spain and the EU; the United States runs to 2043. A design
that couples content to the binary cannot ship today and would have to either stall for three
months or ship infringing text. Decoupling means the app is built, shipped and fully functional
with whatever catalog is available, and the Spanish catalog joins a later release on the date the
license permits.

The contract is: resource types, a `ResourceRef`, a `CatalogManifest`, and a `LibraryRepository`.
Every resource carries `license`, `attribution`, `sourceUrl` and a verification status, because
those are the fields that decide whether it may be shipped at all.

Parsed content is cached in memory by resource id, and chapters are pre-split at load time so
verse-level rendering and cross-reference resolution stay O(1).

### D5 — Two-layer navigation with deep-linkable tab state

**Choice:** `go_router` for destination-level routes, with the open-tab set held in a single
`WorkspaceController` (Riverpod `Notifier`) as the source of truth for the tab strip.

*Alternatives:*
- *One route per tab.* Rejected: the reference's tabs are a set that survives navigation, and
  routes cannot express "tab 3 of 5, split 60/40" — the state would scatter across the route
  tree.
- *Pure local state.* Rejected: the reference's URLs carry the full workspace state, so
  deep-linking and back-navigation must work.

A single serialisable `WorkspaceState` (tabs, active index, split ratio, active toolbar section
per tab) is written to the URL query, which makes back/forward behave and makes any tab
shareable.

### D6 — Search parsed to an AST, evaluated over an inverted index

**Choice:** lexer → parser → AST → evaluator. Operators `O`, `Y`, `NO`, `ANTES`, `DESPUES`,
`CERCA n`, quoted phrases, `*` and `?` wildcards, and `Biblia:"Jn 3:16"` references, exactly as
the reference's help panel documents them.

*Alternatives:* regex-per-query. Rejected: `CERCA 5` with wildcards and phrase handling
composes badly into regex, and errors become user-hostile. An AST makes the unknown-operator
error required by the spec trivial to report, and makes `ANTES`/`DESPUES` expressible as
positional predicates.

An inverted index built once at startup from the corpus gives term lookup; `CERCA` and
`ANTES`/`DESPUES` post-filter candidates by position. The parser is pure and unit-tested
independently of Flutter.

### D7 — Split panes via a hand-rolled controller

**Choice:** a `SplitPaneController` with `layout` and `fractions`, rendering two flexible
children.

*Alternatives:* `flex_split` or a heavy pane library. Rejected — the reference's split is
simple, and the awkward part is not the drag handle but the class-dependent policy: side by
side on expanded/large, stacked on compact/medium, with **no handle at all** when stacked.
A policy-aware wrapper is less code than configuring a general-purpose library to that spec.

### D8 — Bounded card grid rather than a masonry package

**Choice:** a responsive `SliverGrid` with a column count derived from the layout class.

*Alternatives:* `flutter_staggered_grid_view` to reproduce the reference's masonry. Rejected —
the reference's home grid is a regular card grid with a couple of wide featured cards, and a
masonry package adds a dependency plus unbounded-height layout for a look we are approximating
anyway. Wide featured cards are expressed as a span of 2 or full width.

### D9 — Accessibility is structural, not bolted on

**Choice:** Semantics labels on every control, a real focus order, a visible `#4797FF` focus
ring, ≥44 px touch targets, and a limited-view mode that raises contrast.

The reference shows a persistent notice — *"Para acceder a este recurso con tecnología de
asistencia, active el modo de vista limitada en la configuración"* — which means the limitation
is a product feature to be represented, not just a checkbox. Contrast pairs are asserted in
tests so the palette cannot regress below AA.

## Risks / Trade-offs

- **Scope is large for one change** (8 capabilities, ~60 tasks) → the task list is phased with a
  runnable shell first, so every later phase has something to run against. Vertical slices beat
  finishing one layer at a time.
- **Visual parity drifts as Logos ships** → tokens are versioned in `design-tokens.json` with a
  capture script, so re-capturing and regenerating is a diff, not a re-audit.
- **Bundled font licensing** → Source Sans Pro is SIL Open Font License, which permits
  bundling; the licence file ships alongside the assets.
- **Corpus is much smaller than the original** → the UI must degrade gracefully with few
  resources; empty states are specified rather than left undefined.
- **Inverted index build time on large corpora** → build is incremental and off the first frame;
  if a future corpus makes it too slow, move it to a background isolate.
- **`go_router` URL state grows** → cap the serialised workspace state and fall back to defaults
  if the query string exceeds a safe length.
- **Generated theme drifts from the JSON** → a test asserts the committed `LogosColors` matches
  the values in `design-tokens.json`.

### D10 — Tasks 6.1–6.2 contradicted D4; resolved in favour of D4

The task list originally specified an `AssetLibraryRepository` reading **bundled JSON**
assets. That directly contradicts D4, which puts content in a separate repository behind a
versioned contract, and D4's own rejected-alternatives list names "content as app assets"
as a considered and rejected option.

D4 wins. What was built instead:

- `ModuleStore` — the directory holding installed `.amod` files.
- `ModuleInstaller` — verifies the catalog's sha256, checks the archive's entries, and
  writes atomically. Rejection leaves nothing on disk, so a later install cannot mistake a
  partial module for a finished one.
- `BibleRepository` — opens a module read-only, verifies `application_id` and
  `user_version` from the file's own pragmas before anything can query it, and runs the
  integrity check.
- `CatalogService` — parses a catalog index. An unrecognised licence resolves to
  *unresolved*, never to public domain: defaulting would turn a typo into a declaration
  that content is free to redistribute.

A JSON index is still read, but as the **catalog's** manifest, fetched at runtime rather
than compiled into the binary. The distinction is the whole point of D4.

### D11 — The catalog *index* is bundled; the catalog *content* is not

D10 drew the line at "no JSON index in the binary". Building §7 made that line untenable
in practice, and the reason is worth writing down rather than quietly crossing.

**The problem.** The catalog lives in a separate repository and there is no server. Before
this decision the engine had no way to obtain a catalog at all: `LibraryViewModel.load()`
was never called by anything, so the Biblioteca destination was a permanent spinner. Every
other answer — ship a server, require the user to hand-place a `catalog.json`, infer the
catalog from whatever `.amod` files are on disk — makes the first run either require a
network (which D4 explicitly rejects) or require a manual file copy (which is the defect
this section exists to remove). An application that lists nothing and installs nothing is
indistinguishable from a broken one.

**The choice.** The catalog **index** is bundled as an asset. The catalog **content** — the
`.amod` payloads — is still fetched, hash-verified and installed exactly as before.

**Why this is not D4.** The boundary D4 protects is scripture in the binary. An index is
metadata: resource names, licences, hashes, URLs, sizes. It contains no text of any work.
`test/catalog_sync_test.dart` asserts that the engine repository's index agrees, field for
field, with the content repository's — so the copy is demonstrably a copy, and the two
cannot drift silently.

**What it costs, stated plainly.** A bundle cannot be refreshed without a release. When the
content repository publishes a seventeenth real module, users do not see it until the engine
ships. That is a real regression against D4's ideal and it is the price paid for a
first-run experience that works. Two things bound it:

- `tool/sync_catalog.dart` generates the asset from the content repository, and
  `catalog_sync_test.dart` fails the build if the committed copy has drifted. Staleness
  cannot accumulate silently; it fails a test.
- `LibraryViewModel.load` treats a missing or unreadable catalog as a supported state and
  falls back to the installed set. The bundle is an improvement, not a dependency, so
  removing it degrades the library rather than breaking the application.

**The alternative if this proves wrong.** A `CatalogSource` interface already exists in
spirit — `configureCatalog(String?)` is a provider override, and `main` is the only place
that reads the asset. Pointing the application at a network catalog is a change to one
provider, not to the library.

### D12 — Integrity is a second gate on installation, beside the licence

The licence gate answers *may this engine fetch the bytes*. It never answered *can it trust
what arrives*. Seventeen of the eighteen entries in the catalog declare
`sha256: "PLACEHOLDER_*"` — not a hash, so there is no reference value to verify a download
against. The library was offering an `Instalar` button on all seventeen, which is an
integrity guarantee by faith, and a faith-only guarantee is worse than none because it looks
like one.

`LibraryEntry.isInstallable` therefore requires both a cleared licence and a well-formed
digest, and `install` refuses before the request rather than after the download — the same
ordering the licence gate already used, for the same reason: fetching first and declining
afterwards means the application has already pulled the content onto the device in order to
then refuse it.

*Rejected:* a separate `available: true/false` flag in the catalog. It would be a second
source of truth that a catalog edit could set to `true` on a row whose hash is still a
placeholder, and the failure would only appear as a checksum mismatch after the whole
download.

### D13 — A module archive is byte-reproducible, and the rule is unit-tested

The AMF contract requires that two builds of the same content produce the same `sha256`,
achieved by pinning archive timestamps to the DOS epoch. `build_module.dart` never did this:
`ArchiveFile` defaults `lastModTime` to the wall clock, so every build of byte-identical
content produced a different digest.

This is not a curiosity, it is the mechanism by which the catalog came to be wrong. A digest
nobody can reproduce cannot be checked by anyone — not by a rebuild, not by a CI double
build, not by a user comparing a downloaded module against the index. The value could only be
taken on faith, and faith is how `38a18117…` came to sit in the catalog describing a module
that was never published, beside a URL serving a different file.

The rule now lives in `lib/module_archive.dart` rather than inline in the CLI, because a rule
that can only be checked by producing an eleven-megabyte artefact and building it twice is a
rule that gets broken silently. `logos-catalogs/test/module_archive_test.dart` asserts the
property directly, and includes a control — an unpinned entry — that demonstrates the
property comes from the pin rather than from the encoder being well behaved.
