## ADDED Requirements

### Requirement: Gitignore status is derived from scanned gitignore files

After a directory scan, the system SHALL compute gitignore status for scanned paths from `.gitignore` files that appear among those scanned entries. Patterns in a `.gitignore` file SHALL apply to scanned descendants of that file’s directory. The system MUST NOT run `git status` (including porcelain, `--ignored=matching`, or untracked expansion) to produce this information. `.git/info/exclude`, global excludes, and the git index SHALL NOT be required.

#### Scenario: Root gitignore marks a matching file

- **WHEN** a directory contains `.gitignore` with the pattern `*.log` and a file `debug.log`
- **AND** the directory is scanned
- **THEN** `debug.log` is marked gitignored
- **AND** `.gitignore` itself is not marked gitignored unless a pattern matches it

#### Scenario: No gitignore means no gitignore status

- **WHEN** a directory has files but no `.gitignore`
- **AND** the directory is scanned
- **THEN** those files are not marked gitignored

#### Scenario: Works without a git repository

- **WHEN** a temporary directory is not a git repository
- **AND** it contains `.gitignore` with `secret.env` and a file `secret.env`
- **AND** the directory is scanned
- **THEN** `secret.env` is marked gitignored
- **AND** the operation does not fail for lack of git

### Requirement: Nested gitignore files and negation apply to scanned children

A `.gitignore` file in a scanned subdirectory SHALL apply to that subdirectory’s scanned children, in addition to patterns from ancestor `.gitignore` files already seen. A later negation pattern (`!`) SHALL un-ignore a scanned path that an earlier pattern ignored.

#### Scenario: Nested gitignore applies under its directory

- **WHEN** the root `.gitignore` is empty
- **AND** `pkg/.gitignore` contains `dist/`
- **AND** `pkg` is scanned (including its direct children)
- **THEN** `pkg/dist` is marked gitignored
- **AND** a sibling of `dist` under `pkg` is not marked gitignored unless another pattern matches it

#### Scenario: Negation un-ignores a scanned file

- **WHEN** `.gitignore` contains `*.log` then `!keep.log`
- **AND** the directory contains `debug.log` and `keep.log`
- **AND** the directory is scanned
- **THEN** `debug.log` is marked gitignored
- **AND** `keep.log` is not marked gitignored

### Requirement: Parent gitignore marks unpopulated directory stubs

When a scanned `.gitignore` ignores a child directory, that child SHALL be marked gitignored even if it is an unpopulated stub. The system MUST NOT enumerate that stub’s contents in order to mark it.

#### Scenario: Ignored directory stub is marked without descent

- **WHEN** `.gitignore` contains `build/`
- **AND** a one-level scan finds directory `build` as a child
- **THEN** the `build` node is marked gitignored
- **AND** files inside `build` are not listed as a result of that mark

### Requirement: Gitignored files and directories render grey

When a scanned file or directory is marked gitignored and is shown in the tree, the system SHALL highlight its arrow, icon, and name with the ignored (grey) highlight. Name-based skip of `node_modules`, `vendor`, `dist`, `build`, `target`, and `.git` SHALL still hide those names when ignored names are hidden. Gitignored scanned entries SHALL remain listed (grey), not omitted, when they are not also name-based skips.

#### Scenario: Gitignored file is grey

- **WHEN** `.gitignore` contains `secret.env` and that file exists
- **AND** the tree shows that directory
- **THEN** `secret.env` is visible
- **AND** its row uses the ignored grey highlight

#### Scenario: Gitignored directory is grey

- **WHEN** `.gitignore` contains `build/`
- **AND** directory `build` is a scanned child
- **THEN** the `build` row uses the ignored grey highlight

#### Scenario: Name-based skip still hides node_modules

- **WHEN** ignored names are hidden
- **AND** the directory contains `node_modules`
- **THEN** `node_modules` is not shown
- **AND** a gitignored file such as `secret.env` is still shown grey

### Requirement: Gitignore annotation does not use git dump commands

Building gitignore status MUST NOT spawn whole-repo porcelain status, untracked-directory expansion, or `.git` file watchers.

#### Scenario: Annotation does not require git status

- **WHEN** gitignore status is built for a scanned directory that contains a `.gitignore` file
- **THEN** the result is produced without running `git status`

### Requirement: Dirty files show plus-minus line counts

For a shown file that is not gitignored, if staged and unstaged numstat together have added or deleted lines, the tree SHALL append the previous format after the name: ` +N-M` when both are non-zero, ` +N` when only added, ` -M` when only deleted. Additions SHALL use the added highlight and deletions the deleted highlight. Gitignored rows SHALL NOT show these counts.

#### Scenario: File with adds and deletes

