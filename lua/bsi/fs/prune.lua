-- lua/bsi/fs/prune.lua
-- Remove ancestor directories whose subtree contains no files.

local uv = vim.uv or vim.loop

local function normalize(p)
  return vim.fs.normalize(p or ""):gsub("/$", "")
end

local function is_under_root(root, dir)
  if dir == root then
    return true
  end
  return dir:sub(1, #root + 1) == root .. "/"
end

--- True if any file (or symlink-to-file) exists under dir. Does not follow directory symlinks.
---@param dir string
---@return boolean
local function has_files(dir)
  local handle = uv.fs_scandir(dir)
  if not handle then
    return false
  end
  while true do
    local name, etype = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    local full = dir .. "/" .. name
    if not etype then
      local st = uv.fs_lstat(full)
      etype = st and st.type
    end
    if etype == "directory" then
      if has_files(full) then
        return true
      end
    elseif etype == "link" then
      local followed = uv.fs_stat(full)
      if followed and followed.type ~= "directory" then
        return true
      end
    elseif etype then
      return true
    end
  end
  return false
end

--- Prune empty-of-files directories from start_dir up to (not including) root.
---@param root string
---@param start_dir string
---@return { removed: string[] }
local function prune(root, start_dir)
  local removed = {}
  root = normalize(root)
  local dir = normalize(start_dir)
  if root == "" or dir == "" then
    return { removed = removed }
  end
  if not is_under_root(root, dir) then
    return { removed = removed }
  end

  if not uv.fs_stat(dir) then
    dir = vim.fn.fnamemodify(dir, ":h")
    dir = normalize(dir)
  end

  while dir ~= "" and dir ~= root and is_under_root(root, dir) do
    if has_files(dir) then
      break
    end
    local parent = normalize(vim.fn.fnamemodify(dir, ":h"))
    vim.fn.delete(dir, "rf")
    removed[#removed + 1] = dir
    dir = parent
  end

  return { removed = removed }
end

return setmetatable({}, {
  __call = function(_, root, start_dir)
    return prune(root, start_dir)
  end,
})
