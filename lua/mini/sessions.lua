-- MIT License Copyright (c) 2021 Evgeni Chasnovski

-- Documentation ==============================================================
--- Session management (read, write, delete), which works using |mksession|
--- (meaning 'sessionoptions' is fully respected). This is intended as a
--- drop-in Lua replacement for session management part of 'mhinz/vim-startify'
--- (works out of the box with sessions created by it). Implements both global
--- (from configured directory) and local (from current directory) sessions.
---
--- Key design ideas:
--- - Sessions are represented by readable files (results of applying
---   |mksession|). There are two kinds of sessions:
---     - Global: any file inside a configurable directory.
---     - Local: configurable file inside current working directory (|getcwd|).
--- - All session files are detected during `MiniSessions.setup()` with session
---   names being file names (including their possible extension).
--- - Store information about detected sessions in separate table
---   (|MiniSessions.detected|) and operate only on it. Meaning if this
---   information changes, there will be no effect until next detection. So to
---   avoid confusion, don't directly use |mksession| and |source| for writing
---   and reading sessions files.
---
--- Features:
--- - Autoread default session (local if detected, latest otherwise) if Neovim
---   was called without intention to show something else.
--- - Autowrite current session before quitting Neovim.
--- - Configurable severity level of all actions.
---
--- # Setup~
---
--- This module needs a setup with `require('mini.sessions').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniSessions` which you can use for scripting or manually (with
--- `:lua MiniSessions.*`).
---
--- See |MiniSessions.config| for `config` structure and default values.
---
--- This module doesn't benefit from buffer local configuration, so using
--- `vim.b.minimisc_config` will have no effect here.
---
--- # Disabling~
---
--- To disable core functionality, set `g:minisessions_disable` (globally) or
--- `b:minisessions_disable` (for a buffer) to `v:true`. Considering high
--- number of different scenarios and customization intentions, writing exact
--- rules for disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes.
---@tag mini.sessions
---@tag MiniSessions

-- Module definition ==========================================================
local MiniSessions = {}
local H = { path_sep = package.config:sub(1, 1) }

--- Module setup
---
---@param config table|nil Module config table. See |MiniSessions.config|.
---
---@usage `require('mini.sessions').setup({})` (replace `{}` with your `config` table)
MiniSessions.setup = function(config)
  -- Export module
  _G.MiniSessions = MiniSessions

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  vim.api.nvim_exec(
    [[augroup MiniSessions
        au!
        au VimEnter * ++nested ++once lua MiniSessions.on_vimenter()
      augroup END]],
    false
  )

  if config.autowrite then
    vim.api.nvim_exec(
      [[augroup MiniSessions
          au VimLeavePre * lua if vim.v.this_session ~= '' then MiniSessions.write(nil, {force = true}) end
        augroup END]],
      false
    )
  end
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniSessions.config = {
  -- Whether to read latest session if Neovim opened without file arguments
  autoread = false,

  -- Whether to write current session before quitting Neovim
  autowrite = true,

  -- Directory where global sessions are stored (use `''` to disable)
  --minidoc_replace_start directory = --<"session" subdir of user data directory from |stdpath()|>,
  directory = ('%s%ssession'):format(vim.fn.stdpath('data'), H.path_sep),
  --minidoc_replace_end

  -- File for local session (use `''` to disable)
  file = 'Session.vim',

  -- Whether to force possibly harmful actions (meaning depends on function)
  force = { read = false, write = true, delete = false },

  -- Hook functions for actions. Default `nil` means 'do nothing'.
  -- Takes table with active session data as argument.
  hooks = {
    -- Before successful action
    pre = { read = nil, write = nil, delete = nil },
    -- After successful action
    post = { read = nil, write = nil, delete = nil },
  },

  -- Whether to print session path after action
  verbose = { read = false, write = true, delete = true },
}
--minidoc_afterlines_end

-- Module data ================================================================
--- Table of detected sessions. Keys represent session name. Values are tables
--- with session information that currently has these fields (but subject to
--- change):
--- - <modify_time> `(number)` modification time (see |getftime|) of session file.
--- - <name> `(string)` name of session (should be equal to table key).
--- - <path> `(string)` full path to session file.
--- - <type> `(string)` type of session ('global' or 'local').
MiniSessions.detected = {}

