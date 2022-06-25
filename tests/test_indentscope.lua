local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('indentscope', config) end
local unload_module = function() child.mini_unload('indentscope') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Make helpers
local get_visual_marks = function()
  local ns_id = child.api.nvim_get_namespaces()['MiniIndentscope']
  local extmarks = child.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })

  -- Elements of extmarks: [id, row, col, details]
  local res = vim.tbl_map(function(x)
    local virt_text = x[4].virt_text
    local prefix = ''
    if #virt_text > 1 then
      prefix = virt_text[1][1]
    end
    local symbol = virt_text[#virt_text][1]

    return { line = x[2], prefix = prefix, symbol = symbol }
  end, extmarks)

  -- Ensure increasing order of lines
  table.sort(res, function(a, b)
    return a.line < b.line
  end)
  return res
end

-- Data =======================================================================
-- Reference text
-- aa
--
--     aa
--
--     aa
--
--   aa
local example_lines = {
  'aa',
  '',
  '    aa',
  '',
  '    aa',
  '',
  '  aa',
}

-- Reference text
-- aa
--  aa
--   aa
--    aa
--    aa
--    aa
--   aa
--  aa
-- aa
local example_lines_nested = { 'aa', ' aa', '  aa', '   aa', '   aa', '   aa', '  aa', ' aa', 'aa' }

local test_times = { delay = 100, animation_step = 20 }

-- Output test set ============================================================
T = new_set({
  hooks = {
    pre_case = function()
      child.setup()
      load_module()
    end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  -- Global variable
  eq(child.lua_get('type(_G.MiniIndentscope)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniIndentscope'), 1)

  -- Autocommand on `ModeChanged` event
  if child.fn.has('nvim-0.7.0') == 1 then
    eq(child.fn.exists('#MiniIndentscope#ModeChanged'), 1)
  end

  -- Highlight groups
  expect.match(child.cmd_capture('hi MiniIndentscopeSymbol'), 'links to Delimiter')
  expect.match(child.cmd_capture('hi MiniIndentscopePrefix'), 'gui=nocombine')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniIndentscope.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value)
    eq(child.lua_get('MiniIndentscope.config.' .. field), value)
  end

  eq(child.lua_get('type(_G.MiniIndentscope.config.draw.animation)'), 'function')
  expect_config('draw.delay', 100)
  expect_config('mappings.goto_bottom', ']i')
  expect_config('mappings.goto_top', '[i')
  expect_config('mappings.object_scope', 'ii')
  expect_config('mappings.object_scope_with_border', 'ai')
  expect_config('options.border', 'both')
  expect_config('options.indent_at_cursor', true)
  expect_config('options.try_as_border', false)
  expect_config('symbol', '╎')
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ symbol = 'a' })
  eq(child.lua_get('MiniIndentscope.config.symbol'), 'a')
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ draw = 'a' }, 'draw', 'table')
  expect_config_error({ draw = { delay = 'a' } }, 'draw.delay', 'number')
  expect_config_error({ draw = { animation = 'a' } }, 'draw.animation', 'function')
  expect_config_error({ mappings = 'a' }, 'mappings', 'table')
  expect_config_error({ mappings = { object_scope = 1 } }, 'mappings.object_scope', 'string')
  expect_config_error({ mappings = { object_scope_with_border = 1 } }, 'mappings.object_scope_with_border', 'string')
  expect_config_error({ mappings = { goto_top = 1 } }, 'mappings.goto_top', 'string')
  expect_config_error({ mappings = { goto_bottom = 1 } }, 'mappings.goto_bottom', 'string')
  expect_config_error({ options = 'a' }, 'options', 'table')
  expect_config_error({ options = { border = 1 } }, 'options.border', 'string')
  expect_config_error({ options = { indent_at_cursor = 1 } }, 'options.indent_at_cursor', 'boolean')
  expect_config_error({ options = { try_as_border = 1 } }, 'options.try_as_border', 'boolean')
  expect_config_error({ symbol = 1 }, 'symbol', 'string')
end

