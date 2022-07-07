vim.cmd([[set packpath=/tmp/nvim/site]])
vim.cmd([[packadd vim-startify]])

vim.g.startify_custom_header = ''

-- Close Neovim just after fully opening it. Randomize to make "more real".
vim.defer_fn(function() vim.cmd([[quit]]) end, 100 + 200 * math.random())
