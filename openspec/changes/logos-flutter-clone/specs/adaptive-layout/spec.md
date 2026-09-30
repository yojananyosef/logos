# Spec Delta

## Purpose

Define how the workspace adapts across viewport sizes from 360 logical pixels to 1440 and
beyond, so that every destination reflows without horizontal overflow and remains fully
operable on touch devices. This is the deliberate divergence from the original Logos web app,
which keeps a fixed 207 pixel sidebar and overflows horizontally below 600 pixels.

## ADDED Requirements

### Requirement: Breakpoint classification
The system SHALL classify the viewport into exactly four layout classes and SHALL react to
changes of class without losing workspace state.

| Class | Width | Behaviour |
|---|---|---|
| Compact | `< 600` | Compact chrome, single column, bottom navigation |
| Medium | `600–1023` | Collapsible sidebar, single content column, 2-column cards |
| Expanded | `1024–1439` | Full sidebar, 3-column cards, side-by-side panes |
| Large | `>= 1440` | Full sidebar, 3-column cards, side-by-side panes |

#### Scenario: Class changes on resize
- **WHEN** the viewport is resized across the 600 logical pixel boundary
- **THEN** the layout switches from Compact to Medium
- **AND** all open tabs, the active tab and the active toolbar section are preserved

#### Scenario: State survives a class change
- **WHEN** the user resizes the window while a resource is open on a non-default toolbar
  section
- **THEN** the same tab remains active on the same section after the resize

### Requirement: No horizontal overflow
The system SHALL NOT produce horizontal overflow of the document at any viewport width between
360 and 1440 logical pixels, for any destination.

#### Scenario: Compact viewport has no horizontal scroll
- **WHEN** the home dashboard is rendered at 360 logical pixels wide
- **THEN** the document scroll width equals the viewport width
- **AND** no element extends beyond the trailing edge

#### Scenario: Long content wraps instead of overflowing
- **WHEN** a resource title or paragraph is longer than the available width
- **THEN** the text wraps or is truncated with an ellipsis
- **AND** the container does not grow beyond its parent

#### Scenario: Dense text remains within bounds
- **WHEN** the Bible reader is rendered at 360 logical pixels wide with the largest supported
  text size
- **THEN** the text column stays within the viewport

### Requirement: Compact navigation
The system SHALL provide bottom navigation on compact viewports and SHALL keep the sidebar
reachable as an overlay drawer.

#### Scenario: Compact bottom navigation
- **WHEN** the layout class is Compact
- **THEN** a bottom navigation bar presents the nine primary destinations
- **AND** the icon rail and the expanded sidebar are not shown

#### Scenario: Drawer navigation
- **WHEN** the user opens the navigation drawer on a compact viewport
- **THEN** the drawer presents the full sidebar content including the quick actions section
  and the footer controls
- **AND** it overlays the content rather than displacing it

#### Scenario: Drawer closes on selection
- **WHEN** the user selects a destination from the drawer
- **THEN** the drawer closes
- **AND** the selected destination is shown

#### Scenario: Drawer closes on back
- **WHEN** the drawer is open and the user performs the system back gesture
- **THEN** the drawer closes without navigating

### Requirement: Pane stacking by class
The system SHALL present multiple open panes side by side on Expanded and Large viewports and
SHALL stack them vertically on Compact and Medium viewports.

#### Scenario: Side by side on large viewports
- **WHEN** two resources are open side by side at 1280 logical pixels
- **THEN** both panes are visible simultaneously, each receiving a share of the width

#### Scenario: Stacked on compact viewports
- **WHEN** two resources are open at 390 logical pixels
- **THEN** the panes are stacked vertically
- **AND** only the active pane is visible

#### Scenario: Divider only when it is meaningful
- **WHEN** panes are stacked vertically
- **THEN** no horizontal drag handle is presented

### Requirement: Touch targets
The system SHALL present every interactive control with a touch target of at least 44 by 44
logical pixels on touch-capable platforms.

#### Scenario: Sidebar destinations on touch
- **WHEN** the sidebar is rendered on a touch device
- **THEN** each destination row has a height of at least 44 logical pixels

#### Scenario: Tab close controls on touch
- **WHEN** a resource tab is rendered on a touch device
- **THEN** its close control has a touch target of at least 44 by 44 logical pixels

### Requirement: Typography legibility across classes
The system SHALL scale text and spacing between layout classes without producing unreadable
text at any width.

#### Scenario: Minimum body text size
- **WHEN** body text is rendered at any viewport width
- **THEN** its computed size is at least 14 logical pixels

#### Scenario: Reading measure on wide viewports
- **WHEN** the Bible reader is rendered at 1440 logical pixels or wider
- **THEN** the text column is constrained to a maximum readable measure
- **AND** the remaining space is not used to widen the column without limit

### Requirement: Card reflow
The system SHALL reflow the home dashboard and library card grids by layout class.

#### Scenario: Card counts per row
- **WHEN** the card grid is rendered
- **THEN** Compact shows one card per row, Medium two, Expanded three and Large three or
  more, subject to the available width

#### Scenario: No orphaned card
- **WHEN** the last row of the grid contains a single card
- **THEN** the grid still lays out within the container without overflow

### Requirement: Orientation change
The system SHALL preserve the active destination, the active tab and the scroll position of
the active pane across an orientation change on a touch device.

#### Scenario: Rotation preserves position
- **WHEN** the device is rotated from portrait to landscape while reading a passage
- **THEN** the same passage remains displayed
- **AND** the reading position is unchanged
