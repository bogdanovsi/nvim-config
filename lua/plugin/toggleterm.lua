require("toggleterm").setup({
    open_mapping = false,
    start_in_insert = true,
    persist_size = true,
    persist_mode = false, -- TUIs must always land in terminal mode, never restored normal
    direction = "float",
    close_on_exit = false,
    float_opts = {
        border = "rounded",
        width = function()
            return math.floor(vim.o.columns * 0.9)
        end,
        height = function()
            return math.floor(vim.o.lines * 0.9)
        end,
    },
})

require("bsi.tui").setup()
