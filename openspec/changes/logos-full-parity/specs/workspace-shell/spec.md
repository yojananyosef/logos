# Spec Delta

## Purpose

Adds the command box, layout switching, link sets, the contextual new-tab panel and floating
panels to the workspace shell established in `logos-flutter-clone`, whose rail, sidebar, tab
strip, toolbars and split panes remain unchanged.

These are **ADDED** requirements rather than MODIFIED, because the shell requirements live in the
`logos-flutter-clone` change and have not yet been promoted to a main spec.

## ADDED Requirements

### Requirement: Command box
The system SHALL provide a command box that accepts a book, passage, topic, tool or command and
returns grouped actions, and SHALL navigate to the chosen action.

#### Scenario: Command box by passage
- **WHEN** the user types a passage reference in the command box
- **THEN** an action to open that passage is offered

#### Scenario: Command box by tool
- **WHEN** the user types a tool name
- **THEN** actions for that tool are offered

#### Scenario: Grouped results
- **WHEN** the command box returns results
- **THEN** they are grouped by kind

#### Scenario: Navigate via the command box
- **WHEN** the user selects a command box result
- **THEN** the corresponding destination or tab opens

### Requirement: New tab panel
The system SHALL present a contextual launcher when opening a new tab, showing everything
available and, when the previous panel was a Bible reference, additionally showing the tools,
books and guides relevant to that reference.

#### Scenario: Reference-keyed launcher
- **WHEN** the previous panel was a Bible reference
- **THEN** the launcher offers tools, books and guides for that reference

#### Scenario: General launcher
- **WHEN** the previous panel was not a reference
- **THEN** the launcher offers the full set of destinations

### Requirement: Link sets
The system SHALL allow a set of panels to be bound to a shared reference, and SHALL offer the
modes Follow, Align and Scroll for keeping those panels synchronised.

#### Scenario: Link set binding
- **WHEN** the user binds several panels to one reference
- **THEN** each panel tracks that reference

#### Scenario: Follow mode
- **WHEN** one panel in a follow-mode link set navigates
- **THEN** the other panels navigate to the same reference

#### Scenario: Align mode
- **WHEN** a panel in an align-mode link set navigates
- **THEN** the other panels align their display to the same position

#### Scenario: Scroll mode
- **WHEN** a panel in a scroll-mode link set scrolls
- **THEN** the other panels scroll to the corresponding position

### Requirement: Floating panels
The system SHALL allow any panel to be floated to its own window or view, docked back into the
workspace, duplicated, and set full screen, and SHALL preserve the panel's state through each
transition.

#### Scenario: Float a panel
- **WHEN** the user floats a panel
- **THEN** it is presented separately from the workspace
- **AND** its content and scroll position are preserved

#### Scenario: Dock back
- **WHEN** the user docks a floating panel
- **THEN** it returns to its tab

#### Scenario: Duplicate a panel
- **WHEN** the user duplicates a panel
- **THEN** a second tab is opened showing the same content at the same position

### Requirement: Shortcut bar
The system SHALL allow a user-visible bar of favourite resources and commands to be configured and
used to open them in one action.

#### Scenario: Add a shortcut
- **WHEN** the user adds a resource to the shortcut bar
- **THEN** it appears there and opens in one action

#### Scenario: Reorder shortcuts
- **WHEN** the user reorders the shortcut bar
- **THEN** the order changes accordingly

### Requirement: Panel operations
The system SHALL allow panels to be closed, moved between tabs, and reordered within a tab.

#### Scenario: Move a panel to another tab
- **WHEN** the user moves a panel to another tab
- **THEN** it leaves the source tab and joins the target

#### Scenario: Reorder panels
- **WHEN** the user reorders panels within a tab
- **THEN** they render in the new order

### Requirement: Multi-account profiles
The system SHALL allow switching between user profiles without restarting, and SHALL support
signing out of all but the current account.

#### Scenario: Switch profile
- **WHEN** the user switches profile
- **THEN** the workspace reflects that profile's library, notes and settings

#### Scenario: Clear other users
- **WHEN** the user clears other accounts
- **THEN** only the current account remains signed in

### Requirement: Synchronisation
The system SHALL synchronise documents and settings across the user's machines, SHALL allow a
manual synchronisation, and SHALL warn when synchronisation fails.

#### Scenario: Manual sync
- **WHEN** the user triggers a manual synchronisation
- **THEN** pending changes are exchanged

#### Scenario: Sync failure warning
- **WHEN** synchronisation fails
- **THEN** a warning is shown
- **AND** local work remains available

### Requirement: In-app store
The system SHALL provide an in-app store panel for browsing and acquiring resources.

#### Scenario: Open the store
- **WHEN** the user opens the store panel
- **THEN** the catalogue is presented
