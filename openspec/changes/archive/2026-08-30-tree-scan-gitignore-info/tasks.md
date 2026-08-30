## 1. Gitignore matcher

- [x] 1.1 Add `lua/bsi/git/ignore.lua` with `annotate(root_node)` that reads `.gitignore` files found in the node tree, matches the design pattern subset, and sets `git_ignored` on scanned nodes — verify: `require("bsi.git.ignore")` loads in headless Neovim
- [x] 1.2 Add `lua/bsi/git/ignore_spec.lua`: root `*.log` marks `debug.log`; no `.gitignore` leaves files unmarked; works in a temp dir with no `.git` — verify: those examples pass
- [x] 1.3 Cover nested `pkg/.gitignore` with `dist/` and negation `*.log` then `!keep.log` — verify: `pkg/dist` ignored, sibling not; `debug.log` ignored, `keep.log` not
- [x] 1.4 Cover a one-level `build/` stub marked gitignored without listing files inside `build` — verify: stub has `git_ignored` and no children from inside `build`

## 2. Scan performance with annotation

- [x] 2.1 Time `scan` plus `annotate` on 5000 top-level files and a `.gitignore` that ignores a subset; fail if over 200 ms — verify: budget assertion in `ignore_spec` or `provider_spec`
- [x] 2.2 Confirm hidden `node_modules` (≥5000 files) is still absent after scan+annotate and still ≤200 ms — verify: name missing and budget holds

## 3. Tree gitignore greying

- [x] 3.1 After `Provider:scan` on open, expand, and refresh, call `ignore.annotate` on the new nodes — verify: a tree rooted on a fixture with `.gitignore` + `secret.env` has `secret.env.git_ignored == true`
- [x] 3.2 Restore `BSITreeGitIgnored` in setup and grey arrow+icon+name for `git_ignored` rows — verify: render of a gitignored node applies `BSITreeGitIgnored` over that span
- [x] 3.3 Keep name-based skip: with `show_ignored=false`, `node_modules` is absent while a gitignored `secret.env` stays listed and grey — verify: child names and highlight

## 4. Numstat +N-M

- [x] 4.1 Add `lua/bsi/git/numstat.lua` that parses `git diff --numstat` lines, merges staged+unstaged `{ added, deleted }` per absolute path, and formats ` +N-M` / ` +N` / ` -M` — verify: unit tests for merge and format
- [x] 4.2 After the tree is populated, fetch numstat asynchronously; on success stamp `git_numstat` on non-ignored file nodes and re-render without calling `scan` — verify: a stubbed fetch updates nodes and does not invoke `Provider:scan` again
- [x] 4.3 Restore `BSITreeGitAdded` / `BSITreeGitDeleted` and append the formatted counts after the file name with split highlights — verify: a node with added 23 and deleted 23 renders ` +23-23` with those groups
- [x] 4.4 Skip numstat text on `git_ignored` rows; if there is no git root or git fails, scan still succeeds with no `+N-M` — verify: ignored file has no detail; non-repo fixture has no detail and no error
- [x] 4.5 Ignore stale numstat callbacks after a newer refresh (generation counter) — verify: old callback does not overwrite newer nodes

## 5. Integration

- [x] 5.1 Update informal `specs/ui/tree.md` so it no longer says gitignore snapshots and numstat are fully removed — verify: the overview mentions grey gitignored rows and `+N-M`
- [x] 5.2 Run `make test` and confirm provider, ignore, numstat, and tree tests pass — verify: exit code 0
