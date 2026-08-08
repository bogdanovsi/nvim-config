require("telescope").setup({
    defaults = {
        file_ignore_patterns = { ".git/", "node_modules", "poetry.lock" },
        vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden",
        },
        layout_strategy = "flex",
        layout_config = {
            horizontal = {
                preview_width = 0.5,
            },
            vertical = {
                preview_height = 0.5,
            },
            width = 0.99,
            height = 0.99,
        },
        -- Never open picked files into sidebar trees (bsi-tree, nvim-tree, neo-tree).
        -- Without this, launching Telescope from a tree window makes original_win_id the
        -- tree and :edit replaces the tree buffer.
        get_selection_window = function(picker, _)
            local skip_ft = {
                Tree = true,
                NvimTree = true,
                ["neo-tree"] = true,
            }
            local function is_editable_win(win)
                if not win or not vim.api.nvim_win_is_valid(win) then
                    return false
                end
                local cfg = vim.api.nvim_win_get_config(win)
                if cfg.relative and cfg.relative ~= "" then
                    return false -- floating (picker/preview)
                end
                local buf = vim.api.nvim_win_get_buf(win)
                if not vim.api.nvim_buf_is_valid(buf) then
                    return false
                end
                if vim.bo[buf].buftype ~= "" then
                    return false
                end
                if skip_ft[vim.bo[buf].filetype] then
                    return false
                end
                return true
            end

            -- Prefer the window that launched Telescope when it is a normal editor
            local origin = picker and picker.original_win_id
            if is_editable_win(origin) then
                return origin
            end

            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if is_editable_win(win) then
                    return win
                end
            end
            return 0
        end,
        mappings = {
          i = {
            ["<C-q>"] = require("telescope.actions").send_to_qflist + require("telescope.actions").open_qflist,
            ["<M-q>"] = require("telescope.actions").send_selected_to_qflist + require("telescope.actions").open_qflist,
          },
          n = {
            ["<C-q>"] = require("telescope.actions").send_to_qflist + require("telescope.actions").open_qflist,
            ["<M-q>"] = require("telescope.actions").send_selected_to_qflist + require("telescope.actions").open_qflist,
          },
        },
    }
})

