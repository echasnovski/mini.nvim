local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('bufremove', config) end
local unload_module = function() child.mini_unload('bufremove') end
local win_get_buf = function(...) return child.api.nvim_win_get_buf(...) end
local buf_get_option = function(...) return child.api.nvim_buf_get_option(...) end
--stylua: ignore end

-- Make helpers
local setup_layout = function()
  local layout = {}

  child.cmd('silent %bwipeout!')

  -- Create two vertical windows (with ids 'win_left' and 'win_right') with the
  -- same active buffer ('buf') but different alternate buffers (with ids
  -- 'buf_left' and 'buf_right' respectively)
  child.cmd('edit buf')
  layout['buf'] = child.api.nvim_get_current_buf()

  child.cmd('edit buf_right')
  layout['buf_right'], layout['win_right'] = child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()

  child.cmd('edit # | vsplit | edit buf_left')
  layout['buf_left'], layout['win_left'] = child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()

  child.cmd('edit #')

  return layout
end

local validate_unshow_alternate = function(fun_name, layout)
  eq(child.lua_get(('MiniBufremove.%s()'):format(fun_name)), true)

  eq(win_get_buf(layout['win_left']), layout['buf_left'])
  eq(win_get_buf(layout['win_right']), layout['buf_right'])
end

local validate_unshow_bprevious = function(fun_name, layout)
  child.cmd('bwipeout ' .. layout['buf_left'])
  local bprevious_buf = child.api.nvim_create_buf(true, false)

  eq(child.lua_get(('MiniBufremove.%s()'):format(fun_name)), true)

  eq(win_get_buf(layout['win_left']), bprevious_buf)
  eq(win_get_buf(layout['win_right']), layout['buf_right'])
end

local validate_unshow_scratch = function(fun_name, layout)
  -- Wipeout all buffers except current
  child.cmd('.+,$bwipeout')

  eq(child.lua_get(('MiniBufremove.%s()'):format(fun_name)), true)

  -- Verify that created buffer is scratch buffer
  local new_buf = child.api.nvim_get_current_buf()
  assert.True(new_buf ~= layout['buf'])
  eq(buf_get_option(new_buf, 'buflisted'), true)
  eq(buf_get_option(new_buf, 'buftype'), 'nofile')

  eq(win_get_buf(layout['win_left']), new_buf)
  eq(win_get_buf(layout['win_right']), new_buf)
end

local validate_args_validation = function(fun_name, args)
  if vim.tbl_contains(args, 'buf_id') then
    local command = ('MiniBufremove.%s(100)'):format(fun_name)
    eq(child.lua_get(command), false)
    local messages = child.cmd_capture('messages')
    assert.truthy(messages:find('100 is not a valid buffer id%.$'))
  end

  if args['force'] then
    local command = ('MiniBufremove.%s(nil, 1)'):format(fun_name)
    eq(child.lua_get(command), false)
    local messages = child.cmd_capture('messages')
    assert.truthy(messages:find('`force` should be boolean%.$'))
  end
end

local validate_unshow_with_buf_id = function(fun_name, layout)
  local command = ('MiniBufremove.%s(...)'):format(fun_name)
  eq(child.lua_get(command, { layout['buf'] }), true)

  eq(win_get_buf(layout['win_left']), layout['buf_left'])
  eq(win_get_buf(layout['win_right']), layout['buf_right'])
end

local validate_force_argument = function(fun_name, layout)
  child.api.nvim_buf_set_lines(layout['buf'], 0, -1, true, { 'aaa' })
  -- Avoid hit-enter prompt due to long message
  child.cmd('set cmdheight=10')

  local output = child.lua_get(('MiniBufremove.%s()'):format(fun_name))
  eq(output, false)
  eq(win_get_buf(layout['win_left']), layout['buf'])
  eq(win_get_buf(layout['win_right']), layout['buf'])

  local messages = child.cmd_capture('messages')
  assert.truthy(messages:find('Buffer ' .. layout['buf'] .. ' has unsaved changes%..*Use.*force'))

  output = child.lua_get(('MiniBufremove.%s(nil, true)'):format(fun_name))
  eq(output, true)
  eq(win_get_buf(layout['win_left']), layout['buf_left'])
  eq(win_get_buf(layout['win_right']), layout['buf_right'])
