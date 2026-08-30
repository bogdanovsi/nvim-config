## Why

`tree-create-nested-path` can mkdir a chain like `src/app1/app/` when adding a file. Git does not track directories, only files, so after the last file in that chain is deleted (or moved away) the empty folders stay on disk as local trash. The tree should prune those empty ancestors so a clone stays file-shaped.

## What Changes

- After a successful **file or directory delete** (`d`), walk up from the deleted path’s parent and remove every directory whose subtree contains **no files**, stopping at the first directory that still has a file or at the tree root (root is never removed).
- After a successful **rename/move** (`r`/`u`) out of a directory, prune empty ancestors of the **old** path the same way.
- A directory “contains files” if any file exists anywhere under it, including hidden files (`.gitkeep`, `.DS_Store`). Empty nested directories alone do not keep a parent.
- Do not follow directory symlinks out of the tree when deciding emptiness.
- Refresh the tree after prune so empty folders disappear from the UI.

## Capabilities

### New Capabilities

- `ui/tree`: Prune empty nested directories after delete/move so leftover mkdir chains from nested create do not remain in a git working tree.

### Modified Capabilities

- (none — `openspec/specs/` still has no archived `ui/tree`; this is additive to the unarchived create/scan changes)

## Impact

- New `lua/bsi/fs/prune.lua` — testable prune helper (walk up, recursive “has files?”, `rmdir`/`delete` empty trees).
- `lua/bsi/ui/tree.lua` — call prune after `_delete_node` and after a successful `_move_path` from the source parent.
- Tests in `lua/bsi/fs/prune_spec.lua`.
- Keymaps stay `d` / `r` / `u`. No extra user prompt for the prune itself (it only removes dirs with zero files).
