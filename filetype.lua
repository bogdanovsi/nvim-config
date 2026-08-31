-- Sourced during filetype detection, before BufRead of CLI files.
-- Neovim has no builtin *.pcss mapping.
vim.filetype.add({
  extension = { pcss = "postcss" },
})
