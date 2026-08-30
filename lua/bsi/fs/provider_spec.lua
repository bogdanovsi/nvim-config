local Provider = require("bsi.fs.provider")

local function mkdir(path)
  vim.fn.mkdir(path, "p")
end

local function touch(path)
  local fd, err = vim.uv.fs_open(path, "w", 420)
  assert(fd, err or ("open " .. path))
  vim.uv.fs_close(fd)
end

local function child_names(node)
  local names = {}
  for _, c in ipairs(node.children or {}) do
    names[#names + 1] = c.name
  end
  return names
end

local function child_name_set(node)
  local set = {}
  for _, c in ipairs(node.children or {}) do
    set[c.name] = c
  end
  return set
end

local function collect_files(node, acc)
  acc = acc or {}
  if node.type == "file" then
    acc[#acc + 1] = node.name
  end
  for _, c in ipairs(node.children or {}) do
    collect_files(c, acc)
  end
  return acc
end

local function count_files(node)
  return #collect_files(node)
end

describe("bsi.fs.provider", function()
  local tmp

  local function new_tmp()
    local dir = vim.fn.tempname()
    mkdir(dir)
    return dir
  end

  after_each(function()
    if tmp then
      vim.fn.delete(tmp, "rf")
      assert.is_nil(vim.loop.fs_stat(tmp))
      tmp = nil
    end
  end)

  it("creates and removes a temp fixture with no leftovers", function()
    tmp = new_tmp()
    touch(tmp .. "/keep.txt")
    assert.is_not_nil(vim.loop.fs_stat(tmp))
    vim.fn.delete(tmp, "rf")
    assert.is_nil(vim.loop.fs_stat(tmp))
    tmp = nil
  end)

  describe("ignore", function()
    before_each(function()
      tmp = new_tmp()
      for _, name in ipairs({ "node_modules", "vendor", "dist", "build", "target", ".git" }) do
        mkdir(tmp .. "/" .. name)
        touch(tmp .. "/" .. name .. "/inside.txt")
      end
      touch(tmp .. "/.env")
      touch(tmp .. "/keep.txt")
    end)

    it("hides heavy dirs and .git but keeps other dotfiles", function()
      local root = Provider.new():scan(tmp, 0, { show_ignored = false })
      local set = child_name_set(root)
      assert.is_nil(set["node_modules"])
      assert.is_nil(set["vendor"])
      assert.is_nil(set["dist"])
      assert.is_nil(set["build"])
      assert.is_nil(set["target"])
      assert.is_nil(set[".git"])
      assert.is_not_nil(set[".env"])
      assert.is_not_nil(set["keep.txt"])
    end)

    it("includes node_modules when show_ignored is true", function()
      local root = Provider.new():scan(tmp, 0, { show_ignored = true })
      local set = child_name_set(root)
      assert.is_not_nil(set["node_modules"])
      assert.is_not_nil(set[".git"])
    end)
  end)

  describe("bounded scan", function()
    before_each(function()
      tmp = new_tmp()
      touch(tmp .. "/file.txt")
      mkdir(tmp .. "/nested")
      touch(tmp .. "/nested/deep.txt")
      mkdir(tmp .. "/nested/deeper")
      touch(tmp .. "/nested/deeper/leaf.txt")
    end)

    it("one-level scan returns dir stubs without nested files", function()
      local root = Provider.new():scan(tmp, 0, {})
      local set = child_name_set(root)
      assert.is_not_nil(set["file.txt"])
      assert.is_not_nil(set["nested"])
      assert.equals("directory", set["nested"].type)
      assert.is_true(set["nested"]._unpopulated)
      assert.equals(0, #(set["nested"].children or {}))
      local files = collect_files(root)
      assert.are.same({ "file.txt" }, files)
    end)

    it("expand_all populates descendants", function()
      local root = Provider.new():scan(tmp, 0, { expand_all = true })
      local files = collect_files(root)
      table.sort(files)
      assert.are.same({ "deep.txt", "file.txt", "leaf.txt" }, files)
    end)
  end)

  describe("sort and collapse", function()
    it("sorts directories before files by case-insensitive name", function()
      tmp = new_tmp()
      touch(tmp .. "/a.txt")
      mkdir(tmp .. "/b")
      local root = Provider.new():scan(tmp, 0, {})
      local names = child_names(root)
      assert.are.same({ "b", "a.txt" }, names)
    end)

    it("collapses a single-child directory chain under expand_all", function()
      tmp = new_tmp()
      mkdir(tmp .. "/foo/bar")
      touch(tmp .. "/foo/bar/baz.txt")
      local root = Provider.new():scan(tmp, 0, { expand_all = true })
      assert.equals(1, #root.children)
      local collapsed = root.children[1]
      assert.equals("foo/bar", collapsed.name)
      assert.equals(1, #(collapsed.children or {}))
      assert.equals("baz.txt", collapsed.children[1].name)
      assert.equals("file", collapsed.children[1].type)
    end)
  end)

  describe("missing path and node shape", function()
    it("does not error on a missing path and returns no children", function()
      local missing = vim.fn.tempname() .. "-absent"
      local ok, root = pcall(function()
        return Provider.new():scan(missing, 0, {})
      end)
      assert.is_true(ok)
      assert.is_not_nil(root)
      assert.equals(0, #(root.children or {}))
    end)

    it("file nodes have no _icon", function()
      tmp = new_tmp()
      touch(tmp .. "/plain.txt")
      local root = Provider.new():scan(tmp, 0, {})
      local file = child_name_set(root)["plain.txt"]
      assert.is_not_nil(file)
      assert.equals("file", file.type)
      assert.is_nil(file._icon)
      assert.is_nil(file._icon_hl)
    end)
  end)

  describe("backends", function()
    local BACKENDS = { "lstat", "scandir", "readdir" }

    before_each(function()
      tmp = new_tmp()
      mkdir(tmp .. "/b")
      touch(tmp .. "/a.txt")
      touch(tmp .. "/.env")
      mkdir(tmp .. "/node_modules")
      touch(tmp .. "/node_modules/x.js")
    end)

    it("lstat, scandir (nvim-tree/snacks), and readdir (neo-tree) agree on children", function()
      local names = {}
      for _, backend in ipairs(BACKENDS) do
        local root = Provider.new():scan(tmp, 0, { backend = backend, show_ignored = false })
        names[backend] = child_names(root)
        local set = child_name_set(root)
        assert.is_nil(set["node_modules"])
        assert.is_not_nil(set["a.txt"])
        assert.is_not_nil(set["b"])
        assert.equals("directory", set["b"].type)
        assert.is_true(set["b"]._unpopulated)
        assert.is_not_nil(set[".env"])
        assert.equals("file", set["a.txt"].type)
        assert.is_nil(set["a.txt"]._icon)
      end
      assert.are.same(names.lstat, names.scandir)
      assert.are.same(names.lstat, names.readdir)
    end)
  end)

  describe("performance", function()
    local WIDE = 5000
    local IGNORED = 5000

    it("one-level scan of 5000 files finishes within 200ms with dir stubs only", function()
      tmp = new_tmp()
      for i = 1, WIDE do
        touch(string.format("%s/f%04d", tmp, i))
      end
      mkdir(tmp .. "/sub/nested")
      touch(tmp .. "/sub/nested/x.txt")

      local t0 = vim.uv.hrtime()
      local root = Provider.new():scan(tmp, 0, {})
      local elapsed_ms = (vim.uv.hrtime() - t0) / 1e6

      local files = 0
      local sub
      for _, c in ipairs(root.children) do
        if c.type == "file" then
          files = files + 1
        elseif c.name == "sub" then
          sub = c
        end
      end
      assert.equals(WIDE, files)
      assert.is_not_nil(sub)
      assert.is_true(sub._unpopulated)
      assert.equals(0, #(sub.children or {}))
      assert.is_true(elapsed_ms <= 200, string.format("scan took %.1f ms (budget 200)", elapsed_ms))
    end)

    it("skips a 5000-file node_modules tree and stays within 200ms", function()
      tmp = new_tmp()
      touch(tmp .. "/keep.txt")
      mkdir(tmp .. "/node_modules/pkg")
      for i = 1, IGNORED do
        touch(string.format("%s/node_modules/pkg/m%04d", tmp, i))
      end

      local t0 = vim.uv.hrtime()
      local root = Provider.new():scan(tmp, 0, { show_ignored = false })
      local elapsed_ms = (vim.uv.hrtime() - t0) / 1e6

      local set = child_name_set(root)
      assert.is_nil(set["node_modules"])
      assert.is_not_nil(set["keep.txt"])
      assert.equals(1, count_files(root))
      assert.is_true(elapsed_ms <= 200, string.format("scan took %.1f ms (budget 200)", elapsed_ms))
    end)

    it("compares lstat vs nvim-tree scandir vs neo-tree readdir on 5000 files", function()
      tmp = new_tmp()
      for i = 1, WIDE do
        touch(string.format("%s/f%04d", tmp, i))
      end
      mkdir(tmp .. "/sub/nested")
      touch(tmp .. "/sub/nested/x.txt")

      local times = {}
      local counts = {}
      for _, backend in ipairs({ "lstat", "scandir", "readdir" }) do
        local t0 = vim.uv.hrtime()
        local root = Provider.new():scan(tmp, 0, { backend = backend })
        times[backend] = (vim.uv.hrtime() - t0) / 1e6
        local files = 0
        local sub
        for _, c in ipairs(root.children) do
          if c.type == "file" then
            files = files + 1
          elseif c.name == "sub" then
            sub = c
          end
        end
        counts[backend] = files
        assert.is_not_nil(sub)
        assert.is_true(sub._unpopulated)
        assert.is_true(
          times[backend] <= 200,
          string.format("%s took %.1f ms (budget 200)", backend, times[backend])
        )
      end
      assert.equals(WIDE, counts.lstat)
      assert.equals(WIDE, counts.scandir)
      assert.equals(WIDE, counts.readdir)
      print(string.format(
        "scan backends (5000 files): lstat=%.2fms scandir=%.2fms readdir=%.2fms",
        times.lstat,
        times.scandir,
        times.readdir
      ))
    end)
  end)
end)
