-- lua/bsi/git/ignore.lua
-- Mark scanned tree nodes as git_ignored from .gitignore files in the node tree.
-- No git subprocess. Pattern subset: comments, blanks, !, trailing /, leading /, *, ?, **.

local M = {}

local uv = vim.uv or vim.loop

local MAGIC = {
  ["("] = "%(",
  [")"] = "%)",
  ["."] = "%.",
  ["%"] = "%%",
  ["+"] = "%+",
  ["-"] = "%-",
  ["["] = "%[",
  ["]"] = "%]",
  ["^"] = "%^",
  ["$"] = "%$",
}

local function read_file(path)
  local fd = uv.fs_open(path, "r", 420)
  if not fd then
    return nil
  end
  local stat = uv.fs_fstat(fd)
  if not stat then
    uv.fs_close(fd)
    return nil
  end
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return data
end

--- Convert a gitignore glob (anchors already stripped) to a Lua pattern for a `/`-separated rel path.
local function glob_to_lua(glob)
  local out = {}
  local i = 1
  local n = #glob
  while i <= n do
    local c = glob:sub(i, i)
    if c == "*" then
      if glob:sub(i + 1, i + 1) == "*" then
        if glob:sub(i + 2, i + 2) == "/" then
          out[#out + 1] = ".-"
          i = i + 3
        else
          out[#out + 1] = ".*"
          i = i + 2
        end
      else
        out[#out + 1] = "[^/]*"
        i = i + 1
      end
    elseif c == "?" then
      out[#out + 1] = "[^/]"
      i = i + 1
    else
      out[#out + 1] = MAGIC[c] or c
      i = i + 1
    end
  end
  return table.concat(out)
end

---@param content string|nil
---@param base_dir string
---@return table[]
function M.parse(content, base_dir)
  local patterns = {}
  if not content or content == "" then
    return patterns
  end
  if content:sub(-1) ~= "\n" then
    content = content .. "\n"
  end
  for raw in content:gmatch("(.-)\n") do
    local line = raw:gsub("\r$", "")
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local negated = false
      if line:sub(1, 1) == "!" then
        negated = true
        line = line:sub(2)
      end
      local dir_only = false
      if line:sub(-1) == "/" then
        dir_only = true
        line = line:sub(1, -2)
      end
      local anchored = false
      if line:sub(1, 1) == "/" then
        anchored = true
        line = line:sub(2)
      elseif line:find("/", 1, true) then
        anchored = true
      end
      if line ~= "" then
        patterns[#patterns + 1] = {
          negated = negated,
          dir_only = dir_only,
          anchored = anchored,
          base_dir = base_dir,
          lua = glob_to_lua(line),
        }
      end
    end
  end
  return patterns
end

local function rel_to(base, path)
  if not base or not path then
    return nil
  end
  if path == base then
    return ""
  end
  local prefix = base .. "/"
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
  return nil
end

---@param pat table
---@param abs_path string
---@param is_dir boolean
---@return boolean
function M.matches_pattern(pat, abs_path, is_dir)
  if pat.dir_only and not is_dir then
    return false
  end
  local rel = rel_to(pat.base_dir, abs_path)
  if not rel or rel == "" then
    return false
  end
  local lua = pat.lua
  if pat.anchored then
    return rel:match("^" .. lua .. "$") ~= nil
  end
  if rel:match("^" .. lua .. "$") then
    return true
  end
  if rel:match("/" .. lua .. "$") then
    return true
  end
  return false
end

local function copy_stack(stack)
  local t = {}
  for i, p in ipairs(stack) do
    t[i] = p
  end
  return t
end

local function walk(node, stack, parent_ignored)
  local patterns = stack
  if node.children then
    for _, c in ipairs(node.children) do
      if c.type == "file" and c.name == ".gitignore" then
        local extra = M.parse(read_file(c.path), node.path)
        if extra and #extra > 0 then
          patterns = copy_stack(stack)
          for _, p in ipairs(extra) do
            patterns[#patterns + 1] = p
          end
        end
        break
      end
    end
  end

  if not node.children then
    return
  end

  for _, child in ipairs(node.children) do
    local is_dir = child.type == "directory" or child.type == "root"
    local ignored = parent_ignored
    for _, pat in ipairs(patterns) do
      if M.matches_pattern(pat, child.path, is_dir) then
        ignored = not pat.negated
      end
    end
    child.git_ignored = ignored and true or false
    if is_dir then
      walk(child, patterns, child.git_ignored)
    end
  end
end

--- Set `git_ignored` on scanned descendants from `.gitignore` files in the tree.
---@param root table|nil
---@return table|nil
function M.annotate(root)
  if not root then
    return root
  end
  if root.git_ignored == nil then
    root.git_ignored = false
  end
  walk(root, {}, false)
  return root
end

return M
