## 1. Create helper

- [x] 1.1 Add `lua/bsi/fs/create.lua` that resolves `root` + input (absolute, `~`, or relative to root), `mkdir -p` parents, and creates a file or a trailing-slash directory — verify: `require("bsi.fs.create")` returns a function
- [x] 1.2 Return `{ ok, path, kind }` with `kind` `file` | `dir` | `exists` | `empty` and never overwrite — verify: existing path returns `kind = "exists"` and unchanged contents

## 2. Tests

- [x] 2.1 Add `lua/bsi/fs/create_spec.lua` with temp-root fixtures — verify: helper deletes leftover files in `after_each`
- [x] 2.2 Test `src/app1/app/index.tsx` from root creates parents and an empty file — verify: file exists and size 0
- [x] 2.3 Test trailing slash creates a directory only — verify: `src/app1/hooks/` is a directory, no file named `hooks`
- [x] 2.4 Test empty input is a no-op and existing file is not overwritten — verify: `kind` is `empty` / `exists`

## 3. Tree prompt

- [x] 3.1 Change `Tree:_add_file` to prompt `New file: ` with default = tree-relative target dir + `/` and `completion = "file"` — verify: default for a file node is its parent path with `/`
- [x] 3.2 On success call `create`, then refresh + `find_file`; open the editor only for `kind = "file"`; warn on `exists` — verify: `a` still mapped; `make test` exit 0
