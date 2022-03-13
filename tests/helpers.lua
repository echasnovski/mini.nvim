local helpers = {}

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
    vim.cmd('augroup! ' .. tbl_name)
  end
end

function helpers.set_cursor(line, column, win_id)
  vim.api.nvim_win_set_cursor(win_id or 0, { line, column })

  -- Emulate autocommand
  if vim.fn.mode(1) == 'i' and vim.fn.pumvisible() == 0 then
    vim.cmd([[doautocmd CursorMovedI]])
  else
    vim.cmd([[doautocmd CursorMoved]])
  end
end

--- Generate child Neovim process
---
--- This was initially assumed to be used for all testing, but at this stage
--- proved to be more inconvenience than benefits. Should be helpful for
--- certain cases (like testing startup behavior).
---
---@usage
--- -- Initiate
--- local child = helpers.generate_child_nvim()
--- child.api.nvim_ui_attach(40, 40, {})
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
function helpers.generate_child_nvim()
  -- Channel for child Neovim process
  local nvim = vim.fn.jobstart({ 'nvim', '--embed', '--noplugin', '-u', 'NONE', '-c', 'set rtp+=.' }, { rpc = true })

  -- Call `vim.api` functions from within child process
  local api = setmetatable({}, {
    __index = function(t, key)
      return function(...)
        return vim.rpcrequest(nvim, key, ...)
      end
    end,
  })

  -- Call `vim.fn` functions from within child process
  local fn = setmetatable({}, {
    __index = function(t, key)
      return function(...)
        return vim.rpcrequest(nvim, 'nvim_call_function', key, { ... })
      end
    end,
  })

  -- Execute lua code from within child process
  local lua = function(x)
    return vim.rpcrequest(nvim, 'nvim_exec_lua', x, {})
  end

  -- Get lua value
  local lua_get = function(value)
    return vim.rpcrequest(nvim, 'nvim_exec_lua', ('return %s'):format(value), {})
  end

  -- Load and unload 'mini.nvim' module
  local mini_load = function(name, config)
    local require_cmd = ([[require('mini.%s').setup(...)]]):format(name)
    vim.rpcrequest(nvim, 'nvim_exec_lua', require_cmd, { config or {} })
  end

  local mini_unload = function(name)
    -- Unload Lua module
    lua(([[package.loaded['mini.%s'] = nil]]):format(name))

    -- Remove global table
    local tbl_name = 'Mini' .. name:sub(1, 1):upper() .. name:sub(2)
    lua(([[_G.%s = nil]]):format(tbl_name))
  end

  return {
    nvim = nvim,
    api = api,
    fn = fn,
    lua = lua,
    lua_get = lua_get,
    cmd = function(x)
      return api.nvim_exec(x, false)
    end,
    cmd_capture = function(x)
      return api.nvim_exec(x, true)
    end,
    mini_load = mini_load,
    mini_unload = mini_unload,
    stop = function()
      vim.fn.jobstop(nvim)
    end,
  }
end

return helpers
