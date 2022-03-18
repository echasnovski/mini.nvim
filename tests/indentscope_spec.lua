local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('indentscope', config) end
local unload_module = function() child.mini_unload('indentscope') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local sleep = function(ms) vim.loop.sleep(ms); child.loop.update_time() end
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

-- Unit tests =================================================================
describe('MiniIndentscope.setup()', function()
  child.setup()

  before_each(load_module)
  after_each(unload_module)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniIndentscope ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniIndentscope'), 1)

    -- Autocommand on `ModeChanged` event
    if child.fn.has('nvim-0.7.0') == 1 then
      eq(child.fn.exists('#MiniIndentscope#ModeChanged'), 1)
    end

    -- Highlight groups
    eq(child.fn.hlexists('MiniIndentscopeSymbol'), 1)
    eq(child.fn.hlexists('MiniIndentscopePrefix'), 1)
  end)

  it('creates `config` field', function()
    assert.True(child.lua_get([[type(_G.MiniIndentscope.config) == 'table']]))

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniIndentscope.config.' .. field), value)
    end

    assert.True(child.lua_get([[type(_G.MiniIndentscope.config.draw.animation) == 'function']]))
    assert_config('draw.delay', 100)
    assert_config('mappings.goto_bottom', ']i')
    assert_config('mappings.goto_top', '[i')
    assert_config('mappings.object_scope', 'ii')
    assert_config('mappings.object_scope_with_border', 'ai')
    assert_config('options.border', 'both')
    assert_config('options.indent_at_cursor', true)
    assert_config('options.try_as_border', false)
    assert_config('symbol', '╎')
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ symbol = 'a' })
    assert.True(child.lua_get([[MiniIndentscope.config.symbol == 'a']]))
  end)

  it('properly handles `config.mappings`', function()
    local has_map = function(lhs)
      return child.cmd_capture('nmap ' .. lhs):find('MiniIndentscope') ~= nil
    end
    assert.True(has_map('[i'))

    unload_module()
    child.api.nvim_del_keymap('n', '[i')

    -- Supplying empty string should mean "don't create keymap"
    load_module({ mappings = { goto_top = '' } })
    assert.False(has_map('[i'))
  end)
end)

describe('MiniIndentscope.get_scope()', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines)
  end)

  local get_scope = function(...)
    return child.lua_get('MiniIndentscope.get_scope(...)', { ... })
  end
  local get_cursor_scope = function(opts)
    return child.lua_get('MiniIndentscope.get_scope(nil, nil, ...)', { opts })
  end

  it('returns correct structure', function()
    set_cursor(3, 4)
    eq(get_scope(), {
      body = { top = 2, bottom = 6, indent = 4 },
      border = { top = 1, bottom = 7, indent = 2 },
      buf_id = child.api.nvim_win_get_buf(0),
      reference = { line = 3, column = 5, indent = 4 },
    })
  end)

  it('uses "indent at cursor" by default', function()
    set_cursor(3, 0)
    eq(get_scope().reference.indent, 1)
  end)

  it('respects `line` and `col` arguments', function()
    set_cursor(3, 4)
    local scope_from_cursor = get_scope()
    set_cursor(1, 0)
    local scope_from_args = get_scope(3, 5)
    eq(scope_from_cursor, scope_from_args)
  end)

  it('respects `opts.border`', function()
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
  end)

  it('respects `opts.indent_at_cursor`', function()
    set_cursor(3, 1)
    eq(get_cursor_scope({ indent_at_cursor = false }), get_scope(3, math.huge))
  end)

  it('respects `opts.try_as_border`', function()
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
  end)

  it('works on empty lines', function()
    -- By default it should result in reference indent as if from previous
    -- non-blank line
    set_cursor(3, 4)
    local scope_nonblank = get_scope()
    child.cmd([[normal! j]])
    local scope_blank = get_scope()
    eq(scope_blank.reference.indent, scope_nonblank.reference.indent)
    eq(scope_blank.body, scope_nonblank.body)
  end)

  it('uses correct config source', function()
    set_cursor(3, 4)

    -- Global > buffer-local > argument
    child.lua([[MiniIndentscope.config.options.border = 'bottom']])
    eq(get_cursor_scope().border, { top = nil, bottom = 7, indent = 2 })

    child.lua([[vim.b.miniindentscope_options = { border = 'top' }]])
    eq(get_cursor_scope().border, { top = 1, bottom = nil, indent = 0 })

    eq(get_cursor_scope({ border = 'none' }).border, {})
  end)
