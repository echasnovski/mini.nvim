-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom minimal and fast module for working with trailing whitespace.
---
--- Features:
--- - Highlighting is done only in modifiable buffer by default; only in Normal
---   mode; stops in Insert mode and when leaving window.
--- - Trim all trailing whitespace with |MiniTrailspace.trim()| function.
---
--- # Setup
---
--- This module needs a setup with `require('mini.trailspace').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`: {} (currently nothing to configure)
---
--- # Highlight groups
---
--- 1. `MiniTrailspace` - highlight group for trailing space.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling
---
--- To disable, set `g:minitrailspace_disable` (globally) or
--- `b:minitrailspace_disable` (for a buffer) to `v:true`.  Note: after
--- disabling there might be highlighting left; it will be removed after next
--- highlighting update (see |events| and `MiniTrailspace` |augroup|).
---@brief ]]
---@tag MiniTrailspace mini.trailspace

-- Module and its helper
local MiniTrailspace = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.trailspace').setup({})` (replace `{}` with your `config` table)
function MiniTrailspace.setup(config)
  -- Export module
  _G.MiniTrailspace = MiniTrailspace

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  -- Use `defer_fn` for `MiniTrailspace.highlight` to ensure that
  -- 'modifiable' option is set to its final value.
  vim.api.nvim_exec(
    [[augroup MiniTrailspace
        au!
        au WinEnter,BufWinEnter,InsertLeave * lua vim.defer_fn(MiniTrailspace.highlight, 0)
        au WinLeave,BufWinLeave,InsertEnter * lua MiniTrailspace.unhighlight()

        au FileType TelescopePrompt let b:minitrailspace_disable=v:true
      augroup END]],
    false
  )

  -- Create highlighting
  vim.api.nvim_exec([[hi link MiniTrailspace Error]], false)
end

-- Module config
MiniTrailspace.config = {}

-- Functions to perform actions
--- Highlight trailing whitespace
---
---@param check_modifiable boolean: Whether to check |modifiable| (if it is off, don't highlight). Default: `true`.
function MiniTrailspace.highlight(check_modifiable)
  check_modifiable = check_modifiable or true

  -- Highlight only in normal mode
  if H.is_disabled() or vim.fn.mode() ~= 'n' then
    MiniTrailspace.unhighlight()
    return
  end

  if check_modifiable and not vim.bo.modifiable then
    return
  end

  local win_id = vim.fn.win_getid()
  local win_match = H.window_matches[win_id]

  -- Don't add match id on top of existing one
  if win_match == nil then
    H.window_matches[win_id] = vim.fn.matchadd('MiniTrailspace', [[\s\+$]])
  end
end

--- Unhighlight trailing whitespace
function MiniTrailspace.unhighlight()
  local win_id = vim.fn.win_getid()
  local win_match = H.window_matches[win_id]
  if win_match ~= nil then
    vim.fn.matchdelete(win_match)
    H.window_matches[win_id] = nil
  end
end

--- Trim trailing whitespace
function MiniTrailspace.trim()
  -- Save cursor position to later restore
  local curpos = vim.api.nvim_win_get_cursor(0)
  -- Search and replace trailing whitespace
  vim.cmd([[keeppatterns %s/\s\+$//e]])
  vim.api.nvim_win_set_cursor(0, curpos)
end

-- Helper data
---- Module default config
H.default_config = MiniTrailspace.config

-- Information about last match highlighting: word and match id (returned from
-- `vim.fn.matchadd()`). Stored *per window* by its unique identifier.
H.window_matches = {}

---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  return config
end

function H.apply_config(config)
  -- There is nothing to do yet
end

function H.is_disabled()
  return vim.g.minitrailspace_disable == true or vim.b.minitrailspace_disable == true
end

return MiniTrailspace
