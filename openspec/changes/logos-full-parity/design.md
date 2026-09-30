# Design

## Context

Two changes, one direction. `logos-flutter-clone` builds the foundation: the workspace shell,
adaptive layout, design system, library, reader, search, dashboard and tools. This change takes
that foundation to **feature parity** with Logos across thirteen new capabilities.

The plan for that came from auditing the real product, not from memory. The parity research
pulled the full Logos help-centre corpus and the official platform-comparison matrix, and
produced a feature inventory that runs to well over a hundred discrete capabilities. Two findings
changed the design before any code was written:

**There is no Aiers feature.** The brief assumed a spaced-repetition flashcard system. Logos has
none — the search of all 330 help articles, logos.com and Reddit found nothing. The real analogue
is **Word List → Word Cards**: one-way printable cards, no SRS algorithm. Building an SRS engine
"for parity" would have been building something Logos does not have.

**The tool taxonomy is functional, not flat.** The web app's tools menu shows `Focused Atlas`,
`Text Comparison`, `Factbook`, `Media` — these are localized alternates. The desktop taxonomy
groups tools as **Reference, Content, Lookup, Passage, Study, Notes, Utilities, Library**. A clone
that mirrors the web menu gets the wrong information architecture; the functional grouping is what
users actually navigate.

Constraints carried from the foundation: no Faithlife backend, no licensed corpus, `AiProvider`
must work with no key, every feature must work offline, and **the application must launch and
operate with no catalog installed at all**.

The content decisions came out of a licensing audit, not preference, and two of them are
load-bearing for the architecture:

- **RVR1960 is excluded outright.** Copyrighted, renewed 1988, registered trademark, and the
  rights holder names mobile applications as requiring written permission. It is the version
  that appeared in the reference screenshots, which is precisely why the audit was necessary.
- **The Biblia Platense is not public domain until 1 January 2027.** Straubinger died in 1956;
  life+70 (Chile, Ley 17.336 art. 10; Spain; the EU) expires at the end of 2026. The United
  States runs to 2043 under the 95-years-from-publication rule for works of 1931–1977.
- **The academic commentary set is narrower than it first appears.** The entire universe of
  English SWORD commentary modules is 26. Of the commonly cited names, Matthew Henry, Wesley and
  Scofield are devotional or reference works rather than academic, and Robertson's Word Pictures
  was renewed and is not US public domain until 2029. The academic-grade set is Calvin
  (Calvin Translation Society translation, verse-anchored, 48 books), Keil & Delitzsch, Barnes,
  Clarke and JFB. A further tier of genuinely scholarly works — Bengel, Trapp, Gill, Poole,
  Ellicott, Lange, Neander, the ICC — is public domain but has no module and must be built from
  archival sources.
- **There is no public-domain Spanish commentary.** The widely circulated Spanish Matthew Henry is
  a 1983 translation by Francisco Lacueva, and Biblioteca de Autores Cristianos republishes
  ancient authors in modern copyrighted translations. Any Spanish commentary effort is a content
  budget question, not a licensing shortcut.

## Goals / Non-Goals

**Goals:**

- Every capability a Logos user can reach is reachable in the clone.
- The desktop tools taxonomy is the organising spine, not the web menu.
- Each phase lands a working application; parity is reached at the last phase, not the first.
- Nothing requires a network or an API key to build, test, or use the non-AI features.

**Non-Goals:**

- Replicating Faithlife's AI models. The requirement is the *shape* of the AI layer — grounded,
  cited, inspectable — behind a provider interface.
- Shipping Logos' full datasets. Morph tags, Strong's, Louw-Nida, genre analysis and Factbook are
  large; the clone ships public-domain extracts behind dataset interfaces.
- Replicating the subscription tiers and credit pricing, only the accounting shape.
- Multiplayer, sync services, or an in-app community.

## Decisions

### D0 — Two repositories, and a licensing gate in the build

**Choice:** two repositories — `logos-engine` (domain, UI, no scripture text) and
`logos-catalogs` (contract, catalogs, validation CLI) — and the CLI **refuses to build a
distributable catalog** when a resource has an unresolved license, a missing required
attribution, an incompatible use restriction, an unreached release date, or a share-alike
obligation in a closed-distribution target.

