vim.cmd([[set packpath=/tmp/nvim/site]])

-- Close Neovim just after fully opening it. Randomize to make "more real".
vim.defer_fn(function() vim.cmd([[quit]]) end, 100 + 200 * math.random())
