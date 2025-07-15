local new_match = function(range, id, metadata_range)
  return {
    -- Allow emulating tree-sitter directives that can compute range in query.
    -- For example, like this 'after/query/lua/textobjects.scm':
    -- ```
    -- ; extends
    -- ((table_constructor) @table.outer @table.inner (#offset! @table.inner 0 1 0 -1))
    -- ```
    metadata = metadata_range ~= nil and { range = metadata_range } or nil,
    node = {
      -- Track `id` for mocking query within node
      _id = id,

      -- Mock that it is a "real" TSNode
      tree = function() end,

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
     new_match({ 2, 0, 4,  3  }, 1),
     new_match({ 3, 9, 3,  37 }, 2),
     new_match({ 6, 6, 10, 3  }, 3),
  },
  ['@function.inner'] = {
     new_match({ 3, 2,  3, 37 }, 4),
     new_match({ 3, 20, 3, 33 }, 5),
     new_match({ 6, 6, 10, 3  }, 6, { 7, 2,  9, 13 }),
  },
  ['@plugin_other.outer'] = {
     new_match({ 0,  0, 0,  12 }, 7),
     new_match({ 9,  2, 9,  8  }, 8),
     new_match({ 12, 0, 12, 8  }, 9),
  },
  ['@plugin_other.inner'] = {
     new_match({ 0,  6, 0,  12 }, 10),
     new_match({ 12, 7, 12, 8  }, 11),
  },
}

local node_match_ids = {
  [1] = { 4, 5 },
  [2] = { 5 },
  [3] = { 6 },
  [4] = {},
  [5] = {},
  [6] = {},
  [7] = { 10 },
  [8] = {},
  [9] = { 11 },
  [10] = {},
  [11] = {},
}

local get_capture_matches_recursively = function(_, captures, _)
  local res = {}
  captures = type(captures) == 'string' and { captures } or captures
  for _, cap in ipairs(captures) do
    vim.list_extend(res, matches[cap])
  end
  return res
end

local get_capture_matches = function(_, capture, _, node, _)
  local all_matches = matches[capture]
  local valid_ids = node._id ~= nil and node_match_ids[node._id] or vim.tbl_keys(node_match_ids)
  return vim.tbl_filter(function(m) return vim.tbl_contains(valid_ids, m.node._id) end, all_matches)
end

return { get_capture_matches_recursively = get_capture_matches_recursively, get_capture_matches = get_capture_matches }
