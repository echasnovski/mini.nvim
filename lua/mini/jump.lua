-- MIT License Copyright (c) 2021 Evgeni Chasnovski, Adam Blažek

-- Documentation ==============================================================
--- Smarter forward/backward jumping to a single character.
---
--- Features:
--- - Extend f, F, t, T to work on multiple lines.
--- - Repeat jump by pressing f, F, t, T again. It is reset when cursor moved
---   as a result of not jumping or timeout after idle time (duration
---   customizable).
--- - Highlight (after customizable delay) all possible target characters and
---   stop it after some (customizable) idle time.
--- - Normal, Visual, and Operator-pending (with full dot-repeat) modes are
---   supported.
---
--- This module follows vim's 'ignorecase' and 'smartcase' options. When
--- 'ignorecase' is set, f, F, t, T will match case-insensitively. When
--- 'smartcase' is also set, f, F, t, T will only match lowercase
--- characters case-insensitively.
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
--- You can override runtime config settings locally to buffer inside
--- `vim.b.minijump_config` which should have same structure as
--- `MiniJump.config`. See |mini.nvim-buffer-local-config| for more details.
---
--- # Highlight groups~
---
--- * `MiniJump` - all possible cursor positions.
---
--- To change any highlight group, modify it directly with |:highlight|.
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

---@alias __target string The string to jump to.
---@alias __backward boolean Whether to jump backward.
---@alias __till boolean Whether to jump just before/after the match instead of
---   exactly on target. This includes positioning cursor past the end of
---   previous/current line. Note that with backward jump this might lead to
---   cursor being on target if can't be put past the line.
---@alias __n_times number Number of times to perform consecutive jumps.

-- Module definition ==========================================================
local MiniJump = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniJump.config|.
---
---@usage `require('mini.jump').setup({})` (replace `{}` with your `config` table)
MiniJump.setup = function(config)
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
  vim.cmd('hi default link MiniJump SpellRare')
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
MiniJump.jump = function(target, backward, till, n_times)
  if H.is_disabled() then return end

  -- Cache inputs for future use
  H.update_state(target, backward, till, n_times)

  if MiniJump.state.target == nil then
    H.message('Can not jump because there is no recent `target`.')
    return
  end

  -- Determine if target is present anywhere in order to correctly enter
  -- jumping mode. If not, jumping mode is not possible.
  local escaped_target = vim.fn.escape(MiniJump.state.target, [[\]])
  local search_pattern = ([[\V%s]]):format(escaped_target)
  local target_is_present = vim.fn.search(search_pattern, 'wn') ~= 0
  if not target_is_present then return end

  -- Construct search and highlight pattern data
  local pattern, hl_pattern, flags = H.make_search_data()

  -- Delay highlighting after stopping previous one
  local config = H.get_config()
  H.timers.highlight:stop()
  H.timers.highlight:start(
    -- Update highlighting immediately if any highlighting is already present
    H.is_highlighting() and 0 or config.delay.highlight,
    0,
    vim.schedule_wrap(function() H.highlight(hl_pattern) end)
  )

  -- Start idle timer after stopping previous one
  H.timers.idle_stop:stop()
  H.timers.idle_stop:start(config.delay.idle_stop, 0, vim.schedule_wrap(function() MiniJump.stop_jumping() end))

  -- Make jump(s)
  H.cache.n_cursor_moved = 0
  MiniJump.state.jumping = true
  for _ = 1, MiniJump.state.n_times do
    vim.fn.search(pattern, flags)
  end

  -- Open enough folds to show jump
  vim.cmd('normal! zv')

  -- Track cursor position to account for movement not caught by `CursorMoved`
  H.cache.latest_cursor = H.get_cursor_data()
end

--- Make smart jump
---
--- If the last movement was a jump, perform another jump with the same target.
--- Otherwise, wait for a target input (via |getcharstr()|). Respects |v:count|.
---
--- All default values are taken from |MiniJump.state| to emulate latest jump.
---
---@param backward __backward
---@param till __till
MiniJump.smart_jump = function(backward, till)
  if H.is_disabled() then return end

  -- Jumping should stop after mode change (use `mode(1)` to track 'omap' case)
  -- or if cursor has moved after latest jump
  local has_changed_mode = MiniJump.state.mode ~= vim.fn.mode(1)
  local has_changed_cursor = not vim.deep_equal(H.cache.latest_cursor, H.get_cursor_data())
  if has_changed_mode or has_changed_cursor then MiniJump.stop_jumping() end

  -- Ask for target only when needed
  local target
  if not MiniJump.state.jumping or MiniJump.state.target == nil then
    target = H.get_target()
    -- Stop if user supplied invalid target
    if target == nil then return end
  end

  H.update_state(target, backward, till, vim.v.count1)

  MiniJump.jump()
end

