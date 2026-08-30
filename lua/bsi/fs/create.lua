-- lua/bsi/fs/create.lua
-- Resolve a destination path against a tree root and create a file or directory.

local function is_blank(s)
  return not s or s:match("^%s*$")
end

local function is_absolute(p)
  if p:sub(1, 1) == "/" then
    return true
  end
  -- Windows drive: C:\ or C:/
  if p:match("^%a:[/\\]") then
    return true
  end
  return false
end

--- Tree-root-relative path of a directory, always with a trailing slash
--- (empty string when the directory is the root itself).
---@param root string
---@param target_dir string
---@return string
local function default_path(root, target_dir)
  root = vim.fs.normalize(root or ""):gsub("/$", "")
  target_dir = vim.fs.normalize(target_dir or ""):gsub("/$", "")
  if target_dir == "" or target_dir == root then
    return ""
  end
  local prefix = root .. "/"
  if target_dir:sub(1, #prefix) == prefix then
    return target_dir:sub(#prefix + 1) .. "/"
  end
  local rel = vim.fn.fnamemodify(target_dir, ":~:.")
  if rel ~= "" and not rel:match("/$") then
    rel = rel .. "/"
  end
  return rel
end

---@class bsi.fs.CreateResult
---@field ok boolean
---@field path string|nil
---@field kind "file"|"dir"|"exists"|"empty"
---@field err string|nil

--- Create a file or directory from a user path string.
--- Relative paths join `root`. Trailing `/` creates a directory only.
---@param root string
---@param input string|nil
---@return bsi.fs.CreateResult
local function create(root, input)
  if is_blank(input) then
    return { ok = true, kind = "empty" }
  end

  ---@cast input string
  input = vim.trim(input)
  local as_dir = input:match("[/\\]$") ~= nil

  if input:sub(1, 1) == "~" then
    input = vim.fn.expand(input)
  end

  local path
  if is_absolute(input) then
    path = input
  else
    root = (root or ""):gsub("/$", "")
    path = root .. "/" .. input
  end
  path = vim.fs.normalize(path)

  local stat = (vim.uv or vim.loop).fs_stat(path)
  if stat then
    return { ok = false, path = path, kind = "exists", err = "already exists" }
  end

  if as_dir then
    local ok = vim.fn.mkdir(path, "p")
    if ok == 0 then
      return { ok = false, path = path, kind = "dir", err = "mkdir failed" }
    end
    return { ok = true, path = path, kind = "dir" }
  end

  local parent = vim.fn.fnamemodify(path, ":h")
  if parent ~= "" and vim.fn.isdirectory(parent) == 0 then
    local ok = vim.fn.mkdir(parent, "p")
    if ok == 0 then
      return { ok = false, path = path, kind = "file", err = "mkdir failed" }
    end
  end

  local fd, err = io.open(path, "w")
  if not fd then
    return { ok = false, path = path, kind = "file", err = err or "open failed" }
  end
  fd:close()
  return { ok = true, path = path, kind = "file" }
end

return setmetatable({
  default_path = default_path,
}, {
  __call = function(_, root, input)
    return create(root, input)
  end,
})
