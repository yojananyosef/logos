# Spec Delta

## Purpose

Define the settings surface — application configuration, themes, user preferences and the
help and notification affordances that complete the shell.

## ADDED Requirements

### Requirement: Application settings surface
The system SHALL provide a settings destination covering: toolbar location, startup behaviour,
citation style, interface language, information tooltips, visual cues, keyboard selector, help
cards, lemma autocomplete, preferring local data, content and program scaling, resource
background, download windows, community ratings and tags, font and spacing, minimised toolbars,
double- and triple-click action, text selection, the selection menu, preferring lemmas,
transliteration format, hardware acceleration, logging, and hidden books.

#### Scenario: Settings are reachable
- **WHEN** the user opens settings
- **THEN** every listed setting is presented

#### Scenario: Setting takes effect
- **WHEN** the user changes a setting
- **THEN** the change is applied

### Requirement: Settings persistence
The system SHALL persist every setting across sessions, and SHALL synchronise settings across a
user's machines.

#### Scenario: Survive relaunch
- **WHEN** the user changes a setting and reopens the application
- **THEN** the setting retains its value

#### Scenario: Synchronisation failure
- **WHEN** synchronisation fails
- **THEN** the user is warned
- **AND** local settings remain usable

### Requirement: Toolbar location
The system SHALL allow the toolbar to be placed on the left or the top, and SHALL reflow the
shell accordingly.

#### Scenario: Move the toolbar
- **WHEN** the user changes the toolbar location
- **THEN** the shell reflows to the new toolbar position

### Requirement: Startup behaviour
The system SHALL allow the user to choose what opens at startup, and SHALL honour the choice.

#### Scenario: Startup opens a layout
- **WHEN** the user sets a saved layout as the startup target
- **THEN** that layout opens on launch

### Requirement: Citation style
The system SHALL allow a citation style to be chosen, and SHALL apply it to every generated
citation and bibliography.

#### Scenario: Apply the style
- **WHEN** the user changes the citation style
- **THEN** newly generated citations use the new style

### Requirement: Interface language
The system SHALL allow the interface language to be chosen, and SHALL apply it to interface
strings.

#### Scenario: Change language
- **WHEN** the user selects a different interface language
- **THEN** interface labels are rendered in that language

### Requirement: Themes
The system SHALL offer a System, Light and Dark application theme, and SHALL offer separate
light, sepia and black reading appearances for resources.

#### Scenario: Application dark theme
- **WHEN** the user selects the Dark application theme
- **THEN** the application chrome renders in dark mode

#### Scenario: Reading appearance
- **WHEN** the user selects the sepia reading appearance
- **THEN** resource backgrounds and text adopt the sepia scheme

### Requirement: Selection menu
The system SHALL show a selection menu with the most recently used actions, and SHALL allow
user-defined actions to be added and removed, including visual copy and explain.

#### Scenario: Selection menu on selection
- **WHEN** the user selects text
- **THEN** the selection menu appears with recent actions

#### Scenario: Custom action
- **WHEN** the user adds a custom selection action
- **THEN** it appears in the selection menu for future selections

### Requirement: Reading preferences
The system SHALL allow the user to configure double-click and triple-click behaviour, text
selection behaviour, font, spacing, content scaling and resource background, and SHALL apply
those preferences to readers.

#### Scenario: Double-click behaviour
- **WHEN** the user sets double-click to open a lookup
- **THEN** double-clicking an original-language word opens the lookup

#### Scenario: Content scaling
- **WHEN** the user increases content scaling
- **THEN** all interface content renders larger

### Requirement: Language input preferences
The system SHALL allow the user to configure keyboard selectors for Greek, Hebrew and other
supported languages, and the transliteration format for Greek, Hebrew and Syriac.

#### Scenario: Enable a keyboard
- **WHEN** the user enables the Greek keyboard selector
- **THEN** Greek characters can be entered

### Requirement: Hidden books and community data
The system SHALL allow resources to be hidden from the library without deletion, and SHALL allow
community ratings and tags to be shown or hidden.

#### Scenario: Hide a resource
- **WHEN** the user hides a resource
- **THEN** it no longer appears in the library
- **AND** it is still installed and searchable

#### Scenario: Toggle community data
- **WHEN** the user hides community tags
- **THEN** user-authored tags are not displayed

### Requirement: Help centre
The system SHALL provide a searchable help centre with content scoped to the current platform and
training videos.

#### Scenario: Platform-scoped help
- **WHEN** the user opens help from the web build
- **THEN** the results reflect features available on the web

#### Scenario: Help search
- **WHEN** the user searches the help centre
- **THEN** matching articles are listed

### Requirement: Notifications
The system SHALL show a notification indicator with a count, and SHALL report AI credit usage
through a visual ring that has a distinct state before first use, in use, and exhausted.

#### Scenario: Ring before first use
- **WHEN** the user has not used any AI features
- **THEN** the credit ring is not shown

#### Scenario: Exhausted credits
- **WHEN** the AI allowance is exhausted
- **THEN** the ring shows the exhausted state
