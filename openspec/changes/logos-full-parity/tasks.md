# Tasks

Prerequisite: `logos-flutter-clone` is implemented and archived. This change builds on its
shell, theme, `LayoutClass`, catalog contract and `WorkspaceController`.

## 0. Repositories

- [ ] 0.1 Create the `logos-engine` repository with a pinned dependency on the catalog contract package, verified by a build that resolves the contract
- [ ] 0.2 Create the `logos-catalogs` repository with the contract package and the CLI, verified by both building
- [ ] 0.3 Define the contract's resource types, `ResourceRef`, `CatalogManifest` and `LibraryRepository`, verified by a test that a fake implementation satisfies the interface
- [ ] 0.4 Implement contract major-version compatibility checking, verified by a test rejecting an incompatible catalog with a clear error
- [ ] 0.5 Document the two-repository split, the contract boundary and the release-independence workflow in `docs/architecture.md`

## 1. Catalog and licensing

- [ ] 1.1 Implement the per-resource license manifest with `license`, `attribution`, `sourceUrl` and verification status, verified by a test per license class
- [ ] 1.2 Implement the build gate failing on an unresolved license, verified by a test naming the resource
- [ ] 1.3 Implement the build gate failing on a missing required attribution, verified by a test
- [ ] 1.4 Implement the build gate failing on a non-commercial license in a commercial build, verified by a test
- [ ] 1.5 Implement share-alike detection, catalog-level flag propagation and refusal to mix share-alike into a closed catalog, verified by tests per case
- [ ] 1.6 Implement temporal release gating by date and jurisdiction, verified by a test failing before the release date and outside the jurisdiction
- [ ] 1.7 Implement a licensed-resource exclusion list so licensed content never enters a distributable catalog, verified by a test
- [ ] 1.8 Implement content integrity verification by hash, verified by a test failing on mismatch
- [ ] 1.9 Implement reproducible builds from a pinned source manifest, verified by a test asserting two builds are byte-identical
- [ ] 1.10 Implement user-installable catalogs with install, replace, list and remove, verified by tests
- [ ] 1.11 Verify removing a catalog preserves notes, highlights and documents, verified by a test
- [ ] 1.12 Implement the application with no catalog installed, verified by a test asserting launch succeeds and every content surface reports absence without breaking
- [ ] 1.13 Implement the credits and attribution screen listing every resource with its license and source, verified by a widget test
- [ ] 1.14 Implement per-resource attribution discoverable from the resource, verified by a test
- [ ] 1.15 Implement the attribution block in exported documents where the source requires it, verified by a test asserting presence and absence
- [ ] 1.16 Record the expiry analysis or dedication for every shipped resource, verified by a test asserting each entry has a recorded basis
- [ ] 1.17 Record contested or unverified resources in an excluded list with reasons, verified by a test asserting no excluded resource appears in the shipped catalog
- [ ] 1.18 Document the licensing policy, the validation rules and how to add a resource in `docs/licensing/`

## 2. Corpus ingestion

- [ ] 2.1 Implement a USFM and morph-encoded USFM parser producing verses with word-level data, verified by a test on a known passage
- [ ] 2.2 Implement a SWORD module reader for the existing module distribution, verified by a test reading a known module
- [ ] 2.3 Implement verse-anchored commentary ingestion, verified by a test asserting verse anchors
- [ ] 2.4 Implement chapter-level commentary ingestion with declared granularity, verified by a test
- [ ] 2.5 Implement a Barnes-style inline verse-marker splitter, verified by a test asserting the expected number of verses extracted
- [ ] 2.6 Ingest the Biblia Platense behind the release date, verified by a test asserting the build refuses before 1 January 2027
- [ ] 2.7 Ingest Reina-Valera 1865 and the English public-domain parallels, verified by a test
- [ ] 2.8 Ingest the Westminster Leningrad Codex and SBLGNT, verified by a test asserting the recorded license
- [ ] 2.9 Ingest OSHB morphology with its mandatory attribution string, verified by a test
- [ ] 2.10 Re-derive Strong's from the 1890 archival scan and verify the build refuses the GPL-licensed alternative, verified by a test
- [ ] 2.11 Ingest the academic commentary set — Calvin, Keil & Delitzsch, Barnes, Clarke, JFB — each with genre and granularity declared, verified by a test per commentary
- [ ] 2.12 Verify the contested resources are excluded and recorded with reasons, verified by a test
- [ ] 2.13 Build academic public-domain commentary modules from archival sources with recorded provenance, verified by a test asserting source, edition and transcription method
- [ ] 2.14 Label every commentary with its genre so critical and devotional works are distinguishable, verified by a test
- [ ] 2.15 Verify RV1960 and every other copyrighted or licensed resource is absent from all catalogs, verified by a test asserting the shipped catalog contains no such entry

