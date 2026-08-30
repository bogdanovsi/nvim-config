local tree_mod = require("bsi.ui.tree")

describe("bsi.ui.tree width", function()
  it("needed_width is display width plus one", function()
    assert.equals(5, tree_mod.needed_width({ "abcd" }))
    assert.equals(11, tree_mod.needed_width({ "hi", "0123456789" }))
    assert.equals(1, tree_mod.needed_width({}))
  end)

  it("clamped_width uses min, max, and inverted min>max", function()
    assert.equals(30, tree_mod.clamped_width(10, 30, 60))
    assert.equals(45, tree_mod.clamped_width(45, 30, 60))
    assert.equals(60, tree_mod.clamped_width(90, 30, 60))
    assert.equals(60, tree_mod.clamped_width(45, 80, 60))
  end)

  local win

  after_each(function()
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    win = nil
  end)

  local function tree_on_win()
    vim.cmd("vsplit")
    win = vim.api.nvim_get_current_win()
    local t = tree_mod.new({ root = vim.fn.tempname() })
    t.winid = win
    t._width_manual = false
    return t
  end

  it("auto-fit sets 45 for a 45-col needed line and 30 for short names", function()
    local t = tree_on_win()
    t._last_lines = { string.rep("x", 44) }
    t:_apply_width()
    assert.equals(45, vim.api.nvim_win_get_width(win))
    t._last_lines = { "ab" }
    t:_apply_width()
    assert.equals(30, vim.api.nvim_win_get_width(win))
  end)

  it("caps at 100 until > / < nudge width by 3", function()
    vim.o.columns = 150
    local t = tree_on_win()
    t._last_lines = { string.rep("x", 119) }
    t:_apply_width()
    assert.equals(100, vim.api.nvim_win_get_width(win))
    t:nudge_width(3)
    assert.is_true(t._width_manual)
    assert.equals(103, vim.api.nvim_win_get_width(win))
    t:_apply_width()
    assert.equals(103, vim.api.nvim_win_get_width(win))
    t:nudge_width(-3)
    assert.equals(100, vim.api.nvim_win_get_width(win))
    t:nudge_width(-3)
    assert.equals(97, vim.api.nvim_win_get_width(win))
  end)

  it("auto-fits again after a content re-render", function()
    vim.o.columns = 120
    local t = tree_on_win()
    t._last_lines = { string.rep("x", 44) }
    t:_apply_width()
    assert.equals(45, vim.api.nvim_win_get_width(win))
    t:nudge_width(3)
    t._width_manual = false
    t._last_lines = { string.rep("x", 54) }
    t:_apply_width()
    assert.equals(55, vim.api.nvim_win_get_width(win))
  end)

  it("new trees start in auto-fit and do not force 40", function()
    local t = tree_on_win()
    assert.is_false(t._width_manual)
    t._last_lines = { string.rep("x", 49) }
    t:_apply_width()
    assert.equals(50, vim.api.nvim_win_get_width(win))
    t._last_lines = { "a" }
    t:_apply_width()
    assert.equals(30, vim.api.nvim_win_get_width(win))
  end)
end)
