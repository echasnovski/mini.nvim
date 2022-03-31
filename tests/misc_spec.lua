local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('misc', config) end
local unload_module = function() child.mini_unload('misc') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
--stylua: ignore end

-- Unit tests =================================================================
describe('MiniMisc.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniMisc ~= nil'))
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniMisc.config)'), 'table')

    eq(child.lua_get('MiniMisc.config.make_global'), { 'put', 'put_text' })
  end)

  it('respects `config` argument', function()
    reload_module({ make_global = { 'put' } })
    eq(child.lua_get('MiniMisc.config.make_global'), { 'put' })
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ make_global = 'a' }, 'make_global', 'table')
    assert_config_error({ make_global = { 'a' } }, 'make_global', 'actual fields')
  end)

  it('creates global functions', function()
    assert.True(child.lua_get('_G.put ~= nil'))
    assert.True(child.lua_get('_G.put_text ~= nil'))
  end)
end)

describe('MiniMisc.bench_time()', function()
  child.setup()
  load_module()

  child.lua([[_G.f = function(ms) ms = ms or 10; vim.loop.sleep(ms); return ms end]])
  local bench_time = function(...)
    return unpack(child.lua_get('{ MiniMisc.bench_time(_G.f, ...) }', { ... }))
  end

  it('works', function()
    local b, res = bench_time()
    -- By default should run function once
    eq(#b, 1)
    assert.True(0.009 < b[1] and b[1] < 0.011)
    -- Second value is function output
    eq(res, 10)
  end)

  it('respects `n` argument', function()
    local b, _ = bench_time(5)
    -- By default should run function once
    eq(#b, 5)
    for _, x in ipairs(b) do
      assert.True(0.009 < x and x < 0.011)
    end
  end)

  it('respects `...` as benched time arguments', function()
    local b, res = bench_time(1, 50)
    assert.True(0.049 < b[1] and b[1] < 0.051)
    -- Second value is function output
    eq(res, 50)
  end)
end)

describe('MiniMisc.get_gutter_width()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('works', function()
    -- By default there is no gutter ('sign column')
    eq(child.lua_get('MiniMisc.get_gutter_width()'), 0)

    -- This setting indeed makes gutter with width of two columns
    child.wo.signcolumn = 'yes:1'
    eq(child.lua_get('MiniMisc.get_gutter_width()'), 2)
  end)

  it('respects `win_id` argument', function()
    child.cmd('split')
    local windows = child.api.nvim_list_wins()

    child.api.nvim_win_set_option(windows[1], 'signcolumn', 'yes:1')
    eq(child.lua_get('MiniMisc.get_gutter_width(...)', { windows[2] }), 0)
  end)
end)

local describe_put = function(validate_put, put_name)
  describe(('MiniMisc.%s()'):format(put_name), function()
    child.setup()
    load_module()

    it('works', function()
      validate_put('{ a = 1, b = true }', { '{', '  a = 1,', '  b = true', '}' })
    end)

    it('allows several arguments', function()
      child.lua('_G.a = 1; _G.b = true')
      validate_put('_G.a, _G.b', { '1', 'true' })
    end)

    it('handles tuple function output', function()
      child.lua('_G.f = function() return 1, true end')
      validate_put('_G.f()', { '1', 'true' })
    end)

    it('prints `nil` values', function()
      validate_put('nil', { 'nil' })
      validate_put('1, nil', { '1', 'nil' })
      validate_put('nil, 2', { 'nil', '2' })
      validate_put('1, nil, 2', { '1', 'nil', '2' })
    end)
  end)
end

local validate_put = function(args, reference_output)
  local capture = child.cmd_capture(('lua MiniMisc.put(%s)'):format(args))
  eq(capture, table.concat(reference_output, '\n'))
end

local validate_put_text = function(args, reference_output)
  set_lines({})
  child.lua(('MiniMisc.put_text(%s)'):format(args))

  -- Insert text under current line
  table.insert(reference_output, 1, '')
  eq(get_lines(), reference_output)
end

describe_put(validate_put, 'put')

describe_put(validate_put_text, 'put_text')

describe('MiniMisc.resize_window()', function()
  local initial_width, win_id
  before_each(function()
    child.setup()
    load_module()

    -- Prepare two windows
    initial_width = child.api.nvim_win_get_width(0)
    child.cmd([[vsplit]])
    win_id = child.api.nvim_list_wins()[1]
  end)

  it('works', function()
    local target_width = math.floor(0.25 * initial_width)
    -- This sets gutter width to 4
    child.api.nvim_win_set_option(win_id, 'signcolumn', 'yes:2')

    child.lua('MiniMisc.resize_window(...)', { win_id, target_width })
    eq(child.api.nvim_win_get_width(win_id), target_width + 4)
  end)

  it('correctly computes default `text_width` argument', function()
    child.api.nvim_win_set_option(0, 'signcolumn', 'yes:2')

    -- min(vim.o.columns, 79) < textwidth < colorcolumn
    child.o.columns = 160
    child.lua('MiniMisc.resize_window(0)')
    eq(child.api.nvim_win_get_width(0), 79 + 4)

    child.o.columns = 60
    child.lua('MiniMisc.resize_window(0)')
    -- Should set to maximum available width, which is less than `columns` by 1
    -- (window separator) and 'winminwidth'
    eq(child.api.nvim_win_get_width(0), 60 - 1 - child.o.winminwidth)

    child.bo.textwidth = 50
    child.lua('MiniMisc.resize_window(0)')
    eq(child.api.nvim_win_get_width(0), 50 + 4)

    child.wo.colorcolumn = '+2,-2'
    child.lua('MiniMisc.resize_window(0)')
    eq(child.api.nvim_win_get_width(0), 52 + 4)

    child.wo.colorcolumn = '-2,+2'
    child.lua('MiniMisc.resize_window(0)')
    eq(child.api.nvim_win_get_width(0), 48 + 4)

    child.wo.colorcolumn = '40,-2'
    child.lua('MiniMisc.resize_window(0)')
    eq(child.api.nvim_win_get_width(0), 40 + 4)
  end)
end)

describe('MiniMisc.stat_summary()', function()
  child.setup()
  load_module()

  local stat_summary = function(...)
    return child.lua_get('MiniMisc.stat_summary({ ... })', { ... })
  end

  it('works', function()
    eq(stat_summary(10, 4, 3, 2, 1), { minimum = 1, mean = 4, median = 3, maximum = 10, n = 5, sd = math.sqrt(50 / 4) })
  end)

  it('works with one number', function()
    eq(stat_summary(10), { minimum = 10, mean = 10, median = 10, maximum = 10, n = 1, sd = 0 })
  end)

  it('handles even/odd number of elements for `median`', function()
    eq(stat_summary(1, 2).median, 1.5)
    eq(stat_summary(3, 1, 2).median, 2)
  end)
end)

local describe_head_tail = function(fun_name)
  describe(('MiniMisc.%s()'):format(fun_name), function()
    child.setup()
    load_module()

    it('works', function()
      local example_table = { a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7 }

      local validate = function(n)
        local output = child.lua_get(('MiniMisc.%s(...)'):format(fun_name), { example_table, n })
        local reference = math.min(vim.tbl_count(example_table), n or 5)
        eq(vim.tbl_count(output), reference)
      end

      -- The exact values vary greatly and so seem to be untestable
      validate(nil)
      validate(3)
      validate(0)
    end)
  end)
end

describe_head_tail('tbl_head')

describe_head_tail('tbl_tail')

describe('MiniMisc.use_nested_comments()', function()
  child.setup()
  load_module()

  local comments_option
  before_each(function()
    child.api.nvim_set_current_buf(child.api.nvim_create_buf(true, false))
    comments_option = child.bo.comments
  end)

  it('works', function()
    child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
    child.lua('MiniMisc.use_nested_comments()')
    eq(child.api.nvim_buf_get_option(0, 'comments'), 'n:#,' .. comments_option)
  end)

  it("ignores 'commentstring' with two parts", function()
    child.api.nvim_buf_set_option(0, 'commentstring', '/*%s*/')
    child.lua('MiniMisc.use_nested_comments()')
    eq(child.api.nvim_buf_get_option(0, 'comments'), comments_option)
  end)

  it('respects `buf_id` argument', function()
    local new_buf_id = child.api.nvim_create_buf(true, false)
    child.api.nvim_buf_set_option(new_buf_id, 'commentstring', '# %s')

    child.lua('MiniMisc.use_nested_comments(...)', { new_buf_id })

    eq(child.api.nvim_buf_get_option(0, 'comments'), comments_option)
    eq(child.api.nvim_buf_get_option(new_buf_id, 'comments'), 'n:#,' .. comments_option)
  end)
end)

describe('MiniMisc.zoom()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  local get_floating_windows = function()
    return vim.tbl_filter(function(x)
      return child.api.nvim_win_get_config(x).relative ~= ''
    end, child.api.nvim_list_wins())
  end

  it('works', function()
    local buf_id = child.api.nvim_get_current_buf()
    child.lua('MiniMisc.zoom()')
    local floating_wins = get_floating_windows()

    eq(#floating_wins, 1)
    local win_id = floating_wins[1]
    eq(child.api.nvim_win_get_buf(win_id), buf_id)
    local config = child.api.nvim_win_get_config(win_id)
    eq({ config.height, config.width }, { 1000, 1000 })
  end)

  it('respects `buf_id` argument', function()
    local buf_id = child.api.nvim_create_buf(true, false)
    child.lua('MiniMisc.zoom(...)', { buf_id })
    local floating_wins = get_floating_windows()

    eq(#floating_wins, 1)
    eq(child.api.nvim_win_get_buf(floating_wins[1]), buf_id)
  end)

  it('respects `config` argument', function()
    local custom_config = { width = 20 }
    child.lua('MiniMisc.zoom(...)', { 0, custom_config })
    local floating_wins = get_floating_windows()

    eq(#floating_wins, 1)
    local config = child.api.nvim_win_get_config(floating_wins[1])
    eq({ config.height, config.width }, { 1000, 20 })
  end)
end)

child.stop()
