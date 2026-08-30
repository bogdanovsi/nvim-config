## Why

Gitignore handling was removed from the tree with porcelain status because `git status --porcelain -z --ignored=matching -u` listed the whole working tree and stalled large repos. The scanner now only skips a hard-coded name list (`node_modules`, `vendor`, …), so real `.gitignore` rules are ignored. The new bounded filesystem scan already visits the files we care about — including `.gitignore` files — so ignore status can be derived from that scan instead of a second, unbounded git dump.

## What Changes

- After each filesystem scan, build gitignore info from `.gitignore` files found among the scanned entries and apply it to those same paths (and their unscanned child stubs when a parent ignore applies).
- Attach ignore status to scanned nodes so the tree can hide gitignored entries when `show_ignored` is false, and show them when the existing `h` toggle is on.
- Keep the one-level 5000-entry scan at or under the existing 200 ms budget. Gitignore work MUST NOT spawn whole-repo porcelain, numstat, untracked-dir expansion, or `.git` watchers.
- Leave the scanner a filesystem module: listing, name-based skip, sort, and collapse stay in `Provider:scan`. Gitignore matching is a cheap pass over the scan result, not extra syscalls on the readdir/scandir hot path.
- Name-based skip of heavy directories remains the first gate so `node_modules` is still not enumerated.
- Do **not** restore porcelain XY decorations, numstat `+N−M`, git-only mode, or Project watchers.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `ui/tree`: Scanned nodes carry gitignore status derived from `.gitignore` files discovered in the scan; gitignored entries follow `show_ignored`; the 200 ms one-level scan budget still holds when that info is built.

## Impact

- `lua/bsi/fs/provider.lua` — scan stays the source of directory entries; no porcelain on the scan path; backends and the 200 ms tests remain.
- New or extended git helper under `lua/bsi/git/` — parse `.gitignore` files from the scan and mark matching scanned paths. Existing `lua/bsi/git/status.lua` porcelain runner is not wired back into the tree.
- `lua/bsi/ui/tree.lua` — consume ignore status for hide/show; `h` still toggles ignored entries (name-based **and** gitignored).
- Tests: unit coverage for nested `.gitignore`, negation, and parent-ignored stubs; performance tests still enforce 200 ms on 5000-entry fixtures **including** gitignore annotation.
- Informal `specs/ui/tree.md` currently says there is no gitignore snapshot; it should be updated when this lands so the product overview matches.