T['setup()']['properly handles `config.mappings`'] = function()
  local has_map = function(lhs)
    return child.cmd_capture('nmap ' .. lhs):find('MiniIndentscope') ~= nil
  end
  eq(has_map('[i'), true)

  unload_module()
  child.api.nvim_del_keymap('n', '[i')

  -- Supplying empty string should mean "don't create keymap"
  load_module({ mappings = { goto_top = '' } })
  eq(has_map('[i'), false)
end

T['get_scope()'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines)
    end,
  },
})

local get_scope = function(...)
  return child.lua_get('MiniIndentscope.get_scope(...)', { ... })
end
local get_cursor_scope = function(opts)
  return child.lua_get('MiniIndentscope.get_scope(nil, nil, ...)', { opts })
end

T['get_scope()']['returns correct structure'] = function()
  set_cursor(3, 4)
  eq(get_scope(), {
    body = { top = 2, bottom = 6, indent = 4 },
    border = { top = 1, bottom = 7, indent = 2 },
    buf_id = child.api.nvim_win_get_buf(0),
    reference = { line = 3, column = 5, indent = 4 },
  })
end

T['get_scope()']['uses "indent at cursor" by default'] = function()
  set_cursor(3, 0)
  eq(get_scope().reference.indent, 1)
end

T['get_scope()']['respects `line` and `col` arguments'] = function()
  set_cursor(3, 4)
  local scope_from_cursor = get_scope()
  set_cursor(1, 0)
  local scope_from_args = get_scope(3, 5)
  eq(scope_from_cursor, scope_from_args)
end

T['get_scope()']['respects `opts.border`'] = function()
  set_cursor(3, 4)

  local scope_both = get_cursor_scope({ border = 'both' })
  eq(scope_both.body, { top = 2, bottom = 6, indent = 4 })
  eq(scope_both.border, { top = 1, bottom = 7, indent = 2 })

  local scope_bottom = get_cursor_scope({ border = 'bottom' })
  eq(scope_bottom.body, { top = 3, bottom = 6, indent = 4 })
  eq(scope_bottom.border, { bottom = 7, indent = 2 })

  local scope_top = get_cursor_scope({ border = 'top' })
  eq(scope_top.body, { top = 2, bottom = 5, indent = 4 })
  eq(scope_top.border, { top = 1, indent = 0 })

  local scope_none = get_cursor_scope({ border = 'none' })
  eq(scope_none.body, { top = 3, bottom = 5, indent = 4 })
  eq(scope_none.border, {})
end

T['get_scope()']['respects `opts.indent_at_cursor`'] = function()
  set_cursor(3, 1)
  eq(get_cursor_scope({ indent_at_cursor = false }), get_scope(3, math.huge))
end

T['get_scope()']['respects `opts.try_as_border`'] = function()
  -- Border should be recognized only if `opts.border` is appropriate
  set_cursor(1, 0)
  eq(get_cursor_scope({ border = 'both', try_as_border = true }).body.top, 2)
  eq(get_cursor_scope({ border = 'bottom', try_as_border = true }).body.top, 1)
  eq(get_cursor_scope({ border = 'top', try_as_border = true }).body.top, 2)
  eq(get_cursor_scope({ border = 'none', try_as_border = true }).body.top, 1)

  set_cursor(7, 2)
  eq(get_cursor_scope({ border = 'both', try_as_border = true }).body.bottom, 6)
  eq(get_cursor_scope({ border = 'bottom', try_as_border = true }).body.bottom, 6)
  eq(get_cursor_scope({ border = 'top', try_as_border = true }).body.bottom, 7)
  eq(get_cursor_scope({ border = 'none', try_as_border = true }).body.bottom, 7)

  -- If ambiguous, prefer next scope
  set_lines({ '  aa', 'aa', '  aa' })
  set_cursor(2, 1)
  eq(get_cursor_scope({ border = 'both', try_as_border = true }).body, { top = 3, bottom = 3, indent = 2 })
end

T['get_scope()']['works on empty lines'] = function()
  -- By default it should result in reference indent as if from previous
  -- non-blank line
  set_cursor(3, 4)
  local scope_nonblank = get_scope()
  child.cmd('normal! j')
  local scope_blank = get_scope()
  eq(scope_blank.reference.indent, scope_nonblank.reference.indent)
  eq(scope_blank.body, scope_nonblank.body)
end

