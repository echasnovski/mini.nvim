local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('hipatterns', config) end
local set_lines = function(...) return child.set_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Module helpers
local get_hipatterns_extmarks = function(buf_id)
  local ns_id = child.api.nvim_get_namespaces()['MiniHipatternsHighlight']
  return vim.tbl_map(
    function(full_extmark)
      return {
        line = full_extmark[2] + 1,
        from_col = full_extmark[3] + 1,
        to_col = full_extmark[4].end_col,
        hl_group = full_extmark[4].hl_group,
      }
    end,
    child.api.nvim_buf_get_extmarks(buf_id, ns_id, 0, -1, { details = true })
  )
end

local validate_hl_group = function(name, pattern) expect.match(child.cmd_capture('hi ' .. name), pattern) end

-- Data =======================================================================
local test_config = {
  highlighters = { abcd = { pattern = 'abcd', group = 'Error' } },
  delay = { text_change = 30, scroll = 10 },
}
local small_time = 5

local test_lines = { 'abcd abcd', 'Abcd ABCD', 'abcdaabcd' }

-- Output test set ============================================================
T = new_set({
  hooks = {
    pre_case = function()
      child.setup()
      child.set_size(10, 15)
    end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  load_module()

  -- Global variable
  eq(child.lua_get('type(_G.MiniHipatterns)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniHipatterns'), 1)

  -- Highlight groups
  expect.match(child.cmd_capture('hi MiniHipatternsFixme'), 'links to DiagnosticError')
  expect.match(child.cmd_capture('hi MiniHipatternsHack'), 'links to DiagnosticWarn')
  expect.match(child.cmd_capture('hi MiniHipatternsTodo'), 'links to DiagnosticInfo')
  expect.match(child.cmd_capture('hi MiniHipatternsNote'), 'links to DiagnosticHint')
end

T['setup()']['creates `config` field'] = function()
  load_module()

  eq(child.lua_get('type(_G.MiniHipatterns.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniHipatterns.config.' .. field), value) end

  expect_config('highlighters', {})
  expect_config('delay.text_change', 200)
  expect_config('delay.scroll', 50)
end

T['setup()']['respects `config` argument'] = function()
  load_module({ delay = { text_change = 20 } })
  eq(child.lua_get('MiniHipatterns.config.delay.text_change'), 20)
end

T['setup()']['validates `config` argument'] = function()
  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ highlighters = 'a' }, 'highlighters', 'table')
  expect_config_error({ delay = 'a' }, 'delay', 'table')
  expect_config_error({ delay = { text_change = 'a' } }, 'delay.text_change', 'number')
  expect_config_error({ delay = { scroll = 'a' } }, 'delay.scroll', 'number')
end

T['Auto enable'] = new_set()

T['Auto enable']['enables for normal buffers'] = function()
  child.set_size(10, 30)
  child.o.winwidth = 1

  local buf_id_1 = child.api.nvim_get_current_buf()
  set_lines(test_lines)
  child.cmd('wincmd v')

  local buf_id_2 = child.api.nvim_create_buf(true, false)
  child.api.nvim_buf_set_lines(buf_id_2, 0, -1, false, { '22abcd22' })

  local buf_id_3 = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf_id_3)
  set_lines({ '33abcd33' })

  load_module(test_config)
  -- Should enable in all proper buffers currently shown in some window
  child.expect_screenshot()
  eq(child.lua_get('MiniHipatterns.get_enabled_buffers()'), { buf_id_1, buf_id_3 })

  child.api.nvim_set_current_buf(buf_id_2)
  child.expect_screenshot()
  eq(child.lua_get('MiniHipatterns.get_enabled_buffers()'), { buf_id_1, buf_id_2, buf_id_3 })
end

T['Auto enable']['makes `:edit` work'] = function()
  load_module(test_config)

  local test_file = 'tests/hipatterns_file'
  MiniTest.finally(function() vim.fn.delete(test_file) end)

  child.cmd('edit ' .. test_file)
  set_lines(test_lines)
  child.cmd('write')

  sleep(test_config.delay.text_change + small_time)
  child.expect_screenshot()

  child.cmd('edit')
  child.expect_screenshot()
