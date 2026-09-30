# Spec Delta

## Purpose

Adds interlinear display, textual criticism, corresponding text, the insights sidebar, read aloud
and passage-level navigation to the Bible reader established in `logos-flutter-clone`.

These are **ADDED** requirements rather than MODIFIED, because the reader's requirements live in
the `logos-flutter-clone` change and have not yet been promoted to a main spec. On archive this
delta merges with that capability.

## ADDED Requirements

### Requirement: Reverse interlinear ribbon
The system SHALL provide a reverse interlinear that can be shown as a ribbon beneath each verse
and SHALL allow the ribbon to be toggled.

#### Scenario: Ribbon display
- **WHEN** the user enables the reverse interlinear ribbon
- **THEN** each verse shows its original words beneath the translation in non-linear order

#### Scenario: Ribbon toggle
- **WHEN** the user disables the ribbon
- **THEN** the original words are no longer shown beneath the verses

### Requirement: Strong's numbers in the reader
The system SHALL show Strong's numbers inline in the interlinear and SHALL support toggling them.

#### Scenario: Toggle Strong's numbers
- **WHEN** the user toggles Strong's numbers off
- **THEN** the numbers are no longer displayed

### Requirement: Textual variants in the reader
The system SHALL allow textual variants for a passage to be displayed inline in the reader, and
SHALL show the variant readings alongside the base text.

#### Scenario: Show variants
- **WHEN** the user enables textual variants
- **THEN** variant readings appear at the verses where they occur

#### Scenario: Open a textual commentary
- **WHEN** the user opens a textual commentary from a variant
- **THEN** the commentary entry for that variant is shown

### Requirement: Corresponding text in the reader
The system SHALL mark the corresponding position in a parallel translation when the user navigates
in another translation, and SHALL propagate highlights and notes across translations.

#### Scenario: Corresponding position marked
- **WHEN** the user is reading a passage in one translation
- **THEN** the corresponding position is marked in any open parallel translation

#### Scenario: Highlight propagates
- **WHEN** a highlight is applied in one translation
- **THEN** the corresponding text in another translation carries the same highlight

### Requirement: Insights sidebar
The system SHALL provide a sidebar alongside the Bible text presenting Related Books — the
prioritised study Bible and commentary snippets — Related Passages, Cross References and Textual
History, and SHALL allow each card to be expanded, collapsed and removed.

#### Scenario: Related book snippets
- **WHEN** the user moves to a passage
- **THEN** snippets from the prioritised study Bible and commentary are shown

#### Scenario: Remove a card
- **WHEN** the user removes a card
- **THEN** it no longer appears for that session

#### Scenario: Textual history card
- **WHEN** the user opens the Textual History card
- **THEN** textual commentaries, apparatuses and ancient-version readings for the passage are
  offered

### Requirement: Read aloud
The system SHALL provide text-to-speech playback of the open resource, with playback controls and
a voice selection where the platform provides voices.

#### Scenario: Start playback
- **WHEN** the user starts read aloud
- **THEN** the text is read aloud from the current position

#### Scenario: Stop playback
- **WHEN** the user stops playback
- **THEN** speech stops

#### Scenario: Voice selection
- **WHEN** the platform provides multiple voices
- **THEN** the user can choose among them

### Requirement: Passage-level navigation controls
The system SHALL provide controls to move by verse, by chapter, and to a parallel passage.

#### Scenario: Verse stepping
- **WHEN** the user advances to the next verse
- **THEN** the reader moves to that verse

#### Scenario: Chapter stepping
- **WHEN** the user advances to the next chapter
- **THEN** the reader moves to the start of that chapter

### Requirement: Passage block copy
The system SHALL allow copying a passage as styled text, as lines, or as plain text, with options
for block paragraphs, one verse per line, and inclusion of verse numbers.

#### Scenario: Copy as lines
- **WHEN** the user copies a passage in the lines format
- **THEN** each verse is placed on its own line

#### Scenario: One verse per line
- **WHEN** the user enables one verse per line
- **THEN** the copied text places each verse on a separate line

### Requirement: Biblical events navigator
The system SHALL present a timeline of the biblical story positioned at the current passage.

#### Scenario: Navigator position
- **WHEN** the user moves to a passage
- **THEN** the navigator positions itself at that point in the biblical story