T['get_scope()']['uses correct config source'] = function()
  set_cursor(3, 4)

  -- Global > buffer-local > argument
  child.lua([[MiniIndentscope.config.options.border = 'bottom']])
  eq(get_cursor_scope().border, { top = nil, bottom = 7, indent = 2 })

  child.b.miniindentscope_options = { border = 'top' }
  eq(get_cursor_scope().border, { top = 1, bottom = nil, indent = 0 })

  eq(get_cursor_scope({ border = 'none' }).border, {})
end

T['gen_animation()'] = new_set()

local expect_easing = function(easing, target, opts, tolerance)
  opts = opts or {}
  tolerance = tolerance or 0.1
  child.lua('_G._f = MiniIndentscope.gen_animation(...)', { easing, opts })
  local f = function(...)
    return child.lua_get('_G._f(...)', { ... })
  end
  for i, _ in ipairs(target) do
    -- Expect approximate equality
    eq(math.abs(f(i, #target) - target[i]) <= tolerance, true)
  end

  child.lua('_G._f = nil')
end

T['gen_animation()']['respects `easing` argument'] = function()
  expect_easing('none', { 0, 0, 0, 0, 0 })
  expect_easing('linear', { 20, 20, 20, 20, 20 })
  expect_easing('quadraticIn', { 33.3, 26.7, 20, 13.3, 6.7 })
  expect_easing('quadraticOut', { 6.7, 13.3, 20, 26.7, 33.3 })
  expect_easing('quadraticInOut', { 27.3, 18.2, 9, 18.2, 27.3 })
  expect_easing('cubicIn', { 45.5, 29.1, 16.4, 7.2, 1.8 })
  expect_easing('cubicOut', { 1.8, 7.2, 16.4, 29.1, 45.5 })
  expect_easing('cubicInOut', { 33.3, 14.8, 3.8, 14.8, 33.3 })
  expect_easing('quarticIn', { 55.5, 28.5, 12, 3.5, 0.5 })
  expect_easing('quarticOut', { 0.5, 3.5, 12, 28.5, 55.5 })
  expect_easing('quarticInOut', { 38, 11.3, 1.4, 11.3, 38 })
  expect_easing('exponentialIn', { 60.9, 24.2, 9.6, 3.8, 1.5 })
  expect_easing('exponentialOut', { 1.5, 3.8, 9.6, 24.2, 60.9 })
  expect_easing('exponentialInOut', { 38.4, 10.2, 2.8, 10.2, 38.4 })

  -- 'InOut' variants should be always symmetrical
  expect_easing('quadraticInOut', { 30, 20, 10, 10, 20, 30 })
  expect_easing('cubicInOut', { 38.6, 17.1, 4.3, 4.3, 17.1, 38.6 })
  expect_easing('quarticInOut', { 45, 13.3, 1.7, 1.7, 13.3, 45 })
  expect_easing('exponentialInOut', { 45.5, 11.6, 2.9, 2.9, 11.6, 45.5 })
end

T['gen_animation()']['respects `opts` argument'] = function()
  expect_easing('linear', { 10, 10 }, { unit = 'total' })
  expect_easing('linear', { 100, 100 }, { duration = 100 })
  expect_easing('linear', { 50, 50 }, { unit = 'total', duration = 100 })
end

T['gen_animation()']['handles `n_steps=1` for all `easing` values'] = function()
  expect_easing('none', { 0 })
  expect_easing('linear', { 20 })
  expect_easing('quadraticIn', { 20 })
  expect_easing('quadraticOut', { 20 })
  expect_easing('quadraticInOut', { 20 })
  expect_easing('cubicIn', { 20 })
  expect_easing('cubicOut', { 20 })
  expect_easing('cubicInOut', { 20 })
  expect_easing('quarticIn', { 20 })
  expect_easing('quarticOut', { 20 })
  expect_easing('quarticInOut', { 20 })
  expect_easing('exponentialIn', { 20 })
  expect_easing('exponentialOut', { 20 })
  expect_easing('exponentialInOut', { 20 })
end

T['move_cursor()'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines_nested)
    end,
  },
})

local move_cursor = function(...)
  child.lua('MiniIndentscope.move_cursor(...)', { ... })
