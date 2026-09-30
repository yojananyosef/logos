# Spec Delta

## Purpose

Define the Bible reader — the core study surface — including chapter and verse navigation,
footnotes, navigable cross-references, text formatting, zoom, page view, the find bar and
full-screen reading, over a public-domain corpus.

## ADDED Requirements

### Requirement: Resource navigation
The system SHALL display a resource header showing the resource name, a `›` separator and the
current division, and SHALL allow navigating to any book, chapter and verse present in the
corpus.

#### Scenario: Header reflects position
- **WHEN** the user is reading John chapter 1 verse 1
- **THEN** the header shows the resource name, `›`, and `Chapter 1`

#### Scenario: Jump to a chapter
- **WHEN** the user selects a different chapter
- **THEN** the reader displays that chapter from its first verse
- **AND** the header updates to the new chapter

#### Scenario: Jump to a verse
- **WHEN** the user selects a specific verse
- **THEN** the reader scrolls to that verse
- **AND** the verse is brought into view

### Requirement: Verse rendering
The system SHALL render verse numbers inline with the text and SHALL allow the verse number
style to be toggled between visible, superscript and hidden.

#### Scenario: Verse number visibility
- **WHEN** the user changes the verse number style
- **THEN** the reader re-renders all verse numbers in the selected style without reloading
  the text

#### Scenario: Superscript rendering
- **WHEN** the verse number style is set to superscript
- **THEN** each verse number is rendered raised relative to the text baseline

### Requirement: Footnotes
The system SHALL display footnote markers inline in the text and SHALL reveal the corresponding
note when the marker is activated.

#### Scenario: Reveal a footnote
- **WHEN** the user activates a footnote marker
- **THEN** the note text is presented
- **AND** the marker is marked as read

#### Scenario: Footnote list
- **WHEN** the user opens the footnotes section of the toolbar
- **THEN** every footnote of the current chapter is listed in order

### Requirement: Cross-references
The system SHALL render cross-references as links in the link colour and SHALL navigate to the
referenced passage when one is activated.

#### Scenario: Follow a cross-reference
- **WHEN** the user activates a cross-reference
- **THEN** the reader navigates to the referenced book, chapter and verse
- **AND** the previous position can be returned to

#### Scenario: Cross-reference colouring
- **WHEN** cross-references are rendered
- **THEN** they use the link colour `#1E6AFE`
- **AND** they are visually distinguishable from body text

### Requirement: Text formatting
The system SHALL allow text size, line spacing, font family, colour scheme and text alignment
to be configured, and SHALL persist those settings.

#### Scenario: Font size change persists
- **WHEN** the user sets a larger text size, leaves the resource and returns
- **THEN** the same text size is applied

#### Scenario: Line spacing change
- **WHEN** the user increases line spacing
- **THEN** the distance between lines increases
- **AND** the change is applied without losing the reading position

#### Scenario: Colour scheme
- **WHEN** the user selects a different reading colour scheme
- **THEN** the background and text colours of the reading area change to that scheme

### Requirement: Zoom
The system SHALL allow the reader text to be increased and decreased, SHALL display the current
percentage, and SHALL keep the percentage within a defined range.

#### Scenario: Zoom readout
- **WHEN** the reader is displayed
- **THEN** a percentage readout is shown alongside the zoom controls

#### Scenario: Zoom bounds
- **WHEN** the user reaches the maximum zoom
- **THEN** the increase control becomes disabled
- **AND** the readout stops increasing

#### Scenario: Reset zoom
- **WHEN** the user resets the zoom
- **THEN** the text size returns to 100 percent

### Requirement: Page view
The system SHALL support a paged reading mode that presents the text in discrete pages with
explicit page navigation.

#### Scenario: Enable page view
- **WHEN** the user activates `Vista por páginas`
- **THEN** the text is presented as pages
- **AND** page navigation controls become available

#### Scenario: Page navigation
- **WHEN** the user advances a page
- **THEN** the next portion of the chapter is presented
- **AND** the page indicator updates

### Requirement: Find bar
The system SHALL provide a find bar that locates text within the current resource, highlights
every match and allows stepping between matches.

#### Scenario: Find a term
- **WHEN** the user enters a term in the find bar
- **THEN** every occurrence in the current resource is highlighted
- **AND** the match count is reported

#### Scenario: Step through matches
- **WHEN** the user activates the next-match control with matches present
- **THEN** the active match advances to the next occurrence
- **AND** the active match is scrolled into view

#### Scenario: No matches
- **WHEN** the entered term has no occurrences
- **THEN** the system reports that there are no matches
- **AND** no occurrence is highlighted

### Requirement: Full-screen reading
The system SHALL allow the reader to occupy the entire viewport and SHALL restore the previous
layout on exit.

#### Scenario: Enter full screen
- **WHEN** the user activates `Pantalla completa`
- **THEN** the reader fills the viewport
- **AND** the workspace chrome is not visible

#### Scenario: Exit full screen
- **WHEN** the user exits full-screen mode
- **THEN** the workspace chrome is restored
- **AND** the reading position is unchanged

### Requirement: Public-domain corpus
The system SHALL ship its corpus as bundled assets containing only public-domain works, and
SHALL read all content through a repository abstraction so the corpus can be replaced.

#### Scenario: Reading from the bundled corpus
- **WHEN** a Bible resource is opened with no network available
- **THEN** its text is read from the bundled assets

#### Scenario: Corpus is replaceable
- **WHEN** a different repository implementation is supplied
- **THEN** the reader renders content from that implementation without UI changes

#### Scenario: No protected commercial content
- **WHEN** the bundled corpus is inspected
- **THEN** it contains only public-domain texts