end

T['Auto enable']['does not enable for not normal buffers'] = function()
  load_module(test_config)
  local scratch_buf_id = child.api.nvim_create_buf(false, true)
  child.api.nvim_set_current_buf(scratch_buf_id)

  set_lines(test_lines)
  sleep(test_config.delay.text_change + small_time)
  -- Should be no highlighting
  child.expect_screenshot()
end

T['Autocommands'] = new_set()

T['Autocommands']['resets on color scheme change'] = function()
  child.set_size(10, 30)
  child.o.winwidth = 1

  child.lua([[_G.new_hl_group_highlighter = {
    pattern = 'aaa',
    group = function()
      vim.cmd('hi AAA cterm=underline')
      return 'AAA'
    end,
  }]])
  child.lua([[require('mini.hipatterns').setup({
    highlighters = { aaa = _G.new_hl_group_highlighter },
    delay = { text_change = 20 },
  })]])

  set_lines({ 'aaa' })
  child.cmd('wincmd v | enew')
  set_lines({ 'xxaaaxx' })

  sleep(20 + 2)
  child.expect_screenshot()

  -- After `:hi clear` highlighting disappears as highlight group is cleared
  child.cmd('hi clear')
  child.expect_screenshot()

  -- Calling `colorscheme` triggers `ColorScheme` event which should lead to
  -- highlight reevaluation of all enabled buffers
  child.cmd('colorscheme blue')
  child.expect_screenshot()
end

T['enable()'] = new_set()

local enable = function(...) child.lua([[require('mini.hipatterns').enable(...)]], { ... }) end

local get_enabled_buffers =
  function(...) return child.lua_get([[require('mini.hipatterns').get_enabled_buffers(...)]], { ... }) end

T['enable()']['works'] = function()
  set_lines(test_lines)
  enable(0, test_config)

  -- Should register buffer as enabled
  eq(get_enabled_buffers(), { child.api.nvim_get_current_buf() })

  -- Should add highlights immediately
  child.expect_screenshot()

  -- Should disable on buffer detach
  child.ensure_normal_mode()
  child.cmd('bdelete!')
  eq(get_enabled_buffers(), {})
end

T['enable()']['works with defaults'] = function()
  child.b.minihipatterns_config = test_config
  set_lines(test_lines)
  enable()
  child.expect_screenshot()
end

T['enable()']['works in not normal buffer'] = function()
  local scratch_buf_id = child.api.nvim_create_buf(false, true)
  child.api.nvim_set_current_buf(scratch_buf_id)

  set_lines({ 'xxabcdxx' })
  enable(scratch_buf_id, test_config)
  child.expect_screenshot()
end

T['enable()']['works in not current buffer'] = function()
  local new_buf_id = child.api.nvim_create_buf(true, false)
  child.api.nvim_buf_set_lines(new_buf_id, 0, -1, false, { 'xxabcdxx' })

  enable(new_buf_id, test_config)

  child.api.nvim_set_current_buf(new_buf_id)
  child.expect_screenshot()
end

T['enable()']['reacts to text change'] = function()
  -- Should enable debounced auto highlight on text change
  enable(0, test_config)

  -- Interactive text change
  type_keys('i', 'abc')
  sleep(test_config.delay.text_change - small_time)
  type_keys('d')

  -- - No highlights should be shown as delay was smaller than in config
  child.expect_screenshot()

  -- - Still no highlights should be shown
  sleep(test_config.delay.text_change - small_time)
  child.expect_screenshot()

  -- - Now there should be highlights
  sleep(2 * small_time)
  child.expect_screenshot()

  -- Not interactive text change
  set_lines({ 'ABCD', 'abcd' })

  child.expect_screenshot()
  sleep(test_config.delay.text_change + small_time)
  child.expect_screenshot()
end

T['enable()']['does not flicker during text insert'] = function()
  enable(0, test_config)

  -- Interactive text change
  type_keys('i', 'abcd')
  sleep(test_config.delay.text_change + small_time)
  child.expect_screenshot()

  type_keys(' abcd')
  child.expect_screenshot()
  sleep(test_config.delay.text_change + small_time)
  child.expect_screenshot()
