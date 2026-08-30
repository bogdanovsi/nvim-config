## Why

Gitignore greying and file `+N-M` were removed with porcelain status because a whole-working-tree `git status --ignored=matching` plus a full re-scan stalled large repos. The tree now only skips a hard-coded name list, so real `.gitignore` matches look like normal files and there is no `+23-23` on dirty files. The bounded filesystem scan already lists the entries we show — including `.gitignore` files — so ignore status can be derived from that scan, and numstat can return the old way without listing the filesystem again.

## What Changes

- After each filesystem scan, build gitignore status from `.gitignore` files found among the scanned entries and apply it to those paths (and to unpopulated child stubs when a parent pattern applies).
- Visible gitignored files and directories SHALL render grey, using the previous `BSITreeGitIgnored` treatment (arrow, icon, and name).
- Restore file change counts as before: ` +23-23`, ` +23`, or ` -23` after the name, green for additions and red for deletions, from staged + unstaged `git diff --numstat`. Gitignored rows do not show numstat.
- Name-based skip of `node_modules`, `vendor`, `dist`, `build`, `target`, and `.git` stays the first gate. `h` still toggles those heavy names. Gitignored scanned files are shown grey rather than omitted.
- Keep the one-level 5000-entry scan at or under 200 ms **including** gitignore annotation. Numstat is async and MUST NOT re-scan the filesystem when it arrives (attach to existing nodes, then re-render).
- The scanner stays a filesystem module: listing, name-based skip, sort, and collapse stay in `Provider:scan`. Gitignore matching is a cheap pass over the scan result. Numstat is a separate git call after the tree is already on screen.
- Do **not** restore porcelain XY decorations, directory AMD summaries, git-only mode, or Project watchers.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `ui/tree`: Scanned nodes carry gitignore status from scanned `.gitignore` files; gitignored files and dirs render grey; dirty files show `+N-M` as before; the 200 ms one-level scan budget still holds for scan plus gitignore annotation.

## Impact

- `lua/bsi/fs/provider.lua` — unchanged hot path (no git, no porcelain); 200 ms tests still time listing.
- New gitignore helper under `lua/bsi/git/` — parse `.gitignore` from the scan and mark matching nodes. Existing `lua/bsi/git/status.lua` porcelain runner is not wired back into the tree.
- Numstat helper (new or small git module) — async `git diff --numstat` and `git diff --cached --numstat`, merge per path, stamp `git_numstat` on file nodes.
- `lua/bsi/ui/tree.lua` — annotate after scan; grey `BSITreeGitIgnored`; restore `BSITreeGitAdded` / `BSITreeGitDeleted` for `+N-M`; restore those highlight groups.
- Tests: gitignore matching (nested, negation, stubs); renderer/node decoration for grey and `+N-M`; performance tests still 200 ms on 5000-entry fixtures **including** gitignore annotation (not including numstat network/git time).
- Informal `specs/ui/tree.md` currently says git decorations are gone; update it when this lands.
