-- Initiate helpers
local helpers = require('tests.helpers')
local set_cursor, get_cursor, set_lines, feedkeys =
  helpers.set_cursor, helpers.get_cursor, helpers.set_lines, helpers.feedkeys

local eq = assert.are.same

--stylua: ignore start
local load_module = function(config) helpers.mini_load('indentscope', config) end
local unload_module = function() helpers.mini_unload('indentscope') end
local reload_module = function(config) unload_module(); load_module(config) end
--stylua: ignore end

local get_indent_extmarks = function()
  local ns = vim.api.nvim_get_namespaces()['MiniIndentscope']
  local extmarks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
  return vim.tbl_map(function(x)
    return { line = x[2], prefix = x[4].virt_text[1][1], symbol = x[4].virt_text[2][1] }
  end, extmarks)
end

-- Prepare buffer
local test_buf_id = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(test_buf_id)

describe('MiniIndentscope.setup()', function()
  before_each(function()
    load_module()
    vim.api.nvim_set_current_buf(test_buf_id)
  end)
  after_each(unload_module)

  it('creates side effects', function()
    -- Global variable
    assert.True(_G.MiniIndentscope ~= nil)

    -- Autocommand group
    eq(vim.fn.exists('#MiniIndentscope'), 1)

    -- Autocommand on `ModeChanged` event
    if vim.fn.has('nvim-0.7.0') == 1 then
      eq(vim.fn.exists('#MiniIndentscope#ModeChanged'), 1)
    end

    -- Highlight groups
    eq(vim.fn.hlexists('MiniIndentscopeSymbol'), 1)
    eq(vim.fn.hlexists('MiniIndentscopePrefix'), 1)
  end)

  it('creates `config` field', function()
    assert.is.table(_G.MiniIndentscope.config)

    -- Check default values
    local config = MiniIndentscope.config

    eq(type(config.draw.animation), 'function')
    eq(config.draw.delay, 100)
    eq(config.mappings.goto_bottom, ']i')
    eq(config.mappings.goto_top, '[i')
    eq(config.mappings.object_scope, 'ii')
    eq(config.mappings.object_scope_with_border, 'ai')
    eq(config.options.border, 'both')
    eq(config.options.indent_at_cursor, true)
    eq(config.options.try_as_border, false)
    eq(config.symbol, '╎')
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ symbol = 'a' })
    eq(MiniIndentscope.config.symbol, 'a')
  end)

  it('properly handles `config.mappings`', function()
    local has_map = function(lhs)
      return vim.api.nvim_exec('nmap ' .. lhs, true):find('MiniIndentscope') ~= nil
    end
    assert.True(has_map('[i'))

    unload_module()
    vim.api.nvim_del_keymap('n', '[i')

    -- Supplying empty string should mean "don't create keymap"
    load_module({ mappings = { goto_top = '' } })
    assert.False(has_map('[i'))
  end)
end)

load_module()

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

