## Why

The tree window is a fixed 40 columns. Short names waste editor space; deep indent plus long names are clipped. Width should follow the visible rows, stay in a configurable band by default, and let the user grow the window when a row would exceed the cap.

## What Changes

- Size the tree window from the longest **visible** row: indent + arrow + icon + name (and git postfix if present).
- Config: `width_min` and `width_max` (defaults **30** and **100** columns). Auto width is that content length, clamped to `[width_min, width_max]`.
- Recalculate after open, expand, collapse, and refresh.
- If content needs more than `width_max`, keep the window at `width_max` and offer a **manual expand** keymap so the user can grow the buffer to fit (and shrink back to auto).
- Replace the hard-coded `nvim_win_set_width(..., 40)` open path.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `ui/tree`: Tree window width is configurable, auto-fits visible indent+name within min/max, and can be expanded past max by the user.

## Impact

- `lua/bsi/ui/tree.lua` — `M.config` min/max; measure visible lines; set window width; keymap for manual expand/restore.
- Informal `specs/ui/tree.md` options table when this lands.
- Tests for clamp, auto grow/shrink inside the band, and stay-at-max until manual expand.
