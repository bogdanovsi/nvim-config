## Why

Named TUI tools (lazygit, k9s, grok, lazydocker) currently open a new float each time and **kill the job when the window closes**. Switching tools discards session state. The wanted model is one floating slot, many named sessions, and hide ≠ kill: the process stays in a hidden terminal buffer; only the window is closed.

## What Changes

- Add a named-TUI float manager: one visible float at a time; other named sessions hide without stopping their jobs.
- Reopening a named tool restores the same terminal buffer and TUI state.
- Keep `vim.o.hidden` on so hidden terminal buffers are not discarded.
- Wire existing TUI entry points (`<leader>gg` / `<leader>lg` lazygit, `<leader>dd` lazydocker, `:K9S`, `:LG`, `:LazyDocker`) through this manager instead of `open_term_float` / `kdheepak/lazygit.nvim`.
- Add k9s, grok, a last-tool toggle (`<C-\>`), and a picker that lists named tools.
- Do not map Esc (or `q` in terminal mode) to hide TUIs that consume those keys.
- **BREAKING** (local UX): hiding a TUI no longer stops its process. Closing the float with Esc/`q` on those tools is removed; hide via the tool keymap or `<C-\>`.
- Drop `kdheepak/lazygit.nvim` once lazygit is a named session (existing `:LazyGit` / `<leader>gg` / `<leader>lg` keep working via the manager).
- Leave one-shot floats (e.g. LSP log tail) on `open_term_float`; they are not named sessions.

## Capabilities

### New Capabilities

- `ui/tui-float`: One floating window slot for many named TUI sessions. Hide closes the window only; the job keeps running. Reopen restores the same session. Only one named float is visible at a time.

### Modified Capabilities

- (none)

## Impact

- `lua/core/pack.lua` — add `akinsho/toggleterm.nvim`; remove `kdheepak/lazygit.nvim`.
- `lua/core/set.lua` — set `vim.o.hidden = true`.
- New plugin/module wiring (toggleterm setup + named tool table, keys, picker).
- `lua/bsi/tail-file.lua` — stop using `open_term_float` for lazygit / k9s / lazydocker; keep it for LspLog and generic one-shot commands.
- Keymaps in `lua/bsi/remap.lua`, `lua/core/keymap.lua`, `init.lua` — rewire lazygit/lazydocker; add k9s, grok, picker, last-tool toggle.
- User commands `:K9S`, `:LG`, `:LazyDocker`, `:LazyGit` — same names, new backend.
- Tests for hide-not-kill, exclusive float, and session reuse (headless where possible).
