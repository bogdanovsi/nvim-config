local amd = require("bsi.git.amd")

describe("bsi.git.amd", function()
  it("maps porcelain XY to A/M/D with D then M then A", function()
    assert.equals("A", amd.xy_to_letter("??"))
    assert.equals("M", amd.xy_to_letter("M "))
    assert.equals("D", amd.xy_to_letter(" D"))
    assert.equals("D", amd.xy_to_letter("AD"))
    assert.equals("M", amd.xy_to_letter("R "))
    assert.equals("A", amd.xy_to_letter("A "))
    assert.equals("M", amd.xy_to_letter("C "))
    assert.is_nil(amd.xy_to_letter(nil))
    assert.is_nil(amd.xy_to_letter("  "))
  end)

  it("STATUS_CMD is porcelain without --ignored=matching", function()
    local joined = table.concat(amd.STATUS_CMD, " ")
    assert.is_not_nil(joined:find("porcelain", 1, true))
    assert.is_nil(joined:find("--ignored=matching", 1, true))
    assert.is_nil(joined:find(" --ignored", 1, true))
  end)

  it("parses newline porcelain XY path records", function()
    local stdout = " M lua/bsi/ui/tree.lua\n?? lua/bsi/git/amd.lua\nA  pkg/new.ts\n"
    local map = amd.parse_status(stdout, "/repo")
    assert.equals(" M", map["/repo/lua/bsi/ui/tree.lua"] or map[vim.fn.fnamemodify("/repo/lua/bsi/ui/tree.lua", ":p"):gsub("/+$", "")])
    local tree = map["/repo/lua/bsi/ui/tree.lua"]
    local amd_path = map["/repo/lua/bsi/git/amd.lua"]
    -- :p may prefix cwd; also accept keys that end with the rel path
    local function letter_for(suffix)
      for p, xy in pairs(map) do
        if p:sub(-#suffix) == suffix then
          return amd.xy_to_letter(xy)
        end
      end
    end
    assert.equals("M", letter_for("lua/bsi/ui/tree.lua") or amd.xy_to_letter(tree))
    assert.equals("A", letter_for("lua/bsi/git/amd.lua") or amd.xy_to_letter(amd_path))
    assert.equals("A", letter_for("pkg/new.ts"))
  end)

  it("parses git -z records where XY and path share one NUL field", function()
    local stdout = " M lua/a.lua\0?? lua/b.lua\0"
    local map = amd.parse_status(stdout, "/repo")
    local function letter_for(suffix)
      for p, xy in pairs(map) do
        if p:sub(-#suffix) == suffix then
          return amd.xy_to_letter(xy)
        end
      end
    end
    assert.equals("M", letter_for("lua/a.lua"))
    assert.equals("A", letter_for("lua/b.lua"))
  end)

  it("stamps M on a modified file and skips gitignored files", function()
    local keep = { type = "file", name = "keep.txt", path = "/repo/keep.txt" }
    local secret = { type = "file", name = "secret.env", path = "/repo/secret.env", git_ignored = true }
    local root = {
      type = "root",
      name = "repo",
      path = "/repo",
      children = { keep, secret },
    }
    amd.stamp(root, {
      ["/repo/keep.txt"] = "M ",
      ["/repo/secret.env"] = "M ",
    })
    assert.equals("M", keep.git_letter)
    assert.is_nil(secret.git_letter)
  end)

  it("aggregates mixed children to DMA and deleted-only missing files to D", function()
    local a = { type = "file", name = "a.txt", path = "/repo/a.txt" }
    local m = { type = "file", name = "m.txt", path = "/repo/m.txt" }
    local listed_d = { type = "file", name = "d.txt", path = "/repo/d.txt" }
    local root = {
      type = "root",
      name = "repo",
      path = "/repo",
      children = { a, m, listed_d },
    }
    amd.stamp(root, {
      ["/repo/a.txt"] = "??",
      ["/repo/m.txt"] = "M ",
      ["/repo/d.txt"] = "D ",
    })
    assert.equals("DMA", root.git_status_summary)

    local parent = {
      type = "directory",
      name = "src",
      path = "/repo/src",
      children = {},
      _unpopulated = true,
    }
    local tree = { type = "root", name = "repo", path = "/repo", children = { parent } }
    amd.stamp(tree, { ["/repo/src/gone.lua"] = "D " })
    assert.equals("D", parent.git_status_summary)
    assert.equals("D", tree.git_status_summary)
    assert.equals(0, #(parent.children or {}))
  end)

  it("postfixes a directory with MA when children are added and modified", function()
    local a1 = { type = "file", name = "a1.ts", path = "/repo/pkg/a1.ts" }
    local a2 = { type = "file", name = "a2.ts", path = "/repo/pkg/a2.ts" }
    local m1 = { type = "file", name = "m1.ts", path = "/repo/pkg/m1.ts" }
    local pkg = {
      type = "directory",
      name = "pkg",
      path = "/repo/pkg",
      children = { a1, a2, m1 },
    }
    local root = { type = "root", name = "repo", path = "/repo", children = { pkg } }
    amd.stamp(root, {
      ["/repo/pkg/a1.ts"] = "??",
      ["/repo/pkg/a2.ts"] = "A ",
      ["/repo/pkg/m1.ts"] = "M ",
    })
    assert.equals("A", a1.git_letter)
    assert.equals("A", a2.git_letter)
    assert.equals("M", m1.git_letter)
    -- Unique letters, canonical D-M-A order → MA (add + modify inside the folder).
    assert.equals("MA", pkg.git_status_summary)
    assert.equals("MA", root.git_status_summary)
  end)

  it("marks an untracked directory A when git reports ?? on the dir itself", function()
    local pkg = {
      type = "directory",
      name = "pkg",
      path = "/repo/pkg",
      children = {
        { type = "file", name = "a.ts", path = "/repo/pkg/a.ts" },
        { type = "file", name = "b.ts", path = "/repo/pkg/b.ts" },
        { type = "file", name = "c.ts", path = "/repo/pkg/c.ts" },
      },
      _unpopulated = false,
    }
    local root = { type = "root", name = "repo", path = "/repo", children = { pkg } }
    amd.stamp(root, { ["/repo/pkg"] = "??" })
    assert.equals("A", pkg.git_status_summary)
  end)

  it("live git status stamps MA on a folder with add and modify", function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    vim.fn.system({ "git", "-C", tmp, "init" })
    vim.fn.system({ "git", "-C", tmp, "config", "user.email", "t@t.t" })
    vim.fn.system({ "git", "-C", tmp, "config", "user.name", "t" })
    vim.fn.mkdir(tmp .. "/pkg", "p")
    local function write(path, body)
      local fd = assert(vim.uv.fs_open(path, "w", 420))
      vim.uv.fs_write(fd, body, 0)
      vim.uv.fs_close(fd)
    end
    write(tmp .. "/pkg/old.ts", "a\n")
    vim.fn.system({ "git", "-C", tmp, "add", "-A" })
    vim.fn.system({ "git", "-C", tmp, "commit", "-m", "init" })
    write(tmp .. "/pkg/old.ts", "b\n")
    write(tmp .. "/pkg/new.ts", "c\n")

    local root = require("bsi.fs.provider").new():scan(tmp, 0, { expand_all = true })
    local got
    amd.fetch_async(tmp, function(map)
      got = map or false
    end)
    vim.wait(5000, function()
      return got ~= nil
    end)
    assert.is_true(type(got) == "table", "fetch_async returned no map")
    amd.stamp(root, got)
    local pkg
    for _, c in ipairs(root.children or {}) do
      if c.name == "pkg" or c.name:match("^pkg/") then
        pkg = c
      end
    end
    assert.is_not_nil(pkg)
    assert.equals("MA", pkg.git_status_summary)
    vim.fn.delete(tmp, "rf")
  end)

  it("rolls M from src/app up to src", function()
    local file = { type = "file", name = "a.ts", path = "/repo/src/app/a.ts" }
    local app = { type = "directory", name = "app", path = "/repo/src/app", children = { file } }
    local src = { type = "directory", name = "src", path = "/repo/src", children = { app } }
    local root = { type = "root", name = "repo", path = "/repo", children = { src } }
    amd.stamp(root, { ["/repo/src/app/a.ts"] = "M " })
    assert.equals("M", file.git_letter)
    assert.equals("M", app.git_status_summary)
    assert.equals("M", src.git_status_summary)
  end)
end)
