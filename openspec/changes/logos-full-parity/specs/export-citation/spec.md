# Spec Delta

## Purpose

Define print and export, citation handling, deep links and interoperability — how content leaves
the application as documents, references and files.

## ADDED Requirements

### Requirement: Print and export dialog
The system SHALL provide an export dialog with margin control, column count, a choice of printing
as shown or as exported, an option to export only visible results, fit-to-page, and a per-section,
per-page or per-verse scope.

#### Scenario: Print as exported
- **WHEN** the user chooses to print as exported rather than as shown
- **THEN** the export uses the export formatting rather than the on-screen layout

#### Scenario: Visible results only
- **WHEN** the user enables visible results only
- **THEN** only currently displayed results are exported

#### Scenario: Fit to page
- **WHEN** the user enables fit-to-page
- **THEN** the content is scaled to fit the page width

#### Scenario: Export scope
- **WHEN** the user selects per-verse scope
- **THEN** the export is broken down by verse

### Requirement: Export formats
The system SHALL export to Rich Text, Plain Text, Web Page, PDF, and content-dependent additional
formats including images, spreadsheet, calendar and citation files.

#### Scenario: Export to plain text
- **WHEN** the user exports to plain text
- **THEN** a `.txt` file is produced

#### Scenario: Export to web page
- **WHEN** the user exports to web page
- **THEN** an HTML file is produced

#### Scenario: Export to spreadsheet
- **WHEN** the user exports tabular data as a spreadsheet
- **THEN** a spreadsheet file is produced

### Requirement: Export from within a resource
The system SHALL allow a passage, a selection, a chapter or a note to be exported from the reader
and the notes tool, and SHALL allow the exported content to be sent to a new document or pasted
into an open one.

#### Scenario: Export a selection
- **WHEN** the user exports a selection from the reader
- **THEN** the exported file contains that selection with its attribution

#### Scenario: Send to a new document
- **WHEN** the user sends exported content to a new document
- **THEN** a document is created containing that content

### Requirement: Citation styles
The system SHALL support APA, Chicago, MLA and Turabian citation styles, and SHALL apply the
selected style to every generated citation.

#### Scenario: Generate a citation
- **WHEN** the user generates a citation
- **THEN** it is formatted in the configured style

#### Scenario: Change style
- **WHEN** the user changes the citation style
- **THEN** subsequently generated citations use the new style

### Requirement: Deep links
The system SHALL generate links that open a specific resource at a specific position, and
SHALL open the referenced resource and position when such a link is followed.

#### Scenario: Generate a position link
- **WHEN** the user copies a link from a passage
- **THEN** the link identifies the resource and the position

#### Scenario: Follow a link
- **WHEN** a position link is opened
- **THEN** the resource opens at that position

### Requirement: Copy location
The system SHALL allow copying a reference to a location, and SHALL open that location even when
the network is unavailable once the resource is available locally.

#### Scenario: Copy location
- **WHEN** the user copies a location for a passage
- **THEN** a reference identifying that location is on the clipboard

#### Scenario: Open a copied location offline
- **WHEN** the user pastes a copied location with the network unavailable
- **THEN** the passage opens from local content

### Requirement: Import interoperability
The system SHALL import `.docx` documents, own PDFs, and user-supplied text, and SHALL report
clearly which document constructs could not be imported.

#### Scenario: Import a PDF
- **WHEN** the user imports a PDF
- **THEN** it is added as a document

#### Scenario: Report unsupported constructs
- **WHEN** an imported document contains images, tables or hyperlinks
- **THEN** the import reports that those were not imported

### Requirement: Library export
The system SHALL export the whole library as a spreadsheet.

#### Scenario: Export the library
- **WHEN** the user exports the library
- **THEN** a spreadsheet listing every resource is produced
