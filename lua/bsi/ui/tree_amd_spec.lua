local tree_mod = require("bsi.ui.tree")
local amd = require("bsi.git.amd")
local numstat = require("bsi.git.numstat")

local function mkdir(path)
  vim.fn.mkdir(path, "p")
end

local function touch(path)
  mkdir(vim.fn.fnamemodify(path, ":h"))
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  vim.uv.fs_close(fd)
end

local function child_by_name(node, name)
  for _, c in ipairs(node.children or {}) do
    if c.name == name or c.name:match("^" .. name .. "/") then
      return c
    end
  end
end

local function silent_git()
  return {
    numstat = {
      fetch_async = function(_, cb)
        cb(nil)
      end,
      format = numstat.format,
    },
    amd = {
      fetch_async = function(_, cb)
        cb(nil)
      end,
      stamp = amd.stamp,
      xy_to_letter = amd.xy_to_letter,
    },
  }
end

describe("bsi.ui.tree AMD postfix", function()
  local tmp

  after_each(function()
    if tmp then
      vim.fn.delete(tmp, "rf")
      tmp = nil
    end
  end)

  it("renders +23-23 then M with added/deleted/modified highlights", function()
    local built = tree_mod.Renderer.new():build({
      {
        name = "keep.txt",
        path = "/tmp/keep.txt",
        type = "file",
        depth = 1,
        expanded = false,
        git_numstat = { added = 23, deleted = 23 },
        git_letter = "M",
      },
    })
    assert.is_not_nil(built.lines[1]:find(" +23-23 M", 1, true))
    local has = {}
    for _, hl in ipairs(built.highlights) do
      has[hl.hl] = true
    end
    assert.is_true(has.BSITreeGitAdded)
    assert.is_true(has.BSITreeGitDeleted)
    assert.is_true(has.BSITreeGitModified)
  end)

  it("renders directory MA after the name when files inside are added and modified", function()
    local built = tree_mod.Renderer.new():build({
      {
        name = "pkg",
        path = "/tmp/pkg",
        type = "directory",
        depth = 1,
        expanded = false,
        children = {},
        git_status_summary = "MA",
      },
    })
    assert.is_not_nil(built.lines[1]:find(" MA", 1, true))
    local hls = {}
    for _, hl in ipairs(built.highlights) do
      if hl.hl == "BSITreeGitModified" or hl.hl == "BSITreeGitAdded" then
        hls[#hls + 1] = hl.hl
      end
    end
    assert.are.same({ "BSITreeGitModified", "BSITreeGitAdded" }, hls)
  end)

  it("renders directory DMA with per-letter highlights and skips gitignored dirs", function()
    local built = tree_mod.Renderer.new():build({
      {
        name = "src",
        path = "/tmp/src",
        type = "directory",
        depth = 1,
        expanded = false,
        children = {},
        git_status_summary = "DMA",
      },
      {
        name = "skip",
        path = "/tmp/skip",
        type = "directory",
        depth = 1,
        expanded = false,
        children = {},
        git_ignored = true,
        git_status_summary = "DMA",
      },
    })
    assert.is_not_nil(built.lines[1]:find(" DMA", 1, true))
    local dma_hls = {}
    for _, hl in ipairs(built.highlights) do
      if hl.line == 0 and (hl.hl == "BSITreeGitDeleted" or hl.hl == "BSITreeGitModified" or hl.hl == "BSITreeGitAdded") then
        dma_hls[#dma_hls + 1] = hl.hl
      end
    end
    assert.are.same({ "BSITreeGitDeleted", "BSITreeGitModified", "BSITreeGitAdded" }, dma_hls)
    assert.is_nil(built.lines[2]:find("DMA", 1, true))
  end)

  it("stamps AMD from a stubbed fetch without a second scan", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    touch(tmp .. "/keep.txt")
    mkdir(tmp .. "/src/app")
    touch(tmp .. "/src/other.ts")
    touch(tmp .. "/src/app/a.ts")
    local stubs = silent_git()
    local t = tree_mod.new({ root = tmp, numstat = stubs.numstat, amd = stubs.amd })
    local scans = 0
    local orig = t.provider.scan
    t.provider.scan = function(self, ...)
      scans = scans + 1
      return orig(self, ...)
    end
    local src = child_by_name(t.state.root, "src")
    t:_load_directory(src)
    local app = child_by_name(src, "app")
    t:_load_directory(app)
    local before = scans
    local keep = child_by_name(t.state.root, "keep.txt")
    local file = child_by_name(app, "a.ts")
    t._amd.stamp(t.state.root, {
      [keep.path] = "M ",
      [file.path] = "M ",
    })
    assert.equals(before, scans)
    assert.equals("M", keep.git_letter)
    assert.equals("M", file.git_letter)
    assert.equals("M", app.git_status_summary)
    assert.equals("M", src.git_status_summary)
  end)

  it("drops stale AMD callbacks after refresh", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    touch(tmp .. "/keep.txt")
    local cbs = {}
    local t = tree_mod.new({
      root = tmp,
      numstat = silent_git().numstat,
      amd = {
        fetch_async = function(_, cb)
          cbs[#cbs + 1] = cb
        end,
        stamp = amd.stamp,
      },
    })
    t:refresh()
    assert.is_true(#cbs >= 2)
    local keep = child_by_name(t.state.root, "keep.txt")
    cbs[1]({ [keep.path] = "A " })
    assert.is_nil(keep.git_letter)
    cbs[#cbs]({ [keep.path] = "M " })
    keep = child_by_name(t.state.root, "keep.txt")
    assert.equals("M", keep.git_letter)
  end)

  it("non-repo listing succeeds with no AMD postfix", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    touch(tmp .. "/keep.txt")
    assert.is_nil(vim.loop.fs_stat(tmp .. "/.git"))
    local t = tree_mod.new({ root = tmp, numstat = silent_git().numstat, amd = silent_git().amd })
    local keep = child_by_name(t.state.root, "keep.txt")
    assert.is_not_nil(keep)
    assert.is_nil(keep.git_letter)
    assert.is_nil(t.state.root.git_status_summary)
  end)
end)