--- Make expression jump
---
--- Cache information about the jump and return string with command to perform
--- jump. Designed to be used inside Operator-pending mapping (see
--- |omap-info|). Always asks for target (via |getcharstr()|). Respects |v:count|.
---
--- All default values are taken from |MiniJump.state| to emulate latest jump.
---
---@param backward __backward
---@param till __till
MiniJump.expr_jump = function(backward, till)
  if H.is_disabled() then return '' end

  -- Always ask for `target` as this will be used only in operator-pending
  -- mode. Dot-repeat will be implemented via expression-mapping.
  local target = H.get_target()
  -- Stop if user supplied invalid target
  if target == nil then return end
  H.update_state(target, backward, till, vim.v.count1)

  return vim.api.nvim_replace_termcodes('v<Cmd>lua MiniJump.jump()<CR>', true, true, true)
end

--- Stop jumping
---
--- Removes highlights (if any) and forces the next smart jump to prompt for
--- the target. Automatically called on appropriate Neovim |events|.
MiniJump.stop_jumping = function()
  H.timers.highlight:stop()
  H.timers.idle_stop:stop()

  MiniJump.state.jumping = false

  H.cache.n_cursor_moved = 0
  H.cache.latest_cursor = nil
  H.cache.msg_shown = false

  H.unhighlight()
end

--- Act on |CursorMoved|
MiniJump.on_cursormoved = function()
  -- Check if jumping to avoid unnecessary actions on every CursorMoved
  if MiniJump.state.jumping then
    H.cache.n_cursor_moved = H.cache.n_cursor_moved + 1
    -- Stop jumping only if `CursorMoved` was not a result of smart jump
    if H.cache.n_cursor_moved > 1 then MiniJump.stop_jumping() end
  end
end

-- Helper data ================================================================
-- Module default config
H.default_config = MiniJump.config

-- Cache for various operations
H.cache = {
  -- Counter of number of CursorMoved events
  n_cursor_moved = 0,

  -- Latest cursor position data
  latest_cursor = nil,

  -- Whether helper message was shown
  msg_shown = false,
}

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
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

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

H.apply_config = function(config)
  MiniJump.config = config

  --stylua: ignore start
  H.map('n', config.mappings.forward, '<Cmd>lua MiniJump.smart_jump(false, false)<CR>', { desc = 'Jump forward' })
  H.map('n', config.mappings.backward, '<Cmd>lua MiniJump.smart_jump(true, false)<CR>', { desc = 'Jump backward' })
  H.map('n', config.mappings.forward_till, '<Cmd>lua MiniJump.smart_jump(false, true)<CR>', { desc = 'Jump forward till' })
  H.map('n', config.mappings.backward_till, '<Cmd>lua MiniJump.smart_jump(true, true)<CR>', { desc = 'Jump backward till' })
  H.map('n', config.mappings.repeat_jump, '<Cmd>lua MiniJump.jump()<CR>', { desc = 'Repeat jump' })

  H.map('x', config.mappings.forward, '<Cmd>lua MiniJump.smart_jump(false, false)<CR>', { desc = 'Jump forward' })
  H.map('x', config.mappings.backward, '<Cmd>lua MiniJump.smart_jump(true, false)<CR>', { desc = 'Jump backward' })
  H.map('x', config.mappings.forward_till, '<Cmd>lua MiniJump.smart_jump(false, true)<CR>', { desc = 'Jump forward till' })
  H.map('x', config.mappings.backward_till, '<Cmd>lua MiniJump.smart_jump(true, true)<CR>', { desc = 'Jump backward till' })
  H.map('x', config.mappings.repeat_jump, '<Cmd>lua MiniJump.jump()<CR>', { desc = 'Repeat jump' })

  H.map('o', config.mappings.forward, 'v:lua.MiniJump.expr_jump(v:false, v:false)', { expr = true, desc = 'Jump forward' })
  H.map('o', config.mappings.backward, 'v:lua.MiniJump.expr_jump(v:true, v:false)', { expr = true, desc = 'Jump backward' })
  H.map('o', config.mappings.forward_till, 'v:lua.MiniJump.expr_jump(v:false, v:true)', { expr = true, desc = 'Jump forward till' })
  H.map('o', config.mappings.backward_till, 'v:lua.MiniJump.expr_jump(v:true, v:true)', { expr = true, desc = 'Jump backward till' })
  H.map('o', config.mappings.repeat_jump, 'v:lua.MiniJump.expr_jump()', { expr = true, desc = 'Repeat jump' })
  --stylua: ignore end
end

H.is_disabled = function() return vim.g.minijump_disable == true or vim.b.minijump_disable == true end

H.get_config =
  function(config) return vim.tbl_deep_extend('force', MiniJump.config, vim.b.minijump_config or {}, config or {}) end

