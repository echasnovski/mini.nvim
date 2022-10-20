-- Avoid hit-enter-prompt
vim.o.cmdheight = 2
-- Avoid storing unnecessary data (also sometimes avoid hit-enter-prompt)
vim.o.swapfile = false

vim.cmd('set rtp+=.')
require('mini.starter').setup({ autoopen = true })
