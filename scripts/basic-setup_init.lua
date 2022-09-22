-- Test possibility of checking out and initializing 'mini.nvim'
-- Possible problems:
-- - Long file names (particularly from reference screenshots).
-- - Duplicating file names in case-insensitive OS (particularly from reference
--   screenshots of parametrized test cases).

-- Add project root as full path to runtime path (in order to be able to
-- `require()`) modules from this module
vim.cmd([[let &rtp.=','.getcwd()]])

--stylua: ignore
local test_actions = {
  ['ai']          = function() require('mini.ai').setup() end,
  ['align']       = function() require('mini.align').setup() end,
  ['base16']      = function()
    local palette = require('mini.base16').mini_palette('#000000', '#ffffff', 50)
    require('mini.base16').setup({ palette = palette })
  end,
  ['bufremove']   = function() require('mini.bufremove').setup() end,
  ['comment']     = function() require('mini.comment').setup() end,
  ['completion']  = function() require('mini.completion').setup() end,
  ['cursorword']  = function() require('mini.cursorword').setup() end,
  ['doc']         = function() require('mini.doc').setup() end,
  ['fuzzy']       = function() require('mini.fuzzy').setup() end,
  ['indentscope'] = function() require('mini.indentscope').setup() end,
  ['jump']        = function() require('mini.jump').setup() end,
  ['jump2d']      = function() require('mini.jump2d').setup() end,
  ['misc']        = function() require('mini.misc').setup() end,
  ['pairs']       = function() require('mini.pairs').setup() end,
  ['sessions']    = function() require('mini.sessions').setup({ directory = '' }) end,
  ['starter']     = function() require('mini.starter').setup() end,
  ['statusline']  = function() require('mini.statusline').setup() end,
  ['surround']    = function() require('mini.surround').setup() end,
  ['tabline']     = function() require('mini.tabline').setup() end,
  ['test']        = function() require('mini.test').setup() end,
  ['trailspace']  = function() require('mini.trailspace').setup() end,
}

for module, test_fun in pairs(test_actions) do
  local ok, _ = pcall(test_fun)
  if not ok then
    io.stdout:write('There is a problem with following module: mini.' .. module .. '\n')
    vim.cmd('cquit')
  end
end

vim.cmd('qall!')