end

T['enable()']['reacts to buffer enter'] = function()
  local init_buf_id = child.api.nvim_get_current_buf()
  enable(init_buf_id, { highlighters = test_config.highlighters })

  local other_buf_id = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(other_buf_id)

  -- On buffer enter it should update config and highlighting (after delay)
  local lua_cmd = string.format('vim.b[%d].minihipatterns_config = { delay = { text_change = 10 } }', init_buf_id)
  child.lua(lua_cmd)
  child.api.nvim_buf_set_lines(init_buf_id, 0, -1, false, { 'abcd' })

  child.api.nvim_set_current_buf(init_buf_id)

  child.expect_screenshot()
  sleep(10 + small_time)
  child.expect_screenshot()
end

T['enable()']['reacts to filetype change'] = function()
  child.lua([[_G.hipatterns_config = {
    highlighters = {
      abcd_ft = {
        pattern = function(buf_id)
          if vim.bo[buf_id].filetype == 'aaa' then return nil end
          return 'abcd'
        end,
        group = 'Error'
      },
    },
    delay = { text_change = 20 },
  }]])

  set_lines({ 'xxabcdxx' })
  child.lua([[require('mini.hipatterns').enable(0, _G.hipatterns_config)]])
  child.expect_screenshot()

  -- Should update highlighting after delay
  child.cmd('set filetype=aaa')
  child.expect_screenshot()
  sleep(20 + 2)
  child.expect_screenshot()
end

T['enable()']['reacts to window scroll'] = function()
  local config = { highlighters = test_config.highlighters, delay = { text_change = 30, scroll = 10 } }
  enable(0, config)

  -- Change same line each before `delay.text_change`. This creates a situation
  -- when only one line will be highlighted while others - don't (but should).
  set_lines({ 'xxabcdxx' })
  type_keys('yy')
  for _ = 1, 15 do
    type_keys('P')
  end

  sleep(30 + 2)
  child.expect_screenshot()

  -- Scroll should update highlighting inside view with `delay.scroll` debounce
  type_keys('<C-e>')
  sleep(5)
  type_keys('<C-e>')
  sleep(10 + 1)
  child.expect_screenshot()

  -- Update should be done only on the final view
  type_keys('<C-y>')
  child.expect_screenshot()
  type_keys('2<C-e>')
  child.expect_screenshot()
end

T['Highlighters'] = new_set()

T['Highlighters']['silently skips wrong entries'] = function()
  local highlighters = {
    correct = { pattern = 'abcd', group = 'Error' },
    pattern_absent = { group = 'Error' },
    pattern_wrong_type = { pattern = 1, group = 'Error' },
    group_absent = { pattern = 'aaa' },
    group_wrong_type = { pattern = 'aaa', group = 1 },
    priority_wrong_type = { pattern = 'aaa', group = 'Error', priority = 'a' },
  }
  enable(0, { highlighters = highlighters, delay = { text_change = 20 } })

  set_lines({ 'xxabcd', 'aaa' })
  sleep(20 + 2)
  child.expect_screenshot()
end

T['Highlighters']['allows submatch in `pattern`'] = function()
  set_lines({ 'abcd', 'xabcd', 'xxabcd', 'xxabcdxx' })

  local validate = function(pattern)
    child.lua([[require('mini.hipatterns').disable()]])
    local config = {
      highlighters = { abcd = { pattern = pattern, group = 'Error' } },
      delay = { text_change = 20 },
    }
    enable(0, config)

    sleep(20 + 2)
    child.expect_screenshot()
  end

  validate('xx()ab()cd')
  validate('()ab()cd')
  validate('ab()cd()')

  -- One capture `()` should also work treating it as start and inferring end
  -- as full match's end
  validate('()abcd')

  -- Third an more captures should be ignored
  validate('xx()ab()c()d()')
end

