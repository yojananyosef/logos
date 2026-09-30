# Proposal

## Why

The `logos-flutter-clone` change delivers a faithful reproduction of the Logos **workspace shell**
— the rail, sidebar, tabs, split panes, reader, search and dashboard. But an audit of the real
product against that scope shows the clone would cover roughly a quarter of what Logos actually
does. Logos is not a Bible reader with a library attached; it is a research environment with
guided study, original-language analysis, a notes system, sermon production, reading programs,
visual reference tooling and an AI layer.

This change expands the target from *look like Logos* to **be Logos**: every capability a Logos
user can reach is specified, so the project ends with feature parity rather than a good shell.

## What Changes

Builds on the foundation in `logos-flutter-clone` (shell, adaptive layout, design system,
library, reader, search, dashboard, tools). Adds fourteen capabilities:

- **`content-catalog`** — the decoupled catalog: versioned contract, per-resource license
  manifest, build-time license validation, share-alike propagation detection, temporal release
  gating, attribution surfaces, user-installable catalogs and integrity checks. Lives in a
  separate repository from the application.
- **`study-guides`** — Passage Guide, Exegetical Guide, Bible Word Study, Topic Guide and Sermon
  Starter Guide as composable, reorderable, persistent section stacks, plus a Guide Editor.
- **`workflows`** — guided multi-step processes (Devotional Study, Bible & Topic Study, Sermon
  Preparation) with numbered major/minor steps, per-step note fields, step-state rings and
  resume.
- **`notes`** — notes, highlights, notebooks, structured labels, anchoring to references,
  corresponding text, sharing, export, and the journal workflow.
- **`original-languages`** — traditional and reverse interlinears, morphology, lexicons, Strong's,
  syntax and clause search, sentence diagrams, textual variants and apparatus.
- **`reference-data`** — Factbook with lens ribbon, Atlas, Advanced Timeline, Explorer, Cited By,
  Information Tool and the supporting datasets.
- **`ai-features`** — Study Assistant, Smart Search, Smart Synopsis, Summarize, Translate,
  Factbook Questions to Ask, Sermon Assistant and Bible Study Builder, all citation-grounded.
- **`sermon`** — Sermon Builder with simultaneous manuscript/slides/handout/questions, Sermon
  Manager calendar, Preaching Mode, templates and export.
- **`reading-programs`** — Reading Plan Manager with wizard and in-text ribbons, lectionary,
  daily devotionals and prayer lists.
- **`documents`** — the full document type catalogue with per-type editors, import and export.
- **`media`** — Media tool, slide editor, Canvas infinite workspace, Charts and graphic resources.
- **`layouts`** — six tile arrangements, nine QuickStart layouts, saved layouts, workspace
  snapshots and the Get Started Wizard.
- **`settings`** — the application settings surface, themes and per-user preferences.
- **`export-citation`** — print/export, citation styles and bibliography generation.

Extends four existing capabilities: `bible-reader` (interlinears, textual variants, corresponding
text, insights sidebar, read aloud), `search-syntax` (morph, clause, syntax and smart search;
visual filters; search templates), `library-browser` (collections, custom series, priorization,
personal books, print library) and `workspace-shell` (command box, layouts, link sets, new-tab
panel, floating panels).

**Corrections carried into the design**, from the parity audit:
- There is no Aiers or spaced-repetition flashcard feature in Logos. The real analogue is
  **Word List → Word Cards**, one-way printable cards with no SRS. The clone builds that.
- The labels observed in the web app's tools menu (`Focused Atlas`, `Text Comparison`,
  `Factbook`, `Media`, …) are localized alternates, not the desktop taxonomy. The clone follows
  the **desktop** taxonomy, which is grouped by function: Reference, Content, Lookup, Passage,
  Study, Notes, Utilities, Library.

**Content and licensing decisions**, fixed before implementation because they change the
architecture rather than follow from it:

- **Primary Spanish text is the Biblia Platense (Straubinger, 1948)** — the most rigorous scholarly
  Spanish translation, made from the Masoretic text, including the deuterocanonicals. It is
  **not in public domain until 1 January 2027** (author d. 1956, life+70) in Chile, Spain and the
  EU, and not in the US until 2043. This single fact is why the catalog is decoupled: the app
  ships and runs without it, and the catalog joins a later release on the date the license allows.
- **RVR1960 is excluded outright** — copyrighted, renewed 1988, and a registered trademark, with
  mobile applications named as requiring written permission.
- **Commentaries are the academic English public-domain set only** — Calvin (Calvin Translation
  Society translation), Keil & Delitzsch, Barnes, Clarke and Jamieson/Fausset/Brown. Matthew Henry,
  Wesley and Scofield are devotional or reference works and are excluded as such. Robertson's Word
  Pictures is excluded because it was renewed and is not US public domain until 2029.