end)

describe('MiniIndentscope.gen_animation()', function()
  child.setup()
  load_module()

  local assert_easing = function(easing, target, opts, tolerance)
    opts = opts or {}
    tolerance = tolerance or 0.1
    child.lua([[_G._f = MiniIndentscope.gen_animation(...)]], { easing, opts })
    local f = function(...)
      return child.lua_get('_G._f(...)', { ... })
    end
    for i, _ in ipairs(target) do
      assert.near(f(i, #target), target[i], tolerance)
    end

    child.lua('_G._f = nil')
  end

  it('respects `easing` argument', function()
    assert_easing('none', { 0, 0, 0, 0, 0 })
    assert_easing('linear', { 20, 20, 20, 20, 20 })
    assert_easing('quadraticIn', { 33.3, 26.7, 20, 13.3, 6.7 })
    assert_easing('quadraticOut', { 6.7, 13.3, 20, 26.7, 33.3 })
    assert_easing('quadraticInOut', { 27.3, 18.2, 9, 18.2, 27.3 })
    assert_easing('cubicIn', { 45.5, 29.1, 16.4, 7.2, 1.8 })
    assert_easing('cubicOut', { 1.8, 7.2, 16.4, 29.1, 45.5 })
    assert_easing('cubicInOut', { 33.3, 14.8, 3.8, 14.8, 33.3 })
    assert_easing('quarticIn', { 55.5, 28.5, 12, 3.5, 0.5 })
    assert_easing('quarticOut', { 0.5, 3.5, 12, 28.5, 55.5 })
    assert_easing('quarticInOut', { 38, 11.3, 1.4, 11.3, 38 })
    assert_easing('exponentialIn', { 60.9, 24.2, 9.6, 3.8, 1.5 })
    assert_easing('exponentialOut', { 1.5, 3.8, 9.6, 24.2, 60.9 })
    assert_easing('exponentialInOut', { 38.4, 10.2, 2.8, 10.2, 38.4 })

    -- 'InOut' variants should be always symmetrical
    assert_easing('quadraticInOut', { 30, 20, 10, 10, 20, 30 })
    assert_easing('cubicInOut', { 38.6, 17.1, 4.3, 4.3, 17.1, 38.6 })
    assert_easing('quarticInOut', { 45, 13.3, 1.7, 1.7, 13.3, 45 })
    assert_easing('exponentialInOut', { 45.5, 11.6, 2.9, 2.9, 11.6, 45.5 })
  end)

  it('respects `opts` argument', function()
    assert_easing('linear', { 10, 10 }, { unit = 'total' })
    assert_easing('linear', { 100, 100 }, { duration = 100 })
    assert_easing('linear', { 50, 50 }, { unit = 'total', duration = 100 })
  end)

  it('handles `n_steps=1` for all `easing` values', function()
    assert_easing('none', { 0 })
    assert_easing('linear', { 20 })
    assert_easing('quadraticIn', { 20 })
    assert_easing('quadraticOut', { 20 })
    assert_easing('quadraticInOut', { 20 })
    assert_easing('cubicIn', { 20 })
    assert_easing('cubicOut', { 20 })
    assert_easing('cubicInOut', { 20 })
    assert_easing('quarticIn', { 20 })
    assert_easing('quarticOut', { 20 })
    assert_easing('quarticInOut', { 20 })
    assert_easing('exponentialIn', { 20 })
    assert_easing('exponentialOut', { 20 })
    assert_easing('exponentialInOut', { 20 })
  end)
end)

describe('MiniIndentscope.move_cursor()', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines_nested)
  end)

  local move_cursor = function(...)
    child.lua('MiniIndentscope.move_cursor(...)', { ... })
  end

  it('works', function()
    set_cursor(5, 4)
    move_cursor('top')
    eq(get_cursor(), { 4, 3 })

    set_cursor(5, 4)
    move_cursor('bottom')
    eq(get_cursor(), { 6, 3 })
  end)

  it('respects `use_border` argument', function()
    set_cursor(5, 4)
    move_cursor('top', true)
    eq(get_cursor(), { 3, 2 })

    set_cursor(5, 4)
    move_cursor('bottom', true)
    eq(get_cursor(), { 7, 2 })
  end)

  it('respects `scope` argument', function()
    set_cursor(2, 1)
    local scope = child.lua_get('MiniIndentscope.get_scope()')

    set_cursor(5, 4)
    move_cursor('top', false, scope)
    eq(get_cursor(), { 2, 1 })

    set_cursor(5, 4)
    move_cursor('bottom', false, scope)
    eq(get_cursor(), { 8, 1 })
  end)

  it('handles moving to "out of buffer" border lines', function()
    set_cursor(1, 1)
    move_cursor('top', true)
    eq(get_cursor(), { 1, 0 })

    set_cursor(1, 1)
    move_cursor('bottom', true)
    eq(get_cursor(), { 9, 0 })
  end)
end)

