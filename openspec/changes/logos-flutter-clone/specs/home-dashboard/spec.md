# Spec Delta

## Purpose

Define the home dashboard — `Panel de Control` — reproducing the promotional banner, the
`EXPLORAR` card section with its four observed card types, and the `De su biblioteca` section
presenting resources from the user's library.

## ADDED Requirements

### Requirement: Dashboard structure
The system SHALL present the dashboard in this order: a dismissible promotional banner, the
`EXPLORAR` section, and the `De su biblioteca` section, under the heading `Panel de inicio`.

#### Scenario: Section order
- **WHEN** the dashboard is rendered
- **THEN** the banner appears first, then `EXPLORAR`, then `De su biblioteca`

#### Scenario: Dashboard heading
- **WHEN** the dashboard is displayed
- **THEN** the page heading reads `Panel de inicio`

### Requirement: Promotional banner
The system SHALL render the promotional banner with the primary background, white text, a call
to action button and a dismiss control, and SHALL NOT show it again once dismissed.

#### Scenario: Banner composition
- **WHEN** the banner is visible
- **THEN** it shows the promotional message, a call to action button labelled
  `Ver descuentos` and a dismiss control

#### Scenario: Dismissal persists
- **WHEN** the user dismisses the banner, leaves the dashboard and returns
- **THEN** the banner is not shown again

#### Scenario: Call to action
- **WHEN** the user activates `Ver descuentos`
- **THEN** the promotions destination is presented

### Requirement: EXPLORAR section
The system SHALL present the `EXPLORAR` section as a reflowing grid of cards drawn from four
card types: Anuncio, Novedades, Pre-order and Banner de servicio.

#### Scenario: Section heading
- **WHEN** the dashboard is displayed
- **THEN** the section is labelled `EXPLORAR`

#### Scenario: Announcement card
- **WHEN** an Anuncio card is rendered
- **THEN** it shows a large title, a date badge, a dark branded background and a call to
  action button

#### Scenario: News card
- **WHEN** a Novedades card is rendered
- **THEN** it shows an image, a bold title, a body excerpt and an author attribution

#### Scenario: Pre-order card
- **WHEN** a Pre-order card is rendered
- **THEN** it shows a `Pre-orden` badge, the cover image, a bold title, a description and a
  `Pre-orden ahora` button

#### Scenario: Service banner card
- **WHEN** a Banner de servicio card is rendered
- **THEN** it shows an image, a title and a description

#### Scenario: Opening a card
- **WHEN** the user activates a card
- **THEN** the card's destination is presented

### Requirement: De su biblioteca section
The system SHALL present the `De su biblioteca` section with library resources, each showing a
cover, a title, an author or publisher and a description.

#### Scenario: Section heading
- **WHEN** the dashboard is displayed
- **THEN** the section is labelled `De su biblioteca`

#### Scenario: Library card content
- **WHEN** a library card is rendered
- **THEN** it shows the cover image, the resource title, the publisher or author and a
  description

#### Scenario: Opening a library resource
- **WHEN** the user activates a library card
- **THEN** the resource opens in a new tab and becomes the active tab

#### Scenario: Empty library
- **WHEN** the library contains no resources
- **THEN** the section presents an empty state rather than blank space

### Requirement: Dashboard loading and failure
The system SHALL show a loading state while dashboard content is being assembled and SHALL show
a recoverable error state if it cannot be assembled.

#### Scenario: Loading state
- **WHEN** the dashboard is fetching its content
- **THEN** a loading indicator is presented in place of the cards

#### Scenario: Retry after failure
- **WHEN** dashboard loading fails
- **THEN** an error state with a retry action is presented
- **AND** activating retry re-attempts the load

### Requirement: Dashboard reflow
The system SHALL reflow the dashboard card grid by layout class without horizontal overflow, as
defined by the adaptive layout capability.

#### Scenario: Compact dashboard
- **WHEN** the dashboard is rendered at 360 logical pixels
- **THEN** cards stack in a single column
- **AND** the document does not scroll horizontally

#### Scenario: Wide dashboard
- **WHEN** the dashboard is rendered at 1440 logical pixels
- **THEN** cards lay out in multiple columns
- **AND** the library section uses the full available width
