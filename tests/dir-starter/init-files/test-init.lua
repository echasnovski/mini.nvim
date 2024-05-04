-- Avoid hit-enter-prompt
vim.o.cmdheight = 2
-- Avoid storing unnecessary data (also sometimes avoid hit-enter-prompt)
vim.o.swapfile = false

vim.cmd('set rtp+=.')
_G.n_event = 0
vim.cmd('autocmd User MiniStarterOpened lua _G.n_event = _G.n_event + 1')
require('mini.starter').setup({ autoopen = true })
