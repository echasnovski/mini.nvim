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
--- <code>
---   {
---     -- Mappings. Use `''` (empty string) to disable one.
---     mappings = {
---       forward_1 = 'f',
---       backward_1 = 'F',
---       forward_1_till = 't',
---       backward_1_till = 'T',
---     },
---
---     -- Highlight matches when jumping
---     highlight = true,
---   }
--- </code>
--- # Disabling
---
--- To disable core functionality, set `g:minijump_disable` (globally) or
--- `b:minijump_disable` (for a buffer) to `v:true`.
---@brief ]]
---@tag MiniJump mini.jump

-- Module and its helper
local MiniJump = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.jump').setup({})` (replace `{}` with your `config` table)
function MiniJump.setup(config)
  -- Export module
  _G.MiniJump = MiniJump

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  vim.cmd([[autocmd CursorMoved * lua MiniJump.on_cursormoved()]])
  vim.cmd([[autocmd BufLeave,InsertEnter * lua MiniJump.stop_jumping()]])

  -- Highlight groups
  vim.cmd([[hi default link MiniJumpHighlight IncSearch]])
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
--- Jump to target
---
--- Takes a string and jumps to the first occurence of it after the cursor.
---
--- @param target string: The string to jump to.
--- @param backward boolean: If `true`, jump backward.
--- @param till boolean: If `true`, jump just before/after the match instead of to the first character.
---   Also ignore matches that don't have space before/after them. (This will probably be changed in the future.)
function MiniJump.jump(target, backward, till)
  if H.is_disabled() then
    return
  end

  backward = backward == nil and false or backward
  till = till == nil and false or till

  local flags = backward and 'Wb' or 'W'
  local pattern, hl_pattern = [[\V%s]], [[\V%s]]
  if till then
    if backward then
      pattern, hl_pattern = [[\V\(%s\)\@<=\.]], [[\V%s\.\@=]]
      flags = flags .. 'e'
    else
      pattern, hl_pattern = [[\V\.\(%s\)\@=]], [[\V\.\@<=%s]]
    end
  end

  target = vim.fn.escape(target, [[\]])
  pattern, hl_pattern = pattern:format(target), hl_pattern:format(target)

  H.highlight(hl_pattern)
  vim.fn.search(pattern, flags)
  -- Open enough folds to show jump
  vim.cmd([[normal! zv]])
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
  if H.is_disabled() then
    return
  end

  num_chars = num_chars or 1
  backward = backward == nil and false or backward
  till = till == nil and false or till

  H.target = H.target or H.get_chars(num_chars)
  for _ = 1, vim.v.count1 do
    MiniJump.jump(H.target, backward, till)
  end

  H.jumping = true
end

--- Stop jumping
---
--- Removes highlights (if any) and forces the next smart jump to prompt for
--- the target.
function MiniJump.stop_jumping()
  H.target = nil
  H.unhighlight()
end

--- Act on every |CursorMoved|
function MiniJump.on_cursormoved()
  -- Stop jumping only if `CursorMoved` was not a result of smart jump
  if not H.jumping then
    MiniJump.stop_jumping()
  end
  H.jumping = false
end

-- Helpers
---- Module default config
H.default_config = MiniJump.config

---- Current target
H.target = nil

---- Indicator of whether inside smart jumping
H.jumping = false

---- Information about last match highlighting (stored *per window*):
---- - Key: windows' unique buffer identifiers.
---- - Value: table with:
----     - `id` field for match id (from `vim.fn.matchadd()`).
----     - `pattern` field for highlighted pattern.
H.window_matches = {}

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

function H.get_chars(num_chars)
  local chars = ''
  for _ = 1, num_chars do
    chars = chars .. vim.fn.nr2char(vim.fn.getchar())
  end
  return chars
end

function H.highlight(pattern)
  if not MiniJump.config.highlight then
    H.unhighlight()
    return
  end

  local win_id = vim.api.nvim_get_current_win()
  local match_info = H.window_matches[win_id]

  -- Don't do anything if already highlighting input pattern
  if match_info and match_info.pattern == pattern then
    return
  end

  -- Stop highlighting possible previous pattern. Needed to adjust highlighting
  -- when inside jumping but a different kind one. Example: first jump with
  -- `till = false` and then, without jumping stop, jump to same character with
  -- `till = true`. If this character is first on line, highlighting should change
  H.unhighlight()

  local match_id = vim.fn.matchadd('MiniJumpHighlight', pattern)
  H.window_matches[win_id] = { id = match_id, pattern = pattern }
end

function H.unhighlight()
  -- Remove highlighting from all windows as jumping is intended to work only
  -- in current window. This will work also from other (usually popup) window.
  for win_id, match_info in pairs(H.window_matches) do
    if vim.api.nvim_win_is_valid(win_id) then
      -- Use `pcall` because there is an error if match id is not present. It
      -- can happen if something else called `clearmatches`.
      pcall(vim.fn.matchdelete, match_info.id, win_id)
      H.window_matches[win_id] = nil
    end
  end
end

return MiniJump
