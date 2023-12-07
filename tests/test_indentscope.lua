local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set
local mark_flaky = helpers.mark_flaky

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
local T = new_set({
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

  -- Highlight groups
  child.cmd('hi clear')
  load_module()
  expect.match(child.cmd_capture('hi MiniIndentscopeSymbol'), 'links to Delimiter')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniIndentscope.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniIndentscope.config.' .. field), value) end

  eq(child.lua_get('type(_G.MiniIndentscope.config.draw.animation)'), 'function')
  expect_config('draw.delay', 100)
  expect_config('draw.priority', 2)
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
  expect_config_error({ draw = { priority = 'a' } }, 'draw.priority', 'number')
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
  local has_map = function(lhs, pattern) return child.cmd_capture('nmap ' .. lhs):find(pattern) ~= nil end
  eq(has_map('[i', 'indent scope'), true)

  unload_module()
  child.api.nvim_del_keymap('n', '[i')

  -- Supplying empty string should mean "don't create keymap"
  load_module({ mappings = { goto_top = '' } })
  eq(has_map('[i', 'indent scope'), false)
end

T['get_scope()'] = new_set({
  hooks = {
    pre_case = function() set_lines(example_lines) end,
  },
})

local get_scope = function(...) return child.lua_get('MiniIndentscope.get_scope(...)', { ... }) end
local get_cursor_scope = function(opts) return child.lua_get('MiniIndentscope.get_scope(nil, nil, ...)', { opts }) end

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

  child.b.miniindentscope_config = { options = { border = 'top' } }
  eq(get_cursor_scope().border, { top = 1, bottom = nil, indent = 0 })

  eq(get_cursor_scope({ border = 'none' }).border, {})
end

T['gen_animation'] = new_set()

local expect_animation = function(family, target, opts, tolerance)
  opts = opts or {}
  tolerance = tolerance or 0.1
  local lua_cmd = string.format('_G.f = MiniIndentscope.gen_animation.%s(...)', family)
  child.lua(lua_cmd, { opts })

  local f = function(...) return child.lua_get('_G.f(...)', { ... }) end
  for i, _ in ipairs(target) do
    -- Expect approximate equality
    eq(math.abs(f(i, #target) - target[i]) <= tolerance, true)
  end

  child.lua('_G.f = nil')
end

--stylua: ignore
T['gen_animation']['respects `opts.easing` argument'] = function()
  expect_animation('none',        { 0,    0,    0,    0,    0 })
  expect_animation('linear',      { 20,   20,   20,   20,   20 })
  expect_animation('quadratic',   { 33.3, 26.7, 20,   13.3, 6.7 },  { easing = 'in' })
  expect_animation('quadratic',   { 6.7,  13.3, 20,   26.7, 33.3 }, { easing = 'out' })
  expect_animation('quadratic',   { 27.3, 18.2, 9,    18.2, 27.3 }, { easing = 'in-out' })
  expect_animation('cubic',       { 45.5, 29.1, 16.4, 7.2,  1.8 },  { easing = 'in' })
  expect_animation('cubic',       { 1.8,  7.2,  16.4, 29.1, 45.5 }, { easing = 'out' })
  expect_animation('cubic',       { 33.3, 14.8, 3.8,  14.8, 33.3 }, { easing = 'in-out' })
  expect_animation('quartic',     { 55.5, 28.5, 12,   3.5,  0.5 },  { easing = 'in' })
  expect_animation('quartic',     { 0.5,  3.5,  12,   28.5, 55.5 }, { easing = 'out' })
  expect_animation('quartic',     { 38,   11.3, 1.4,  11.3, 38 },   { easing = 'in-out' })
  expect_animation('exponential', { 60.9, 24.2, 9.6,  3.8,  1.5 },  { easing = 'in' })
  expect_animation('exponential', { 1.5,  3.8,  9.6,  24.2, 60.9 }, { easing = 'out' })
  expect_animation('exponential', { 38.4, 10.2, 2.8,  10.2, 38.4 }, { easing = 'in-out' })

  -- 'in-out' variants should be always symmetrical
  expect_animation('quadratic',   { 30,   20,   10,  10,  20,   30 },   { easing = 'in-out' })
  expect_animation('cubic',       { 38.6, 17.1, 4.3, 4.3, 17.1, 38.6 }, { easing = 'in-out' })
  expect_animation('quartic',     { 45,   13.3, 1.7, 1.7, 13.3, 45 },   { easing = 'in-out' })
  expect_animation('exponential', { 45.5, 11.6, 2.9, 2.9, 11.6, 45.5 }, { easing = 'in-out' })
end

T['gen_animation']['respects `opts` other arguments'] = function()
  expect_animation('linear', { 10, 10 }, { unit = 'total' })
  expect_animation('linear', { 100, 100 }, { duration = 100 })
  expect_animation('linear', { 50, 50 }, { unit = 'total', duration = 100 })
end

T['gen_animation']['validates `opts` values'] = function()
  local validate = function(opts, err_pattern)
    expect.error(function() child.lua('MiniIndentscope.gen_animation.linear(...)', { opts }) end, err_pattern)
  end

  validate({ easing = 'a' }, 'one of')
  validate({ duration = 'a' }, 'number')
  validate({ duration = -1 }, 'positive')
  validate({ unit = 'a' }, 'one of')
end

--stylua: ignore
T['gen_animation']['handles `n_steps=1` for all progression families and `opts.easing`'] = function()
  expect_animation('none',        { 0 })
  expect_animation('linear',      { 20 })
  expect_animation('quadratic',   { 20 }, { easing = 'in' })
  expect_animation('quadratic',   { 20 }, { easing = 'out' })
  expect_animation('quadratic',   { 20 }, { easing = 'in-out' })
  expect_animation('cubic',       { 20 }, { easing = 'in' })
  expect_animation('cubic',       { 20 }, { easing = 'out' })
  expect_animation('cubic',       { 20 }, { easing = 'in-out' })
  expect_animation('quartic',     { 20 }, { easing = 'in' })
  expect_animation('quartic',     { 20 }, { easing = 'out' })
  expect_animation('quartic',     { 20 }, { easing = 'in-out' })
  expect_animation('exponential', { 20 }, { easing = 'in' })
  expect_animation('exponential', { 20 }, { easing = 'out' })
  expect_animation('exponential', { 20 }, { easing = 'in-out' })
end

T['move_cursor()'] = new_set({
  hooks = {
    pre_case = function() set_lines(example_lines_nested) end,
  },
})

local move_cursor = function(...) child.lua('MiniIndentscope.move_cursor(...)', { ... }) end

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
      child.set_size(15, 12)
    end,
  },
})

T['draw()']['works'] = function()
  mark_flaky()

  set_cursor(6, 1)
  child.lua('MiniIndentscope.draw()')

  -- Should be single symbol at cursor line
  child.expect_screenshot()

  sleep(test_times.animation_step)
  child.expect_screenshot()
  sleep(test_times.animation_step)
  child.expect_screenshot()
  sleep(test_times.animation_step)
  child.expect_screenshot()
end

local validate_hl_group = function(hl_group)
  local ns_id = child.api.nvim_get_namespaces()['MiniIndentscope']
  local extmarks = child.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })

  local all_correct_hl_group = true
  for _, e_mark in ipairs(extmarks) do
    if e_mark[4].virt_text[1][2] ~= hl_group then all_correct_hl_group = false end
  end

  eq(all_correct_hl_group, true)
