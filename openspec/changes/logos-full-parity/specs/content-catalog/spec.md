# Spec Delta

## Purpose

Define the decoupled content catalog — the contract between the application and its content, the
license manifest every resource must carry, the validation that gates distribution, and the
user-installable catalog. This capability lives in a separate repository from the application so
content can be versioned, licensed and replaced independently of application releases.

## ADDED Requirements

### Requirement: Catalog contract
The system SHALL define a versioned contract covering resource types, a resource reference, a
catalog manifest and a library interface, and the application SHALL depend only on this contract.

#### Scenario: Application holds no scripture text
- **WHEN** the application repository is inspected
- **THEN** it contains no scripture, lexicon or morphology content

#### Scenario: Contract versioning
- **WHEN** the application declares a supported catalog contract version
- **THEN** a catalog built against an incompatible major version is rejected with a clear error

#### Scenario: Contract upgrade
- **WHEN** the application upgrades to a new contract major version
- **THEN** existing catalogs are identified as incompatible rather than silently misread

### Requirement: License manifest
Every resource in a catalog SHALL declare its license, its attribution string, its source URL and
a verification status.

#### Scenario: Public domain resource
- **WHEN** a resource is in the public domain
- **THEN** its license is recorded as public domain
- **AND** its attribution is empty and its source URL is recorded

#### Scenario: Attribution-required resource
- **WHEN** a resource is licensed CC BY 4.0
- **THEN** its attribution string is mandatory and non-empty
- **AND** the string names the rights holder and links the license

#### Scenario: Unverified resource
- **WHEN** a resource has no recorded license
- **THEN** the catalog is marked as not distributable

### Requirement: License validation gate
The catalog tooling SHALL refuse to produce a distributable catalog when any resource has an
unresolved license, a missing required attribution, or a license that forbids the intended use.

#### Scenario: Missing attribution blocks the build
- **WHEN** a catalog contains a CC BY resource with an empty attribution
- **THEN** the build fails and names the offending resource

#### Scenario: Unresolved license blocks the build
- **WHEN** a catalog contains a resource with no license
- **THEN** the build fails and names the resource

#### Scenario: Non-commercial license blocked for commercial distribution
- **WHEN** a catalog contains a non-commercial resource and the build target is commercial
- **THEN** the build fails and names the resource

### Requirement: Share-alike propagation
The system SHALL flag resources carrying a share-alike license, SHALL compute whether a catalog
as a whole inherits a share-alike obligation, and SHALL refuse to mix share-alike content into a
catalog intended for closed distribution.

#### Scenario: Share-alike resource detected
- **WHEN** a catalog contains a share-alike licensed resource
- **THEN** the catalog is flagged as share-alike
- **AND** the tooling reports which resource introduced the obligation

#### Scenario: Mixing into a closed catalog
- **WHEN** a share-alike resource is added to a catalog marked closed
- **THEN** the build fails and explains the obligation

#### Scenario: Open catalog accepts share-alike
- **WHEN** a share-alike resource is added to a catalog marked open
- **THEN** the build succeeds and the catalog remains marked share-alike

### Requirement: Temporal release gating
A resource SHALL declare the jurisdictions in which it may be distributed and the date from which
it may be distributed, and the tooling SHALL refuse distribution outside that scope.

#### Scenario: Release date not reached
- **WHEN** a resource declares a release date in the future and the build runs before it
- **THEN** the build fails and reports the date on which it becomes distributable

#### Scenario: Jurisdiction not covered
- **WHEN** a resource is not cleared for the target jurisdiction
- **THEN** the build fails and names the jurisdiction

#### Scenario: Licensed resource excluded
- **WHEN** a resource is marked licensed rather than public domain
- **THEN** it is excluded from any distributable catalog

### Requirement: Attribution surface
The application SHALL present the catalog's attribution information to the user, listing every
resource whose license requires attribution, with its license and source.

#### Scenario: Attribution screen
- **WHEN** the user opens the credits or attribution screen
- **THEN** every attribution-required resource is listed with its license and source URL

#### Scenario: Per-resource attribution
- **WHEN** the user views a resource that requires attribution
- **THEN** its attribution is discoverable from the resource itself

#### Scenario: Public domain attribution
- **WHEN** a resource is public domain
- **THEN** it is still listed on the credits screen as public domain, with no attribution
  obligation

### Requirement: Attribution on exported content
The application SHALL include the catalog attribution block in exported documents whose source
content requires attribution.

#### Scenario: Export with attribution
- **WHEN** the user exports content from a resource that requires attribution
- **THEN** the export contains that resource's attribution

#### Scenario: Export without obligation
- **WHEN** the user exports content entirely from public-domain resources
- **THEN** no attribution block is required
- **AND** the export proceeds without it

### Requirement: User-installable catalogs
The system SHALL allow a user to install a catalog from a local file, SHALL list installed
catalogs, SHALL allow a catalog to be removed, and SHALL keep application data intact when a
catalog is removed.

#### Scenario: Install a catalog
- **WHEN** the user installs a catalog from a file
- **THEN** its resources become available in the library

#### Scenario: Replace an installed catalog
- **WHEN** the user installs a catalog with the same identifier as one already installed
- **THEN** the new version replaces the old one

#### Scenario: Remove a catalog
- **WHEN** the user removes a catalog
- **THEN** its resources are no longer available
- **AND** the user's notes, highlights and documents are preserved

#### Scenario: Application without a catalog
- **WHEN** no catalog is installed
- **THEN** the application still launches
- **AND** every content-dependent surface reports that no content is available
- **AND** no part of the interface is broken

### Requirement: Catalog build reproducibility
The catalog tooling SHALL produce a build that is reproducible from a pinned source manifest, and
SHALL record for every built resource the source, version and retrieval date.

#### Scenario: Reproducible build
- **WHEN** the same pinned source manifest is built twice
- **THEN** the two builds are byte-identical

#### Scenario: Source provenance recorded
- **WHEN** a catalog is built
- **THEN** every resource records its source URL, version and retrieval date

### Requirement: Content integrity
The catalog tooling SHALL verify that built content matches its recorded source, and SHALL fail
the build on mismatch.

#### Scenario: Integrity check passes
- **WHEN** a resource's content hash matches the recorded hash
- **THEN** the resource is accepted

#### Scenario: Integrity check fails
- **WHEN** a resource's content hash does not match
- **THEN** the build fails and names the resource

### Requirement: Provenance of the shipped corpus
The system SHALL ship only resources whose license permits distribution, and SHALL document for
each shipped resource why it is permissible.

#### Scenario: Documented permissibility
- **WHEN** the shipped catalog is inspected
- **THEN** every resource has a recorded license basis and, where relevant, the expiry analysis
  or dedication that permits its use

#### Scenario: Contested status excluded
- **WHEN** a resource's license status is contested or unverified
- **THEN** it is excluded from the shipped catalog
- **AND** it is recorded in an excluded list with the reason

### Requirement: Research corpus availability
The system SHALL support academic-grade public-domain commentary that has no ready-made
distribution, by building modules from archival sources, and SHALL label each commentary with its
genre so devotional and critical works are distinguishable.

#### Scenario: Genre labelling
- **WHEN** the library lists a commentary
- **THEN** it is labelled as critical, expository, homiletic or devotional

#### Scenario: Building from an archival source
- **WHEN** a public-domain commentary is built from an archival source
- **THEN** the tooling records the source, the edition and the transcription method

#### Scenario: Granularity is declared
- **WHEN** a commentary is built
- **THEN** its granularity is declared as verse, chapter or book
- **AND** the application renders it accordingly
