-- render-markdown.nvim: in-buffer markdown preview
-- https://github.com/MeanderingProgrammer/render-markdown.nvim
require("render-markdown").setup({
    enabled = true,
    file_types = { "markdown" },
    -- Render in normal/command; raw source while inserting
    render_modes = { "n", "c", "t" },

    code = {
        enabled = true,
        -- Conceal the ``` fences themselves
        conceal_delimiters = true,
        -- Language icon + name above the block (needs nvim-web-devicons / mini.icons)
        sign = true,
        language = true,
        language_icon = true,
        language_name = true,
        language_info = true,
        position = "left",
        -- Background for the whole block body
        width = "block",
        left_pad = 1,
        right_pad = 1,
        min_width = 45,
        -- Border styles: none | thick | thin | hide
        border = "thin",
        above = "▄",
        below = "▀",
        -- Also style `inline code`
        inline = true,
        -- full | normal | language | none
        style = "full",
        -- Languages where background is off (treesitter already colors them)
        disable_background = { "diff" },
    },

    heading = {
        enabled = true,
        sign = true,
        width = "full",
    },

    bullet = {
        enabled = true,
    },

    checkbox = {
        enabled = true,
    },

    -- LSP hover / nofile buffers still get rendering without sign clutter
    overrides = {
        buftype = {
            nofile = {
                render_modes = true,
                sign = { enabled = false },
            },
        },
    },
})
