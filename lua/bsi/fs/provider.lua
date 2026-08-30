-- lua/bsi/fs/provider.lua
-- Filesystem-only directory scanner. No buffers, windows, or icon plugins.
--
-- Backends (see :scan opts.backend):
--   lstat    — two-pass scandir then fs_lstat every entry (original)
--   scandir  — nvim-tree / snacks: one-pass fs_scandir_next, use dentry type, lstat only if missing
--              https://github.com/nvim-tree/nvim-tree.lua explorer/init.lua
--              https://github.com/folke/snacks.nvim explorer/tree.lua
--   readdir  — neo-tree: fs_opendir + batched fs_readdir (name+type, no per-file lstat)
--              https://github.com/nvim-neo-tree/neo-tree.nvim .../fs_scan.lua

---@class bsi.fs.Provider
local Provider = {}
Provider.__index = Provider

local uv = vim.uv or vim.loop

local DEFAULT_IGNORE = { "node_modules$", "^vendor$", "^dist$", "^build$", "^target$" }
local READDIR_BATCH = 1000

--- Default after 5000-file bench: readdir ~18ms, scandir ~19ms, lstat ~50ms.
--- Override per-call with opts.backend = "lstat"|"scandir"|"readdir".
Provider.backend = "readdir"

function Provider.new()
  return setmetatable({}, Provider)
end

---@param name string
---@return boolean
function Provider:_should_ignore_name(name)
  for _, pattern in ipairs(DEFAULT_IGNORE) do
    if name:match(pattern) then
      return true
    end
  end
  return false
end

--- Determines whether a path should be skipped based on hidden settings.
---@param name string
---@param opts table|nil { show_ignored = boolean }
function Provider:_should_skip(name, opts)
  opts = opts or {}
  local show_ignored = opts.show_ignored == true

  if name == ".git" and not show_ignored then
    return true
  end

  if not show_ignored and self:_should_ignore_name(name) then
    return true
  end

  return false
end

---@class bsi.fs.DirEntry
---@field name string
---@field type string