*Alternatives:*
- *Monorepo.* Rejected by the user in favour of independent release cycles, which is correct:
  content changes on license timelines, code changes on release cadence.
- *Content as app assets.* Rejected — it freezes content into the binary and blocks a
  user bringing their own licensed books.
- *A license check as documentation only.* Rejected — a checklist is not a control. Putting the
  check in the build path is what makes the risk fail before it reaches a user.
- *A remote content service.* Rejected for now; every feature would require a network.

**This design is load-bearing, not cosmetic.** The chosen Spanish text, the Biblia Platense
(Straubinger, d. 1956), is under copyright until **1 January 2027** in Chile, Spain and the EU,
and until 2043 in the US. Any design that couples content to the binary either stalls for three
months or ships infringing text. Decoupling means the application is built, shipped and fully
functional with whatever catalog exists, and the Spanish catalog joins a later release on the date
the license permits.

The share-alike check exists because of a specific finding: Robinson's morphological codes are
CC BY-SA in the CrossWire distribution, which would impose a share-alike obligation on derived
data. Share-alike is contagious, so a catalog mixing such content into a closed target must fail
rather than quietly inherit the obligation. The shipped catalog uses public-domain and CC BY 4.0
only, which are both clean for closed commercial distribution.

### D1 — Two changes, not one

**Choice:** `logos-full-parity` depends on `logos-flutter-clone` and carries the four overlapping
capabilities as **ADDED** deltas, not MODIFIED.

