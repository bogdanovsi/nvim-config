local tree_mod = require("bsi.ui.tree")

local function touch(path)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  vim.uv.fs_close(fd)
end

local function cursor_on_file(t, name)
  vim.api.nvim_set_current_win(t.winid)
  for i, n in ipairs(t.visible_nodes or {}) do
    if n.type == "file" and n.name == name then
      vim.api.nvim_win_set_cursor(t.winid, { i, 0 })
      return n
    end
  end
end

local function tree_buf(t)
  return vim.api.nvim_win_get_buf(t.winid)
end

describe("bsi.ui.tree open file", function()
  local tmp
  local orig_confirm

  before_each(function()
    orig_confirm = vim.fn.confirm
    tmp = vim.fn.tempname()
    touch(tmp .. "/a.txt")
    touch(tmp .. "/b.txt")
    touch(tmp .. "/c.txt")
  end)

  after_each(function()
    vim.fn.confirm = orig_confirm
    if tmp then
      vim.fn.delete(tmp, "rf")
      tmp = nil
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local ft = vim.bo[buf].filetype
        local bt = vim.bo[buf].buftype
        if ft == "Tree" or bt == "terminal" then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for i, win in ipairs(wins) do
      if i < #wins and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_set_option_value, "winfixbuf", false, { win = win })
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
    local win = vim.api.nvim_get_current_win()
    pcall(vim.api.nvim_set_option_value, "winfixbuf", false, { win = win })
    pcall(vim.cmd, "enew")
  end)

  local function close_non_tree(t)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= t.winid and vim.api.nvim_win_is_valid(win) then
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative == "" then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end
    vim.api.nvim_set_current_win(t.winid)
  end

  local function open_tree()
    local t = tree_mod.new({ root = tmp })
    t:open()
    vim.api.nvim_set_current_win(t.winid)
    return t
  end

  it("opens a file in a new window when the tree is the only window", function()
    local t = open_tree()
    close_non_tree(t)
    assert.equals(1, #vim.api.nvim_tabpage_list_wins(0))
    assert.is_not_nil(cursor_on_file(t, "a.txt"))
    t:_open_file()
    assert.is_true(vim.api.nvim_win_is_valid(t.winid))
    assert.equals(t.bufnr, tree_buf(t))
    local file_win
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= t.winid then
        file_win = win
      end
    end
    assert.is_not_nil(file_win)
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(file_win))
    assert.is_truthy(name:find("a%.txt$", 1, false))
    assert.is_not_equal(t.bufnr, vim.api.nvim_win_get_buf(file_win))
  end)

  it("opens another file after deleting the displayed file", function()
    local t = open_tree()
    local editor
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= t.winid then
        editor = win
        break
      end
    end
    assert.is_not_nil(editor)
    vim.api.nvim_set_current_win(editor)
    vim.cmd("edit " .. vim.fn.fnameescape(tmp .. "/a.txt"))
    vim.api.nvim_set_current_win(t.winid)
    assert.is_not_nil(cursor_on_file(t, "a.txt"))
    vim.fn.confirm = function()
      return 1
    end
    t:_delete_node()
    assert.is_not_nil(cursor_on_file(t, "b.txt"))
    t:_open_file()
    assert.equals(t.bufnr, tree_buf(t))
    local found
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= t.winid then
        local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
        if name:find("b%.txt$", 1, false) then
          found = true
        end
      end
    end
    assert.is_true(found)
  end)

  it("does not open into a floating terminal", function()
    local t = open_tree()
    close_non_tree(t)
    local term_buf = vim.api.nvim_create_buf(false, true)
    local float = vim.api.nvim_open_win(term_buf, false, {
      relative = "editor",
      width = 20,
      height = 8,
      row = 1,
      col = 10,
    })
    vim.api.nvim_open_term(term_buf, {})
    vim.api.nvim_set_current_win(t.winid)
    assert.is_not_nil(cursor_on_file(t, "a.txt"))
    t:_open_file()
    assert.is_true(vim.api.nvim_win_is_valid(float))
    assert.equals(term_buf, vim.api.nvim_win_get_buf(float))
    assert.equals(t.bufnr, tree_buf(t))
    local file_win
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= t.winid and win ~= float then
        file_win = win
      end
    end
    assert.is_not_nil(file_win)
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(file_win))
    assert.is_truthy(name:find("a%.txt$", 1, false))
  end)

  it("opens a created file in a new editor when the tree is the only window", function()
    local t = open_tree()
    close_non_tree(t)
    local path = tmp .. "/new.txt"
    touch(path)
    t:_edit_in_editor(path)
    assert.equals(t.bufnr, tree_buf(t))
    local found
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= t.winid then
        local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
        if name:find("new%.txt$", 1, false) then
          found = true
        end
      end
    end
    assert.is_true(found)
  end)

  it("edits in the last-used file window when two splits exist", function()
    local t = open_tree()
    local first
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= t.winid then
        first = win
        break
      end
    end
    assert.is_not_nil(first)
    vim.api.nvim_set_current_win(first)
    vim.cmd("edit " .. vim.fn.fnameescape(tmp .. "/a.txt"))
    vim.cmd("vsplit")
    local second = vim.api.nvim_get_current_win()
    vim.cmd("edit " .. vim.fn.fnameescape(tmp .. "/b.txt"))
    vim.api.nvim_set_current_win(first)
    vim.api.nvim_set_current_win(t.winid)
    assert.is_not_nil(cursor_on_file(t, "c.txt"))
    t:_open_file()
    assert.equals(first, vim.api.nvim_get_current_win())
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(first))
    assert.is_truthy(name:find("c%.txt$", 1, false))
    assert.equals(
      vim.fn.resolve(tmp .. "/b.txt"),
      vim.fn.resolve(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(second)))
    )
    assert.equals(t.bufnr, tree_buf(t))
  end)
end)
