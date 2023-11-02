local tmp = 1

local keymap_rhs = function()
  -- Comment
  _G.been_here = true
end

--stylua: ignore
vim.api.nvim_set_keymap(
  'n', 'ga', '',
  { callback = keymap_rhs, desc = 'Keymap with callback' }
)
