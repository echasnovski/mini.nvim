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
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniTrailspace` which you can use for scripting or manually (with
--- `:lua MiniTrailspace.*`).
---
--- Default `config`:
--- <code>
---   {
---     -- Highlight only in normal buffers (ones with empty 'buftype'). This is
---     -- useful to not show trailing whitespace where it usually doesn't matter.
---     only_in_normal_buffers = true,
---   }
--- </code>
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
        au WinEnter,BufEnter,InsertLeave * lua MiniTrailspace.highlight()
        au WinLeave,BufLeave,InsertEnter * lua MiniTrailspace.unhighlight()

        au FileType TelescopePrompt let b:minitrailspace_disable=v:true
      augroup END]],
    false
  )

  if config.only_in_normal_buffers then
    -- Add tracking of 'buftype' changing because it can be set after events on
    -- which highlighting is done. If not done, highlighting appears but
    -- disappears if buffer is reentered.
    vim.api.nvim_exec(
      [[augroup MiniTrailspace
          au OptionSet buftype lua MiniTrailspace.track_normal_buffer()
        augroup END]],
      false
    )
  end

  -- Create highlighting
  vim.api.nvim_exec([[hi default link MiniTrailspace Error]], false)
end

-- Module config
MiniTrailspace.config = {
  -- Highlight only in normal buffers (ones with empty 'buftype'). This is
  -- useful to not show trailing whitespace where it usually doesn't matter.
  only_in_normal_buffers = true,
}

-- Functions to perform actions
--- Highlight trailing whitespace
function MiniTrailspace.highlight()
  -- Highlight only in normal mode
  if H.is_disabled() or vim.fn.mode() ~= 'n' then
    MiniTrailspace.unhighlight()
    return
  end

  if MiniTrailspace.config.only_in_normal_buffers and not H.is_buffer_normal() then
    return
  end

  local win_id = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  -- Don't add match id on top of existing one
  if H.window_matches[win_id] == nil then
    local match_id = vim.fn.matchadd('MiniTrailspace', [[\s\+$]])
    H.window_matches[win_id] = { id = match_id }
  end
end

--- Unhighlight trailing whitespace
function MiniTrailspace.unhighlight()
  local win_id = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  local win_match = H.window_matches[win_id]
  if win_match ~= nil then
    -- Use `pcall` because there is an error if match id is not present. It can
    -- happen if something else called `clearmatches`.
    pcall(vim.fn.matchdelete, win_match.id)
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

--- Track normal buffer
---
--- Designed to be used with |autocmd|. No need to use it directly.
function MiniTrailspace.track_normal_buffer()
  if not MiniTrailspace.config.only_in_normal_buffers then
    return
  end

  -- This should be used with 'OptionSet' event for 'buftype' option
  -- Empty 'buftype' means "normal buffer"
  if vim.v.option_new == '' then
    MiniTrailspace.highlight()
  else
    MiniTrailspace.unhighlight()
  end
end

-- Helper data
---- Module default config
H.default_config = MiniTrailspace.config

-- Information about last match highlighting (stored *per window*):
-- - Key: windows' unique buffer identifiers.
-- - Value: table with `id` field for match id (from `vim.fn.matchadd()`).
H.window_matches = {}

---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({ only_in_normal_buffers = { config.only_in_normal_buffers, 'boolean' } })

  return config
end

function H.apply_config(config)
  MiniTrailspace.config = config
end

function H.is_disabled()
  return vim.g.minitrailspace_disable == true or vim.b.minitrailspace_disable == true
end

function H.is_buffer_normal(buf_id)
  return vim.api.nvim_buf_get_option(buf_id or 0, 'buftype') == ''
end

return MiniTrailspace