- **WHEN** a visible file has numstat added 23 and deleted 23
- **AND** it is not gitignored
- **THEN** the row includes ` +23-23` after the name
- **AND** `+23` uses the added highlight
- **AND** `-23` uses the deleted highlight

#### Scenario: Add-only and delete-only

- **WHEN** a file has only added lines
- **THEN** the row includes ` +N` and not a `-0`
- **WHEN** a file has only deleted lines
- **THEN** the row includes ` -M` and not a `+0`

#### Scenario: Gitignored file has no numstat text

- **WHEN** a file is marked gitignored
- **AND** numstat data exists for that path
- **THEN** the row does not append `+N-M`

### Requirement: Numstat attaches without a filesystem re-scan

Numstat SHALL be fetched asynchronously after the tree is already populated from the filesystem scan. When it arrives, the system SHALL attach counts to existing file nodes and re-render. It MUST NOT re-list directories to apply numstat. A missing git root or a failed git command SHALL leave nodes without counts and MUST NOT fail the scan.

#### Scenario: Tree is usable before numstat returns

- **WHEN** a repository tree is opened
- **THEN** the filesystem listing is shown without waiting for numstat
- **AND** `+N-M` appears on dirty files after numstat arrives without a new directory listing

#### Scenario: Not a git repository

- **WHEN** the tree root is not inside a git repository
- **THEN** the scan still succeeds
- **AND** no `+N-M` text is shown

## MODIFIED Requirements

### Requirement: Scanner is a filesystem module, not UI

The directory scanner SHALL be a standalone filesystem component. Invoking it MUST NOT create buffers, windows, or highlight groups, and MUST NOT load icon plugins. Returned nodes SHALL describe path, name, type (`file` | `directory` | `root`), depth, expansion stubs, and children. Nodes MAY include gitignore status and file numstat derived after the listing. They MUST NOT require icon or highlight fields to be valid.

#### Scenario: Scan without a tree window

- **WHEN** a caller scans a temporary directory with no UI session setup beyond headless Neovim
- **THEN** the scan returns a node tree
- **AND** no tree buffer or window is created

#### Scenario: Nodes carry no presentation fields

- **WHEN** a file node is produced
- **THEN** it has `path`, `name`, and `type` `"file"`
- **AND** it does not require icon or highlight fields to be valid

#### Scenario: Gitignore status is data, not presentation

- **WHEN** a scanned file is marked gitignored
- **THEN** the node includes gitignore status
- **AND** it still does not require icon or highlight fields to be valid

### Requirement: Large-directory scan stays interactive

A one-level scan of a large directory, including building gitignore status from scanned `.gitignore` files, MUST complete within 200 milliseconds on the test machine. “Large” means at least 5000 direct entries plus at least one ignored nested tree of at least 5000 files. The timed path SHALL NOT include numstat git commands. Automated tests MUST fail if that work exceeds that budget.

#### Scenario: Wide directory meets budget

- **WHEN** a temporary directory is created with 5000 files at the top level
- **AND** a one-level scan runs against it, including gitignore annotation
- **THEN** the scan returns within 200 milliseconds
- **AND** the result contains 5000 file children

#### Scenario: Nested ignored tree does not blow the budget

- **WHEN** a temporary directory contains a hidden `node_modules` tree of at least 5000 files plus a modest number of real children
- **AND** a one-level scan runs with ignored names hidden, including gitignore annotation
- **THEN** the scan returns within 200 milliseconds
- **AND** the ignored tree is not present in the result

#### Scenario: Gitignore file does not blow the budget

- **WHEN** a temporary directory contains 5000 top-level files and a `.gitignore` that ignores a subset of them
- **AND** a one-level scan runs including gitignore annotation
- **THEN** the work returns within 200 milliseconds
- **AND** matching files are marked gitignored

### Requirement: Automated unit and performance coverage

The project SHALL ship automated tests that target the filesystem scanner and gitignore annotation directly (no tree UI required for those tests). Unit tests MUST cover ignore, stubs, expand-all, sort, collapse, missing paths, node shape, gitignore matching, nested `.gitignore` files, negation, parent-ignored stubs, grey highlighting of gitignored rows, and `+N-M` formatting for file numstat. Performance tests MUST use disposable fixture trees, enforce the 200 millisecond budget including gitignore annotation, and MUST NOT commit fixtures to the repository. Both SHALL run with the existing headless Lua test command.

#### Scenario: Tests run with the existing suite

- **WHEN** `make test` runs
- **THEN** the scanner unit and performance tests execute as part of that suite
- **AND** they pass against generated fixtures
- **AND** gitignore unit tests execute as part of that suite
- **AND** tests for grey gitignored rows and `+N-M` formatting execute as part of that suite
