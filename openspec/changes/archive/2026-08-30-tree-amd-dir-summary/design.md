## Context

See proposal.md. Files already get async `+N-M` from `bsi.git.numstat`; gitignored rows are grey from scan-based `.gitignore`. `bsi.git.status.compute_dir_git_status` still builds a canonical `DMA` summary from child XY / DIR_* strings. The old renderer put that summary after the directory name (A green, M orange, D red) and stripped a far-right letter from **files** in favor of `+N-M`. This change puts a single A/M/D back on files as a postfix and keeps DMA on directories.

Porcelain `--ignored=matching -u` stays out: that was the stall. Status for AMD is a cheaper `git status --porcelain=v1 -z` (no ignored matching).

## Goals / Non-Goals

**Goals:**
- Map porcelain XY to one of A, M, D on file nodes.
- Roll unique letters up to directory names in D-M-A order.
- Attach asynchronously without a second `Provider:scan`.

**Non-Goals:**
- `--ignored=matching`, untracked-directory expansion, git-only mode, Project watchers.
- Ghost rows for deleted files (they only feed parent DMA).
- Replacing `+N-M`.
- Changing the 200 ms scan budget.

## Decisions

### Decision 1: Light porcelain, not numstat-derived letters

`git status --porcelain=v1 -z` (no `--ignored=matching`, no `-u` extra untracked expansion beyond default). Parse with existing `GitRunner.parse_porcelain_v1_z`. Map:

| XY (either column) | Letter |
|---|---|
| `?` / `A` | A |
| `M` `R` `C` | M |
| `D` | D |

If several apply, prefer **D** then **M** then **A** so a staged delete wins. Untracked `??` is A.

Alternative: derive A/M/D from numstat only. Rejected — untracked files have no numstat, so new files would have no **A**.

Alternative: full `--ignored=matching -u`. Rejected — that is the old hitch.

### Decision 2: File postfix after `+N-M`

Line: `name` + optional ` +N-M` + optional ` X` where X is A/M/D. Colors: A `BSITreeGitAdded`, M `BSITreeGitModified` (`#e0af68`, restore in setup), D `BSITreeGitDeleted`. Gitignored: no postfix (grey wins).

### Decision 3: Directory DMA from children + missing deletes

Walk the existing node tree bottom-up. Each file contributes its letter. Each directory concatenates unique child letters (and child summaries) via `compute_dir_git_status`, store `git_status_summary` (`"D"`, `"MA"`, `"DMA"`, …). Also mark **D** for porcelain paths that are deleted and live under that directory but are not tree children (deleted files are absent from the scan). Do not insert those paths as nodes.

Render `" " .. summary` after the directory name; color each letter. Gitignored dirs: no summary.

Stubs: a collapsed/unpopulated dir still gets a summary from porcelain paths under it, so a closed folder can show `M` without expanding.

### Decision 4: Same async generation as numstat

Kick off porcelain after scan (open/refresh), same generation counter so a stale callback cannot stamp a newer tree. Stamp in place; `render()` only. Reuse or sit next to `_fetch_numstat` so one refresh does not double-scan.

Do not wait for porcelain before painting the listing.

## Risks / Trade-offs

- [Default porcelain still lists every untracked file] → Mitigation: no `-u` force; no ignored matching; timeout like other git helpers; tree already visible.
- [Deleted files invisible as rows] → Mitigation: they still set parent **D**. Acceptable; listing stays filesystem-true.
- [R/C shown as M] → Mitigation: matches the old DMA fold (`[MRC]` → M).
- [Two async git paths (numstat + porcelain)] → Mitigation: independent callbacks; either may arrive first; render is cheap.

## Migration Plan

No config. Users see A/M/D on files and DMA on dirs again. Rollback is revert of stamp/render plus the light porcelain call.

## Open Questions

None that change specs or tasks. Letter priority D > M > A on a single file is recorded in Decision 1.
