# Spec Delta

## Purpose

Adds collections, custom series, global priorization, top Bibles, personal books, the print
library, offline resources and library export to the library capability established in
`logos-flutter-clone`, whose faceted browsing, filtering and responsive grid remain unchanged.

These are **ADDED** requirements rather than MODIFIED, because the library requirements live in
the `logos-flutter-clone` change and have not yet been promoted to a main spec.

## ADDED Requirements

### Requirement: Library facets
The system SHALL allow filtering the library by resource type, subject, author, series,
publisher, tag, language, corpus and user tag, and SHALL combine multiple facets.

#### Scenario: Combine facets
- **WHEN** the user selects a subject and an author facet
- **THEN** only resources matching both are listed

#### Scenario: Facet counts
- **WHEN** facets are shown
- **THEN** each facet reports how many resources it would yield

### Requirement: Collections
The system SHALL allow a user to define named collections of resources, and SHALL let collections
scope search, the study assistant, guides and Cited By.

#### Scenario: Create a collection
- **WHEN** the user creates a collection and adds resources
- **THEN** the collection lists exactly those resources

#### Scenario: Scope search to a collection
- **WHEN** the user searches within a collection
- **THEN** only that collection's resources are searched

#### Scenario: Collection scope in Cited By
- **WHEN** Cited By is opened with a collection scope
- **THEN** only resources in that collection are searched

### Requirement: Custom series
The system SHALL allow a user to create custom book series in the library, grouping resources
independently of publisher-defined series.

#### Scenario: Create a custom series
- **WHEN** the user creates a custom series and adds books
- **THEN** those books are listed under that series

### Requirement: Global priorization
The system SHALL allow a user to rank series, books or top-level entries, and SHALL apply that
ranking to guides, lookups, top Bibles and insight cards, and SHALL allow the ranking to be
reordered and reset.

#### Scenario: Prioritized commentary leads the list
- **WHEN** a commentary is ranked first
- **THEN** guides and insight cards present it first

#### Scenario: Reset prioritisation
- **WHEN** the user resets prioritisation
- **THEN** the default ranking is restored

### Requirement: Top Bibles
The system SHALL allow a user to mark a preferred Bible and a set of top Bibles, and SHALL use
those in guides and tools.

#### Scenario: Preferred study Bible
- **WHEN** the user marks a study Bible as preferred
- **THEN** it is used as the study Bible in guides

#### Scenario: Top Bibles set
- **WHEN** the top Bibles set is configured
- **THEN** tools use that set

### Requirement: Parallel resource sets
The system SHALL list, for the current entry, every same-type resource that also contains it, and
SHALL allow stepping through that list.

#### Scenario: Parallel commentaries
- **WHEN** the user is reading in a commentary
- **THEN** other commentaries containing the same entry are listed

#### Scenario: Step through
- **WHEN** the user steps to the next parallel resource
- **THEN** that resource opens at the corresponding entry

### Requirement: Downloaded versus cloud resources
The system SHALL distinguish locally available resources from cloud resources that stream on
demand, and SHALL group search and library results accordingly.

#### Scenario: Cloud resource opens on demand
- **WHEN** the user opens a cloud resource
- **THEN** it is retrieved and then displayed

### Requirement: Offline resources
The system SHALL allow resources to be made available without a network, SHALL list which
resources are available offline, and SHALL remove offline copies.

#### Scenario: Make available offline
- **WHEN** the user marks a resource for offline use
- **THEN** it is available with the network disconnected

#### Scenario: Remove offline copy
- **WHEN** the user removes a resource from offline
- **THEN** it requires the network again

### Requirement: Print library catalog
The system SHALL allow physical books to be catalogued by identifier, and SHALL make their
contents searchable alongside digital resources.

#### Scenario: Catalogue a print book
- **WHEN** the user catalogues a physical book by its identifier
- **THEN** it is added to the print library

#### Scenario: Search print library contents
- **WHEN** the user searches a phrase known only from a print book
- **THEN** the print library entry appears in the results with its page reference

### Requirement: Personal books
The system SHALL allow a user to compile an uploaded document into a first-class library resource,
SHALL report the conversion stages with a log, SHALL allow recompiling, and SHALL allow publishing
the result to the community library.

#### Scenario: Conversion stages
- **WHEN** a personal book is compiled
- **THEN** the system reports each stage: starting, converting, compiling, discovering

#### Scenario: Conversion failure
- **WHEN** conversion fails
- **THEN** the log is shown so the user can see why

#### Scenario: Recompile
- **WHEN** the user recompiles a personal book
- **THEN** the build runs again

### Requirement: Hide books
The system SHALL allow a resource to be hidden from library views without uninstalling it, and
SHALL allow it to be shown again.

#### Scenario: Hide without uninstall
- **WHEN** the user hides a resource
- **THEN** it is absent from library views
- **AND** it remains installed and searchable

### Requirement: Library export
The system SHALL export the whole library as a spreadsheet.

#### Scenario: Export the library
- **WHEN** the user exports the library
- **THEN** a spreadsheet listing every resource with its metadata is produced

### Requirement: Library search scope
The system SHALL allow library search to be restricted to a collection, a type or a series.

#### Scenario: Scope to a series
- **WHEN** the user restricts the library to a series
- **THEN** only that series' resources are listed