describe('MiniIndentscope.get_scope()', function()
  local get_scope = MiniIndentscope.get_scope
  local get_cursor_scope = function(opts)
    return MiniIndentscope.get_scope(nil, nil, opts)
  end

  before_each(function()
    vim.api.nvim_set_current_buf(test_buf_id)
    set_lines(example_lines)
  end)

  it('returns correct structure', function()
    set_cursor(3, 4)
    eq(get_scope(), {
      body = { top = 2, bottom = 6, indent = 4 },
      border = { top = 1, bottom = 7, indent = 2 },
      buf_id = vim.api.nvim_win_get_buf(0),
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
    vim.cmd([[normal! j]])
    local scope_blank = get_scope()
    eq(scope_blank.reference.indent, scope_nonblank.reference.indent)
    eq(scope_blank.body, scope_nonblank.body)
  end)

  it('uses correct config source', function()
    set_cursor(3, 4)

    -- Global > buffer-local > argument
    MiniIndentscope.config.options.border = 'bottom'
    eq(get_cursor_scope().border, { top = nil, bottom = 7, indent = 2 })

    vim.b.miniindentscope_options = { border = 'top' }
    eq(get_cursor_scope().border, { top = 1, bottom = nil, indent = 0 })

    eq(get_cursor_scope({ border = 'none' }).border, {})
  end)

  -- Cleanup
  set_lines({})
  vim.b.miniindentscope_options = nil
  reload_module()
end)

describe('MiniIndentscope.gen_animation()', function()
  local assert_easing = function(easing, target, opts, tolerance)
    opts = opts or {}
    tolerance = tolerance or 0.1
    local f = MiniIndentscope.gen_animation(easing, opts)
    for i, _ in ipairs(target) do
      assert.near(f(i, #target), target[i], tolerance)
    end
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
  before_each(function()
    reload_module()
    vim.api.nvim_set_current_buf(test_buf_id)
    set_lines(example_lines_nested)
  end)

  it('works', function()
    set_cursor(5, 4)
    MiniIndentscope.move_cursor('top')
    eq(get_cursor(), { 4, 3 })

    set_cursor(5, 4)
    MiniIndentscope.move_cursor('bottom')
    eq(get_cursor(), { 6, 3 })
  end)

  it('respects `use_border` argument', function()
    set_cursor(5, 4)
    MiniIndentscope.move_cursor('top', true)
    eq(get_cursor(), { 3, 2 })

    set_cursor(5, 4)
    MiniIndentscope.move_cursor('bottom', true)
    eq(get_cursor(), { 7, 2 })
  end)

  it('respects `scope` argument', function()
    set_cursor(2, 1)
    local scope = MiniIndentscope.get_scope()

    set_cursor(5, 4)
    MiniIndentscope.move_cursor('top', false, scope)
    eq(get_cursor(), { 2, 1 })

    set_cursor(5, 4)
    MiniIndentscope.move_cursor('bottom', false, scope)
    eq(get_cursor(), { 8, 1 })
  end)

  it('handles moving to "out of buffer" border lines', function()
    set_cursor(1, 1)
    MiniIndentscope.move_cursor('top', true)
    eq(get_cursor(), { 1, 0 })

    set_cursor(1, 1)
    MiniIndentscope.move_cursor('bottom', true)
    eq(get_cursor(), { 9, 0 })
  end)
end)

describe('MiniIndentscope motion', function()
  before_each(function()
    reload_module()
    vim.api.nvim_set_current_buf(test_buf_id)
    set_lines(example_lines_nested)
  end)

  it('works in Normal mode', function()
    local validate = function(keys, final_cursor_pos)
      set_cursor(5, 4)
      feedkeys(keys)

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
      feedkeys(keys)

      eq(get_cursor(), final_cursor_pos)
      eq(vim.fn.mode(1), 'v')

      helpers.exit_visual_mode()
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
      helpers.assert_equal_keys_effect(op_pending_keys, visual_keys, {
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
    feedkeys('[I')
    eq(get_cursor(), { 3, 2 })

    -- `goto_bottom`
    set_cursor(5, 4)
    feedkeys(']I')
    eq(get_cursor(), { 7, 2 })
  end)

  it('allows not immediate dot-repeat', function()
    -- `goto_top`
    set_cursor(5, 4)
    feedkeys('dv[i')
    set_cursor(2, 2)
    feedkeys('.')

    eq(get_cursor(), { 1, 0 })
    eq(vim.api.nvim_buf_line_count(0), 6)

    set_lines(example_lines_nested)

    -- `goto_bottom`
    set_cursor(5, 4)
    feedkeys('dv]i')
    set_cursor(6, 2)
    feedkeys('.')

    eq(get_cursor(), { 6, 2 })
    eq(vim.api.nvim_buf_line_count(0), 6)

    set_lines(example_lines_nested)
  end)

  it('respects `config.options.border`', function()
    -- Should move to respective body edge if border is not present
    MiniIndentscope.config.options.border = 'bottom'
    set_cursor(5, 4)
    feedkeys('[i')
    eq(get_cursor(), { 4, 3 })

    MiniIndentscope.config.options.border = 'top'
    set_cursor(5, 4)
    feedkeys(']i')
    eq(get_cursor(), { 6, 3 })

    MiniIndentscope.config.options.border = 'none'
    set_cursor(5, 4)
    feedkeys('[i')
    eq(get_cursor(), { 4, 3 })
    set_cursor(5, 4)
    feedkeys(']i')
    eq(get_cursor(), { 6, 3 })
  end)

  it('handles `v:count` when `try_as_border=true`', function()
    reload_module({ options = { try_as_border = true } })
    set_cursor(5, 4)
    feedkeys('100[i')
    eq(get_cursor(), { 1, 0 })
  end)

  it('updates jumplist only in Normal mode', function()
    -- Normal mode
    set_cursor(5, 4)
    feedkeys(']i')
    feedkeys('<C-o>')
    eq(get_cursor(), { 5, 4 })

    -- Visual mode
    set_cursor(2, 1)
    feedkeys('v]i<Esc>')
    feedkeys('<C-o>')
    assert.are.not_same(get_cursor(), { 2, 1 })
  end)
end)

describe('MiniIndentscope textobject', function()
  before_each(function()
    reload_module()
    vim.api.nvim_set_current_buf(test_buf_id)
    set_lines(example_lines_nested)
  end)

  it('works in Visual mode', function()
    local validate = function(keys, start_line, end_line)
      set_cursor(5, 4)
      feedkeys(keys)
      helpers.exit_visual_mode()
      helpers.assert_visual_marks(start_line, end_line)
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
      helpers.assert_equal_keys_effect(op_pending_keys, visual_keys, {
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
    feedkeys('vII<Esc>')
    helpers.assert_visual_marks(4, 6)

    -- `object_scope_with_border`
    set_cursor(5, 4)
    feedkeys('vAI<Esc>')
    helpers.assert_visual_marks(3, 7)
  end)

  it('allows not immediate dot-repeat', function()
    -- `object_scope`
    set_cursor(5, 4)
    feedkeys('dii')
    set_cursor(2, 2)
    feedkeys('.')

    eq(vim.api.nvim_buf_line_count(0), 2)

    set_lines(example_lines_nested)

    -- `object_scope_with_border`
    set_cursor(5, 4)
    feedkeys('dai')
    set_cursor(2, 2)
    feedkeys('.')

    eq(helpers.get_lines(), { '' })

    set_lines(example_lines_nested)
  end)

  it('respects `config.options.border`', function()
    -- Should select up to respective body edge if border is not present
    MiniIndentscope.config.options.border = 'bottom'
    set_cursor(5, 4)
    feedkeys('vai<Esc>')
    helpers.assert_visual_marks(4, 7)

    MiniIndentscope.config.options.border = 'top'
    set_cursor(5, 4)
    feedkeys('vai<Esc>')
    helpers.assert_visual_marks(3, 6)

    MiniIndentscope.config.options.border = 'none'
    set_cursor(5, 4)
    feedkeys('vai<Esc>')
    helpers.assert_visual_marks(4, 6)
  end)

  it('handles `v:count` when `try_as_border=true`', function()
    reload_module({ options = { try_as_border = true } })
    set_cursor(5, 4)
    feedkeys('v100ai<Esc>')
    helpers.assert_visual_marks(1, 9)
  end)
end)

unload_module()

-- -- Attempt at automating testing drawing itself
-- local a = require('plenary.async')
-- local async_describe, async_it = a.tests.describe, a.tests.it
-- async_describe('ModeChange event', function()
--   async_it('is respected', function()
--     -- Disable in Visual mode
--     vim.cmd([[au ModeChanged *:[vV\x16]* lua vim.b.miniindentscope_disable = true]])
--     vim.cmd([[au ModeChanged [vV\x16]*:* lua vim.b.miniindentscope_disable = false]])
--     load_module({ draw = { delay = 0 } })
--     local ns = vim.api.nvim_get_namespaces()['MiniIndentscope']
--
--     set_lines({ 'Line 1', '  Line 2', '  Line 3' })
--     set_cursor( 3, 0 )
--
--     a.util.sleep(110)
--     eq(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), 2)
--
--     feedkeys('v')
--     a.util.sleep(110)
--     eq(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), 0)
--   end)
-- end)
--
-- child.stop()
