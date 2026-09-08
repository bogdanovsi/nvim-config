## 1. Window helper

- [x] 1.1 Add `Tree:_edit_in_editor(path)` in `lua/bsi/ui/tree.lua` that picks a suitable window in the current tab (not the tree, not `winfixbuf`, not a float, `buftype == ""`) or `vsplit`s if none exist, then `:edit`s the path — verify: `_open_file` and `_add_file` no longer call `wincmd l` directly
- [x] 1.2 Prefer the most recently used suitable window when more than one exists — verify: with two file splits, opening from the tree edits in the last-used file window, not the tree

## 2. Tests

- [x] 2.1 Add `lua/bsi/ui/tree_open_file_spec.lua` that opens a tree on a real window with temp files — verify: `after_each` deletes the temp dir and closes extra windows
- [x] 2.2 Test Enter-open when the tree is the only window: `_open_file` opens the file in a new window and the tree buffer stays in the tree window — verify: no E1513; file buf is not the tree buf
- [x] 2.3 Test Enter-open after deleting the displayed file (`vim.fn.confirm` stubbed to Yes, or wipe the editor buffer then `_open_file`) — verify: the other file opens in an editor window; tree still shows the tree
- [x] 2.4 Test Enter-open when the only other window is a floating terminal — verify: the float’s buffer is unchanged and the file opens in a new split
- [x] 2.5 Test file-create follow-up when the tree is the only window (call `_edit_in_editor` / the create-open path with a new file) — verify: new file opens in an editor window; tree still shows the tree

## 3. Wire-up

- [x] 3.1 Point `_open_file` at `_edit_in_editor` — verify: Enter and double-click still open files; `make test` covers 2.2–2.4
- [x] 3.2 Point `_add_file`’s file-open follow-up at `_edit_in_editor` instead of `wincmd l` + `edit` — verify: no remaining `wincmd l` + `edit` in `tree.lua` for file open; `make test` exit 0
