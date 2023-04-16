vim.cmd('highlight clear')
vim.g.colors_name = 'mock_cs'

--stylua: ignore start
vim.api.nvim_set_hl(0, 'Normal',          { fg = '#5f87af', bg = '#080808' })
vim.api.nvim_set_hl(0, 'TestNormalCterm', { ctermfg = 67,   ctermbg = 232 })
vim.api.nvim_set_hl(0, 'TestComment',     { fg = '#5f87af', bg = '#080808' })
vim.api.nvim_set_hl(0, 'TestSpecial',     { sp = '#00ff00', underline = true })
vim.api.nvim_set_hl(0, 'TestBlend',       { bg = '#121212', blend = 0 })
--stylua: ignore end

vim.g.terminal_color_0 = '#010101'
vim.g.terminal_color_7 = '#fefefe'
