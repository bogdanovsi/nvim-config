return {

  {
    "nvim-neotest/neotest",

    dependencies = {
      { "nvim-lua/plenary.nvim" },
      { "nvim-treesitter/nvim-treesitter" },
      { "antoinemadec/FixCursorHold.nvim" },
      { "folke/neodev.nvim" },

      { "haydenmeade/neotest-jest" },

      -- adapters
      { "nvim-neotest/neotest-vim-test" },
      { "nvim-neotest/neotest-python" },
      { "rouge8/neotest-rust" },
      { "nvim-neotest/neotest-go", commit = "05535cb2cfe3ce5c960f65784896d40109572f89" }, -- https://github.com/nvim-neotest/neotest-go/issues/57
      { "adrigzr/neotest-mocha" },
      { "vim-test/vim-test" },
    },

    keys = {
      {
        "<leader>tS",
        ":lua require('neotest').run.run({ suite = true })<CR>",
        desc = "Run all tests in suite",
      },
    },

    opts = {
      adapters = {
        ["neotest-python"] = {
          -- https://github.com/nvim-neotest/neotest-python
          runner = "pytest",
          args = { "--log-level", "INFO", "--color", "yes", "-vv", "-s" },
          -- dap = { justMyCode = false },
        },
        ["neotest-go"] = {
          args = { "-coverprofile=coverage.out" },
        },
        -- ["neotest-rust"] = {
        --   -- see lazy.lua
        --   -- https://github.com/rouge8/neotest-rust
        --   --
        --   -- requires nextest, which can be installed via "cargo binstall":
        --   -- https://github.com/cargo-bins/cargo-binstall
        --   -- https://nexte.st/book/pre-built-binaries.html
        -- },
        ["neotest-vim-test"] = {
          -- https://github.com/nvim-neotest/neotest-vim-test
          ignore_file_types = { "python", "vim", "lua", "rust", "go" },
        },
        ["neotest-jest"] = {
          filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
          jestCommand = "npm test -- --watch",
        },
      },
    },
  },

  {
    "andythigpen/nvim-coverage",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>tc", "<cmd>Coverage<cr>", desc = "Coverage in gutter" },
      { "<leader>tC", "<cmd>CoverageLoad<cr><cmd>CoverageSummary<cr>", desc = "Coverage summary" },
    },
    config = function()
      require("coverage").setup({
        auto_reload = true,
      })
    end,
  },
}
