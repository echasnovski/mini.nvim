local new_match = function(range, id)
  return {
    node = {
      -- Track `id` for mocking query within node
      _id = id,

      -- `node:range()` should return 0-based numbers (row1, col1, row2, col2)
      -- for end-exclusive region
      range = function(_) return unpack(range) end,

      -- Return start row, start col, and number of bytes from buffer start
      start = function(_) return range[1], range[2], vim.fn.line2byte(range[1] + 1) + range[2] - 1 end,

      -- Return end row, end col, and number of bytes from buffer start
      end_ = function(_) return range[3], range[4] - 1, vim.fn.line2byte(range[3] + 1) + range[4] - 2 end,
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
     new_match({ 7, 2,  9, 13 }, 6),
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
