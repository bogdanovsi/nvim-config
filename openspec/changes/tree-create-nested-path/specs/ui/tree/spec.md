## Purpose

Let the user add a file from the tree by editing a full destination path, creating any missing parent directories in one step.

## ADDED Requirements

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
