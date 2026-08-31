## 1. Plugin and hidden buffers

- [x] 1.1 Add `akinsho/toggleterm.nvim` to `lua/core/pack.lua` and set `vim.o.hidden = true` in `lua/core/set.lua` — verify: pack spec present; `hidden` is true in `set.lua`
- [x] 1.2 Add `lua/plugin/toggleterm.lua` that `setup`s toggleterm (`open_mapping = false`, float 90%, rounded, `start_in_insert`, `close_on_exit = false`) and require it from pack setup — verify: file is required from `lua/core/pack.lua` and those options appear in setup

## 2. Named session manager

- [x] 2.1 Add `lua/bsi/tui.lua` with injectable Terminal factory, `define`, `hide_others`, `toggle`, catalog names `lazygit`/`k9s`/`grok`/`lazydocker`/`shell`, last-tool tracking, and default last=`shell` — verify: unit tests with fake Terminals
- [x] 2.2 Test hide ≠ kill: open A, open B → A's `close` called, A not reconstructed, B `toggle`d — verify: `lua/bsi/tui_spec.lua`
- [x] 2.3 Test same-session reopen and self-toggle hide — verify: second open of A calls `toggle` on the same object; toggling visible A only `close`s
- [x] 2.4 Test last-tool and picker choice invoke `toggle(name)` — verify: last starts nil → shell; after k9s, last is k9s; picker callback toggles the chosen name
- [x] 2.5 Define real Terminals with `hidden = true`, no Esc/`q` hide maps, `<C-\>` hide on open, `close_on_exit = true` only for lazygit — verify: those fields in `define` defaults / catalog extras

## 3. Keys, commands, and cleanup

- [x] 3.1 Rewire `<leader>gg`, `<leader>lg`, `<leader>dd`, `:LazyGit`, `:LG`, `:K9S`, `:LazyDocker` to `bsi.tui.toggle`; add `<leader>tk`, `<leader>xg`, `<leader>T`, `<C-\>` — verify: those maps/commands call tui, not `open_term_float`; `<leader>tt` / `<leader>tx` still neotest in `lua/core/keymap.lua`
- [x] 3.2 Remove lazygit/k9s/lazydocker wrappers from `lua/bsi/tail-file.lua`; keep `:LspLog` / `open_term_float` one-shot (wipe + jobstop) — verify: no named-tool cmds in tail-file; LspLog still uses `open_term_float`
- [x] 3.3 Remove `kdheepak/lazygit.nvim` from pack; drop `lazygit` from FileType `close_with_q` Esc/`q` in `lua/bsi/init.lua` — verify: pack has no lazygit.nvim; lazygit not in that filetype list
- [x] 3.4 Run `make test` — verify: exit code 0
