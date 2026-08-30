## 1. Prune helper

- [x] 1.1 Add `lua/bsi/fs/prune.lua` with `prune(root, start_dir)` that walks toward `root` and removes each directory whose subtree has no files — verify: `require("bsi.fs.prune")` is callable
- [x] 1.2 Never delete `root`; stop at the first ancestor that contains any file (including dotfiles); do not follow directory symlinks — verify: `.gitkeep` keeps its directory; root remains

## 2. Tests

- [x] 2.1 Add `lua/bsi/fs/prune_spec.lua` with temp-root fixtures and `after_each` cleanup — verify: leftover dirs are deleted
- [x] 2.2 Test deleting the last file under `src/app1/app/` removes `app` and `app1` but not `src` when `src` has another file — verify: paths on disk
- [x] 2.3 Test a sibling file or `.gitkeep` blocks prune — verify: parent directory still exists
- [x] 2.4 Test an empty nested chain `hooks/` inside `app/` with no files is removed as a whole — verify: all three dirs gone, root kept

## 3. Tree wiring

- [x] 3.1 After a successful `_delete_node`, prune the deleted path’s parent then refresh — verify: `d` still confirms before delete
- [x] 3.2 After a successful rename/move, prune the **old** parent if it is still under the tree root — verify: `make test` exit 0
