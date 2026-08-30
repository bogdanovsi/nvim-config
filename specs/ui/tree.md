# BSI Tree

Modern, embedded **filesystem-only** file tree for the BSI Neovim UI layer.

**Location:** `lua/bsi/ui/tree.lua`  
**Entry point:** `require("bsi.ui.tree")`  
**Setup:** Called automatically from `lua/bsi/init.lua`

---

## Overview

The BSI Tree provides a lightweight, fast file tree that can be opened as a sidebar. It is **not** a replacement for `nvim-tree` (which is also installed); it is a purpose-built component for quick navigation.

Gitignore greying, file `+N-M`, and A/M/D letters come back **without** `--ignored=matching`. `.gitignore` files found in the filesystem scan mark matching nodes (`git_ignored`); those rows render grey (`BSITreeGitIgnored`). Staged + unstaged `git diff --numstat` attach asynchronously as ` +23-23` / ` +N` / ` -M`. Light `git status --porcelain=v1 -z` (no ignored matching) stamps a file A/M/D postfix and aggregates **DMA** after directory names. No `--ignored=matching`, no untracked-dir expansion, no Project watchers, no git-only mode, and git data does not re-scan the filesystem.

Key characteristics:
- Clean three-class architecture (Renderer / Provider / Tree)
- Synchronous bounded FS scan for instant open
- Gitignore annotation from scanned `.gitignore` files (no git subprocess)
- Async `+N-M` on dirty files after the listing is already shown
- File A/M/D postfix and directory DMA summary (async, after the listing)
- Lazy expansion of directories on demand
- Automatic current-file tracking across open tree instances
- Name-based skip of `node_modules` / `vendor` / … (`h` toggle); gitignored files stay listed and grey

---

## Architecture

| Component    | Responsibility |
|--------------|----------------|
| `Renderer`   | Pure rendering: visible nodes → buffer lines + highlights |
| `Provider`   | Filesystem scanning (`scan`) with name-based ignore |
| `Tree`       | Orchestrator: state, expansion, refresh, keymaps, instance API |
| `M` (module) | Factory + registry (`M.instances`) + setup + `toggle_tree` |

The tree never writes to the filesystem except through explicit user actions (`a`, `d`, rename). All scanning is read-only.

---

## Data Model

### `bsi.Node`

```lua
---@class bsi.Node
---@field id string
---@field name string
---@field path string
---@field type "file"|"directory"|"root"
---@field depth integer
---@field expanded boolean
---@field children bsi.Node[]|nil
---@field _unpopulated boolean|nil  -- stub dir, populated on expand
---@field _icon string|nil
---@field _icon_hl string|nil
---@field git_ignored boolean|nil
---@field git_numstat { added: integer, deleted: integer }|nil
```

No porcelain `git_status` or directory `git_status_summary`. `git_ignored` comes from scanned `.gitignore` files. `git_numstat` is async file `+N-M`.

---

## Core Features

### 1. Filesystem Scanning
- `vim.loop.fs_scandir` + `fs_lstat`
- Bounded initial depth (root direct children only); deeper dirs are stubs until expanded
- Name-based ignore (when `show_ignored=false`): `node_modules`, `vendor`, `dist`, `build`, `target`, and `.git`
- **Dotfiles** always included (except `.git` when hidden)
- Gitignored scanned files stay listed and render grey
- Single-child directory collapsing (`foo/bar/baz`)

### 2. Expansion & Visibility
- Root starts expanded; children lazy-loaded on toggle / find_file
- `get_visible_nodes()` DFS walk with cache (`_visible_dirty`)

### 3. Current File Tracking
- `BufEnter` on real file buffers updates `M.opened_buffer` and calls `find_file` on live trees
- Current file row gets `BSITreeCurrentFile` highlight

### 3b. Window is not an edit target
- Tree buffer: `buftype=nofile`, `bufhidden=wipe`, unlisted scratch
- Tree window: `winfixbuf=true` so plugins cannot replace the buffer in-place
- Telescope uses `get_selection_window` to skip `filetype=Tree` (and other sidebars); opening a file from a picker while focused on the tree must land in a normal editor window

### 4. Auto-Refresh Triggers
- `BufAdd` / `BufDelete` / `BufWipeout` → re-render live trees
- Manual `R` → full FS re-scan preserving expansion

### 5. Actions
- `<CR>`: toggle dir / open file
- `o`: system open
- `a` / `r` / `u` / `d`: add / rename-move / delete
- `D`: `DiffviewOpen -- <file>`
- `y` / `Y`: yank name or relative path
- `h`: toggle name-based ignored dirs
- `R` / `q`: refresh / close

---

## Public API

```lua
local tree = require("bsi.ui.tree")

local t = tree.new({ root = "/path" })
t:open()
t:refresh()
t:find_file("/absolute/path/to/file.lua")

tree.toggle_tree()          -- <leader>ee
tree.show_in_git_mode()    -- <leader>ge (compat stub: opens normal tree; no git mode)
tree.instances
```

### Options for `Tree.new(opts)`

| Option         | Type    | Default            | Description |
|----------------|---------|--------------------|-------------|
| `root`         | string  | `vim.fn.getcwd()`  | Root directory |
| `expand_all`   | boolean | false              | Force every directory open |
| `show_ignored` | boolean | `M.config.show_ignored` (false) | Show node_modules/vendor/.git etc. |
| `bufnr`/`winid`| number  | (created)          | Reuse buffer/window |

**Removed options:** `git_only` (ignored if passed).

---

## Keybindings

| Key | Action |
|-----|--------|
| `R` | Refresh |
| `h` | Toggle ignored dirs (name-based) |
| `q` | Close |
| `<CR>` | Toggle dir / open file |
| `o` | System open |
| `d` / `D` | Delete / Diffview |
| `a` / `r` / `u` | Add / Rename-Move |
| `y` / `Y` | Yank name / relative path |

Global:
- `<leader>ee` → `toggle_tree()`
- `<leader>ge` → open/focus tree (legacy; no git-changes view)
- `:BSITree [dir]` → open tree at dir or cwd

---

## Highlights

- `BSITreeCurrentFile` — current editing file row
- `BSITreeCursorLine` — native cursorline in tree window
- `BSITreeOpenedFile` — defined, unused
- `BSITreeTitle` — winbar
- `BSITreeGitIgnored` — grey gitignored file/dir row
- `BSITreeGitAdded` / `BSITreeGitModified` / `BSITreeGitDeleted` — `+N` / A/M/D postfix / `-M` and directory DMA

---

## Git decorations (current)

1. Quick FS scan (fast, name-based skip)
2. Annotate from `.gitignore` files in the scan result (no `git status`)
3. Async: `git diff --numstat` + `git diff --cached --numstat`
4. Async: light `git status --porcelain=v1 -z` (no `--ignored=matching`) → file A/M/D postfix and directory DMA
5. Stamp existing nodes and re-render (no filesystem re-scan)

`--ignored=matching`, untracked expansion, and Project watchers stay gone.

---

*Updated 2026-08: scan-based gitignore greying, async file `+N-M`, file A/M/D postfix, directory DMA.*
