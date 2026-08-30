-- lua/bsi/ui/tree.lua
-- BSI Tree: fast filesystem-only embedded file tree (no git status tracking).
-- Git decorations (porcelain status, numstat, gitignore snapshot) were removed
-- because they lag badly on repos with large working trees / huge change sets.

local M = {}

M.instances = {}

-- One-time namespace for all extmarks (cheaper than create_namespace on every render)
local ns_id = vim.api.nvim_create_namespace("bsitree")

-- Track last opened file path we synced trees to, to avoid redundant find_file+render
-- on every BufEnter (only pay when user actually switched main editing file)
M._last_synced_file = ""

-- "The one" main BSI tree instance for <leader>ee.
M.the_tree = nil

-- Tracked "opened buffer": the single main editing buffer the user is working with.
-- Used for current-file highlighting and find_file syncing.
M.opened_buffer = nil

--- Default configuration for the tree
M.config = {
  -- When false, name-based heavy dirs (node_modules, vendor, …) and .git are hidden.
  -- Dotfiles (names starting with ".") are always included except .git when hidden.
  -- Toggle with 'h' inside the tree.
  show_ignored = false,
}

local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local Provider = require("bsi.fs.provider")
local create_fs = require("bsi.fs.create")
local prune_fs = require("bsi.fs.prune")
local system = require("bsi.system")

--- Safely close a window, handling the "cannot close last window" (E444) case.
local function safe_close_win(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end
  local tab = vim.api.nvim_win_get_tabpage(winid)
  local tab_wins = vim.api.nvim_tabpage_list_wins(tab)
  if #tab_wins <= 1 then
    pcall(vim.cmd, "enew")
    return
  end
  pcall(vim.api.nvim_win_close, winid, true)
end

---@class bsi.Node
---@field id string
---@field name string
---@field path string
---@field type "file"|"directory"|"root"
---@field depth integer
---@field expanded boolean
---@field children bsi.Node[]|nil

---@class bsi.TreeState
---@field root bsi.Node

---@class bsi.Renderer
local Renderer = {}
Renderer.__index = Renderer

function Renderer.new()
  return setmetatable({}, Renderer)
end

--- Renders the provided nodes into the buffer with indentation, icons, and highlights
---@param bufnr integer
---@param nodes bsi.Node[]
---@param winid integer|nil
function Renderer:render(bufnr, nodes, winid)
  local lines = {}
  local highlights = {}
  local indent_cache = { ["0"] = "", ["1"] = " ", ["2"] = "  ", ["3"] = "   ", ["4"] = "    " }
  local current_file = M.get_opened_file()

  for i, node in ipairs(nodes) do
    local display_depth = node.depth - 1
    if display_depth < 0 then
      display_depth = 0
    end
    local indent = indent_cache[tostring(display_depth)] or string.rep(" ", display_depth)
    local arrow = "  "
    local icon = ""
    local icon_hl = nil
    local name_hl = nil
    local is_current = node.path == current_file

    if node.type == "root" or node.type == "directory" then
      if node.expanded then
        if node.children and #node.children == 0 then
          icon = ""
        else
          icon = ""
        end
        arrow = " "
      else
        icon = ""
        arrow = " "
      end
      name_hl = "Directory"
    else
      arrow = "  "
      if node._icon then
        icon = node._icon
        icon_hl = node._icon_hl
      elseif has_devicons then
        local ic, hl = devicons.get_icon(node.name, vim.fn.fnamemodify(node.name, ":e"), { default = true })
        icon = ic
        icon_hl = hl
      else
        icon = ""
      end
    end

    local line_content = table.concat({ indent, arrow, icon, " ", node.name })
    table.insert(lines, line_content)

    if is_current then
      table.insert(highlights, { hl = "BSITreeCurrentFile", line = i - 1, col_start = 0, col_end = -1 })
    end

    local current_col = #indent
    local arrow_start = current_col
    local arrow_end = arrow_start + #arrow
    local icon_start = arrow_end
    local icon_end = icon_start + #icon
    local name_start = icon_end + 1

    if icon_hl then
      table.insert(highlights, { hl = icon_hl, line = i - 1, col_start = icon_start, col_end = icon_end })
    end
    if name_hl then
      table.insert(highlights, {
        hl = name_hl,
        line = i - 1,
        col_start = name_start,
        col_end = name_start + #node.name,
      })
    end
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl.hl, hl.line, hl.col_start, hl.col_end)
  end
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "Tree"

  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_set_option_value("number", false, { win = winid })
    vim.api.nvim_set_option_value("relativenumber", false, { win = winid })
  end
