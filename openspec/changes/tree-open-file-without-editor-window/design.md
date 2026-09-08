## Context

See proposal.md for motivation. Today `Tree:_open_file` and the file-create follow-up in `Tree:_add_file` both do `wincmd l` then `:edit`. The tree window sets `winfixbuf`. `:bdelete` of the buffer shown on the right closes that window, so the next open runs `:edit` in the tree and Neovim raises E1513.

## Goals / Non-Goals

**Goals:**
- One window-pick helper used by Enter-open and by file-create follow-up.
- Prefer an existing normal editor window; split only when none exists.
- Keep `winfixbuf` on the tree.

**Non-Goals:**
- Changing delete/prune besides relying on robust open.
- Changing picker (Telescope) window selection.
- Opening files into named TUI floats or other terminals.
- Changing tree keymaps.

## Decisions

### Decision 1: Fix open, not delete

Do not keep a placeholder `[No Name]` when wiping the displayed file. Delete closing the last editor window is normal Neovim. Any other way of dropping that window (`:q`, `:bd`) hits the same gap. Open must create a split when it needs one.

Alternative: `enew` in the file window before `nvim_buf_delete`. Rejected — only covers this delete sequence.

### Decision 2: Suitable window = non-float, not tree, not `winfixbuf`, not terminal

Walk tabpage windows. Skip:
- the tree window (`filetype == "Tree"` or `winid == self.winid`)
- `winfixbuf`
- floating windows (`nvim_win_get_config(win).relative ~= ""`)
- `buftype == "terminal"`

If several remain, prefer the most recently used (`vim.fn.win_findbuf` / last accessed among remaining). If none, `vsplit` from the tree (file appears to the right of the sidebar) then `:edit`.

Alternative: keep `wincmd l` and `vsplit` only when it does not move. Rejected — `wincmd l` can land in a float sitting to the right of the tree.

### Decision 3: Shared helper, not two copies

`Tree:_edit_in_editor(path)` (or a local function in `tree.lua`) picks the window and edits. `_open_file` and `_add_file` call it. Stay in `tree.lua`; this is window policy for the tree, not a filesystem module.

Alternative: extract `bsi.ui.windows`. Rejected — one call site family, no other consumer yet.

### Decision 4: Tests drive real windows

Headless Neovim can `vsplit`, attach a tree, `nvim_buf_delete` the file window’s buffer, then `_open_file`. Assert: no error, tree buf still in tree win, file buf in a different win. Cover: tree-only tab, and tree plus a float.

`vim.fn.confirm` in delete is awkward to stub; tests may close the editor window / wipe the buffer directly to reach the same layout. One test should go through `_delete_node` if confirm can be stubbed with `vim.fn.confirm = function() return 1 end`.

## Risks / Trade-offs

- [Split from a full-width tree makes a 50/50 layout] → Acceptable; same as opening the tree then immediately needing an editor. Tree still has `winfixwidth` and auto-fit on the next render.
- [Help / quickfix / prompt windows match “suitable”] → Skip `buftype ~= ""` as well as terminal, so only empty/`""` buftype windows are reused. If every remaining window is special, split a new one.
- [Tests need a UI window in headless] → Use `nvim_open_win` or `vsplit` as `tree_width_spec.lua` already does.

## Migration Plan

No config or keymap change. Revert the helper and the two call sites to roll back.

## Open Questions

None.
