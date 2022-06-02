-- MIT License Copyright (c) 2021 Evgeni Chasnovski

-- Documentation ==============================================================
--- Minimal and fast module for working with trailing whitespace.
---
--- Features:
--- - Highlighting is done only in modifiable buffer by default; only in Normal
---   mode; stops in Insert mode and when leaving window.
--- - Trim all trailing whitespace with |MiniTrailspace.trim()| function.
---
--- # Setup~
---
--- This module needs a setup with `require('mini.trailspace').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniTrailspace` which you can use for scripting or manually (with
--- `:lua MiniTrailspace.*`).
---
--- See |MiniTrailspace.config| for `config` structure and default values.
---
--- # Highlight groups~
---
--- * `MiniTrailspace` - highlight group for trailing space.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling~
---
--- To disable, set `g:minitrailspace_disable` (globally) or
--- `b:minitrailspace_disable` (for a buffer) to `v:true`. Considering high
--- number of different scenarios and customization intentions, writing exact
--- rules for disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes. Note: after disabling
--- there might be highlighting left; it will be removed after next
--- highlighting update (see |events| and `MiniTrailspace` |augroup|).
---@tag mini.trailspace
---@tag MiniTrailspace
---@toc_entry Trailspace (highlight and remove)

-- Module definition ==========================================================
local MiniTrailspace = {}
local H = {}

--- Module setup
---
---@param config table Module config table. See |MiniTrailspace.config|.
---
---@usage `require('mini.trailspace').setup({})` (replace `{}` with your `config` table)
function MiniTrailspace.setup(config)
  -- Export module
  _G.MiniTrailspace = MiniTrailspace

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  -- NOTE: Respecting both `WinEnter` and `BufEnter` seems to be useful to
  -- account of different order of handling buffer opening in new window.
  -- Notable example: 'nvim-tree' at commit a1600e5.
  vim.api.nvim_exec(
    [[augroup MiniTrailspace
        au!
        au WinEnter,BufEnter,InsertLeave * lua MiniTrailspace.highlight()
        au WinLeave,BufLeave,InsertEnter * lua MiniTrailspace.unhighlight()
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
  vim.api.nvim_exec('hi default link MiniTrailspace Error', false)

  -- Initialize highlight (usually takes effect during startup)
  vim.defer_fn(MiniTrailspace.highlight, 0)
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniTrailspace.config = {
  -- Highlight only in normal buffers (ones with empty 'buftype'). This is
  -- useful to not show trailing whitespace where it usually doesn't matter.
  only_in_normal_buffers = true,
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Highlight trailing whitespace in current window
function MiniTrailspace.highlight()
  -- Highlight only in normal mode
  if H.is_disabled() or vim.fn.mode() ~= 'n' then
    MiniTrailspace.unhighlight()
    return
  end

  -- Possibly work only in normal buffers
  if MiniTrailspace.config.only_in_normal_buffers and not H.is_buffer_normal() then
    return
  end

  -- Don't add match id on top of existing one
  --stylua: ignore
  if H.get_match_id() ~= nil then return end

  vim.fn.matchadd('MiniTrailspace', [[\s\+$]])
end

--- Unhighlight trailing whitespace in current window
function MiniTrailspace.unhighlight()
  -- Use `pcall` because there is an error if match id is not present. It can
  -- happen if something else called `clearmatches`.
  pcall(vim.fn.matchdelete, H.get_match_id())
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

-- Helper data ================================================================
-- Module default config
H.default_config = MiniTrailspace.config

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
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

function H.get_match_id()
  -- NOTE: this can be replaced with more efficient custom tracking of id per
  -- window but it will have more edge cases (like won't update on manual
  -- `clearmatches()`)
  for _, match in ipairs(vim.fn.getmatches()) do
    if match.group == 'MiniTrailspace' then
      return match.id
    end
  end
end

return MiniTrailspace
