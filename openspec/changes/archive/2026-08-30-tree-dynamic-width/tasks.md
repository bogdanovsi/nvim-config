## 1. Width helpers and config

- [x] 1.1 Add `M.config.width_min` / `width_max` (defaults 30 / 60) and helpers `needed_width(lines)` (`strdisplaywidth`) and `clamped_width(needed, min, max)` (swap inverted min/max) — verify: unit tests for short→min, 45→45, 90→60, min>max
- [x] 1.2 After `Renderer:build` in `Tree:render`, if auto-fit is on, set the tree window to `clamped_width` and skip when unchanged — verify: a tree with a 45-col visible line ends at width 45; all-short names end at 30

## 2. Manual expand

- [x] 2.1 Map `>` to expand the window to the longest visible line even if above `width_max`, and set a manual-width flag so later renders do not clamp — verify: 90-col line + `>` → width ≥ 90
- [x] 2.2 Map `<` to clear the flag and re-apply clamp — verify: after `>` then `<`, width is 60 when content is 90
- [x] 2.3 New `Tree.new` / `open` starts in auto-fit (no leftover 40) — verify: open no longer forces 40 when content is 30 or 50

## 3. Integration

- [x] 3.1 Document `width_min` / `width_max` and `>` / `<` in informal `specs/ui/tree.md` — verify: those strings appear
- [x] 3.2 Run `make test` — verify: exit code 0
