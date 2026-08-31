-- Named TUI float sessions: one visible slot, hide ≠ kill.
local M = {}

M.tools = {}
M.last = nil

--- Injectable factory so tests can stub Terminal without loading toggleterm.
function M.new_terminal(opts)
    local Terminal = require("toggleterm.terminal").Terminal
    return Terminal:new(opts)
end

function M.reset()
    M.tools = {}
    M.last = nil
end

--- Keep the float focused and in terminal mode so k9s/lazygit/grok receive keys.
function M.focus(term)
    if not term then
        return
    end
    local buf = term.bufnr
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    if vim.bo[buf].buftype ~= "terminal" then
        return
    end
    local win = term.window
    if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() ~= win then
        vim.api.nvim_set_current_win(win)
    end
    vim.cmd("startinsert!")
end

local function on_open(term)
    local buf = term.bufnr
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
            M.focus(term)
        end)
        return
    end

    vim.keymap.set("t", "<C-\\>", function()
        term:toggle()
    end, { buffer = buf, silent = true, desc = "Hide TUI" })

    -- vim-tmux-navigator uses <C-h/j/k/l> in terminal mode and leaves insert.
    -- TUIs need those chords; send them to the job instead.
    for _, lhs in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
        vim.keymap.set("t", lhs, lhs, { buffer = buf, nowait = true, noremap = true })
    end

    local group = vim.api.nvim_create_augroup("bsi_tui_focus_" .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TermEnter" }, {
        group = group,
        buffer = buf,
        callback = function()
            M.focus(term)
        end,
    })
    vim.api.nvim_create_autocmd("ModeChanged", {
        group = group,
        pattern = "*:nt",
        callback = function()
            if vim.api.nvim_get_current_buf() == buf then
                M.focus(term)
            end
        end,
    })

    vim.schedule(function()
        M.focus(term)
    end)
end

function M.define(name, cmd, extra)
    extra = extra or {}
    local opts = vim.tbl_extend("force", {
        cmd = cmd,
        hidden = true,
        direction = "float",
        close_on_exit = false,
        on_open = on_open,
    }, extra)
    M.tools[name] = M.new_terminal(opts)
end

function M.hide_others(except)
    for name, t in pairs(M.tools) do
        if name ~= except and t:is_open() then
            t:close()
        end
    end
end

function M.toggle(name)
    local t = M.tools[name]
    if not t then
        return
    end
    if t:is_open() then
        t:close()
        return
    end
    M.hide_others(name)
    M.last = name
    t:toggle()
    M.focus(t)
end

function M.toggle_last()
    M.toggle(M.last or "shell")
end

function M.pick()
    local names = vim.tbl_keys(M.tools)
    table.sort(names)
    vim.ui.select(names, { prompt = "CLI tool:" }, function(choice)
        if choice then
            M.toggle(choice)
        end
    end)
end

function M.setup()
    M.reset()
    M.define("lazygit", "lazygit", { close_on_exit = true })
    M.define("k9s", "k9s")
    M.define("grok", "grok")
    M.define("lazydocker", "lazydocker")
    M.define("shell", vim.o.shell)

    local function cmd(name, tool)
        pcall(vim.api.nvim_del_user_command, name)
        vim.api.nvim_create_user_command(name, function()
            M.toggle(tool)
        end, {})
    end
    cmd("LazyGit", "lazygit")
    cmd("LG", "lazygit")
    cmd("K9S", "k9s")
    cmd("LazyDocker", "lazydocker")
end

return M
