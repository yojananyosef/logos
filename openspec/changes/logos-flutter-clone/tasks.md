# Tasks

## 1. Project scaffold and toolchain

- [x] 1.1 Create the Flutter project with `flutter create --platforms=android,ios,web,linux,macos,windows --org cl.logos logos_app` and verify `flutter --version` and the six platform folders exist
- [x] 1.2 Add dependencies `flutter_riverpod`, `go_router`, `flutter_test`, `mocktail` and verify `flutter pub get` resolves cleanly
- [x] 1.3 Create the feature-first directory tree `lib/{app,core,features,shared}` and verify `flutter analyze` reports no issues
- [ ] 1.4 Bundle Source Sans Pro (regular, semibold, bold) into `assets/fonts/` with its OFL licence and verify the font loads in a widget test asserting the resolved family
- [ ] 1.5 Add a `tool/generate_theme.dart` that reads `docs/research/design-tokens.json` and emits the theme, and verify the generated output matches the committed `lib/core/theme/logos_colors.dart`

## 2. Design system

- [x] 2.1 Implement `LogosColors` and `LogosSpacing` with the exact token values from `specs/design-system/spec.md` and verify a unit test asserts each value against `design-tokens.json`
- [x] 2.2 Build the `ThemeData` from those tokens — Source Sans Pro, `#154AC9` primary, `#E7E7E7` borders — and verify a test asserts the primary is not the Material default
- [x] 2.3 Implement the active-tab indicator of 2 px `#154AC9` with `#F4F4F4` background and verify a widget test measures the border on the active toolbar section
- [ ] 2.4 Build base components (nav item, tab, toolbar section, card, banner, filter chip, reader panel) with default/hover/pressed/selected/focus/disabled states, verifying each state in a widget test
- [x] 2.5 Add a visible `#4797FF` focus ring and verify a widget test detects the focus indicator on keyboard traversal
- [ ] 2.6 Implement the limited-view (high contrast) mode and verify a test asserts contrast ratios meet WCAG AA in both normal and limited modes
- [ ] 2.7 Document the token mapping in `docs/design-system.md` and verify each documented colour resolves to a token present in `design-tokens.json`

## 3. Adaptive layout foundation

- [x] 3.1 Implement `LayoutClass` and the pure resolver with breakpoints `<600`, `600–1023`, `1024–1439`, `>=1440`, verified by a unit test covering boundary values 599/600/1023/1024/1439/1440
- [x] 3.2 Implement the `SlotPolicy` table from design D1 and verify a unit test asserts the expected policy for every class
- [ ] 3.3 Provide `LayoutClass` through a Riverpod provider and verify a widget test that changes the surface size observes the class change without losing workspace state
- [x] 3.4 Implement the compact drawer with the full sidebar content, verifying it overlays rather than displacing, closes on selection, and closes on back gesture
- [x] 3.5 Implement the compact bottom navigation with the nine destinations, verifying it replaces the rail and the expanded sidebar on compact only
- [x] 3.6 Add an overflow test harness that renders every screen at 360, 390, 600, 768, 1024, 1280 and 1440 px and asserts `scrollWidth == viewportWidth` for each
- [ ] 3.7 Document the breakpoint table and slot policy in `docs/adaptive-layout.md` and verify the documented breakpoints match `LayoutClass`

## 4. Workspace shell

- [x] 4.1 Implement the 48 px icon rail with the `Pasaje o tema` field and verify a widget test asserts the rail width
- [x] 4.2 Implement the sidebar with the nine destinations in order and verify a test asserts order, icons, labels and that exactly one is active
- [x] 4.3 Implement sidebar collapse/expand with persistence for the session, verified by a test that collapses, navigates and asserts the state is retained
- [x] 4.4 Implement the `Acciones Rápidas` section with the five entries, verifying each opens its resource in a new tab and that the comparison entry opens the comparison tool
- [x] 4.5 Implement the sidebar footer (Centro de ayuda, Entornos, Cerrar todos los paneles, session control), verifying `Cerrar todos los paneles` closes every tab and returns to the dashboard
- [x] 4.6 Implement the resource tab strip with name, accessibility badge and close control, verifying open/activate/close and that closing the last tab shows the dashboard
- [x] 4.7 Implement duplicate-tab prevention and horizontal scrolling with the active tab scrolled into view, verified by widget tests
- [x] 4.8 Implement the per-tab toolbar (Inicio, Búsqueda, Notas, Formato, Vista, Compartir, Más) and verify switching sections keeps the same tab active
- [x] 4.9 Implement the sub-toolbar (Contenido, Historia, Artículo, Conjunto de enlaces, Ideas, Información del libro), verifying each presents its panel
- [ ] 4.10 Implement the resource panel header with name, `›` separator, division and close control, verified by a test asserting the header text for a known position
- [ ] 4.11 Verify the shell against `docs/research/` by comparing a rendered screenshot of the shell to `nav-02-biblioteca.png` and recording the comparison in `docs/research/shell-parity.md`

