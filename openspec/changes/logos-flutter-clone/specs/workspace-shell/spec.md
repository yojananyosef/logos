# Spec Delta

## Purpose

Define the structural shell of the Logos study workspace — icon rail, collapsible sidebar,
resource tab strip, per-tab toolbar, sub-toolbar and resource panel — which hosts every
destination in the application and is reproduced 1:1 from the observed Logos web app.

## ADDED Requirements

### Requirement: Workspace shell layout
The system SHALL render the workspace as a horizontal composition of a fixed icon rail, a
collapsible sidebar and a content area, in that order from leading to trailing edge.

#### Scenario: Desktop composition
- **WHEN** the viewport width is 1440 logical pixels or greater
- **THEN** the icon rail, the sidebar and the content area are visible simultaneously
- **AND** the icon rail occupies exactly 48 logical pixels of width

#### Scenario: Resource panel is the content area host
- **WHEN** any destination is opened
- **THEN** the content area hosts the resource panel with a header row showing the resource
  name, a breadcrumb separator `›` and the current division, and a close control

### Requirement: Collapsible sidebar
The system SHALL allow the sidebar to collapse to icon-only width and to expand again, and
SHALL preserve the user's choice for the remainder of the session.

#### Scenario: Collapsing the sidebar
- **WHEN** the user activates the collapse control at the trailing edge of the sidebar footer
- **THEN** the sidebar reduces to a width that shows icons only
- **AND** all navigation labels become visually hidden while remaining present for assistive
  technology

#### Scenario: Expanded state is remembered
- **WHEN** the user collapses the sidebar, navigates to another destination, and returns
- **THEN** the sidebar is still collapsed

#### Scenario: Keyboard operation
- **WHEN** the sidebar is focused and the user activates the collapse control with the keyboard
- **THEN** the sidebar toggles without requiring a pointer

### Requirement: Primary navigation destinations
The system SHALL expose exactly these nine destinations in the sidebar, in this order:
Panel de Control, Biblioteca, Buscar, Biblia, Asistente de estudio, Enciclopedia bíblica,
Guías de Estudio, Notas, Herramientas.

Each SHALL display its icon and label, and exactly one SHALL be marked active at a time.

#### Scenario: Active destination is marked
- **WHEN** the user opens `Biblioteca`
- **THEN** `Biblioteca` is marked active with the active background colour
- **AND** every other destination is rendered in the inactive state

#### Scenario: Direct navigation to a destination
- **WHEN** the user activates `Notas`
- **THEN** the workspace opens the notes destination
- **AND** the sidebar reflects `Notas` as the active destination

### Requirement: Quick actions section
The system SHALL render a `Acciones Rápidas` section beneath the primary destinations
containing exactly: Abrir un comentario, Abrir una Biblia de estudio, Comparar versiones de la
Biblia, Abrir un diccionario bíblico, Abrir el devocional de hoy.

#### Scenario: Quick action opens its resource
- **WHEN** the user activates `Abrir un devocional` in the quick actions list
- **THEN** the corresponding resource is opened in a new tab
- **AND** that tab becomes the active tab

#### Scenario: Quick action runs a comparison
- **WHEN** the user activates `Comparar versiones de la Biblia`
- **THEN** the workspace opens the version comparison tool

### Requirement: Sidebar footer controls
The system SHALL render in the sidebar footer: Centro de ayuda, Entornos, Cerrar todos los
paneles, and a user session control.

#### Scenario: Close all panels
- **WHEN** the user activates `Cerrar todos los paneles`
- **THEN** every open resource tab is closed
- **AND** the workspace returns to the home dashboard

#### Scenario: Environments are listed
- **WHEN** the user activates `Entornos`
- **THEN** a chooser is presented listing the available study environments

### Requirement: Resource tab strip
The system SHALL display each open resource as a tab showing its short name, an accessibility
mode indicator and a close control, and SHALL support opening, activating, closing and
reordering tabs.

#### Scenario: Opening a resource creates a tab
- **WHEN** the user opens a resource that is not already open
- **THEN** a new tab is appended to the tab strip
- **AND** the new tab becomes the active tab

#### Scenario: Closing the active tab
- **WHEN** the user activates the close control on the active tab
- **THEN** that tab is removed
- **AND** the adjacent tab becomes active
- **AND** when no tabs remain, the home dashboard is shown

#### Scenario: Duplicate resources are not opened twice
- **WHEN** the user opens a resource that is already open in some tab
- **THEN** the existing tab is activated rather than a duplicate being created

#### Scenario: Overflow beyond available width
- **WHEN** the number of open tabs exceeds the width available in the tab strip
- **THEN** the tab strip scrolls horizontally
- **AND** the active tab is scrolled into view

### Requirement: Per-tab toolbar
The system SHALL render a toolbar on the active tab's panel exposing, in order: Inicio,
Búsqueda, Notas, Formato, Vista, Compartir, Más.

#### Scenario: Switching toolbar sections
- **WHEN** the user activates `Búsqueda` in the toolbar
- **THEN** the `Búsqueda` section becomes active
- **AND** it is marked with a 2 logical pixel bottom border in the primary colour
- **AND** the panel body presents the search interface for the active resource

#### Scenario: Section change does not open a new tab
- **WHEN** the user switches toolbar sections
- **THEN** the active tab remains the same tab

### Requirement: Sub-toolbar content sections
The system SHALL render a sub-toolbar on the resource panel exposing: Contenido, Historia,
Artículo, Conjunto de enlaces, Ideas, Información del libro.

#### Scenario: Opening the table of contents
- **WHEN** the user activates `Contenido`
- **THEN** a navigation panel presents the outline of the active resource

#### Scenario: Link set is presented
- **WHEN** the user activates `Conjunto de enlaces`
- **THEN** the curated set of links associated with the current position is presented

### Requirement: View controls
The system SHALL expose under `Vista`: Vista por páginas, Barra localizadora,
Aumentar/Disminuir with a percentage readout, and Pantalla completa.

#### Scenario: Zoom readout reflects state
- **WHEN** the user increases the text size
- **THEN** the percentage readout increases by the configured step
- **AND** the resource text renders at the new size

#### Scenario: Full screen
- **WHEN** the user activates `Pantalla completa`
- **THEN** the resource panel occupies the whole viewport
- **AND** exiting restores the previous layout
