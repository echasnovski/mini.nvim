local new_match = function(range, metadata_range)
  return {
    -- Allow emulating tree-sitter directives that can compute range in query.
    -- For example, like this 'after/query/lua/textobjects.scm':
    -- ```
    -- ; extends
    -- ((table_constructor) @table.outer @table.inner (#offset! @table.inner 0 1 0 -1))
    -- ```
    metadata = metadata_range ~= nil and { range = metadata_range } or nil,
    node = {
      -- `node:range()` should return 0-based numbers (row1, col1, row2, col2)
      -- for end-exclusive region
      range = function(include_bytes)
        if not include_bytes then return unpack(range) end
        -- If `include_bytes` is `true`, then the output is
        -- `row1-col1-byte1-row2-col2-byte2`
        local start_byte = vim.fn.line2byte(range[1] + 1) + range[2]
        local end_byte = vim.fn.line2byte(range[3] + 1) + range[4] - 1
        return range[1], range[2], start_byte, range[3], range[4], end_byte
      end,
    },
  }
end

-- Imitate matches from reference file 'tests/dir-ai/lua-file.lua'
-- The 'function.outer' and 'function.inner' matches are "real"
--stylua: ignore
local matches = {
  ['@function.outer'] = {
     new_match({ 2, 0, 4,  3  }),
     new_match({ 3, 9, 3,  38 }),
     new_match({ 6, 6, 10, 3  }),
  },
  ['@function.inner'] = {
     new_match({ 3, 2,  3, 38 }),
     new_match({ 3, 20, 3, 33 }),
     new_match({ 6, 6, 10, 3  }, { 7, 2,  9, 13 }),
  },
  ['@plugin_return'] = {
     new_match({ 3,  2, 3,  38 }),
     new_match({ 9,  2, 9,  13 }),
     new_match({ 12, 0, 12, 8  }),
  },
}

local get_capture_matches_recursively = function(_, captures, _)
  local res = {}
  captures = type(captures) == 'string' and { captures } or captures
  for _, cap in ipairs(captures) do
    vim.list_extend(res, matches[cap])
  end
  return res
end

return { get_capture_matches_recursively = get_capture_matches_recursively }