## 3. Tools taxonomy foundation

- [ ] 3.1 Define the functional tools taxonomy — Reference, Content, Lookup, Passage, Study, Notes, Utilities, Library — plus the pinned core tools, verified by a unit test asserting the groups and their members
- [ ] 3.2 Rewrite the tools destination to render the taxonomy with collapsible categories and pinned tools, replacing the flat web-app list, verified by a widget test asserting group order and pinning
- [ ] 3.3 Implement the tools menu search that filters tools by name, verified by a test
- [ ] 3.4 Migrate the existing seven tools into their functional groups, verified by a test asserting each is reachable from its group

## 4. Document store

- [ ] 4.1 Define the `Document` model with type, title, author, created and modified dates, and define the type catalogue of fifteen, verified by a test enumerating every type
- [ ] 4.2 Implement `DocumentStore` with list, create, open, delete, restore and permanently delete, verified by unit tests
- [ ] 4.3 Implement the documents destination with find, column sorting, a sidebar filter by type, author and modified date, and Public and Groups tabs, verified by widget tests
- [ ] 4.4 Implement the document trash, verified by a test restoring a deleted document
- [ ] 4.5 Persist documents locally and verify a test that creates, restarts and reopens with documents intact

## 5. Notes and highlighting

- [ ] 5.1 Implement the notes destination with sidebar, results panel and editor panel plus Filters and Notebooks tabs, verified by a widget test
- [ ] 5.2 Implement note creation from a selection, a context menu, the reader Notes section, the notes tool and a guide section, verified by a test per path
- [ ] 5.3 Implement active-reference and explicit-reference anchors with multiple anchors per note, verified by tests asserting anchor capture and listing
- [ ] 5.4 Implement automatic note metadata — book, resource, data type, created, modified, author — verified by a test asserting each field
- [ ] 5.5 Implement notebook assignment with recent-notebooks offering, creation and drag-to-move, verified by tests
- [ ] 5.6 Implement structured labels of Name, Attribute, Value for notes and highlights, verified by a test filtering by label
- [ ] 5.7 Implement highlighting of a selection or a whole verse with a palette and most-recently-used ordering, verified by a test
- [ ] 5.8 Implement note and highlight filtering by type, book, reference, tag, author, anchor, modified and created with filter-aware sort options, verified by a test asserting options change with the filter
- [ ] 5.9 Implement corresponding text so notes and highlights appear in every translation containing the anchored text, verified by a test with two translations open
- [ ] 5.10 Implement the rich text editor with formatting, note icon, note colour, highlight style and per-note palette, verified by a widget test
- [ ] 5.11 Implement public sharing and group sharing with collaborative editing, verified by tests
- [ ] 5.12 Implement the journal workflow with a dedicated notebook, notes and icons suppressed, creation-date ordering, date anchoring and a templates notebook, verified by a test
- [ ] 5.13 Implement note export to rich text, plain text, web page and PDF, plus calendar and citation formats where applicable, verified by tests asserting a file is produced

## 6. Guide engine

- [ ] 6.1 Define the guide section type catalogue of twenty-eight, verified by a test enumerating every type
- [ ] 6.2 Implement `GuideEngine` evaluating a section list against a subject, verified by a unit test over a stub section set
- [ ] 6.3 Implement section expand, collapse, reorder, remove and add, verified by tests
- [ ] 6.4 Implement per-section settings applied in isolation, verified by a test asserting other sections are unaffected
- [ ] 6.5 Implement opening a section standalone in a tab, verified by a test
- [ ] 6.6 Implement repeatable sections with independent scopes, verified by a test with two Collections sections
- [ ] 6.7 Implement empty and unavailable section states, verified by a test
- [ ] 6.8 Implement per-guide arrangement persistence, verified by a test navigating away and returning
- [ ] 6.9 Implement the five built-in guides with their default section lists, verified by a test per guide
- [ ] 6.10 Implement the guide editor for creating and saving custom guides, verified by a test creating, saving and reopening a guide
- [ ] 6.11 Implement preferred study Bible and preferred commentaries driving the Commentaries section, verified by a test
- [ ] 6.12 Implement commentary grouping with sort options and per-category limits, verified by a test
- [ ] 6.13 Implement notes created from guide sections anchored to that section instance, verified by a test

