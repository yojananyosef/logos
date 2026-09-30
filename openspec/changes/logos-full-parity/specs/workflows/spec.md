# Spec Delta

## Purpose

Define guided multi-step processes — the Devotional Study, Bible and Topic Study and Sermon
Preparation workflows — with numbered major and minor steps, per-step content types, visual step
state, progress persistence and resume.

## ADDED Requirements

### Requirement: Prebuilt workflow catalogue
The system SHALL provide workflows in three groups: Devotional Study (Devotional, Lectio Divina,
Praying Scripture, Adoration), Bible and Topic Study (Basic Bible Study, Inductive Bible Study,
Biblical Person Study, Biblical Place Study, Biblical Theme Study, Biblical Topic Study, Passage
Exegesis, Word Study in an Original Language, Regular Reading Routine, and named third-party
methods), and Sermon Preparation (Expository Sermon Prep, Topical Sermon Prep, Named preaching
models, and expanded expository models).

#### Scenario: Listing workflows
- **WHEN** the user opens the workflows list
- **THEN** the prebuilt workflows are listed grouped by category

#### Scenario: Starting a workflow
- **WHEN** the user starts a workflow at a passage
- **THEN** the first major step opens with its content

### Requirement: Step structure
The system SHALL support numbered major steps and numbered minor steps within them, and SHALL
render the current step index.

#### Scenario: Step numbering
- **WHEN** a workflow is open
- **THEN** the step indicator shows the current major and minor step numbers

#### Scenario: Sub-step completion
- **WHEN** every minor step of a major step is complete
- **THEN** the major step is marked complete

### Requirement: Step content types
The system SHALL allow each step to contain any of: Document, Expandable Text, Question and
Answer, Share Media, Share Text, Text, or an embedded tool or guide section.

#### Scenario: Question step
- **WHEN** a step's content type is Question and Answer
- **THEN** the step presents a question field and an answer field

#### Scenario: Expandable text
- **WHEN** a step's content type is Expandable Text
- **THEN** the step presents collapsible text blocks that the user can expand and edit

#### Scenario: Embedded tool
- **WHEN** a step embeds a tool section
- **THEN** that section renders inline within the step

### Requirement: Step notes
The system SHALL store each minor step's authored content as a note in a dedicated notebook named
for the workflow and its subject.

#### Scenario: Step content is persisted as a note
- **WHEN** the user types content into a minor step and moves on
- **THEN** that content is stored as a note in the workflow's notebook

#### Scenario: Reopening a workflow
- **WHEN** the user reopens a workflow in progress
- **THEN** the authored content of each completed step is restored

### Requirement: Step state
The system SHALL represent each major step with one of three states: current, complete, or
skipped, and SHALL render the state visually.

#### Scenario: Current step state
- **WHEN** a step is the step in progress
- **THEN** it renders with the current-state indicator

#### Scenario: Skipped step
- **WHEN** the user skips a step
- **THEN** it renders as skipped and is excluded from completion

### Requirement: Progress and resume
The system SHALL track workflow progress, SHALL allow resuming where the user left off, and
SHALL report in-progress workflows on the dashboard.

#### Scenario: Resume
- **WHEN** the user reopens a workflow in progress
- **THEN** it opens at the first incomplete step

#### Scenario: Dashboard progress card
- **WHEN** a workflow is in progress
- **THEN** the dashboard shows a card for it with its current step

### Requirement: Custom workflows
The system SHALL allow a user to author a workflow from scratch with its own steps and content
types.

#### Scenario: Creating a custom workflow
- **WHEN** the user creates a workflow and defines its steps
- **THEN** it is saved and appears in the user's workflow list

#### Scenario: Opening a custom workflow
- **WHEN** the user opens a custom workflow
- **THEN** its steps render in the authored order

### Requirement: Workflow filtering
The system SHALL allow filtering notes by workflow anchor and SHALL automatically anchor workflow
notes to the biblical book being studied.

#### Scenario: Filter notes by workflow
- **WHEN** the user filters notes by the workflow anchor
- **THEN** only notes created by that workflow are listed

#### Scenario: Automatic book anchor
- **WHEN** a workflow note is created
- **THEN** it is anchored to the biblical book the workflow subject belongs to
