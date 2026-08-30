## Context

See proposal.md for motivation. Today `Provider` is a local class inside `lua/bsi/ui/tree.lua`. It mixes filesystem work (`fs_scandir` / `fs_lstat`, ignore, sort, collapse) with UI (`nvim-web-devicons` on file nodes). `Tree.new` bounds `max_depth` to 1; expand and `refresh` call `scan` with `max_depth = nil` and recurse the whole subtree. `make test` already PlenaryBusts `lua/bsi/`.

## Goals / Non-Goals

**Goals:**
- One filesystem module whose only job is building `bsi.Node` trees from directories.
- Tree UI depends on that module; icons and rendering stay in `tree.lua`.
- Unit tests for scan behavior; performance tests for large dirs.
- Default one-level scan unless `expand_all`.

**Non-Goals:**
- New tree keymaps, highlights, or git status.
- Changing the ignore name list.
- Extracting Renderer or Tree.
- Mocking the filesystem (tests use real temp dirs).

## Decisions

### Decision 1: Module path `lua/bsi/fs/provider.lua`

Public require: `require("bsi.fs.provider")`.

```lua
local Provider = require("bsi.fs.provider")
local root = Provider.new():scan(path, 0, opts)
```

Matches existing `bsi.git` / `bsi.utils` (domain packages, not UI). Alternatives: `bsi.ui.tree.provider` (still under UI) or `bsi.fs.scan` as a bare function (harder to hang helpers on). Rejected: exporting `M.Provider` from `tree.lua` (previous plan) — that does not separate files from UI.

API kept: `Provider.new()`, `scan(path, depth, opts)` with `{ expand_all, show_ignored, max_depth }`. `_should_skip` / `_should_ignore_name` stay internal.

### Decision 2: No UI in the filesystem module

The module does not `require` nvim-web-devicons, create namespaces, or touch buffers. File nodes omit `_icon` / `_icon_hl`. `Renderer:render` already falls back to devicons when those fields are missing; Tree may fill them after scan if it wants a cache. Collapse and sort stay in the FS module because they define the node tree shape the informal scan spec already describes.

### Decision 3: Default `max_depth` is one extra level

When `expand_all` is false and `max_depth` is nil, treat `max_depth` as current `depth` (populate this directory; child dirs are `_unpopulated` stubs). Explicit `max_depth` and `expand_all` unchanged.

`Tree:refresh` today sets `max_depth = nil` then `populate_expanded`. After the default, refresh is a one-level root scan plus one-level scans of expanded dirs — same UX, no full-tree walk.

### Decision 4: Tree becomes a consumer

`tree.lua` deletes the inlined Provider class and `require("bsi.fs.provider")`. `Tree.new` / expand / refresh keep calling `self.provider:scan(...)`. Icon assignment, if still desired as a cache, happens in Tree after scan, not inside scan.

### Decision 5: Tests live in `lua/bsi/fs/provider_spec.lua`

Not `tree_spec.lua`. Headless, no `Tree.new`.

**Unit (small fixtures):**
- missing path: no error, empty/no children
- ignore hidden: skip `node_modules`, `vendor`, `dist`, `build`, `target`, `.git`
- `.env` kept when `.git` hidden
- `show_ignored=true` includes `node_modules`
- one-level: nested files absent; child dirs `_unpopulated`
- `expand_all`: descendants present
- sort: dir before file; case-insensitive names
- collapse: `foo/bar/file` → collapsed directory name
- file node has no `_icon`

**Performance (generated, deleted in `after_each`):**
- 5000 top-level files, one-level scan ≤ 200 ms (`vim.uv.hrtime` around scan only)
- `node_modules` with ≥5000 files skipped and still ≤ 200 ms
- Create files with `vim.uv.fs_open` / `fs_close`

Shared fixture helper in the spec file; do not commit trees.

## Risks / Trade-offs

- [Tree regression if scan node shape drifts] → Mitigation: keep field names (`id`, `path`, `type`, `_unpopulated`, collapse naming) identical; Tree tests are not in scope unless a refresh bug shows up.
- [Icon-less nodes change look] → Mitigation: Renderer already has a devicons fallback; optionally stamp icons in Tree after scan.
- [10k-file fixture slows the suite] → Mitigation: libuv creates; time only `scan`; delete in `after_each`.
- [200 ms flakes] → Mitigation: measure scan only; do not raise the budget to hide recursion.

## Migration Plan

Move code, point Tree at the new module, add specs, run `make test`. Rollback is revert of the three files (`provider.lua`, `provider_spec.lua`, `tree.lua`). No user-facing config migration.
