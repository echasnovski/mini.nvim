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

-- Custom assertions ==========================================================
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
function helpers.assert_equal_keys_effect(keys_1, keys_2, actions)
  actions = actions or {}
  local before = actions.before or function() end
  local effect = actions.effect
    or function()
      return { cursor = helpers.get_cursor(), text = vim.api.nvim_buf_get_lines(0, 0, -1, true) }
    end
  local after = actions.after or function() end

  before()
  helpers.feedkeys(keys_1)
  local result_1 = effect()
  after()

  before()
  helpers.feedkeys(keys_2)
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
function helpers.assert_visual_marks(first, last)
  helpers.exit_visual_mode()

  first = type(first) == 'number' and { first, 0 } or first
  last = type(last) == 'number' and { last, 2147483647 } or last

  assert.are.same(vim.api.nvim_buf_get_mark(0, '<'), first)
  assert.are.same(vim.api.nvim_buf_get_mark(0, '>'), last)
end

-- Work with child Neovim process =============================================
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