end

---@class bsi.Tree
local Tree = {}
Tree.__index = Tree

--- Creates a new Tree instance and performs initial scan
---@param opts table|nil { root, expand_all, bufnr, winid, show_ignored }
function Tree.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Tree)
  self.provider = Provider.new()
  self.renderer = Renderer.new()
  local raw_root = opts.root or vim.fn.getcwd()
  self.root_path = vim.fn.resolve(vim.fn.fnamemodify(raw_root, ":p")):gsub("/$", "")
  self.opts = opts

  if opts.show_ignored ~= nil then
    self.show_ignored = opts.show_ignored
  else
    self.show_ignored = M.config.show_ignored
  end

  local initial_max_depth = opts.expand_all and nil or 1
  self._scan_opts = {
    expand_all = opts.expand_all,
    show_ignored = self.show_ignored,
    max_depth = initial_max_depth,
  }

  local root = self.provider:scan(self.root_path, 0, self._scan_opts)
  self.state = {
    root = root or {
      id = self.root_path,
      name = vim.fn.fnamemodify(self.root_path, ":t"),
      path = self.root_path,
      type = "root",
      depth = 0,
      expanded = true,
      children = {},
    },
  }
  self._visible_dirty = true
  self.bufnr = opts.bufnr
  self.winid = opts.winid
  return self
end

---@return string
function Tree:get_root_path()
  return vim.fn.fnamemodify(self.root_path, ":~")
end

---@return bsi.Node[]
function Tree:get_visible_nodes()
  if self._visible_nodes and not self._visible_dirty then
    return self._visible_nodes
  end
  local nodes = {}
  local function walk(node)
    if node.type ~= "root" then
      table.insert(nodes, node)
    end
    if (node.type == "directory" or node.type == "root") and node.expanded and node.children then
      for _, child in ipairs(node.children) do
        walk(child)
      end
    end
  end
  walk(self.state.root)
  self._visible_nodes = nodes
  self._visible_dirty = false
  return nodes
end

function Tree:render()
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    return
  end

  local now = (vim.uv and vim.uv.now and vim.uv.now()) or 0
  if not self._visible_dirty and self._last_render_ms and (now - self._last_render_ms) < 60 then
    return
  end
  self._last_render_ms = now

  self.visible_nodes = self:get_visible_nodes()
  self.renderer:render(self.bufnr, self.visible_nodes, self.winid)
end

function Tree:_update_winbar()
  if not self.winid or not vim.api.nvim_win_is_valid(self.winid) then
    return
  end
  local title = self:get_root_path()
  if self._refreshing then
    title = title .. " (refreshing...)"
  end
  vim.api.nvim_set_hl(0, "BSITreeTitle", { fg = "#3EFFDC", bold = true })
  vim.wo[self.winid].winbar = "%#BSITreeTitle# " .. title
end

