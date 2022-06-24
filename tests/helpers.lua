local Helpers = {}

-- Add extra expectations
Helpers.expect = vim.deepcopy(MiniTest.expect)

Helpers.expect.match = MiniTest.new_expectation('string matching', function(str, pattern)
  return str:find(pattern) ~= nil
end, function(str, pattern)
  return string.format('Pattern: %s\nObserved string: %s', vim.inspect(pattern), str)
end)

Helpers.expect.no_match = MiniTest.new_expectation('no string matching', function(str, pattern)
  return str:find(pattern) == nil
end, function(str, pattern)
  return string.format('Pattern: %s\nObserved string: %s', vim.inspect(pattern), str)
end)

-- Monkey-patch `MiniTest.new_child_neovim` with helpful wrappers
Helpers.new_child_neovim = function()
  local child = MiniTest.new_child_neovim()

  local prevent_hanging = function(method)
    -- stylua: ignore
    if not child.is_blocked() then return end

    local msg = string.format('Can not use `child.%s` because child process is blocked.', method)
    error(msg)
  end

  function child.setup()
    child.restart({ '-u', 'scripts/minimal_init.lua' })

    -- Change initial buffer to be readonly. This not only increases execution
    -- speed, but more closely resembles manually opened Neovim.
    child.bo.readonly = false
  end

  function child.set_lines(arr, start, finish)
    prevent_hanging('set_lines')

    if type(arr) == 'string' then
      arr = vim.split(arr, '\n')
    end

    child.api.nvim_buf_set_lines(0, start or 0, finish or -1, false, arr)
  end

  function child.get_lines(start, finish)
    prevent_hanging('get_lines')

    return child.api.nvim_buf_get_lines(0, start or 0, finish or -1, false)
  end

  function child.set_cursor(line, column, win_id)
    prevent_hanging('set_cursor')

    child.api.nvim_win_set_cursor(win_id or 0, { line, column })
  end

  function child.get_cursor(win_id)
    prevent_hanging('get_cursor')

    return child.api.nvim_win_get_cursor(win_id or 0)
  end

  function child.set_size(lines, columns)
    prevent_hanging('set_size')

    if type(lines) == 'number' then
      child.o.lines = lines
    end

    if type(columns) == 'number' then
      child.o.columns = columns
    end
  end

  function child.get_size()
    prevent_hanging('get_size')

    return { child.o.lines, child.o.columns }
  end

  -- Custom child expectations
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
  function child.expect_equal_keys_effect(keys_1, keys_2, actions)
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

    MiniTest.expect.equality(result_1, result_2)
  end

  --- Assert visual marks
  ---
  --- Useful to validate visual selection
  ---
  ---@param first number|table Table with start position or number to check linewise.
  ---@param last number|table Table with finish position or number to check linewise.
  ---@private
  function child.expect_visual_marks(first, last)
    child.ensure_normal_mode()

    first = type(first) == 'number' and { first, 0 } or first
    last = type(last) == 'number' and { last, 2147483647 } or last

    MiniTest.expect.equality(child.api.nvim_buf_get_mark(0, '<'), first)
    MiniTest.expect.equality(child.api.nvim_buf_get_mark(0, '>'), last)
  end

  -- Work with 'mini.nvim':
  -- - `mini_load` - load with "normal" table config
  -- - `mini_load_strconfig` - load with "string" config, which is still a
  --   table but with string values. Final loading is done by constructing
  --   final string table. Needed to be used if one of the config entries is a
  --   function (as currently there is no way to communicate a function object
  --   through RPC).
  -- - `mini_unload` - unload module and revert common side effects.
  function child.mini_load(name, config)
    local lua_cmd = ([[require('mini.%s').setup(...)]]):format(name)
    child.lua(lua_cmd, { config })
  end

  function child.mini_load_strconfig(name, strconfig)
    local t = {}
    for key, val in pairs(strconfig) do
      table.insert(t, key .. ' = ' .. val)
    end
    local str = string.format('{ %s }', table.concat(t, ', '))

    local command = ([[require('mini.%s').setup(%s)]]):format(name, str)
    child.lua(command)
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

  function child.expect_screenshot(opts, path, screenshot_opts)
    if child.fn.has('nvim-0.8') == 0 then
      MiniTest.skip('Screenshots are tested for Neovim>=0.8 (for simplicity).')
    end

    MiniTest.expect.reference_screenshot(child.get_screenshot(screenshot_opts), path, opts)
  end

  return child
end

-- Mark test failure as "flaky"
function Helpers.mark_flaky()
  MiniTest.finally(function()
    if #MiniTest.current.case.exec.fails > 0 then
      MiniTest.add_note('This test is flaky.')
    end
  end)
end

return Helpers
