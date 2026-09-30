# Spec Delta

## Purpose

Define the visual design system of the application — colour, typography, spacing, elevation and
the base components — reproducing the values extracted from the 1893 CSS custom properties that
the real Logos web app exposes, so the clone is visually indistinguishable on desktop.

## ADDED Requirements

### Requirement: Brand colour palette
The system SHALL use exactly these colours as its brand tokens.

| Token | Value | Role |
|---|---|---|
| `primary` | `#154AC9` | Active tab underline, toolbar icon hover, promotional banner, primary buttons |
| `navy` | `#030B60` | Subscriber badge, high-contrast branded surfaces |
| `link` | `#1E6AFE` | Inline links, cross-references |
| `linkHover` | `#4797FF` | Link hover, focus ring |
| `infoSoft` | `#E9F5FF` | Soft informational backgrounds, badge surfaces |
| `infoPill` | `#8BC5FF` | Pill surfaces on soft backgrounds |
| `textPrimary` | `#333333` | Body and toolbar text |
| `textSecondary` | `#515D72` | Toolbar icons, secondary text |
| `textTertiary` | `#63728C` | Tab bar icons, de-emphasised text |
| `textMuted` | `#888888` | Decorative icons |
| `textDisabled` | `#C7CFDC` | Disabled controls |
| `border` | `#E7E7E7` | Default borders, sidebar trailing edge |
| `borderStrong` | `#CCCCCC` | Hover borders, strong dividers |
| `surfaceSunken` | `#EEEEEE` | Toolbar buttons, selected content items |
| `surfaceHover` | `#F4F4F4` | Hover states, active tab bar icon background |
| `surface` | `#FFFFFF` | Sidebar, content and tab bar background |
| `danger` | `#CC3333` | Error badges, discount prices |
| `success` | `#55B155` | Completed reading plan |
| `warningSurface` | `#FFF4D5` | Alert bar background |
| `warningIcon` | `#DBA910` | Alert bar icon |
| `mapAccent` | `#FF6600` | Biblical places map |

#### Scenario: Brand primary is applied where Logos applies it
- **WHEN** a promotional banner is rendered
- **THEN** its background is `#154AC9` and its text is `#FFFFFF`

#### Scenario: Border colour parity
- **WHEN** the sidebar is rendered
- **THEN** its trailing border is 1 logical pixel of `#E7E7E7`

### Requirement: Typography
The system SHALL use **Source Sans Pro** as the primary typeface, with a system sans-serif
fallback, at a 16 logical pixel base size and weight 400.

#### Scenario: Base typography
- **WHEN** body copy is rendered
- **THEN** the font family resolves to Source Sans Pro
- **AND** the computed size is 16 logical pixels at weight 400

#### Scenario: Fallback when the font is unavailable
- **WHEN** Source Sans Pro cannot be loaded
- **THEN** the system sans-serif fallback is used
- **AND** layout does not overflow as a result

#### Scenario: Accessible text mode
- **WHEN** the user enables the limited view mode
- **THEN** text contrast is raised to at least WCAG AA against its background

### Requirement: Active tab indicator
The system SHALL mark the active tab and the active toolbar section with a 2 logical pixel
bottom border in `#154AC9` and a `#F4F4F4` background.

#### Scenario: Toolbar active section styling
- **WHEN** a toolbar section is active
- **THEN** it shows a 2 logical pixel bottom border in `#154AC9`
- **AND** a background of `#F4F4F4`

### Requirement: Spacing scale
The system SHALL derive all spacing from a fixed scale of 4, 8, 12, 16, 24 and 32 logical
pixels.

#### Scenario: No off-scale spacing
- **WHEN** padding or margin is applied to a standard component
- **THEN** the value is a member of the spacing scale

### Requirement: Base components
The system SHALL provide reusable components for the sidebar navigation item, tab strip tab,
toolbar section, sub-toolbar section, card, banner, filter chip and reader panel, each
supporting default, hover, pressed, selected, focused and disabled states.

#### Scenario: Hover state on a navigation item
- **WHEN** the pointer rests over a navigation item
- **THEN** the item shows its hover surface
- **AND** the item is not shown as selected

#### Scenario: Focus is always visible
- **WHEN** any interactive component receives keyboard focus
- **THEN** a focus indicator in `#4797FF` is visible

#### Scenario: Disabled state
- **WHEN** an action is unavailable
- **THEN** the control is rendered with the disabled colour
- **AND** it does not respond to activation

### Requirement: Theme parity with the source application
The system SHALL derive its default theme values from the captured design tokens rather than
from a generic Material palette.

#### Scenario: Primary is not the Material default
- **WHEN** the default theme is inspected
- **THEN** the primary colour is `#154AC9` and not the framework default blue

#### Scenario: Token provenance
- **WHEN** a theme colour is looked up
- **THEN** it corresponds to a documented token in the captured token set
