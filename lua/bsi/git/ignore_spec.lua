local Provider = require("bsi.fs.provider")
local ignore = require("bsi.git.ignore")

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

local function scan_annotate(path, opts)
  local root = Provider.new():scan(path, 0, opts or {})
  ignore.annotate(root)
  return root
end

describe("bsi.git.ignore", function()
  local tmp

  local function new_tmp()
    local dir = vim.fn.tempname()
    mkdir(dir)
    return dir
  end

  after_each(function()
    if tmp then
      vim.fn.delete(tmp, "rf")
      tmp = nil
    end
  end)

  it("loads as a module", function()
    assert.equals("function", type(ignore.annotate))
  end)

  it("marks *.log from a root gitignore", function()
    tmp = new_tmp()
    write_file(tmp .. "/.gitignore", "*.log\n")
    touch(tmp .. "/debug.log")
    touch(tmp .. "/keep.txt")
    local root = scan_annotate(tmp)
    local log = child_by_name(root, "debug.log")
    local keep = child_by_name(root, "keep.txt")
    local gi = child_by_name(root, ".gitignore")
    assert.is_not_nil(log)
    assert.is_true(log.git_ignored)
    assert.is_not_nil(keep)
    assert.is_false(keep.git_ignored)
    assert.is_not_nil(gi)
    assert.is_false(gi.git_ignored)
  end)

  it("leaves files unmarked when there is no gitignore", function()
    tmp = new_tmp()
    touch(tmp .. "/debug.log")
    local root = scan_annotate(tmp)
    local log = child_by_name(root, "debug.log")
    assert.is_not_nil(log)
    assert.is_false(log.git_ignored)
  end)

  it("works in a temp dir that is not a git repository", function()
    tmp = new_tmp()
    assert.is_nil(vim.loop.fs_stat(tmp .. "/.git"))
    write_file(tmp .. "/.gitignore", "secret.env\n")
    touch(tmp .. "/secret.env")
    local root = scan_annotate(tmp)
    local secret = child_by_name(root, "secret.env")
    assert.is_not_nil(secret)
    assert.is_true(secret.git_ignored)
  end)

  it("applies a nested pkg/.gitignore to dist/", function()
    tmp = new_tmp()
    write_file(tmp .. "/.gitignore", "\n")
    write_file(tmp .. "/pkg/.gitignore", "dist/\n")
    mkdir(tmp .. "/pkg/dist")
    touch(tmp .. "/pkg/keep.txt")
    local root = scan_annotate(tmp, { show_ignored = true })
    local pkg = child_by_name(root, "pkg")
    assert.is_not_nil(pkg)
    local scanned = Provider.new():scan(pkg.path, pkg.depth, { show_ignored = true })
    pkg.children = scanned.children
    pkg._unpopulated = false
    ignore.annotate(root)
    local dist = child_by_name(pkg, "dist")
    local keep = child_by_name(pkg, "keep.txt")
    assert.is_not_nil(dist)
    assert.is_true(dist.git_ignored)
    assert.is_not_nil(keep)
    assert.is_false(keep.git_ignored)
  end)

  it("negation un-ignores keep.log after *.log", function()
    tmp = new_tmp()
    write_file(tmp .. "/.gitignore", "*.log\n!keep.log\n")
    touch(tmp .. "/debug.log")
    touch(tmp .. "/keep.log")
    local root = scan_annotate(tmp)
    assert.is_true(child_by_name(root, "debug.log").git_ignored)
    assert.is_false(child_by_name(root, "keep.log").git_ignored)
  end)

  it("marks a one-level build/ stub without listing its files", function()
    tmp = new_tmp()
    write_file(tmp .. "/.gitignore", "build/\n")
    mkdir(tmp .. "/build")
    touch(tmp .. "/build/inside.txt")
    touch(tmp .. "/keep.txt")
    local root = scan_annotate(tmp, { show_ignored = true })
    local build = child_by_name(root, "build")
    assert.is_not_nil(build)
    assert.is_true(build.git_ignored)
    assert.is_true(build._unpopulated)
    assert.equals(0, #(build.children or {}))
  end)

  describe("performance", function()
    local WIDE = 5000
    local IGNORED = 5000

    it("scan plus annotate of 5000 files stays within 200ms", function()
      tmp = new_tmp()
      write_file(tmp .. "/.gitignore", "f0001\n")
      for i = 1, WIDE do
        touch(string.format("%s/f%04d", tmp, i))
      end
      local t0 = vim.uv.hrtime()
      local root = scan_annotate(tmp)
      local elapsed_ms = (vim.uv.hrtime() - t0) / 1e6
      local files = 0
      local marked
      for _, c in ipairs(root.children) do
        if c.type == "file" and c.name ~= ".gitignore" then
          files = files + 1
        end
        if c.name == "f0001" then
          marked = c
        end
      end
      assert.equals(WIDE, files)
      assert.is_not_nil(marked)
      assert.is_true(marked.git_ignored)
      assert.is_true(elapsed_ms <= 200, string.format("scan+annotate took %.1f ms (budget 200)", elapsed_ms))
    end)

    it("hidden node_modules of 5000 files stays absent and within 200ms", function()
      tmp = new_tmp()
      write_file(tmp .. "/.gitignore", "secret.env\n")
      touch(tmp .. "/keep.txt")
      touch(tmp .. "/secret.env")
      mkdir(tmp .. "/node_modules/pkg")
      for i = 1, IGNORED do
        touch(string.format("%s/node_modules/pkg/m%04d", tmp, i))
      end
      local t0 = vim.uv.hrtime()
      local root = scan_annotate(tmp, { show_ignored = false })
      local elapsed_ms = (vim.uv.hrtime() - t0) / 1e6
      assert.is_nil(child_by_name(root, "node_modules"))
      assert.is_not_nil(child_by_name(root, "keep.txt"))
      assert.is_true(child_by_name(root, "secret.env").git_ignored)
      assert.is_true(elapsed_ms <= 200, string.format("scan+annotate took %.1f ms (budget 200)", elapsed_ms))
    end)
  end)
end)
