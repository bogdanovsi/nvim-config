local tui = require("bsi.tui")
local orig_focus = tui.focus

local function fake_terminal(opts)
    local t = {
        opts = opts,
        _open = false,
        close_count = 0,
        toggle_count = 0,
        job_running = true,
    }
    function t:is_open()
        return self._open
    end
    function t:close()
        self._open = false
        self.close_count = self.close_count + 1
    end
    function t:toggle()
        self._open = not self._open
        self.toggle_count = self.toggle_count + 1
    end
    return t
end

describe("bsi.tui", function()
    before_each(function()
        tui.reset()
        tui.new_terminal = fake_terminal
        tui.focus = orig_focus
    end)

    it("defines the named catalog", function()
        tui.setup()
        assert.is_not_nil(tui.tools.lazygit)
        assert.is_not_nil(tui.tools.k9s)
        assert.is_not_nil(tui.tools.grok)
        assert.is_not_nil(tui.tools.lazydocker)
        assert.is_not_nil(tui.tools.shell)
        assert.is_nil(tui.last)
    end)

    it("hides A when opening B without stopping A's job", function()
        tui.define("lazygit", "lazygit")
        tui.define("k9s", "k9s")
        local a = tui.tools.lazygit
        tui.toggle("lazygit")
        tui.toggle("k9s")
        assert.equals(1, a.close_count)
        assert.is_false(a:is_open())
        assert.is_true(a.job_running)
        assert.equals(a, tui.tools.lazygit)
        assert.is_true(tui.tools.k9s:is_open())
        assert.equals(1, tui.tools.k9s.toggle_count)
    end)

    it("reopens the same session object", function()
        tui.define("lazygit", "lazygit")
        local a = tui.tools.lazygit
        tui.toggle("lazygit")
        tui.toggle("lazygit") -- hide
        tui.toggle("lazygit") -- show again
        assert.equals(a, tui.tools.lazygit)
        assert.equals(2, a.toggle_count)
        assert.is_true(a:is_open())
    end)

    it("focuses the terminal after opening", function()
        local focused
        tui.focus = function(term)
            focused = term
        end
        tui.define("k9s", "k9s")
        tui.toggle("k9s")
        assert.equals(tui.tools.k9s, focused)
    end)

    it("self-toggle of a visible tool only closes", function()
        tui.define("lazygit", "lazygit")
        local a = tui.tools.lazygit
        tui.toggle("lazygit")
        tui.toggle("lazygit")
        assert.equals(1, a.toggle_count)
        assert.equals(1, a.close_count)
        assert.is_false(a:is_open())
        assert.is_true(a.job_running)
    end)

    it("toggle_last defaults to shell then tracks last shown", function()
        tui.define("shell", "sh")
        tui.define("k9s", "k9s")
        assert.is_nil(tui.last)
        tui.toggle_last()
        assert.equals("shell", tui.last)
        assert.is_true(tui.tools.shell:is_open())
        tui.toggle("k9s")
        assert.equals("k9s", tui.last)
        tui.toggle_last()
        assert.is_false(tui.tools.k9s:is_open())
    end)

    it("picker choice toggles the chosen name", function()
        tui.define("k9s", "k9s")
        tui.define("grok", "grok")
        local captured
        local orig = vim.ui.select
        vim.ui.select = function(items, opts, cb)
            captured = { items = items, opts = opts, cb = cb }
        end
        tui.pick()
        vim.ui.select = orig
        assert.is_not_nil(captured)
        assert.equals("CLI tool:", captured.opts.prompt)
        captured.cb("k9s")
        assert.is_true(tui.tools.k9s:is_open())
        assert.equals("k9s", tui.last)
        captured.cb(nil)
        assert.is_true(tui.tools.k9s:is_open())
    end)

    it("define defaults: hidden, no Esc/q hide, C-\\ hide, close_on_exit only for lazygit", function()
        tui.setup()
        assert.is_true(tui.tools.lazygit.opts.hidden)
        assert.is_true(tui.tools.lazygit.opts.close_on_exit)
        assert.is_false(tui.tools.k9s.opts.close_on_exit)
        assert.is_false(tui.tools.grok.opts.close_on_exit)
        assert.is_false(tui.tools.lazydocker.opts.close_on_exit)
        assert.is_false(tui.tools.shell.opts.close_on_exit)
        assert.equals("float", tui.tools.k9s.opts.direction)

        local buf = vim.api.nvim_create_buf(false, true)
        local term = tui.tools.k9s
        term.bufnr = buf
        term.opts.on_open(term)

        local tmaps = vim.api.nvim_buf_get_keymap(buf, "t")
        local has_hide = false
        local has_esc = false
        for _, m in ipairs(tmaps) do
            local lhs = m.lhs or ""
            local rhs = m.rhs or ""
            assert.are_not.equal("q", lhs)
            assert.is_nil(rhs:find("close", 1, true))
            if lhs == "<Esc>" then
                has_esc = true
                assert.equals("<Esc>", rhs)
            end
            if lhs == "<C-Bslash>" or lhs == "<C-\\>" or lhs:find("Bslash", 1, true) then
                has_hide = true
            end
        end
        assert.is_true(has_esc)
        assert.is_true(has_hide)
        vim.api.nvim_buf_delete(buf, { force = true })
    end)
end)
