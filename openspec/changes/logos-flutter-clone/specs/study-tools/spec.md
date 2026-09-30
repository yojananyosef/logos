# Spec Delta

## Purpose

Define the study tools container — `Herramientas` — which hosts the tool set observed in the
original application: Atlas focalizado, Comparación de versiones, Cursos, Documentos,
Enciclopedia bíblica, Información and Recursos gráficos.

## ADDED Requirements

### Requirement: Tools menu
The system SHALL present the tools destination as a menu listing exactly: Atlas focalizado,
Comparación de versiones, Cursos, Documentos, Enciclopedia bíblica, Información,
Recursos gráficos. Each entry SHALL have an icon.

#### Scenario: Menu contents
- **WHEN** the tools destination is presented
- **THEN** all seven tools are listed with their icons
- **AND** they appear in the order above

#### Scenario: Menu closing
- **WHEN** the user selects a tool
- **THEN** the menu closes
- **AND** the selected tool is presented

### Requirement: Focused atlas
The system SHALL provide a focused atlas that displays a map of a biblical place and the
scripture passages that mention it, and SHALL highlight the mapped area in `#FF6600`.

#### Scenario: Atlas list
- **WHEN** the focused atlas is opened
- **THEN** the available places are listed

#### Scenario: Selecting a place
- **WHEN** the user selects a place
- **THEN** the map displays that location with the area highlighted
- **AND** the passages mentioning it are listed

#### Scenario: Opening a passage from the atlas
- **WHEN** the user activates a passage in the atlas
- **THEN** the reader opens at that passage

### Requirement: Bible version comparison
The system SHALL allow two or more Bible versions to be displayed side by side, synchronised by
scroll position, so the same passage can be read in parallel.

#### Scenario: Selecting versions
- **WHEN** the user selects two versions
- **THEN** both are displayed side by side
- **AND** each pane shows its version name

#### Scenario: Synchronised scrolling
- **WHEN** the user scrolls one pane
- **THEN** the other pane scrolls to the equivalent passage

#### Scenario: Changing versions
- **WHEN** the user changes the version in one pane
- **THEN** only that pane's version changes
- **AND** the synchronisation with the other pane is preserved

### Requirement: Courses
The system SHALL present courses with a title, description, lesson count and progress, and
SHALL track which lessons are complete.

#### Scenario: Course list
- **WHEN** the courses tool is opened
- **THEN** the available courses are listed

#### Scenario: Lesson progress
- **WHEN** the user completes a lesson
- **THEN** that lesson is marked complete
- **AND** the course progress reflects the completion

### Requirement: Documents
The system SHALL present documents the user has created, with a title and last-modified time,
and SHALL allow creating and opening them.

#### Scenario: Document list
- **WHEN** the documents tool is opened
- **THEN** the user's documents are listed with title and modified time

#### Scenario: Creating a document
- **WHEN** the user creates a document and supplies a title
- **THEN** the document appears in the list
- **AND** it opens for editing

#### Scenario: Empty documents
- **WHEN** the user has no documents
- **THEN** an empty state with a create action is presented

### Requirement: Bible encyclopedia
The system SHALL present encyclopedia articles that can be browsed by topic and opened for
reading, and SHALL preserve the article identifier so it can be linked and revisited.

#### Scenario: Article browsing
- **WHEN** the encyclopedia tool is opened
- **THEN** articles are listed and can be filtered by topic

#### Scenario: Opening an article
- **WHEN** the user selects an article
- **THEN** the article opens in a tab and can be read

#### Scenario: Revisiting a linked article
- **WHEN** a link to a previously opened article is activated
- **THEN** the same article opens rather than a duplicate

### Requirement: Information tool
The system SHALL present version and licence information for the application and the content it
ships.

#### Scenario: Version information
- **WHEN** the information tool is opened
- **THEN** the application version is displayed

#### Scenario: Content provenance
- **WHEN** the information tool is opened
- **THEN** it states that the bundled corpus is public-domain content

### Requirement: Graphic resources
The system SHALL present graphic resources such as maps, illustrations and charts, with a
preview and the ability to open one at full size.

#### Scenario: Graphic list
- **WHEN** the graphic resources tool is opened
- **THEN** the available graphics are listed with thumbnails

#### Scenario: Opening a graphic
- **WHEN** the user opens a graphic
- **THEN** it is displayed at full size
- **AND** it can be dismissed to return to the list

### Requirement: Tools launch behaviour
The system SHALL open every tool in a tab in the workspace and SHALL return to the tools menu
when the active tab is closed.

#### Scenario: Launching a tool
- **WHEN** the user selects any tool
- **THEN** a tab is opened for it
- **AND** the tools destination is marked active in the sidebar

#### Scenario: Closing a tool tab
- **WHEN** the user closes the tab of an open tool
- **THEN** the tools menu is presented again

### Requirement: Tools reflow
The system SHALL reflow tool surfaces by layout class, and SHALL stack comparison panes
vertically on compact viewports.

#### Scenario: Comparison on compact
- **WHEN** a version comparison is opened at 360 logical pixels
- **THEN** the two versions are stacked vertically
- **AND** the document does not scroll horizontally
