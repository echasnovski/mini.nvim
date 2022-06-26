local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('misc', config) end
local unload_module = function() child.mini_unload('misc') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
--stylua: ignore end

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
  eq(child.lua_get('type(_G.MiniMisc)'), 'table')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniMisc.config)'), 'table')

  eq(child.lua_get('MiniMisc.config.make_global'), { 'put', 'put_text' })
end

T['setup()']['respects `config` argument'] = function()
  reload_module({ make_global = { 'put' } })
  eq(child.lua_get('MiniMisc.config.make_global'), { 'put' })
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ make_global = 'a' }, 'make_global', 'table')
  expect_config_error({ make_global = { 'a' } }, 'make_global', 'actual fields')
end

T['setup()']['creates global functions'] = function()
  eq(child.lua_get('type(_G.put)'), 'function')
  eq(child.lua_get('type(_G.put_text)'), 'function')
end

T['bench_time()'] = new_set({
  hooks = {
    pre_case = function()
      child.lua('_G.f = function(ms) ms = ms or 10; vim.loop.sleep(ms); return ms end')
    end,
  },
})

local bench_time = function(...)
  return unpack(child.lua_get('{ MiniMisc.bench_time(_G.f, ...) }', { ... }))
end

-- Validate that benchmark is within tolerable error from target. This is
-- needed due to random nature of benchmarks.
local validate_benchmark = function(time_tbl, target, error)
  error = error or 0.2
  local s, n = 0, 0
  for _, x in ipairs(time_tbl) do
    s, n = s + x, n + 1
  end

  eq(n * target * (1 - error) < s, true)
  eq(s < target * (1 + error) * n, true)
end