--- Original: collect names, then lstat each (extra syscall per entry).
---@param path string
---@param opts table
---@return bsi.fs.DirEntry[]
function Provider:_list_lstat(path, opts)
  local names = {}
  local handle = uv.fs_scandir(path)
  if handle then
    while true do
      local name = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if not self:_should_skip(name, opts) then
        names[#names + 1] = name
      end
    end
  end

  local entries = {}
  for _, name in ipairs(names) do
    local stat = uv.fs_lstat(path .. "/" .. name)
    if stat then
      entries[#entries + 1] = { name = name, type = stat.type }
    end
  end
  return entries
end

--- nvim-tree / snacks: one pass; prefer dentry type from fs_scandir_next.
---@param path string
---@param opts table
---@return bsi.fs.DirEntry[]
function Provider:_list_scandir(path, opts)
  local entries = {}
  local handle = uv.fs_scandir(path)
  if not handle then
    return entries
  end
  while true do
    local name, etype = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if not self:_should_skip(name, opts) then
      if not etype then
        local stat = uv.fs_lstat(path .. "/" .. name)
        etype = stat and stat.type
      end
      if etype then
        entries[#entries + 1] = { name = name, type = etype }
      end
    end
  end
  return entries
end

--- neo-tree: opendir + readdir in batches of 1000; each record has name+type.
---@param path string
---@param opts table
---@return bsi.fs.DirEntry[]
function Provider:_list_readdir(path, opts)
  local entries = {}
  local dir = uv.fs_opendir(path, nil, READDIR_BATCH)
  if not dir then
    return entries
  end
  repeat
    local stats = uv.fs_readdir(dir)
    if not stats then
      break
    end
    local more = false
    for i, stat in ipairs(stats) do
      more = i == READDIR_BATCH
      if not self:_should_skip(stat.name, opts) then
        entries[#entries + 1] = { name = stat.name, type = stat.type }
      end
    end
  until not more
  uv.fs_closedir(dir)
  return entries
end

---@param path string
---@param opts table
---@return bsi.fs.DirEntry[]
function Provider:_list_entries(path, opts)
  local backend = opts.backend or Provider.backend or "scandir"
  if backend == "lstat" then
    return self:_list_lstat(path, opts)
  elseif backend == "readdir" then
    return self:_list_readdir(path, opts)
  end
  return self:_list_scandir(path, opts)
end

local function sort_children(children)
  table.sort(children, function(a, b)
    if a.type ~= b.type then
      return a.type == "directory"
    end
    if a.type == "directory" then
      local function dir_priority(n)
        if n == ".git" then
          return 0
        end
        if n:sub(1, 1) == "." then
          return 1
        end
        return 2
      end
      local pa, pb = dir_priority(a.name), dir_priority(b.name)
      if pa ~= pb then
        return pa < pb
      end
    end
    return a.name:lower() < b.name:lower()
  end)
end

local function collapse_single_child(node)
  if node.type ~= "directory" or #node.children ~= 1 or node.children[1].type ~= "directory" then
    return
  end
  local child = node.children[1]
  local unpopulated = child._unpopulated
  node.name = node.name .. "/" .. child.name
  node.children = child.children or {}
  node.path = child.path
  node.id = child.id
  if unpopulated then
    node._unpopulated = true
  end
  local function sync_depth(n, d)
    n.depth = d
    if n.children then
      for _, c in ipairs(n.children) do
        sync_depth(c, d + 1)
      end
    end
  end
  if node.children then
    for _, c in ipairs(node.children) do
      sync_depth(c, node.depth + 1)
    end
  end
end

--- Follow a chain of directories that contain only one subdirectory and no files.
--- Stops at the last directory that has files (or at a dead-end empty dir).
---@return string display_name
---@return string leaf_path
function Provider:_follow_empty_chain(path, name, opts)
  local display = name
  local cur = path
  local guard = {}
  while true do
    if guard[cur] then
      break
    end
    guard[cur] = true
    local nfiles, ndirs = 0, 0
    local only_dir
    for _, e in ipairs(self:_list_entries(cur, opts)) do
      if e.type == "directory" then
        ndirs = ndirs + 1
        only_dir = e
      else
        nfiles = nfiles + 1
      end
    end
    if nfiles > 0 then
      break
    end
    if ndirs == 1 and only_dir then
      display = display .. "/" .. only_dir.name
      cur = cur .. "/" .. only_dir.name
    else
      break
    end
  end
  return display, cur
end

--- Scans a directory path to build a tree of bsi.Node objects.
--- When expand_all is false and max_depth is nil, only this directory's
--- direct children are populated (child dirs are unpopulated stubs).
---@param path string
---@param depth integer
---@param opts table|nil { expand_all, show_ignored, max_depth, backend }
---@return bsi.Node
function Provider:scan(path, depth, opts)
  depth = depth or 0
  opts = opts or {}

  local expand_all = opts.expand_all
  local max_d = opts.max_depth
  if not expand_all and max_d == nil then
    max_d = depth
  end

  local node = {
    id = path,
    name = vim.fn.fnamemodify(path, ":t") or path,
    path = path,
    type = depth == 0 and "root" or "directory",
    depth = depth,
    expanded = expand_all or (depth == 0),
    children = {},
  }

  for _, entry in ipairs(self:_list_entries(path, opts)) do
    local fullpath = path .. "/" .. entry.name
    local is_dir = entry.type == "directory"
    local child

    if is_dir then
      local at_max_depth = max_d and (depth + 1 > max_d)
      if at_max_depth and not expand_all then
        local display, leaf = self:_follow_empty_chain(fullpath, entry.name, opts)
        child = {
          id = leaf,
          name = display,
          path = leaf,
          type = "directory",
          depth = depth + 1,
          expanded = false,
          children = {},
          _unpopulated = true,
        }
      else
        child = self:scan(fullpath, depth + 1, opts)
        child.expanded = expand_all or false
      end
    else
      child = {
        id = fullpath,
        name = entry.name,
        path = fullpath,
        type = "file",
        depth = depth + 1,
        expanded = false,
        children = nil,
      }
    end

    table.insert(node.children, child)
  end

  sort_children(node.children)
  collapse_single_child(node)
  return node
end

return Provider
