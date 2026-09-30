# Spec Delta

## Purpose

Define the AI layer — Study Assistant, Smart Search and Synopsis, Summarize, Translate, Factbook
Questions to Ask, Sermon Assistant and Bible Study Builder — built on the rule that every
generated claim is grounded in a citable source the user can inspect.

## ADDED Requirements

### Requirement: Grounded output
The system SHALL attach inspectable citations to every AI-generated claim, SHALL mark the source
text that produced each claim, and SHALL never present a claim without a source.

#### Scenario: Inline citations
- **WHEN** the assistant produces an answer
- **THEN** the answer contains inline citations
- **AND** each citation resolves to the passage that supports it

#### Scenario: Source highlighting
- **WHEN** the user activates a citation
- **THEN** the supporting text is shown
- **AND** it is highlighted in the open resource

#### Scenario: Footnote navigation
- **WHEN** an answer has multiple citations
- **THEN** the user can step through the footnotes in order

### Requirement: AI provider abstraction
The system SHALL route all AI features through a single provider interface, and SHALL ship a
stub provider that works with no API key and no network.

#### Scenario: No provider configured
- **WHEN** no AI provider is configured
- **THEN** AI features report that no provider is available
- **AND** the rest of the application is unaffected

#### Scenario: Swapping providers
- **WHEN** a different provider implementation is supplied
- **THEN** all AI features use it without UI changes

### Requirement: Study Assistant
The system SHALL provide a conversational assistant that answers questions grounded in the user's
library, SHALL allow scoping the conversation to the whole catalogue or to the user's library, and
SHALL allow narrowing that scope by collection, resource type, series or individual book.

#### Scenario: Ask a question
- **WHEN** the user asks a question
- **THEN** an answer grounded in the scoped sources is returned with citations

#### Scenario: Narrow the scope
- **WHEN** the user narrows the scope to a collection
- **THEN** subsequent answers draw only on that collection

#### Scenario: Add current selection as context
- **WHEN** the user injects the text at the current location
- **THEN** that text is included as context for the answer

#### Scenario: Conversation management
- **WHEN** the user opens the recent conversations list
- **THEN** previous conversations can be opened, renamed or deleted

#### Scenario: Copy the conversation
- **WHEN** the user copies a conversation
- **THEN** the full exchange including citations is placed on the clipboard

#### Scenario: Answer feedback
- **WHEN** the user marks an answer not helpful
- **THEN** the feedback is recorded against that answer

### Requirement: Entry points to the assistant
The system SHALL allow the assistant to be opened from the toolbar, the tools menu, a text
selection, a Factbook entry's questions, and from a Smart Search synopsis, and SHALL carry
context into the conversation when invoked from those entry points.

#### Scenario: Explain from a selection
- **WHEN** the user invokes Explain on a selection
- **THEN** the assistant opens with that selection as context

#### Scenario: Continue from a synopsis
- **WHEN** the user continues a Smart Search synopsis in the assistant
- **THEN** the search results and question carry over as context

### Requirement: Smart Search
The system SHALL provide a semantic search mode that combines lexical matching, semantic
retrieval and learned ranking, and SHALL fall back to precise search when the query is a Bible
reference, is entirely in an original language, or contains special syntax.

#### Scenario: Natural-language query
- **WHEN** the user submits a natural-language question
- **THEN** results are ranked for relevance to the question's meaning

#### Scenario: Automatic fallback
- **WHEN** the user submits a Bible reference
- **THEN** the precise search engine runs instead of the semantic engine

### Requirement: Smart Bible Search
The system SHALL locate relevant passages for a question, and SHALL render every returned verse
by looking it up in the user's selected translation so displayed text is guaranteed accurate.

#### Scenario: Verse accuracy
- **WHEN** a verse is returned for a selected translation
- **THEN** the text shown is the text of that translation at that reference

### Requirement: Smart Synopsis
The system SHALL synthesise the top results of a search into prose with footnotes, and SHALL map
each claim to the source text that produced it.

#### Scenario: Synopsis generation
- **WHEN** the user requests a synopsis of a result set
- **THEN** a synthesised summary is returned with footnotes

#### Scenario: Claim provenance
- **WHEN** the user inspects a claim in the synopsis
- **THEN** the source passages it draws on are identified

### Requirement: Result summaries
The system SHALL summarise an individual search result on request, including results from
resources the user does not own, and SHALL let the summary be continued in the assistant.

#### Scenario: Summarise a result
- **WHEN** the user requests a summary of a result
- **THEN** a summary of that result is returned

#### Scenario: Summary of an unowned result
- **WHEN** the result is a resource the user does not own
- **THEN** the summary is still produced

### Requirement: Summarize
The system SHALL summarise an article, a chapter or a whole book at a user-selected hierarchy
level, and SHALL work in commentaries, dictionaries, monographs and biblical books.

#### Scenario: Hierarchy level
- **WHEN** the user selects book-level summarisation
- **THEN** the summary covers the whole book

#### Scenario: Summarise a biblical book
- **WHEN** the user summarises a biblical book
- **THEN** a summary of that book is produced

### Requirement: Translate
The system SHALL translate selected text preserving tone, and SHALL present the translation
line by line alongside the original for comparison.

#### Scenario: Line-by-line comparison
- **WHEN** the user translates a selection
- **THEN** each source line is shown with its translation beneath it

#### Scenario: Original remains visible
- **WHEN** a translation is produced
- **THEN** the untranslated source text is still shown

### Requirement: Factbook Questions to Ask
The system SHALL propose curiosity questions on Factbook entries, SHALL answer them inline, and
SHALL let a question be continued in the assistant.

#### Scenario: Suggested questions
- **WHEN** a Factbook entry is open
- **THEN** suggested questions specific to that entry are presented

#### Scenario: Follow-up in the assistant
- **WHEN** the user continues a suggested question in the assistant
- **THEN** the assistant opens with that question and the entry as context

### Requirement: Sermon Assistant
The system SHALL provide four generation modes inside the sermon builder — Outlines,
Illustrations, Applications and Questions — each with tone, type, situation and audience
controls, and SHALL let results be inserted, copied, cleared or regenerated.

#### Scenario: Generate an outline
- **WHEN** the user requests an outline for a passage with a theme and a point count
- **THEN** an outline with that many points is returned

#### Scenario: Questions from existing text
- **WHEN** the user requests questions in Questions mode
- **THEN** the questions are generated from the sermon text already written

#### Scenario: Insert at cursor
- **WHEN** the user inserts a generated result
- **THEN** it is placed at the cursor in the sermon

#### Scenario: Multiple outlines
- **WHEN** the user generates more than one outline
- **THEN** each is kept on its own tab

#### Scenario: Clear results
- **WHEN** the user clears results
- **THEN** generated results for that mode are removed

### Requirement: Bible Study Builder
The system SHALL generate small-group discussion questions from the library for a topic or
passage.

#### Scenario: Generate discussion questions
- **WHEN** the user requests discussion questions for a passage
- **THEN** a set of discussion questions grounded in the library is returned

### Requirement: AI credit accounting
The system SHALL track AI usage against a monthly allowance, SHALL display remaining usage, and
SHALL notify the user when the allowance is exhausted.

#### Scenario: Usage display
- **WHEN** the user has used part of the monthly allowance
- **THEN** the remaining usage is visible

#### Scenario: Allowance exhausted
- **WHEN** the allowance is exhausted
- **THEN** AI features report that the allowance is spent
- **AND** the rest of the application remains usable
