# Spec Delta

## Purpose

Define the media and visual layer — the Media tool and browser, the slide editor, the infinite
Canvas, Charts and graphic resources.

## ADDED Requirements

### Requirement: Media browser
The system SHALL present a browsable, searchable media library with multi-tag facets and a sort
by recently used, and SHALL distinguish the user's own media, media collections, online results,
atlas maps and library media.

#### Scenario: Media sections
- **WHEN** the media tool is opened
- **THEN** its sections for personal media, collections, online results, atlas and library are
  available

#### Scenario: Recently used sort
- **WHEN** the user sorts by recently used
- **THEN** the most recently used media appear first

#### Scenario: Facet filtering
- **WHEN** the user selects a media tag
- **THEN** only media carrying that tag are listed

### Requirement: Slide editor
The system SHALL provide a slide editor with font, size, colour and style controls, a body text
box, and a resolution selector.

#### Scenario: Edit slide text
- **WHEN** the user changes a slide's font size
- **THEN** the slide text re-renders at that size

#### Scenario: Resolution selection
- **WHEN** the user selects a resolution
- **THEN** the slide canvas adopts that resolution

#### Scenario: Visual copy
- **WHEN** the user creates a slide from a text selection
- **THEN** a slide is generated containing that selection

### Requirement: Slide export
The system SHALL export a slide as an image, to a third-party presentation tool, to PDF, by
sharing, or as an email attachment.

#### Scenario: Export as image
- **WHEN** the user exports a slide as an image
- **THEN** an image file of the slide is produced

#### Scenario: Send to a presentation tool
- **WHEN** the user sends a slide to a third-party tool
- **THEN** the slide is exported in that tool's format

### Requirement: User media upload
The system SHALL allow a user to upload media to their library, enforcing a maximum file size and
preferring a supported image format, and SHALL reject oversized or unsupported files with a
clear message.

#### Scenario: Successful upload
- **WHEN** the user uploads a supported image within the size limit
- **THEN** it appears in their media

#### Scenario: Oversized upload
- **WHEN** the user uploads a file exceeding the size limit
- **THEN** the upload is rejected with a message stating the limit

### Requirement: Canvas workspace
The system SHALL provide an infinite canvas supporting passages, freehand drawing, zoom, text
blocks that can be dragged and reformatted, annotations, and info cards linking to reference
entries and word studies, and SHALL persist the canvas as a document.

#### Scenario: Infinite canvas navigation
- **WHEN** the user pans and zooms the canvas
- **THEN** the canvas viewport moves accordingly

#### Scenario: Reflow a text block
- **WHEN** the user drags a text block
- **THEN** it moves to the new position

#### Scenario: Persistence
- **WHEN** the canvas is saved
- **THEN** reopening it restores all placed content

### Requirement: Charts
The system SHALL turn search results into charts with multiple chart types, per-version toggling,
a count-per-book mode, zoom, selectable aspect ratio, colour themes, export to image formats, and
the ability to send a chart to a new sermon slide.

#### Scenario: Chart from results
- **WHEN** the user charts a set of search results
- **THEN** a chart of that result set is produced

#### Scenario: Count per book
- **WHEN** the user enables count-per-book
- **THEN** the chart shows counts by biblical book

#### Scenario: Chart to sermon
- **WHEN** the user sends a chart to a sermon
- **THEN** it becomes a slide in that sermon

### Requirement: Graphic resources
The system SHALL present graphic resources such as maps, illustrations and diagrams with a
thumbnail preview, SHALL open one at full size, and SHALL allow images to be inserted into notes.

#### Scenario: Thumbnail list
- **WHEN** the graphic resources tool is opened
- **THEN** graphics are listed with thumbnails

#### Scenario: Full-size view
- **WHEN** the user opens a graphic
- **THEN** it is displayed at full size
- **AND** dismissing returns to the list

#### Scenario: Insert into a note
- **WHEN** the user inserts a graphic into a note
- **THEN** the note contains that image

### Requirement: Visual filters
The system SHALL provide visual filters for books, for the Bible and for morphology, built with
the same syntax as search, and SHALL scope a filter to a specific resource, a resource type or all
resources of a type.

#### Scenario: Book visual filter
- **WHEN** a book visual filter is created
- **THEN** matching terms are marked in book resources

#### Scenario: Bible visual filter
- **WHEN** a Bible visual filter is created
- **THEN** matching terms are marked in scripture

#### Scenario: Scope to a resource type
- **WHEN** the user scopes a filter to all lexicons
- **THEN** every lexicon in the library is filtered
