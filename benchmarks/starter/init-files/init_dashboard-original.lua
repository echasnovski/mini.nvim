vim.cmd([[set packpath=/tmp/nvim/site]])
vim.cmd([[packadd dashboard-nvim]])

vim.g.mapleader = ' '
vim.g.dashboard_default_executive = 'telescope'
vim.api.nvim_set_keymap('n', '<Leader>ss', ':<C-u>SessionSave<CR>', {})
vim.api.nvim_set_keymap('n', '<Leader>sl', ':<C-u>SessionLoad<CR>', {})

vim.api.nvim_set_keymap('n', '<Leader>fh', ':DashboardFindHistory<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>ff', ':DashboardFindFile<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>tc', ':DashboardChangeColorscheme<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>fa', ':DashboardFindWord<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>fb', ':DashboardJumpMark<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>cn', ':DashboardNewFile<CR>', { noremap = true, silent = true })

-- Close Neovim just after fully opening it. Randomize to make "more real".
vim.defer_fn(function() vim.cmd([[quit]]) end, 100 + 200 * math.random())