- **Originals**: Westminster Leningrad Codex (public domain) for Hebrew, SBLGNT (CC BY 4.0) for
  Greek, OSHB (CC BY 4.0) for Hebrew morphology, Strong's 1890 re-derived from its archival scan.
  Robinson's codes are excluded because the CrossWire file is CC BY-SA and imposes a share-alike
  obligation.
- Decisions, expiry analyses and excluded items are recorded in `docs/licensing/`.

No breaking changes to the foundation; this change is additive and depends on it.

## Capabilities

### New Capabilities

- `content-catalog`: The decoupled content catalog — contract, license manifest, build-time
  license validation, share-alike detection, release gating, attribution, user-installable
  catalogs and integrity checks.
- `study-guides`: Composable research guides (Passage, Exegetical, Bible Word Study, Topic,
  Sermon Starter) built from reorderable, configurable, persistent sections, plus a guide editor.
- `workflows`: Multi-step guided processes with major/minor steps, per-step content types, step
  state, progress and resume.
- `notes`: Notes, highlights, notebooks, labels, anchoring, corresponding text, sharing, export
  and journaling.
- `original-languages`: Interlinear and reverse interlinear display, morphology, lexicons,
  Strong's numbers, syntax and clause search, sentence diagrams and textual criticism.
- `reference-data`: Factbook, Atlas, Advanced Timeline, Explorer, Cited By, Information Tool and
  the datasets that back them.
- `ai-features`: Citation-grounded AI — Study Assistant, Smart Search and Synopsis, Summarize,
  Translate, Factbook Questions to Ask, Sermon Assistant and Bible Study Builder.
- `sermon`: Sermon Builder, Sermon Manager, Preaching Mode, templates, metadata and export.
- `reading-programs`: Reading plans, lectionary, devotionals and prayer lists.
- `documents`: The full catalogue of creatable document types with editors, import and export.
- `media`: Media browser and search, slide editor, Canvas visual workspace, Charts and graphics.
- `layouts`: Tile arrangements, QuickStart layouts, saved layouts, snapshots and the wizard.
- `settings`: Application settings, themes and user preferences.
- `export-citation`: Print and export, citation styles and bibliography generation.

### Modified Capabilities

- `bible-reader`: Adds interlinear options, textual variants and apparatus, corresponding text,
  the insights sidebar, read aloud and passage-level navigation.
- `search-syntax`: Adds morphology, clause, syntax, factbook, media, docs and smart search,
  visual filters, search templates and search suggestions.
- `library-browser`: Adds collections, custom series, global priorization, top Bibles, personal
  books, print library, offline resources and export.
- `workspace-shell`: Adds the command box, layout switching, link sets, the contextual new-tab
  panel and floating panels.

All four deltas are written with **ADDED** requirements rather than MODIFIED, and each opens
with a `## Purpose` explaining why. The requirements they extend live in the unarchived
`logos-flutter-clone` change, so there is no main spec to copy an existing requirement block
from; MODIFIED would silently discard the foundation's detail at archive time. ADDED merges
correctly once both changes are archived. **Order matters: `logos-flutter-clone` must be
archived first**, and the delta must be re-validated against the promoted main spec.

## Impact

- **Depends on** `logos-flutter-clone` — every capability here is expressed in terms of the
  shell, theme, layout classes, catalog contract and workspace state established there.
- **Two repositories, as approved:**
  - `logos-engine` — domain models, search, guides, workflows, notes, AI contracts and the
    Flutter UI. Contains no scripture text. Depends on a pinned catalog contract version.
  - `logos-catalogs` — the catalog contract, the built catalogs, and a CLI that validates
    licenses, integrity, share-alike propagation and release dates before a catalog may ship.
- **New code** under `lib/features/`: `guides`, `workflows`, `notes`, `original_languages`,
  `reference_data`, `ai`, `sermon`, `reading_programs`, `documents`, `media`, `layouts`,
  `settings`, `export`.
- **New domain contracts**: `GuideEngine`, `WorkflowEngine`, `NoteStore`, `MorphologyService`,
  `LexiconService`, `DatasetProvider`, `AiProvider`, `DocumentStore`, `MediaStore`.
- **New dependencies**: a document/PDF rendering package for print export, a charting package
  for Charts, and a graph layout package for Canvas and Passage Analysis. AI access goes behind
  `AiProvider` with a stub default, so no provider key is required to build or test.
- **Dataset scope**: the chosen morphology and original texts are public domain or CC BY 4.0 with
  mandatory attribution, which the manifest carries. Fuller data can be added to the catalog
  repository without an application release.
- **Legal gate**: because the catalog tooling refuses to ship a resource with an unresolved
  license, a missing attribution, a share-alike conflict or an unreached release date, the
  licensing risk fails the build rather than reaching a user.
- **Size**: this is a large change. `tasks.md` is phased so each phase lands a working
  application; parity is reached at the final phase, not at the start.
