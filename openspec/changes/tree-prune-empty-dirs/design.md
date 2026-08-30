## Context

See proposal.md. Nested create (`bsi.fs.create`) mkdir’s intermediate dirs. `Tree:_delete_node` uses `vim.fn.delete` and refreshes; it does not walk parents. `_move_path` can leave the source parent empty. Git never records empty directories.

## Goals / Non-Goals

**Goals:**
- A testable prune helper: given tree root + start directory, delete upward while subtrees have zero files.
- Call it after delete and after a successful move from the old parent.
- Keep `.gitkeep` / any file as a reason to stop.

**Non-Goals:**
- A separate “clean empty dirs” keymap.
- Pruning on create or on tree open/refresh of the whole project.
- Deleting the tree root or paths outside the root.
- Treating directories with only empty subdirs as “having content”.

## Decisions

### Decision 1: Helper `lua/bsi/fs/prune.lua`

```lua
prune(root, start_dir) → { removed = { paths... } }
```

`start_dir` is the parent of the deleted/moved path (or the deleted directory’s parent). Walk:

1. Normalize `root` and `dir`; abort if `dir` is not under `root`.
2. While `dir ~= root`:
   - If `has_files(dir)` (recursive scandir; files and symlinks-to-files count; do not follow dir symlinks), **stop**.
   - Else `vim.fn.delete(dir, "rf")`, record path, `dir = parent(dir)`.
3. Never delete `root`.

`has_files`: DFS with the existing scan backends or raw `fs_scandir_next` types. First file found → true. Ignore `.` / `..`.

Alternative: only `rmdir` if the directory has **no entries**. Rejected: `app/` containing empty `hooks/` would not be removed until hooks is removed first; a recursive “no files in subtree” then `delete rf` removes the whole empty chain in one step.

### Decision 2: When to call

- `_delete_node`: after successful delete, `prune(self.root_path, vim.fn.fnamemodify(path, ":h"))`.
- `_move_path` / `rename_or_move`: after success, prune the **old** parent if it is still under `root_path` and different from the new parent (don’t prune the destination).

Do not ask the user; empty-of-files dirs are the trash described in the proposal.

### Decision 3: Refresh once

Delete/move already `refresh()`. Prune before that refresh so the UI drops empty dirs. No second refresh.

## Risks / Trade-offs

- [Accidentally deleting a dir that only had ignored names like `node_modules` with files] → Mitigation: `has_files` counts **all** files, not the tree ignore list. `node_modules` with packages is kept.
- [`.DS_Store` keeps a “empty” folder] → Mitigation: it is a file; that is correct vs gitkeep-style markers. Users can delete the file first.
- [Symlink to a directory with files] → Mitigation: treat dir symlinks as non-file entries and do not descend; a dir that only contains a symlink-to-dir could be pruned. Acceptable; do not follow out of tree.
- [Race with another process adding a file] → Mitigation: `delete rf` on a dir we just saw as file-empty; rare in this UI.

## Migration Plan

No config. Behavior of `d`/`r`/`u` gains prune. Revert `prune.lua` + the two call sites to roll back.