## 7. Workflows

- [ ] 7.1 Implement the step model with numbered major and minor steps, verified by a unit test asserting the numbering
- [ ] 7.2 Implement the prebuilt workflow catalogue grouped into Devotional Study, Bible and Topic Study, and Sermon Preparation, verified by a test enumerating the catalogue
- [ ] 7.3 Implement step content types — Document, Expandable Text, Question and Answer, Share Media, Share Text, Text, embedded tool or guide section — verified by a test per type
- [ ] 7.4 Implement step state of current, complete and skipped, verified by tests
- [ ] 7.5 Implement step content persistence as notes in a workflow notebook, verified by a test asserting the note is created and restored
- [ ] 7.6 Implement resume-where-you-left-off, verified by a test reopening an incomplete workflow
- [ ] 7.7 Implement in-progress workflow progress on the dashboard, verified by a widget test
- [ ] 7.8 Implement the workflow editor for custom workflows, verified by a test
- [ ] 7.9 Implement note filtering by workflow anchor and automatic biblical book anchoring, verified by a test

## 8. Dataset provider

- [ ] 8.1 Define `DatasetProvider` and the dataset catalogue, verified by a test enumerating every dataset
- [ ] 8.2 Implement public-domain extracts for genre analysis, word senses, semantic roles, persons, places, events and things, verified by a test loading each
- [ ] 8.3 Implement self-documenting manual entries for every dataset, verified by a test opening each dataset's manual
- [ ] 8.4 Implement the unavailable-dataset state surfaced to every consumer, verified by a test that a dependent feature reports it rather than failing silently
- [ ] 8.5 Document the dataset interfaces and how to load fuller data in `docs/datasets.md`

## 9. Original languages

- [ ] 9.1 Implement the traditional interlinear with independently toggleable translation, manuscript, lemma and morphology lines, verified by a test toggling each line independently
- [ ] 9.2 Implement interlinear line configuration persistence, verified by a test
- [ ] 9.3 Implement the reverse interlinear with original words beneath the translation in non-linear order, verified by a test asserting word order
- [ ] 9.4 Implement per-word form, lemma and morphology on activation in an interlinear, verified by a test
- [ ] 9.5 Implement morphology category selection highlighting all matching forms, verified by a test
- [ ] 9.6 Implement the morphology query builder including absence queries, verified by unit tests
- [ ] 9.7 Implement meaning-focused and theological lexicons with a prioritised lexicon for double-click, verified by a test changing the prioritised lexicon
- [ ] 9.8 Implement opening any lexicon for a lemma, verified by a test
- [ ] 9.9 Implement Strong's numbers with toggle and lexicon preview, verified by a test
- [ ] 9.10 Implement the sense lexicon with a sense tree, frequency by book, lemma lists and sense relationships, verified by a test
- [ ] 9.11 Implement search by sense, verified by a test asserting results are passages using that sense
- [ ] 9.12 Implement semantic domain exploration, verified by a test navigating domain to subdomain to word
- [ ] 9.13 Implement syntax search from templates and from scratch restricted to syntax-tagged texts, verified by tests
- [ ] 9.14 Implement clause graphics for syntax results, verified by a test
- [ ] 9.15 Implement field-scoped clause search including implied entities, verified by a test
- [ ] 9.16 Implement sentence diagrams in line and text-flow styles with per-word annotations, verified by a test per style
- [ ] 9.17 Implement textual variants, textual commentaries, apparatuses and ancient-version comparison, verified by a test per source
- [ ] 9.18 Implement lemmas in passage and other lemmas, verified by a test
- [ ] 9.19 Implement transliteration format configuration for Greek, Hebrew and Syriac and lemma auto-completion, verified by a test
- [ ] 9.20 Implement Greek and Hebrew keyboard input, verified by a test entering native characters

## 10. Search engines

