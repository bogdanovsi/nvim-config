## Context

See proposal.md for motivation. `Provider:scan` is a fast filesystem listing (`readdir` default, ≤200 ms on 5000 entries) with name-based skip only. `Renderer:render` draws indent, arrow, icon, and name with no git highlights. Before the 2026-08 optimize, the tree greys `git_ignored` rows (`BSITreeGitIgnored`) and appends file `git_numstat` as ` +N-M` / ` +N` / ` -M`. That path also ran porcelain status and re-scanned the filesystem when git data arrived — the lag we must not bring back.

## Goals / Non-Goals

**Goals:**
- Annotate a scan result with gitignore flags without extra directory syscalls.
- Grey gitignored rows the way the old renderer did.
- Fetch numstat asynchronously and stamp existing file nodes; re-render only.
- Keep `Provider:scan` free of git.

**Non-Goals:**
- Porcelain XY, directory AMD summaries, git-only mode, Project watchers.
- Matching `.git/info/exclude` or global `excludesfile`.
- Honouring the git index (tracked files that match a gitignore pattern are still marked gitignored).
- Changing the name-based skip list or the default `show_ignored=false`.

## Decisions

### Decision 1: Gitignore matcher `lua/bsi/git/ignore.lua`

```lua
local ignore = require("bsi.git.ignore")
ignore.annotate(root_node)
```

Walk the node tree once:

1. If the current directory has a child named `.gitignore`, read that file (one `fs_open` per gitignore, not per entry) and compile its patterns relative to that directory.
2. For each child, match against the stacked patterns from this directory and ancestors; set `node.git_ignored = true|false`.
3. If a parent is ignored, children/stubs inherit ignored unless a later `!` negation un-ignores them.
4. Directory patterns (`build/`) match directory nodes only.

Pattern subset: comments, blanks, `!`, trailing `/`, leading `/` (relative to that gitignore’s directory), `*`, `?`, `**`. Compile each pattern to a Lua matcher once; do not spawn git.

Alternative: `git check-ignore --stdin` on scanned paths. Rejected — still a git subprocess on every scan, fails without git, and is not “from the scan”. Alternative: wire `bsi.git.status` porcelain `--ignored=matching`. Rejected — that is the old stall.

### Decision 2: Annotate after scan, not inside `_list_*`

`Provider:scan` stays listing + name skip + sort + collapse. Tree (open, expand, refresh) calls `ignore.annotate` on the returned node or subtree. Expand of a stub annotates only that subtree, stacking ancestor gitignore already loaded if we pass the compiled stack; simplest correct approach is re-read `.gitignore` files visible on the path from tree root to the expanded dir (those files are already in parent children).

Do not parse gitignore inside `readdir`/`scandir` loops — that would add file reads to the 5000-entry hot path when a `.gitignore` is absent we pay nothing beyond checking the child’s name.

### Decision 3: Grey in the renderer, not by omitting nodes

If `node.git_ignored`, highlight arrow+icon+name with `BSITreeGitIgnored` (`#5c6370`), same as before. Name-based skip still happens in the provider. Gitignored scanned files stay in `children` so they can be grey.

Restore in `M.setup`:

- `BSITreeGitIgnored` `{ fg = "#5c6370" }`
- `BSITreeGitAdded` `{ fg = "#9ece6a" }`
- `BSITreeGitDeleted` `{ fg = "#f7768e" }`

### Decision 4: Numstat is async attach, never a second scan

Helper `lua/bsi/git/numstat.lua`:

```lua
numstat.fetch_async(git_root, function(map) -- abs_path -> { added, deleted } end)
```

Two commands, merge by path (sum added/deleted):

- `git -C <root> --no-optional-locks diff --numstat`
- `git -C <root> --no-optional-locks diff --cached --numstat`

Parse `added deleted path` (treat `-` as 0 for binary). Resolve paths against `git_root`. On success, walk **existing** nodes, set `file.git_numstat` when not `git_ignored`, then `renderer:render`. If no git root or the command fails, leave numstat unset.

Tree kicks this off after the first scan (and after refresh). Generation counter so a stale callback cannot stamp a newer tree.

Alternative: pass numstat into `scan` and re-scan. Rejected — that was the old hitch. Alternative: include numstat in the 200 ms test. Rejected — git time is not listing time.

Format (old renderer):

- both > 0 → `" +%d-%d"`
- only added → `" +%d"`
- only deleted → `" -%d"`
- split highlight: `+` segment `BSITreeGitAdded`, `-` segment `BSITreeGitDeleted`

### Decision 5: Tests

- `lua/bsi/git/ignore_spec.lua` — nested gitignore, negation, stubs, no-git fixture, 5000-file + `.gitignore` budget including `annotate`.
- `lua/bsi/git/numstat_spec.lua` — parser merge of staged+unstaged; format helper for `+N-M`.
- Renderer: grey range and `+N-M` text. Prefer a small function that builds line+highlight specs so tests do not need a window, or drive `Renderer:render` on a scratch buffer in headless Neovim.
- Existing `provider_spec.lua` performance tests stay listing-only; add annotation time either in `ignore_spec` or by wrapping scan+annotate in that file. Spec requires the timed path to include annotation.

## Risks / Trade-offs

- [Gitignore subset ≠ full git] → Mitigation: documented; no index/exclude/global. Wrong marks possible for tracked-but-ignored-pattern files. Acceptable vs porcelain cost.
- [Reading every nested `.gitignore` on expand-all] → Mitigation: default scan is one level; expand-all is user-opted and still only reads gitignore files present in the result, not the whole repo.
- [Numstat on a huge diff is slow] → Mitigation: async; tree already painted; timeout/kill like other git helpers; do not re-scan.
- [Stale numstat after refresh] → Mitigation: increment a generation; ignore callbacks from older generations.
- [Byte vs character columns for highlights] → Mitigation: keep ASCII ` +N-M` and highlight by constructed offsets as the old renderer did.

## Migration Plan

No config keys. Users see grey gitignored files and `+N-M` again. Rollback is revert of `bsi/git/ignore.lua`, `bsi/git/numstat.lua`, and tree annotate/render/setup hooks.

## Open Questions

None that change specs or tasks. Highlight default for `BSITreeGitIgnored` follows the previous `#5c6370`; users can override via `nvim_set_hl` after setup.
