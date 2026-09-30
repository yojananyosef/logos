# Spec Delta

## Purpose

Adds the non-basic search engines, visual filters, search templates and search suggestions to the
search capability established in `logos-flutter-clone`, whose syntax grammar and operator
semantics remain unchanged.

These are **ADDED** requirements rather than MODIFIED, because the search requirements live in
the `logos-flutter-clone` change and have not yet been promoted to a main spec.

## ADDED Requirements

### Requirement: Search engine selection
The system SHALL offer a search destination selectable between All, Books, Bible, Factbook,
Documents, Media, Maps, Factbook Tags, Morphology, Clause, Syntax, Smart and Store, and SHALL
run the query against the selected engine.

#### Scenario: Books engine
- **WHEN** the user runs a query in the Books engine
- **THEN** only non-scripture resources are searched

#### Scenario: All engine
- **WHEN** the user runs a query in the All engine
- **THEN** library, reference, media and document results are all included

#### Scenario: Engine restriction
- **WHEN** the user runs a syntax query
- **THEN** only syntax-tagged texts are searched
- **AND** untagged translations are not searched

### Requirement: Bible search result views
The system SHALL offer Bible search results as Passages, Aligned, Grid, Analysis and Fuzzy views,
and SHALL allow constraining results to verse or chapter boundaries and selecting one or more
versions.

#### Scenario: Grid view
- **WHEN** the user selects the Grid view
- **THEN** results are shown as a grid by book and chapter

#### Scenario: Verse boundary
- **WHEN** the user constrains results to verses
- **THEN** individual verses are returned rather than whole passages

#### Scenario: Version selection
- **WHEN** the user adds a second version
- **THEN** results can be shown in either version

### Requirement: Precise versus smart mode
The system SHALL support a precise engine and a smart semantic engine, and SHALL fall back to
precise when the query is a Bible reference, is entirely in an original language, or contains
special syntax.

#### Scenario: Automatic fallback
- **WHEN** the user submits a query that is entirely Greek
- **THEN** the precise engine runs rather than the semantic engine

#### Scenario: Explicit smart search
- **WHEN** the user explicitly chooses smart search
- **THEN** semantic ranking is used

### Requirement: Search modifiers
The system SHALL offer match case, match all word forms, and a reference-matching breadth of
Narrow, Default or Broad, and SHALL apply them where the selected engine supports them.

#### Scenario: Match case
- **WHEN** the user enables match case
- **THEN** only results matching case are returned

#### Scenario: Reference matching breadth
- **WHEN** the user selects Narrow reference matching
- **THEN** references must match closely to be included

#### Scenario: Unsupported modifier
- **WHEN** the selected engine does not support a modifier
- **THEN** that modifier is not offered for that engine

### Requirement: Search suggestions
The system SHALL provide as-you-type suggestions drawing on topics, events, senses, persons,
places, things, lemmas, and the choice between searching text and searching an entity.

#### Scenario: Lemma suggestion
- **WHEN** the user types a lemma prefix with a language prefix
- **THEN** matching lemmas are suggested

#### Scenario: Text or entity choice
- **WHEN** suggestions are shown
- **THEN** the user can choose to search the text or to search the entity itself

### Requirement: Resource-scoped search prefixes
The system SHALL support search prefixes scoping a query to a resource or an entity type,
including bible, lemma, sense, milestone, place, topic, event, person, speaker, addressee,
figure, cultural concept, preaching theme, theological topic, title, author, date and editor, and
SHALL support matching the same passage in another book.

#### Scenario: Topic prefix
- **WHEN** the user searches with a topic prefix
- **THEN** results are scoped to that topic

#### Scenario: Field match on title
- **WHEN** the user searches with a title match
- **THEN** only resources whose title matches are returned

### Requirement: Advanced operator set
The system SHALL support the advanced precise operators AND, OR, NOT, EQUALS, NOT EQUALS,
INTERSECTS, THEN, BEFORE, AFTER, NEAR, WITHIN with a word or character distance, milestone
restriction, label restriction, and parentheses grouping, alongside the basic operators already
specified.

#### Scenario: Distance within characters
- **WHEN** the user searches with a character distance
- **THEN** terms are matched within that character distance

#### Scenario: Grouping
- **WHEN** the user groups terms with parentheses
- **THEN** the grouped expression is evaluated as a unit

#### Scenario: Milestone restriction
- **WHEN** the user restricts a search to a milestone
- **THEN** only passages associated with that milestone are returned

### Requirement: Search templates
The system SHALL provide a form-based builder that produces a search query, with templates such as
both terms and this-before-that.

#### Scenario: Both-terms template
- **WHEN** the user uses the both-terms template
- **THEN** a query requiring both terms is produced
- **AND** the user can run it directly

### Requirement: Visual filters
The system SHALL provide visual filters for books, for the Bible and for morphology, built with
the same syntax as search and stored as documents, and SHALL apply them to readings as marks or
hidden text.

#### Scenario: Morphology visual filter
- **WHEN** a morphology visual filter is applied while reading
- **THEN** matching words are marked in the text

#### Scenario: Hide filtered text
- **WHEN** the filter is configured to hide rather than mark
- **THEN** matching text is not rendered

### Requirement: Search templates saved as documents
The system SHALL store a syntax search, a morphology query and a visual filter as retrievable
documents so they can be reopened and rerun.

#### Scenario: Rerun a stored query
- **WHEN** the user opens a stored search document and runs it
- **THEN** the stored query executes

### Requirement: Store search
The system SHALL allow searching the application's resource catalogue.

#### Scenario: Store search
- **WHEN** the user runs a query in the Store engine
- **THEN** matching catalogue entries are returned
