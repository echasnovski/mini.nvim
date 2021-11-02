-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- A module for smarter jumping, inspired by clever-f. By default it does nothing.
---
--- # Setup
---
--- This module needs a setup with `require('mini.jump').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`:
--- <pre>
--- {
---   -- Make f, F, t and T able to jump across lines and be repeated by pressing them again.
---   map_ft = false,
--- }
--- </pre>
---@brief ]]
---@tag MiniJump mini.pairs

-- Module and its helper
local MiniJump = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.completion').setup({})` (replace `{}` with your `config` table)
function MiniJump.setup(config)
  -- Export module
  _G.MiniJump = MiniJump

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)
end

-- Module config
MiniJump.config = {
  map_ft = false,
}

-- Module functionality
MiniJump.target = nil
MiniJump.ask_for_target = true

function MiniJump.jump(target, backward, till)
  local flags = 'W'
  if backward then
    flags = flags .. 'b'
  end
  if target == '\\' then
    target = '\\\\'
  end
  local pattern
  if target == "'" then
    pattern = [["'"]]
  else
    pattern = [['\V]] .. target .. [[']]
  end
  local rhs = H.keys.cmd_start .. 'call search(' .. pattern .. ", '" .. flags .. "')" .. H.keys.cmd_end
  if till then
    if backward then
      rhs = H.get_arrow_key('left') .. rhs .. H.get_arrow_key('right')
    else
      rhs = H.get_arrow_key('right') .. rhs .. H.get_arrow_key('left')
    end
  end
  return rhs
end

function MiniJump.smart_jump(backward, till)
  if MiniJump.ask_for_target then
    MiniJump.target = H.get_char()
  end
  return MiniJump.jump(MiniJump.target, backward, till)
    .. H.keys.cmd_start
    .. [[lua MiniJump.ask_for_target = false]]
    .. H.keys.cmd_end
end

-- Helpers
---- Module default config
H.default_config = MiniJump.config

---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({
    map_ft = { config.map_ft, 'boolean' },
  })

  return config
end

function H.apply_config(config)
  MiniJump.config = config

  mode = 'n'

  if config.map_ft then
    H.map(mode, 'f', [[v:lua.MiniJump.smart_jump(v:false, v:false)]])
    H.map(mode, 'F', [[v:lua.MiniJump.smart_jump(v:true, v:false)]])
    H.map(mode, 't', [[v:lua.MiniJump.smart_jump(v:false, v:true)]])
    H.map(mode, 'T', [[v:lua.MiniJump.smart_jump(v:true, v:true)]])
    vim.cmd([[autocmd CursorMoved * lua MiniJump.ask_for_target = true]])
  end
end

function H.is_disabled()
  return vim.g.minijump_disable == true or vim.b.minijump_disable == true
end

---- Various helpers
function H.map(mode, key, command)
  vim.api.nvim_set_keymap(mode, key, command, { expr = true, noremap = true })
end

function H.escape(s)
  return vim.api.nvim_replace_termcodes(s, true, true, true)
end

-- stylua: ignore start
H.keys = {
  bs        = H.escape('<bs>'),
  cr        = H.escape('<cr>'),
  del       = H.escape('<del>'),
  cmd_start = H.escape('<cmd>'),
  cmd_end   = H.escape('<cr>'),
  keep_undo = H.escape('<C-g>U'),
  -- NOTE: use `get_arrow_key()` instead of `H.keys.left` or `H.keys.right`
  left      = H.escape('<left>'),
  right     = H.escape('<right>')
}
-- stylua: ignore end

function H.get_arrow_key(key)
  if vim.fn.mode() == 'i' then
    -- Using left/right keys in insert mode breaks undo sequence and, more
    -- importantly, dot-repeat. To avoid this, use 'i_CTRL-G_U' mapping.
    return H.keys.keep_undo .. H.keys[key]
  else
    return H.keys[key]
  end
end

function H.is_in_table(val, tbl)
  if tbl == nil then
    return false
  end
  for _, value in pairs(tbl) do
    if val == value then
      return true
    end
  end
  return false
end

function H.get_char()
  return vim.fn.nr2char(vim.fn.getchar())
end

return MiniJump