end

T['move_cursor()']['works'] = function()
  set_cursor(5, 4)
  move_cursor('top')
  eq(get_cursor(), { 4, 3 })

  set_cursor(5, 4)
  move_cursor('bottom')
  eq(get_cursor(), { 6, 3 })
end

T['move_cursor()']['respects `use_border` argument'] = function()
  set_cursor(5, 4)
  move_cursor('top', true)
  eq(get_cursor(), { 3, 2 })

  set_cursor(5, 4)
  move_cursor('bottom', true)
  eq(get_cursor(), { 7, 2 })
end

T['move_cursor()']['respects `scope` argument'] = function()
  set_cursor(2, 1)
  local scope = child.lua_get('MiniIndentscope.get_scope()')

  set_cursor(5, 4)
  move_cursor('top', false, scope)
  eq(get_cursor(), { 2, 1 })

  set_cursor(5, 4)
  move_cursor('bottom', false, scope)
  eq(get_cursor(), { 8, 1 })
end

T['move_cursor()']['handles moving to "out of buffer" border lines'] = function()
  set_cursor(1, 1)
  move_cursor('top', true)
  eq(get_cursor(), { 1, 0 })

  set_cursor(1, 1)
  move_cursor('bottom', true)
  eq(get_cursor(), { 9, 0 })
end

-- Integration tests ==========================================================
T['draw()'] = new_set({
  hooks = {
    pre_case = function()
      -- Virtually disable autodrawing
      child.lua('MiniIndentscope.config.draw.delay = 100000')
      set_lines(example_lines_nested)
    end,
  },
})

T['draw()']['works'] = function()
  set_cursor(6, 1)
  child.lua('MiniIndentscope.draw()')

  -- Symbol at cursor line should be drawn immediately
  eq(get_visual_marks(), { { line = 5, prefix = ' ', symbol = '╎' } })

  -- Then should be drawn step by step with upward and downward rays
  sleep(test_times.animation_step)
  eq(get_visual_marks(), {
    { line = 4, prefix = ' ', symbol = '╎' },
    { line = 5, prefix = ' ', symbol = '╎' },
    { line = 6, prefix = ' ', symbol = '╎' },
  })
  sleep(test_times.animation_step)
  eq(get_visual_marks(), {
    { line = 3, prefix = ' ', symbol = '╎' },
    { line = 4, prefix = ' ', symbol = '╎' },
    { line = 5, prefix = ' ', symbol = '╎' },
    { line = 6, prefix = ' ', symbol = '╎' },
  })
  sleep(test_times.animation_step)
  eq(get_visual_marks(), {
    { line = 2, prefix = ' ', symbol = '╎' },
    { line = 3, prefix = ' ', symbol = '╎' },
    { line = 4, prefix = ' ', symbol = '╎' },
    { line = 5, prefix = ' ', symbol = '╎' },
    { line = 6, prefix = ' ', symbol = '╎' },
  })
end

