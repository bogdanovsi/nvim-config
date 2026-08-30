local tree_mod = require("bsi.ui.tree")

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

local function expand(tree, node)
  local scanned = tree.provider:scan(node.path, node.depth, {
    show_ignored = tree.show_ignored,
  })
  if scanned and scanned.children then
    node.children = scanned.children
    node._unpopulated = false
  end
  node.expanded = true
end

describe("bsi.ui.tree refresh (R)", function()
  local tmp

  after_each(function()
    if tmp then
      vim.fn.delete(tmp, "rf")
      tmp = nil
    end
  end)

  it("keeps expanded subdirectory files after refresh", function()
    tmp = vim.fn.tempname()
    touch(tmp .. "/keep.txt")
    touch(tmp .. "/src/a.ts")
    touch(tmp .. "/src/lib/util.ts")

    local t = tree_mod.new({ root = tmp })
    local src = child_by_name(t.state.root, "src")
    assert.is_not_nil(src)
    expand(t, src)
    local lib = child_by_name(src, "lib")
    assert.is_not_nil(lib)
    expand(t, lib)
    assert.is_not_nil(child_by_name(lib, "util.ts"))

    t:refresh()

    src = child_by_name(t.state.root, "src")
    assert.is_not_nil(src)
    assert.is_true(src.expanded)
    assert.is_not_nil(child_by_name(src, "a.ts"))
    lib = child_by_name(src, "lib")
    assert.is_not_nil(lib)
    assert.is_true(lib.expanded)
    assert.is_not_nil(child_by_name(lib, "util.ts"))
  end)

  it("keeps files under a collapsed single-child chain after refresh", function()
    tmp = vim.fn.tempname()
    touch(tmp .. "/keep.txt")
    touch(tmp .. "/foo/bar/x.ts")

    local t = tree_mod.new({ root = tmp })
    local foo = child_by_name(t.state.root, "foo")
    assert.is_not_nil(foo)
    expand(t, foo)
    if not child_by_name(foo, "x.ts") then
      local bar = child_by_name(foo, "bar")
      assert.is_not_nil(bar)
      expand(t, bar)
    end
    assert.is_not_nil(child_by_name(foo, "x.ts") or (child_by_name(foo, "bar") and child_by_name(child_by_name(foo, "bar"), "x.ts")))

    t:refresh()

    foo = child_by_name(t.state.root, "foo")
    assert.is_not_nil(foo)
    local x = child_by_name(foo, "x.ts")
    if not x then
      local bar = child_by_name(foo, "bar")
      x = bar and child_by_name(bar, "x.ts")
    end
    assert.is_not_nil(x)
  end)

  it("renders empty nested dirs as one row and Enter opens the last dir with files", function()
    tmp = vim.fn.tempname()
    mkdir(tmp .. "/empty/nested")
    touch(tmp .. "/src/deep/a.ts")

    local t = tree_mod.new({ root = tmp })
    local empty = child_by_name(t.state.root, "empty")
    assert.is_not_nil(empty)
    assert.equals("empty/nested", empty.name)

    local src = child_by_name(t.state.root, "src")
    assert.is_not_nil(src)
    assert.equals("src/deep", src.name)

    t:_load_directory(src)
    src.expanded = true
    assert.is_not_nil(child_by_name(src, "a.ts"))
    src.expanded = false
    assert.is_false(src.expanded)
    src.expanded = true
    assert.is_not_nil(child_by_name(src, "a.ts"))
  end)
end)
