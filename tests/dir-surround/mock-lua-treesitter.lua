-- Mock treesitter for 'lua'
vim.treesitter.get_parser = function(_, lang, _)
  if lang ~= 'lua' then
    -- On Neovim>=0.12 `nil` is silently returned if there is no parser
    if vim.fn.has('nvim-0.12') == 1 then return nil end
    error([[There is parser only for 'lua' language.]])
  end

  return {
    trees = function(_)
      return { { root = function(_) return {} end } }
    end,
  }
end

local new_node = function(range, id)
  return {
    -- Track `id` for mocking query within node
    _id = id,

    -- `node:range()` should return 0-based numbers (row1, col1, row2, col2)
    -- for end-exclusive region
    range = function(_) return unpack(range) end,
  }
end

local get_query = function(lang, _)
  if lang ~= 'lua' then error([[There is query only for 'lua' language.]]) end

  local query = {}
  query.captures = { 'function.outer', 'function.inner', 'other.outer', 'other.inner' }

  -- Imitate matches from reference file 'tests/dir-surround/lua-file.lua'
  -- The 'function.outer' and 'function.inner' matches are "real"
  --stylua: ignore
  local matches = {
    { 3, new_node({ 0,  0,  0,  12 }, 1),  {} },
    { 4, new_node({ 0,  6,  0,  12 }, 2),  {} },
    { 1, new_node({ 2,  0,  4,  3 },  3),  {} },
    { 2, new_node({ 3,  2,  3,  37 }, 4),  {} },
    { 1, new_node({ 3,  9,  3,  37 }, 5),  {} },
    { 2, new_node({ 3,  20, 3,  33 }, 6),  {} },
    { 1, new_node({ 6,  6,  10, 3 },  7),  {} },
    -- Mock presence of something like `(#offset! @table.inner 1 -4 -1 10)`
    -- which would result in third `metadata` value being like this
    { 2, new_node({ 6,  6,  10, 3 },  8),  { [2] = { range = { 7,  2,  9,  13 } } } },
    { 3, new_node({ 9,  2,  9,  8 },  9),  {} },
    { 3, new_node({ 12, 0,  12, 8 }, 10),  {} },
    { 4, new_node({ 12, 7,  12, 8 }, 11),  {} },
  }

  local node_match_ids = {
    [1] = { 2 },
    [2] = {},
    [3] = { 4, 6 },
    [4] = {},
    [5] = { 6 },
    [6] = {},
    [7] = { 8 },
    [8] = {},
    [9] = {},
    [10] = { 11 },
    [11] = {},
  }

  query.iter_captures = function(_, node, _, _, _)
    local node_matches = node._id ~= nil and node_match_ids[node._id] or vim.tbl_keys(node_match_ids)
    local iterator = function(s, _)
      s.i = s.i + 1
      local res = matches[node_matches[s.i]]
      if res == nil then return nil end
      return unpack(res)
    end
    return iterator, { i = 0 }
  end

  return query
end

vim.treesitter.get_query = function(...)
  if vim.fn.has('nvim-0.9') == 1 then error('Use `vim.treesitter.query.get`.') end
  return get_query(...)
end

vim.treesitter.query = vim.treesitter.query or {}
vim.treesitter.query.get = function(...)
  if vim.fn.has('nvim-0.9') == 0 then error('This does not yet exist in Neovim<0.9.') end
  return get_query(...)
end
