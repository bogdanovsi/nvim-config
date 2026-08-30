-- nvim-lint: golangci-lint via `go tool` (go.mod pin), matching `make lint`.
-- gopls still owns LSP diagnostics; this layer adds .golangci.yml rules (e.g. depguard).
local lint = require("lint")

local golangcilint = lint.linters.golangcilint
golangcilint.cmd = "go"

-- Keep nvim-lint's v1/v2 JSON args and parser; only wrap the binary as `go tool golangci-lint`.
-- Do not replace args with `--output.json` — that flag is invalid on v2 (`--output.json.path=stdout`).
local args = golangcilint.args
if type(args) ~= "table" then
  golangcilint.args = {
    "tool",
    "golangci-lint",
    "run",
    "--output.json.path=stdout",
    "--show-stats=false",
    "--issues-exit-code=0",
  }
elseif args[1] ~= "tool" then
  table.insert(args, 1, "tool")
  table.insert(args, 2, "golangci-lint")
end

lint.linters_by_ft = {
  go = { "golangcilint" },
}

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
  pattern = "*.go",
  callback = function()
    local cwd = vim.fs.root(0, { "go.mod", "go.work" }) or vim.fn.getcwd()
    lint.try_lint(nil, { cwd = cwd })
  end,
})
