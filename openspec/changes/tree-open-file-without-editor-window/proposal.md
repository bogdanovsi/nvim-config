## Why

Opening a file from the tree with Enter (or after creating one) assumes a sibling editor window exists (`wincmd l` then `:edit`). After deleting the file that was shown on the right, that window is gone and only the tree remains. The tree has `winfixbuf`, so `:edit` raises E1513 and the file never opens.

## What Changes

- Opening a file from the tree SHALL still land in a normal editor window when no editor window remains (tree is the only window, or the only other windows are floats/terminals).
- If no suitable editor window exists, the tree SHALL create one (split) rather than `:edit` in the tree.
- The same path SHALL apply after a successful file create (`a`), which currently uses the same `wincmd l` + `:edit`.
- The tree window SHALL keep the tree buffer. Do not special-case delete; make open robust so `:q` on the last file window has the same outcome.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `ui/tree`: Opening a file from the tree (Enter, create follow-up) must use or create an editor window when none remains; the tree is never the `:edit` target.

## Impact

- `lua/bsi/ui/tree.lua` — `Tree:_open_file`, `Tree:_add_file` window selection.
- Tests under `lua/bsi/ui/` that open a real tree window, wipe the last editor window, then open a file without E1513.
- No keymap, command, or plugin changes.