end

T['draw()']['uses correct highlight groups'] = new_set(
  { parametrize = { { 2, 'MiniIndentscopeSymbol' }, { 3, 'MiniIndentscopeSymbolOff' } } },
  {
    test = function(shiftwidth, hl_group)
      child.o.shiftwidth = shiftwidth
      set_lines({ '  aa', '    aa', '  aa' })
      set_cursor(2, 4)

      child.lua('MiniIndentscope.draw()')
      sleep(test_times.animation_step)

      validate_hl_group(hl_group)
    end,
  }
)

T['draw()']['respects `config.draw.animation`'] = function()
  mark_flaky()

  local validate = function(duration)
    set_cursor(5, 4)
    child.lua('MiniIndentscope.draw()')

    sleep(duration - 10)
    -- Should still be one symbol
    child.expect_screenshot()
    sleep(10 + 1)
    -- Should be two symbols
    child.expect_screenshot()
  end

  local duration = 2.5 * test_times.animation_step
  local command = string.format('MiniIndentscope.config.draw.animation = function() return %d end', duration)
  child.lua(command)
  validate(duration)

  -- Should also use buffer local config
  set_cursor(1, 0)
  child.lua('vim.b.miniindentscope_config = { draw = { animation = function() return 30 end } }')
  validate(30)
