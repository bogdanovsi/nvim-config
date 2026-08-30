-- lua/bsi/git/amd.lua
-- Map porcelain XY to A/M/D, fetch light git status (no --ignored=matching), stamp the tree.

local status = require("bsi.git.status")

local M = {}

--- Light porcelain: no --ignored=matching, no forced -u.
--- Newline records (`XY path`), not `-z` (`XY path\0` as one field — easy to mis-parse).
M.STATUS_CMD = { "git", "--no-optional-locks", "status", "--porcelain=v1" }

local function norm_path(p)
  if not p or p == "" then
    return p
  end
  p = vim.fn.fnamemodify(p, ":p")
  p = vim.fn.resolve(p)
  return p:gsub("/+$", "")
end

--- Parse `git status --porcelain=v1` (newline) or `-z` (NUL) into abs_path -> XY.
---@param stdout string|nil
---@param git_root string
---@return table<string, string>
function M.parse_status(stdout, git_root)
  local out = {}
  if not stdout or stdout == "" or not git_root then
    return out
  end
  git_root = git_root:gsub("/+$", "")

  local function add(xy, rel)
    if not xy or not rel or rel == "" then
      return
    end
    local dest = rel:match(" -> (.+)$")
    if dest then
      rel = dest
    end
    rel = rel:gsub("^/+", ""):gsub("/+$", "")
    local abs = norm_path(git_root .. "/" .. rel)
    out[abs] = xy
    out[git_root .. "/" .. rel] = xy
  end

  if stdout:find("\0", 1, true) then
    local entries = {}
    for e in vim.gsplit(stdout, "\0", { plain = true, trimempty = true }) do
      entries[#entries + 1] = e
    end
    local i = 1
    while i <= #entries do
      local e = entries[i]
      local xy, path = e:match("^(..) (.*)$")
      if xy and path then
        if (xy:sub(1, 1) == "R" or xy:sub(1, 1) == "C") and entries[i + 1] and not entries[i + 1]:match("^(..) ") then
          i = i + 1
          add(xy, entries[i])
        else
          add(xy, path)
        end
      end
      i = i + 1
    end
    return out
  end

  for line in stdout:gmatch("[^\r\n]+") do
    local xy, path = line:match("^(..) (.*)$")
    if xy and path then
      add(xy, path)
    end
  end
  return out
end

local function letter_of_char(ch)
  if ch == "?" or ch == "A" then
    return "A"
  end
  if ch == "M" or ch == "R" or ch == "C" then
    return "M"
  end
  if ch == "D" then
    return "D"
  end
  return nil
end

--- Map porcelain XY to a single A/M/D. Prefer D, then M, then A.
---@param xy string|nil
---@return string|nil
function M.xy_to_letter(xy)
  if not xy or xy == "" then
    return nil
  end
  local rank = { D = 3, M = 2, A = 1 }
  local best, best_rank = nil, 0
  local function consider(L)
    if L and rank[L] > best_rank then
      best, best_rank = L, rank[L]
    end
  end
  consider(letter_of_char(xy:sub(1, 1)))
  consider(letter_of_char(xy:sub(2, 2)))
  return best
end

local function covered_by_child(node, path)
  for _, c in ipairs(node.children or {}) do
    if path == c.path then
      return true
    end
    if c.type ~= "file" and path:sub(1, #c.path + 1) == c.path .. "/" then
      return true
    end
  end
  return false
end

--- Stamp git_letter on files and git_status_summary on dirs. Does not insert nodes.
---@param root table
---@param map table<string, string>|nil abs_path -> XY
function M.stamp(root, map)
  map = map or {}
  local idx = {}
  for p, xy in pairs(map) do
    idx[p] = xy
    idx[norm_path(p)] = xy
  end

  local function xy_of(path)
    if not path then
      return nil
    end
    return idx[path] or idx[norm_path(path)] or idx[path .. "/"]
  end

  local function walk(node)
    if node.type == "file" then
      if node.git_ignored then
        node.git_letter = nil
      else
        local xy = xy_of(node.path)
        node.git_letter = xy and M.xy_to_letter(xy) or nil
      end
      return
    end

    for _, child in ipairs(node.children or {}) do
      walk(child)
    end

    if node.git_ignored then
      node.git_status_summary = nil
      return
    end

    local child_statuses = {}
    local child_summaries = {}
    for _, c in ipairs(node.children or {}) do
      if c.type == "file" and c.git_letter then
        child_statuses[#child_statuses + 1] = c.git_letter
      elseif c.git_status_summary and c.git_status_summary ~= "" then
        child_summaries[#child_summaries + 1] = c.git_status_summary
      end
    end

    -- Porcelain on the directory itself (e.g. untracked `?? dir/`) counts as its letter.
    local self_xy = xy_of(node.path)
    if self_xy then
      local letter = M.xy_to_letter(self_xy)
      if letter then
        child_statuses[#child_statuses + 1] = letter
      end
    end

    local npath = norm_path(node.path)
    local prefix = npath .. "/"
    local raw_prefix = node.path .. "/"
    for p, xy in pairs(map) do
      local np = norm_path(p)
      local under = (np:sub(1, #prefix) == prefix) or (p:sub(1, #raw_prefix) == raw_prefix)
      if under and np ~= npath and not covered_by_child(node, p) and not covered_by_child(node, np) then
        local letter = M.xy_to_letter(xy)
        if letter then
          child_statuses[#child_statuses + 1] = letter
        end
      end
    end

    local synth = status.compute_dir_git_status(child_statuses, child_summaries)
    node.git_status_summary = synth.git_status_summary
  end

  walk(root)
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

--- Async porcelain map abs_path -> XY, or nil.
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

    vim.schedule(function()
      vim.system(M.STATUS_CMD, {
        cwd = git_root,
        text = true,
        timeout = 8000,
      }, function(obj)
        if not obj or obj.code ~= 0 then
          vim.schedule(function()
            done(nil)
          end)
          return
        end
        local map = M.parse_status(obj.stdout or "", git_root)
        vim.schedule(function()
          done(map)
        end)
      end)
    end)
  end)
end

return M
