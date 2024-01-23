-- Mock treesitter for 'lua'
vim.treesitter.get_parser = function(_, lang, _)
  if lang ~= 'lua' then error([[There is parser only for 'lua' language.]]) end

  return {
    trees = function(_)
      return { { root = function(_) return {} end } }
    end,
    lang = function(_) return lang end,
  }
end

local new_node = function(range)
  -- `node:range()` should return 0-based numbers (row1, col1, row2, col2) for
  -- end-exclusive region
  return { range = function(_) return unpack(range) end }
end

local get_query = function(lang, _)
  if lang ~= 'lua' then error([[There is query only for 'lua' language.]]) end

  local query = {}
  query.captures = { 'function.outer', 'function.inner', 'other' }

  -- Imitate matches from reference file 'tests/dir-ai/lua-file.lua'
  -- The 'function.outer' and 'function.inner' matches are "real"
  --stylua: ignore
  local matches = {
    { 3, new_node({ 0,  0,  0,  12 }), {} },
    { 1, new_node({ 2,  0,  4,  3 }),  {} },
    { 2, new_node({ 3,  2,  3,  37 }), {} },
    { 1, new_node({ 3,  9,  3,  37 }), {} },
    { 2, new_node({ 3,  20, 3,  33 }), {} },
    { 1, new_node({ 6,  6,  10, 3 }),  {} },
    { 2, new_node({ 7,  2,  9,  13 }), {} },
    { 3, new_node({ 12, 0,  12, 8 }),  {} },
  }

  query.iter_captures = function(_, _, _, _, _)
    local iterator = function(s, _)
      s.i = s.i + 1
      local res = matches[s.i]
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
