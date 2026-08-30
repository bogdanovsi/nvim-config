## 1. Extract filesystem provider

- [x] 1.1 Add `lua/bsi/fs/provider.lua` with `Provider.new` / `scan` moved from `tree.lua` (ignore, sort, collapse; no devicons or UI) — verify: `require("bsi.fs.provider")` returns a module whose `new():scan` works in headless Neovim
- [x] 1.2 Default missing `max_depth` with `expand_all` false to one-level stubs — verify: nested files under child dirs are absent unless `expand_all`
- [x] 1.3 Remove the inlined Provider from `lua/bsi/ui/tree.lua` and `require("bsi.fs.provider")`; attach icons in the UI layer if still needed — verify: `require("bsi.ui.tree")` loads and `Tree.new` still scans a real directory

## 2. Unit tests

- [x] 2.1 Add `lua/bsi/fs/provider_spec.lua` with a small-fixture helper (temp dir, `after_each` delete) — verify: helper leaves no leftover files
- [x] 2.2 Test ignore: hidden skips `node_modules`/`vendor`/`dist`/`build`/`target`/`.git`; `.env` stays; `show_ignored` includes `node_modules` — verify: assertions on child names
- [x] 2.3 Test one-level stubs vs `expand_all` descendants — verify: `_unpopulated` stubs without nested files; expand-all includes nested files
- [x] 2.4 Test sort (dirs before files, case-insensitive names) and single-child collapse (`foo/bar`) — verify: child order and collapsed `name`
- [x] 2.5 Test missing path does not error and file nodes have no `_icon` — verify: pcall success / empty children; `_icon == nil`

## 3. Performance tests

- [x] 3.1 Test one-level scan of 5000 top-level files completes in ≤200 ms (`vim.uv.hrtime` around scan only) and returns 5000 file children with dir stubs only — verify: fail if elapsed > 200 ms or nested files appear
- [x] 3.2 Test one-level scan with hidden ignore skips a `node_modules` tree of ≥5000 files and still finishes in ≤200 ms — verify: `node_modules` absent; same budget

## 4. Integration verification

- [x] 4.1 Run `make test` and confirm `lua/bsi/fs/provider_spec.lua` plus existing suite pass — verify: `make test` exit code 0