end

local validate_disable = function(var_type, fun_name, layout)
  child.lua(('vim.%s.minibufremove_disable = true'):format(var_type))
  local output = child.lua_get(('MiniBufremove.%s()'):format(fun_name))
  eq(output, vim.NIL)

  -- Check that lyout didn't change
  eq(win_get_buf(layout['win_left']), layout['buf'])
  eq(win_get_buf(layout['win_right']), layout['buf'])

  -- Cleanup
  child.lua(('vim.%s.minibufremove_disable = nil'):format(var_type))
end

local validate_bufhidden_option = function(fun_name, bufhidden_value)
  local layout = setup_layout()
  child.api.nvim_buf_set_option(layout['buf'], 'bufhidden', bufhidden_value)

  local command = ('MiniBufremove.%s(...)'):format(fun_name)
  local output = child.lua_get(command, { layout['buf'] })
  eq(output, true)

  if fun_name == 'wipeout' or bufhidden_value == 'wipe' then
    eq(child.api.nvim_buf_is_valid(layout['buf']), false)
  else
    eq(buf_get_option(layout['buf'], 'buflisted'), false)
  end
end

-- Unit tests =================================================================
describe('MiniBufremove.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniBufremove ~= nil'))

    -- Sets appropriate settings
    eq(child.lua_get('vim.o.hidden'), true)
  end)

  it('creates `config` field', function()
    assert.True(child.lua_get([[type(_G.MiniBufremove.config) == 'table']]))

    -- Check default values
    eq(child.lua_get('MiniBufremove.config.set_vim_settings'), true)
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ set_vim_settings = false })
    eq(child.lua_get('MiniBufremove.config.set_vim_settings'), false)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ set_vim_settings = 'a' }, 'set_vim_settings', 'boolean')
  end)
end)

describe('MiniBufremove.unshow()', function()
  local layout
  before_each(function()
    child.setup()
    layout = setup_layout()
    load_module()
  end)

  it('uses alternate buffer', function()
    validate_unshow_alternate('unshow', layout)
    eq(buf_get_option(layout['buf'], 'buflisted'), true)
  end)

  it('uses `bprevious`', function()
    validate_unshow_bprevious('unshow', layout)
    eq(buf_get_option(layout['buf'], 'buflisted'), true)
  end)

  it('creates a scratch buffer', function()
    validate_unshow_scratch('unshow', layout)
    eq(buf_get_option(layout['buf'], 'buflisted'), true)
  end)

  it('validates arguments', function()
    validate_args_validation('unshow', { 'buf_id' })
  end)

  it('respects `buf_id` argument', function()
    validate_unshow_with_buf_id('unshow', layout)
    eq(buf_get_option(layout['buf'], 'buflisted'), true)
  end)

  it('respects vim.{g,b}.minibufremove_disable', function()
    validate_disable('g', 'unshow', layout)
    validate_disable('b', 'unshow', layout)
  end)
end)