T['bench_time()']['works'] = function()
  local b, res = bench_time()
  -- By default should run function once
  eq(#b, 1)
  validate_benchmark(b, 0.01)
  -- Second value is function output
  eq(res, 10)
end

T['bench_time()']['respects `n` argument'] = function()
  local b, _ = bench_time(5)
  -- By default should run function once
  eq(#b, 5)
  validate_benchmark(b, 0.01)
end

T['bench_time()']['respects `...` as benched time arguments'] = function()
  local b, res = bench_time(1, 50)
  validate_benchmark(b, 0.05)
  -- Second value is function output
  eq(res, 50)
end

T['get_gutter_width()'] = new_set()

T['get_gutter_width()']['works'] = function()
  -- By default there is no gutter ('sign column')
  eq(child.lua_get('MiniMisc.get_gutter_width()'), 0)

  -- This setting indeed makes gutter with width of two columns
  child.wo.signcolumn = 'yes:1'
  eq(child.lua_get('MiniMisc.get_gutter_width()'), 2)
end

T['get_gutter_width()']['respects `win_id` argument'] = function()
  child.cmd('split')
  local windows = child.api.nvim_list_wins()

  child.api.nvim_win_set_option(windows[1], 'signcolumn', 'yes:1')
  eq(child.lua_get('MiniMisc.get_gutter_width(...)', { windows[2] }), 0)
end

local validate_put = {
  put = function(args, reference_output)
    local capture = child.cmd_capture(('lua MiniMisc.put(%s)'):format(args))
    eq(capture, table.concat(reference_output, '\n'))
  end,

  put_text = function(args, reference_output)
    set_lines({})
    child.lua(('MiniMisc.put_text(%s)'):format(args))

    -- Insert text under current line
    table.insert(reference_output, 1, '')
    eq(get_lines(), reference_output)
  end,
}

T['put()/put_text()'] = new_set({
  parametrize = { { 'put' }, { 'put_text' } },
})

T['put()/put_text()']['works'] = function(put_name)
  local validate = validate_put[put_name]

  validate('{ a = 1, b = true }', { '{', '  a = 1,', '  b = true', '}' })
end

T['put()/put_text()']['allows several arguments'] = function(put_name)
  local validate = validate_put[put_name]

  child.lua('_G.a = 1; _G.b = true')
  validate('_G.a, _G.b', { '1', 'true' })
end

T['put()/put_text()']['handles tuple function output'] = function(put_name)
  local validate = validate_put[put_name]

  child.lua('_G.f = function() return 1, true end')
  validate('_G.f()', { '1', 'true' })
end

T['put()/put_text()']['prints `nil` values'] = function(put_name)
  local validate = validate_put[put_name]

  validate('nil', { 'nil' })
  validate('1, nil', { '1', 'nil' })
  validate('nil, 2', { 'nil', '2' })
  validate('1, nil, 2', { '1', 'nil', '2' })
end

local resize_initial_width, resize_win_id
T['resize_window()'] = new_set({
  hooks = {
    pre_case = function()
      -- Prepare two windows
      resize_initial_width = child.api.nvim_win_get_width(0)
      child.cmd('vsplit')
      resize_win_id = child.api.nvim_list_wins()[1]
    end,
  },
})

T['resize_window()']['works'] = function()
  local target_width = math.floor(0.25 * resize_initial_width)
  -- This sets gutter width to 4
  child.api.nvim_win_set_option(resize_win_id, 'signcolumn', 'yes:2')

  child.lua('MiniMisc.resize_window(...)', { resize_win_id, target_width })
  eq(child.api.nvim_win_get_width(resize_win_id), target_width + 4)
end

T['resize_window()']['correctly computes default `text_width` argument'] = function()
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
end

T['stat_summary()'] = new_set()

local stat_summary = function(...)
  return child.lua_get('MiniMisc.stat_summary({ ... })', { ... })
end

T['stat_summary()']['works'] = function()
  eq(stat_summary(10, 4, 3, 2, 1), { minimum = 1, mean = 4, median = 3, maximum = 10, n = 5, sd = math.sqrt(50 / 4) })
end

T['stat_summary()']['works with one number'] = function()
  eq(stat_summary(10), { minimum = 10, mean = 10, median = 10, maximum = 10, n = 1, sd = 0 })
end

T['stat_summary()']['handles even/odd number of elements for `median`'] = function()
  eq(stat_summary(1, 2).median, 1.5)
  eq(stat_summary(3, 1, 2).median, 2)
end

T['tbl_head()/tbl_tail()'] = new_set({
  parametrize = { { 'tbl_head' }, { 'tbl_tail' } },
})

T['tbl_head()/tbl_tail()']['works'] = function(fun_name)
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
end

local comments_option
T['use_nested_comments()'] = new_set({
  hooks = {
    pre_case = function()
      child.api.nvim_set_current_buf(child.api.nvim_create_buf(true, false))
      comments_option = child.bo.comments
    end,
  },
})

T['use_nested_comments()']['works'] = function()
  child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
  child.lua('MiniMisc.use_nested_comments()')
  eq(child.api.nvim_buf_get_option(0, 'comments'), 'n:#,' .. comments_option)
end

T['use_nested_comments()']["ignores 'commentstring' with two parts"] = function()
  child.api.nvim_buf_set_option(0, 'commentstring', '/*%s*/')
  child.lua('MiniMisc.use_nested_comments()')
  eq(child.api.nvim_buf_get_option(0, 'comments'), comments_option)
end

T['use_nested_comments()']['respects `buf_id` argument'] = function()
  local new_buf_id = child.api.nvim_create_buf(true, false)
  child.api.nvim_buf_set_option(new_buf_id, 'commentstring', '# %s')

  child.lua('MiniMisc.use_nested_comments(...)', { new_buf_id })

  eq(child.api.nvim_buf_get_option(0, 'comments'), comments_option)
  eq(child.api.nvim_buf_get_option(new_buf_id, 'comments'), 'n:#,' .. comments_option)
end

T['zoom()'] = new_set()

local get_floating_windows = function()
  return vim.tbl_filter(function(x)
    return child.api.nvim_win_get_config(x).relative ~= ''
  end, child.api.nvim_list_wins())
end

T['zoom()']['works'] = function()
  local buf_id = child.api.nvim_get_current_buf()
  child.lua('MiniMisc.zoom()')
  local floating_wins = get_floating_windows()

  eq(#floating_wins, 1)
  local win_id = floating_wins[1]
  eq(child.api.nvim_win_get_buf(win_id), buf_id)
  local config = child.api.nvim_win_get_config(win_id)
  eq({ config.height, config.width }, { 1000, 1000 })
end

T['zoom()']['respects `buf_id` argument'] = function()
  local buf_id = child.api.nvim_create_buf(true, false)
  child.lua('MiniMisc.zoom(...)', { buf_id })
  local floating_wins = get_floating_windows()

  eq(#floating_wins, 1)
  eq(child.api.nvim_win_get_buf(floating_wins[1]), buf_id)
end

T['zoom()']['respects `config` argument'] = function()
  local custom_config = { width = 20 }
  child.lua('MiniMisc.zoom(...)', { 0, custom_config })
  local floating_wins = get_floating_windows()

  eq(#floating_wins, 1)
  local config = child.api.nvim_win_get_config(floating_wins[1])
  eq({ config.height, config.width }, { 1000, 20 })
end

return T
