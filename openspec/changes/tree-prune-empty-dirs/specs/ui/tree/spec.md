## Purpose

Remove nested directories that contain no files after a tree delete or move, so git working trees do not keep empty folder trash.

## ADDED Requirements

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
