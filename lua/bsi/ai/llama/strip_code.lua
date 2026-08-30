--- @param input string
--- @return string
-- local function strip_code(input)
--   -- Check for triple backticks
--   if input:sub(1, 3) == "```" and input:sub(-3) == "```" then
--     return input:sub(4, -4)
--   -- Check for single backticks
--   elseif input:sub(1, 1) == "`" and input:sub(-1) == "`" then
--     return input:sub(2, -2)
--   else
--     return input
--   end
-- end

--- Strip markdown code fences. Lua patterns have no `{n,m}`, so fences are
--- matched as ``` (optional language + newline) or wrapping ` / ``` pairs.
---@param str string
---@return string
function strip_code(str)
    -- ```lang\ncode\n``` → keep surrounding newlines around the body
    local body = str:match("^```[%w]*\n(.*)\n```%s*$")
    if body then
        return "\n" .. body .. "\n"
    end
    -- ```code``` on one line
    local triple = str:match("^```(.*)```$")
    if triple then
        return triple
    end
    -- `code`
    local single = str:match("^`(.*)`$")
    if single then
        return single
    end
    return str
end

-- --- @param input string
-- --- @return string
-- local function strip_code(input)
--     local code = string.match(input, one_line_pattern)
--     if code then
--         return code
--     end

--     return input
--     -- local multiline_code = string.match(input, multiline_code_pattern);
--     -- if multiline_code then
--     --     return multiline_code
--     -- end

--     -- local one_line = string.match(input, multiline_line_pattern);
--     -- if one_line then
--     --     return one_line
--     -- end

--     -- local code = string.match(input, one_line_pattern);
--     -- if code then
--     --     return code
--     -- end

--     -- return input
-- end

return strip_code
