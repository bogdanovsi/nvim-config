local blink = require("blink.cmp")

return {
    cmd = { "vscode-css-language-server", "--stdio" },
    filetypes = { "css", "scss", "less", "postcss" },
    root_markers = { "package.json", ".git" },
    -- vscode-css-language-server only has css/scss/less services; unknown
    -- languageIds (including postcss) fall back to css, but mapping here keeps
    -- workspace/configuration on the `css` settings section.
    get_language_id = function(_, filetype)
        if filetype == "postcss" then
            return "css"
        end
        return filetype
    end,
    settings = {
        css = {
            validate = true,
            lint = { unknownAtRules = "ignore" },
        },
        scss = { validate = true },
        less = { validate = true },
    },
    capabilities = vim.tbl_deep_extend(
        "force",
        {},
        vim.lsp.protocol.make_client_capabilities(),
        blink.get_lsp_capabilities()
    ),
}
