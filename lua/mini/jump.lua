-- MIT License Copyright (c) 2021 Evgeni Chasnovski, Adam Blažek

-- Documentation ==============================================================
--- Minimal and fast module for smarter jumping to a single character. Inspired
--- by 'rhysd/clever-f.vim'.
---
--- Features:
--- - Extend f, F, t, T to work on multiple lines.
--- - Repeat jump by pressing f, F, t, T again. It is reset when cursor moved
---   as a result of not jumping or timeout after idle time (duration
---   customizable).
--- - Highlight (after customizable delay) of all possible target characters.
--- - Normal, Visual, and Operator-pending (with full dot-repeat) modes are
---   supported.
---
--- # Setup~
---
--- This module needs a setup with `require('mini.jump').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniJump` which you can use for scripting or manually (with
--- `:lua MiniJump.*`).
---
--- See |MiniJump.config| for `config` structure and default values.
---
--- # Highlight groups~
---
--- - `MiniJump` - all possible cursor positions.
---
--- # Disabling~
---
--- To disable core functionality, set `g:minijump_disable` (globally) or
--- `b:minijump_disable` (for a buffer) to `v:true`. Considering high number of
--- different scenarios and customization intentions, writing exact rules for
--- disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes.
---@tag mini.jump
---@tag MiniJump
---@toc_entry Jump cursor

---@alias __target string The string to jump to.
---@alias __backward boolean Whether to jump backward.
---@alias __till boolean Whether to jump just before/after the match instead of
---   exactly on target. Also ignore matches that have nothing before/after them.
---@alias __n_times number Number of times to perform consecutive jumps.

-- Module definition ==========================================================
local MiniJump = {}
local H = {}

--- Module setup
---
---@param config table Module config table. See |MiniJump.config|.
---
---@usage `require('mini.jump').setup({})` (replace `{}` with your `config` table)
function MiniJump.setup(config)
  -- Export module
  _G.MiniJump = MiniJump

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  vim.api.nvim_exec(
    [[augroup MiniJump
        au!
        au CursorMoved * lua MiniJump.on_cursormoved()
        au BufLeave,InsertEnter * lua MiniJump.stop_jumping()
      augroup END]],
    false
  )

  -- Highlight groups
  vim.cmd([[hi default link MiniJump SpellRare]])
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniJump.config = {
  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    forward = 'f',
    backward = 'F',
    forward_till = 't',
    backward_till = 'T',
    repeat_jump = ';',
  },

  -- Delay values (in ms) for different functionalities. Set any of them to
  -- a very big number (like 10^7) to virtually disable.
  delay = {
    -- Delay between jump and highlighting all possible jumps
    highlight = 250,

    -- Delay between jump and automatic stop if idle (no jump is done)
    idle_stop = 10000000,
  },

  -- DEPRECATION NOTICE: `highlight_delay` is now deprecated, please use
  -- `delay.highlight` instead
}
--minidoc_afterlines_end

