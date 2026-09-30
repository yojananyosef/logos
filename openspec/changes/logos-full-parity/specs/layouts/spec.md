# Spec Delta

## Purpose

Define the layout system — tile arrangements, the QuickStart layout catalogue, saved layouts,
chronological workspace snapshots and the Get Started Wizard.

## ADDED Requirements

### Requirement: Tile arrangements
The system SHALL offer six tile arrangements for the workspace, and SHALL apply the chosen
arrangement to the open panels.

#### Scenario: Switch arrangement
- **WHEN** the user switches tile arrangement
- **THEN** the open panels are re-tiled in the new arrangement

#### Scenario: Arrangement with fewer panels than tiles
- **WHEN** fewer panels are open than the arrangement has tiles
- **THEN** the empty tiles are handled without layout error

### Requirement: QuickStart layout catalogue
The system SHALL provide QuickStart layouts for Bible and Commentary, Bible Journaling, Bible
Reading Plan, Daily Devotional, Greek Word Study, Hebrew Word Study, Lectionary, Passage Study,
Study Bible and Topic Study, and SHALL open a chosen layout pre-populated with the appropriate
resources.

#### Scenario: Open a QuickStart layout
- **WHEN** the user opens the Greek Word Study QuickStart layout
- **THEN** the workspace opens with a Greek Bible, a Greek lexicon and a Greek word study ready

#### Scenario: Layout without owned resources
- **WHEN** a required resource for a layout is not owned
- **THEN** the layout reports the missing resource
- **AND** the rest of the layout still opens

### Requirement: Saved layouts
The system SHALL allow the current workspace arrangement to be saved as a named layout, and SHALL
restore a saved layout on demand.

#### Scenario: Save a layout
- **WHEN** the user saves the current arrangement with a name
- **THEN** it appears in the saved layouts list

#### Scenario: Restore a layout
- **WHEN** the user opens a saved layout
- **THEN** the workspace returns to that arrangement with its resources

### Requirement: Workspace snapshots
The system SHALL capture the workspace state over time so the user can return to an earlier
working state.

#### Scenario: Capture a snapshot
- **WHEN** the user captures a snapshot
- **THEN** the current tabs, panes and active resources are recorded with a timestamp

#### Scenario: Return to a snapshot
- **WHEN** the user restores an earlier snapshot
- **THEN** the workspace returns to that recorded state

### Requirement: Get Started Wizard
The system SHALL offer a wizard that takes an activity — personal study, group study, sermon
preparation, or a user-defined activity — and generates a matching layout.

#### Scenario: Wizard generates a layout
- **WHEN** the user selects sermon preparation in the wizard
- **THEN** a layout tailored to sermon preparation is generated

#### Scenario: Wizard is cancellable
- **WHEN** the user cancels the wizard
- **THEN** no layout is created and the workspace is unchanged

### Requirement: Layout persistence across sessions
The system SHALL remember the workspace layout and the selected arrangement, and SHALL restore
them on the next launch.

#### Scenario: Restore after relaunch
- **WHEN** the application is reopened
- **THEN** the previous layout and arrangement are restored

### Requirement: Dashboard layout configuration
The system SHALL allow the dashboard to display three, four, five or an automatic number of card
columns, SHALL allow the marketing banner to be toggled, and SHALL allow cards to be added,
rearranged and removed.

#### Scenario: Column count
- **WHEN** the user sets the dashboard to four columns
- **THEN** the dashboard lays out cards in four columns

#### Scenario: Remove a card
- **WHEN** the user removes a card
- **THEN** it no longer appears on the dashboard

#### Scenario: Rearrange cards
- **WHEN** the user drags a card to a new position
- **THEN** the card order changes accordingly

#### Scenario: Automatic columns
- **WHEN** the column count is set to automatic
- **THEN** the count is derived from the current layout class