T['draw()']['respects `config.draw.animation`'] = function()
  unload_module()
  child.lua([[require('mini.indentscope').setup({ draw = { animation = function() return 50 end } })]])

  set_cursor(5, 4)

  child.lua('MiniIndentscope.draw()')
  eq(#get_visual_marks(), 1)
  sleep(test_times.animation_step)
  eq(#get_visual_marks(), 1)
  sleep(30)
  eq(#get_visual_marks(), 3)
end

T['draw()']['respects `config.symbol`'] = function()
  child.lua([[MiniIndentscope.config.symbol = 'a']])
  set_cursor(5, 4)
  child.lua('MiniIndentscope.draw()')

  eq(get_visual_marks()[1]['symbol'], 'a')
end

T['undraw()'] = new_set({
  hooks = {
    pre_case = function()
      -- Virtually disable autodrawing
      child.lua('MiniIndentscope.config.draw.delay = 100000')
      set_lines(example_lines_nested)
    end,
  },
})

T['undraw()']['works'] = function()
  set_cursor(5, 4)
  child.lua('MiniIndentscope.draw()')
  eq(#get_visual_marks() > 0, true)

  child.lua('MiniIndentscope.undraw()')
  eq(#get_visual_marks(), 0)
end

T['Auto drawing'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines_nested)
    end,
  },
})

T['Auto drawing']['works in Normal mode'] = function()
  set_cursor(5, 4)

  sleep(test_times.delay - 10)
  eq(#get_visual_marks(), 0)
  sleep(10)
  -- Symbol at cursor line should be drawn immediately
  eq(#get_visual_marks(), 1)
  sleep(test_times.animation_step)
  eq(#get_visual_marks(), 3)
end

local validate_event = function(event_name)
  set_cursor(5, 4)
  sleep(test_times.delay + test_times.animation_step * 1 + 1)

  child.lua('MiniIndentscope.undraw()')
  eq(#get_visual_marks(), 0)

  child.cmd('doautocmd ' .. event_name)
  sleep(test_times.delay + test_times.animation_step * 1 + 1)
  eq(get_visual_marks(), {
    { line = 3, prefix = '  ', symbol = '╎' },
    { line = 4, prefix = '  ', symbol = '╎' },
    { line = 5, prefix = '  ', symbol = '╎' },
  })
end

T['Auto drawing']['respects CursorMoved'] = function()
  validate_event('CursorMoved')
end

T['Auto drawing']['respects CursorMovedI'] = function()
  validate_event('CursorMovedI')
end

T['Auto drawing']['respects TextChanged'] = function()
  validate_event('TextChanged')
end

T['Auto drawing']['respects TextChangedI'] = function()
  validate_event('TextChangedI')
end

T['Auto drawing']['respects TextChangedP'] = function()
  validate_event('TextChangedP')
end

T['Auto drawing']['respects ModeChanged'] = function()
  if child.fn.exists('##ModeChanged') ~= 1 then
    return
  end

  -- Add disabling in Insert mode
  unload_module()
  child.cmd([[
      augroup InsertDisable
        au!
        au ModeChanged *:i lua vim.b.miniindentscope_disable = true
        au ModeChanged i:* lua vim.b.miniindentscope_disable = false
      augroup END
    ]])
  child.lua([[require('mini.indentscope').setup({ draw = { delay = 0, animation = function() return 0 end } })]])

  set_cursor(5, 4)
  sleep(10)
  eq(#get_visual_marks(), 3)

  type_keys('i')
  sleep(10)
  eq(#get_visual_marks(), 0)

  type_keys('<Esc>')
  sleep(10)
  eq(#get_visual_marks(), 3)
end

T['Auto drawing']['respects `config.draw.delay`'] = function()
  reload_module({ draw = { delay = 20 } })
  set_cursor(5, 4)

  sleep(10)
  eq(#get_visual_marks(), 0)
  sleep(10)
  eq(#get_visual_marks() > 0, true)
end

T['Auto drawing']['implements debounce-style delay'] = function()
  set_cursor(5, 4)
  sleep(test_times.delay - 10)
  eq(#get_visual_marks(), 0)

  set_cursor(2, 0)
  sleep(test_times.delay - 10)
  eq(#get_visual_marks(), 0)
  sleep(10)
  eq(#get_visual_marks() > 0, true)
end

T['Auto drawing']['respects `vim.{g,b}.miniindentscope_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].miniindentscope_disable = true
    set_cursor(5, 4)
    sleep(test_times.delay + 10)
    eq(#get_visual_marks(), 0)

    child[var_type].miniindentscope_disable = false
    set_cursor(5, 3)
    sleep(test_times.delay)
    eq(#get_visual_marks() > 0, true)
  end,
})

T['Auto drawing']['works in Insert mode'] = function()
  set_cursor(5, 4)
  type_keys('i')

  sleep(test_times.delay - 10)
  eq(#get_visual_marks(), 0)
  sleep(10)
  eq(#get_visual_marks(), 1)
  sleep(test_times.animation_step)
  eq(#get_visual_marks(), 3)
end

T['Auto drawing']['updates immediately when scopes intersect'] = function()
  set_cursor(5, 4)
  sleep(130)
  eq(#get_visual_marks(), 3)

  type_keys('o')
  sleep(1)
  eq(#get_visual_marks(), 4)
end

T['Motion'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines_nested)
    end,
  },
})

T['Motion']['works in Normal mode'] = new_set({
  parametrize = {
    -- `goto_top`
    { '[i', { 3, 2 } },
    { '2[i', { 2, 1 } },
    { '100[i', { 1, 0 } },
    -- `goto_bottom`
    { ']i', { 7, 2 } },
    { '2]i', { 8, 1 } },
    { '100]i', { 9, 0 } },
  },
}, {
  test = function(keys, final_cursor_pos)
    set_cursor(5, 4)
    type_keys(keys)
    eq(get_cursor(), final_cursor_pos)
  end,
})

T['Motion']['works in Visual mode'] = new_set({
  parametrize = {
    -- `goto_top`
    { 'v[i', { 3, 2 } },
    { 'v2[i', { 2, 1 } },
    { 'v100[i', { 1, 0 } },
    -- `goto_bottom`
    { 'v]i', { 7, 2 } },
    { 'v2]i', { 8, 1 } },
    { 'v100]i', { 9, 0 } },
  },
}, {
  test = function(keys, final_cursor_pos)
    set_cursor(5, 4)
    type_keys(keys)
    eq(get_cursor(), final_cursor_pos)
    eq(child.fn.mode(1), 'v')
  end,
})

-- NOTE: for some reason it seems to be very important to do cases for
-- Operator-pending mode in parametrized form, because this way child process
-- is restarted every time. Otherwise it will lead to hanging process somewhere
T['Motion']['works in Operator-pending mode'] = new_set({
  parametrize = {
    -- Use `dv` instead of `d` for deleting to make motion 'inclusive'
    -- `goto_top`
    { 'dv[i', 'v[id' },
    { '2dv[i', 'v2[id' },
    { 'dv2[i', 'v2[id' },
    { 'dv100[i', 'v100[id' },
    -- `goto_bottom`
    { 'dv]i', 'v]id' },
    { '2dv]i', 'v2]id' },
    { 'dv2]i', 'v2]id' },
    { 'dv100]i', 'v100]id' },
  },
}, {
  test = function(keys_to_try, keys_reference)
    local lines = get_lines()
    set_cursor(5, 4)
    type_keys(keys_to_try)
    local data_tried = { cursor = get_cursor(), lines = get_lines() }

    set_lines(lines)
    set_cursor(5, 4)
    type_keys(keys_reference)
    local data_ref = { cursor = get_cursor(), lines = get_lines() }

    eq(data_tried, data_ref)
  end,
})

T['Motion']['works with different mappings'] = function()
  reload_module({ mappings = { goto_top = '[I', goto_bottom = ']I' } })

  -- `goto_top`
  set_cursor(5, 4)
  type_keys('[I')
  eq(get_cursor(), { 3, 2 })

  -- `goto_bottom`
  set_cursor(5, 4)
  type_keys(']I')
  eq(get_cursor(), { 7, 2 })

  reload_module()
end

T['Motion']['allows not immediate dot-repeat'] = function()
  -- `goto_top`
  set_cursor(5, 4)
  type_keys('dv', '[i')
  set_cursor(2, 2)
  type_keys('.')

  eq(get_cursor(), { 1, 0 })
  eq(child.api.nvim_buf_line_count(0), 6)

  set_lines(example_lines_nested)

  -- `goto_bottom`
  set_cursor(5, 4)
  type_keys('dv', ']i')
  set_cursor(6, 2)
  type_keys('.')

  eq(get_cursor(), { 6, 2 })
  eq(child.api.nvim_buf_line_count(0), 6)

  set_lines(example_lines_nested)
end

T['Motion']['respects `config.options.border`'] = function()
  -- Should move to respective body edge if border is not present
  child.lua([[MiniIndentscope.config.options.border = 'bottom']])
  set_cursor(5, 4)
  type_keys('[i')
  eq(get_cursor(), { 4, 3 })

  child.lua([[MiniIndentscope.config.options.border = 'top']])
  set_cursor(5, 4)
  type_keys(']i')
  eq(get_cursor(), { 6, 3 })

  child.lua([[MiniIndentscope.config.options.border = 'none']])
  set_cursor(5, 4)
  type_keys('[i')
  eq(get_cursor(), { 4, 3 })
  set_cursor(5, 4)
  type_keys(']i')
  eq(get_cursor(), { 6, 3 })
end

T['Motion']['handles `v:count` when `try_as_border=true`'] = function()
  reload_module({ options = { try_as_border = true } })
  set_cursor(5, 4)
  type_keys('100[i')
  eq(get_cursor(), { 1, 0 })

  reload_module()
end

T['Motion']['updates jumplist only in Normal mode'] = function()
  -- Normal mode
  set_cursor(5, 4)
  type_keys(']i')
  type_keys('<C-o>')
  eq(get_cursor(), { 5, 4 })

  -- Visual mode
  set_cursor(2, 1)
  type_keys('v', ']i', '<Esc>')
  type_keys('<C-o>')
  expect.no_equality(get_cursor(), { 2, 1 })
end

T['Textobject'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines_nested)
    end,
  },
})

T['Textobject']['works in Visual mode'] = new_set({
  parametrize = {
    -- `object_scope`
    { 'vii', 4, 6 },
    { 'v2ii', 4, 6 },
    -- `object_scope_with_border`
    { 'vai', 3, 7 },
    { 'v2ai', 2, 8 },
    { 'v100ai', 1, 9 },
  },
}, {
  test = function(keys, start_line, end_line)
    set_cursor(5, 4)
    type_keys(keys)
    child.expect_visual_marks(start_line, end_line)
  end,
})

T['Textobject']['works in Operator-pending mode'] = new_set({
  parametrize = {
    { 'dii', 'viid' },
    { '2dii', 'v2iid' },
    { 'd2ii', 'viid' },
    { 'dai', 'vaid' },
    { '2dai', 'v2aid' },
    { 'd2ai', 'v2aid' },
    { 'd100ai', 'v100aid' },
  },
}, {
  test = function(keys_to_try, keys_reference)
    local lines = get_lines()
    set_cursor(5, 4)
    type_keys(keys_to_try)
    local data_tried = { cursor = get_cursor(), lines = get_lines() }

    set_lines(lines)
    set_cursor(5, 4)
    type_keys(keys_reference)
    local data_ref = { cursor = get_cursor(), lines = get_lines() }

    eq(data_tried, data_ref)
  end,
})

T['Textobject']['works with different mappings'] = function()
  reload_module({ mappings = { object_scope = 'II', object_scope_with_border = 'AI' } })

  -- `object_scope`
  set_cursor(5, 4)
  type_keys('v', 'II', '<Esc>')
  child.expect_visual_marks(4, 6)

  -- `object_scope_with_border`
  set_cursor(5, 4)
  type_keys('v', 'AI', '<Esc>')
  child.expect_visual_marks(3, 7)

  reload_module()
end

T['Textobject']['allows not immediate dot-repeat'] = function()
  -- `object_scope`
  set_cursor(5, 4)
  type_keys('d', 'ii')
  set_cursor(2, 2)
  type_keys('.')

  eq(child.api.nvim_buf_line_count(0), 2)

  set_lines(example_lines_nested)

  -- `object_scope_with_border`
  set_cursor(5, 4)
  type_keys('d', 'ai')
  set_cursor(2, 2)
  type_keys('.')

  eq(get_lines(), { '' })

  set_lines(example_lines_nested)
end

T['Textobject']['respects `config.options.border`'] = function()
  -- Should select up to respective body edge if border is not present
  child.lua([[MiniIndentscope.config.options.border = 'bottom']])
  set_cursor(5, 4)
  type_keys('v', 'ai', '<Esc>')
  child.expect_visual_marks(4, 7)

  child.lua([[MiniIndentscope.config.options.border = 'top']])
  set_cursor(5, 4)
  type_keys('v', 'ai', '<Esc>')
  child.expect_visual_marks(3, 6)

  child.lua([[MiniIndentscope.config.options.border = 'none']])
  set_cursor(5, 4)
  type_keys('v', 'ai', '<Esc>')
  child.expect_visual_marks(4, 6)
end

T['Textobject']['handles `v:count` when `try_as_border=true`'] = function()
  reload_module({ options = { try_as_border = true } })
  set_cursor(5, 4)
  type_keys('v', '100ai', '<Esc>')
  child.expect_visual_marks(1, 9)

  reload_module()
end

return T
