# logos-engine

The Logos workspace, in Flutter. One codebase for Android, iOS, web, Linux, macOS and
Windows.

Contains no scripture text. Content arrives through the `logos-catalogs` contract, which
is versioned and lives in its own repository — see
`../logos-catalogs` and `docs/research/EXISTING-REPOS-EVALUATION.md` for why.

## What is built

The workspace shell, reproduced 1:1 from the reference application: a 48dp icon rail with
the `Pasaje o tema` field, a collapsible sidebar carrying the nine destinations and the
quick-actions section, a resource tab strip, the six-section toolbar, the six-section
sub-toolbar, split panes, and the dashboard with its four card types.

## The one deliberate divergence

The reference application is **not responsive**. Below 600 logical pixels it keeps a
207px sidebar and the document overflows horizontally — verified at 360, 390, 768, 1024
and 1280 pixels, and captured in `docs/research/rw-*.png`.

This clone keeps the reference layout exactly on desktop and is genuinely adaptive below
that. Four layout classes, resolved from available space:

| Class | Width | Chrome |
|---|---|---|
| compact | `< 600` | drawer sidebar, bottom navigation, stacked panes, one card column |
| medium | `600–1023` | collapsible sidebar, stacked panes, two card columns |
| expanded | `1024–1439` | full sidebar, side-by-side panes, three card columns |
| large | `>= 1440` | the 1:1 reference layout, columns grow with the window |

`LayoutClass` is resolved in one place with `LayoutBuilder` and published through an
inherited widget, so no widget measures the screen independently and none can disagree
about the class.

## Architecture

Layered, following the Flutter architecture guidance:

```
lib/
├── domain/models/       catalogue contract, licences, references, workspace vocabulary
├── data/services/       AMF module reading, integrity checking
├── ui/
│   ├── core/            theme tokens, layout classes, base components
│   ├── features/*/      views/ + view_models/
│   └── app.dart
```

ViewModels are `ChangeNotifier`s registered through Riverpod, so the dependency-injection
container and the presentation-state pattern are both kept.

## The theme is generated, not transcribed

`lib/ui/core/theme/logos_colors.dart` is **generated**. Every colour is resolved from the
1890 `--bible-study-theme-*` custom properties captured from the live application, by name
rather than by value, and `test/theme_parity_test.dart` regenerates the file in memory and
fails if the committed values drift from the source.

```
dart run tool/generate_theme.dart            # regenerate
dart run tool/generate_theme.dart --check    # verify, exit 1 on drift
```

This is not a stylistic preference. Reading the theme by hand got the **active tab accent
wrong**: the reference uses `#FF6600` — orange, not the brand blue — because
`panel-tab-active-border-color` is a warm accent. A hand-written theme reaches for the
primary blue, and the result looks plausible while being wrong. The generator is what made
that finding visible, and the parity test is what stops it regressing.

Three provenance classes, kept separate on purpose:

| Class | Source | Example |
|---|---|---|
| `LogosColors` | a custom property, by name | `#FF6600` active tab accent |
| `LogosDimensions` | a custom property written as `Npx` | `4` button radius |
| `LogosMeasured` | measured from the rendered DOM | `48` icon rail width |

The reference **exposes no width tokens** for the rail or the sidebar, so those values are
measurements and are labelled as such. Listing them beside token-derived values would imply
a provenance they do not have.

`LogosSpacing` is a convention, not a transcription — the reference has no spacing tokens at
all. It is a 4dp lattice, recorded as such, because the clone adds surfaces the reference
does not have.

## The typeface

Source Sans 3 is bundled: Regular, Semibold, Bold, and two italics, ~1.9MB, SIL OFL 1.1 with
the licence text in `assets/fonts/OFL.txt`. Bundled rather than fetched, because the reader
has to work offline and a runtime font fetch would delay first paint.

The reference declares `'BrandLogos', 'Alaska', 'Source Sans Pro', sans-serif`. The first two
are Logos display faces that cannot be redistributed, so the third is substituted — which
affects display type only, since Source Sans Pro *is* the reference's body face. Adobe
renamed Source Sans Pro to Source Sans 3 upstream; it is the same typeface continued.

A test reads `pubspec.yaml`, checks every declared font file exists, and checks its sfnt
signature. A missing or 404-downloaded font otherwise fails only at runtime, on one
platform, as invisible fallback text.

## Tests

```
flutter test
```

92 tests across six files, plus an opt-in suite that runs against real published modules:

- `workspace_test.dart` — the layout classes and their exact boundaries, the slot policy,
  the absence of horizontal overflow from 360 to 1440, the shell's chrome per class, the
  tab lifecycle including duplicate prevention and the return to the dashboard on closing
  the last tab, and the tab indicator colour driven through the real interaction path.
- `theme_parity_test.dart` — the generated theme against its source; the specific
  transcribed values, each named; the font files and their signatures; the OFL text
  travelling with the font; the spacing lattice.
- `reference_capture_parity_test.dart` — the theme against the twelve captures of the live
  application, sampling the pixels the captures were taken to record.

The overflow tests are the point of the layout work: they assert the rendered root is
exactly the window width at seven sizes, because a shell that merely looks right at one size
is not a responsive shell.

Two real bugs were found by these tests rather than by reading the code: the sidebar
overflowed vertically at 1440×900, and the promo banner overflowed horizontally below
420px.

## Toolchain

Flutter 3.24.5 · Dart 3.5.4. `drift` is pinned to 2.23.x because 2.31 requires Dart 3.7.
