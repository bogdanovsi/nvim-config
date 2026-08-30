local prune = require("bsi.fs.prune")

local function mkdir(path)
  vim.fn.mkdir(path, "p")
end

local function write_file(path, contents)
  mkdir(vim.fn.fnamemodify(path, ":h"))
  local fd = assert(io.open(path, "w"))
  fd:write(contents or "")
  fd:close()
end

describe("bsi.fs.prune", function()
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
    mkdir(tmp .. "/a")
    assert.is_not_nil(vim.loop.fs_stat(tmp))
    vim.fn.delete(tmp, "rf")
    assert.is_nil(vim.loop.fs_stat(tmp))
    tmp = nil
  end)

  it("removes empty app and app1 but keeps src when src has another file", function()
    tmp = vim.fn.tempname()
    write_file(tmp .. "/src/app1/app/index.tsx", "x")
    write_file(tmp .. "/src/keep.ts", "y")
    vim.fn.delete(tmp .. "/src/app1/app/index.tsx")
    local result = prune(tmp, tmp .. "/src/app1/app")
    assert.is_nil(vim.loop.fs_stat(tmp .. "/src/app1/app"))
    assert.is_nil(vim.loop.fs_stat(tmp .. "/src/app1"))
    assert.equals(1, vim.fn.isdirectory(tmp .. "/src"))
    assert.is_not_nil(vim.loop.fs_stat(tmp .. "/src/keep.ts"))
    assert.is_not_nil(vim.loop.fs_stat(tmp))
    assert.is_true(#result.removed >= 2)
  end)

  it("sibling file blocks prune", function()
    tmp = vim.fn.tempname()
    write_file(tmp .. "/src/app1/app/index.tsx", "x")
    write_file(tmp .. "/src/app1/app/util.ts", "y")
    vim.fn.delete(tmp .. "/src/app1/app/index.tsx")
    prune(tmp, tmp .. "/src/app1/app")
    assert.equals(1, vim.fn.isdirectory(tmp .. "/src/app1/app"))
    assert.is_not_nil(vim.loop.fs_stat(tmp .. "/src/app1/app/util.ts"))
  end)

  it("gitkeep blocks prune", function()
    tmp = vim.fn.tempname()
    write_file(tmp .. "/src/empty/.gitkeep", "")
    prune(tmp, tmp .. "/src/empty")
    assert.equals(1, vim.fn.isdirectory(tmp .. "/src/empty"))
    assert.is_not_nil(vim.loop.fs_stat(tmp .. "/src/empty/.gitkeep"))
  end)

  it("removes an empty nested chain and keeps root", function()
    tmp = vim.fn.tempname()
    mkdir(tmp .. "/src/app1/app/hooks")
    write_file(tmp .. "/src/keep.ts", "z")
    local result = prune(tmp, tmp .. "/src/app1/app/hooks")
    assert.is_nil(vim.loop.fs_stat(tmp .. "/src/app1/app/hooks"))
    assert.is_nil(vim.loop.fs_stat(tmp .. "/src/app1/app"))
    assert.is_nil(vim.loop.fs_stat(tmp .. "/src/app1"))
    assert.equals(1, vim.fn.isdirectory(tmp .. "/src"))
    assert.is_not_nil(vim.loop.fs_stat(tmp))
    assert.is_true(#result.removed >= 3)
  end)

  it("never deletes the tree root", function()
    tmp = vim.fn.tempname()
    mkdir(tmp)
    prune(tmp, tmp)
    assert.equals(1, vim.fn.isdirectory(tmp))
  end)
end)
