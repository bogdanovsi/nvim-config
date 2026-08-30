## 1. Letter mapping

- [x] 1.1 Add a helper that maps porcelain XY to a single `A`/`M`/`D` (untracked/added → A, M/R/C → M, D → D; D then M then A if several apply) — verify: unit tests for `??`, `M `, ` D`, `AD`, `R `
- [x] 1.2 Fetch `git status --porcelain=v1 -z` asynchronously **without** `--ignored=matching` and parse with the existing porcelain parser — verify: the command argv does not include `--ignored=matching`; a stubbed map stamps files

## 2. File postfix and directory DMA

- [x] 2.1 Stamp `git_letter` (or equivalent) on non-gitignored file nodes from the porcelain map; skip gitignored files — verify: modified file gets `M`; gitignored file stays unset
- [x] 2.2 Bottom-up, set directory `git_status_summary` via `compute_dir_git_status`, including porcelain deleted paths under the dir that are not tree children — verify: mixed children yield `DMA`; a deleted-only missing file still sets parent `D`
- [x] 2.3 Nested roll-up: a modified file under `src/app` marks both `src/app` and `src` with `M` — verify: both summaries contain `M`
- [x] 2.4 Render file postfix after `+N-M` when both exist; restore `BSITreeGitModified`; color A/M/D — verify: a modified file with added 23 and deleted 23 renders ` +23-23` then `M`
- [x] 2.5 Render directory DMA after the name with per-letter highlights; gitignored dirs have no summary — verify: `DMA` uses deleted/modified/added groups; ignored dir line has no `D`/`M`/`A` postfix

## 3. Async attach

- [x] 3.1 After open/refresh, fetch porcelain without calling `Provider:scan` again; generation counter drops stale callbacks — verify: scan count unchanged on stamp; old callback does not overwrite newer letters
- [x] 3.2 Non-repo or git failure leaves no AMD and does not fail the listing — verify: temp dir without `.git` has no postfix/summary and scan succeeds

## 4. Integration

- [x] 4.1 Update informal `specs/ui/tree.md` to mention file A/M/D postfix and directory DMA — verify: those strings appear in the overview
- [x] 4.2 Run `make test` — verify: exit code 0
