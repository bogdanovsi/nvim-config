## Purpose

Provide one floating window slot for many named TUI sessions so hiding a tool closes only the window, the process keeps running, and reopening restores the same session.

## ADDED Requirements

### Requirement: Hidden named sessions keep their jobs

Hiding a named TUI float SHALL close its window and SHALL NOT stop the job. Terminal buffers for named sessions SHALL remain valid while hidden. `hidden` SHALL be enabled so Neovim does not discard those buffers.

#### Scenario: Hide leaves the process running

- **WHEN** a named TUI is open in the float
- **AND** the user hides it
- **THEN** the floating window is closed
- **AND** the tool's job is still running
- **AND** the terminal buffer still exists

#### Scenario: Hidden buffers are not discarded

- **WHEN** a named TUI is hidden
- **THEN** Neovim's `hidden` option is on
- **AND** the session buffer is not wiped solely because it is no longer displayed

### Requirement: Reopening a named tool restores the same session

Toggling a named tool that is already running SHALL show the same terminal buffer, not spawn a second job. The TUI SHALL resume at its previous UI state (same process).

#### Scenario: Second open is the same job

- **WHEN** the user has opened lazygit and then hidden it
- **AND** they open lazygit again
- **THEN** the same terminal buffer is shown
- **AND** a second lazygit process is not started

#### Scenario: Toggle of the visible tool hides it

- **WHEN** a named TUI is the visible float
- **AND** the user triggers that same tool's toggle again
- **THEN** the float is hidden
- **AND** the job keeps running

### Requirement: Only one named float is visible at a time

Opening a named TUI SHALL hide any other named TUI float first. Hidden tools SHALL keep running. Unrelated editor windows SHALL not be closed.

#### Scenario: Switching tools hides the previous float

- **WHEN** lazygit is the visible float
- **AND** the user opens k9s
- **THEN** the lazygit window is hidden
- **AND** the lazygit job is still running
- **AND** k9s is the visible float

#### Scenario: Switching back restores the first session

- **WHEN** lazygit was hidden by opening k9s
- **AND** the user opens lazygit again
- **THEN** the same lazygit session is shown
- **AND** k9s is hidden and still running

### Requirement: Named catalog and existing entry points

The manager SHALL expose named sessions for at least `lazygit`, `k9s`, `grok`, `lazydocker`, and `shell`. Existing user commands `:LazyGit`, `:LG`, `:K9S`, and `:LazyDocker` SHALL open those named sessions. Existing keys `<leader>gg` and `<leader>lg` SHALL toggle lazygit; `<leader>dd` SHALL toggle lazydocker.

#### Scenario: Existing lazygit keys use the named session

- **WHEN** the user presses `<leader>gg` or `<leader>lg`
- **THEN** the named lazygit session is toggled in the float

#### Scenario: Existing lazydocker key uses the named session

- **WHEN** the user presses `<leader>dd`
- **THEN** the named lazydocker session is toggled in the float

#### Scenario: Existing commands still work

- **WHEN** the user runs `:LazyGit`, `:LG`, `:K9S`, or `:LazyDocker`
- **THEN** the corresponding named session is toggled

### Requirement: Additional keys, last-tool toggle, and picker

`<leader>tk` SHALL toggle k9s. `<leader>xg` SHALL toggle grok. `<C-\>` SHALL toggle the last named tool that was shown, or `shell` if none has been shown yet. A picker (`<leader>T`) SHALL list named tools and toggle the chosen one. These keys SHALL NOT replace neotest's `<leader>tt` (run file) or `<leader>tx` (stop).

#### Scenario: k9s and grok have dedicated keys

- **WHEN** the user presses `<leader>tk`
- **THEN** the named k9s session is toggled
- **WHEN** the user presses `<leader>xg`
- **THEN** the named grok session is toggled

#### Scenario: Last-tool toggle

- **WHEN** the user last opened k9s
- **AND** they press `<C-\>`
- **THEN** k9s is toggled (shown if hidden, hidden if visible)

#### Scenario: Last-tool defaults to shell

- **WHEN** no named TUI has been shown in this Neovim session
- **AND** the user presses `<C-\>`
- **THEN** the named shell session is toggled

#### Scenario: Picker lists named tools

- **WHEN** the user opens the CLI tool picker
- **AND** they choose a listed name
- **THEN** that named session is toggled

#### Scenario: Neotest keys are unchanged

- **WHEN** the user presses `<leader>tt` or `<leader>tx` in a normal buffer
- **THEN** those keys still run the existing neotest file-run and stop actions

### Requirement: TUIs keep Esc and q

Named TUI floats SHALL NOT map Esc or terminal-mode `q` to hide the window. Hide SHALL use the tool's toggle key or `<C-\>`.

#### Scenario: Esc reaches the TUI

- **WHEN** lazygit, k9s, or grok is the visible float and is in terminal mode
- **AND** the user presses Esc
- **THEN** the float stays open
- **AND** the key is delivered to the TUI

### Requirement: Float appearance and insert mode

A named TUI SHALL open as a rounded-border float occupying about 90% of the editor width and height, and SHALL start in insert/terminal mode so the TUI receives keys immediately.

#### Scenario: Size and insert

- **WHEN** a named TUI is shown
- **THEN** it is a floating window with a rounded border
- **AND** it is about 90% of editor columns and lines
- **AND** Neovim is in insert mode in that terminal

### Requirement: Process exit policy

Quitting lazygit SHALL close its session (the process is meant to exit). For other named tools, if the process exits the terminal buffer SHALL remain so output can be read until the user dismisses it. Reopening a closed lazygit session SHALL start a new job.

#### Scenario: Lazygit quit ends the session

- **WHEN** the user quits lazygit from inside the TUI
- **THEN** the float is closed
- **AND** the next lazygit toggle starts a new job

#### Scenario: Other tools keep the buffer after exit

- **WHEN** k9s, grok, lazydocker, or shell exits
- **THEN** the terminal buffer remains available to read
- **AND** the float is not wiped solely because the process ended

### Requirement: One-shot floats stay one-shot

Generic one-shot terminal floats (including LSP log tail via `:LspLog`) SHALL remain a separate path. They SHALL NOT join the named exclusive-slot catalog. Closing a one-shot float MAY stop its job.

#### Scenario: LspLog is not a named exclusive session

- **WHEN** the user runs `:LspLog`
- **THEN** a one-shot float tails the LSP log
- **AND** it is not required to hide named TUIs through the exclusive-slot manager
- **AND** closing it may stop the tail job