describe('MiniBufremove.unshow_in_window()', function()
  local layout
  before_each(function()
    child.setup()
    load_module()
    layout = setup_layout()
  end)

  it('uses alternate buffer', function()
    eq(child.lua_get('MiniBufremove.unshow_in_window()'), true)
    eq(win_get_buf(layout['win_left']), layout['buf_left'])
    eq(win_get_buf(layout['win_right']), layout['buf'])

    -- Ensure that buffer is not deleted
    eq(buf_get_option(layout['buf'], 'buflisted'), true)
  end)

  it('uses `bprevious`', function()
    child.cmd('bwipeout ' .. layout['buf_left'])
    local previous_buf = child.api.nvim_create_buf(true, false)

    eq(child.lua_get('MiniBufremove.unshow_in_window()'), true)
    eq(win_get_buf(layout['win_left']), previous_buf)
    eq(win_get_buf(layout['win_right']), layout['buf'])

    -- Ensure that buffer is not deleted
    eq(buf_get_option(layout['buf'], 'buflisted'), true)
  end)

  it('creates a scratch buffer', function()
    child.cmd('.+,$bwipeout')
    eq(child.lua_get('MiniBufremove.unshow_in_window()'), true)

    -- Verify that created buffer is scratch buffer
    local new_buf = child.api.nvim_get_current_buf()
    eq(buf_get_option(new_buf, 'buflisted'), true)
    eq(buf_get_option(new_buf, 'buftype'), 'nofile')

    eq(win_get_buf(layout['win_left']), new_buf)
    eq(win_get_buf(layout['win_right']), layout['buf'])

    -- Ensure that buffer is not deleted
    eq(buf_get_option(layout['buf'], 'buflisted'), true)
  end)

  it('validates arguments', function()
    eq(child.lua_get('MiniBufremove.unshow_in_window(100)'), false)
    local messages = child.cmd_capture('messages')
    assert.truthy(messages:find('100 is not a valid window id%.$'))
  end)

  it('respects `win_id` argument', function()
    local output = child.lua_get('MiniBufremove.unshow_in_window(...)', { layout['win_left'] })
    eq(output, true)
    eq(win_get_buf(layout['win_left']), layout['buf_left'])
    eq(win_get_buf(layout['win_right']), layout['buf'])
  end)

  it('respects vim.{g,b}.minibufremove_disable', function()
    validate_disable('g', 'unshow_in_window', layout)
    validate_disable('b', 'unshow_in_window', layout)
  end)
end)

describe('MiniBufremove.delete()', function()
  local layout
  before_each(function()
    child.setup()
    layout = setup_layout()
    load_module()
  end)

  it('uses alternate buffer', function()
    validate_unshow_alternate('delete', layout)
    eq(buf_get_option(layout['buf'], 'buflisted'), false)
  end)

  it('uses `bprevious`', function()
    validate_unshow_bprevious('delete', layout)
    eq(buf_get_option(layout['buf'], 'buflisted'), false)
  end)

  it('creates a scratch buffer', function()
    validate_unshow_scratch('delete', layout)
    eq(buf_get_option(layout['buf'], 'buflisted'), false)
  end)

  it('validates arguments', function()
    validate_args_validation('delete', { 'buf_id', 'force' })
  end)

  it('respects `buf_id` argument', function()
    validate_unshow_with_buf_id('delete', layout)
    eq(buf_get_option(layout['buf'], 'buflisted'), false)
  end)

  it('respects `force` argument', function()
    validate_force_argument('delete', layout)
  end)

  it('respects vim.{g,b}.minibufremove_disable', function()
    validate_disable('g', 'delete', layout)
    validate_disable('b', 'delete', layout)
  end)

  it("works with different 'bufhidden' options", function()
    validate_bufhidden_option('delete', 'delete')
    validate_bufhidden_option('delete', 'wipe')
  end)
end)

describe('MiniBufremove.wipeout()', function()
  local layout
  before_each(function()
    child.setup()
    layout = setup_layout()
    load_module()
  end)

  it('uses alternate buffer', function()
    validate_unshow_alternate('wipeout', layout)
    eq(child.api.nvim_buf_is_valid(layout['buf']), false)
  end)

  it('uses `bprevious`', function()
    validate_unshow_bprevious('wipeout', layout)
    eq(child.api.nvim_buf_is_valid(layout['buf']), false)
  end)

  it('creates a scratch buffer', function()
    validate_unshow_scratch('wipeout', layout)
    eq(child.api.nvim_buf_is_valid(layout['buf']), false)
  end)

  it('validates arguments', function()
    validate_args_validation('wipeout', { 'buf_id', 'force' })
  end)

  it('respects `buf_id` argument', function()
    validate_unshow_with_buf_id('wipeout', layout)
    eq(child.api.nvim_buf_is_valid(layout['buf']), false)
  end)

  it('respects `force` argument', function()
    validate_force_argument('wipeout', layout)
  end)

  it('respects vim.{g,b}.minibufremove_disable', function()
    validate_disable('g', 'wipeout', layout)
    validate_disable('b', 'wipeout', layout)
  end)

  it("works with different 'bufhidden' options", function()
    validate_bufhidden_option('wipeout', 'delete')
    validate_bufhidden_option('wipeout', 'wipe')
  end)
end)

child.stop()
