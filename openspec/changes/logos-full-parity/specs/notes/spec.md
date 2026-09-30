# Spec Delta

## Purpose

Define the note-taking and highlighting system — notes, highlights, notebooks, structured labels,
anchoring to references, corresponding text across translations, sharing, export and the journal
workflow.

## ADDED Requirements

### Requirement: Notes tool layout
The system SHALL present the notes destination with a toolbar offering sidebar, search, share and
new-note actions, a collapsible sidebar with Filters and Notebooks tabs, a results panel and an
editor panel.

#### Scenario: Notes destination structure
- **WHEN** the user opens the notes destination
- **THEN** the sidebar, results panel and editor panel are all present

#### Scenario: Sidebar tabs
- **WHEN** the sidebar is opened
- **THEN** it offers Filters and Notebooks tabs

### Requirement: Note creation
The system SHALL allow a note to be created from a text selection, from a context menu, from a
resource's Notes toolbar section, from the notes tool, and from any guide section, and SHALL
support a new-note-on-selected-text action.

#### Scenario: Note from selection
- **WHEN** the user selects text and creates a note
- **THEN** the note is created containing the selection

#### Scenario: Note from guide section
- **WHEN** the user adds a note from a guide section
- **THEN** the note is anchored to that section instance

### Requirement: Note anchoring
The system SHALL support an active-reference anchor that picks up the currently open resource
automatically, and an explicit reference anchor, and SHALL allow multiple anchors per note.

#### Scenario: Active reference anchor
- **WHEN** the user creates a note while a passage is open
- **THEN** the note is anchored to that passage and the anchor text is captured

#### Scenario: Multiple anchors
- **WHEN** the user adds a second anchor to a note
- **THEN** the note lists both anchors

#### Scenario: Reference anchor across translations
- **WHEN** a note is anchored to a reference
- **THEN** the note is visible from that reference in every available translation

### Requirement: Note filtering
The system SHALL allow filtering notes by type, biblical book, reference, tag, author, anchor,
modified date and created date, and SHALL allow sorting with options that adapt to the active
filter.

#### Scenario: Filter by tag
- **WHEN** the user filters notes by a tag
- **THEN** only notes carrying that tag are listed

#### Scenario: Adaptive sort options
- **WHEN** a filter is active
- **THEN** the sort options offered are those valid for that filter

### Requirement: Notebooks
The system SHALL allow notes to be grouped into notebooks, SHALL offer the most recently used
notebooks plus a create action when assigning, and SHALL allow moving notes between notebooks.

#### Scenario: Assign to a notebook
- **WHEN** the user assigns a note to a notebook
- **THEN** the note belongs to that notebook

#### Scenario: Move a note
- **WHEN** the user drags a note into another notebook
- **THEN** it moves and appears in the destination notebook

#### Scenario: Empty notebooks
- **WHEN** a notebook contains no notes
- **THEN** the notebook is still listed with a count of zero

### Requirement: Labels
The system SHALL support structured labels of the form Name, Attribute, Value, and SHALL allow
labelling both notes and highlights.

#### Scenario: Apply a label
- **WHEN** the user applies a label to a highlight
- **THEN** the highlight records that name, attribute and value

#### Scenario: Filter by label
- **WHEN** the user filters by a label
- **THEN** only items carrying that label are listed

### Requirement: Highlighting
The system SHALL allow applying a highlight to a selection or to a whole verse or reference, and
SHALL provide a palette of highlight styles including the most recently used.

#### Scenario: Highlight a selection
- **WHEN** the user applies a highlight to a selection
- **THEN** the selected text is marked with that highlight style

#### Scenario: Highlight a whole verse
- **WHEN** the user highlights a verse reference
- **THEN** the entire verse is marked

#### Scenario: Recent highlight styles
- **WHEN** the user opens the highlight control
- **THEN** the most recently used styles appear first

### Requirement: Corresponding text
The system SHALL make notes and highlights visible in every translation that contains the
anchored text.

#### Scenario: Note appears in a parallel translation
- **WHEN** a note is anchored to a passage
- **AND** the user opens a different translation
- **THEN** the note indicator for that passage is present

#### Scenario: Corresponding highlight
- **WHEN** a highlight is anchored to a passage
- **THEN** the corresponding passage in another translation carries the same highlight

### Requirement: Note sharing
The system SHALL allow sharing a notebook publicly as a view-only link, and SHALL allow sharing
with a group with collaborative editing.

#### Scenario: Public share
- **WHEN** the user shares a notebook publicly
- **THEN** a view-only link is produced

#### Scenario: Group collaboration
- **WHEN** the user shares a notebook with a group with collaborate enabled
- **THEN** group members can edit the notes in it

### Requirement: Note export
The system SHALL support exporting notes and highlights to Rich Text, Plain Text, Web Page and PDF
or XPS, and SHALL support content-dependent additional formats including image, spreadsheet,
calendar and citation files.

#### Scenario: Export to plain text
- **WHEN** the user exports a notebook to plain text
- **THEN** a `.txt` file containing the note text is produced

#### Scenario: Export a reading plan to calendar
- **WHEN** the user exports a reading plan to calendar format
- **THEN** an `.ics` file is produced containing the scheduled sessions

### Requirement: Journaling
The system SHALL provide a journal workflow with a dedicated notebook, notes and icons set to
none, creation-date sorting, date anchoring and a templates notebook.

#### Scenario: Journal configuration
- **WHEN** the user opens the journal workflow
- **THEN** the journal notebook is active with notes and icons suppressed and ordering by
  creation date

#### Scenario: Date anchor
- **WHEN** the user anchors a journal note to a date
- **THEN** the note is filed under that date

### Requirement: Note trash and recovery
The system SHALL provide a trash view from which deleted notes and notebooks can be restored or
permanently removed.

#### Scenario: Restore a deleted note
- **WHEN** the user restores a note from the trash
- **THEN** the note returns to its notebook

#### Scenario: Permanent deletion
- **WHEN** the user permanently deletes a note
- **THEN** it is no longer recoverable
