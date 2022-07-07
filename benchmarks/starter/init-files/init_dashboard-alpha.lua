vim.cmd([[set packpath=/tmp/nvim/site]])
vim.cmd([[packadd alpha-nvim]])

local alpha = require('alpha')
local dashboard = require('alpha.themes.dashboard')
alpha.setup(dashboard.opts)

vim.g.mapleader = ' '

-- Some of these keybindings doesn't exactly match with what is shown in
-- buffer, but this doesn't really matter. Main point is that some keybindings
-- should be pre-made.
vim.api.nvim_set_keymap('n', '<Leader>ff', ':Telescope find_files<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>fh', ':Telescope oldfiles<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>fr', ':Telescope jumplist<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>fg', ':Telescope live_grep<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>fm', ':Telescope marks<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>sl', ':Telescope command_history<CR>', { noremap = true, silent = true })

-- Close Neovim just after fully opening it. Randomize to make "more real".
vim.defer_fn(function() vim.cmd([[quit]]) end, 100 + 200 * math.random())
