-- Mock tree-sitter as if node is a region inside balanced `{}`

-- Find enclosing balanced `{}`. If `accept_at_cursor`, return balanced `{}`
-- when on it.
local find_enclosing_brackets = function(row, col, accept_at_cursor)
  local searchpairpos = function(flags)
    flags = flags or ''

    local cache_cursor = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_set_cursor(0, { row, col - 1 })
    local res = vim.fn.searchpairpos('{', '', '}', 'nWz' .. flags)
    vim.api.nvim_win_set_cursor(0, cache_cursor)

    return res
  end

  if accept_at_cursor == nil then accept_at_cursor = true end

  local char_at_cursor = vim.fn.getline(row):sub(col, col)

  if char_at_cursor == '{' and accept_at_cursor then return { row, col }, searchpairpos() end
  if char_at_cursor == '{' and not accept_at_cursor then return searchpairpos('b'), searchpairpos('c') end

  if char_at_cursor == '}' and accept_at_cursor then return searchpairpos('b'), { row, col } end
  if char_at_cursor == '}' and not accept_at_cursor then return searchpairpos('bc'), searchpairpos() end

  return searchpairpos('b'), searchpairpos()
end

--@param row number Row number starting from 1.
--@param col number Column number starting from 1.
local new_node
new_node = function(row, col, accept_at_cursor)
  if row == nil or col == nil then return nil end

  -- Start and end of this node
  local node_start, node_end = find_enclosing_brackets(row, col, accept_at_cursor)

  -- - No node under cursor if no `{}` found
  local no_node_found = (node_start[1] == 0 and node_start[2] == 0) or (node_end[1] == 0 and node_end[2] == 0)
  if no_node_found then return nil end

  -- Row and column for parent node
  local node = {}

  -- Start - inclusive, end - row-inclusive, col-exclusive. All zero-indexed.
  node.start = function(_) return node_start[1] - 1, node_start[2] - 1 end
  node.end_ = function(_) return node_end[1] - 1, node_end[2] end
  node.range = function(_) return node_start[1] - 1, node_start[2] - 1, node_end[1] - 1, node_end[2] - 1 end

  -- NOTE: this recursively searches for all parents for initial node
  local parent_node = new_node(node_start[1], node_start[2], false)
  node.parent = function(_) return parent_node end

  return node
end

-- `row` and `col` are both zero-indexed here
vim.treesitter.get_node_at_pos = function(_, row, col, _) return new_node(row + 1, col + 1) end
vim.treesitter.get_node = function(opts) return new_node(opts.pos[1] + 1, opts.pos[2] + 1) end
