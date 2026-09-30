# Spec Delta

## Purpose

Define the reference and visual research layer — the Bible Encyclopedia with its lens ribbon, the
Atlas, the Advanced Timeline, the Explorer, Cited By, the Information Tool and the datasets that
back them.

## ADDED Requirements

### Requirement: Factbook entry resolution
The system SHALL resolve a Factbook entry from a person, place, event, thing, passage, topic,
lemma, sense or ancient text, and SHALL open the corresponding entry.

#### Scenario: Entry by person
- **WHEN** the user looks up a biblical person
- **THEN** that person's encyclopedia entry opens

#### Scenario: Entry by ancient text
- **WHEN** the user looks up an ancient text
- **THEN** that text's entry opens

#### Scenario: Unknown subject
- **WHEN** the subject has no entry
- **THEN** a not-found state is presented

### Requirement: Lens ribbon
The system SHALL provide a lens ribbon offering Library, Theological, Counseling and Discover
lenses, and SHALL switch the entry's content with the lens.

#### Scenario: Switching lens
- **WHEN** the user selects the Theological lens
- **THEN** the entry renders theological sections

#### Scenario: Lens is remembered
- **WHEN** the user opens a different entry
- **THEN** the same lens remains selected

### Requirement: Factbook section types
The system SHALL support the following Factbook section types: Dictionaries, Commentaries,
Cultural Concepts, Journals, Sermons, Preaching Resources, Books grouped by type or author, Factbook
Tags, Bible Book Guide, Biblical Events, Reported Speech, Church History Themes and Store.

#### Scenario: Commentaries section
- **WHEN** a Factbook entry renders its Commentaries section
- **THEN** relevant commentaries are listed for that subject

#### Scenario: Bible Book Guide
- **WHEN** the entry is a biblical book
- **THEN** the guide for that book is shown

#### Scenario: Church history theme
- **WHEN** the entry is a church-history theme
- **THEN** its timing, era, key developments, people, events, places, concepts and documents are
  shown

### Requirement: Ownership states
The system SHALL distinguish resources the user owns, resources they do not own but may preview,
and resources owned but not downloaded.

#### Scenario: Unowned resource
- **WHEN** a Factbook section lists a resource the user does not own
- **THEN** it is shown with a lock indicator and offers preview and acquisition

#### Scenario: Cloud resource
- **WHEN** a resource is owned but not downloaded
- **THEN** it is shown with a cloud indicator and downloads on first open

### Requirement: Atlas
The system SHALL present an interactive map relating biblical events to places, with a layer and
search sidebar, a map pane and a toolbar, and SHALL highlight the relevant area in the map accent
colour.

#### Scenario: Selecting a place
- **WHEN** the user selects a biblical place
- **THEN** the map centres on it with the area highlighted

#### Scenario: Events for a place
- **WHEN** a place is selected
- **THEN** the events associated with it are listed

#### Scenario: Map layers
- **WHEN** the user toggles a map layer
- **THEN** that layer appears or disappears

#### Scenario: Map unavailable
- **WHEN** map data cannot be loaded
- **THEN** the atlas reports the failure and the event list remains usable

### Requirement: Advanced Timeline
The system SHALL present a unified timeline with a date range, zoom, era presets for Bible and
Church history and for Western history, filters, grouping by subject, type or none, era headers
and expandable sub-events, and a details sidebar.

#### Scenario: Era preset
- **WHEN** the user selects the Western History era preset
- **THEN** the timeline renders that era's events

#### Scenario: Date range
- **WHEN** the user narrows the date range
- **THEN** only events within it are shown

#### Scenario: Grouping
- **WHEN** the user groups by subject
- **THEN** events are grouped under subject headings

#### Scenario: Expand a sub-event
- **WHEN** the user expands an event
- **THEN** its sub-events are shown

### Requirement: Explorer
The system SHALL provide an Explorer that follows the currently open Bible and presents
information about biblical events, people, places and things, media and commentaries for the
current passage.

#### Scenario: Explorer follows the Bible
- **WHEN** the user moves to a different passage
- **THEN** the Explorer content updates to that passage

#### Scenario: Explorer sections
- **WHEN** the Explorer is open
- **THEN** events, people, places, things, media and commentaries sections are available

### Requirement: Cited By
The system SHALL present references to a primary source across the library, split into Open Books,
Your Books, Collections and Series sections.

#### Scenario: Cited By sections
- **WHEN** the user opens Cited By for a source
- **THEN** the results are grouped into the four sections

#### Scenario: Empty section
- **WHEN** a section has no results
- **THEN** it is hidden or shown empty rather than omitted silently

### Requirement: Information Tool
The system SHALL present a context-sensitive panel with configurable sections including
Definition, Translation, Word Info, Literary Typing, Other References, Factbook Tags, Preaching
Themes, Highlights and Footnotes, and SHALL let sections be added, removed, reordered and copied.

#### Scenario: Context-sensitive content
- **WHEN** the user places the cursor on a term
- **THEN** the panel shows information for that term

#### Scenario: Section reordering
- **WHEN** the user reorders the panel sections
- **THEN** they render in the new order

#### Scenario: Copy all
- **WHEN** the user copies all panel content
- **THEN** the combined text of all visible sections is placed on the clipboard

### Requirement: Factbook tags
The system SHALL surface tags inline in resources, SHALL show a tag's definition on hover and open
its entry on activation, SHALL allow tags to be toggled off, and SHALL support filtering by tag
type including user-authored tags.

#### Scenario: Inline tag
- **WHEN** a resource contains a tagged term
- **THEN** the term is marked as a tag

#### Scenario: Toggle tags off
- **WHEN** the user turns tags off in formatting
- **THEN** the tag marks are not rendered

#### Scenario: User-authored tag
- **WHEN** the user filters tags by type user-created
- **THEN** only tags authored by users are listed

### Requirement: Bible browser
The system SHALL provide a faceted Bible search over categorized tags such as people and senses,
with verse-versus-pericope filtering and a visual filter, and SHALL support hovering a word to
see its morphology.

#### Scenario: Facet search
- **WHEN** the user searches by a category such as people
- **THEN** passages matching that category are returned

#### Scenario: Verse or pericope boundary
- **WHEN** the user constrains results to pericope boundaries
- **THEN** whole passages are returned rather than single verses

### Requirement: Dataset abstraction
The system SHALL expose the reference datasets — genre analysis, systematic theology cross
references, word senses, semantic roles, events, persons, places, things, saints, cultural
concepts, preaching themes, theological topics, figurative language, questions and answers,
speaker and addressee, milestone, sense-numbering, Strong's, lectionary and deuterocanonical
indices — behind a single provider interface, and each dataset SHALL document itself as a
readable manual entry.

#### Scenario: Dataset lookup by name
- **WHEN** the user looks up a dataset by name
- **THEN** its manual entry is presented

#### Scenario: Dataset unavailable
- **WHEN** a dataset has not been loaded
- **THEN** dependent features report the dataset as unavailable rather than failing silently

### Requirement: Bible books explorer
The system SHALL allow the sixty-six books to be compared by corpus, kind, author and recipient,
viewed as word-count blocks with genre slices, and placed on a composition timeline.

#### Scenario: Compare books
- **WHEN** the user selects several books
- **THEN** their corpus, kind, author and recipient are compared

#### Scenario: Genre slices
- **WHEN** a book is selected
- **THEN** its genre composition is shown as a proportion

#### Scenario: Composition timeline
- **WHEN** the timeline view is selected
- **THEN** the selected books appear by composition date