function Tree:open()
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = vim.api.nvim_create_buf(false, true)
  end
  local is_new_win = false
  if not self.winid or not vim.api.nvim_win_is_valid(self.winid) then
    vim.cmd("leftabove vsplit")
    self.winid = vim.api.nvim_get_current_win()
    is_new_win = true
  end
  vim.api.nvim_win_set_buf(self.winid, self.bufnr)
  vim.b[self.bufnr].bsi_tree_root = self.root_path

  -- Scratch / non-file buffer: never a valid :edit target (Telescope, etc.)
  vim.bo[self.bufnr].buftype = "nofile"
  vim.bo[self.bufnr].bufhidden = "wipe"
  vim.bo[self.bufnr].swapfile = false
  vim.bo[self.bufnr].modifiable = false

  M.instances[self.bufnr] = self
  pcall(vim.api.nvim_buf_set_name, self.bufnr, "BSITree")

  if is_new_win then
    vim.api.nvim_win_set_width(self.winid, 40)
  end

  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_set_option_value("cursorline", true, { win = self.winid })
    vim.api.nvim_set_option_value("winhighlight", "CursorLine:BSITreeCursorLine", { win = self.winid })
    -- Forbid replacing the tree buffer in this window (Telescope/edit must use another win)
    pcall(vim.api.nvim_set_option_value, "winfixbuf", true, { win = self.winid })
  end

  self:render()

  local opened = M.get_opened_file()
  if opened ~= "" then
    self:find_file(opened)
  end

  self:_update_winbar()

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = self.bufnr, silent = true, desc = "Tree: " .. desc })
  end

  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = self.bufnr,
    callback = function()
      M.instances[self.bufnr] = nil
      if M.the_tree and M.the_tree.bufnr == self.bufnr then
        M.the_tree = nil
      end
    end,
  })

  map("R", function()
    self:refresh()
  end, "Refresh")
  map("h", function()
    self:toggle_show_ignored()
  end, "Toggle ignored dirs (node_modules, vendor, .git, …)")
  map("q", function()
    safe_close_win(vim.api.nvim_get_current_win())
  end, "Close")
  map("<CR>", function()
    self:toggle()
  end, "Toggle / Expand directory")
  map("o", function()
    self:_open_system()
  end, "Open with system default app")
  map("d", function()
    self:_delete_node()
  end, "Delete file or directory")
  map("D", function()
    self:_diff_file()
  end, "Diff file")
  map("a", function()
    self:_add_file()
  end, "Add new file")
  map("r", function()
    self:rename_or_move()
  end, "Rename / Move")
  map("u", function()
    self:rename_or_move()
  end, "Rename / Move")
  map("y", function()
    self:_yank(false)
  end, "Yank name")
  map("Y", function()
    self:_yank(true)
  end, "Yank relative path")
  map("<LeftMouse>", "<LeftMouse>", "Select node")
  map("<2-LeftMouse>", function()
    self:toggle()
  end, "Open file / Toggle directory")

  map("gg", function()
    if self.winid and vim.api.nvim_win_is_valid(self.winid) then
      pcall(vim.api.nvim_win_set_cursor, self.winid, { 1, 0 })
    end
  end, "Go to top of tree")

  map("G", function()
    local nodes = self.visible_nodes or self:get_visible_nodes() or {}
    if self.winid and vim.api.nvim_win_is_valid(self.winid) and #nodes > 0 then
      pcall(vim.api.nvim_win_set_cursor, self.winid, { #nodes, 0 })
    end
  end, "Go to bottom of tree")
end

--- Re-scan filesystem, preserving expansion state
function Tree:refresh()
  local expanded = {}
  local function collect(node)
    if node.expanded then
      expanded[node.id] = true
    end
    if node.children then
      for _, child in ipairs(node.children) do
        collect(child)
      end
    end
  end
  collect(self.state.root)

  self._refreshing = true
  self:_update_winbar()

  local scan_opts = {
    expand_all = self.opts and self.opts.expand_all,
    show_ignored = self.show_ignored,
    -- Full-depth on refresh so expanded dirs can be restored with children
    max_depth = nil,
  }
  local new_root = self.provider:scan(self.root_path, 0, scan_opts)
  new_root = new_root
    or {
      id = self.root_path,
      name = vim.fn.fnamemodify(self.root_path, ":t"),
      path = self.root_path,
      type = "root",
      depth = 0,
      expanded = true,
      children = {},
    }

  local function restore(node)
    if expanded[node.id] or (self.opts and self.opts.expand_all) then
      node.expanded = true
      if node.children then
        for _, child in ipairs(node.children) do
          restore(child)
        end
      end
    end
  end
  restore(new_root)

  -- Populate any restored expanded dirs that are still stubs
  local function populate_expanded(node)
    if (node.type == "directory" or node.type == "root") and node.expanded then
      local needs = (not node.children or #node.children == 0) or node._unpopulated
      if needs then
        local sc = self.provider:scan(node.path, node.depth, {
          show_ignored = self.show_ignored,
        })
        if sc and sc.children then
          node.children = sc.children
        end
        node._unpopulated = false
      end
    end
    if node.children then
      for _, child in ipairs(node.children) do
        populate_expanded(child)
      end
    end
  end
  populate_expanded(new_root)

  self.state.root = new_root
  self._visible_dirty = true
  self._refreshing = false

  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    self:render()
  end
  self:_update_winbar()
end

function Tree:toggle_show_ignored()
  self.show_ignored = not (self.show_ignored or false)
  self:refresh()
end

function Tree:toggle()
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = self.visible_nodes[cursor[1]]
  if not node or node.type == "file" then
    self:_open_file()
    return
  end
  if not node.expanded and node.type == "directory" then
    local needs_load = (node.children and #node.children == 0) or node._unpopulated
    if needs_load then
      local scanned = self.provider:scan(node.path, node.depth, {
        show_ignored = self.show_ignored,
      })
      if scanned and scanned.children then
        node.children = scanned.children
        node._unpopulated = false
      end
    end
  end
  node.expanded = not node.expanded
  self._visible_dirty = true
  self:render()
end

function Tree:_open_file()
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = self.visible_nodes[cursor[1]]
  if not node or node.type ~= "file" then
    return
  end
  vim.cmd("wincmd l")
  vim.cmd("edit " .. vim.fn.fnameescape(node.path))
end

function Tree:_open_system()
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = self.visible_nodes[cursor[1]]
  if not node then
    return
  end

  system.open_url(node.path)
end

function Tree:_diff_file()
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = self.visible_nodes[cursor[1]]
  if not node or node.type ~= "file" then
    return
  end
  vim.cmd("DiffviewOpen -- " .. vim.fn.fnameescape(node.path))
end

function Tree:_delete_node()
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = self.visible_nodes[cursor[1]]
  if not node or node.type == "root" then
    vim.notify("Cannot delete the root", vim.log.levels.WARN)
    return
  end

  local path = node.path
  local is_dir = node.type == "directory"
  local label = is_dir and "directory" or "file"

  local choice = vim.fn.confirm(
    "Delete " .. label .. " " .. vim.fn.fnamemodify(path, ":t") .. "?",
    "&Yes\n&No",
    2
  )
  if choice ~= 1 then
    return
  end

  local flags = is_dir and "rf" or ""
  local deleted = vim.fn.delete(path, flags)

  if deleted == 0 then
    vim.notify("Deleted " .. label .. ": " .. path, vim.log.levels.INFO)
    if M.opened_buffer and vim.api.nvim_buf_get_name(M.opened_buffer) == path then
      M.opened_buffer = nil
    end
    local bufnr = vim.fn.bufnr(path)
    if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
    prune_fs(self.root_path, vim.fn.fnamemodify(path, ":h"))
    self:refresh()
  else
    vim.notify("Failed to delete " .. label .. ": " .. path, vim.log.levels.ERROR)
  end
end

---@param full boolean
function Tree:_yank(full)
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = self.visible_nodes[cursor[1]]
  if not node then
    return
  end
  local text = full and (node.path:sub(#self.root_path + 2)) or node.name
  if text == "" then
    text = "."
  end
  vim.fn.setreg('"', text)
  vim.notify("Yanked " .. text, vim.log.levels.INFO)
  vim.schedule(function()
    vim.fn.setreg("+", text)
  end)
end

function Tree:_add_file()
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = self.visible_nodes[cursor[1]]
  if not node then
    return
  end

  local target_dir = (node.type == "directory" or node.type == "root") and node.path
    or vim.fn.fnamemodify(node.path, ":h")

  vim.ui.input({
    prompt = "New file: ",
    default = create_fs.default_path(self.root_path, target_dir),
    completion = "file",
  }, function(input)
    local result = create_fs(self.root_path, input)
    if result.kind == "empty" then
      return
    end
    if result.kind == "exists" then
      vim.notify("Already exists: " .. (result.path or input), vim.log.levels.WARN)
      return
    end
    if not result.ok then
      vim.notify("Failed to create: " .. (result.err or result.path or "unknown"), vim.log.levels.ERROR)
      return
    end

    self:refresh()
    if result.path then
      self:find_file(result.path)
    end

    if result.kind == "file" and result.path then
      vim.schedule(function()
        vim.cmd("wincmd l")
        vim.cmd("edit " .. vim.fn.fnameescape(result.path))
      end)
    end
  end)
end

---@param src string
---@param dst string
---@return boolean success
---@return string|nil error
function Tree:_move_path(src, dst)
  local stat = vim.loop.fs_stat(src)
  if not stat then
    return false, "Source does not exist"
  end

  local ok = vim.loop.fs_rename(src, dst)
  if ok then
    return true
  end

  vim.fn.mkdir(vim.fn.fnamemodify(dst, ":h"), "p")

  if stat.type == "file" then
    local content = vim.fn.readfile(src, "b")
    vim.fn.writefile(content, dst, "b")
    vim.loop.fs_unlink(src)
    return true
  end

  if stat.type == "directory" then
    vim.fn.mkdir(vim.fn.fnamemodify(dst, ":h"), "p")
    if not vim.loop.fs_stat(dst) then
      local mkdir_ok = vim.loop.fs_mkdir(dst, 493)
      if not mkdir_ok then
        return false, "Failed to create destination directory"
      end
    end

    local handle = vim.loop.fs_scandir(src)
    if handle then
      while true do
        local name = vim.loop.fs_scandir_next(handle)
        if not name then
          break
        end
        local success, move_err = self:_move_path(src .. "/" .. name, dst .. "/" .. name)
        if not success then
          return false, move_err
        end
      end
    end
    vim.loop.fs_rmdir(src)
    return true
  end

  return false, "Unsupported file type: " .. stat.type
end

function Tree:rename_or_move()
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local node = self.visible_nodes[cursor[1]]
  if not node or node.type == "root" then
    vim.notify("Cannot rename/move the root", vim.log.levels.WARN)
    return
  end

  local current = node.path
  vim.ui.input({
    prompt = "New path: ",
    default = current,
    completion = "file",
  }, function(new_path)
    if not new_path or new_path == "" or new_path == current then
      return
    end
    local old_parent = vim.fn.fnamemodify(current, ":h")
    local success, err = self:_move_path(current, new_path)
    if not success then
      vim.notify("Failed to move/rename: " .. (err or "unknown error"), vim.log.levels.ERROR)
      return
    end
    vim.notify(string.format("Moved/Renamed:\n  %s\n→ %s", current, new_path), vim.log.levels.INFO)
    local new_parent = vim.fn.fnamemodify(vim.fs.normalize(new_path), ":h")
    if vim.fs.normalize(old_parent) ~= vim.fs.normalize(new_parent) then
      prune_fs(self.root_path, old_parent)
    end
    self:refresh()
  end)
end

---@param target_path string
function Tree:find_file(target_path)
  if not target_path or target_path == "" then
    return
  end
  if target_path:sub(1, #self.root_path) ~= self.root_path then
    return
  end

  if self.visible_nodes then
    for i, node in ipairs(self.visible_nodes) do
      if node.path == target_path then
        if self.winid and vim.api.nvim_win_is_valid(self.winid) then
          pcall(vim.api.nvim_win_set_cursor, self.winid, { i, 0 })
        end
        return
      end
    end
  end

  local function expand_recursive(node, target)
    if node.path == target then
      return true
    end
    if node.type == "directory" or node.type == "root" then
      if target:sub(1, #node.path) == node.path then
        if not node.expanded then
          if (node.children and #node.children == 0) or node._unpopulated then
            local scanned = self.provider:scan(node.path, node.depth, {
              show_ignored = self.show_ignored,
            })
            if scanned and scanned.children then
              node.children = scanned.children
              node._unpopulated = false
            end
          end
          node.expanded = true
        end
        if node.children then
          for _, child in ipairs(node.children) do
            if expand_recursive(child, target) then
              return true
            end
          end
        end
      end
    end
    return false
  end

  expand_recursive(self.state.root, target_path)
  self._visible_dirty = true
  self:render()

  for i, node in ipairs(self.visible_nodes) do
    if node.path == target_path then
      if self.winid and vim.api.nvim_win_is_valid(self.winid) then
        pcall(vim.api.nvim_win_set_cursor, self.winid, { i, 0 })
      end
      break
    end
  end
end

---@param node bsi.Node
---@return bsi.Node|nil
function Tree:_find_parent_node(node)
  if not node or node.path == self.root_path then
    return nil
  end

  local function search(current, target_path)
    if not current.children then
      return nil
    end
    for _, child in ipairs(current.children) do
      if child.path == target_path then
        return current
      end
      if child.type == "directory" or child.type == "root" then
        local found = search(child, target_path)
        if found then
          return found
        end
      end
    end
    return nil
  end

  return search(self.state.root, node.path)
end

---@param direction "down"|"up"
function Tree:navigate_file(direction)
  if not self.visible_nodes or #self.visible_nodes == 0 then
    return
  end
  if not self.winid or not vim.api.nvim_win_is_valid(self.winid) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(self.winid)
  local idx = cursor[1]

  if direction == "down" then
    idx = math.min(idx + 1, #self.visible_nodes)
  else
    idx = math.max(idx - 1, 1)
  end

  vim.api.nvim_win_set_cursor(self.winid, { idx, 0 })

  local node = self.visible_nodes[idx]
  if not node then
    return
  end

  local target = node

  if node.type == "directory" and not node.expanded then
    local current = (direction == "up") and self:_find_parent_node(node) or node

    while current and (current.type == "directory" or current.type == "root") do
      if not current.children or #current.children == 0 or current._unpopulated then
        local scanned = self.provider:scan(current.path, current.depth, {
          show_ignored = self.show_ignored,
        })
        if scanned and scanned.children then
          current.children = scanned.children
          current._unpopulated = false
        end
      end
      local children = current.children or {}
      if #children == 0 then
        break
      end
      current = children[(direction == "up") and #children or 1]
    end

    if current then
      target = current
    end
  end

  if target and target.type == "file" then
    if vim.api.nvim_get_current_win() ~= self.winid then
      vim.api.nvim_set_current_win(self.winid)
    end
    for i, n in ipairs(self.visible_nodes) do
      if n.path == target.path then
        pcall(vim.api.nvim_win_set_cursor, self.winid, { i, 0 })
        break
      end
    end
    self:_open_file()
  end
end

--- Factory
---@param opts table|nil
function M.new(opts)
  return Tree.new(opts)
end

---@param bufnr integer|nil
---@return string|nil
function M.get_root_path(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.b[bufnr].bsi_tree_root
end

function M.toggle_tree()
  if M.the_tree and M.the_tree.winid and vim.api.nvim_win_is_valid(M.the_tree.winid) then
    safe_close_win(M.the_tree.winid)
    M.the_tree = nil
    return
  end

  local found_win = nil
  local found_buf = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "Tree" then
      found_win = win
      found_buf = buf
      break
    end
  end

  if found_win and found_buf then
    local inst = M.instances[found_buf]
    if inst then
      M.the_tree = inst
    end
    safe_close_win(found_win)
    M.the_tree = nil
    return
  end

  local t = M.new()
  t:open()
  M.the_tree = t

  local opened_path = M.get_opened_file()
  if opened_path ~= "" then
    t:find_file(opened_path)
  end
  vim.cmd("wincmd l")
end

--- Compatibility stub: git-changes mode was removed (laggy on large change sets).
--- Opens / focuses the normal filesystem tree instead.
function M.show_in_git_mode()
  if M.the_tree and M.the_tree.winid and vim.api.nvim_win_is_valid(M.the_tree.winid) then
    return
  end
  M.toggle_tree()
end

function M.set_opened_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.bo[bufnr].buftype ~= "" then
    return
  end
  local ft = vim.bo[bufnr].filetype
  if ft == "Tree" or ft == "GitView" then
    return
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return
  end
  M.opened_buffer = bufnr
end

function M.get_opened_buffer()
  local buf = M.opened_buffer
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  M.opened_buffer = nil
  return nil
end

function M.get_opened_file()
  local buf = M.get_opened_buffer()
  if buf then
    return vim.api.nvim_buf_get_name(buf) or ""
  end
  return ""
end

---@param opts table|nil
function M.setup(opts)
  opts = opts or {}
  for k, v in pairs(opts) do
    M.config[k] = v
  end

  M.set_opened_buffer()

  vim.api.nvim_set_hl(0, "BSITreeCurrentFile", { bg = "#3b4261", bold = true })
  vim.api.nvim_set_hl(0, "BSITreeOpenedFile", { fg = "#7aa2f7", italic = true })
  vim.api.nvim_set_hl(0, "BSITreeCursorLine", { bg = "#2e3a4a" })

  local group = vim.api.nvim_create_augroup("BSITreeTracking", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      local buf = args.buf
      M.set_opened_buffer(buf)

      local path = vim.api.nvim_buf_get_name(buf)
      if path == "" or vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "Tree" then
        return
      end

      if path ~= M._last_synced_file then
        M._last_synced_file = path
        for _, tree in pairs(M.instances) do
          if tree.winid and vim.api.nvim_win_is_valid(tree.winid) then
            tree:find_file(path)
          end
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function()
      if M.opened_buffer and not vim.api.nvim_buf_is_valid(M.opened_buffer) then
        M.opened_buffer = nil
      end
      for _, tree in pairs(M.instances) do
        tree:render()
      end
    end,
  })

  vim.api.nvim_create_user_command("BSITree", function(args)
    local root = args.args ~= "" and args.args or nil
    M.new({ root = root }):open()
  end, { nargs = "?", complete = "dir" })
end

return M
