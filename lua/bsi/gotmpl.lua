-- Go template (*.tmpl) host-language detection + treesitter injection.
--
-- Problem: bare `gotmpl` only highlights `{{ ... }}`; the surrounding text
-- (HTML/YAML/JSON/...) stays plain and hard to read.
--
-- Solution (community pattern from nvim-treesitter discussions):
-- 1. Detect the *result* language from the name (`foo.html.tmpl`) or content.
-- 2. Inject that language into gotmpl `(text)` nodes via a custom directive.

local M = {}

--- Map file extensions / aliases to treesitter language names.
local ext_to_lang = {
  html = "html",
  htm = "html",
  xhtml = "html",
  yaml = "yaml",
  yml = "yaml",
  json = "json",
  jsonc = "json",
  json5 = "json5",
  md = "markdown",
  markdown = "markdown",
  xml = "xml",
  svg = "xml",
  sql = "sql",
  go = "go",
  toml = "toml",
  css = "css",
  scss = "scss",
  js = "javascript",
  jsx = "javascript",
  ts = "typescript",
  tsx = "tsx",
  sh = "bash",
  bash = "bash",
  zsh = "bash",
  shell = "bash",
  ksh = "bash",
  proto = "proto",
  graphql = "graphql",
  gql = "graphql",
  txt = nil, -- plain text: no host injection
  text = nil,
}

--- @param ext string|nil
--- @return string|nil
local function map_ext(ext)
  if not ext then
    return nil
  end
  return ext_to_lang[ext:lower()]
end

--- Host language from double-extension names: `config.yaml.tmpl`, `page.html.gotmpl`.
--- @param path string
--- @return string|nil
function M.host_from_filename(path)
  local name = vim.fs.basename(path)
  local ext = name:match("%.([%w_+-]+)%.tmpl$") or name:match("%.([%w_+-]+)%.gotmpl$")
  return map_ext(ext)
end

