-- Avoid storing unnecessary data (also sometimes avoid hit-enter-prompt)
vim.o.swapfile = false

vim.cmd('set rtp+=.')
require('mini.sessions').setup({ autowrite = true })
