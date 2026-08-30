## Purpose

Provide a filesystem-only directory scanner that the BSI tree UI consumes: bounded, ignore-aware, independent of windows and icons, and fast enough that large folders stay interactive.

## ADDED Requirements

### Requirement: Scanner is a filesystem module, not UI

The directory scanner SHALL be a standalone filesystem component. Invoking it MUST NOT create buffers, windows, or highlight groups, and MUST NOT load icon plugins. Returned nodes SHALL describe path, name, type (`file` | `directory` | `root`), depth, expansion stubs, and children only.

#### Scenario: Scan without a tree window

- **WHEN** a caller scans a temporary directory with no UI session setup beyond headless Neovim
- **THEN** the scan returns a node tree
- **AND** no tree buffer or window is created

#### Scenario: Nodes carry no presentation fields

- **WHEN** a file node is produced
- **THEN** it has `path`, `name`, and `type` `"file"`
- **AND** it does not require icon or highlight fields to be valid

### Requirement: Bounded one-level directory scan

When scanning a directory without expand-all, the scanner SHALL return that directory’s direct children only. Child directories SHALL be unpopulated stubs (no recursive descent into their contents). Expand-all MAY populate the full subtree.

#### Scenario: Wide directory with nested children

- **WHEN** a directory contains at least 1000 files and several subdirectories that each contain nested files
- **AND** the scanner runs a one-level (non expand-all) scan of that directory
- **THEN** the result includes those files and subdirectory stubs as direct children
- **AND** no nested file from inside a child directory appears in the result tree

#### Scenario: Expand-all populates descendants

- **WHEN** a small nested directory is scanned with expand-all
- **THEN** descendant files under child directories are present in the result tree

### Requirement: Name-based ignore skips heavy directories

When ignored names are hidden, the scanner SHALL skip directories named `node_modules`, `vendor`, `dist`, `build`, `target`, and `.git`, and SHALL NOT descend into them. Dotfiles other than `.git` SHALL still be included.

#### Scenario: Huge node_modules is skipped

- **WHEN** a directory contains a `node_modules` folder with thousands of nested files and ignored names are hidden
- **AND** the scanner scans that directory
- **THEN** `node_modules` is absent from the children
- **AND** the scan does not enumerate files inside `node_modules`

#### Scenario: Ignored names are visible when shown

- **WHEN** the same directory is scanned with ignored names shown
- **THEN** `node_modules` appears as a child

#### Scenario: Dotfiles remain visible

- **WHEN** a directory contains `.env` and `.git` and ignored names are hidden
- **THEN** `.env` is present
- **AND** `.git` is absent

### Requirement: Stable child order and single-child collapse

Direct children SHALL be ordered directories before files, then by case-insensitive name, with `.git` (when shown) before other dot-directories. A directory whose only child is another directory SHALL collapse into a single `parent/child` name node, preserving the grandchild list.

#### Scenario: Directories sort before files

- **WHEN** a directory contains `a.txt` and `b/`
- **THEN** the first child is directory `b`
- **AND** the second child is file `a.txt`

#### Scenario: Single-child directory chain collapses

- **WHEN** expand-all scans `foo/bar/baz.txt` with no siblings
- **THEN** the tree exposes a collapsed directory name containing `foo/bar`
- **AND** `baz.txt` is a child of that collapsed node

### Requirement: Missing path is safe

Scanning a path that does not exist or cannot be listed SHALL NOT raise. The scanner SHALL return a node with empty children or no node, without throwing.

#### Scenario: Absent directory

- **WHEN** the scanner is given a path that does not exist
- **THEN** it returns without error
- **AND** no children are produced for that path

### Requirement: Large-directory scan stays interactive

A one-level scan of a large directory MUST complete within 200 milliseconds on the test machine. “Large” means at least 5000 direct entries plus at least one ignored nested tree of at least 5000 files. Automated tests MUST fail if the scan exceeds that budget.

#### Scenario: Wide directory meets budget

- **WHEN** a temporary directory is created with 5000 files at the top level
- **AND** a one-level scan runs against it
- **THEN** the scan returns within 200 milliseconds
- **AND** the result contains 5000 file children

#### Scenario: Nested ignored tree does not blow the budget

- **WHEN** a temporary directory contains a hidden `node_modules` tree of at least 5000 files plus a modest number of real children
- **AND** a one-level scan runs with ignored names hidden
- **THEN** the scan returns within 200 milliseconds
- **AND** the ignored tree is not present in the result

### Requirement: Automated unit and performance coverage

The project SHALL ship automated tests that target the filesystem scanner directly (no tree UI). Unit tests MUST cover ignore, stubs, expand-all, sort, collapse, missing paths, and node shape. Performance tests MUST use disposable fixture trees, enforce the 200 millisecond budget, and MUST NOT commit fixtures to the repository. Both SHALL run with the existing headless Lua test command.

#### Scenario: Tests run with the existing suite

- **WHEN** `make test` runs
- **THEN** the scanner unit and performance tests execute as part of that suite
- **AND** they pass against generated fixtures