T['Highlighters']['allows frontier pattern in `pattern`'] = function()
  local config = {
    highlighters = { abcd = { pattern = '%f[%w]abcd%f[%W]', group = 'Error' } },
    delay = { text_change = 20 },
  }
  enable(0, config)

  set_lines({ 'abcd', 'xabcd', 'abcdx', 'xabcdx', ' abcd ' })
  sleep(20 + 2)
  child.expect_screenshot()
end

T['Highlighters']['allows callable `pattern`'] = function()
  child.lua([[_G.hi_callable_pattern = {
    pattern = function(...)
      _G.args = { ... }
      return 'abcd'
    end,
    group = 'Error'
  }]])
  child.lua([[require('mini.hipatterns').enable(
    0,
    {
      highlighters = { test = _G.hi_callable_pattern },
      delay = { text_change = 20 },
    }
  )]])

  set_lines({ 'xxabcd' })
  sleep(20 + 2)
  child.expect_screenshot()
  -- Should be called with correct signature
  eq(child.lua_get('_G.args'), { child.api.nvim_get_current_buf() })
end

T['Highlighters']['allows return `nil` `pattern` to not highlight'] = function()
  child.lua([[_G.hi_conditional_pattern = {
    pattern = function(buf_id)
      if vim.b[buf_id].not_highlight then return nil end
      return 'abcd'
    end,
    group = 'Error'
  }]])
  child.lua([[require('mini.hipatterns').enable(
    0,
    { highlighters = { test = _G.hi_conditional_pattern }, delay = { text_change = 20 } }
  )]])

  set_lines({ 'xxabcd' })
  sleep(20 + 2)
  child.expect_screenshot()

  child.b.not_highlight = true
  set_lines({ 'xxabcd' })
  sleep(20 + 2)
  child.expect_screenshot()
end

T['Highlighters']['allows callable `group`'] = function()
  child.lua([[_G.hi_callable_group = {
    pattern = 'abcd',
    group = function(...)
      _G.args = { ... }
      return 'Error'
    end,
  }]])
  child.lua([[require('mini.hipatterns').enable(
    0,
    {
      highlighters = { test = _G.hi_callable_group },
      delay = { text_change = 20 },
    }
  )]])

  set_lines({ 'xxabcd' })
  sleep(20 + 2)
  child.expect_screenshot()
  -- Should be called with correct signature
  eq(child.lua_get('_G.args'), { 1, 'abcd', { full_match = 'abcd', line = 1, from_col = 3, to_col = 6 } })

  -- Check arguments with submatch
  local validate_submatch = function(pattern, ref_args)
    child.lua('_G.args = nil')
    child.lua('_G.hi_callable_group.pattern = ' .. vim.inspect(pattern))
    set_lines({ 'abcd' })
    sleep(20 + 2)
    eq(child.lua_get('_G.args'), ref_args)
  end

  validate_submatch('()ab()cd', { 1, 'ab', { full_match = 'abcd', line = 1, from_col = 1, to_col = 2 } })
  validate_submatch('a()bc()d', { 1, 'bc', { full_match = 'abcd', line = 1, from_col = 2, to_col = 3 } })
  validate_submatch('ab()cd()', { 1, 'cd', { full_match = 'abcd', line = 1, from_col = 3, to_col = 4 } })

  validate_submatch('a()bcd', { 1, 'bcd', { full_match = 'abcd', line = 1, from_col = 2, to_col = 4 } })
end

T['Highlighters']['allows return `nil` `group` to not highlight'] = function()
  child.lua([[_G.hi_conditional_group = {
    pattern = 'abcd',
    group = function(buf_id, match, data)
      -- Don't highlight on even lines
      if data.line % 2 == 0 then return nil end
      return 'Error'
    end,
  }]])
  child.lua([[require('mini.hipatterns').enable(
    0,
    { highlighters = { test = _G.hi_conditional_group }, delay = { text_change = 20 } }
  )]])

  set_lines({ 'xxabcd', 'xxabcd', 'xxabcd', 'xxabcd', 'xxabcd' })
  sleep(20 + 2)
  child.expect_screenshot()
end

