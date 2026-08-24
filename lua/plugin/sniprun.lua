local sr = require("sniprun")

sr.setup({
  display = {
    "Classic",
    "VirtualTextOk",
    "NvimNotify",
  },
})

-- Upstream :SnipInfo waits a fixed 500ms then io.open()s infofile.txt
-- with no nil check. The binary also shells out to git for a version
-- check (~700ms), so the first call always races and crashes:
--   attempt to index local 'file' (a nil value)
-- Poll until the file is rewritten instead.

local function infofile_paths()
  local home = vim.env.HOME or vim.fn.expand("~")
  local paths = {
    home .. "/Library/Caches/sniprun/infofile.txt",
    home .. "/.cache/sniprun/infofile.txt",
  }
  local xdg = vim.env.XDG_CACHE_HOME
  if xdg and xdg ~= "" then
    table.insert(paths, 1, xdg .. "/sniprun/infofile.txt")
  end
  return paths
end

local function newest_infofile()
  local best
  for _, path in ipairs(infofile_paths()) do
    local stat = vim.uv.fs_stat(path)
    if stat and stat.size > 0 then
      local stamp = stat.mtime.sec * 1e9 + stat.mtime.nsec
      if not best or stamp > best.stamp then
        best = { path = path, stamp = stamp, size = stat.size }
      end
    end
  end
  return best
end

local function read_lines(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()
  return lines
end

function sr.info(arg)
  if arg ~= nil and arg ~= "" then
    local name = string.gsub(arg, "%s+", "")
    local path = sr.config_values.sniprun_path .. "/doc/sources/interpreters/" .. name .. ".md"
    local lines = read_lines(path)
    if not lines then
      vim.notify("sniprun: no docs for interpreter '" .. name .. "'", vim.log.levels.WARN)
      return
    end
    sr.display_lines_in_floating_win(lines)
    return
  end

  local prev = newest_infofile()
  local prev_key = prev and (prev.path .. prev.stamp .. prev.size)

  sr.config_values["sniprun_root_dir"] = sr.config_values.sniprun_path
  sr.notify("info", 1, 1, sr.config_values, "")

  local found
  vim.wait(4000, function()
    local cur = newest_infofile()
    if not cur then
      return false
    end
    local key = cur.path .. cur.stamp .. cur.size
    if prev_key and key == prev_key then
      return false
    end
    found = cur.path
    return true
  end, 30)

  local lines = found and read_lines(found)
  if not lines then
    vim.notify("sniprun: timed out waiting for infofile (is the binary running?)", vim.log.levels.ERROR)
    return
  end
  sr.display_lines_in_floating_win(lines)
end

-- Warm the RPC job so the first :SnipInfo / :SnipRun is not also paying startup.
pcall(sr.start)

-- <Plug> maps must be recursive
vim.keymap.set({ "n", "v" }, "<leader>rr", "<Plug>SnipRun", { silent = true, remap = true, desc = "SnipRun" })
vim.keymap.set("n", "<leader>rR", "<Plug>SnipRunOperator", { silent = true, remap = true, desc = "SnipRun operator" })
vim.keymap.set("n", "<leader>rc", "<Plug>SnipClose", { silent = true, remap = true, desc = "SnipRun close" })
vim.keymap.set("n", "<leader>rx", "<Plug>SnipReset", { silent = true, remap = true, desc = "SnipRun reset" })
