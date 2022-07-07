vim.cmd([[set packpath=/tmp/nvim/site]])
vim.cmd([[packadd mini.nvim]])

require('mini.starter').setup()

-- Close Neovim just after fully opening it. Randomize to make "more real".
vim.defer_fn(function() vim.cmd([[quit]]) end, 100 + 200 * math.random())
