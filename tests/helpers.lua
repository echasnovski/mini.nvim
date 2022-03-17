local helpers = {}

-- Work with 'mini.nvim' modules ==============================================
function helpers.mini_load(name, config)
  require(('mini.%s'):format(name)).setup(config)
end

function helpers.mini_unload(name)
  local tbl_name = 'Mini' .. name:sub(1, 1):upper() .. name:sub(2)
  local module_name = ('mini.%s'):format(name)

  -- Unload Lua module
  package.loaded[module_name] = nil

  -- Remove global table
  _G[tbl_name] = nil

  -- Remove autocmd group
  if vim.fn.exists('#' .. tbl_name) == 1 then
    vim.cmd('silent augroup! ' .. tbl_name)
  end
end

-- Convenience wrappers =======================================================
function helpers.set_cursor(line, column, win_id)
  vim.api.nvim_win_set_cursor(win_id or 0, { line, column })

  -- Emulate autocommand
  if vim.fn.mode(1) == 'i' and vim.fn.pumvisible() == 0 then
    vim.cmd([[doautocmd CursorMovedI]])
  else
    vim.cmd([[doautocmd CursorMoved]])
  end

  -- Advance event loop (not sure if needed)
  vim.wait(0)
end

function helpers.get_cursor(win_id)
  return vim.api.nvim_win_get_cursor(win_id or 0)
end

function helpers.set_lines(lines, buf_id)
  vim.api.nvim_buf_set_lines(buf_id or 0, 0, -1, true, lines)
end

function helpers.get_lines(buf_id)
  return vim.api.nvim_buf_get_lines(buf_id or 0, 0, -1, true)
end

function helpers.feedkeys(keys, replace_termcodes)
  replace_termcodes = replace_termcodes or true
  if replace_termcodes then
    keys = vim.api.nvim_replace_termcodes(keys, true, true, true)
  end

  -- Use `xt` to emulate user key press
  vim.api.nvim_feedkeys(keys, 'xt', false)
end

function helpers.exit_visual_mode()
  local ctrl_v = vim.api.nvim_replace_termcodes('<C-v>', true, true, true)
  local cur_mode = vim.fn.mode()
  if cur_mode == 'v' or cur_mode == 'V' or cur_mode == ctrl_v then
    vim.cmd('normal! ' .. cur_mode)
  end
end

-- Work with child Neovim process =============================================
local neovim_children = {}