T['Highlighters']['respects `priority`'] = function()
  local config = { highlighters = { abcd = { pattern = 'abcd', group = 'Error' } }, delay = { text_change = 20 } }
  set_lines({ 'abcd', 'abcd', 'abcd' })
  enable(0, config)
  child.expect_screenshot()

  local ns_id = child.api.nvim_create_namespace('test')
  local set_extmark = function(line, priority)
    child.api.nvim_buf_set_extmark(0, ns_id, line - 1, 0, { end_col = 4, hl_group = 'Visual', priority = priority })
  end

  -- Default priority should be 200
  set_extmark(1, 199)
  set_extmark(3, 201)
  child.expect_screenshot()

  -- Should respect priority in `highlighters` entry
  child.lua([[require('mini.hipatterns').disable(0)]])
  config.highlighters.abcd.priority = 202
  enable(0, config)
  child.expect_screenshot()
end

T['enable()']['validates arguments'] = function()
  expect.error(function() enable('a', {}) end, '`buf_id`.*valid buffer id')
  expect.error(function() enable(child.api.nvim_get_current_buf(), 'a') end, '`config`.*table')
end

T['enable()']['respects `vim.{g,b}.minihipatterns_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minihipatterns_disable = true

    set_lines(test_lines)
    enable(0, test_config)
    sleep(test_config.delay.text_change + small_time)
    child.expect_screenshot()
  end,
})

T['enable()']['respects global config after `setup()`'] = function()
  set_lines(test_lines)
  load_module(test_config)
  enable(0)

  child.expect_screenshot()
end

T['enable()']['respects `vim.b.minihipatterns_config`'] = function()
  set_lines(test_lines)
  child.b.minihipatterns_config = test_config
  enable(0)

  child.expect_screenshot()

  -- Delay should also be respected
  set_lines({ 'abcd' })
  sleep(test_config.delay.text_change - small_time)
  child.expect_screenshot()
  sleep(2 * small_time)
  child.expect_screenshot()
end

T['disable()'] = new_set()

local disable = function(...) child.lua([[require('mini.hipatterns').disable(...)]], { ... }) end

T['disable()']['works'] = function()
  local cur_buf_id = child.api.nvim_get_current_buf()
  set_lines(test_lines)
  enable(0, test_config)
  child.expect_screenshot()

  -- By default should disable current buffer
  disable()
  child.expect_screenshot()
  eq(get_enabled_buffers(), {})

  -- Allows 0 as alias for current buffer
  enable(0, test_config)
  eq(get_enabled_buffers(), { cur_buf_id })
  disable(0)
  eq(get_enabled_buffers(), {})
end

T['disable()']['works in not current buffer'] = function()
  local init_buf_id = child.api.nvim_get_current_buf()
  set_lines(test_lines)
  enable(0, test_config)
  child.expect_screenshot()

  child.api.nvim_set_current_buf(child.api.nvim_create_buf(true, false))
  disable(init_buf_id)
  child.api.nvim_set_current_buf(init_buf_id)
  sleep(test_config.delay.text_change + small_time)
  child.expect_screenshot()
end

T['disable()']['works on not enabled buffer'] = function()
  expect.no_error(function() disable(0) end)
end

T['disable()']['validates arguments'] = function()
  expect.error(function() disable('a') end, '`buf_id`.*valid buffer id')
end

T['toggle()'] = new_set()

local toggle = function(...) child.lua([[require('mini.hipatterns').toggle(...)]], { ... }) end

T['toggle()']['works'] = function()
  local cur_buf_id = child.api.nvim_get_current_buf()
  set_lines(test_lines)

  -- By default should disable current buffer
  child.lua('_G.test_config = ' .. vim.inspect(test_config))
  child.lua([[require('mini.hipatterns').toggle(nil, test_config)]])
  child.expect_screenshot()
  eq(get_enabled_buffers(), { cur_buf_id })

  toggle()
  child.expect_screenshot()
  eq(get_enabled_buffers(), {})

  -- Allows 0 as alias for current buffer
  toggle(0, test_config)
  eq(get_enabled_buffers(), { cur_buf_id })

  toggle(0)
  eq(get_enabled_buffers(), {})
end

T['toggle()']['validates arguments'] = function()
  expect.error(function() toggle('a', {}) end, '`buf_id`.*valid buffer id')
  expect.error(function() toggle(child.api.nvim_get_current_buf(), 'a') end, '`config`.*table')