## 5. Split panes

- [ ] 5.1 Implement `SplitPaneController` with `layout` and `fractions`, verified by unit tests for set and clamp
- [ ] 5.2 Implement the drag handle, verifying a drag updates the fractions and that the handle is not rendered when stacked
- [ ] 5.3 Apply the class policy — side by side on expanded/large, stacked on compact/medium — verified by tests at 1280 px and 360 px
- [ ] 5.4 Verify no horizontal overflow of the split area at every width in the harness from task 3.6

## 6. Corpus and library repository

- [ ] 6.1 Define the `LibraryRepository` interface in the domain layer, verified by a test that a fake implementation satisfies it
- [ ] 6.2 Build the `AssetLibraryRepository` reading bundled JSON, verified by a test loading a known resource and asserting its metadata
- [ ] 6.3 Add the public-domain corpus assets and verify a test asserts every bundled resource is flagged public domain
- [ ] 6.4 Build the in-memory inverted index with incremental construction, verified by a test asserting correct postings for a known term
- [ ] 6.5 Implement the chapter/verse pre-split cache and verify a test asserts O(1)-style lookup by book, chapter and verse
- [ ] 6.6 Document the repository interface and how to swap in a networked source in `docs/corpus.md`

## 7. Library browser

- [ ] 7.1 Implement the resource list with cover, title, subtitle and total count, verified by a test asserting the count matches the corpus
- [ ] 7.2 Implement the `Suyos` / `Tienda` / `por Título` filters, verifying each changes the list and the reported total
- [ ] 7.3 Implement search-as-you-type filtering by title and subtitle, verifying filtering, clearing and the no-match empty state
- [ ] 7.4 Implement grid and list view modes with persistence, verified by a test that switches, navigates away and returns
- [ ] 7.5 Implement opening a resource in a new tab, verifying that an already-open resource activates the existing tab instead of duplicating
- [ ] 7.6 Implement the responsive grid (1/2/3/3+ columns) and verify it in the overflow harness
- [ ] 7.7 Implement loading and recoverable error states with retry, verified by a test with a failing repository

## 8. Bible reader

- [ ] 8.1 Implement book/chapter/verse navigation and verify the header text for a known position
- [ ] 8.2 Implement inline verse numbers with visible, superscript and hidden styles, verified by a test re-rendering in each style
- [ ] 8.3 Implement footnote markers and reveal, verified by a test asserting the note text appears and the marker is marked read
- [ ] 8.4 Implement the chapter footnote list in order, verified by a test
- [ ] 8.5 Implement cross-references in `#1E6AFE` that navigate and support returning to the previous position, verified by a test asserting the restored position
- [ ] 8.6 Implement text formatting — size, line spacing, font, colour scheme, alignment — with persistence, verified by a test that changes, navigates away and returns
- [ ] 8.7 Implement zoom with percentage readout, bounds that disable the control, and reset to 100%, verified by tests
- [ ] 8.8 Implement page view with page navigation and a page indicator, verified by a test advancing pages
- [ ] 8.9 Implement the find bar with highlight, match count and next/previous stepping, verified by tests for found, no-match and stepping
- [ ] 8.10 Implement full-screen reading and restore, verified by a test asserting the reading position survives
- [ ] 8.11 Verify the reader works with no network and a swapped repository, verified by a test using a fake repository
- [ ] 8.12 Add a reading-measure constraint at wide viewports and verify a test asserts the text column does not exceed the maximum measure