--- Host language from buffer content heuristics (first ~80 lines).
--- Template actions are stripped so tags/keys remain visible.
--- @param bufnr integer
--- @return string|nil
function M.host_from_content(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 80, false)
  if #lines == 0 then
    return nil
  end

  local text = table.concat(lines, "\n")
  -- Strip go-template actions (non-greedy; fine for heuristics).
  text = text:gsub("{{.-}}", " ")
  text = text:gsub("%[%[.-%]%]", " ")

  local trimmed = text:match("^%s*(.*)$") or text
  local head = trimmed:sub(1, 400)
  local head_l = head:lower()

  -- Shell shebang is a strong signal (must run before markdown `#` checks).
  local shebang = head_l:match("^#!([^\r\n]+)")
  if shebang
    and (
      shebang:find("bash", 1, true)
      or shebang:find("zsh", 1, true)
      or shebang:find("ksh", 1, true)
      or shebang:match("/bin/sh%s*$")
      or shebang:match("env%s+sh%s*$")
    )
  then
    return "bash"
  end

  if head:match("^[%[%{]") then
    return "json"
  end
  if head_l:match("^<%?xml") or head:match("^<svg[%s>]") then
    return "xml"
  end
  if head_l:match("<!doctype%s+html") or head_l:match("<html[%s>]") then
    return "html"
  end
  -- Several HTML-ish tags in the sample → treat as HTML.
  local html_hits = 0
  for _ in text:lower():gmatch("</?%s*[%a][%w%-]*") do
    html_hits = html_hits + 1
    if html_hits >= 3 then
      return "html"
    end
  end

  if head:match("^%-%-%-") then
    return "yaml"
  end

  -- Bash/shell construct scoring (scripts without shebang, or shebang stripped by templates).
  local bash_hits = 0
  local bash_patterns = {
    -- control flow
    "%f[%w]if%s+%[%[", -- if [[
    "%f[%w]if%s+%[", -- if [
    "%f[%w]then%f[%W]",
    "%f[%w]elif%f[%W]",
    "%f[%w]fi%f[%W]",
    "%f[%w]for%s+[%w_]+%s+in%f[%W]",
    "%f[%w]while%s+",
    "%f[%w]until%s+",
    "%f[%w]do%f[%W]",
    "%f[%w]done%f[%W]",
    "%f[%w]case%s+",
    "%f[%w]esac%f[%W]",
    "%f[%w]function%s+[%w_]+",
    -- common builtins / idioms
    "%f[%w]set%s+-[a-zA-Z]+",
    "%f[%w]export%s+[%w_]+",
    "%f[%w]source%s+",
    "%f[%w]echo%s+",
    "%f[%w]printf%s+",
    "%f[%w]readonly%s+",
    "%f[%w]local%s+[%w_]+",
    "%f[%w]return%s+",
    "%f[%w]exit%s+",
    "%f[%w]cd%s+",
    "%f[%w]mkdir%s+",
    "%f[%w]chmod%s+",
    "%f[%w]curl%s+",
    "%f[%w]wget%s+",
    -- expansions / redirects typical of shell
    "%$%{",
    "%$%(",
    "2>&1",
    "||%s*true",
  }
  for _, pat in ipairs(bash_patterns) do
    if text:match(pat) then
      bash_hits = bash_hits + 1
    end
  end
  -- ENV-style assignments: FOO=bar (not TOML key = value with spaces)
  local shell_assigns = 0
  for _, line in ipairs(lines) do
    local bare = line:gsub("{{.-}}", ""):gsub("^%s+", "")
    if bare:match("^[%w_]+=") and not bare:match("^[%w_]+%s*=") then
      shell_assigns = shell_assigns + 1
    end
  end
  if shell_assigns >= 2 then
    bash_hits = bash_hits + 1
  end
  if bash_hits >= 3 then
    return "bash"
  end

  local yaml_keys, toml_keys = 0, 0
  for _, line in ipairs(lines) do
    local bare = line:gsub("{{.-}}", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if bare:match("^[%w_.-]+%s*:%s*") and not bare:match("^[%w_.-]+%s*:%s*//") then
      yaml_keys = yaml_keys + 1
    end
    if bare:match("^[%w_.-]+%s*=") or bare:match("^%[[%w_.-]+%]$") then
      toml_keys = toml_keys + 1
    end
  end
  if yaml_keys >= 3 and yaml_keys >= toml_keys then
    return "yaml"
  end
  if toml_keys >= 2 then
    return "toml"
  end

  if head:upper():match("^%s*(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|WITH)%s") then
    return "sql"
  end
  if head:match("^package%s+%w+") or head:match("\npackage%s+%w+") then
    return "go"
  end
  -- Markdown headers: "# Title" — after bash so shell comments alone don't win.
  if head:match("^#%s+[%w]") or text:match("\n#%s+[%w].*\n#%s+[%w]") then
    return "markdown"
  end
  -- Weak shell signal if nothing else matched (e.g. short install scripts).
  if bash_hits >= 2 then
    return "bash"
  end

  return nil
end

--- Resolve host language for a buffer (filename first, then content).
--- Cached on `vim.b.gotmpl_host_lang` (`false` = known none).
--- @param bufnr integer
--- @return string|nil
function M.resolve_host_lang(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local cached = vim.b[bufnr].gotmpl_host_lang
  if cached ~= nil then
    return cached ~= false and cached or nil
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  local lang = M.host_from_filename(path) or M.host_from_content(bufnr)

  -- Only inject languages that actually have a parser available.
  if lang then
    local ok = pcall(vim.treesitter.language.add, lang)
    if not ok then
      lang = nil
    end
  end

  vim.b[bufnr].gotmpl_host_lang = lang or false
  return lang
end

--- Treesitter directive: set injection.language from detected host.
local function inject_host_directive(_match, _pattern, source, _pred, metadata)
  local bufnr = type(source) == "number" and source or 0
  local lang = M.resolve_host_lang(bufnr)
  if lang then
    metadata["injection.language"] = lang
  end
end

function M.setup()
  vim.treesitter.query.add_directive("inject-gotmpl-host!", inject_host_directive, { force = true })

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("bsi_gotmpl", { clear = true }),
    pattern = { "*.tmpl", "*.gotmpl" },
    callback = function(ev)
      local path = ev.file or vim.api.nvim_buf_get_name(ev.buf)

      -- Helm charts already use the helm dialect (yaml + gotmpl).
      if path:match("[/\\]templates[/\\]") then
        return
      end

      -- Reset cache on read so renames / content edits can re-detect later if needed.
      vim.b[ev.buf].gotmpl_host_lang = nil
      vim.bo[ev.buf].filetype = "gotmpl"

      local lang = M.resolve_host_lang(ev.buf)
      if lang then
        vim.b[ev.buf].gotmpl_host_lang = lang
      end
    end,
  })

  -- Re-detect when buffer text changes a lot (optional cheap refresh on write).
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("bsi_gotmpl_write", { clear = true }),
    pattern = { "*.tmpl", "*.gotmpl" },
    callback = function(ev)
      vim.b[ev.buf].gotmpl_host_lang = nil
      M.resolve_host_lang(ev.buf)
      -- Restart highlighter so injections pick up a changed host lang.
      pcall(vim.treesitter.start, ev.buf, "gotmpl")
    end,
  })
end

return M
