# Spec Delta

## Purpose

Define the search experience — the query parser, the boolean and proximity operators, wildcard
handling, Bible reference syntax, result ranking and the syntax help panel that the real Logos
app shows when no query has been entered.

## ADDED Requirements

### Requirement: Search scopes
The system SHALL offer three search scopes matching the observed tabs: Todo, Biblia, Libros, and
SHALL scope results accordingly.

#### Scenario: Bible scope restricts to scripture
- **WHEN** the user selects the `Biblia` scope and runs a query
- **THEN** every result is a scripture passage

#### Scenario: Books scope restricts to monographs
- **WHEN** the user selects the `Libros` scope and runs a query
- **THEN** every result is a book or monograph

#### Scenario: Switching scope
- **WHEN** the user switches scope with a query already entered
- **THEN** results are re-run for the new scope without the user retyping the query

### Requirement: Boolean operators
The system SHALL support the basic operators observed in the Logos search help, with these exact
semantics: `O` (either), `Y` (both), `NO` (one but not the other), `ANTES` (one before another),
`DESPUES` (one after another) and `CERCA` (near, optionally with a distance).

#### Scenario: Either of two terms
- **WHEN** the user searches `Cristo O Jesús`
- **THEN** results match documents containing `Cristo` or `Jesús`

#### Scenario: Both terms required
- **WHEN** the user searches `Cristo Y Jesús`
- **THEN** results match only documents containing both terms

#### Scenario: Exclusion
- **WHEN** the user searches `Cristo NO Jesús`
- **THEN** results match documents containing `Cristo` and not `Jesús`

#### Scenario: Ordered proximity
- **WHEN** the user searches `Cristo ANTES Jesús`
- **THEN** every result contains `Cristo` occurring before `Jesús`

#### Scenario: Reverse ordering
- **WHEN** the user searches `Cristo DESPUES Jesús`
- **THEN** every result contains `Cristo` occurring after `Jesús`

#### Scenario: Near with distance
- **WHEN** the user searches `Cristo CERCA 5 Jesús`
- **THEN** every result contains both terms within five words of each other

#### Scenario: Unsupported operator is reported
- **WHEN** the user submits a query containing an unknown operator
- **THEN** the system reports the invalid operator and does not run the search

### Requirement: Exact phrase matching
The system SHALL treat a term enclosed in double quotes as an exact phrase.

#### Scenario: Quoted phrase
- **WHEN** the user searches `"hijo del Hombre"`
- **THEN** results match only that exact phrase

### Requirement: Wildcards
The system SHALL treat `*` as matching zero or more characters within a word and `?` as matching
exactly one character within a word.

#### Scenario: Prefix wildcard
- **WHEN** the user searches `Crist*`
- **THEN** results match `Cristo`, `Cristiano`, `Cristología` and similar

#### Scenario: Single character wildcard
- **WHEN** the user searches `s?n`
- **THEN** results match `sin` and `son` and not `sino`

#### Scenario: Wildcard is not a global match
- **WHEN** the user searches `Crist*`
- **THEN** results do not match words where `Crist` is not at the start, such as `Cristiana` after
  a prefix character

### Requirement: Bible reference queries
The system SHALL parse reference syntax of the form `Biblia:"Jn 3:16"` and SHALL resolve it to
the referenced passage.

#### Scenario: Inline reference in a query
- **WHEN** the user searches `Biblia:"Jn 3:16"`
- **THEN** the system resolves the reference to John chapter 3 verse 16
- **AND** results include that passage

#### Scenario: Chapter-wide reference
- **WHEN** the user searches `Biblia:"Juan 3"`
- **THEN** the system resolves the reference to all of John chapter 3

#### Scenario: Invalid reference
- **WHEN** the user submits an unparseable reference
- **THEN** the system reports that the reference is not valid

### Requirement: Search results presentation
The system SHALL present results with a title, the matched content with the query terms
highlighted, and enough context to judge relevance, and SHALL report the total result count.

#### Scenario: Highlighted matches
- **WHEN** results are displayed
- **THEN** each occurrence of a query term in the result snippet is highlighted

#### Scenario: Result count
- **WHEN** a search completes
- **THEN** the total number of matching results is reported

#### Scenario: No results
- **WHEN** no result matches
- **THEN** the system reports an empty result state
- **AND** suggests broadening the query

### Requirement: Syntax help panel
The system SHALL present a syntax help panel when the search field is empty, containing the
worked examples, the basic operators and the additional help links observed in the original.

#### Scenario: Empty field shows help
- **WHEN** the user opens the search destination with an empty field
- **THEN** the syntax help panel is displayed
- **AND** the results region is not shown

#### Scenario: Help content
- **WHEN** the syntax help panel is displayed
- **THEN** it shows the two-word example, the `O` example, the quoted phrase example, the
  `*` and `?` wildcard examples, the reference example, the basic operators section and the
  additional help section

#### Scenario: Example inserts into the field
- **WHEN** the user activates an example in the help panel
- **THEN** that example is placed in the search field
- **AND** the search can be run from there

### Requirement: Global passage and topic field
The system SHALL provide the `Pasaje o tema` field in the icon rail, which accepts a reference
or a topic and opens the appropriate destination.

#### Scenario: Reference opens the reader
- **WHEN** the user enters `Jn 3:16` in the `Pasaje o tema` field
- **THEN** the reader opens at John chapter 3 verse 16

#### Scenario: Topic opens search
- **WHEN** the user enters a topic phrase in the `Pasaje o tema` field
- **THEN** the search destination opens with that phrase as the query