end

T['draw()']['respects `config.draw.priority`'] = function()
  mark_flaky()

  local ns_id = child.api.nvim_create_namespace('indentscope-test')
  child.api.nvim_buf_set_extmark(0, ns_id, 4, 0, { virt_text_pos = 'overlay', virt_text = { { '+' } }, priority = 5 })

  set_cursor(5, 0)
  child.lua('MiniIndentscope.draw()')
  sleep(test_times.animation_step)
  child.expect_screenshot()

  child.lua('MiniIndentscope.undraw()')

  child.lua('MiniIndentscope.config.draw.priority = 6')
  child.lua('MiniIndentscope.draw()')
  sleep(test_times.animation_step)
  child.expect_screenshot()
end

T['draw()']['respects `config.symbol`'] = function()
  mark_flaky()

  child.lua([[MiniIndentscope.config.symbol = '-']])
  set_cursor(5, 4)
  child.lua('MiniIndentscope.draw()')
  child.expect_screenshot()

  -- Should also use buffer local config
  set_cursor(1, 0)
  child.b.miniindentscope_config = { symbol = '+' }
  set_cursor(5, 4)
  child.lua('MiniIndentscope.draw()')
  child.expect_screenshot()
end

T['draw()']["does not overshadow 'listchars'"] = function()
  mark_flaky()

  child.o.list = true
  child.o.listchars = 'space:.'

  set_cursor(5, 4)
  child.lua('MiniIndentscope.config.draw.animation = function() return 0 end')
  child.lua('MiniIndentscope.draw()')
  child.expect_screenshot()
end

T['draw()']['does not round time of every animation step'] = function()
  child.lua('MiniIndentscope.config.draw.animation = function() return 2.99 end')

  set_cursor(6, 0)
  child.lua('MiniIndentscope.draw()')

  -- Should be single symbol at cursor line
  sleep(2 * 3)
  child.expect_screenshot()
end

T['undraw()'] = new_set({
  hooks = {
    pre_case = function()
      -- Virtually disable autodrawing
      child.lua('MiniIndentscope.config.draw.delay = 100000')
      set_lines(example_lines_nested)
      child.set_size(15, 12)
    end,
  },
})

T['undraw()']['works'] = function()
  mark_flaky()

  set_cursor(5, 4)
  child.lua('MiniIndentscope.draw()')
  child.expect_screenshot()

  child.lua('MiniIndentscope.undraw()')
  child.expect_screenshot()
end

T['Auto drawing'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines_nested)
      child.set_size(15, 12)
    end,
  },
})

T['Auto drawing']['works in Normal mode'] = function()
  mark_flaky()

  set_cursor(5, 4)

  sleep(test_times.delay - 10)
  -- Nothing should yet be shown
  child.expect_screenshot()

  sleep(10)
  -- Symbol at cursor line should be drawn immediately
  child.expect_screenshot()

  sleep(test_times.animation_step)
  child.expect_screenshot()
end

T['Auto drawing']['respects common events'] = new_set({
  parametrize = { { 'CursorMoved' }, { 'CursorMovedI' }, { 'TextChanged' }, { 'TextChangedI' }, { 'TextChangedP' } },
}, {
  test = function(event_name)
    mark_flaky()

    set_cursor(5, 4)
    child.lua('MiniIndentscope.undraw()')
    sleep(10)

    child.cmd('doautocmd ' .. event_name)
    sleep(test_times.delay + test_times.animation_step * 1 + 1)
    child.expect_screenshot()
  end,
})