end

T['update()'] = new_set()

local update = function(...) child.lua([[require('mini.hipatterns').update(...)]], { ... }) end

T['update()']['works'] = function()
  child.lua([[_G.hi_conditional_pattern = {
    pattern = function(buf_id)
      if vim.b[buf_id].not_highlight then return nil end
      return 'abcd'
    end,
    group = 'Error'
  }]])
  child.lua([[require('mini.hipatterns').enable(
    0,
    { highlighters = { test = _G.hi_conditional_pattern }, delay = { text_change = 20 } }
  )]])

  local lines = { 'xxabcd', 'xxabcd', 'xxabcd', 'xxabcd' }
  set_lines(lines)
  sleep(test_config.delay.text_change + small_time)

  child.expect_screenshot()

  -- Should update immediately to not highlight only lines 2 and 3
  child.b.not_highlight = true
  update(0, 2, 3)
  child.expect_screenshot()

  -- Should work for single lines
  child.b.not_highlight = true
  update(0, 1, 1)
  child.expect_screenshot()

  -- `from_line` should be inferred as 1
  child.b.not_highlight = false
  child.lua([[require('mini.hipatterns').update(0, nil, 3)]])
  child.expect_screenshot()

  -- `to_line` should be inferred as last line
  child.b.not_highlight = true
  child.lua([[require('mini.hipatterns').update(0, 2, nil)]])
  child.expect_screenshot()

  -- Works on not current buffer
  local init_buf_id = child.api.nvim_get_current_buf()
  child.api.nvim_set_current_buf(child.api.nvim_create_buf(true, false))

  child.api.nvim_buf_set_var(init_buf_id, 'not_highlight', false)
  update(init_buf_id, 2, 3)
  child.api.nvim_set_current_buf(init_buf_id)
  child.expect_screenshot()
end

T['update()']['does not work in not enabled buffer'] = function()
  local cur_buf_id = child.api.nvim_get_current_buf()
  set_lines(test_lines)

  expect.error(function() update(cur_buf_id, 1, 2) end, 'Buffer ' .. cur_buf_id .. ' is not enabled')
end

T['update()']['validates arguments'] = function()
  enable(0)

  expect.error(function() update('a', 1, 2) end, '`buf_id`.*valid buffer id')
  expect.error(function() update(0, 'a', 2) end, '`from_line`.*number')
  expect.error(function() update(0, 1, 'a') end, '`to_line`.*number')
end

T['get_enabled_buffers()'] = new_set()

T['get_enabled_buffers()']['works'] = function()
  local create_buf = function() return child.api.nvim_create_buf(true, false) end
  local buf_id_1 = create_buf()
  local buf_id_2 = create_buf()
  local buf_id_3 = create_buf()
  local buf_id_4 = create_buf()

  enable(buf_id_3)
  enable(buf_id_1)
  enable(buf_id_4)
  eq(get_enabled_buffers(), { buf_id_1, buf_id_3, buf_id_4 })

  disable(buf_id_3)
  eq(get_enabled_buffers(), { buf_id_1, buf_id_4 })

  -- Does not return invalid buffers
  child.api.nvim_buf_delete(buf_id_4, {})
  eq(get_enabled_buffers(), { buf_id_1 })
end

T['gen_highlighter'] = new_set()

T['gen_highlighter']['hex_color()'] = new_set()

local enable_hex_color = function(...)
  child.lua(
    [[_G.hipatterns = require('mini.hipatterns')
      _G.hipatterns.setup({
        highlighters = { hex_color = _G.hipatterns.gen_highlighter.hex_color(...) },
      })]],
    { ... }
  )
end