*Alternatives:* one monolithic change (unreviewable, and the foundation would have to be
re-specified as if it did not exist); MODIFIED deltas (rejected — the requirements they extend
are still inside an unarchived change, so there is no main spec to copy from, and MODIFIED with
partial content silently discards the foundation's detail at archive time).

**Consequence:** archive order is a hard dependency — `logos-flutter-clone` first, then
re-validate the delta against the promoted spec. Recorded in the proposal so it is not lost.

### D2 — The desktop tools taxonomy is the navigation spine

**Choice:** organise the tools menu by function — Reference, Content, Lookup, Passage, Study,
Notes, Utilities, Library — with the seven core tools pinned above the categories.

The web app's flat seven-item menu is the wrong shape to copy: it is a localized subset, and it
hides the fact that Lookup and Passage are distinct concerns. The functional grouping is what
Logos users have navigated for a decade, and it scales — adding a tool means adding it to a
category, not extending a flat list.

*Alternative:* mirror the web menu for simplicity. Rejected: it caps the clone at whatever the
web build exposes and produces a worse information architecture than the original desktop app.

### D3 — One `GuideEngine` behind five guides

**Choice:** Passage, Exegetical, Bible Word Study, Topic and Sermon Starter guides are **not five
implementations**. They are declarative section lists evaluated by one engine.

They share their whole model: an ordered stack of typed sections, each reorderable, removable,
configurable, persistable and openable standalone. Five separate implementations would be five
copies of the same section-stack logic drifting apart. The engine also makes the Guide Editor
almost free — a custom guide is a section list.

*Alternative:* a generic `SectionWidget` registry is the mechanism; the shared engine and
per-guide section lists are the decision. Not a plugin architecture — the section types are known
at build time, so a static registry beats runtime discovery.

### D4 — Documents are the storage primitive

**Choice:** unify Notes, Reading Plans, Sermons, Visual Filters, Syntax Searches, Morphology
Queries, Word Lists, Passages Lists and Prayer Lists on one `DocumentStore` with a `type` field,
rather than a bespoke store per type.

This mirrors Logos itself: the document menu lists fifteen types through one list, one filter
sidebar, one sort and one trash. The failure mode of per-type stores is fifteen lists to keep
consistent; the failure mode here is one list with a sealed set of editor widgets per type.

*Alternative:* typed sub-collections per feature. Rejected for the reason above.

### D5 — AI behind `AiProvider` with a stub default

**Choice:** define `AiProvider` with generate, ground and summarise operations. Ship
`StubAiProvider` that returns deterministic placeholder content, and make the whole app build and
test with no key.

Every AI requirement in `ai-features` is written as a *shape* requirement — citations present,
claims mappable to sources, fallback triggers — rather than an output-quality requirement. That
is the testable part. Output quality is not ours to specify.

*Alternatives:* wire a real provider now (a key becomes a build prerequisite and tests become
non-deterministic); skip AI (it is roughly a tenth of Logos' surface).

### D6 — Datasets behind one provider with public-domain extracts

**Choice:** a single `DatasetProvider` for genre analysis, systematic theology cross-references,
word senses, semantic roles, events, persons, places, things, saints, cultural concepts,
preaching themes, theological topics, figurative language, questions and answers, speaker and
addressee, milestone, Strong's, lectionary and deuterocanonical indices. Ship public-domain
extracts; each dataset documents itself as a manual entry.

One interface because every consumer — guides, search, reader, atlas — needs several datasets and
should not know which are loaded. The "documented as a manual" rule comes straight from Logos
and it forces each dataset to be genuinely inspectable rather than an opaque blob.

### D7 — Guides and workflows share the step model

**Choice:** one `StepModel` — numbered major steps, numbered minor steps, content types, state —
used by both guides and workflows.

They are the same shape: an ordered, nested, resumable sequence of authored content. The earlier
temptation was a separate `WorkflowEngine`; reusing the guide engine's section machinery with
step semantics is less code and makes "add a tool section as a workflow step" fall out for free,
which the spec requires anyway.

### D8 — Search stays one engine family, not fourteen

**Choice:** keep the foundation's lexer/parser/AST/inverted-index design as the single substrate,
and implement morph, clause, syntax and smart search as **new node types and evaluators** over it
— not as separate search systems.

Morphology adds a `MorphProperty` predicate node; clause adds a field-scoped clause node; syntax
adds a syntax-tree node; smart search adds a semantic retrieval node plus reranking. The
`Study search` screen is a launcher that pre-fills the box and switches the active node type.

*Alternative:* a separate semantic search service. Rejected — it would fork ranking, highlighting
and scoping, and the fallback rules (reference, original language, special syntax) only make
sense if both live in one pipeline.

### D9 — Notes use event-sourced-free simple store

**Choice:** a `NoteStore` with notebooks, notes, highlights, labels and anchors, persisted
locally, with corresponding-text propagation computed at read time rather than stored.

*Alternatives:* event sourcing (overkill for a local-first store, and it makes the corresponding
text invariant much harder to reason about); storing propagated highlights (goes stale the moment
a translation is added).

### D10 — Phased delivery, each phase runnable

Tasks are organised so that every phase ends with a working app. Phases 1–3 of the foundation
plus this change's phases 1–3 give a usable study environment; parity lands at the end.

*Alternative:* build all thirteen capabilities then integrate. Rejected: integration at the end
means failures cascade back through every phase.

## Risks / Trade-offs

- **Scope is very large** — thirteen capabilities plus four extensions. → Phased, each phase
  runnable, with the shell as the constant. Parity is a destination, not a first milestone.
- **"All features" is unbounded without a stopping rule.** → The stopping rule is the parity
  audit's inventory: anything in it is in scope, anything not is explicitly out. That list is the
  contract.
- **Dataset availability limits feature depth.** → Every consumer degrades to a reported
  "dataset unavailable" state rather than failing silently. Public-domain extracts ship; fuller
  data is a data task, not a code task.
- **AI parity is shape-only.** → Stated plainly rather than implied. Requirements cover citations,
  grounding, fallback and accounting — never output quality.
- **Two dependent changes can drift.** → Archive order is documented; the delta is re-validated
  after the foundation archives.
- **Personal books and print scanning are heavy.** → Both are scoped to their explicit
  requirements and land late, so the core is not blocked behind them.
- **Notes export to PDF/XPS on web.** → Export is capability-gated per platform, with a stated
  fallback rather than a silent no-op.
- **Search suggestion index size.** → Suggestions draw from the same inverted index as search;
  if entity datasets make it large, suggestions move to a background isolate.
