-- Avoid hit-enter-prompt
vim.o.cmdheight = 10
-- Avoid storing unnecessary data (also sometimes avoid hit-enter-prompt)
vim.o.swapfile = false

vim.cmd('set rtp+=.')
require('mini.sessions').setup({ autoread = true, autowrite = false, directory = 'tests/dir-sessions/local' })