-- Pattern matching -----------------------------------------------------------
H.make_search_data = function()
  local target = vim.fn.escape(MiniJump.state.target, [[\]])
  local backward, till = MiniJump.state.backward, MiniJump.state.till

  local flags = backward and 'Wb' or 'W'
  local pattern, hl_pattern

  if till then
    -- General logic: moving pattern should match just before/after target,
    -- while highlight pattern should match target for every "movable" place.
    -- Also allow checking for "just before/after" across lines by accepting
    -- `\n` as possible match.
    if backward then
      -- NOTE: use `\@<=` instead of `\zs` because it behaves better in case of
      -- consecutive matches (like `xxxx` for target `x`)
      pattern = target .. [[\@<=\_.]]
      hl_pattern = target .. [[\ze\_.]]
    else
      pattern = [[\_.\ze]] .. target
      hl_pattern = [[\_.\@<=]] .. target
    end
  else
    local is_visual = vim.tbl_contains({ 'v', 'V', '\22' }, vim.fn.mode())
    local is_exclusive = vim.o.selection == 'exclusive'
    if not backward and is_visual and is_exclusive then
      -- Still select target in case of exclusive visual selection
      pattern = target .. [[\zs\_.]]
      hl_pattern = target .. [[\ze\_.]]
    else
      pattern = target
      hl_pattern = target
    end
  end

  -- Enable 'very nomagic' mode and possibly case-insensitivity
  local ignore_case = vim.o.ignorecase and (not vim.o.smartcase or target == target:lower())
  local prefix = ignore_case and [[\V\c]] or [[\V]]
  pattern, hl_pattern = prefix .. pattern, prefix .. hl_pattern

  return pattern, hl_pattern, flags
end

-- Highlighting ---------------------------------------------------------------
H.highlight = function(pattern)
  -- Don't do anything if already highlighting input pattern
  if H.is_highlighting(pattern) then return end

  -- Stop highlighting possible previous pattern. Needed to adjust highlighting
  -- when inside jumping but a different kind one. Example: first jump with
  -- `till = false` and then, without jumping stop, jump to same character with
  -- `till = true`. If this character is first on line, highlighting should change
  H.unhighlight()

  -- Never highlight in Insert mode
  if vim.fn.mode() == 'i' then return end

  local match_id = vim.fn.matchadd('MiniJump', pattern)
  H.window_matches[vim.api.nvim_get_current_win()] = { id = match_id, pattern = pattern }
end

H.unhighlight = function()
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
H.is_highlighting = function(pattern)
  local win_id = vim.api.nvim_get_current_win()
  local match_info = H.window_matches[win_id]
  if match_info == nil then return false end
  return pattern == nil or match_info.pattern == pattern
end

-- Utilities ------------------------------------------------------------------
H.echo = function(msg, is_important)
  -- Construct message chunks
  msg = type(msg) == 'string' and { { msg } } or msg
  table.insert(msg, 1, { '(mini.jump) ', 'WarningMsg' })

  -- Avoid hit-enter-prompt
  local chunks = msg
  if not is_important then
    chunks = {}
    local max_width = vim.o.columns * math.max(vim.o.cmdheight - 1, 0) + vim.v.echospace
    local tot_width = 0
    for _, ch in ipairs(msg) do
      local new_ch = { vim.fn.strcharpart(ch[1], 0, max_width - tot_width), ch[2] }
      table.insert(chunks, new_ch)
      tot_width = tot_width + vim.fn.strdisplaywidth(new_ch[1])
      if tot_width >= max_width then break end
    end
  end

  -- Echo. Force redraw to ensure that it is effective (`:h echo-redraw`)
  vim.cmd([[echo '' | redraw]])
  vim.api.nvim_echo(chunks, is_important, {})
end

H.unecho = function()
  if H.cache.msg_shown then vim.cmd([[echo '' | redraw]]) end
end

H.message = function(msg) H.echo(msg, true) end

H.update_state = function(target, backward, till, n_times)
  MiniJump.state.mode = vim.fn.mode(1)

  -- Don't use `? and <1> or <2>` because it doesn't work when `<1>` is `false`
  if target ~= nil then MiniJump.state.target = target end
  if backward ~= nil then MiniJump.state.backward = backward end
  if till ~= nil then MiniJump.state.till = till end
  if n_times ~= nil then MiniJump.state.n_times = n_times end
end

H.get_cursor_data = function() return { vim.api.nvim_get_current_win(), vim.api.nvim_win_get_cursor(0) } end

H.get_target = function()
  local needs_help_msg = true
  vim.defer_fn(function()
    if not needs_help_msg then return end
    H.echo('Enter target single character ')
    H.cache.msg_shown = true
  end, 1000)
  local ok, char = pcall(vim.fn.getcharstr)
  needs_help_msg = false
  H.unecho()

  -- Terminate if couldn't get input (like with <C-c>) or it is `<Esc>`
  if not ok or char == '\27' then return end
  return char
end

H.map = function(mode, key, rhs, opts)
  if key == '' then return end

  opts = vim.tbl_deep_extend('force', { noremap = true }, opts or {})

  -- Use mapping description only in Neovim>=0.7
  if vim.fn.has('nvim-0.7') == 0 then opts.desc = nil end

  vim.api.nvim_set_keymap(mode, key, rhs, opts)
end

return MiniJump