--- Generate child Neovim process
---
--- This was initially assumed to be used for all testing, but at this stage
--- proved to be more inconvenience than benefits. Should be helpful for
--- certain cases (like testing startup behavior).
---
---@usage
--- -- Initiate
--- local child = helpers.new_child_neovim()
--- child.start()
---
--- -- Use API functions
--- child.api.nvim_buf_set_lines(0, 0, -1, true, { 'This is inside child Neovim' })
---
--- -- Execute Lua code, commands, etc.
--- child.lua('_G.n = 0')
--- child.cmd('au CursorMoved * lua _G.n = _G.n + 1')
--- child.cmd('normal! l')
--- print(child.lua_get('_G.n')) -- Should be 1
---
--- -- Stop
--- child.stop()
---@private
function helpers.new_child_neovim()
  local child = { address = vim.fn.tempname() }

  -- Start fully functional Neovim instance (not '--embed' or '--headless',
  -- because they don't provide full functionality)
  function child.start(extra_args, opts)
    extra_args = extra_args or {}
    opts = vim.tbl_deep_extend('force', { connection_timeout = 5000, nvim_executable = 'nvim' }, opts or {})

    local args = { '--clean', '--listen', child.address }
    vim.list_extend(args, extra_args)

    -- Using 'libuv' for creating a job is crucial for getting this to work in
    -- Github Actions. Other approaches:
    -- - Use built-in `vim.fn.jobstart(args)`. Works locally but doesn't work
    --   in Github Action.
    -- - Use `plenary.job`. Works fine both locally and in Github Action, but
    --   needs a 'plenary.nvim' dependency (not exactly bad, but undesirable).
    local job = {}
    job.stdin, job.stdout, job.stderr = vim.loop.new_pipe(false), vim.loop.new_pipe(false), vim.loop.new_pipe(false)
    job.handle, job.pid = vim.loop.spawn(opts.nvim_executable, {
      stdio = { job.stdin, job.stdout, job.stderr },
      args = args,
    }, function() end)
    child.job = job

    local step = 10
    local connected, i, max_tries = nil, 0, math.floor(opts.connection_timeout / step)
    repeat
      i = i + 1
      vim.loop.sleep(step)
      connected, child.channel = pcall(vim.fn.sockconnect, 'pipe', child.address, { rpc = true })
    until connected or i >= max_tries

    if not connected then
      vim.notify('Failed to make connection to child Neovim.')
      pcall(vim.fn.chanclose, child.job_channel)
    end

    -- Enable method chaining
    return child
  end

  function child.stop()
    pcall(vim.fn.chanclose, child.channel)

    child.job.stdin:close()
    child.job.stdout:close()
    child.job.stderr:close()

    child.job.handle:kill()
    child.job.handle:close()

    -- Enable method chaining
    return child
  end

  child.api = setmetatable({}, {
    __index = function(t, key)
      return function(...)
        return vim.rpcrequest(child.channel, key, ...)
      end
    end,
  })

  child.fn = setmetatable({}, {
    __index = function(t, key)
      return function(...)
        return vim.rpcrequest(child.channel, 'nvim_call_function', key, { ... })
      end
    end,
  })

  child.loop = setmetatable({}, {
    __index = function(t, key)
      return function(...)
        return vim.rpcrequest(child.channel, 'nvim_exec_lua', ([[return vim.loop['%s'](...)]]):format(key), { ... })
      end
    end,
  })

  function child.type_keys(keys, wait)
    wait = wait or 0
    local keys_list = vim.split(vim.api.nvim_replace_termcodes(keys, true, true, true), '')

    for _, k in ipairs(keys_list) do
      child.api.nvim_input(k)
      if wait > 0 then
        child.sleep(wait)
      end
    end
  end

  function child.cmd(str)
    return child.api.nvim_exec(str, false)
  end

  function child.cmd_capture(str)
    return child.api.nvim_exec(str, true)
  end

  function child.lua(str, args)
    return child.api.nvim_exec_lua(str, args or {})
  end

  function child.lua_get(str, args)
    return child.api.nvim_exec_lua('return ' .. str, args or {})
  end

  function child.sleep(ms)
    child.lua(('vim.loop.sleep(%s)'):format(ms))
  end

  function child.set_lines(arr, start, finish)
    if type(arr) == 'string' then
      arr = vim.split(arr, '\n')
    end

    child.api.nvim_buf_set_lines(0, start or 0, finish or -1, false, arr)
  end

  function child.get_lines(start, finish)
    return child.api.nvim_buf_get_lines(0, start or 0, finish or -1, false)
  end

  function child.set_cursor(line, column, win_id)
    child.api.nvim_win_set_cursor(win_id or 0, { line, column })
  end

  function child.get_cursor(win_id)
    return child.api.nvim_win_get_cursor(win_id or 0)
  end

  -- Custom assertions
  --- Assert equal effect of keys
  ---
  --- Usual usage is to test equivalence of mapping in operator pending mode and
  --- similar one using Visual mode first.
  ---
  ---@param keys_1 string First sequence of keys.
  ---@param keys_2 string Second sequence of keys.
  ---@param actions table Table with keys:
  ---   - <before> - perform before applying keys.
  ---   - <effect> - get effect of applying keys. Outputs will be compared. By
  ---     default tests eventual cursor position and buffer text.
  ---   - <after> - perform after applying keys.
  ---@private
  function child.assert_equal_keys_effect(keys_1, keys_2, actions)
    actions = actions or {}
    local before = actions.before or function() end
    local effect = actions.effect
      or function()
        return { cursor = child.get_cursor(), text = child.api.nvim_buf_get_lines(0, 0, -1, true) }
      end
    local after = actions.after or function() end

    before()
    child.type_keys(keys_1)
    local result_1 = effect()
    after()

    before()
    child.type_keys(keys_2)
    local result_2 = effect()
    after()

    assert.are.same(result_1, result_2)
  end

  --- Assert visual marks
  ---
  --- Useful to validate visual selection
  ---
  ---@param first number|table Table with start position or number to check linewise.
  ---@param last number|table Table with finish position or number to check linewise.
  ---@private
  function child.assert_visual_marks(first, last)
    child.exit_visual_mode()

    first = type(first) == 'number' and { first, 0 } or first
    last = type(last) == 'number' and { last, 2147483647 } or last

    assert.are.same(child.api.nvim_buf_get_mark(0, '<'), first)
    assert.are.same(child.api.nvim_buf_get_mark(0, '>'), last)
  end

  -- Work with 'mini.nvim'
  function child.mini_load(name, config)
    local lua_cmd = ([[require('mini.%s').setup(...)]]):format(name)
    child.lua(lua_cmd, { config })
  end

  function child.mini_unload(name)
    local module_name = 'mini.' .. name
    local tbl_name = 'Mini' .. name:sub(1, 1):upper() .. name:sub(2)

    -- Unload Lua module
    child.lua(([[package.loaded['%s'] = nil]]):format(module_name))

    -- Remove global table
    child.lua(('_G[%s] = nil'):format(tbl_name))

    -- Remove autocmd group
    if child.fn.exists('#' .. tbl_name) == 1 then
      child.cmd(('augroup %s | au! | augroup END'):format(tbl_name))
    end
  end

  -- Various wrappers
  function child.exit_visual_mode()
    local ctrl_v = vim.api.nvim_replace_termcodes('<C-v>', true, true, true)
    local cur_mode = child.fn.mode(1)
    if cur_mode == 'v' or cur_mode == 'V' or cur_mode == ctrl_v then
      child.cmd('normal! ' .. cur_mode)
    end
  end

  table.insert(neovim_children, child)

  return child
end

function _G.child_neovim_on_vimleavepre()
  for _, child in ipairs(neovim_children) do
    child.stop()
  end
end

vim.cmd([[au VimLeavePre * _G.child_neovim_on_vimleavepre()]])

return helpers
