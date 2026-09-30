# Spec Delta

## Purpose

Define the library browser — the destination that lists the resources available to the user,
supports searching and filtering them, and presents each resource with its cover and metadata in
a grid or list.

## ADDED Requirements

### Requirement: Resource list
The system SHALL present library resources with, for each one, a cover image, a title and a
subtitle describing the type and the author or publisher, and SHALL report the total count.

#### Scenario: Resource presentation
- **WHEN** the library is displayed
- **THEN** each row shows a cover, a title and a subtitle

#### Scenario: Total count
- **WHEN** the library is displayed
- **THEN** the total number of matching resources is reported

### Requirement: Library filters
The system SHALL offer the filter set observed in the original: `Suyos`, `Tienda` and
`por Título`, and SHALL sort the list accordingly.

#### Scenario: Suyos filter
- **WHEN** the user selects `Suyos`
- **THEN** only resources owned by the user are listed

#### Scenario: Tienda filter
- **WHEN** the user selects `Tienda`
- **THEN** only resources available for acquisition are listed

#### Scenario: Sort by title
- **WHEN** the user selects `por Título`
- **THEN** the list is ordered alphabetically by title

#### Scenario: Switching filter
- **WHEN** the user switches filter
- **THEN** the list updates to the new filter
- **AND** the reported total updates with it

### Requirement: Library search
The system SHALL provide a search field in the library that filters resources by title and
subtitle as the user types.

#### Scenario: Filtering by title
- **WHEN** the user types a fragment of a resource title
- **THEN** only resources whose title matches are listed

#### Scenario: Empty query
- **WHEN** the search field is cleared
- **THEN** the full resource list is restored

#### Scenario: No match
- **WHEN** no resource matches the query
- **THEN** an empty state is presented

### Requirement: Grid and list view modes
The system SHALL allow switching between a cover grid and a list view, and SHALL remember the
chosen mode.

#### Scenario: Switching view mode
- **WHEN** the user switches from grid to list
- **THEN** resources are presented as rows with the same metadata

#### Scenario: View mode persists
- **WHEN** the user chooses a view mode, leaves the library and returns
- **THEN** the same view mode is applied

### Requirement: Opening a library resource
The system SHALL open a resource selected from the library in a new tab and make it active.

#### Scenario: Opening a resource
- **WHEN** the user activates a library resource
- **THEN** a new tab is opened for it
- **AND** it becomes the active tab

#### Scenario: Resource already open
- **WHEN** the user activates a resource that is already open in a tab
- **THEN** the existing tab becomes active

### Requirement: Library reflow
The system SHALL reflow the library by layout class: one column on compact, two on medium and
three or more on expanded and large, without horizontal overflow.

#### Scenario: Compact library
- **WHEN** the library is rendered at 360 logical pixels
- **THEN** one resource is shown per row
- **AND** covers scale down to fit the column width

#### Scenario: Expanded library
- **WHEN** the library is rendered at 1280 logical pixels
- **THEN** multiple resources are shown per row

### Requirement: Library loading and failure
The system SHALL show a loading state while the library is being fetched and SHALL show a
recoverable error state if it cannot be fetched.

#### Scenario: Loading state
- **WHEN** the library is loading
- **THEN** a loading indicator is presented in place of the list

#### Scenario: Retry after failure
- **WHEN** library loading fails
- **THEN** an error state with a retry action is presented
- **AND** activating retry re-attempts the load
