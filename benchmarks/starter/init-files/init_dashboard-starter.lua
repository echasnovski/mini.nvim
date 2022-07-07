vim.cmd([[set packpath=/tmp/nvim/site]])
vim.cmd([[packadd mini.nvim]])

local starter = require('mini.starter')
starter.setup({
  items = {
    { name = 'Edit file', action = [[enew]], section = 'Actions' },
    { name = 'Quit', action = [[quit]], section = 'Actions' },
    starter.sections.telescope(),
  },
  content_hooks = {
    starter.gen_hook.adding_bullet(),
    starter.gen_hook.aligning('center', 'center'),
  },
})

-- Close Neovim just after fully opening it. Randomize to make "more real".
vim.defer_fn(function() vim.cmd([[quit]]) end, 100 + 200 * math.random())