T['gen_highlighter']['hex_color()']['works'] = function()
  set_lines({
    -- Should be highlighted
    '#000000 #ffffff',
    '#FffFFf',

    -- Should not be highlighted
    '#00000 #0000000',
    '#00000g',
  })

  enable_hex_color()

  child.expect_screenshot()

  -- Should use correct highlight groups
  --stylua: ignore
  eq(get_hipatterns_extmarks(0), {
    { line = 1, from_col = 1, to_col = 7,  hl_group = 'MiniHipatterns000000' },
    { line = 1, from_col = 9, to_col = 15, hl_group = 'MiniHipatternsffffff' },
    { line = 2, from_col = 1, to_col = 7,  hl_group = 'MiniHipatternsffffff' },
  })
  expect.match(child.cmd_capture('hi MiniHipatterns000000'), 'guifg=#ffffff guibg=#000000')
  expect.match(child.cmd_capture('hi MiniHipatternsffffff'), 'guifg=#000000 guibg=#ffffff')
end

T['gen_highlighter']['hex_color()']["works with style '#'"] = function()
  set_lines({ '#000000 #ffffff' })

  enable_hex_color({ style = '#' })

  child.expect_screenshot()

  -- Should use correct highlight groups
  eq(get_hipatterns_extmarks(0), {
    { line = 1, from_col = 1, to_col = 1, hl_group = 'MiniHipatterns000000' },
    { line = 1, from_col = 9, to_col = 9, hl_group = 'MiniHipatternsffffff' },
  })
  expect.match(child.cmd_capture('hi MiniHipatterns000000'), 'guifg=#ffffff guibg=#000000')
  expect.match(child.cmd_capture('hi MiniHipatternsffffff'), 'guifg=#000000 guibg=#ffffff')
end

T['gen_highlighter']['hex_color()']["works with style 'line'"] = function()
  set_lines({ '#000000 #ffffff' })

  enable_hex_color({ style = 'line' })

  child.expect_screenshot()

  -- Should use correct highlight groups
  --stylua: ignore
  eq(get_hipatterns_extmarks(0), {
    { line = 1, from_col = 1, to_col = 7,  hl_group = 'MiniHipatterns000000' },
    { line = 1, from_col = 9, to_col = 15, hl_group = 'MiniHipatternsffffff' },
  })
  expect.match(child.cmd_capture('hi MiniHipatterns000000'), 'gui=underline guisp=#000000')
  expect.match(child.cmd_capture('hi MiniHipatternsffffff'), 'gui=underline guisp=#ffffff')
end

T['gen_highlighter']['hex_color()']['correctly computes highlight group'] = function()
  set_lines({ '#767676 #777777', '#098777 #178d7c' })

  enable_hex_color()
  sleep(2 * small_time)

  --stylua: ignore
  eq(get_hipatterns_extmarks(0), {
    { line = 1, from_col = 1, to_col = 7,  hl_group = 'MiniHipatterns767676' },
    { line = 1, from_col = 9, to_col = 15, hl_group = 'MiniHipatterns777777' },
    { line = 2, from_col = 1, to_col = 7,  hl_group = 'MiniHipatterns098777' },
    { line = 2, from_col = 9, to_col = 15, hl_group = 'MiniHipatterns178d7c' },
  })

  validate_hl_group('MiniHipatterns767676', 'guifg=#ffffff guibg=#767676')
  validate_hl_group('MiniHipatterns777777', 'guifg=#000000 guibg=#777777')
  validate_hl_group('MiniHipatterns098777', 'guifg=#ffffff guibg=#098777')
  validate_hl_group('MiniHipatterns178d7c', 'guifg=#000000 guibg=#178d7c')
end

T['gen_highlighter']['hex_color()']['is present after color scheme change'] = function()
  set_lines({ '#000000 #ffffff' })
  enable_hex_color()
  sleep(2 * small_time)

  child.cmd('hi clear')
  child.cmd('colorscheme blue')

  sleep(2 * small_time)
  --stylua: ignore
  eq(get_hipatterns_extmarks(0), {
    { line = 1, from_col = 1, to_col = 7,  hl_group = 'MiniHipatterns000000' },
    { line = 1, from_col = 9, to_col = 15, hl_group = 'MiniHipatternsffffff' },
  })
  expect.match(child.cmd_capture('hi MiniHipatterns000000'), 'guifg=#ffffff guibg=#000000')
  expect.match(child.cmd_capture('hi MiniHipatternsffffff'), 'guifg=#000000 guibg=#ffffff')
