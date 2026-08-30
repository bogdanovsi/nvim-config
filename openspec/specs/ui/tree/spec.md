# ui/tree Specification

## Purpose

Provide a filesystem-only directory scanner that the BSI tree UI consumes: bounded, ignore-aware, independent of windows and icons, and fast enough that large folders stay interactive.

## Requirements

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

### Requirement: Add prompt prefills an editable destination path

When adding a node, the prompt SHALL present the destination as editable text, not only a filename under a fixed parent. The default SHALL be the tree-root-relative path of the target directory with a trailing slash. The target directory is the directory under the cursor, or the parent of the file under the cursor.

#### Scenario: Cursor on a directory

- **WHEN** the user adds a node with the cursor on directory `src/app`
- **THEN** the input default is `src/app/`
- **AND** the prompt identifies a new file (for example `New file: `)

#### Scenario: Cursor on a file

- **WHEN** the user adds a node with the cursor on file `src/app/page.tsx`
- **THEN** the input default is `src/app/`

### Requirement: Edited path creates missing directories and the file

The submitted string SHALL be treated as the full destination. Relative paths resolve against the tree root. Absolute paths SHALL be used as given. Missing parent directories MUST be created. A path that does not end with `/` SHALL create an empty file at that location.

#### Scenario: Nested path with new parent dirs

- **WHEN** the default is `src/app/` and the user submits `src/app1/app/index.tsx`
- **THEN** directories `src/app1` and `src/app1/app` are created if missing
- **AND** an empty file `src/app1/app/index.tsx` exists

#### Scenario: Sibling file under the default directory

- **WHEN** the default is `src/app/` and the user submits `src/app/util.ts`
- **THEN** file `src/app/util.ts` is created
- **AND** no extra directories are created beyond those already present

#### Scenario: Absolute destination

- **WHEN** the user submits an absolute path `/tmp/example/foo.txt` whose parents do not all exist
- **THEN** missing parents are created
- **AND** the file exists at that absolute path

### Requirement: Trailing slash creates a directory only

A submitted path that ends with `/` SHALL create that directory (and missing parents) and SHALL NOT create an extra file.

#### Scenario: Directory-only create

- **WHEN** the user submits `src/app1/hooks/`
- **THEN** directory `src/app1/hooks` exists
- **AND** no file named `hooks` is created

### Requirement: Existing paths are not overwritten

If the resolved destination already exists as a file or directory, the system SHALL NOT overwrite it and SHALL notify the user.

#### Scenario: File already exists

- **WHEN** the user submits a path of an existing file
- **THEN** that file’s contents are unchanged
- **AND** a warning is shown

#### Scenario: Empty or cancelled input

- **WHEN** the user cancels or submits an empty string
- **THEN** no files or directories are created

### Requirement: Tree updates after a successful create

After a successful file create, the tree SHALL refresh and reveal the new file, and the file SHALL open in an editor. After a successful directory-only create, the tree SHALL refresh and reveal that directory.

#### Scenario: File create follows into the editor

- **WHEN** a new file is created successfully
- **THEN** the tree shows the new file
- **AND** the file is opened for editing

### Requirement: Empty ancestor directories are removed after delete

After a file or directory is deleted from the tree, the system SHALL remove each ancestor directory of that path whose subtree contains no files, walking upward until a directory that still contains a file or until the tree root. The tree root SHALL NOT be deleted.

#### Scenario: Last file in a nested create chain

- **WHEN** the tree root contains only `src/app1/app/index.tsx` plus other files under `src/` (not under `app1`)
- **AND** the user deletes `src/app1/app/index.tsx`
- **THEN** directories `src/app1/app` and `src/app1` no longer exist
- **AND** `src/` still exists

#### Scenario: Sibling file keeps the parent

- **WHEN** `src/app1/app/` contains `index.tsx` and `util.ts`
- **AND** the user deletes `index.tsx`
- **THEN** `src/app1/app` still exists
- **AND** `util.ts` is unchanged

#### Scenario: Nested empty dirs without files are removed together

- **WHEN** `src/app1/app/hooks/` exists with no files anywhere under `app1`
- **AND** prune starts at `src/app1/app/hooks`
- **THEN** `hooks`, `app`, and `app1` are all removed
- **AND** the tree root is unchanged

### Requirement: Hidden files count as contents

A directory SHALL NOT be pruned if its subtree contains any file, including dotfiles such as `.gitkeep`.

#### Scenario: gitkeep preserves the directory

- **WHEN** `src/empty/.gitkeep` exists
- **AND** prune starts at `src/empty`
- **THEN** `src/empty` still exists
- **AND** `.gitkeep` is unchanged

### Requirement: Empty ancestors are removed after a move out of a directory

After a file or directory is moved to a path outside its old parent, the system SHALL prune empty ancestor directories of the **old** path using the same rules as after delete.

#### Scenario: Move last nested file away

- **WHEN** the only file under `src/app1/` is `src/app1/app/index.tsx`
- **AND** the user moves it to `src/index.tsx`
- **THEN** `src/app1/app` and `src/app1` no longer exist
- **AND** `src/index.tsx` exists

### Requirement: Tree root is never pruned

Prune SHALL stop at the tree root even if the root would otherwise have no files.

#### Scenario: Last file under root

- **WHEN** the only file in the tree is `readme.md` at the root
- **AND** the user deletes `readme.md`
- **THEN** the tree root directory still exists

### Requirement: Tree refreshes after prune

After prune runs as part of delete or move, the tree SHALL refresh so removed directories are not shown.

#### Scenario: Deleted nested file disappears with empty parents

- **WHEN** the user deletes the last file in a nested empty chain
- **THEN** the tree no longer lists those empty directories