-- Functional tests ===========================================================
describe('MiniIndentscope.draw()', function()
  before_each(function()
    -- Set up child Neovim in every subtest to avoid asynchronous drawing issues
    child.setup()

    -- Virtually disable autodrawing
    load_module({ draw = { delay = 100000 } })

    set_lines(example_lines_nested)
  end)

  it('works', function()
    set_cursor(6, 1)
    child.lua('MiniIndentscope.draw()')

    -- Symbol at cursor line should be drawn immediately
    eq(get_visual_marks(), { { line = 5, prefix = ' ', symbol = '╎' } })

    -- Then should be drawn step by step with upward and downward rays
    sleep(20)
    eq(get_visual_marks(), {
      { line = 4, prefix = ' ', symbol = '╎' },
      { line = 5, prefix = ' ', symbol = '╎' },
      { line = 6, prefix = ' ', symbol = '╎' },
    })
    sleep(20)
    eq(get_visual_marks(), {
      { line = 3, prefix = ' ', symbol = '╎' },
      { line = 4, prefix = ' ', symbol = '╎' },
      { line = 5, prefix = ' ', symbol = '╎' },
      { line = 6, prefix = ' ', symbol = '╎' },
    })
    sleep(20)
    eq(get_visual_marks(), {
      { line = 2, prefix = ' ', symbol = '╎' },
      { line = 3, prefix = ' ', symbol = '╎' },
      { line = 4, prefix = ' ', symbol = '╎' },
      { line = 5, prefix = ' ', symbol = '╎' },
      { line = 6, prefix = ' ', symbol = '╎' },
    })
  end)

  it('respects `config.draw.animation`', function()
    unload_module()
    child.lua([[require('mini.indentscope').setup({ draw = { animation = function() return 50 end } })]])

    set_cursor(5, 4)

    child.lua('MiniIndentscope.draw()')
    eq(#get_visual_marks(), 1)
    sleep(20)
    eq(#get_visual_marks(), 1)
    sleep(30)
    eq(#get_visual_marks(), 3)
  end)

  it('respects `config.symbol`', function()
    child.lua([[MiniIndentscope.config.symbol = 'a']])
    set_cursor(5, 4)
    child.lua('MiniIndentscope.draw()')

    eq(get_visual_marks()[1]['symbol'], 'a')
  end)
end)

describe('MiniIndentscope.undraw()', function()
  before_each(function()
    -- Set up child Neovim in every subtest to avoid asynchronous drawing issues
    child.setup()

    -- Virtually disable autodrawing
    load_module({ draw = { delay = 100000 } })

    set_lines(example_lines_nested)
  end)

  it('works', function()
    set_cursor(5, 4)
    child.lua('MiniIndentscope.draw()')
    assert.True(#get_visual_marks() > 0)

    child.lua('MiniIndentscope.undraw()')
    eq(#get_visual_marks(), 0)
  end)
end)

describe('MiniIndentscope auto drawing', function()
  before_each(function()
    -- Set up child Neovim in every subtest to avoid asynchronous drawing issues
    child.setup()

    load_module()

    set_lines(example_lines_nested)
  end)

  after_each(function()
    child.exit_visual_mode()
  end)

  it('works in Normal mode', function()
    set_cursor(5, 4)

    -- Check default delay of 100
    sleep(90)
    eq(#get_visual_marks(), 0)
    sleep(10)
    -- Symbol at cursor line should be drawn immediately
    eq(#get_visual_marks(), 1)
    sleep(20)
    eq(#get_visual_marks(), 3)
  end)

  local validate_event = function(event_name)
    set_cursor(5, 4)
    sleep(100 + 20 * 1 + 1)

    child.lua('MiniIndentscope.undraw()')
    eq(#get_visual_marks(), 0)

    child.cmd('doautocmd ' .. event_name)
    sleep(100 + 20 * 1 + 1)
    eq(get_visual_marks(), {
      { line = 3, prefix = '  ', symbol = '╎' },
      { line = 4, prefix = '  ', symbol = '╎' },
      { line = 5, prefix = '  ', symbol = '╎' },
    })
  end

  it('respects CursorMoved', function()
    validate_event('CursorMoved')
  end)

  it('respects CursorMovedI', function()
    validate_event('CursorMovedI')
  end)

  it('respects TextChanged', function()
    validate_event('TextChanged')
  end)

  it('respects TextChangedI', function()
    validate_event('TextChangedI')
  end)

  it('respects TextChangedP', function()
    validate_event('TextChangedP')
  end)

  it('respects ModeChanged', function()
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
  end)

  it('respects `config.draw.delay`', function()
    reload_module({ draw = { delay = 20 } })
    set_cursor(5, 4)

    sleep(10)
    eq(#get_visual_marks(), 0)
    sleep(10)
    assert.True(#get_visual_marks() > 0)
  end)

  it('respects `vim.b.miniindentscope_disable`', function()
    child.lua('vim.b.miniindentscope_disable = true')
    set_cursor(5, 4)
    sleep(110)
    eq(#get_visual_marks(), 0)

    child.lua('vim.b.miniindentscope_disable = false')
    set_cursor(5, 3)
    sleep(100)
    assert.True(#get_visual_marks() > 0)
  end)

  it('works in Insert mode', function()
    set_cursor(5, 4)
    type_keys('i')

    -- Check default delay of 100
    sleep(90)
    eq(#get_visual_marks(), 0)
    sleep(10)
    eq(#get_visual_marks(), 1)
    sleep(20)
    eq(#get_visual_marks(), 3)
  end)

  it('updates immediately when scopes intersect', function()
    set_cursor(5, 4)
    sleep(130)
    eq(#get_visual_marks(), 3)

    type_keys('o')
    sleep(1)
    eq(#get_visual_marks(), 4)
  end)
end)

describe('MiniIndentscope motion', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines_nested)
  end)

  it('works in Normal mode', function()
    local validate = function(keys, final_cursor_pos)
      set_cursor(5, 4)
      type_keys(vim.split(keys, ''))

      eq(get_cursor(), final_cursor_pos)
    end

    -- `goto_top`
    validate('[i', { 3, 2 })
    validate('2[i', { 2, 1 })
    validate('100[i', { 1, 0 })

    -- `goto_bottom`
    validate(']i', { 7, 2 })
    validate('2]i', { 8, 1 })
    validate('100]i', { 9, 0 })
  end)

  it('works in Visual mode', function()
    local validate = function(keys, final_cursor_pos)
      set_cursor(5, 4)
      type_keys(vim.split(keys, ''))

      eq(get_cursor(), final_cursor_pos)
      eq(child.fn.mode(1), 'v')

      child.exit_visual_mode()
    end

    -- `goto_top`
    validate('v[i', { 3, 2 })
    validate('v2[i', { 2, 1 })
    validate('v100[i', { 1, 0 })

    -- `goto_bottom`
    validate('v]i', { 7, 2 })
    validate('v2]i', { 8, 1 })
    validate('v100]i', { 9, 0 })
  end)

  it('works in Operator-pending mode', function()
    local validate = function(op_pending_keys, visual_keys)
      child.assert_equal_keys_effect(op_pending_keys, visual_keys, {
        before = function()
          set_cursor(5, 4)
        end,
        after = function()
          set_lines(example_lines_nested)
        end,
      })
    end

    -- Use `dv` instead of `d` for deleting to make motion 'inclusive'
    -- `goto_top`
    validate('dv[i', 'v[id')
    validate('2dv[i', 'v2[id')
    validate('dv2[i', 'v2[id')
    validate('dv100[i', 'v100[id')

    -- `goto_bottom`
    validate('dv]i', 'v]id')
    validate('2dv]i', 'v2]id')
    validate('dv2]i', 'v2]id')
    validate('dv100]i', 'v100]id')
  end)

  it('works with different mappings', function()
    reload_module({ mappings = { goto_top = '[I', goto_bottom = ']I' } })

    -- `goto_top`
    set_cursor(5, 4)
    type_keys({ '[', 'I' })
    eq(get_cursor(), { 3, 2 })

    -- `goto_bottom`
    set_cursor(5, 4)
    type_keys({ ']', 'I' })
    eq(get_cursor(), { 7, 2 })
  end)

  it('allows not immediate dot-repeat', function()
    -- `goto_top`
    set_cursor(5, 4)
    type_keys({ 'd', 'v', '[', 'i' })
    set_cursor(2, 2)
    type_keys('.')

    eq(get_cursor(), { 1, 0 })
    eq(child.api.nvim_buf_line_count(0), 6)

    set_lines(example_lines_nested)

    -- `goto_bottom`
    set_cursor(5, 4)
    type_keys({ 'd', 'v', ']', 'i' })
    set_cursor(6, 2)
    type_keys('.')

    eq(get_cursor(), { 6, 2 })
    eq(child.api.nvim_buf_line_count(0), 6)

    set_lines(example_lines_nested)
  end)

  it('respects `config.options.border`', function()
    -- Should move to respective body edge if border is not present
    child.lua([[MiniIndentscope.config.options.border = 'bottom']])
    set_cursor(5, 4)
    type_keys({ '[', 'i' })
    eq(get_cursor(), { 4, 3 })

    child.lua([[MiniIndentscope.config.options.border = 'top']])
    set_cursor(5, 4)
    type_keys({ ']', 'i' })
    eq(get_cursor(), { 6, 3 })

    child.lua([[MiniIndentscope.config.options.border = 'none']])
    set_cursor(5, 4)
    type_keys({ '[', 'i' })
    eq(get_cursor(), { 4, 3 })
    set_cursor(5, 4)
    type_keys({ ']', 'i' })
    eq(get_cursor(), { 6, 3 })
  end)

  it('handles `v:count` when `try_as_border=true`', function()
    reload_module({ options = { try_as_border = true } })
    set_cursor(5, 4)
    type_keys(vim.split('100[i', ''))
    eq(get_cursor(), { 1, 0 })
  end)

  it('updates jumplist only in Normal mode', function()
    -- Normal mode
    set_cursor(5, 4)
    type_keys({ ']', 'i' })
    type_keys('<C-o>')
    eq(get_cursor(), { 5, 4 })

    -- Visual mode
    set_cursor(2, 1)
    type_keys(vim.split('v]i<Esc>', ''))
    type_keys('<C-o>')
    assert.are.not_same(get_cursor(), { 2, 1 })
  end)
end)

describe('MiniIndentscope textobject', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines_nested)
  end)

  it('works in Visual mode', function()
    local validate = function(keys, start_line, end_line)
      set_cursor(5, 4)
      type_keys(vim.split(keys, ''))
      child.exit_visual_mode()
      child.assert_visual_marks(start_line, end_line)
    end

    -- `object_scope`
    validate('vii', 4, 6)
    validate('v2ii', 4, 6)

    -- `object_scope_with_border`
    validate('vai', 3, 7)
    validate('v2ai', 2, 8)
    validate('v100ai', 1, 9)
  end)

  it('works in Operator-pending mode', function()
    local validate = function(op_pending_keys, visual_keys)
      child.assert_equal_keys_effect(op_pending_keys, visual_keys, {
        before = function()
          set_cursor(5, 4)
        end,
        after = function()
          set_lines(example_lines_nested)
        end,
      })
    end

    -- `object_scope`
    validate('dii', 'viid')
    validate('2dii', 'v2iid')
    validate('d2ii', 'v2iid')

    -- `object_scope_with_border`
    validate('dai', 'vaid')
    validate('2dai', 'v2aid')
    validate('d2ai', 'v2aid')
    validate('d100ai', 'v100aid')
  end)

  it('works with different mappings', function()
    reload_module({ mappings = { object_scope = 'II', object_scope_with_border = 'AI' } })

    -- `object_scope`
    set_cursor(5, 4)
    type_keys({ 'v', 'I', 'I', '<Esc>' })
    child.assert_visual_marks(4, 6)

    -- `object_scope_with_border`
    set_cursor(5, 4)
    type_keys({ 'v', 'A', 'I', '<Esc>' })
    child.assert_visual_marks(3, 7)
  end)

  it('allows not immediate dot-repeat', function()
    -- `object_scope`
    set_cursor(5, 4)
    type_keys({ 'd', 'i', 'i' })
    set_cursor(2, 2)
    type_keys('.')

    eq(child.api.nvim_buf_line_count(0), 2)

    set_lines(example_lines_nested)

    -- `object_scope_with_border`
    set_cursor(5, 4)
    type_keys({ 'd', 'a', 'i' })
    set_cursor(2, 2)
    type_keys('.')

    eq(helpers.get_lines(), { '' })

    set_lines(example_lines_nested)
  end)

  it('respects `config.options.border`', function()
    -- Should select up to respective body edge if border is not present
    child.lua([[MiniIndentscope.config.options.border = 'bottom']])
    set_cursor(5, 4)
    type_keys({ 'v', 'a', 'i', '<Esc>' })
    child.assert_visual_marks(4, 7)

    child.lua([[MiniIndentscope.config.options.border = 'top']])
    set_cursor(5, 4)
    type_keys({ 'v', 'a', 'i', '<Esc>' })
    child.assert_visual_marks(3, 6)

    child.lua([[MiniIndentscope.config.options.border = 'none']])
    set_cursor(5, 4)
    type_keys({ 'v', 'a', 'i', '<Esc>' })
    child.assert_visual_marks(4, 6)
  end)

  it('handles `v:count` when `try_as_border=true`', function()
    reload_module({ options = { try_as_border = true } })
    set_cursor(5, 4)
    type_keys({ 'v', '1', '0', '0', 'a', 'i', '<Esc>' })
    child.assert_visual_marks(1, 9)
  end)
end)

child.stop()