- [ ] 10.1 Implement the search engine selector across All, Books, Bible, Factbook, Documents, Media, Maps, Factbook Tags, Morphology, Clause, Syntax, Smart and Store, verified by a test per engine
- [ ] 10.2 Extend the AST with a morphology-property node, verified by unit tests
- [ ] 10.3 Extend the AST with a field-scoped clause node, verified by unit tests
- [ ] 10.4 Extend the AST with a syntax-tree node restricted to tagged texts, verified by a test asserting untagged translations are excluded
- [ ] 10.5 Implement the advanced operator set — AND, OR, NOT, EQUALS, NOT EQUALS, INTERSECTS, THEN, BEFORE, AFTER, NEAR, WITHIN, milestone, label and parentheses — verified by unit tests per operator
- [ ] 10.6 Implement resource-scoped prefixes including bible, lemma, sense, milestone, place, topic, event, person and field matches, verified by a test per prefix group
- [ ] 10.7 Implement precise versus smart mode with automatic fallback for references, original-language and special-syntax queries, verified by tests
- [ ] 10.8 Implement the smart search node with semantic retrieval and reranking, verified by a test against a stub semantic index
- [ ] 10.9 Implement smart Bible search rendering every verse by lookup in the selected translation, verified by a test asserting text accuracy
- [ ] 10.10 Implement the Smart Synopsis with footnotes and claim-to-source mapping, verified by a test
- [ ] 10.11 Implement per-result summaries including for unowned resources, verified by a test
- [ ] 10.12 Implement Bible search result views — Passages, Aligned, Grid, Analysis, Fuzzy — with verse or chapter boundaries and multi-version, verified by a test per view
- [ ] 10.13 Implement search modifiers — match case, match all word forms, reference breadth — gated per engine, verified by a test asserting unsupported modifiers are not offered
- [ ] 10.14 Implement as-you-type search suggestions across topics, events, senses, persons, places, things and lemmas, verified by a test
- [ ] 10.15 Implement the text-or-entity choice in suggestions, verified by a test
- [ ] 10.16 Implement search templates producing queries, verified by a test using the both-terms template
- [ ] 10.17 Implement the store engine, verified by a test
- [ ] 10.18 Extend the Study search destination to launch any engine with the query prefilled, verified by a widget test

## 11. Reference data

- [ ] 11.1 Implement Factbook entry resolution from person, place, event, thing, passage, topic, lemma, sense and ancient text, verified by a test per entry kind
- [ ] 11.2 Implement the lens ribbon with Library, Theological, Counseling and Discover lenses and persistence, verified by a test
- [ ] 11.3 Implement Factbook section types including Dictionaries, Commentaries, Cultural Concepts, Journals, Sermons, Preaching Resources, Books, Factbook Tags, Bible Book Guide, Biblical Events, Reported Speech, Church History Themes and Store, verified by a test per section
- [ ] 11.4 Implement ownership states of owned, unowned with preview, and owned-not-downloaded, verified by a test per state
- [ ] 11.5 Implement inline Factbook tags with hover definition, activation, toggle-off and user-tag filtering, verified by a test
- [ ] 11.6 Implement the Atlas with a layer and search sidebar, map pane, toolbar and accent-coloured area highlight, verified by a test asserting the highlight colour
- [ ] 11.7 Implement the Atlas map-unavailable state keeping the event list usable, verified by a test
- [ ] 11.8 Implement the Advanced Timeline with date range, zoom, era presets, filters, grouping, era headers, expandable sub-events and a details sidebar, verified by a test per control
- [ ] 11.9 Implement the Explorer following the open Bible with events, people, places, things, media and commentaries, verified by a test
- [ ] 11.10 Implement Cited By grouped into Open Books, Your Books, Collections and Series, verified by a test
- [ ] 11.11 Implement the Information Tool with configurable sections, reordering and copy-all, verified by a test
- [ ] 11.12 Implement the Bible browser with faceted search, verse versus pericope boundaries and morphology hover, verified by a test
- [ ] 11.13 Implement the Bible books explorer with corpus, kind, author and recipient comparison, word-count blocks with genre slices and a composition timeline, verified by a test per view

## 12. AI layer

