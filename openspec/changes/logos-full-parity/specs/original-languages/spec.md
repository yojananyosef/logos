# Spec Delta

## Purpose

Define the original-language analysis layer — interlinear and reverse interlinear display,
morphology, lexicons, Strong's numbers, syntax and clause search, sentence diagrams and textual
criticism — that underpins Logos' scholarly study.

## ADDED Requirements

### Requirement: Traditional interlinear
The system SHALL support an interlinear display with independently toggleable lines for the
translation, the manuscript or original text, the lemma form and the morphology, and SHALL allow
choosing which lines are shown.

#### Scenario: Toggling lines
- **WHEN** the user turns off the morphology line
- **THEN** the interlinear renders without that line
- **AND** the other lines are unchanged

#### Scenario: Line selection persists
- **WHEN** the user sets a line configuration and reopens the Bible
- **THEN** the same lines are displayed

#### Scenario: Keyboard toggle
- **WHEN** the user invokes the interlinear toggle
- **THEN** the interlinear appears or disappears

### Requirement: Reverse interlinear
The system SHALL present a reverse interlinear that shows the modern translation above the
original words placed beneath in non-linear order.

#### Scenario: Reverse interlinear display
- **WHEN** the user enables a reverse interlinear
- **THEN** each verse shows the translation with the original words beneath in their out-of-order
  position

#### Scenario: Tap an original word
- **WHEN** the user activates an original word in a reverse interlinear
- **THEN** the form, lemma and morphology for that word are shown

### Requirement: Morphology
The system SHALL expose morphological analysis for each original-language word, SHALL allow
selecting a morphology category to highlight all matching forms in the text, and SHALL support a
morphology query builder.

#### Scenario: Highlight a morphology category
- **WHEN** the user selects a morphology category
- **THEN** every word in the text sharing that category is marked

#### Scenario: Morphology query builder
- **WHEN** the user builds a query from morphology properties
- **THEN** results match documents satisfying all specified properties

#### Scenario: Query for absence
- **WHEN** the user builds a query specifying a morphology property must be absent
- **THEN** results match documents where that property does not occur

### Requirement: Lexicons
The system SHALL provide meaning-focused lexicons and theological lexicons, SHALL prioritize
one lexicon for double-click lookup, and SHALL allow any lexicon to be opened for a lemma.

#### Scenario: Double-click lookup
- **WHEN** the user double-clicks an original-language word in a prioritised lexicon's language
- **THEN** the prioritised lexicon's entry for that lemma opens

#### Scenario: Choosing the prioritised lexicon
- **WHEN** the user changes which lexicon is prioritised
- **THEN** subsequent double-click lookups use the new one

#### Scenario: Opening a different lexicon
- **WHEN** the user opens a non-prioritised lexicon for a lemma
- **THEN** that lexicon's entry is shown

### Requirement: Strong's numbers
The system SHALL display Strong's numbers in the interlinear, SHALL allow toggling them, and
SHALL show a preview from the prioritised lexicon on hover or activation.

#### Scenario: Toggle Strong's
- **WHEN** the user toggles Strong's numbers
- **THEN** the numbers appear or disappear in the interlinear

#### Scenario: Strong's preview
- **WHEN** the user activates a Strong's number
- **THEN** the entry from the prioritised lexicon is shown

### Requirement: Semantic senses and domains
The system SHALL present a sense-organised lexicon with a hierarchical sense tree, per-sense
frequency by book, lemma lists and sense relationships, and SHALL support exploring semantic
domains.

#### Scenario: Sense tree
- **WHEN** the user opens a sense lexicon entry
- **THEN** a hierarchical tree of senses is presented

#### Scenario: Frequency by book
- **WHEN** the user selects a sense
- **THEN** the frequency of that sense across biblical books is shown

#### Scenario: Search by sense
- **WHEN** the user searches from a sense
- **THEN** the results are the passages using that sense

### Requirement: Syntax search
The system SHALL support a syntax-tree search over syntax-tagged original-language texts, from
prebuilt templates or built from scratch, and SHALL present the matching clause graphically.

#### Scenario: Syntax template
- **WHEN** the user selects a syntax template and runs it
- **THEN** clauses matching the template's structure are returned

#### Scenario: From-scratch syntax query
- **WHEN** the user builds a syntax query from scratch
- **THEN** the search runs against the syntax-tagged texts only

#### Scenario: Clause graphic
- **WHEN** a syntax search returns results
- **THEN** each result can be shown as a clause diagram

#### Scenario: Restriction to tagged texts
- **WHEN** the user runs a syntax search
- **THEN** translations that are not syntax-tagged are not searched

### Requirement: Clause search
The system SHALL support a field-scoped clause search over sentence clauses, so that entities can
be matched by their role even when the text does not name them explicitly.

#### Scenario: Role-scoped query
- **WHEN** the user searches `subject:Jesus object:Peter`
- **THEN** clauses are returned whose subject is Jesus and object is Peter

#### Scenario: Implied entity
- **WHEN** a clause does not name the entity but implies it
- **THEN** it is still matched

### Requirement: Sentence diagrams
The system SHALL render a biblical clause or phrase as a line diagram or a text-flow diagram, and
SHALL allow per-word annotations.

#### Scenario: Line diagram
- **WHEN** the user generates a line diagram for a clause
- **THEN** the clause is rendered as a structured line diagram

#### Scenario: Text flow diagram
- **WHEN** the user generates a text-flow diagram
- **THEN** the clause is rendered as a flow of labelled parts

#### Scenario: Per-word annotation
- **WHEN** the user annotates a word in a diagram
- **THEN** the annotation appears against that word

### Requirement: Textual criticism
The system SHALL present textual variants for a passage, SHALL provide textual commentaries and
apparatuses, and SHALL support comparison against ancient versions.

#### Scenario: Textual variants
- **WHEN** the user opens textual variants for a passage
- **THEN** the variants for that passage are listed

#### Scenario: Apparatus
- **WHEN** the user opens an apparatus
- **THEN** the apparatus entry for the passage is shown with its witness readings

#### Scenario: Version comparison within criticism
- **WHEN** the user compares the passage across ancient versions
- **THEN** each version's reading is shown for that passage

### Requirement: Lemma in passage
The system SHALL find lemmas occurring in a passage within the commentary literature.

#### Scenario: Lemmas in passage
- **WHEN** the user requests lemmas in a passage
- **THEN** lemmas used in that passage are listed with commentary hits

#### Scenario: Other lemmas
- **WHEN** the user requests other lemmas
- **THEN** lemmas not in the passage but linked from the commentary are listed

### Requirement: Transliteration and input
The system SHALL allow the transliteration format for Greek, Hebrew and Syriac to be configured,
SHALL offer lemma auto-completion in Latin and transliterated forms, and SHALL provide Greek and
Hebrew keyboard input.

#### Scenario: Transliteration format
- **WHEN** the user changes the transliteration format
- **THEN** transliterated output uses the new format

#### Scenario: Lemma autocomplete
- **WHEN** the user begins typing a lemma
- **THEN** matching lemmas are suggested

#### Scenario: Native keyboard input
- **WHEN** the native-script keyboard is enabled
- **THEN** original-language characters can be typed
