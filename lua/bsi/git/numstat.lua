-- lua/bsi/git/numstat.lua
-- Parse and merge git diff --numstat (unstaged + staged). No filesystem scan.

local M = {}

local function abs_path(git_root, rel)
  if not rel or rel == "" then
    return nil
  end
  if rel:sub(1, 1) == '"' then
    rel = rel:sub(2, -2):gsub('\\"', '"')
  end
  git_root = git_root:gsub("/+$", "")
  return git_root .. "/" .. rel
end

local function count(s)
  if not s or s == "-" then
    return 0
  end
  return tonumber(s) or 0
end

--- Parse numstat stdout into abs_path -> { added, deleted }, merging into `into`.
---@param stdout string|nil
---@param git_root string
---@param into table|nil
---@return table
function M.parse(stdout, git_root, into)
  into = into or {}
  if not stdout or stdout == "" then
    return into
  end
  for line in stdout:gmatch("[^\r\n]+") do
    local added_str, deleted_str, path = line:match("^(%S+)%s+(%S+)%s+(.+)$")
    if added_str and deleted_str and path then
      local full = abs_path(git_root, path)
      if full then
        local added = count(added_str)
        local deleted = count(deleted_str)
        local cur = into[full]
        if cur then
          cur.added = cur.added + added
          cur.deleted = cur.deleted + deleted
        else
          into[full] = { added = added, deleted = deleted }
        end
      end
    end
  end
  return into
end

--- Merge two abs_path maps by summing added/deleted.
---@param a table|nil
---@param b table|nil
---@return table
function M.merge(a, b)
  local out = {}
  for path, ns in pairs(a or {}) do
    out[path] = { added = ns.added or 0, deleted = ns.deleted or 0 }
  end
  for path, ns in pairs(b or {}) do
    local cur = out[path]
    if cur then
      cur.added = cur.added + (ns.added or 0)
      cur.deleted = cur.deleted + (ns.deleted or 0)
    else
      out[path] = { added = ns.added or 0, deleted = ns.deleted or 0 }
    end
  end
  return out
end

--- Format added/deleted as " +N-M", " +N", " -M", or "".
---@param added number|nil
---@param deleted number|nil
---@return string
function M.format(added, deleted)
  local a = tonumber(added) or 0
  local d = tonumber(deleted) or 0
  if a > 0 and d > 0 then
    return string.format(" +%d-%d", a, d)
  elseif a > 0 then
    return string.format(" +%d", a)
  elseif d > 0 then
    return string.format(" -%d", d)
  end
  return ""
end

local function toplevel_then(start_path, done)
  vim.system({ "git", "-C", start_path, "--no-optional-locks", "rev-parse", "--show-toplevel" }, {
    text = true,
    timeout = 4000,
  }, function(obj)
    if not obj or obj.code ~= 0 then
      done(nil)
      return
    end
    local root = (obj.stdout or ""):gsub("%s+$", "")
    if root == "" then
      done(nil)
      return
    end
    done(root)
  end)
end

local function diff_cmd(git_root, cached)
  local cmd = { "git", "-C", git_root, "--no-optional-locks", "diff" }
  if cached then
    cmd[#cmd + 1] = "--cached"
  end
  cmd[#cmd + 1] = "--numstat"
  return cmd
end

--- Async: resolve git root from start_path, then unstaged + staged numstat.
---@param start_path string
---@param done fun(map: table|nil)
function M.fetch_async(start_path, done)
  if not start_path or start_path == "" then
    vim.schedule(function()
      done(nil)
    end)
    return
  end

  toplevel_then(start_path, function(git_root)
    if not git_root then
      vim.schedule(function()
        done(nil)
      end)
      return
    end

    local pending = 2
    local unstaged, staged
    local failed = false

    local function finish()
      pending = pending - 1
      if pending > 0 then
        return
      end
      vim.schedule(function()
        if failed then
          done(nil)
          return
        end
        done(M.merge(unstaged, staged))
      end)
    end

    vim.system(diff_cmd(git_root, false), { text = true, timeout = 8000 }, function(obj)
      if not obj or obj.code ~= 0 then
        failed = true
      else
        unstaged = M.parse(obj.stdout, git_root)
      end
      finish()
    end)

    vim.system(diff_cmd(git_root, true), { text = true, timeout = 8000 }, function(obj)
      if not obj or obj.code ~= 0 then
        failed = true
      else
        staged = M.parse(obj.stdout, git_root)
      end
      finish()
    end)
  end)
end

return M
