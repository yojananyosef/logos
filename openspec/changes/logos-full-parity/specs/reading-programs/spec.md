# Spec Delta

## Purpose

Define the structured reading and devotional layer — the Reading Plan Manager and its in-text
experience, the lectionary, daily devotionals and prayer lists.

## ADDED Requirements

### Requirement: Reading plan creation
The system SHALL allow a reading plan to be created for the whole Bible, a passage range, a whole
book, or a custom chapter range of a book, with front matter excluded, and SHALL allow a plan to
be created from a template, from the dashboard, from the manager, from a new document, from an
open book's tools section, or from the library.

#### Scenario: Whole-Bible plan
- **WHEN** the user creates a plan for the whole Bible
- **THEN** the plan covers every chapter

#### Scenario: Chapter range of a book
- **WHEN** the user creates a plan for a chapter range
- **THEN** only those chapters are included
- **AND** the book's front matter is excluded

#### Scenario: Creation entry points
- **WHEN** the user creates a plan from the library
- **THEN** the plan creation flow opens

### Requirement: Reading plan schedule
The system SHALL allow a plan to be scheduled by a start date, the days of the week, a reminder
time, and a goal expressed as a finish-by date, a number of minutes per day, or a number of
sessions; and SHALL allow a plan with no schedule.

#### Scenario: Finish-by goal
- **WHEN** the user sets a finish-by date
- **THEN** the daily readings are distributed to meet that date

#### Scenario: Daily minutes goal
- **WHEN** the user sets a minutes-per-day goal
- **THEN** sessions are sized to meet that goal

#### Scenario: Unscheduled plan
- **WHEN** the user chooses no schedule
- **THEN** the plan has no dates and the user reads at their own pace

#### Scenario: Reminder time
- **WHEN** the user sets a reminder time
- **THEN** the reminder is scheduled for that time on reading days

#### Scenario: Edit after creation
- **WHEN** the user edits a plan's schedule
- **THEN** the new schedule applies

### Requirement: In-text reading experience
The system SHALL present the day's reading under a ribbon showing the date and the passage, SHALL
present a ribbon at the end of each section, SHALL present an end-of-session ribbon with a mark
done action, SHALL offer a skip-to-latest action that marks missed days skipped, and SHALL provide
toggleable margin indicators and a reminder button showing current state.

#### Scenario: Daily ribbon
- **WHEN** the user opens the book on a planned day
- **THEN** a ribbon shows today's date and passage

#### Scenario: Section-end ribbon
- **WHEN** the user reaches the end of a section
- **THEN** a ribbon marks the section boundary

#### Scenario: Mark done
- **WHEN** the user marks the session done
- **THEN** the day is recorded complete and the next session becomes available

#### Scenario: Skip to latest
- **WHEN** the user has missed days and activates skip to latest
- **THEN** the current day becomes the reading day
- **AND** missed days are marked skipped

#### Scenario: Margin indicators
- **WHEN** the user toggles margin indicators off
- **THEN** the margin markers are not rendered

### Requirement: Reading plan progress states
The system SHALL represent each day as on track, behind, skipped, complete or new, and SHALL
display an overall progress indicator.

#### Scenario: Behind state
- **WHEN** the current date has passed a planned day
- **THEN** that day is shown as behind

#### Scenario: Archived plan
- **WHEN** a plan is archived
- **THEN** it moves out of the active list and its progress is retained

#### Scenario: Restart a plan
- **WHEN** the user restarts a plan
- **THEN** its schedule begins again from the start date

### Requirement: Reading plan sharing
The system SHALL allow a plan to be kept private, shared for a group to read together, shared by
link, or published as a template, and SHALL allow export to a calendar file.

#### Scenario: Read together
- **WHEN** the user shares a plan for a group
- **THEN** group members can follow the same plan

#### Scenario: Publish as template
- **WHEN** the user publishes a plan as a template
- **THEN** it becomes available as a template for others

#### Scenario: Calendar export
- **WHEN** the user exports a plan to calendar
- **THEN** an `.ics` file with the sessions is produced

### Requirement: Lectionary
The system SHALL present the next lectionary event with the liturgical colour for the day on the
dashboard, SHALL open a lectionary layout containing the lectionary, prioritised Bibles,
prioritised commentaries, Cited By and Explorer, and SHALL support overlaying a calendar in the
sermon manager and generating sermon series from a lectionary and season.

#### Scenario: Lectionary card
- **WHEN** the dashboard is displayed
- **THEN** the lectionary card shows the next event and today's liturgical colour

#### Scenario: Lectionary layout
- **WHEN** the user opens the lectionary card
- **THEN** the lectionary layout opens with its five sections

#### Scenario: Series from lectionary
- **WHEN** the user generates sermons from a lectionary and season
- **THEN** sermons are created for the season's readings

### Requirement: Daily devotional
The system SHALL provide a daily devotional on the dashboard, SHALL open the highest-prioritised
devotional in a devotional layout with a prayer list and a date-matched reference entry.

#### Scenario: Devotional card
- **WHEN** the dashboard is displayed
- **THEN** the daily devotional card is present

#### Scenario: Devotional layout
- **WHEN** the user opens the devotional
- **THEN** the devotional layout opens with a prayer list and a date-matched reference entry

### Requirement: Prayer list
The system SHALL allow prayer requests to be recorded in a list with a recurrence frequency, and
SHALL allow the list to be created and read.

#### Scenario: Add a prayer request
- **WHEN** the user adds a prayer request
- **THEN** it appears in the prayer list

#### Scenario: Recurrence
- **WHEN** the user sets a recurrence frequency
- **THEN** the request recurs on that frequency

### Requirement: Reading plan lifecycle
The system SHALL support creating, tracking, archiving and restarting reading plans, and SHALL
show in-progress plans on the dashboard.

#### Scenario: Dashboard progress
- **WHEN** a reading plan is in progress
- **THEN** the dashboard shows its current day and progress
