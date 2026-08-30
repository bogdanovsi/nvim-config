## ADDED Requirements

### Requirement: Tree window width follows visible indent and names

The tree window width SHALL be the maximum display width of currently visible rows (indent + arrow + icon + name and any git postfix), clamped to a configurable minimum and maximum. Defaults SHALL be 30 and 100 columns. Changing which rows are visible (open, expand, collapse, refresh) SHALL recompute the width while auto-fit is on.

#### Scenario: Short names use the minimum

- **WHEN** every visible row is shorter than 30 columns
- **AND** auto-fit is on
- **THEN** the tree window width is 30

#### Scenario: Medium names auto-size inside the band

- **WHEN** the longest visible row is 45 columns
- **AND** min is 30 and max is 100
- **AND** auto-fit is on
- **THEN** the tree window width is 45

#### Scenario: Deep indent plus long name still auto-fits under the max

- **WHEN** indent and name together are 52 columns
- **AND** auto-fit is on
- **THEN** the window width is 52

### Requirement: Width min and max are configurable

`width_min` and `width_max` SHALL be tree config (defaults 30 and 100). Auto-fit SHALL use those bounds. If min is greater than max, the system SHALL treat them as the same number (no inverted range).

#### Scenario: Custom max

- **WHEN** config sets `width_max` to 80
- **AND** the longest visible row is 70 columns
- **AND** auto-fit is on
- **THEN** the window width is 70

### Requirement: Content longer than max stays capped until the user expands

If the longest visible row is wider than `width_max`, auto-fit SHALL set the window to `width_max` and SHALL NOT grow past it. The user SHALL be able to expand the tree window past the max to fit that content, and to return to auto-fit.

#### Scenario: Over max stays at max

- **WHEN** the longest visible row is 120 columns
- **AND** `width_max` is 100
- **AND** auto-fit is on
- **THEN** the window width is 100

#### Scenario: Manual expand past max

- **WHEN** the longest visible row is 120 columns
- **AND** the user expands the tree window manually
- **THEN** the window is at least as wide as that row

#### Scenario: Return to auto-fit

- **WHEN** the user has expanded past max
- **AND** they restore auto-fit
- **THEN** the window width is again clamped to `[width_min, width_max]`