end

T['gen_highlighter']['hex_color()']['respects `opts.priority`'] = function()
  set_lines({ '#000000', '#000000', '#000000' })
  enable_hex_color()
  sleep(2 * small_time)

  child.expect_screenshot()

  local ns_id = child.api.nvim_create_namespace('test')
  child.cmd('hi Temp guifg=#aaaaaa')
  local set_extmark = function(line, priority)
    child.api.nvim_buf_set_extmark(0, ns_id, line - 1, 0, { end_col = 7, hl_group = 'Temp', priority = priority })
  end

  -- Default priority should be 200
  set_extmark(1, 199)
  set_extmark(3, 201)
  child.expect_screenshot()

  -- Should respect priority in `highlighters` entry
  disable(0)
  enable_hex_color({ priority = 202 })
  child.expect_screenshot()
end

T['gen_highlighter']['hex_color()']['respects `opts.filter`'] = function()
  set_lines({ '#000000 #ffffff' })

  child.lua([[
    _G.hipatterns = require('mini.hipatterns')
    _G.filter = function(buf_id) return vim.b[buf_id].do_highlight end
    _G.hipatterns.enable(0, {
      highlighters = {
        hex_color = _G.hipatterns.gen_highlighter.hex_color({ filter = _G.filter }),
      },
    })
  ]])

  -- Should not highlight
  child.b.do_highlight = false
  update(0)
  child.expect_screenshot()

  -- Should highlight
  child.b.do_highlight = true
  update(0)
  child.expect_screenshot()
end

T['compute_hex_color_group()'] = new_set()

local compute_hex_color_group =
  function(...) return child.lua_get([[require('mini.hipatterns').compute_hex_color_group(...)]], { ... }) end

T['compute_hex_color_group()']['works'] = function()
  eq(compute_hex_color_group('#000000', 'bg'), 'MiniHipatterns000000')
  eq(compute_hex_color_group('#ffffff', 'bg'), 'MiniHipatternsffffff')
  eq(compute_hex_color_group('#767676', 'bg'), 'MiniHipatterns767676')
  eq(compute_hex_color_group('#777777', 'bg'), 'MiniHipatterns777777')
  eq(compute_hex_color_group('#098777', 'bg'), 'MiniHipatterns098777')
  eq(compute_hex_color_group('#178d7c', 'bg'), 'MiniHipatterns178d7c')

  validate_hl_group('MiniHipatterns000000', 'guifg=#ffffff guibg=#000000')
  validate_hl_group('MiniHipatternsffffff', 'guifg=#000000 guibg=#ffffff')
  validate_hl_group('MiniHipatterns767676', 'guifg=#ffffff guibg=#767676')
  validate_hl_group('MiniHipatterns777777', 'guifg=#000000 guibg=#777777')
  validate_hl_group('MiniHipatterns098777', 'guifg=#ffffff guibg=#098777')
  validate_hl_group('MiniHipatterns178d7c', 'guifg=#000000 guibg=#178d7c')

  -- Should use cache per `hex_color`
  eq(compute_hex_color_group('#767676', 'line'), 'MiniHipatterns767676')
  validate_hl_group('MiniHipatterns767676', 'guifg=#ffffff guibg=#767676')
end

T['compute_hex_color_group()']['respects `style` argument'] = function()
  eq(compute_hex_color_group('#000000', 'line'), 'MiniHipatterns000000')
  validate_hl_group('MiniHipatterns000000', 'gui=underline guisp=#000000')
end

T['compute_hex_color_group()']['clears cache after `:colorscheme`'] = function()
  -- Needs `setup()` call to create `ColorScheme` autocommand
  load_module()

  eq(compute_hex_color_group('#000000', 'bg'), 'MiniHipatterns000000')
  validate_hl_group('MiniHipatterns000000', 'guifg=#ffffff guibg=#000000')

  child.cmd('colorscheme blue')
  eq(compute_hex_color_group('#000000', 'line'), 'MiniHipatterns000000')
  validate_hl_group('MiniHipatterns000000', 'gui=underline guisp=#000000')
end

return T
