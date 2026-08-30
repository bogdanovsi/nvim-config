local create = require("bsi.fs.create")

local function mkdir(path)
  vim.fn.mkdir(path, "p")
end

local function read_file(path)
  local fd = io.open(path, "rb")
  if not fd then
    return nil
  end
  local data = fd:read("*a")
  fd:close()
  return data
end

local function write_file(path, contents)
  mkdir(vim.fn.fnamemodify(path, ":h"))
  local fd = assert(io.open(path, "w"))
  fd:write(contents)
  fd:close()
end

describe("bsi.fs.create", function()
  local tmp

  after_each(function()
    if tmp then
      vim.fn.delete(tmp, "rf")
      assert.is_nil(vim.loop.fs_stat(tmp))
      tmp = nil
    end
  end)

  it("creates and removes a temp root with no leftovers", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    write_file(tmp .. "/keep.txt", "x")
    assert.is_not_nil(vim.loop.fs_stat(tmp))
    vim.fn.delete(tmp, "rf")
    assert.is_nil(vim.loop.fs_stat(tmp))
    tmp = nil
  end)

  it("creates nested parents and an empty file", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    local result = create(tmp, "src/app1/app/index.tsx")
    assert.is_true(result.ok)
    assert.equals("file", result.kind)
    local path = tmp .. "/src/app1/app/index.tsx"
    assert.equals(vim.fs.normalize(path), result.path)
    local stat = vim.loop.fs_stat(path)
    assert.is_not_nil(stat)
    assert.equals("file", stat.type)
    assert.equals(0, stat.size)
    assert.equals(1, vim.fn.isdirectory(tmp .. "/src/app1/app"))
  end)

  it("trailing slash creates a directory only", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    local result = create(tmp, "src/app1/hooks/")
    assert.is_true(result.ok)
    assert.equals("dir", result.kind)
    local dir = tmp .. "/src/app1/hooks"
    assert.equals(1, vim.fn.isdirectory(dir))
    assert.is_nil(vim.loop.fs_stat(dir .. "/hooks"))
    assert.are.not_equal("file", (vim.loop.fs_stat(dir) or {}).type)
  end)

  it("empty input is a no-op", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    local result = create(tmp, "")
    assert.is_true(result.ok)
    assert.equals("empty", result.kind)
    assert.is_nil(result.path)
    assert.equals(0, vim.fn.filereadable(tmp .. "/"))
  end)

  it("does not overwrite an existing file", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    write_file(tmp .. "/src/app/index.tsx", "keep-me")
    local result = create(tmp, "src/app/index.tsx")
    assert.is_false(result.ok)
    assert.equals("exists", result.kind)
    assert.equals("keep-me", read_file(tmp .. "/src/app/index.tsx"))
  end)

  it("creates at an absolute path with missing parents", function()
    tmp = vim.fn.tempname()
    local dest = tmp .. "/example/foo.txt"
    local result = create("/unused-root", dest)
    assert.is_true(result.ok)
    assert.equals("file", result.kind)
    assert.is_not_nil(vim.loop.fs_stat(dest))
    assert.equals(0, vim.loop.fs_stat(dest).size)
  end)

  it("default_path for a file's parent is tree-relative with a slash", function()
    local root = "/proj"
    local file_parent = "/proj/src/app"
    assert.equals("src/app/", create.default_path(root, file_parent))
    assert.equals("", create.default_path(root, root))
  end)
end)