- [ ] 12.1 Define `AiProvider` with generate, ground and summarise, and implement `StubAiProvider` returning deterministic content, verified by a test running an AI feature with no key
- [ ] 12.2 Implement the AI credit accounting with a monthly allowance, usage display and exhausted notification, verified by a test
- [ ] 12.3 Implement inline citations with source resolution and source highlighting, verified by a test asserting every claim has a resolvable source
- [ ] 12.4 Implement footnote stepping in order, verified by a test
- [ ] 12.5 Implement the Study Assistant with conversation, scoping to catalogue or library, narrowing by collection, type, series or book, verified by a test per scope
- [ ] 12.6 Implement injecting current selection as context, verified by a test
- [ ] 12.7 Implement conversation management — recent, open, rename, delete, copy all — verified by a test
- [ ] 12.8 Implement answer feedback recording, verified by a test
- [ ] 12.9 Implement assistant entry points from toolbar, tools menu, selection explain, selection ask, Factbook and synopsis, verified by a test per entry point carrying context
- [ ] 12.10 Implement Summarize at article, chapter and book level, verified by a test per level
- [ ] 12.11 Implement Translate with tone preservation and line-by-line comparison, verified by a test
- [ ] 12.12 Implement Factbook Questions to Ask with inline answers and follow-up into the assistant, verified by a test
- [ ] 12.13 Implement Smart Synopsis generation with claim-to-source mapping, verified by a test
- [ ] 12.14 Implement the Study search destination's smart mode delegating to the smart node, verified by a test
- [ ] 12.15 Implement the no-provider state leaving the rest of the app unaffected, verified by a test

## 13. Sermon

- [ ] 13.1 Implement the sermon builder with Sidebar, Edit, Outline and Info sections producing manuscript, slides, handout and questions, verified by a widget test
- [ ] 13.2 Implement passage insertion with optional slide generation, verified by a test per combination
- [ ] 13.3 Implement block formatting — block paragraphs, one verse per slide, fully formatted — verified by a test per option
- [ ] 13.4 Implement verse number, red letter and version switch options, verified by a test
- [ ] 13.5 Implement editing a generated slide without altering the passage block, verified by a test
- [ ] 13.6 Implement sermon metadata of series, number, topics and references, verified by a test filtering by topic
- [ ] 13.7 Implement the Sermon Manager with week-grid and radial-calendar views, verified by a test per view
- [ ] 13.8 Implement bulk adding sermons from a template or a lectionary and season, verified by a test asserting the count
- [ ] 13.9 Implement bulk metadata editing, column and date filtering and a calendar overlay, verified by a test
- [ ] 13.10 Implement sermon templates supplying metadata, verified by a test
- [ ] 13.11 Implement Preaching Mode with an editable timer, one and two minute warnings, over-time state, paging or scrolling, three fonts, five sizes, five spacings and three margins, verified by a test per control
- [ ] 13.12 Implement Preaching Mode settings remembered per sermon, verified by a test
- [ ] 13.13 Implement `.docx` import with styles, headings to slides and parsed references, verified by a test
- [ ] 13.14 Implement batch `.docx` import, verified by a test
- [ ] 13.15 Implement the import report for unimported images, tables and hyperlinks, verified by a test
- [ ] 13.16 Implement sermon export to a presentation tool, to PDF and to a public link, verified by a test
- [ ] 13.17 Implement the sermon archive surfaced in guides and inline markers with preview, verified by a test

## 14. Reading programs

- [ ] 14.1 Implement reading plan creation for whole Bible, passage range, whole book and chapter range with front matter excluded, verified by a test per scope
- [ ] 14.2 Implement creation entry points from dashboard, manager, documents, an open book's tools and the library, verified by a test per entry point
- [ ] 14.3 Implement scheduling by start date, days of week, reminder time, and goals of finish-by, minutes per day, sessions, or no schedule, verified by a test per goal
- [ ] 14.4 Implement editing a plan after creation, verified by a test
- [ ] 14.5 Implement the in-text daily ribbon, section-end ribbon and end-of-session ribbon with mark done, verified by a test
- [ ] 14.6 Implement skip-to-latest marking missed days skipped, verified by a test
- [ ] 14.7 Implement toggleable margin indicators and a reminder button with distinct states, verified by a test
- [ ] 14.8 Implement progress states of on track, behind, skipped, complete and new, verified by a test per state
- [ ] 14.9 Implement archiving and restarting a plan, verified by a test
- [ ] 14.10 Implement sharing privately, with a group, by link and as a template, plus calendar export, verified by a test per mode
- [ ] 14.11 Implement the lectionary card with the next event and today's liturgical colour, verified by a test
- [ ] 14.12 Implement the lectionary layout with its five sections, verified by a widget test
- [ ] 14.13 Implement the sermon manager calendar overlay and series generation from a lectionary and season, verified by a test
- [ ] 14.14 Implement the daily devotional card and devotional layout with prayer list and date-matched entry, verified by a test
- [ ] 14.15 Implement prayer lists with recurrence, verified by a test