## 9. Search

- [ ] 9.1 Implement the lexer and verify unit tests for terms, phrases, operators, wildcards and references
- [ ] 9.2 Implement the parser producing an AST and verify unit tests for each operator's precedence
- [ ] 9.3 Implement the evaluator over the inverted index and verify tests for `O`, `Y`, `NO`, `ANTES`, `DESPUES` and `CERCA n`
- [ ] 9.4 Implement quoted phrase matching, verified by a test that a non-exact match is excluded
- [ ] 9.5 Implement `*` and `?` wildcards, verified by tests including the non-prefix exclusion case
- [ ] 9.6 Implement `Biblia:"Jn 3:16"` reference resolution and verify tests for a verse, a chapter, and an invalid reference
- [ ] 9.7 Implement unknown-operator reporting, verified by a test asserting the error names the operator
- [ ] 9.8 Implement the Todo/Biblia/Libros scopes, verified by a test asserting result types per scope and re-running on scope change
- [ ] 9.9 Implement results with highlighted terms, match count and an empty state with a suggestion
- [ ] 9.10 Implement the syntax help panel with the required sections and example insertion, verified by a widget test
- [ ] 9.11 Wire the rail's `Pasaje o tema` field so references open the reader and topics open search, verified by tests for both

## 10. Home dashboard

- [ ] 10.1 Implement the dashboard skeleton with the heading `Panel de inicio` and the section order, verified by a widget test
- [ ] 10.2 Implement the promotional banner with primary background, CTA and dismissal persistence, verified by a test that dismisses, navigates and returns
- [ ] 10.3 Implement the `EXPLORAR` section heading and the four card types, verified by a widget test per card type
- [ ] 10.4 Implement card activation, verified by a test asserting the card destination opens
- [ ] 10.5 Implement `De su biblioteca` with cover, title, publisher and description, verified by a test, plus the empty state
- [ ] 10.6 Implement loading and error states with retry, verified by a test with a failing repository
- [ ] 10.7 Apply responsive card reflow and verify the dashboard in the overflow harness at 360 and 1440 px

## 11. Study tools

- [ ] 11.1 Implement the tools menu with the seven entries, icons and order, verified by a widget test
- [ ] 11.2 Implement the focused atlas with place list, `#FF6600` map highlight and passage list, verified by a test opening a passage
- [ ] 11.3 Implement version comparison with side-by-side panes, per-pane version change and synchronised scrolling, verified by tests
- [ ] 11.4 Implement courses with lesson count, progress tracking and completion, verified by a test
- [ ] 11.5 Implement documents with list, create and open plus the empty state, verified by tests
- [ ] 11.6 Implement the Bible encyclopedia with topic filtering, article opening and stable identifiers that avoid duplicates, verified by a test
- [ ] 11.7 Implement the information tool reporting version and public-domain provenance, verified by a test
- [ ] 11.8 Implement graphic resources with thumbnails and full-size view, verified by a test
- [ ] 11.9 Implement the launch behaviour — every tool opens in a tab, and closing the tab returns to the menu, verified by a test
- [ ] 11.10 Stack comparison panes vertically on compact and verify no horizontal overflow at 360 px

## 12. Navigation integration and parity audit

- [ ] 12.1 Wire `go_router` with serialised workspace state so the open tab set, active index, split ratio and per-tab toolbar section round-trip through the URL, verified by a test navigating back and forward
- [ ] 12.2 Verify deep-linking a serialised workspace state restores the same tabs and active tab, verified by a test
- [ ] 12.3 Run the full-screen overflow harness across all destinations at 360–1440 px and record the results in `docs/research/responsive-audit.md`
- [ ] 12.4 Verify every interactive control meets the 44 px touch target on touch platforms, verified by a test enumerating the primary controls
- [ ] 12.5 Verify orientation change preserves destination, tab and reading position, verified by a test
- [ ] 12.6 Run `flutter analyze` and `flutter test` and verify both pass with no issues
- [ ] 12.7 Compare final screenshots against `docs/research/` and record remaining visual deltas in `docs/research/parity-report.md`