T['Auto drawing']['respects ModeChanged event'] = function()
  child.set_size(15, 15)

  -- Add disabling in Insert mode
  child.cmd([[
      augroup InsertDisable
        au!
        au ModeChanged *:i lua vim.b.miniindentscope_disable = true
        au ModeChanged i:* lua vim.b.miniindentscope_disable = false
      augroup END
    ]])
  -- Needs reloading to register ModeChanged autocommands *after* previous ones
  child.lua([[require('mini.indentscope').setup({ draw = { delay = 0, animation = function() return 0 end } })]])

  set_cursor(5, 4)
  sleep(10)
  child.expect_screenshot()

  type_keys('i')
  sleep(10)
  child.expect_screenshot()

  type_keys('<Esc>')
  sleep(10)
  child.expect_screenshot()
end

T['Auto drawing']['respects `config.draw.delay`'] = function()
  child.lua('MiniIndentscope.config.draw.delay = ' .. 0.5 * test_times.delay)
  set_cursor(5, 4)

  sleep(0.5 * test_times.delay)
  child.expect_screenshot()

  -- Should also use buffer local config
  set_cursor(1, 0)
  child.b.miniindentscope_config = { draw = { delay = 30 } }
  set_cursor(5, 4)
  sleep(30)
  child.expect_screenshot()
end

T['Auto drawing']['implements debounce-style delay'] = function()
  set_cursor(5, 4)
  sleep(test_times.delay - 10)
  set_cursor(2, 0)
  sleep(test_times.delay - 10)

  -- Should draw nothing
  child.expect_screenshot()
  sleep(10)
  -- Should start drawing
  child.expect_screenshot()
end

T['Auto drawing']['respects `vim.{g,b}.miniindentscope_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child.lua('MiniIndentscope.config.draw.delay = 0')
    child[var_type].miniindentscope_disable = true
    set_cursor(5, 4)
    -- Nothing should be shown
    child.expect_screenshot()

    child[var_type].miniindentscope_disable = false
    set_cursor(5, 3)
    -- Something should be shown
    child.expect_screenshot()
  end,
})

T['Auto drawing']['works in Insert mode'] = function()
  child.set_size(15, 15)

  set_cursor(5, 4)
  type_keys('i')

  sleep(test_times.delay - 10)
  -- Nothing yet should be shown
  child.expect_screenshot()

  sleep(10)
  -- Show only on cursor line
  child.expect_screenshot()

  sleep(test_times.animation_step)
  -- One new step should be drawn
  child.expect_screenshot()
end

T['Auto drawing']['updates immediately when scopes intersect'] = function()
  child.set_size(15, 15)

  set_cursor(5, 4)
  sleep(test_times.delay + test_times.animation_step + 10)
  -- Full scope should be shown
  child.expect_screenshot()

  type_keys('o')
  -- Should be update immediately
  child.expect_screenshot()
end

T['Motion'] = new_set({
  hooks = {
    pre_case = function() set_lines(example_lines_nested) end,
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

  -- Should also use buffer local config
  child.b.miniindentscope_config = { options = { border = 'bottom' } }
  set_cursor(5, 4)
  type_keys('[i')
  eq(get_cursor(), { 4, 3 })
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
    pre_case = function() set_lines(example_lines_nested) end,
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

  -- Should also use buffer local config
  child.b.miniindentscope_config = { options = { border = 'bottom' } }
  set_cursor(5, 4)
  type_keys('v', 'ai', '<Esc>')
  child.expect_visual_marks(4, 7)
end

T['Textobject']['handles `v:count` when `try_as_border=true`'] = function()
  reload_module({ options = { try_as_border = true } })
  set_cursor(5, 4)
  type_keys('v', '100ai', '<Esc>')
  child.expect_visual_marks(1, 9)

  reload_module()
end

return T
