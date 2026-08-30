## Context

See proposal.md. `Tree:open` sets `nvim_win_set_width(self.winid, 40)` once. Visible rows already go through `Renderer:build` → `lines`. Indent is `depth - 1` spaces plus arrow, icon, name, and optional git `+N-M` / AMD.

## Goals / Non-Goals

**Goals:**
- Auto window width from the longest **visible** line, clamped to config min/max (30–100).
- Recalc on render while auto-fit is on.
- Keymaps to expand past max and restore auto-fit.

**Non-Goals:**
- Wrapping tree lines (`wrap` stays off).
- Sizing from the full unexpanded tree.
- Persisting manual width across Neovim restarts.
- Changing sidebar side or split command.

## Decisions

### Decision 1: Config `width_min` / `width_max`

```lua
M.config = {
  show_ignored = false,
  width_min = 30,
  width_max = 100,
}
```

Override via existing `M.setup(opts)`. If `width_min > width_max`, use `width_max` for both.

Needed width = `max(strdisplaywidth(line))` over `Renderer:build` lines, plus 1 for the end-of-line cursor column. Clamp: `math.min(max, math.max(min, needed))`.

### Decision 2: Apply after every auto-fit render

`Tree:render` already builds lines. After setting buffer lines, if `self._width_manual` is false, `nvim_win_set_width` to the clamped value. Open, expand, collapse, and refresh all render, so they pick up new depths/names.

Do not animate; one set_width per render. Skip if the window is invalid or width already matches.

### Decision 3: Manual expand with `>` and restore with `<`

- `>` : `self._width_manual = true`, set width to `max(needed, width_max)` (fit the longest visible line, even if > 60).
- `<` : `self._width_manual = false`, apply clamp again.

While `_width_manual`, render does not shrink/grow automatically. Close/reopen resets to auto-fit.

Mouse-drag resize is native Vim; next auto-fit render will overwrite it unless `_width_manual` is set. Acceptable.

Alternative: `nowrap` + horizontal scroll only. Rejected — user asked to expand the buffer.

### Decision 4: Tests without a UI layout

Measure helper `needed_width(lines)` and `clamped_width(needed, min, max)` plus `_width_manual` behavior on a fake winid via stubbing `nvim_win_set_width` / `nvim_win_get_width` where a window exists, or unit-test the clamp/needed functions exported from the tree module.

## Risks / Trade-offs

- [Nerd icons are double-width] → Mitigation: `strdisplaywidth`, not `#line`.
- [Frequent expand/collapse flickers the editor] → Mitigation: skip set_width when unchanged.
- [Manual width lost on refresh] → Mitigation: keep `_width_manual` across refresh; only reset on new `Tree.new`/`open`.
- [Git postfix grows the line] → Mitigation: include it in the measured line (already in `build` output).

## Migration Plan

No migration. Old implicit 40 is replaced by auto 30–100. Rollback is revert of config + render width + two keymaps.

## Open Questions

None that change specs or tasks. Keymap `>` / `<` is recorded here; another pair can be swapped later without changing requirements.