## 15. Media

- [ ] 15.1 Implement the media browser with sections for personal media, collections, online results, atlas and library, verified by a widget test
- [ ] 15.2 Implement multi-tag facets and sort by recently used, verified by a test
- [ ] 15.3 Implement the slide editor with font, size, colour, style, body text and resolution selector, verified by a test per control
- [ ] 15.4 Implement visual copy generating a slide from a selection, verified by a test
- [ ] 15.5 Implement slide export as an image, to a presentation tool, to PDF, by sharing and as an email attachment, verified by a test per target
- [ ] 15.6 Implement media upload with size limit and format preference and a clear rejection message, verified by a test per rejection case
- [ ] 15.7 Implement the Canvas with passages, freehand drawing, zoom, draggable text blocks, annotations and info cards, verified by a test
- [ ] 15.8 Implement canvas persistence as a document and export as an image, verified by a test
- [ ] 15.9 Implement Charts with multiple types, per-version toggling, count-per-book, zoom, aspect ratio, colour themes and image export, verified by a test per control
- [ ] 15.10 Implement sending a chart to a sermon slide, verified by a test
- [ ] 15.11 Implement graphic resources with thumbnails, full-size view and insertion into notes, verified by a test
- [ ] 15.12 Implement visual filters for books, Bible and morphology with scoping to a resource, a type or all of a type, verified by a test per scope

## 16. Layouts

- [ ] 16.1 Implement six tile arrangements applied to open panels, verified by a unit test per arrangement
- [ ] 16.2 Implement the arrangement with fewer panels than tiles without layout error, verified by a test
- [ ] 16.3 Implement the ten QuickStart layouts pre-populated with the appropriate resources, verified by a test per layout
- [ ] 16.4 Implement the missing-resource state in a layout, verified by a test
- [ ] 16.5 Implement saved layouts with naming and restore, verified by a test
- [ ] 16.6 Implement workspace snapshots with timestamped capture and restore, verified by a test
- [ ] 16.7 Implement the Get Started Wizard with activity selection and cancellation, verified by a test per activity and for cancellation
- [ ] 16.8 Implement layout and arrangement restoration across sessions, verified by a test
- [ ] 16.9 Implement dashboard column configuration, banner toggle and card add, rearrange and remove, verified by a test

## 17. Shell extensions

- [ ] 17.1 Implement the command box with grouped results and navigation, verified by tests for book, passage, topic, tool and command queries
- [ ] 17.2 Implement the new-tab panel with a reference-keyed mode and an everything mode, verified by a test per mode
- [ ] 17.3 Implement link sets binding panels to a shared reference, verified by a test
- [ ] 17.4 Implement Follow, Align and Scroll link-set modes, verified by a test per mode
- [ ] 17.5 Implement floating panels with float, dock, duplicate and full screen preserving state, verified by a test per operation
- [ ] 17.6 Implement the shortcut bar with add, reorder and one-action open, verified by a test
- [ ] 17.7 Implement panel close, move between tabs and reorder, verified by a test per operation
- [ ] 17.8 Implement multi-account profile switching and clearing other accounts, verified by a test
- [ ] 17.9 Implement synchronisation with a manual trigger and a failure warning, verified by a test
- [ ] 17.10 Implement the in-app store panel, verified by a widget test

## 18. Settings

- [ ] 18.1 Implement the settings destination covering every specified setting, verified by a test enumerating them
- [ ] 18.2 Implement per-setting application and persistence across sessions, verified by a test
- [ ] 18.3 Implement toolbar location left or top with shell reflow, verified by a test
- [ ] 18.4 Implement startup behaviour, verified by a test
- [ ] 18.5 Implement citation style selection applied to every generated citation, verified by a test
- [ ] 18.6 Implement interface language selection, verified by a test
- [ ] 18.7 Implement System, Light and Dark application themes and light, sepia and black reading appearances, verified by a test per option
- [ ] 18.8 Implement the selection menu with recent actions and user-defined actions including visual copy and explain, verified by a test
- [ ] 18.9 Implement reading preferences — double and triple click, selection behaviour, font, spacing, content scaling, resource background, verified by a test
- [ ] 18.10 Implement language keyboard selectors and transliteration format configuration, verified by a test
- [ ] 18.11 Implement hidden books and community ratings and tags toggles, verified by a test
- [ ] 18.12 Implement the searchable platform-scoped help centre, verified by a test
- [ ] 18.13 Implement the notification indicator and the AI credit ring states, verified by a test per state
- [ ] 18.14 Document every setting and its effect in `docs/settings.md`