-- Module functionality =======================================================
--- Read detected session
---
--- What it does:
--- - Delete all current buffers with |bwipeout|. This is needed to correctly
---   restore buffers from target session. If `force` is not `true`, checks
---   beforehand for unsaved listed buffers and stops if there is any.
--- - Source session with supplied name.
---
---@param session_name string Name of detected session file to read. Default:
---   `nil` for default session: local (if detected) or latest session (see
---   |MiniSessions.get_latest|).
---@param opts table Table with options. Current allowed keys:
---   - <force> (whether to delete unsaved buffers; default:
---     `MiniSessions.config.force.read`).
---   - <verbose> (whether to print session path after action; default
---     `MiniSessions.config.verbose.read`).
---   - <hooks> (a table with <pre> and <post> function hooks to be executed
---     with session data argument before and after successful read; overrides
---     `MiniSessions.config.hooks.pre.read` and
---     `MiniSessions.config.hooks.post.read`).
MiniSessions.read = function(session_name, opts)
  if H.is_disabled() then return end
  if vim.tbl_count(MiniSessions.detected) == 0 then
    H.error('There is no detected sessions. Change configuration and rerun `MiniSessions.setup()`.')
  end

  if session_name == nil then
    if MiniSessions.detected[MiniSessions.config.file] ~= nil then
      session_name = MiniSessions.config.file
    else
      session_name = MiniSessions.get_latest()
    end
  end

  opts = vim.tbl_deep_extend('force', H.default_opts('read'), opts or {})

  if not H.validate_detected(session_name) then return end

  local data = MiniSessions.detected[session_name]

  -- Possibly check for unsaved listed buffers and do nothing if present
  if not opts.force then
    local unsaved_listed_buffers = H.get_unsaved_listed_buffers()

    if #unsaved_listed_buffers > 0 then
      local buf_list = table.concat(unsaved_listed_buffers, ', ')
      H.error(('There are unsaved listed buffers: %s.'):format(buf_list))
    end
  end

  -- Execute 'pre' hook
  H.possibly_execute(opts.hooks.pre, data)

  -- Wipeout all buffers
  vim.cmd('%bwipeout!')

  -- Read session file
  local session_path = data.path
  vim.cmd(('source %s'):format(vim.fn.fnameescape(session_path)))
  vim.v.this_session = session_path

  -- Possibly notify
  if opts.verbose then H.message(('Read session %s'):format(session_path)) end

  -- Execute 'post' hook
  H.possibly_execute(opts.hooks.post, data)
end

