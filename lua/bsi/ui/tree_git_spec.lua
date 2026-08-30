local tree_mod = require("bsi.ui.tree")
local numstat = require("bsi.git.numstat")

local function mkdir(path)
  vim.fn.mkdir(path, "p")
end

local function touch(path)
  mkdir(vim.fn.fnamemodify(path, ":h"))
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  vim.uv.fs_close(fd)
end

local function write_file(path, contents)
  mkdir(vim.fn.fnamemodify(path, ":h"))
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  vim.uv.fs_write(fd, contents, 0)
  vim.uv.fs_close(fd)
end

local function child_by_name(node, name)
  for _, c in ipairs(node.children or {}) do
    if c.name == name or c.name:match("^" .. name .. "/") then
      return c
    end
  end
end

local function silent_numstat()
  return {
    fetch_async = function(_, cb)
      cb(nil)
    end,
    format = numstat.format,
  }
end

describe("bsi.ui.tree gitignore and numstat", function()
  local tmp

  after_each(function()
    if tmp then
      vim.fn.delete(tmp, "rf")
      tmp = nil
    end
  end)

  local function fixture()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    write_file(tmp .. "/.gitignore", "secret.env\nbuild/\n")
    touch(tmp .. "/secret.env")
    touch(tmp .. "/keep.txt")
    mkdir(tmp .. "/build")
    touch(tmp .. "/build/inside.txt")
    mkdir(tmp .. "/node_modules/pkg")
    touch(tmp .. "/node_modules/pkg/x.js")
    mkdir(tmp .. "/src")
    touch(tmp .. "/src/a.ts")
    return tmp
  end

  it("marks secret.env git_ignored after Tree.new, expand, and refresh", function()
    fixture()
    local t = tree_mod.new({ root = tmp, numstat = silent_numstat() })
    local secret = child_by_name(t.state.root, "secret.env")
    assert.is_not_nil(secret)
    assert.is_true(secret.git_ignored)

    local src = child_by_name(t.state.root, "src")
    assert.is_not_nil(src)
    t:_load_directory(src)
    src.expanded = true
    assert.is_true(child_by_name(t.state.root, "secret.env").git_ignored)

    t:refresh()
    secret = child_by_name(t.state.root, "secret.env")
    assert.is_not_nil(secret)
    assert.is_true(secret.git_ignored)
  end)

  it("greys gitignored rows (arrow through name)", function()
    local renderer = tree_mod.Renderer.new()
    local built = renderer:build({
      {
        name = "secret.env",
        path = "/tmp/secret.env",
        type = "file",
        depth = 1,
        git_ignored = true,
        expanded = false,
      },
    })
    local found
    for _, hl in ipairs(built.highlights) do
      if hl.hl == "BSITreeGitIgnored" then
        found = hl
      end
    end
    assert.is_not_nil(found)
    assert.is_true(found.col_end > found.col_start)
    assert.is_nil((built.lines[1]):match("%+%d"))
  end)

  it("hides node_modules but lists grey secret.env when show_ignored is false", function()
    fixture()
    local t = tree_mod.new({ root = tmp, show_ignored = false, numstat = silent_numstat() })
    assert.is_nil(child_by_name(t.state.root, "node_modules"))
    local secret = child_by_name(t.state.root, "secret.env")
    assert.is_not_nil(secret)
    assert.is_true(secret.git_ignored)
    local built = tree_mod.Renderer.new():build({ secret })
    local grey = false
    for _, hl in ipairs(built.highlights) do
      if hl.hl == "BSITreeGitIgnored" then
        grey = true
      end
    end
    assert.is_true(grey)
  end)

  it("stamps numstat without a second scan", function()
    fixture()
    local scans = 0
    local t = tree_mod.new({ root = tmp, numstat = silent_numstat() })
    local orig = t.provider.scan
    t.provider.scan = function(self, ...)
      scans = scans + 1
      return orig(self, ...)
    end
    local keep = child_by_name(t.state.root, "keep.txt")
    local before = scans
    t:_stamp_numstat(t.state.root, { [keep.path] = { added = 23, deleted = 23 } })
    assert.equals(before, scans)
    assert.are.same({ added = 23, deleted = 23 }, keep.git_numstat)
  end)

  it("renders +23-23 with added and deleted highlights", function()
    local built = tree_mod.Renderer.new():build({
      {
        name = "keep.txt",
        path = "/tmp/keep.txt",
        type = "file",
        depth = 1,
        expanded = false,
        git_numstat = { added = 23, deleted = 23 },
      },
    })
    assert.is_not_nil(built.lines[1]:find(" +23-23", 1, true))
    local has_added, has_deleted = false, false
    for _, hl in ipairs(built.highlights) do
      if hl.hl == "BSITreeGitAdded" then
        has_added = true
      end
      if hl.hl == "BSITreeGitDeleted" then
        has_deleted = true
      end
    end
    assert.is_true(has_added)
    assert.is_true(has_deleted)
  end)

  it("skips +N-M on gitignored files and on non-repos", function()
    fixture()
    local t = tree_mod.new({ root = tmp, numstat = silent_numstat() })
    local secret = child_by_name(t.state.root, "secret.env")
    local keep = child_by_name(t.state.root, "keep.txt")
    t:_stamp_numstat(t.state.root, {
      [secret.path] = { added = 3, deleted = 1 },
      [keep.path] = { added = 2, deleted = 0 },
    })
    assert.is_true(secret.git_ignored)
    assert.is_nil(secret.git_numstat)
    assert.are.same({ added = 2, deleted = 0 }, keep.git_numstat)
    local ignored_line = tree_mod.Renderer.new():build({ secret }).lines[1]
    assert.is_nil(ignored_line:find(" +", 1, true))

    local t2 = tree_mod.new({ root = tmp, numstat = silent_numstat() })
    assert.is_not_nil(t2.state.root)
    assert.is_nil(child_by_name(t2.state.root, "keep.txt").git_numstat)
  end)

  it("ignores stale numstat callbacks after a newer refresh", function()
    fixture()
    local cbs = {}
    local t = tree_mod.new({
      root = tmp,
      numstat = {
        fetch_async = function(_, cb)
          cbs[#cbs + 1] = cb
        end,
        format = numstat.format,
      },
    })
    t:refresh()
    assert.is_true(#cbs >= 2)
    local keep = child_by_name(t.state.root, "keep.txt")
    local stale = { [keep.path] = { added = 1, deleted = 1 } }
    local fresh = { [keep.path] = { added = 9, deleted = 8 } }
    cbs[1](stale)
    assert.is_nil(keep.git_numstat)
    cbs[#cbs](fresh)
    keep = child_by_name(t.state.root, "keep.txt")
    assert.are.same({ added = 9, deleted = 8 }, keep.git_numstat)
  end)
end)
