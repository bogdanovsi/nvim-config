## Why

The tree shows `+N-M` on dirty files but no A/M/D letters. Directories no longer roll those letters up next to the name, so a collapsed folder does not tell you whether its subtree was added, modified, or deleted. The old postfix and directory `DMA` summary should come back without restoring porcelain `--ignored=matching` or a filesystem re-scan.

## What Changes

- Show a single **A**, **M**, or **D** postfix on non-gitignored files after the name (after `+N-M` when both exist). Untracked (`??`) maps to **A**; rename/copy map to **M**.
- Aggregate those letters onto directory (and root) names in canonical **DMA** order (D then M then A), each letter colored as before (A green, M orange, D red).
- Gitignored rows stay grey and get no AMD postfix or directory summary.
- Fetch status asynchronously; attach to existing nodes and re-render. Do **not** re-list directories. Do **not** restore `--ignored=matching`, untracked-dir expansion, git-only mode, or Project watchers.
- Keep existing `+N-M` numstat and scan-based gitignore greying. The 200 ms scan budget is unchanged (AMD is not on the scan path).

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `ui/tree`: Visible files can carry an A/M/D postfix; directories show an aggregated DMA summary after the name.

## Impact

- `lua/bsi/ui/tree.lua` — render file postfix and directory DMA; restore `BSITreeGitModified` for **M**.
- Git status helper (`lua/bsi/git/status.lua` `compute_dir_git_status`, plus a light porcelain fetch without `--ignored=matching`) — map XY to A/M/D, roll up from children (and deleted paths under a dir that are not in the listing).
- Tests for letter mapping, directory aggregation, gitignored omission, and no second `scan`.
- Informal `specs/ui/tree.md` should mention AMD postfix and directory DMA when this lands.