--- Write session
---
--- What it does:
--- - Check if file for supplied session name already exists. If it does and
---   `force` is not `true`, then stop.
--- - Write session with |mksession| to a file named `session_name`. Its
---   directory is determined based on type of session:
---     - It is at location |v:this_session| if `session_name` is `nil` and
---       there is current session.
---     - It is current working directory (|getcwd|) if `session_name` is equal
---       to `MiniSessions.config.file` (represents local session).
---     - It is `MiniSessions.config.directory` otherwise (represents global
---       session).
--- - Update |MiniSessions.detected|.
---
---@param session_name string Name of session file to write. Default: `nil` for
---   current session (|v:this_session|).
---@param opts table Table with options. Current allowed keys:
---   - <force> (whether to ignore existence of session file; default:
---     `MiniSessions.config.force.write`).
---   - <verbose> (whether to print session path after action; default
---     `MiniSessions.config.verbose.write`).
---   - <hooks> (a table with <pre> and <post> function hooks to be executed
---     with session data argument before and after successful write; overrides
---     `MiniSessions.config.hooks.pre.write` and
---     `MiniSessions.config.hooks.post.write`).
MiniSessions.write = function(session_name, opts)
  if H.is_disabled() then return end

  opts = vim.tbl_deep_extend('force', H.default_opts('write'), opts or {})

  local session_path = H.name_to_path(session_name)

  if not opts.force and H.is_readable_file(session_path) then
    H.error([[Can't write to existing session when `opts.force` is not `true`.]])
  end

  local data = H.new_session(session_path)

  -- Execute 'pre' hook
  H.possibly_execute(opts.hooks.pre, data)

  -- Make session file
  local cmd = ('mksession%s'):format(opts.force and '!' or '')
  vim.cmd(('%s %s'):format(cmd, vim.fn.fnameescape(session_path)))
  data.modify_time = vim.fn.getftime(session_path)

  -- Update detected sessions
  MiniSessions.detected[data.name] = data

  -- Possibly notify
  if opts.verbose then H.message(('Written session %s'):format(session_path)) end

  -- Execute 'post' hook
  H.possibly_execute(opts.hooks.post, data)
end

--- Delete detected session
---
--- What it does:
--- - Check if session name is a current one. If yes and `force` is not `true`,
---   then stop.
--- - Delete session.
--- - Update |MiniSessions.detected|.
---
---@param session_name string Name of detected session file to delete. Default:
---   `nil` for name of current session (taken from |v:this_session|).
---@param opts table Table with options. Current allowed keys:
---   - <force> (whether to allow deletion of current session; default:
---     `MiniSessions.config.force.delete`).
---   - <verbose> (whether to print session path after action; default
---     `MiniSessions.config.verbose.delete`).
---   - <hooks> (a table with <pre> and <post> function hooks to be executed
---     with session data argument before and after successful delete; overrides
---     `MiniSessions.config.hooks.pre.delete` and
---     `MiniSessions.config.hooks.post.delete`).
MiniSessions.delete = function(session_name, opts)
  if H.is_disabled() then return end
  if vim.tbl_count(MiniSessions.detected) == 0 then
    H.error('There is no detected sessions. Change configuration and rerun `MiniSessions.setup()`.')
  end

  opts = vim.tbl_deep_extend('force', H.default_opts('delete'), opts or {})

  local session_path = H.name_to_path(session_name)

  -- Make sure to delete only detected session (matters for local session)
  session_name = vim.fn.fnamemodify(session_path, ':t')
  if not H.validate_detected(session_name) then return end
  session_path = MiniSessions.detected[session_name].path

  local is_current_session = session_path == vim.v.this_session
  if not opts.force and is_current_session then
    H.error([[Can't delete current session when `opts.force` is not `true`.]])
  end

  local data = MiniSessions.detected[session_name]

  -- Execute 'pre' hook
  H.possibly_execute(opts.hooks.pre, data)

  -- Delete and update detected sessions
  vim.fn.delete(session_path)
  MiniSessions.detected[session_name] = nil
  if is_current_session then vim.v.this_session = '' end

  -- Possibly notify
  if opts.verbose then H.message(('Deleted session %s'):format(session_path)) end

  -- Execute 'pre' hook
  H.possibly_execute(opts.hooks.post, data)
end

--- Select session interactively and perform action
---
--- Note: this uses |vim.ui.select()| function. For more user-friendly
--- experience, override it (for example, with external plugins like
--- "stevearc/dressing.nvim").
---
---@param action string Action to perform. Should be one of "read" (default),
---   "write", or "delete".
---@param opts table Options for specified action.
MiniSessions.select = function(action, opts)
  if not (type(vim.ui) == 'table' and type(vim.ui.select) == 'function') then
    H.error('`MiniSessions.select()` requires `vim.ui.select()` function.')
  end

  action = action or 'read'
  if not vim.tbl_contains({ 'read', 'write', 'delete' }, action) then
    H.error("`action` should be one of 'read', 'write', or 'delete'.")
  end

  -- Ensure consistent order of items
  local detected = {}
  for _, session in pairs(MiniSessions.detected) do
    table.insert(detected, session)
  end
  local sort_fun = function(a, b)
    -- Put local session first, others - increasing alphabetically
    local a_name = a.type == 'local' and '' or a.name
    local b_name = b.type == 'local' and '' or b.name
    return a_name < b_name
  end
  table.sort(detected, sort_fun)
  local detected_names = vim.tbl_map(function(x) return x.name end, detected)

  vim.ui.select(detected_names, {
    prompt = 'Select session to ' .. action,
    format_item = function(x) return ('%s (%s)'):format(x, MiniSessions.detected[x].type) end,
  }, function(item, idx)
    if item == nil then return end
    MiniSessions[action](item, opts)
  end)
end

--- Get name of latest detected session
---
--- Latest session is the session with the latest modification time determined
--- by |getftime|.
---
---@return string|nil Name of latest session or `nil` if there is no sessions.
MiniSessions.get_latest = function()
  if vim.tbl_count(MiniSessions.detected) == 0 then return end

  local latest_time, latest_name = -1, nil
  for name, data in pairs(MiniSessions.detected) do
    if data.modify_time > latest_time then
      latest_time, latest_name = data.modify_time, name
    end
  end

  return latest_name
end

--- Act on |VimEnter|
MiniSessions.on_vimenter = function()
  if MiniSessions.config.autoread and not H.is_something_shown() then MiniSessions.read() end
end

-- Helper data ================================================================
-- Module default config
H.default_config = MiniSessions.config

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  -- Validate per nesting level to produce correct error message
  vim.validate({
    autoread = { config.autoread, 'boolean' },
    autowrite = { config.autowrite, 'boolean' },
    directory = { config.directory, 'string' },
    file = { config.file, 'string' },
    force = { config.force, 'table' },
    hooks = { config.hooks, 'table' },
    verbose = { config.verbose, 'table' },
  })

  vim.validate({
    ['force.read'] = { config.force.read, 'boolean' },
    ['force.write'] = { config.force.write, 'boolean' },
    ['force.delete'] = { config.force.delete, 'boolean' },

    ['hooks.pre'] = { config.hooks.pre, 'table' },
    ['hooks.post'] = { config.hooks.post, 'table' },

    ['verbose.read'] = { config.verbose.read, 'boolean' },
    ['verbose.write'] = { config.verbose.write, 'boolean' },
    ['verbose.delete'] = { config.verbose.delete, 'boolean' },
  })

  vim.validate({
    ['hooks.pre.read'] = { config.hooks.pre.read, 'function', true },
    ['hooks.pre.write'] = { config.hooks.pre.write, 'function', true },
    ['hooks.pre.delete'] = { config.hooks.pre.delete, 'function', true },

    ['hooks.post.read'] = { config.hooks.post.read, 'function', true },
    ['hooks.post.write'] = { config.hooks.post.write, 'function', true },
    ['hooks.post.delete'] = { config.hooks.post.delete, 'function', true },
  })

  return config
end

H.apply_config = function(config)
  MiniSessions.config = config

  MiniSessions.detected = H.detect_sessions(config)
end

H.is_disabled = function() return vim.g.minisessions_disable == true or vim.b.minisessions_disable == true end

-- Work with sessions ---------------------------------------------------------
H.detect_sessions = function(config)
  local res_global = config.directory == '' and {} or H.detect_sessions_global(config.directory)
  local res_local = config.file == '' and {} or H.detect_sessions_local(config.file)

  -- If there are both local and global session with same name, prefer local
  return vim.tbl_deep_extend('force', res_global, res_local)
end

H.detect_sessions_global = function(global_dir)
  global_dir = H.full_path(global_dir)
  if vim.fn.isdirectory(global_dir) ~= 1 then
    H.message(('%s is not a directory path.'):format(vim.inspect(global_dir)))
    return {}
  end

  local globs = vim.fn.globpath(global_dir, '*')
  if #globs == 0 then return {} end

  local res = {}
  for _, f in pairs(vim.split(globs, '\n')) do
    if H.is_readable_file(f) then
      local s = H.new_session(f, 'global')
      res[s.name] = s
    end
  end
  return res
end

H.detect_sessions_local = function(local_file)
  local f = H.joinpath(vim.fn.getcwd(), local_file)

  if not H.is_readable_file(f) then return {} end

  local res = {}
  local s = H.new_session(f, 'local')
  res[s.name] = s
  return res
end

H.new_session = function(session_path, session_type)
  return {
    modify_time = vim.fn.getftime(session_path),
    name = vim.fn.fnamemodify(session_path, ':t'),
    path = H.full_path(session_path),
    type = session_type or H.get_session_type(session_path),
  }
end

H.get_session_type = function(session_path)
  if MiniSessions.config.directory == '' then return 'local' end

  local session_dir = H.full_path(session_path)
  local global_dir = H.full_path(MiniSessions.config.directory)
  return session_dir == global_dir and 'global' or 'local'
end

H.validate_detected = function(session_name)
  local is_detected = vim.tbl_contains(vim.tbl_keys(MiniSessions.detected), session_name)
  if is_detected then return true end

  H.error(('%s is not a name for detected session.'):format(vim.inspect(session_name)))
end

H.get_unsaved_listed_buffers = function()
  return vim.tbl_filter(
    function(buf_id) return vim.api.nvim_buf_get_option(buf_id, 'modified') and vim.api.nvim_buf_get_option(buf_id, 'buflisted') end,
    vim.api.nvim_list_bufs()
  )
end

H.get_current_session_name = function() return vim.fn.fnamemodify(vim.v.this_session, ':t') end

H.name_to_path = function(session_name)
  if session_name == nil then
    if vim.v.this_session == '' then H.error('There is no active session. Supply non-nil session name.') end
    return vim.v.this_session
  end

  session_name = tostring(session_name)
  if session_name == '' then H.error('Supply non-empty session name.') end

  local session_dir = (session_name == MiniSessions.config.file) and vim.fn.getcwd() or MiniSessions.config.directory
  local path = H.joinpath(session_dir, session_name)
  return H.full_path(path)
end

-- Utilities ------------------------------------------------------------------
H.echo = function(msg, is_important)
  -- Construct message chunks
  msg = type(msg) == 'string' and { { msg } } or msg
  table.insert(msg, 1, { '(mini.sessions) ', 'WarningMsg' })

  -- Avoid hit-enter-prompt
  local max_width = vim.o.columns * math.max(vim.o.cmdheight - 1, 0) + vim.v.echospace
  local chunks, tot_width = {}, 0
  for _, ch in ipairs(msg) do
    local new_ch = { vim.fn.strcharpart(ch[1], 0, max_width - tot_width), ch[2] }
    table.insert(chunks, new_ch)
    tot_width = tot_width + vim.fn.strdisplaywidth(new_ch[1])
    if tot_width >= max_width then break end
  end

  -- Echo. Force redraw to ensure that it is effective (`:h echo-redraw`)
  vim.cmd([[echo '' | redraw]])
  vim.api.nvim_echo(chunks, is_important, {})
end

H.message = function(msg) H.echo(msg, true) end

H.error = function(msg) error(('(mini.sessions) %s'):format(msg)) end

H.default_opts = function(action)
  local config = MiniSessions.config
  return {
    force = config.force[action],
    verbose = config.verbose[action],
    hooks = { pre = config.hooks.pre[action], post = config.hooks.post[action] },
  }
end

H.is_readable_file = function(path) return vim.fn.isdirectory(path) ~= 1 and vim.fn.getfperm(path):sub(1, 1) == 'r' end

H.joinpath = function(directory, filename) return ('%s%s%s'):format(directory, H.path_sep, tostring(filename)) end

H.full_path = function(path) return vim.fn.resolve(vim.fn.fnamemodify(path, ':p')) end

H.is_something_shown = function()
  -- Don't autoread session if Neovim is opened to show something. That is
  -- when at least one of the following is true:
  -- - Current buffer has any lines (something opened explicitly).
  -- NOTE: Usage of `line2byte(line('$') + 1) > 0` seemed to be fine, but it
  -- doesn't work if some automated changed was made to buffer while leaving it
  -- empty (returns 2 instead of -1). This was also the reason of not being
  -- able to test with child Neovim process from 'tests/helpers'.
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  if #lines > 1 or (#lines == 1 and lines[1]:len() > 0) then return true end

  -- - Several buffers are listed (like session with placeholder buffers). That
  --   means unlisted buffers (like from `nvim-tree`) don't affect decision.
  local listed_buffers = vim.tbl_filter(
    function(buf_id) return vim.fn.buflisted(buf_id) == 1 end,
    vim.api.nvim_list_bufs()
  )
  if #listed_buffers > 1 then return true end

  -- - There are files in arguments (like `nvim foo.txt` with new file).
  if vim.fn.argc() > 0 then return true end

  return false
end

H.possibly_execute = function(f, ...)
  if f == nil then return end
  return f(...)
end

return MiniSessions