-- Module data ================================================================
--- Data about jumping state
---
--- It stores various information used in this module. All elements, except
--- `jumping`, is about the latest jump. They are used as default values for
--- similar arguments.
---
---@class JumpingState
---
---@field target __target
---@field backward __backward
---@field till __till
---@field n_times __n_times
---@field mode string Mode of latest jump (output of |mode()| with non-zero argument).
---@field jumping boolean Whether module is currently in "jumping mode": usage of
---   |MiniJump.smart_jump| and all mappings won't require target.
---@text
--- Initial values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniJump.state = {
  target = nil,
  backward = false,
  till = false,
  n_times = 1,
  mode = nil,
  jumping = false,
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Jump to target
---
--- Takes a string and jumps to its first occurrence in desired direction.
---
--- All default values are taken from |MiniJump.state| to emulate latest jump.
---
---@param target __target
---@param backward __backward
---@param till __till
---@param n_times __n_times
function MiniJump.jump(target, backward, till, n_times)
  if H.is_disabled() then
    return
  end

  -- Cache inputs for future use
  H.update_state(target, backward, till, n_times)

  if MiniJump.state.target == nil then
    H.notify('Can not jump because there is no recent `target`.')
    return
  end

  -- Determine if target is present anywhere in order to correctly enter
  -- jumping mode. If not, jumping mode is not possible.
  local escaped_target = vim.fn.escape(MiniJump.state.target, [[\]])
  local search_pattern = ([[\V%s]]):format(escaped_target)
  local target_is_present = vim.fn.search(search_pattern, 'wn') ~= 0
  if not target_is_present then
    return
  end

  -- Construct search and highlight patterns
  local flags = MiniJump.state.backward and 'Wb' or 'W'
  local pattern, hl_pattern = [[\V%s]], [[\V%s]]
  if MiniJump.state.till then
    if MiniJump.state.backward then
      pattern, hl_pattern = [[\V\(%s\)\@<=\.]], [[\V%s\.\@=]]
      flags = ('%se'):format(flags)
    else
      pattern, hl_pattern = [[\V\.\(%s\)\@=]], [[\V\.\@<=%s]]
    end
  end

  pattern, hl_pattern = pattern:format(escaped_target), hl_pattern:format(escaped_target)

  -- Delay highlighting after stopping previous one
  H.timers.highlight:stop()
  H.timers.highlight:start(
    -- Update highlighting immediately if any highlighting is already present
    H.is_highlighting() and 0 or MiniJump.config.delay.highlight,
    0,
    vim.schedule_wrap(function()
      H.highlight(hl_pattern)
    end)
  )

  -- Start idle timer after stopping previous one
  H.timers.idle_stop:stop()
  H.timers.idle_stop:start(
    MiniJump.config.delay.idle_stop,
    0,
    vim.schedule_wrap(function()
      MiniJump.stop_jumping()
    end)
  )

  -- Make jump(s)
  H.n_cursor_moved = 0
  MiniJump.state.jumping = true
  for _ = 1, MiniJump.state.n_times do
    vim.fn.search(pattern, flags)
  end

  -- Open enough folds to show jump
  vim.cmd([[normal! zv]])
end

--- Make smart jump
---
--- If the last movement was a jump, perform another jump with the same target.
--- Otherwise, wait for a target input (via |getchar()|). Respects |v:count|.
---
--- All default values are taken from |MiniJump.state| to emulate latest jump.
---
---@param backward __backward
---@param till __till
function MiniJump.smart_jump(backward, till)
  if H.is_disabled() then
    return
  end

  -- Jumping should stop after mode change. Use `mode(1)` to track 'omap' case.
  local cur_mode = vim.fn.mode(1)
  if MiniJump.state.mode ~= cur_mode then
    MiniJump.stop_jumping()
  end

  -- Ask for target only when needed
  local target
  if not MiniJump.state.jumping or MiniJump.state.target == nil then
    target = H.get_target()
    -- Stop if user supplied invalid target
    if target == nil then
      return
    end
  end

  H.update_state(target, backward, till, vim.v.count1)

  MiniJump.jump()
end

--- Make expression jump
---
--- Cache information about the jump and return string with command to perform
--- jump. Designed to be used inside Operator-pending mapping (see
--- |omap-info|). Always asks for target (via |getchar()|). Respects |v:count|.
---
--- All default values are taken from |MiniJump.state| to emulate latest jump.
---
---@param backward __backward
---@param till __till
function MiniJump.expr_jump(backward, till)
  if H.is_disabled() then
    return ''
  end

  -- Always ask for `target` as this will be used only in operator-pending
  -- mode. Dot-repeat will be implemented via expression-mapping.
  local target = H.get_target()
  -- Stop if user supplied invalid target
  if target == nil then
    return
  end
  H.update_state(target, backward, till, vim.v.count1)

  return vim.api.nvim_replace_termcodes('v:<C-u>lua MiniJump.jump()<CR>', true, true, true)
end

--- Stop jumping
---
--- Removes highlights (if any) and forces the next smart jump to prompt for
--- the target. Automatically called on appropriate Neovim |events|.
function MiniJump.stop_jumping()
  H.timers.highlight:stop()
  H.timers.idle_stop:stop()
  MiniJump.state.jumping = false
  H.unhighlight()
end

--- Act on |CursorMoved|
function MiniJump.on_cursormoved()
  -- Check if jumping to avoid unnecessary actions on every CursorMoved
  if MiniJump.state.jumping then
    H.n_cursor_moved = H.n_cursor_moved + 1
    -- Stop jumping only if `CursorMoved` was not a result of smart jump
    if H.n_cursor_moved > 1 then
      MiniJump.stop_jumping()
    end
  end
end

-- Helper data ================================================================
-- Module default config
H.default_config = MiniJump.config

-- Counter of number of CursorMoved events
H.n_cursor_moved = 0

-- Timers for different delay-related functionalities
H.timers = { highlight = vim.loop.new_timer(), idle_stop = vim.loop.new_timer() }

-- Information about last match highlighting (stored *per window*):
-- - Key: windows' unique buffer identifiers.
-- - Value: table with:
--     - `id` field for match id (from `vim.fn.matchadd()`).
--     - `pattern` field for highlighted pattern.
H.window_matches = {}

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  -- Soft deprecate `config.highlight_delay`
  if config.highlight_delay then
    H.notify('`highlight_delay` is now deprecated. Please use `delay.highlight` instead.')
    config.delay.highlight = config.highlight_delay
  end

  -- Validate per nesting level to produce correct error message
  vim.validate({
    mappings = { config.mappings, 'table' },
    delay = { config.delay, 'table' },
  })

  vim.validate({
    ['delay.highlight'] = { config.delay.highlight, 'number' },
    ['delay.idle_stop'] = { config.delay.idle_stop, 'number' },

    ['mappings.forward'] = { config.mappings.forward, 'string' },
    ['mappings.backward'] = { config.mappings.backward, 'string' },
    ['mappings.forward_till'] = { config.mappings.forward_till, 'string' },
    ['mappings.backward_till'] = { config.mappings.backward_till, 'string' },
    ['mappings.repeat_jump'] = { config.mappings.repeat_jump, 'string' },
  })

  return config
end

function H.apply_config(config)
  MiniJump.config = config

  H.map('n', config.mappings.forward, [[<Cmd>lua MiniJump.smart_jump(false, false)<CR>]])
  H.map('n', config.mappings.backward, [[<Cmd>lua MiniJump.smart_jump(true, false)<CR>]])
  H.map('n', config.mappings.forward_till, [[<Cmd>lua MiniJump.smart_jump(false, true)<CR>]])
  H.map('n', config.mappings.backward_till, [[<Cmd>lua MiniJump.smart_jump(true, true)<CR>]])
  H.map('n', config.mappings.repeat_jump, [[<Cmd>lua MiniJump.jump()<CR>]])

  H.map('x', config.mappings.forward, [[<Cmd>lua MiniJump.smart_jump(false, false)<CR>]])
  H.map('x', config.mappings.backward, [[<Cmd>lua MiniJump.smart_jump(true, false)<CR>]])
  H.map('x', config.mappings.forward_till, [[<Cmd>lua MiniJump.smart_jump(false, true)<CR>]])
  H.map('x', config.mappings.backward_till, [[<Cmd>lua MiniJump.smart_jump(true, true)<CR>]])
  H.map('x', config.mappings.repeat_jump, [[<Cmd>lua MiniJump.jump()<CR>]])

  H.map('o', config.mappings.forward, [[v:lua.MiniJump.expr_jump(v:false, v:false)]], { expr = true })
  H.map('o', config.mappings.backward, [[v:lua.MiniJump.expr_jump(v:true, v:false)]], { expr = true })
  H.map('o', config.mappings.forward_till, [[v:lua.MiniJump.expr_jump(v:false, v:true)]], { expr = true })
  H.map('o', config.mappings.backward_till, [[v:lua.MiniJump.expr_jump(v:true, v:true)]], { expr = true })
  H.map('o', config.mappings.repeat_jump, [[v:lua.MiniJump.expr_jump()]], { expr = true })
end

function H.is_disabled()
  return vim.g.minijump_disable == true or vim.b.minijump_disable == true
end

-- Highlighting ---------------------------------------------------------------
function H.highlight(pattern)
  -- Don't do anything if already highlighting input pattern
  if H.is_highlighting(pattern) then
    return
  end

  -- Stop highlighting possible previous pattern. Needed to adjust highlighting
  -- when inside jumping but a different kind one. Example: first jump with
  -- `till = false` and then, without jumping stop, jump to same character with
  -- `till = true`. If this character is first on line, highlighting should change
  H.unhighlight()

  local match_id = vim.fn.matchadd('MiniJump', pattern)
  H.window_matches[vim.api.nvim_get_current_win()] = { id = match_id, pattern = pattern }
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

---@param pattern string Highlight pattern to check for. If `nil`, checks for
---   any highlighting registered in current window.
---@private
function H.is_highlighting(pattern)
  local win_id = vim.api.nvim_get_current_win()
  local match_info = H.window_matches[win_id]
  if match_info == nil then
    return false
  end
  return pattern == nil or match_info.pattern == pattern
end

-- Utilities ------------------------------------------------------------------
function H.notify(msg)
  vim.notify(('(mini.jump) %s'):format(msg))
end

function H.update_state(target, backward, till, n_times)
  MiniJump.state.mode = vim.fn.mode(1)

  -- Don't use `? and <1> or <2>` because it doesn't work when `<1>` is `false`
  if target ~= nil then
    MiniJump.state.target = target
  end
  if backward ~= nil then
    MiniJump.state.backward = backward
  end
  if till ~= nil then
    MiniJump.state.till = till
  end
  if n_times ~= nil then
    MiniJump.state.n_times = n_times
  end
end

function H.get_target()
  local needs_help_msg = true
  vim.defer_fn(function()
    if not needs_help_msg then
      return
    end
    H.notify('Enter target single character ')
  end, 1000)
  local ok, char = pcall(vim.fn.getchar)
  needs_help_msg = false

  -- Terminate if couldn't get input (like with <C-c>) or it is `<Esc>`
  if not ok or char == 27 then
    return
  end

  if type(char) == 'number' then
    char = vim.fn.nr2char(char)
  end
  return char
end

function H.map(mode, key, rhs, opts)
  if key == '' then
    return
  end

  opts = vim.tbl_deep_extend('force', { noremap = true }, opts or {})
  vim.api.nvim_set_keymap(mode, key, rhs, opts)
end

return MiniJump
