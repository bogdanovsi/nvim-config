## Why

Directory scanning is embedded in `lua/bsi/ui/tree.lua` next to windows, keymaps, and icons. That makes the hot path untestable without a UI, and it lets expand/refresh recurse entire trees. The scan should be a filesystem module: list files, bound depth, skip heavy names — then the tree UI can consume it. Tests (unit + performance) belong on that module, not on the sidebar.

## What Changes

- Extract `Provider` (scan, ignore, sort, single-child collapse) from `lua/bsi/ui/tree.lua` into a dedicated filesystem module, e.g. `lua/bsi/fs/provider.lua` (`require("bsi.fs.provider")`).
- Specialize that module for files only: `vim.uv`/`vim.loop` scandir + lstat, name-based ignore, bounded depth, `bsi.Node` file/dir trees. No buffers, windows, highlights, keymaps, or `nvim-web-devicons`.
- Tree UI requires the module and attaches presentation (icons, render) after scan. Public tree API and keymaps stay the same.
- Default non-expand-all scan is one level (child dirs are stubs) so expand/refresh cannot walk a whole repo by omitting `max_depth`.
- Add **unit tests** for skip/ignore, stubs vs expand-all, sort, collapse, missing paths, and node shape (no UI fields).
- Add **performance tests** on generated temp fixtures (5000-entry dirs and ignored `node_modules` trees) with a 200 ms budget.
- Fixtures are created at runtime and deleted; nothing large is committed.

## Capabilities

### New Capabilities

- `ui/tree`: Filesystem directory provider used by the BSI tree — bounded, ignore-aware scan of real directories, independent of the tree UI, with unit and performance coverage so large folders stay interactive.

### Modified Capabilities

- (none — `openspec/specs/` has no existing capabilities)

## Impact

- New `lua/bsi/fs/provider.lua` — scan implementation.
- New `lua/bsi/fs/provider_spec.lua` — unit + performance tests (picked up by existing `make test` / PlenaryBusted on `lua/bsi/`).
- `lua/bsi/ui/tree.lua` — delete inlined Provider; `require("bsi.fs.provider")`; apply icons in the UI layer.
- Informal `specs/ui/tree.md` remains the product overview; this change does not rewrite it. No keymap or `:BSITree` changes.
