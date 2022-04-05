local helpers = {}

-- Work with child Neovim process =============================================
local neovim_children = {}

--- Generate child Neovim process
---
--- This was initially assumed to be used for all testing, but at this stage
--- proved to be more inconvenience than benefits. Should be helpful for
--- certain cases (like testing startup behavior).
---
--- Methods:
--- - Job-related: `start`, `stop`, `restart`, etc.
--- - Wrappers for executing Lua inside child process: `api`, `fn`, `lsp`, `loop`, etc.
--- - Wrappers: `type_keys`, `set_lines()`, etc.
---
---@usage
--- -- Initiate
--- local child = helpers.new_child_neovim()
--- child.start()
---
--- -- Execute Lua code, commands, etc.
--- child.lua('_G.n = 0')
--- child.cmd('au CursorMoved * lua _G.n = _G.n + 1')
--- child.cmd('normal! l')
--- print(child.lua_get('_G.n')) -- Should be 1
---
--- -- Use API functions
--- child.api.nvim_buf_set_lines(0, 0, -1, true, { 'This is inside child Neovim' })
---
--- -- Use other `vim.xxx` Lua wrappers (get executed inside child process)
--- vim.b.aaa = 'current process'
--- child.b.aaa = 'child process'
--- print(child.lua_get('vim.b.aaa')) -- Should be 'child process'
---
--- -- Stop
--- child.stop()
---@private
function helpers.new_child_neovim()
  local child = { address = vim.fn.tempname() }

  -- Start fully functional Neovim instance (not '--embed' or '--headless',
  -- because they don't provide full functionality)
  function child.start(opts)
    opts = vim.tbl_deep_extend('force', { nvim_executable = 'nvim', args = {}, connection_timeout = 5000 }, opts or {})

    local args = { '--clean', '--listen', child.address }
    vim.list_extend(args, opts.args)

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
    child.start_opts = opts

    local step = 10
    local connected, i, max_tries = nil, 0, math.floor(opts.connection_timeout / step)
    repeat
      i = i + 1
      vim.loop.sleep(step)
      connected, child.channel = pcall(vim.fn.sockconnect, 'pipe', child.address, { rpc = true })
    until connected or i >= max_tries

    if not connected then
      vim.notify('Failed to make connection to child Neovim.')
      child.stop()
    end

    -- Enable method chaining
    return child
  end

  function child.stop()
    pcall(vim.fn.chanclose, child.channel)

    if child.job ~= nil then
      child.job.stdin:close()
      child.job.stdout:close()
      child.job.stderr:close()

      -- Use `pcall` to not error with `channel closed by client`
      pcall(child.cmd, 'qall!')
      child.job.handle:kill()
      child.job.handle:close()

      child.job = nil
    end

    -- Enable method chaining
    return child
  end

  function child.restart(opts)
    opts = vim.tbl_deep_extend('force', child.start_opts or {}, opts or {})

    if child.job ~= nil then
      child.stop()
      child.address = vim.fn.tempname()
    end

    child.start(opts)
  end

  function child.setup()
    child.restart({ args = { '-u', 'scripts/minimal_init.vim' } })

    -- Ensure sinle empty readable buffer
    -- NOTE: for some unimaginable reason this also speeds up test execution by
    -- factor of almost two (was 4:40 minutes; became 2:40 minutes)
    child.cmd('enew')
  end

  -- Wrappers for common `vim.xxx` objects (will get executed inside child)
  child.api = setmetatable({}, {
    __index = function(t, key)
      return function(...)
        return vim.rpcrequest(child.channel, key, ...)
      end
    end,
  })

  -- Variant of `api` functions called with `vim.rpcnotify`. Useful for
  -- making blocking requests (like `getchar()`).
  child.api_notify = setmetatable({}, {
    __index = function(t, key)
      return function(...)
        return vim.rpcnotify(child.channel, key, ...)
      end
    end,
  })

  ---@return table Emulates `vim.xxx` table (like `vim.fn`)
  ---@private
  local forward_to_child = function(tbl_name)
    -- TODO: try to figure out the best way to operate on tables with function
    -- values (needs "deep encode/decode" of function objects)
    return setmetatable({}, {
      __index = function(_, key)
        local obj_name = ('vim[%s][%s]'):format(vim.inspect(tbl_name), vim.inspect(key))
        local value_type = child.api.nvim_exec_lua(('return type(%s)'):format(obj_name), {})

        if value_type == 'function' then
          -- This allows syntax like `child.fn.mode(1)`
          return function(...)
            return child.api.nvim_exec_lua(([[return %s(...)]]):format(obj_name), { ... })
          end
        end

        -- This allows syntax like `child.bo.buftype`
        return child.api.nvim_exec_lua(([[return %s]]):format(obj_name), {})
      end,
      __newindex = function(_, key, value)
        local obj_name = ('vim[%s][%s]'):format(vim.inspect(tbl_name), vim.inspect(key))
        -- This allows syntax like `child.b.aaa = function(x) return x + 1 end`
        -- (inherits limitations of `string.dump`: no upvalues, etc.)
        if type(value) == 'function' then
          local dumped = vim.inspect(string.dump(value))
          value = ('loadstring(%s)'):format(dumped)
        else
          value = vim.inspect(value)
        end

        child.api.nvim_exec_lua(('%s = %s'):format(obj_name, value), {})
      end,
    })
  end

  --stylua: ignore start
  local supported_vim_tables = {
    -- Collections
    'diagnostic', 'fn', 'highlight', 'json', 'loop', 'lsp', 'mpack', 'treesitter', 'ui',
    -- Variables
    'g', 'b', 'w', 't', 'v', 'env',
    -- Options (no 'opt' becuase not really usefult due to use of metatables)
    'o', 'go', 'bo', 'wo',
  }
  --stylua: ignore end
  for _, v in ipairs(supported_vim_tables) do
    child[v] = forward_to_child(v)
  end

  -- Convenience wrappers
  function child.type_keys(keys, wait)
    wait = wait or 0
    keys = type(keys) == 'string' and { keys } or keys

    for _, k in ipairs(keys) do
      -- Need to escape bare `<` (see `:h nvim_input`)
      child.api.nvim_input(k == '<' and '<LT>' or k)
      if wait > 0 then
        child.loop.sleep(wait)
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

  function child.lua_notify(str, args)
    return child.api_notify.nvim_exec_lua(str, args or {})
  end

  function child.lua_get(str, args)
    return child.api.nvim_exec_lua('return ' .. str, args or {})
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
    child.ensure_normal_mode()

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
      -- NOTE: having this in one line as `'augroup %s | au! | augroup END'`
      -- for some reason seemed to sometimes not execute `augroup END` part.
      -- That lead to a subsequent bare `au ...` calls to be inside `tbl_name`
      -- group, which gets empty after every `require(<module_name>)` call.
      child.cmd(('augroup %s'):format(tbl_name))
      child.cmd('au!')
      child.cmd('augroup END')
    end
  end

  -- Various wrappers
  function child.ensure_normal_mode()
    local cur_mode = child.fn.mode()

    -- Exit from Visual mode
    local ctrl_v = vim.api.nvim_replace_termcodes('<C-v>', true, true, true)
    if cur_mode == 'v' or cur_mode == 'V' or cur_mode == ctrl_v then
      child.type_keys(cur_mode)
      return
    end

    -- Exit from Terminal mode
    if cur_mode == 't' then
      child.type_keys({ [[<C-\>]], '<C-n>' })
      return
    end

    -- Exit from other modes
    child.type_keys('<Esc>')
  end

  -- Register child
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
