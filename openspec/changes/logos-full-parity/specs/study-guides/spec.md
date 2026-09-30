# Spec Delta

## Purpose

Define the guided research reports — Passage Guide, Exegetical Guide, Bible Word Study, Topic
Guide and Sermon Starter Guide — as composable stacks of reorderable, configurable, persistent
sections that a user can extend with their own sections.

## ADDED Requirements

### Requirement: Guide catalogue
The system SHALL provide Passage Guide, Exegetical Guide, Bible Word Study, Topic Guide and
Sermon Starter Guide, and SHALL open a guide for the passage or topic the user is at.

#### Scenario: Opening a guide for a passage
- **WHEN** the user opens the Passage Guide at a passage
- **THEN** the guide renders a report scoped to that passage

#### Scenario: Guide opens from a selection
- **WHEN** the user invokes a guide from a text selection
- **THEN** the selected text is used as the guide's subject

### Requirement: Guide sections
The system SHALL render each guide as an ordered list of sections, and SHALL provide the
following section types: Commentaries, Cross References, Systematic Theology, Biblical Theology,
Biblical People, Biblical Places, Biblical Events, Biblical Things, Media Resources, Journals,
Sermons, Sermon Documents, Outlines, Parallel Passages, Figurative Language, Thematic Outlines,
Illustrations, Topical Links, Textual Variants, Grammars, Grammatical Constructions, Lemma in
Passage, Important Words, Important Passages, Cultural Concepts, Bible Facts, Media Collections,
Atlas, Charts and Questions and Answers.

#### Scenario: Section renders content
- **WHEN** a guide containing a Commentaries section is opened
- **THEN** the section lists the relevant commentaries for the subject

#### Scenario: Repeatable sections
- **WHEN** the user adds a second Collections section scoped to a different collection
- **THEN** both Collections sections appear and each searches its own scope

#### Scenario: Empty section
- **WHEN** a section has no result for the current subject
- **THEN** the section renders an empty state rather than disappearing

### Requirement: Section composition
The system SHALL allow sections to be expanded, collapsed, reordered by drag, removed, and
opened standalone, and SHALL allow sections to be added to a guide.

#### Scenario: Reordering sections
- **WHEN** the user drags a section to a new position
- **THEN** the sections reorder to match
- **AND** the new order is persisted

#### Scenario: Collapsing a section
- **WHEN** the user collapses a section
- **THEN** its body is hidden and its heading remains visible

#### Scenario: Opening a section standalone
- **WHEN** the user opens a section standalone
- **THEN** the section renders in its own tab

#### Scenario: Removing a section
- **WHEN** the user removes a section
- **THEN** it no longer appears in that guide

### Requirement: Per-section settings
Each section SHALL expose its own settings, and the system SHALL apply them to that section only.

#### Scenario: Result count setting
- **WHEN** the user changes the results-per-category count on the Commentaries section
- **THEN** that section shows the new number of results
- **AND** other sections are unaffected

#### Scenario: Commentary sort
- **WHEN** the user sorts Commentaries by denomination
- **THEN** the commentaries are grouped and ordered by denomination

### Requirement: Guide persistence
The system SHALL reopen a guide in the last arrangement the user left it in.

#### Scenario: Arrangement survives navigation
- **WHEN** the user reorders and removes sections, navigates away and reopens the guide
- **THEN** the guide reopens with that same arrangement

### Requirement: Guide editor
The system SHALL allow a user to create a new guide from any available section type and save it
to their guide list.

#### Scenario: Creating a guide
- **WHEN** the user creates a guide and adds sections
- **THEN** the guide is saved and listed with the user's other guides

#### Scenario: Opening a custom guide
- **WHEN** the user opens a guide they created
- **THEN** it renders its saved sections for the current subject

### Requirement: Commentaries section behaviour
The system SHALL let the user mark a preferred study Bible and preferred commentaries, and the
Commentaries section SHALL reflect that prioritisation.

#### Scenario: Prioritised commentary appears first
- **WHEN** the user marks a commentary as preferred
- **THEN** it is listed before non-prioritised commentaries

#### Scenario: Group result limit
- **WHEN** commentaries are grouped by author with the default limit
- **THEN** each group shows at most the configured number of results

### Requirement: Notes from guide sections
The system SHALL allow a note to be created from any guide section, anchored to that section
instance.

#### Scenario: Note from a section
- **WHEN** the user adds a note from the top of a guide section
- **THEN** a note is created anchored to that guide section
- **AND** the note records which guide and section it came from
