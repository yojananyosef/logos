# Spec Delta

## Purpose

Define the sermon and preaching workflow — the Sermon Builder producing manuscript, slides,
handout and questions together, the Sermon Manager calendar, Preaching Mode, templates, metadata
and export.

## ADDED Requirements

### Requirement: Sermon Builder workspace
The system SHALL open the sermon builder with document toolbar sections for Sidebar, Edit,
Outline and Info, and SHALL generate manuscript, slides, handout and questions simultaneously.

#### Scenario: Builder sections
- **WHEN** the sermon builder is open
- **THEN** the Sidebar, Edit, Outline and Info sections are present

#### Scenario: All four outputs
- **WHEN** the user authors a sermon
- **THEN** manuscript, slides, handout and questions are all available

### Requirement: Passage insertion
The system SHALL insert a passage block from a reference, and SHALL optionally generate a slide
from it, with a choice of block formatting: block paragraphs, one verse per slide, or fully
formatted.

#### Scenario: Insert with slide
- **WHEN** the user inserts a reference with slide generation enabled
- **THEN** a passage block is inserted
- **AND** a matching slide is generated

#### Scenario: Insert without slide
- **WHEN** the user inserts a reference with slide generation disabled
- **THEN** the passage block is inserted inline with no slide

#### Scenario: Block formatting
- **WHEN** the user selects one verse per slide
- **THEN** each verse becomes its own slide

#### Scenario: Verse number and red letter options
- **WHEN** the user toggles verse numbers
- **THEN** the generated slide and handout reflect that choice

#### Scenario: Version switch
- **WHEN** the user changes the version for a passage block
- **THEN** the block, slide and handout re-render in that version

### Requirement: Editable generated slides
The system SHALL allow any generated slide to be edited after generation.

#### Scenario: Edit a generated slide
- **WHEN** the user edits a generated slide
- **THEN** the slide shows the edited content
- **AND** the passage block is unchanged

### Requirement: Sermon metadata
The system SHALL record a series, a number within the series, topics and scripture references for a
sermon, and SHALL expose them for filtering.

#### Scenario: Series metadata
- **WHEN** the user sets a series and number
- **THEN** the sermon is filed under that series and number

#### Scenario: Filter by topic
- **WHEN** the user filters sermons by a topic
- **THEN** only sermons carrying that topic are listed

### Requirement: Sermon Manager
The system SHALL present a week-grid and a radial-calendar view, SHALL allow bulk adding up to one
hundred sermons from a template or from a lectionary and season, and SHALL support bulk metadata
editing, column and date filtering, and a calendar overlay.

#### Scenario: View modes
- **WHEN** the sermon manager is opened
- **THEN** week-grid and radial-calendar views are available

#### Scenario: Bulk add from lectionary
- **WHEN** the user generates a series from a lectionary and season
- **THEN** the sermons are created for the matching dates

#### Scenario: Bulk metadata edit
- **WHEN** the user bulk-edits the series of several sermons
- **THEN** all selected sermons carry the new series

#### Scenario: Calendar overlay
- **WHEN** the calendar overlay is enabled
- **THEN** a calendar is shown over the radial calendar

### Requirement: Sermon templates
The system SHALL allow a sermon document to be flagged as a template and SHALL use its metadata
for sermons generated from it.

#### Scenario: Template supplies metadata
- **WHEN** the user generates a sermon from a template
- **THEN** the new sermon inherits the template's series and other metadata

### Requirement: Preaching Mode
The system SHALL present the sermon for delivery with an editable timer, one-minute and
two-minute flash warnings, an over-time visual state, a choice of paging or scrolling text
column, a choice of serif, sans or monospace font, five font sizes with proportional scaling, five
line-spacing steps, and tight, normal or loose margins, and SHALL remember these settings per
sermon.

#### Scenario: Timer countdown
- **WHEN** preaching mode is started
- **THEN** a countdown timer runs from the configured length

#### Scenario: Flash warning
- **WHEN** the timer reaches the one-minute warning
- **THEN** a visual warning is shown

#### Scenario: Over time
- **WHEN** the timer passes the configured length
- **THEN** the over-time state is shown

#### Scenario: Text column paging
- **WHEN** the user selects paging
- **THEN** the text advances page by page rather than scrolling

#### Scenario: Settings remembered
- **WHEN** the user changes font and spacing and reopens preaching mode for that sermon
- **THEN** the same settings are applied

### Requirement: Sermon import
The system SHALL import a `.docx` sermon, honouring text styles, colours and sizes, generating
slides from Word headings, and parsing scripture references; and SHALL import a batch of files.
It SHALL NOT import images, tables or hyperlinks.

#### Scenario: Import a docx
- **WHEN** the user imports a `.docx`
- **THEN** its text and text styles are preserved

#### Scenario: Slides from headings
- **WHEN** the imported document has headings
- **THEN** slides are generated from those headings

#### Scenario: References parsed
- **WHEN** the imported text contains scripture references
- **THEN** those references are recorded as metadata

### Requirement: Sermon export
The system SHALL export a sermon to a third-party presentation tool, to PDF, and to a shared
public link, and SHALL allow transcript and closed-caption attachment.

#### Scenario: Export for presentation
- **WHEN** the user exports a sermon for a third-party presentation tool
- **THEN** an export is produced in that tool's format

#### Scenario: Publish a link
- **WHEN** the user publishes a sermon
- **THEN** a public link is produced

### Requirement: Sermon library
The system SHALL surface archived sermons by preacher and topic wherever the corresponding guide
sections appear, and SHALL allow inline markers in the Bible with a preview.

#### Scenario: Sermons in a guide
- **WHEN** a guide section for sermons is rendered
- **THEN** the user's sermon archive is listed

#### Scenario: Inline sermon marker
- **WHEN** the user enables sermon markers
- **THEN** tagged sermons appear inline at the passage with a preview
