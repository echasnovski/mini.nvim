vim.cmd([[set packpath=/tmp/nvim/site]])
vim.cmd([[packadd alpha-nvim]])

local alpha = require('alpha')
local startify = require('alpha.themes.startify')
startify.nvim_web_devicons.enabled = false
alpha.setup(startify.opts)

-- Close Neovim just after fully opening it. Randomize to make "more real".
vim.defer_fn(function() vim.cmd([[quit]]) end, 100 + 200 * math.random())
