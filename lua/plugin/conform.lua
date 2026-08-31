require("conform").setup({
  formatters_by_ft = {
    go = { "goimports", "gofmt" },
    lua = { "stylua" },
    python = { "isort", "black" },
    php = { "pint" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    rust = { "rustfmt" },
    ejs = { "prettier" },
    postcss = { "prettier" },
    -- prettier: markdown prose + js/ts/json/yaml/html/css fences
    -- injected: remaining fences via formatters_by_ft (go, lua, python, …)
    markdown = { "prettier", "injected" },
    ["markdown.mdx"] = { "prettier", "injected" },
  },
  default_format_opts = {
    lsp_format = "fallback",
  },
  formatters = {
    injected = {
      options = {
        ignore_errors = true,
        lang_to_ft = {
          bash = "sh",
        },
        lang_to_ext = {
          bash = "sh",
          javascript = "js",
          typescript = "ts",
          python = "py",
          rust = "rs",
          markdown = "md",
        },
      },
    },
  },
})
