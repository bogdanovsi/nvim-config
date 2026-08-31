## Context

See proposal.md for motivation. This config is custom `vim.pack`, not LazyVim/lazy.nvim and not Snacks.

Today `lua/bsi/tail-file.lua` `open_term_float` creates a scratch buffer (`bufhidden = wipe`), maps `q`/`Esc` to `:close`, and `jobstop`s on `BufWipeout`/`WinClosed`. `:K9S`, `:LG`, `:LazyDocker` use that path. Lazygit is additionally provided by `kdheepak/lazygit.nvim` via `:LazyGit` (`<leader>gg`, `<leader>lg`). `<leader>t*` is owned by neotest (`<leader>tt` run file, `<leader>tx` stop).

## Goals / Non-Goals

**Goals:**
- One exclusive float slot implemented as hide-window, keep-job.
- Named `Terminal:new` tools, not the generic `:ToggleTerm` pool.
- Fit `vim.pack` + `lua/plugin/*.lua` + existing TUI keys/commands.
- Unit-test the exclusive-slot / last-tool / catalog logic without launching real TUIs.

**Non-Goals:**
- Replacing one-shot `open_term_float` (LSP log, ad-hoc commands).
- Snacks terminal, floaterm, multiterm, or a sidebar terminal list.
- Mapping Esc to hide.
- Changing Claude Code, harpoon term, or tmux navigator.
- Steal neotest `<leader>tt` / `<leader>tx`.

## Decisions

### Decision 1: `toggleterm.nvim` via `vim.pack`, not Snacks or in-house persist

Use `akinsho/toggleterm.nvim`. Named `Terminal:new({ hidden = true })` plus `t:close()` hides the window and leaves the job. That matches hide ≠ kill without rewriting PTY/float lifecycle.

Alternatives considered:
- Persist inside `open_term_float` (keep buf, hide win, no jobstop). Possible, but we would reimplement session catalog, float opts, and last-tool ourselves. Rejected for this change.
- Snacks.terminal. This repo does not depend on Snacks. Rejected.
- `kdheepak/lazygit.nvim` only. It is lazygit-only and still a new window/job model. Removed once the named session exists.

Pack: `gh("akinsho/toggleterm.nvim")` in `lua/core/pack.lua`. Setup in `lua/plugin/toggleterm.lua`, required from pack setup like other plugins. Named-tool table lives in `lua/bsi/tui.lua` so tests can require it without packing UI.

`open_mapping = false`; we own keys. `direction = "float"`, `start_in_insert = true`, `persist_size` / `persist_mode` true, global `close_on_exit = false`. Float ~90% editor, rounded border.

### Decision 2: `vim.o.hidden = true` in `lua/core/set.lua`

Required so hidden terminal buffers are not unloaded. Set explicitly even if a given Neovim version already defaults it on.

### Decision 3: Exclusive slot is `hide_others` then `toggle`

```lua
local tools = {} -- name -> Terminal
local last

local function hide_others(except)
  for name, t in pairs(tools) do
    if name ~= except and t:is_open() then
      t:close() -- window only
    end
  end
end

local function toggle(name)
  local t = tools[name]
  if not t then return end
  if t:is_open() then
    t:close()
    return
  end
  hide_others(name)
  last = name
  t:toggle()
end
```

`hidden = true` on each Terminal so they are not in the generic ToggleTerm pool. `on_open` maps `<C-\>` buffer-local to hide that term; does **not** map Esc or `q`.

### Decision 4: Catalog and close-on-exit

| Name | cmd | close_on_exit |
|---|---|---|
| lazygit | `lazygit` | true |
| k9s | `k9s` | false |
| grok | `grok` | false |
| lazydocker | `lazydocker` | false |
| shell | `vim.o.shell` | false |

Lazygit is a session you quit; the others are long-running or worth reading after crash. Missing binary: toggleterm's usual fail path plus `vim.notify`; no extra launcher.

`:LspLog` stays on `open_term_float`.

### Decision 5: Keys that match this config

User sketch used `<leader>tt` / `<leader>tg` / `<leader>tx`. Here `<leader>tt` and `<leader>tx` are neotest. Keep existing TUI keys; add only free ones.

| Action | Keys / commands |
|---|---|
| lazygit | `<leader>gg`, `<leader>lg`, `:LazyGit`, `:LG` |
| lazydocker | `<leader>dd`, `:LazyDocker` |
| k9s | `<leader>tk`, `:K9S` |
| grok | `<leader>xg` |
| picker | `<leader>T` (`vim.ui.select` over `vim.tbl_keys(tools)`) |
| last tool | `<C-\>` in n/t; if `last` is nil, toggle `shell` |

Rewire `:LazyGit` by defining it ourselves after dropping `kdheepak/lazygit.nvim`. If the plugin command must exist during transition, map it to `toggle("lazygit")` before removing the pack entry.

Do not add `close_with_q` Esc/`q` maps for these terminal buffers. The existing FileType `lazygit` `q`/`Esc` close in `lua/bsi/init.lua` applies to the old plugin buffer; remove that filetype from the list if it would steal keys from the new session.

### Decision 6: Tests stub Terminal, do not spawn k9s

Export `bsi.tui` helpers (`define`/`toggle`/`hide_others`/`last`/`tools`) that accept a Terminal-like object `{ is_open, close, toggle }`. Specs:

- hide A then open B → A's `close` called, job flag stays running
- reopen A → same object `toggle`, not a new define
- visible A toggled again → `close` only
- last-tool tracks last shown name; default `shell`
- picker choice calls `toggle(name)`

Headless Neovim cannot usefully drive lazygit. Do not require the real binary in `make test`.

### Decision 7: Leave `open_term_float` kill-on-close for one-shots

One-shot helpers still wipe + jobstop. Only named catalog entries persist. Avoid mixing the two in one buffer.

## Risks / Trade-offs

- [Hidden jobs keep using CPU/cluster context (k9s, grok)] → Mitigation: exclusive slot only hides; user can quit inside the TUI. Out of scope: idle timeout.
- [TUI eats `<C-\>`] → Mitigation: also hide with the same leader key; document that Esc is for the TUI.
- [Dropping lazygit.nvim changes `:LazyGit` options (floating vs tab)] → Mitigation: named session is always the 90% float; no tab fallback.
- [toggleterm + `hidden=true` still lists some terms in `:TermSelect`] → Mitigation: `hidden = true` on `Terminal:new`; we do not use the generic pool. Picker is `vim.ui.select` over our table.
- [Tests that `require("toggleterm")` fail in `--noplugins` busted] → Mitigation: inject a fake Terminal in unit tests; plugin file is thin setup.

## Migration Plan

1. Add pack + `hidden` + `bsi.tui` + plugin setup.
2. Point existing commands/keys at `toggle(name)`.
3. Remove lazygit/k9s/lazydocker from `open_term_float` wrappers.
4. Remove `kdheepak/lazygit.nvim` from `vim.pack.add`.
5. Drop `lazygit` from the FileType `close_with_q` Esc/`q` list if it still matches.

Rollback: revert those files; pack lock will drop toggleterm and restore lazygit.nvim.

## Open Questions

None that change specs or tasks. Grok binary name is `grok`. Picker UI is `vim.ui.select`, not `:TermSelect`.
