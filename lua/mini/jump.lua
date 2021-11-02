-- MIT License Copyright (c) 2021 Evgeni Chasnovski, Adam Blažek

---@brief [[
--- A module for smarter jumping, inspired by clever-f.
--- By default it extends f, F, t, T to work on multiple lines,
--- be repeatable by pressing f, F, t, T again,
--- and highlight characters they're going to jump to.
---
--- # Setup
---
--- This module needs a setup with `require('mini.jump').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`:
--- <pre>
--- {
---   -- Mappings. Use `''` (empty string) to disable one.
---   mappings = {
---     forward_1 = 'f',
---     backward_1 = 'F',
---     forward_1_till = 't',
---     backward_1_till = 'T',
---   },
---   -- Highlight matches when jumping.
---   highlight = true,
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
  mappings = {
    forward_1 = 'f',
    backward_1 = 'F',
    forward_1_till = 't',
    backward_1_till = 'T',
  },
  -- Highlight matches when jumping.
  highlight = true,
}

-- Module functionality
H.jumping = false
vim.cmd([[highlight link MiniJumpHighlight Search]])

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
  local hl_pattern = [[\V%s]]
  if till then
    if backward then
      pattern = [[\V%s\.]]
      hl_pattern = [[\V%s\ze\.]]
      flags = flags .. 'e'
    else
      pattern = [[\V\.%s]]
      hl_pattern = [[\V\.\zs%s]]
    end
  end
  pattern = pattern:format(vim.fn.escape(target, [[\]]))
  hl_pattern = hl_pattern:format(vim.fn.escape(target, [[\]]))
  vim.fn.search(pattern, flags)
  H.highlight(hl_pattern)
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
  H.target = H.target or H.get_chars(num_chars)
  MiniJump.jump(H.target, backward, till)
  for _ = 2, vim.v.count do
    MiniJump.jump(H.target, backward, till)
  end
  H.jumping = true
  vim.schedule(function()
    H.jumping = false
  end)
end

--- Reset target
---
--- Removes highlights (if any) and forces the next smart jump to prompt for the target.
--- Triggered automatically on CursorMoved, but can be also triggered manually.
function MiniJump.reset_target()
  if not H.jumping then
    H.target = nil
    H.reset_highlight()
  end
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
    mappings = { config.mappings, 'table' },
    ['mappings.forward_1'] = { config.mappings.forward_1, 'string' },
    ['mappings.backward_1'] = { config.mappings.forward_1, 'string' },
    ['mappings.forward_1_till'] = { config.mappings.forward_1, 'string' },
    ['mappings.backward_1_till'] = { config.mappings.forward_1, 'string' },
    highlight = { config.highlight, 'boolean' },
  })

  return config
end

function H.apply_config(config)
  MiniJump.config = config

  local modes = { 'n', 'o', 'x' }
  H.map_cmd(modes, config.mappings.forward_1, [[lua MiniJump.smart_jump(1, false, false)]])
  H.map_cmd(modes, config.mappings.backward_1, [[lua MiniJump.smart_jump(1, true, false)]])
  H.map_cmd(modes, config.mappings.forward_1_till, [[lua MiniJump.smart_jump(1, false, true)]])
  H.map_cmd(modes, config.mappings.backward_1_till, [[lua MiniJump.smart_jump(1, true, true)]])
  vim.cmd([[autocmd BufLeave,CursorMoved,InsertEnter * lua MiniJump.reset_target()]])
end

function H.is_disabled()
  return vim.g.minijump_disable == true or vim.b.minijump_disable == true
end

---- Various helpers
function H.map_cmd(modes, key, command)
  if key == '' then
    return
  end
  for _, mode in ipairs(modes) do
    local rhs = ('<cmd>%s<cr>'):format(command)
    if mode == 'o' then
      rhs = 'v' .. rhs
    end
    vim.api.nvim_set_keymap(mode, key, rhs, { noremap = true })
  end
end

function H.escape(s)
  return vim.api.nvim_replace_termcodes(s, true, true, true)
end

function H.get_chars(num_chars)
  local chars = ''
  for _ = 1, num_chars do
    chars = chars .. vim.fn.nr2char(vim.fn.getchar())
  end
  return chars
end

function H.highlight(pattern)
  if MiniJump.config.highlight then
    H.reset_highlight()
    H.match_id = vim.fn.matchadd('MiniJumpHighlight', pattern)
  end
end

function H.reset_highlight()
  if H.match_id then
    vim.fn.matchdelete(H.match_id)
    H.match_id = nil
  end
end

return MiniJump
