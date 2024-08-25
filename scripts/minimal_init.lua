-- Add project root as full path to runtime path (in order to be able to
-- `require()`) modules from this module
vim.cmd([[let &rtp.=','.getcwd()]])

-- Ensure persistent color scheme (matters after new default in Neovim 0.10)
vim.o.background = 'dark'
require('mini.hues').setup({ background = '#11262d', foreground = '#c0c8cc' })

-- - Make screenshot tests more robust across Neovim versions
if vim.fn.has('nvim-0.11') == 1 then
  vim.api.nvim_set_hl(0, 'PmenuMatch', { link = 'Pmenu' })
  vim.api.nvim_set_hl(0, 'PmenuMatchSel', { link = 'PmenuSel' })
end
