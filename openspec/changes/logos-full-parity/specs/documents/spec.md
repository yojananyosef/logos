# Spec Delta

## Purpose

Define the document system — the full catalogue of creatable document types, each with its own
editor, creation paths, import, conversion, sharing and export.

## ADDED Requirements

### Requirement: Document type catalogue
The system SHALL support the following creatable document types: Bible Study, Bibliography,
Canvas, Clippings, Morphology Query, Passage List, Prayer List, Reading Plan, Sentence Diagram,
Sermon, Syntax Search, Visual Filter, Word Find Puzzle and Word List.

#### Scenario: Document list
- **WHEN** the user opens documents
- **THEN** every created document is listed with its type, author and modified date

#### Scenario: Filter by type
- **WHEN** the user filters documents by type
- **THEN** only documents of that type are listed

#### Scenario: Open a document
- **WHEN** the user opens a document
- **THEN** it opens in a tab with the editor for its type

### Requirement: Document menu
The system SHALL provide a find field, column sorting, and a sidebar filter by type, author and
date modified, and SHALL provide Public and Groups tabs.

#### Scenario: Sort by modified date
- **WHEN** the user sorts by modified date
- **THEN** documents are ordered by modification time

#### Scenario: Public tab
- **WHEN** the user opens the Public tab
- **THEN** publicly shared documents are listed

#### Scenario: Adopt a shared document
- **WHEN** the user gets a copy of a shared document
- **THEN** it is added to the user's own documents

### Requirement: Document creation paths
The system SHALL allow a document to be created from a reference, a selection, a search result, a
passage list, the clipboard, or an existing document of a convertible type.

#### Scenario: Create from a search result
- **WHEN** the user creates a document from a search result
- **THEN** the result is added to the new document

#### Scenario: Create from the clipboard
- **WHEN** the user creates a document from clipboard content
- **THEN** the clipboard content becomes the document body

### Requirement: Bibliography
The system SHALL generate a bibliography from milestones, collections, clippings, another
bibliography, selected text, or all open resources.

#### Scenario: Bibliography from all open resources
- **WHEN** the user creates a bibliography from all open resources
- **THEN** every open resource is cited in it

#### Scenario: Citation formatting
- **WHEN** a bibliography is generated
- **THEN** entries use the configured citation style

### Requirement: Clippings
The system SHALL collect clipped text with its source attribution, and SHALL convert clippings to
a passage list or to a bibliography.

#### Scenario: Clip with attribution
- **WHEN** the user creates a clipping
- **THEN** it records the source resource and reference

#### Scenario: Convert clippings
- **WHEN** the user converts clippings to a passage list
- **THEN** a passage list is created from the clippings' references

### Requirement: Passage List
The system SHALL hold an ordered list of passages, SHALL support notes per entry, and SHALL drive
verse comparison, word lists and reading from the list.

#### Scenario: Add a passage
- **WHEN** the user adds a passage to a list
- **THEN** it is appended in order

#### Scenario: Drive a reading session
- **WHEN** the user starts reading a passage list
- **THEN** each passage is presented in sequence

### Requirement: Word List
The system SHALL build a word list from references, resources, search results, passage lists,
selected text, the clipboard or another word list; SHALL support merging two lists showing overlap
or divergence; SHALL support grouping terms by a column; SHALL generate printable word cards; and
SHALL be shareable and exportable.

#### Scenario: Build from search results
- **WHEN** the user builds a word list from search results
- **THEN** the terms in those results form the list

#### Scenario: Merge lists
- **WHEN** the user merges two word lists
- **THEN** terms present in both are shown as overlap
- **AND** terms present in only one are shown as divergence

#### Scenario: Word cards
- **WHEN** the user generates word cards from a word list
- **THEN** printable cards are produced, one term per card

#### Scenario: Group by column
- **WHEN** the user groups terms by a chosen column such as occurrence count
- **THEN** the list is grouped by that value

### Requirement: Word Find Puzzle
The system SHALL generate a word-search puzzle from a word list or a passage, at small, medium,
large or extra-large size, with optional diagonal and backward placement, inline solving, a
solution reveal, and print or export.

#### Scenario: Generate a puzzle
- **WHEN** the user generates a puzzle from a word list
- **THEN** a puzzle grid containing every term is produced

#### Scenario: Reveal the solution
- **WHEN** the user reveals the solution
- **THEN** the placement of every term is shown

### Requirement: Morphology Query document
The system SHALL store a morphology query as a document built column by term and row by property,
and SHALL allow it to be reopened and rerun.

#### Scenario: Save a morphology query
- **WHEN** the user builds a morphology query and saves it
- **THEN** it appears in documents as a Morphology Query

#### Scenario: Rerun a saved query
- **WHEN** the user opens a saved morphology query and runs it
- **THEN** the search runs with the stored properties

### Requirement: Syntax Search document
The system SHALL store a syntax query as a document, and SHALL allow it to be reopened and rerun.

#### Scenario: Save a syntax query
- **WHEN** the user saves a syntax query
- **THEN** it appears in documents as a Syntax Search

### Requirement: Visual Filter document
The system SHALL store a visual filter as a document, SHALL allow it to be scoped to a resource, a
resource type or all resources of a type, and SHALL apply it to readings.

#### Scenario: Scope a filter to a resource
- **WHEN** the user scopes a visual filter to one resource
- **THEN** only that resource is filtered

#### Scenario: Apply while reading
- **WHEN** a visual filter is active
- **THEN** the filtered terms are marked or hidden in the open resource

### Requirement: Sentence Diagram document
The system SHALL store a sentence diagram as a document, and SHALL allow it to be reopened,
edited and exported.

#### Scenario: Save a diagram
- **WHEN** the user generates and saves a sentence diagram
- **THEN** it appears in documents as a Sentence Diagram

### Requirement: Canvas document
The system SHALL provide an infinite canvas for passages, freehand drawing, text blocks and info
cards linked to reference entries and word studies, and SHALL save the canvas as a document and
export it as an image.

#### Scenario: Place a passage
- **WHEN** the user places a passage on the canvas
- **THEN** the passage text appears as a block

#### Scenario: Info card
- **WHEN** the user adds an info card linked to a reference entry
- **THEN** activating the card opens that entry

#### Scenario: Export the canvas
- **WHEN** the user exports the canvas as an image
- **THEN** an image of the canvas is produced

### Requirement: Document trash and recovery
The system SHALL provide a trash from which deleted documents can be restored or permanently
removed.

#### Scenario: Restore a document
- **WHEN** the user restores a document from the trash
- **THEN** it returns to the document list
