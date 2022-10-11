local get_hunks = function()
  local res = {}
  local add = function(added, removed) table.insert(res, { added = added, removed = removed }) end

  -- Typical usa cases
  -- First two lines should be "add"
  add({ start = 1, count = 2 }, { start = 0, count = 0 })
  -- Single line 4 should be "delete"
  add({ start = 4, count = 0 }, { start = 5, count = 6 })
  -- First two lines (7-8) should be "change", rest (9-12) - "add"
  add({ start = 7, count = 6 }, { start = 7, count = 2 })

  -- Out of bounds data
  add({ start = 0, count = 0 }, { start = 1, count = 2 })
  add({ start = 1000, count = 1 }, { start = 0, count = 0 })

  return res
end

vim.cmd('hi GitSignsAdd guibg=green')
vim.cmd('hi GitSignsChange guibg=gray')
vim.cmd('hi GitSignsDelete guibg=red')

return { get_hunks = get_hunks }
