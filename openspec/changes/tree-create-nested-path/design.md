## Context

See proposal.md for motivation. `Tree:_add_file` in `lua/bsi/ui/tree.lua` prompts `New file (in <dir>): ` with **no default**. The callback does `target_dir .. "/" .. name` then `mkdir -p` of the parent. Nested names like `app1/app/index.tsx` already work **under the cursor dir**, but the parent itself is not in the editable string, so changing `src/app` → `src/app1/app` means leaving the folder first. Rename already uses `vim.ui.input` with `default = current` and `completion = "file"`.

## Goals / Non-Goals

**Goals:**
- Prefill a tree-relative path the user can edit.
- Resolve relative vs absolute; mkdir -p; file vs trailing-slash directory.
- Extract a testable create helper so tests do not drive `vim.ui.input`.

**Non-Goals:**
- Changing `r`/`u` rename-move.
- Templates / file contents.
- Multi-root trees or paths outside the filesystem.
- Telescope or floating-buffer pickers.

## Decisions

### Decision 1: Prompt is `New file: ` with `default` = relative target dir + `/`

`vim.fn.fnamemodify(target_dir, ":~:.")` when possible, else path relative to `self.root_path`. Always a trailing slash so the user types a filename or edits directories. `completion = "file"` like rename.

Alternative: empty default (nvim-tree often does this). Rejected: the user’s example is editing `src/app/index.tsx` in place.

Alternative: default includes a placeholder filename. Rejected: we don’t know the name; trailing slash is enough.

### Decision 2: Input is the full destination, not concatenated onto `target_dir`

If the string is absolute (`vim.startswith` `/` or Windows drive), use it. Otherwise join with `self.root_path` (not the cursor dir). `vim.fs.normalize` after join.

That way default `src/app/` + edit to `src/app1/app/index.tsx` is relative to the tree root, matching the example.

Empty / cancelled → no-op.

### Decision 3: Trailing `/` (after normalize) means mkdir only

nvim-tree convention. File create: `io.open(path, "w")` empty, same as today. Directory: `vim.fn.mkdir(path, "p")`. Existing dest → warn, return.

`..` and `.` segments are allowed after normalize; no extra jail beyond what mkdir/open would do. Stay on the user’s machine; tree root is a convenience base, not a sandbox.

### Decision 4: Extract `bsi.fs.create` for tests

Put resolve + mkdir + create in `lua/bsi/fs/create.lua`:

```lua
create(root, input) → { ok, path, kind = "file"|"dir"|"exists"|"empty", err }
```

`Tree:_add_file` computes default, calls `create(self.root_path, input)`, then refresh/find_file/edit. Tests hit `create` with temp roots.

Alternative: keep everything in `tree.lua` and test via Tree (needs a window). Rejected.

### Decision 5: After success, keep current UX

File: `refresh`, `find_file`, `wincmd l` + `edit`. Directory: `refresh` + `find_file` on the new dir (no extra editor buffer).

## Risks / Trade-offs

- [Relative to tree root, not cursor dir, surprises if user types a bare `foo.ts`] → Mitigation: default already includes `src/app/`; a bare name becomes `<root>/foo.ts`. Document in prompt only via the default text.
- [Create outside the tree root via `../` or absolute] → Mitigation: allowed; not a sandbox. Refresh/find_file no-ops if the path is outside `root_path`.
- [Broken `~`] → Mitigation: `vim.fn.expand` on the input before normalize if it starts with `~`.

## Migration Plan

No config migration. `a` still adds; only the prompt/default/path rules change. Revert `_add_file` + `bsi.fs.create` to roll back.
