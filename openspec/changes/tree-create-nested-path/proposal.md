## Why

`a` in the BSI tree only asks for a name under the cursor’s directory (`New file (in src/app): `). To put a file in a different folder you must first navigate there. The whole destination should be editable in one string — like `src/app/index.tsx` → `src/app1/app/index.tsx` — and missing directories must be created.

## What Changes

- Change the add-file prompt so the **path is the input**, not a parenthetical. Default is the tree-relative path of the target directory (trailing `/`), e.g. `New file: src/app/`.
- Treat the submitted string as a destination path (relative to the tree root, or absolute). Editing `src/app/index.tsx` to `src/app1/app/index.tsx` creates `src/app1/app/` and the file.
- Create every missing intermediate directory (`mkdir -p`).
- Trailing `/` creates a directory only (no empty file).
- Do not overwrite an existing file or directory; warn instead.
- Keep current follow-up for files: refresh, reveal in the tree, open in an editor.

## Capabilities

### New Capabilities

- `ui/tree`: Nested path create from the tree add prompt — user edits the full destination; parents are created as needed.

### Modified Capabilities

- (none — `openspec/specs/` has no archived `ui/tree` yet; `tree-provider-scan-perf-tests` introduced the same path for scan and is not archived)

## Impact

- `lua/bsi/ui/tree.lua` — `Tree:_add_file` prompt, default, path resolution, mkdir, file vs directory create.
- Tests under `lua/bsi/` for path resolution and nested create (temp dirs; no UI required if the create helper is extracted).
- Informal `specs/ui/tree.md` is not rewritten here. Keymap stays `a`.
