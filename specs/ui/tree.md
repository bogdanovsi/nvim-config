# BSI Tree

Modern, embedded **filesystem-only** file tree for the BSI Neovim UI layer.

**Location:** `lua/bsi/ui/tree.lua`  
**Entry point:** `require("bsi.ui.tree")`  
**Setup:** Called automatically from `lua/bsi/init.lua`

---

## Overview

The BSI Tree provides a lightweight, fast file tree that can be opened as a sidebar. It is **not** a replacement for `nvim-tree` (which is also installed); it is a purpose-built component for quick navigation.

**No git status tracking.** Porcelain status, numstat `+N-M` deltas, gitignore snapshots, Project watchers, and git-only mode were removed. They caused lag on repos with large change sets (expensive `git status --porcelain -z --ignored=matching -u`, untracked-dir expansion, and full-tree re-scan/re-render when data arrived).

Key characteristics:
- Clean three-class architecture (Renderer / Provider / Tree)
- Synchronous bounded FS scan for instant open
- Lazy expansion of directories on demand
- Automatic current-file tracking across open tree instances
- Name-based ignore list only (no git processes)

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
```

No `git_status`, `git_numstat`, `git_status_summary`, or `git_ignored` fields.

---

## Core Features

### 1. Filesystem Scanning
- `vim.loop.fs_scandir` + `fs_lstat`
- Bounded initial depth (root direct children only); deeper dirs are stubs until expanded
- Name-based ignore (when `show_ignored=false`): `node_modules`, `vendor`, `dist`, `build`, `target`, and `.git`
- **Dotfiles** always included (except `.git` when hidden)
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

Git-related highlight groups (`BSITreeGitAdded` etc.) are no longer defined by the tree.

---

## Why git tracking was removed

With large dirty working trees the old path did roughly:

1. Quick FS scan (fast)
2. Async: `git status --porcelain=v1 -z --ignored=matching -u` (can be huge)
3. Async: untracked-directory full expansion
4. Async: `git diff --numstat` × 2 (staged + unstaged)
5. Re-scan / decorate entire tree + re-render when all three finished

Steps 2–5 blocked interactivity and re-rendered thrashing on big change sets. Gitsigns / Diffview / Telescope remain available for git work; the tree stays a pure navigator.

---

*Updated 2026-08: git status tracking fully removed from bsi.ui.tree.*
