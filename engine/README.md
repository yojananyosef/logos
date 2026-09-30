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

Colours come from the 1893 `--bible-study-theme-*` custom properties captured from the
live application, not from a Material seed. `#154AC9` primary, `#030B60` navy, `#1E6AFE`
link, `#E7E7E7` borders, Source Sans Pro. See `lib/ui/core/theme/logos_colors.dart`.

## Tests

```
flutter test
```

19 tests, covering the layout classes and their boundaries, the slot policy, the absence
of horizontal overflow from 360 to 1440, the shell's chrome per class, and the tab
lifecycle including duplicate prevention and the return to the dashboard on closing the
last tab.

The overflow tests are the point of the layout work: they assert the rendered root is
exactly the window width at seven sizes, because a shell that merely looks right at one
size is not a responsive shell.

## Toolchain

Flutter 3.24.5 · Dart 3.5.4. `drift` is pinned to 2.23.x because 2.31 requires Dart 3.7.
