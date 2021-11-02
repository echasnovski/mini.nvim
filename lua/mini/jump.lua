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
---@tag MiniJump mini.jump

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
H.target = nil

--- Jump to target
---
--- Takes a string and jumps to the first occurence of it after the cursor.
---
--- @param target string: The string to jump to.
--- @param backward boolean: If true, jump backward.
--- @param till boolean: If true, jump just before/after the match instead of to the first character.
---   Also ignore matches that don't have space before/after them. (This will probably be changed in the future.)
function MiniJump.jump(target, backward, till)
  backward = backward or false
  till = till or false
  local flags = 'W'
  if backward then
    flags = flags .. 'b'
  end
  local pattern = [[\V%s]]
  if till then
    if backward then
      pattern = [[\V%s\.]]
      flags = flags .. 'e'
    else
      pattern = [[\V\.%s]]
    end
  end
  pattern = pattern:format(vim.fn.escape(target, [[\]]))
  vim.fn.search(pattern, flags)
end

--- Smart jump
---
--- If the last movement was a jump, perform another jump with the same target.
--- Otherwise, prompt for a target. Respects v:count.
---
--- @param num_chars number: The length of the target to prompt for.
--- @param backward boolean: If true, jump backward.
--- @param till boolean: If true, jump just before/after the match instead of to the first character.
---   Also ignore matches that don't have space before/after them. (This will probably be changed in the future.)
function MiniJump.smart_jump(num_chars, backward, till)
  num_chars = num_chars or 1
  backward = backward or false
  till = till or false
  local target = H.target or H.get_chars(num_chars)
  MiniJump.jump(target, backward, till)
  for _ = 2, vim.v.count do
    MiniJump.jump(target, backward, till)
  end
  -- This has to be scheduled so it doesn't get overridden by CursorMoved from the jump.
  vim.schedule(function()
    H.target = target
  end)
end

--- Reset target
---
--- Forces the next smart jump to prompt for the target.
--- Triggered automatically on CursorMoved, but can be also triggered manually.
function MiniJump.reset_target()
  H.target = nil
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

  if config.map_ft then
    local modes = { 'n', 'o', 'x' }
    for _, mode in ipairs(modes) do
      H.map_cmd(mode, 'f', [[lua MiniJump.smart_jump(1, false, false)]])
      H.map_cmd(mode, 'F', [[lua MiniJump.smart_jump(1, true, false)]])
      H.map_cmd(mode, 't', [[lua MiniJump.smart_jump(1, false, true)]])
      H.map_cmd(mode, 'T', [[lua MiniJump.smart_jump(1, true, true)]])
      vim.cmd([[autocmd CursorMoved * lua MiniJump.reset_target()]])
    end
  end
end

function H.is_disabled()
  return vim.g.minijump_disable == true or vim.b.minijump_disable == true
end

---- Various helpers
function H.map_cmd(mode, key, command)
  local rhs = ('<cmd>%s<cr>'):format(command)
  if mode == 'o' then
    rhs = 'v' .. rhs
  end
  vim.api.nvim_set_keymap(mode, key, rhs, { noremap = true })
end

function H.escape(s)
  return vim.api.nvim_replace_termcodes(s, true, true, true)
end

-- stylua: ignore start
H.keys = {
  bs        = H.escape('<bs>'),
  cr        = H.escape('<cr>'),
  del       = H.escape('<del>'),
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

function H.get_chars(num_chars)
  local chars = ''
  for _ = 1, num_chars do
    chars = chars .. vim.fn.nr2char(vim.fn.getchar())
  end
  return chars
end

return MiniJump