## 19. Export and citation

- [ ] 19.1 Implement the export dialog with margins, columns, print-as-shown or as-exported, visible results only, fit-to-page and per-section, per-page or per-verse scope, verified by a test per control
- [ ] 19.2 Implement export to rich text, plain text, web page and PDF, verified by a test per format
- [ ] 19.3 Implement content-dependent exports to image, spreadsheet, calendar and citation files, verified by a test
- [ ] 19.4 Implement exporting a passage, selection, chapter or note from the reader and notes, verified by a test per source
- [ ] 19.5 Implement send to a new document and paste into an open document, verified by a test
- [ ] 19.6 Implement APA, Chicago, MLA and Turabian citation styles applied to generated citations, verified by a test per style
- [ ] 19.7 Implement deep links that open a resource at a position, verified by a test
- [ ] 19.8 Implement copy location with offline opening, verified by a test with the network disabled
- [ ] 19.9 Implement `.docx`, PDF and plain-text import, verified by a test per format
- [ ] 19.10 Implement library export to a spreadsheet, verified by a test
- [ ] 19.11 Implement per-platform export capability gating with a stated fallback, verified by a test

## 20. Reader extensions

- [ ] 20.1 Implement the reverse interlinear ribbon with toggle, verified by a test
- [ ] 20.2 Implement Strong's numbers inline with toggle, verified by a test
- [ ] 20.3 Implement textual variants displayed inline with variant readings, verified by a test
- [ ] 20.4 Implement opening a textual commentary from a variant, verified by a test
- [ ] 20.5 Implement corresponding text marking the corresponding position across translations, verified by a test
- [ ] 20.6 Implement the insights sidebar with Related Books, Related Passages, Cross References and Textual History, verified by a widget test
- [ ] 20.7 Implement insights card expand, collapse and remove, verified by a test
- [ ] 20.8 Implement read aloud with playback controls and voice selection, verified by a test
- [ ] 20.9 Implement verse, chapter and parallel passage navigation, verified by a test per mode
- [ ] 20.10 Implement passage block copy as styled, lines or plain text with block options, verified by a test per format
- [ ] 20.11 Implement the biblical events navigator positioned at the current passage, verified by a test

## 21. Library extensions

- [ ] 21.1 Implement library facets by type, subject, author, series, publisher, tag, language, corpus and user tag with combination, verified by a test
- [ ] 21.2 Implement facet counts, verified by a test
- [ ] 21.3 Implement collections with creation, membership and scoping of search, assistant, guides and Cited By, verified by a test per consumer
- [ ] 21.4 Implement custom series, verified by a test
- [ ] 21.5 Implement global priorization applied to guides, lookups, top Bibles and insight cards with reorder and reset, verified by a test
- [ ] 21.6 Implement top Bibles and a preferred study Bible used by guides, verified by a test
- [ ] 21.7 Implement parallel resource sets with stepping, verified by a test
- [ ] 21.8 Implement downloaded versus cloud grouping and cloud retrieval on open, verified by a test
- [ ] 21.9 Implement offline resources with list, make available and remove, verified by a test with the network disabled
- [ ] 21.10 Implement the print library catalogue and searching its contents, verified by a test
- [ ] 21.11 Implement personal books with conversion stages, a log, recompile and publish, verified by a test per stage and a failure case
- [ ] 21.12 Implement hiding books without uninstalling, verified by a test
- [ ] 21.13 Implement library export to a spreadsheet, verified by a test
- [ ] 21.14 Implement library search scoping to a collection, type or series, verified by a test

## 22. Parity audit

- [ ] 22.1 Re-run the feature inventory against the built application and record each item as implemented, partial or not implemented in `docs/research/parity-report.md`
- [ ] 22.2 Verify every capability in this change has a corresponding passing test, verified by `flutter test` with no failures
- [ ] 22.3 Run `flutter analyze` and verify it reports no issues
- [ ] 22.4 Re-run the responsive audit across all destinations at 360 to 1440 pixels and record results in `docs/research/responsive-audit.md`
- [ ] 22.5 Verify the app builds and runs with no network and no AI provider key, verified by a test
