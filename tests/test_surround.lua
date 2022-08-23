local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('surround', config) end
local unload_module = function() child.mini_unload('surround') end
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
local clear_messages = function() child.cmd('messages clear') end

local get_latest_message = function() return child.cmd_capture('1messages') end

local has_message_about_not_found = function(char, n_lines, search_method)
  n_lines = n_lines or 20
  search_method = search_method or 'cover'
  local msg = string.format(
    [[(mini.surround) No surrounding '%s' found within %s lines and `config.search_method = '%s'`.]],
    char,
    n_lines,
    search_method
  )
  eq(get_latest_message(), msg)
end

-- Custom validators
local validate_edit = function(before_lines, before_cursor, after_lines, after_cursor, test_action, ...)
  child.ensure_normal_mode()

  set_lines(before_lines)
  set_cursor(unpack(before_cursor))

  test_action(...)

  eq(get_lines(), after_lines)
  eq(get_cursor(), after_cursor)
end

local validate_find = function(lines, start_pos, positions, f, ...)
  set_lines(lines)
  set_cursor(unpack(start_pos))

  for _, pos in ipairs(positions) do
    f(...)
    eq(get_lines(), lines)
    eq(get_cursor(), pos)
  end
end

-- Output test set ============================================================
T = new_set({
  hooks = {
    pre_case = function()
      child.setup()
      load_module()

      -- Avoid hit-enter-prompt
      child.o.cmdheight = 10
    end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  -- Global variable
  eq(child.lua_get('type(_G.MiniSurround)'), 'table')

  -- Highlight groups
  expect.match(child.cmd_capture('hi MiniSurround'), 'links to IncSearch')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniSurround.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniSurround.config.' .. field), value) end

  -- Check default values
  expect_config('custom_surroundings', vim.NIL)
  expect_config('n_lines', 20)
  expect_config('highlight_duration', 500)
  expect_config('mappings.add', 'sa')
  expect_config('mappings.delete', 'sd')
  expect_config('mappings.find', 'sf')
  expect_config('mappings.find_left', 'sF')
  expect_config('mappings.highlight', 'sh')
  expect_config('mappings.replace', 'sr')
  expect_config('mappings.update_n_lines', 'sn')
  expect_config('search_method', 'cover')
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ n_lines = 10 })
  eq(child.lua_get('MiniSurround.config.n_lines'), 10)
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ custom_surroundings = 'a' }, 'custom_surroundings', 'table')
  expect_config_error({ highlight_duration = 'a' }, 'highlight_duration', 'number')
  expect_config_error({ mappings = 'a' }, 'mappings', 'table')
  expect_config_error({ mappings = { add = 1 } }, 'mappings.add', 'string')
  expect_config_error({ mappings = { delete = 1 } }, 'mappings.delete', 'string')
  expect_config_error({ mappings = { find = 1 } }, 'mappings.find', 'string')
  expect_config_error({ mappings = { find_left = 1 } }, 'mappings.find_left', 'string')
  expect_config_error({ mappings = { highlight = 1 } }, 'mappings.highlight', 'string')
  expect_config_error({ mappings = { replace = 1 } }, 'mappings.replace', 'string')
  expect_config_error({ mappings = { update_n_lines = 1 } }, 'mappings.update_n_lines', 'string')
  expect_config_error({ n_lines = 'a' }, 'n_lines', 'number')
  expect_config_error({ search_method = 1 }, 'search_method', 'one of')
end

-- Integration tests ==========================================================
-- Operators ------------------------------------------------------------------
T['Add surrounding'] = new_set()

T['Add surrounding']['works in Normal mode with dot-repeat'] = function()
  validate_edit({ 'aaa' }, { 1, 0 }, { '(aaa)' }, { 1, 1 }, type_keys, 'sa', 'iw', ')')
  validate_edit({ ' aaa ' }, { 1, 1 }, { ' (aaa) ' }, { 1, 2 }, type_keys, 'sa', 'iw', ')')

  -- Allows immediate dot-repeat
  type_keys('.')
  eq(get_lines(), { ' ((aaa)) ' })
  eq(get_cursor(), { 1, 3 })

  -- Allows not immediate dot-repeat
  set_lines({ 'aaa bbb' })
  set_cursor(1, 5)
  type_keys('.')
  eq(get_lines(), { 'aaa (bbb)' })
end

T['Add surrounding']['works in Visual mode without dot-repeat'] = function()
  -- Reset dot-repeat
  set_lines({ ' aaa ' })
  type_keys('dd')

  validate_edit({ ' aaa ' }, { 1, 1 }, { ' (aaa) ' }, { 1, 2 }, type_keys, 'viw', 'sa', ')')
  eq(child.fn.mode(), 'n')

  -- Does not allow dot-repeat. Should do `dd`.
  type_keys('.')
  eq(get_lines(), { '' })
end

T['Add surrounding']['works in line and block Visual mode'] = function()
  validate_edit({ 'aaa' }, { 1, 0 }, { '(aaa)' }, { 1, 1 }, type_keys, 'V', 'sa', ')')

  validate_edit({ 'aaa', 'bbb' }, { 1, 0 }, { '(aaa', 'bbb)' }, { 1, 1 }, type_keys, '<C-v>j$', 'sa', ')')
end

T['Add surrounding']['validates single character user input'] = function()
  validate_edit({ ' aaa ' }, { 1, 1 }, { ' aaa ' }, { 1, 1 }, type_keys, 'sa', 'iw', '<C-v>')
  eq(get_latest_message(), '(mini.surround) Input must be single character: alphanumeric, punctuation, or space.')
end

T['Add surrounding']['places cursor to the right of left surrounding'] = function()
  local f = function(textobject, visual_key)
    if visual_key == nil then
      type_keys('sa', textobject)
    else
      type_keys(visual_key, textobject, 'sa')
    end
    type_keys('f', 'myfunc', '<CR>')
  end

  -- Same line
  validate_edit({ 'aaa' }, { 1, 0 }, { 'myfunc(aaa)' }, { 1, 7 }, f, 'iw')
  validate_edit({ 'aaa' }, { 1, 0 }, { 'myfunc(aaa)' }, { 1, 7 }, f, 'iw', 'v')
  validate_edit({ 'aaa' }, { 1, 0 }, { 'myfunc(aaa)' }, { 1, 7 }, f, '', 'V')

  -- Not the same line
  validate_edit({ 'aaa', 'bbb', 'ccc' }, { 2, 0 }, { 'myfunc(aaa', 'bbb', 'ccc)' }, { 1, 7 }, f, 'ip')
  validate_edit({ 'aaa', 'bbb', 'ccc' }, { 2, 0 }, { 'myfunc(aaa', 'bbb', 'ccc)' }, { 1, 7 }, f, 'ip', 'v')
  validate_edit({ 'aaa', 'bbb', 'ccc' }, { 2, 0 }, { 'myfunc(aaa', 'bbb', 'ccc)' }, { 1, 7 }, f, 'ip', 'V')
end

T['Add surrounding']['prompts helper message after one idle second'] = function()
  set_lines({ ' aaa ' })
  set_cursor(1, 1)

  -- Execute one time to test if 'needs help message' flag is set per call
  type_keys('sa', 'iw', ')')
  sleep(200)

  type_keys('sa', 'iw')
  sleep(1000 - 10)
  eq(get_latest_message(), '')
  sleep(10 + 2)
  eq(get_latest_message(), '(mini.surround) Enter output surrounding identifier (single character) ')
end

T['Add surrounding']['works with multibyte characters'] = function()
  local f = function() type_keys('sa', 'iw', ')') end

  validate_edit({ '  ыыы  ' }, { 1, 2 }, { '  (ыыы)  ' }, { 1, 3 }, f)
  validate_edit({ 'ыыы ttt' }, { 1, 2 }, { '(ыыы) ttt' }, { 1, 1 }, f)
  validate_edit({ 'ttt ыыы' }, { 1, 4 }, { 'ttt (ыыы)' }, { 1, 5 }, f)
end

T['Add surrounding']['works on whole line'] = function()
  -- Should ignore indent at left mark but not whitespace at right
  validate_edit({ '  aaa ', '' }, { 1, 0 }, { '  (aaa )', '' }, { 1, 3 }, type_keys, 'sa', '_', ')')
  validate_edit({ '  aaa ', '' }, { 1, 0 }, { '  (aaa )', '' }, { 1, 3 }, type_keys, 'V', 'sa', ')')
end

T['Add surrounding']['works on multiple lines'] = function()
  local f = function() type_keys('sa', 'ap', ')') end
  local f_vis = function() type_keys('Vap', 'sa', ')') end

  -- Should ignore indent at left mark but not whitespace at right
  validate_edit({ '  aaa ', 'bbb', ' ccc' }, { 1, 0 }, { '  (aaa ', 'bbb', ' ccc)' }, { 1, 3 }, f)
  validate_edit({ '  aaa ', 'bbb', ' ccc' }, { 1, 0 }, { '  (aaa ', 'bbb', ' ccc)' }, { 1, 3 }, f_vis)
  validate_edit({ '  aaa ', ' ' }, { 1, 0 }, { '  (aaa ', ' )' }, { 1, 3 }, f)
  validate_edit({ '  aaa ', ' ' }, { 1, 0 }, { '  (aaa ', ' )' }, { 1, 3 }, f_vis)
end

T['Add surrounding']['works with multiline output surroundings'] = function()
  child.lua([[MiniSurround.config.custom_surroundings = {
    a = { output = { left = '\n(\n', right = '\n)\n' } }
  }]])
  local lines = { '  xxx' }
  validate_edit(lines, { 1, 3 }, { '  ', '(', 'xxx', ')', '' }, { 1, 1 }, type_keys, 'sa', 'iw', 'a')
end

T['Add surrounding']['works when using $ motion'] = function()
  -- It might not work because cursor column is outside of line width
  validate_edit({ 'aaa' }, { 1, 0 }, { '(aaa)' }, { 1, 1 }, type_keys, 'sa', '$', ')')
  validate_edit({ 'aaa' }, { 1, 0 }, { '(aaa)' }, { 1, 1 }, type_keys, 'v$', 'sa', ')')
end

T['Add surrounding']['allows cancelling with `<Esc> and <C-c>`'] = function()
  local validate_cancel = function(key)
    child.ensure_normal_mode()
    set_lines({ ' aaa ' })
    set_cursor(1, 1)

    -- Cancel before textobject
    type_keys(1, 'sa', key)
    eq(get_lines(), { ' aaa ' })
    eq(get_cursor(), { 1, 1 })

    -- Cancel before output surrounding
    type_keys(1, 'sa', 'iw', key)
    eq(get_lines(), { ' aaa ' })
    eq(get_cursor(), { 1, 1 })
  end

  validate_cancel('<Esc>')
  validate_cancel('<C-c>')
end

T['Add surrounding']['works with different mapping'] = function()
  reload_module({ mappings = { add = 'SA' } })

  validate_edit({ 'aaa' }, { 1, 0 }, { '(aaa)' }, { 1, 1 }, type_keys, 'SA', 'iw', ')')
  child.api.nvim_del_keymap('n', 'SA')
end

T['Add surrounding']['respects `selection=exclusive` option'] = function()
  child.o.selection = 'exclusive'
  local f = function() type_keys('v2l', 'sa', ')') end

  -- Regular case
  validate_edit({ ' aaa ' }, { 1, 1 }, { ' (aa)a ' }, { 1, 2 }, f)

  -- Multibyte characters
  validate_edit({ ' ыыы ' }, { 1, 1 }, { ' (ыы)ы ' }, { 1, 2 }, f)
end

T['Add surrounding']['respects `vim.{g,b}.minisurround_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child.ensure_normal_mode()
    child[var_type].minisurround_disable = true

    set_lines({ ' aaa ' })
    set_cursor(1, 1)

    -- It should ignore `sa` and start typing in Insert mode after `i`
    type_keys('sa', 'iw', ')')
    eq(get_lines(), { ' w)aaa ' })
    eq(get_cursor(), { 1, 3 })
  end,
})

T['Add surrounding']['respects `vim.b.minisurround_config`'] = function()
  child.b.minisurround_config = { custom_surroundings = { ['<'] = { output = { left = '>', right = '<' } } } }
  validate_edit({ 'aaa' }, { 1, 1 }, { '>aaa<' }, { 1, 1 }, type_keys, 'sa', 'iw', '<')
end

T['Delete surrounding'] = new_set()

T['Delete surrounding']['works with dot-repeat'] = function()
  validate_edit({ '(aaa)' }, { 1, 0 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', ')')
  validate_edit({ '(aaa)' }, { 1, 4 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', ')')
  validate_edit({ '(aaa)' }, { 1, 2 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', ')')

  -- Allows immediate dot-repeat
  set_lines({ '((aaa))' })
  set_cursor(1, 2)
  type_keys('sd', ')')
  type_keys('.')
  eq(get_lines(), { 'aaa' })
  eq(get_cursor(), { 1, 0 })

  -- Allows not immediate dot-repeat
  set_lines({ 'aaa (bbb)' })
  set_cursor(1, 5)
  type_keys('.')
  eq(get_lines(), { 'aaa bbb' })
end

T['Delete surrounding']['respects `config.n_lines`'] = function()
  reload_module({ n_lines = 2 })
  local lines = { '(', '', '', 'a', '', '', ')' }
  validate_edit(lines, { 4, 0 }, lines, { 4, 0 }, type_keys, 'sd', ')')
  has_message_about_not_found(')', 2)

  -- Should also use buffer local config
  child.b.minisurround_config = { n_lines = 10 }
  validate_edit(lines, { 4, 0 }, { '', '', '', 'a', '', '', '' }, { 1, 0 }, type_keys, 'sd', ')')
end

T['Delete surrounding']['respects `config.search_method`'] = function()
  local lines = { 'aaa (bbb)' }

  -- By default uses 'cover'
  validate_edit(lines, { 1, 0 }, lines, { 1, 0 }, type_keys, 'sd', ')')
  has_message_about_not_found(')')

  -- Should change behavior according to `config.search_method`
  reload_module({ search_method = 'cover_or_next' })
  validate_edit(lines, { 1, 0 }, { 'aaa bbb' }, { 1, 4 }, type_keys, 'sd', ')')

  -- Should also use buffer local config
  child.b.minisurround_config = { search_method = 'cover' }
  validate_edit(lines, { 1, 0 }, lines, { 1, 0 }, type_keys, 'sd', ')')
end

T['Delete surrounding']['places cursor to the right of left surrounding'] = function()
  local f = function() type_keys('sd', 'f') end

  -- Same line
  validate_edit({ 'myfunc(aaa)' }, { 1, 7 }, { 'aaa' }, { 1, 0 }, f)

  -- Not the same line
  validate_edit({ 'myfunc(aaa', 'bbb', 'ccc)' }, { 1, 8 }, { 'aaa', 'bbb', 'ccc' }, { 1, 0 }, f)
  validate_edit({ 'myfunc(aaa', 'bbb', 'ccc)' }, { 2, 0 }, { 'aaa', 'bbb', 'ccc' }, { 1, 0 }, f)
  validate_edit({ 'myfunc(aaa', 'bbb', 'ccc)' }, { 3, 2 }, { 'aaa', 'bbb', 'ccc' }, { 1, 0 }, f)
end

T['Delete surrounding']['prompts helper message after one idle second'] = function()
  set_lines({ '((aaa))' })
  set_cursor(1, 1)

  -- Execute one time to test if 'needs help message' flag is set per call
  type_keys('sd', ')')
  sleep(200)

  type_keys('sd')
  sleep(1000 - 10)
  eq(get_latest_message(), '')
  sleep(10 + 2)
  eq(get_latest_message(), '(mini.surround) Enter input surrounding identifier (single character) ')
end

T['Delete surrounding']['works with multibyte characters'] = function()
  local f = function() type_keys('sd', ')') end

  validate_edit({ '  (ыыы)  ' }, { 1, 3 }, { '  ыыы  ' }, { 1, 2 }, f)
  validate_edit({ '(ыыы) ttt' }, { 1, 1 }, { 'ыыы ttt' }, { 1, 0 }, f)
  validate_edit({ 'ttt (ыыы)' }, { 1, 5 }, { 'ttt ыыы' }, { 1, 4 }, f)
end

T['Delete surrounding']['works on multiple lines'] = function()
  local f = function() type_keys('sd', ')') end

  validate_edit({ '(aaa', 'bbb', 'ccc)' }, { 1, 3 }, { 'aaa', 'bbb', 'ccc' }, { 1, 0 }, f)
  validate_edit({ '(aaa', 'bbb', 'ccc)' }, { 2, 0 }, { 'aaa', 'bbb', 'ccc' }, { 1, 0 }, f)
end

T['Delete surrounding']['works with multiline input surroundings'] = function()
  child.lua([[MiniSurround.config.custom_surroundings = {
    a = { input = { find = '%(\na.-a\n%)', extract = '^(...).-(...)$' } },
    b = { input = { find = '%(\n.-\n%)', extract = '^(..).-(..)$' } },
    c = { input = { find = '\na.-a\n', extract = '^(..).-(..)$' } },
    d = { input = { find = '\n.-\n', extract = '^(.).-(.)$' } },
  }]])
  local lines = { 'xxx(', 'aaa', ')xxx' }
  local f

  f = function() type_keys('sd', 'a') end
  validate_edit(lines, { 1, 3 }, { 'xxxaxxx' }, { 1, 3 }, f)
  validate_edit(lines, { 2, 1 }, { 'xxxaxxx' }, { 1, 3 }, f)
  validate_edit(lines, { 3, 0 }, { 'xxxaxxx' }, { 1, 3 }, f)

  f = function() type_keys('sd', 'b') end
  validate_edit(lines, { 1, 3 }, { 'xxxaaaxxx' }, { 1, 3 }, f)
  validate_edit(lines, { 2, 1 }, { 'xxxaaaxxx' }, { 1, 3 }, f)
  validate_edit(lines, { 3, 0 }, { 'xxxaaaxxx' }, { 1, 3 }, f)

  f = function() type_keys('sd', 'c') end
  -- No case for first line because there is no covering match
  validate_edit(lines, { 2, 1 }, { 'xxx(a)xxx' }, { 1, 4 }, f)
  -- No case for third line because there is no covering match

  f = function() type_keys('sd', 'd') end
  -- No case for first line because there is no covering match
  validate_edit(lines, { 2, 1 }, { 'xxx(aaa)xxx' }, { 1, 4 }, f)
  -- There is a `\n` at the end of last line, so it is matched
  validate_edit(lines, { 3, 0 }, { 'xxx(', 'aaa)xxx' }, { 2, 3 }, f)
end

T['Delete surrounding']['allows cancelling with `<Esc> and <C-c>`'] = function()
  local validate_cancel = function(key)
    child.ensure_normal_mode()
    set_lines({ '<aaa>' })
    set_cursor(1, 1)

    type_keys(1, 'sd', key)
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })
  end

  validate_cancel('<Esc>')
  validate_cancel('<C-c>')
end

T['Delete surrounding']['works with different mapping'] = function()
  reload_module({ mappings = { delete = 'SD' } })

  validate_edit({ '(aaa)' }, { 1, 1 }, { 'aaa' }, { 1, 0 }, type_keys, 'SD', ')')
  child.api.nvim_del_keymap('n', 'SD')
end

T['Delete surrounding']['respects `vim.{g,b}.minisurround_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minisurround_disable = true

    set_lines({ '<aaa>' })
    set_cursor(1, 1)

    -- It should ignore `sd`
    type_keys('sd', '>')
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })
  end,
})

T['Delete surrounding']['respects `vim.b.minisurround_config`'] = function()
  child.b.minisurround_config =
    { custom_surroundings = { ['<'] = { input = { find = '>.-<', extract = '^(.).*(.)$' } } } }
  validate_edit({ '>aaa<' }, { 1, 2 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', '<')
end

T['Replace surrounding'] = new_set()

-- NOTE: use `>` for replacement because it itself is not a blocking key.
-- Like if you type `}` or `]`, Neovim will have to wait for the next key,
-- which blocks `child`.
T['Replace surrounding']['works with dot-repeat'] = function()
  validate_edit({ '(aaa)' }, { 1, 0 }, { '<aaa>' }, { 1, 1 }, type_keys, 'sr', ')', '>')
  validate_edit({ '(aaa)' }, { 1, 4 }, { '<aaa>' }, { 1, 1 }, type_keys, 'sr', ')', '>')
  validate_edit({ '(aaa)' }, { 1, 2 }, { '<aaa>' }, { 1, 1 }, type_keys, 'sr', ')', '>')

  -- Allows immediate dot-repeat
  set_lines({ '((aaa))' })
  set_cursor(1, 2)
  type_keys('sr', ')', '>')
  type_keys('.')
  eq(get_lines(), { '<<aaa>>' })
  eq(get_cursor(), { 1, 1 })

  -- Allows not immediate dot-repeat
  set_lines({ 'aaa (bbb)' })
  set_cursor(1, 5)
  type_keys('.')
  eq(get_lines(), { 'aaa <bbb>' })
end

T['Replace surrounding']['respects `config.n_lines`'] = function()
  reload_module({ n_lines = 2 })
  local lines = { '(', '', '', 'a', '', '', ')' }
  validate_edit(lines, { 4, 0 }, lines, { 4, 0 }, type_keys, 'sr', ')', '>')
  has_message_about_not_found(')', 2)

  -- Should also use buffer local config
  child.b.minisurround_config = { n_lines = 10 }
  validate_edit(lines, { 4, 0 }, { '<', '', '', 'a', '', '', '>' }, { 1, 0 }, type_keys, 'sr', ')', '>')
end

T['Replace surrounding']['respects `config.search_method`'] = function()
  local lines = { 'aaa (bbb)' }

  -- By default uses 'cover'
  validate_edit(lines, { 1, 0 }, lines, { 1, 0 }, type_keys, 'sr', ')', '>')
  has_message_about_not_found(')')

  -- Should change behavior according to `config.search_method`
  reload_module({ search_method = 'cover_or_next' })
  validate_edit(lines, { 1, 0 }, { 'aaa <bbb>' }, { 1, 5 }, type_keys, 'sr', ')', '>')

  -- Should also use buffer local config
  child.b.minisurround_config = { search_method = 'cover' }
  validate_edit(lines, { 1, 0 }, lines, { 1, 0 }, type_keys, 'sr', ')', '>')
end

T['Replace surrounding']['places cursor to the right of left surrounding'] = function()
  local f = function() type_keys('sr', 'f', '>') end

  -- Same line
  validate_edit({ 'myfunc(aaa)' }, { 1, 7 }, { '<aaa>' }, { 1, 1 }, f)

  -- Not the same line
  validate_edit({ 'myfunc(aaa', 'bbb', 'ccc)' }, { 1, 8 }, { '<aaa', 'bbb', 'ccc>' }, { 1, 1 }, f)
  validate_edit({ 'myfunc(aaa', 'bbb', 'ccc)' }, { 2, 0 }, { '<aaa', 'bbb', 'ccc>' }, { 1, 1 }, f)
  validate_edit({ 'myfunc(aaa', 'bbb', 'ccc)' }, { 3, 2 }, { '<aaa', 'bbb', 'ccc>' }, { 1, 1 }, f)
end

T['Replace surrounding']['prompts helper message after one idle second'] = function()
  set_lines({ '((aaa))' })
  set_cursor(1, 1)

  -- Execute one time to test if 'needs help message' flag is set per call
  type_keys('sr', ')', '>')
  sleep(200)

  type_keys('sr')
  sleep(1000 - 10)
  eq(get_latest_message(), '')
  sleep(10 + 2)
  eq(get_latest_message(), '(mini.surround) Enter input surrounding identifier (single character) ')

  clear_messages()
  type_keys(')')

  sleep(1000 - 10)
  eq(get_latest_message(), '')
  sleep(10 + 2)
  eq(get_latest_message(), '(mini.surround) Enter output surrounding identifier (single character) ')
end

T['Replace surrounding']['works with multibyte characters'] = function()
  local f = function() type_keys('sr', ')', '>') end

  validate_edit({ '  (ыыы)  ' }, { 1, 3 }, { '  <ыыы>  ' }, { 1, 3 }, f)
  validate_edit({ '(ыыы) ttt' }, { 1, 1 }, { '<ыыы> ttt' }, { 1, 1 }, f)
  validate_edit({ 'ttt (ыыы)' }, { 1, 5 }, { 'ttt <ыыы>' }, { 1, 5 }, f)
end

T['Replace surrounding']['works on multiple lines'] = function()
  local f = function() type_keys('sr', ')', '>') end

  validate_edit({ '(aaa', 'bbb', 'ccc)' }, { 1, 3 }, { '<aaa', 'bbb', 'ccc>' }, { 1, 1 }, f)
  validate_edit({ '(aaa', 'bbb', 'ccc)' }, { 2, 0 }, { '<aaa', 'bbb', 'ccc>' }, { 1, 1 }, f)
end

T['Replace surrounding']['works with multiline input surroundings'] = function()
  child.lua([[MiniSurround.config.custom_surroundings = {
    a = { input = { find = '%(\na.-a\n%)', extract = '^(...).-(...)$' } },
    b = { input = { find = '%(\n.-\n%)', extract = '^(..).-(..)$' } },
    c = { input = { find = '\na.-a\n', extract = '^(..).-(..)$' } },
    d = { input = { find = '\n.-\n', extract = '^(.).-(.)$' } },
  }]])
  local lines = { 'xxx(', 'aaa', ')xxx' }
  local f

  f = function() type_keys('sr', 'a', '>') end
  validate_edit(lines, { 1, 3 }, { 'xxx<a>xxx' }, { 1, 4 }, f)
  validate_edit(lines, { 2, 1 }, { 'xxx<a>xxx' }, { 1, 4 }, f)
  validate_edit(lines, { 3, 0 }, { 'xxx<a>xxx' }, { 1, 4 }, f)

  f = function() type_keys('sr', 'b', '>') end
  validate_edit(lines, { 1, 3 }, { 'xxx<aaa>xxx' }, { 1, 4 }, f)
  validate_edit(lines, { 2, 1 }, { 'xxx<aaa>xxx' }, { 1, 4 }, f)
  validate_edit(lines, { 3, 0 }, { 'xxx<aaa>xxx' }, { 1, 4 }, f)

  f = function() type_keys('sr', 'c', '>') end
  -- No case for first line because there is no covering match
  validate_edit(lines, { 2, 1 }, { 'xxx(<a>)xxx' }, { 1, 5 }, f)
  -- No case for third line because there is no covering match

  f = function() type_keys('sr', 'd', '>') end
  -- No case for first line because there is no covering match
  validate_edit(lines, { 2, 1 }, { 'xxx(<aaa>)xxx' }, { 1, 5 }, f)
  -- There is a `\n` at the end of last line. It is matched but can't be replaced.
  validate_edit(lines, { 3, 0 }, { 'xxx(', 'aaa<)xxx' }, { 2, 4 }, f)
end

T['Replace surrounding']['works with multiline output surroundings'] = function()
  child.lua([[MiniSurround.config.custom_surroundings = {
    a = { output = { left = '\n(\n', right = '\n)\n' } }
  }]])
  local lines = { '  [xxx]' }
  validate_edit(lines, { 1, 3 }, { '  ', '(', 'xxx', ')', '' }, { 1, 1 }, type_keys, 'sr', ']', 'a')
end

T['Replace surrounding']['allows cancelling with `<Esc> and <C-c>`'] = function()
  local validate_cancel = function(key)
    child.ensure_normal_mode()
    set_lines({ '<aaa>' })
    set_cursor(1, 1)

    -- Cancel before input surrounding
    type_keys(1, 'sr', key)
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })

    -- Cancel before output surrounding
    type_keys(1, 'sr', '>', key)
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })
  end

  validate_cancel('<Esc>')
  validate_cancel('<C-c>')
end

T['Replace surrounding']['works with different mapping'] = function()
  reload_module({ mappings = { replace = 'SR' } })

  validate_edit({ '(aaa)' }, { 1, 1 }, { '<aaa>' }, { 1, 1 }, type_keys, 'SR', ')', '>')
  child.api.nvim_del_keymap('n', 'SR')
end

T['Replace surrounding']['respects `vim.{g,b}.minisurround_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minisurround_disable = true

    set_lines({ '<aaa>' })
    set_cursor(1, 1)

    -- It should ignore `sr`
    type_keys('sr', '>', '"')
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })
  end,
})

T['Replace surrounding']['respects `vim.b.minisurround_config`'] = function()
  child.b.minisurround_config = { custom_surroundings = { ['<'] = { output = { left = '>', right = '<' } } } }
  validate_edit({ '<aaa>' }, { 1, 2 }, { '>aaa<' }, { 1, 1 }, type_keys, 'sr', '>', '<')
end

T['Find surrounding'] = new_set()

-- NOTE: most tests are done for `sf` ('find right') in hope that `sF` ('find
-- left') is implemented similarly
T['Find surrounding']['works with dot-repeat'] = function()
  validate_find({ '(aaa)' }, { 1, 0 }, { { 1, 4 }, { 1, 0 }, { 1, 4 } }, type_keys, 'sf', ')')
  validate_find({ '(aaa)' }, { 1, 2 }, { { 1, 4 }, { 1, 0 }, { 1, 4 } }, type_keys, 'sf', ')')
  validate_find({ '(aaa)' }, { 1, 4 }, { { 1, 0 }, { 1, 4 }, { 1, 0 } }, type_keys, 'sf', ')')

  -- Allows immediate dot-repeat
  set_lines({ '(aaa)' })
  set_cursor(1, 2)
  type_keys('sf', ')')
  type_keys('.')
  eq(get_lines(), { '(aaa)' })
  eq(get_cursor(), { 1, 0 })

  -- Allows not immediate dot-repeat
  set_lines({ 'aaa (bbb)' })
  set_cursor(1, 5)
  type_keys('.')
  eq(get_cursor(), { 1, 8 })
end

T['Find surrounding']['works in left direction with dot-repeat'] = function()
  validate_find({ '(aaa)' }, { 1, 0 }, { { 1, 4 }, { 1, 0 }, { 1, 4 } }, type_keys, 'sF', ')')
  validate_find({ '(aaa)' }, { 1, 4 }, { { 1, 0 }, { 1, 4 }, { 1, 0 } }, type_keys, 'sF', ')')
  validate_find({ '(aaa)' }, { 1, 2 }, { { 1, 0 }, { 1, 4 }, { 1, 0 } }, type_keys, 'sF', ')')

  -- Allows immediate dot-repeat
  set_lines({ '(aaa)' })
  set_cursor(1, 2)
  type_keys('sF', ')')
  type_keys('.')
  eq(get_lines(), { '(aaa)' })
  eq(get_cursor(), { 1, 4 })

  -- Allows not immediate dot-repeat
  set_lines({ 'aaa (bbb)' })
  set_cursor(1, 5)
  type_keys('.')
  eq(get_cursor(), { 1, 4 })
end

T['Find surrounding']['works with "non single character" surroundings'] = function()
  --stylua: ignore start
  -- Cursor is strictly inside surroundings
  validate_find({ 'myfunc(aaa)' }, { 1, 9 }, { {1,10}, {1,0}, {1,6}, {1,10} }, type_keys, 'sf', 'f')
  validate_find({ '<t>aaa</t>' }, { 1, 4 }, { {1,6}, {1,9}, {1,0}, {1,2}, {1,6} }, type_keys, 'sf', 't')
  validate_find({ '_aaa*^' }, { 1, 2 }, { {1,4}, {1,5}, {1,0}, {1,4} }, type_keys, 'sf', 'i', '_<CR>', '*^<CR>')

  -- Cursor is inside one of the surrounding parts
  validate_find({ 'myfunc(aaa)' }, { 1, 2 }, { {1,6}, {1,10}, {1,0}, {1,6} }, type_keys, 'sf', 'f')
  validate_find({ '<t>aaa</t>' }, { 1, 1 }, { {1,2}, {1,6}, {1,9}, {1,0}, {1,2} }, type_keys, 'sf', 't')
  validate_find({ '_aaa*^' }, { 1, 4 }, { {1,5}, {1,0}, {1,4}, {1,5} }, type_keys, 'sf', 'i', '_<CR>', '*^<CR>')

  -- Moving in left direction
  validate_find({ 'myfunc(aaa)' }, { 1, 8 }, { {1,6}, {1,0}, {1,10}, {1,6} }, type_keys, 'sF', 'f')
  validate_find({ '<t>aaa</t>' }, { 1, 4 }, { {1,2}, {1,0}, {1,9}, {1,6}, {1,2} }, type_keys, 'sF', 't')
  validate_find({ '_aaa*^' }, { 1, 2 }, { {1,0}, {1,5}, {1,4}, {1,0} }, type_keys, 'sF', 'i', '_<CR>', '*^<CR>')
  --stylua: ignore end
end

T['Find surrounding']['respects `config.n_lines`'] = function()
  reload_module({ n_lines = 2 })
  local lines = { '(', '', '', 'a', '', '', ')' }
  validate_find(lines, { 4, 0 }, { { 4, 0 } }, type_keys, 'sf', ')')
  has_message_about_not_found(')', 2)

  -- Should also use buffer local config
  child.b.minisurround_config = { n_lines = 10 }
  validate_find(lines, { 4, 0 }, { { 7, 0 } }, type_keys, 'sf', ')')
end

T['Find surrounding']['respects `config.search_method`'] = function()
  local lines = { 'aaa (bbb)' }

  -- By default uses 'cover'
  validate_find(lines, { 1, 0 }, { { 1, 0 } }, type_keys, 'sf', ')')
  has_message_about_not_found(')')

  clear_messages()
  validate_find(lines, { 1, 0 }, { { 1, 0 } }, type_keys, 'sF', ')')
  has_message_about_not_found(')')

  -- Should change behavior according to `config.search_method`
  reload_module({ search_method = 'cover_or_next' })
  validate_find(lines, { 1, 0 }, { { 1, 4 } }, type_keys, 'sf', ')')
  validate_find(lines, { 1, 0 }, { { 1, 8 } }, type_keys, 'sF', ')')

  -- Should also use buffer local config
  child.b.minisurround_config = { search_method = 'cover' }
  validate_find(lines, { 1, 0 }, { { 1, 0 } }, type_keys, 'sf', ')')
end

T['Find surrounding']['prompts helper message after one idle second'] = function()
  set_lines({ '(aaa)' })
  set_cursor(1, 2)

  -- Execute one time to test if 'needs help message' flag is set per call
  type_keys('sf', ')')
  sleep(200)

  type_keys('sf')
  sleep(1000 - 10)
  eq(get_latest_message(), '')
  sleep(10 + 2)
  eq(get_latest_message(), '(mini.surround) Enter input surrounding identifier (single character) ')
end

T['Find surrounding']['works with multibyte characters'] = function()
  local f = function() type_keys('sf', ')') end

  validate_find({ '  (ыыы)  ' }, { 1, 5 }, { { 1, 9 }, { 1, 2 } }, f)
  validate_find({ '(ыыы) ttt' }, { 1, 3 }, { { 1, 7 }, { 1, 0 } }, f)
  validate_find({ 'ttt (ыыы)' }, { 1, 7 }, { { 1, 11 }, { 1, 4 } }, f)
end

T['Find surrounding']['works on multiple lines'] = function()
  validate_find({ '(aaa', 'bbb', 'ccc)' }, { 1, 3 }, { { 3, 3 }, { 1, 0 } }, type_keys, 'sf', ')')
  validate_find({ '(aaa', 'bbb', 'ccc)' }, { 1, 3 }, { { 1, 0 }, { 3, 3 } }, type_keys, 'sF', ')')
end

T['Find surrounding']['works with multiline input surroundings'] = function()
  child.lua([[MiniSurround.config.custom_surroundings = {
    a = { input = { find = '%(\na.-a\n%)', extract = '^(...).-(...)$' } },
    b = { input = { find = '%(\n.-\n%)', extract = '^(..).-(..)$' } },
    c = { input = { find = '\na.-a\n', extract = '^(..).-(..)$' } },
    d = { input = { find = '\n.-\n', extract = '^(.).-(.)$' } },
  }]])
  local lines = { 'xxx(', 'aaa', ')xxx' }

  validate_find(lines, { 2, 1 }, { { 2, 2 }, { 3, 0 }, { 1, 3 }, { 2, 0 } }, type_keys, 'sf', 'a')
  validate_find(lines, { 2, 1 }, { { 2, 0 }, { 1, 3 }, { 3, 0 }, { 2, 2 } }, type_keys, 'sF', 'a')

  -- Same as `a` because new line characters are normalized "inside" surrounding
  validate_find(lines, { 2, 1 }, { { 2, 2 }, { 3, 0 }, { 1, 3 }, { 2, 0 } }, type_keys, 'sf', 'b')
  validate_find(lines, { 2, 1 }, { { 2, 0 }, { 1, 3 }, { 3, 0 }, { 2, 2 } }, type_keys, 'sF', 'b')

  validate_find(lines, { 2, 1 }, { { 2, 2 }, { 2, 0 } }, type_keys, 'sf', 'c')
  validate_find(lines, { 2, 1 }, { { 2, 0 }, { 2, 2 } }, type_keys, 'sF', 'c')

  -- Same as `c` because new line characters are normalized "inside" surrounding
  validate_find(lines, { 2, 1 }, { { 2, 2 }, { 2, 0 } }, type_keys, 'sf', 'd')
  validate_find(lines, { 2, 1 }, { { 2, 0 }, { 2, 2 } }, type_keys, 'sF', 'd')
end

T['Find surrounding']['allows cancelling with `<Esc> and <C-c>`'] = function()
  local validate_cancel = function(key)
    child.ensure_normal_mode()
    set_lines({ '<aaa>' })
    set_cursor(1, 1)

    -- It should work with `sf`
    type_keys(1, 'sf', key)
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })

    -- It should work with `sF`
    type_keys(1, 'sF', key)
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })
  end

  validate_cancel('<Esc>')
  validate_cancel('<C-c>')
end

T['Find surrounding']['works with different mapping'] = function()
  reload_module({ mappings = { find = 'SF', find_left = 'Sf' } })

  validate_find({ '(aaa)' }, { 1, 2 }, { { 1, 4 }, { 1, 0 } }, type_keys, 'SF', ')')
  validate_find({ '(aaa)' }, { 1, 2 }, { { 1, 0 }, { 1, 4 } }, type_keys, 'Sf', ')')
  child.api.nvim_del_keymap('n', 'SF')
  child.api.nvim_del_keymap('n', 'Sf')
end

T['Find surrounding']['respects `vim.{g,b}.minisurround_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minisurround_disable = true

    set_lines({ '<aaa>' })
    set_cursor(1, 1)

    -- It should ignore `sf`
    type_keys('sf', '>')
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })

    -- It should ignore `sF`
    type_keys('sF', '>')
    eq(get_lines(), { '<aaa>' })
    eq(get_cursor(), { 1, 1 })
  end,
})

T['Find surrounding']['respects `vim.b.minisurround_config`'] = function()
  child.b.minisurround_config =
    { custom_surroundings = { ['<'] = { input = { find = '>.-<', extract = '^(.).*(.)$' } } } }
  validate_edit({ '>aaa<' }, { 1, 2 }, { '>aaa<' }, { 1, 4 }, type_keys, 'sf', '<')
end

-- NOTE: most tests are done specifically for highlighting in hope that
-- finding of surrounding is done properly
T['Highlight surrounding'] = new_set({
  hooks = {
    pre_case = function()
      -- Reduce default highlight duration to speed up tests execution
      child.lua('MiniSurround.config.highlight_duration = 50')
      child.set_size(5, 12)
      child.o.cmdheight = 1
    end,
  },
})

local activate_highlighting = function()
  type_keys('sh)')
  poke_eventloop()
end

T['Highlight surrounding']['works with dot-repeat'] = function()
  local test_duration = child.lua_get('MiniSurround.config.highlight_duration')
  set_lines({ '(aaa) (bbb)' })
  set_cursor(1, 2)

  -- Should show highlighting immediately
  activate_highlighting()
  child.expect_screenshot()

  -- Should still highlight
  sleep(test_duration - 10)
  child.expect_screenshot()

  -- Should stop highlighting
  sleep(10)
  child.expect_screenshot()

  -- Should highlight with dot-repeat
  type_keys('.')
  child.expect_screenshot()

  -- Should stop highlighting
  sleep(test_duration)
  child.expect_screenshot()

  -- Should allow not immediate dot-repeat
  set_cursor(1, 8)
  type_keys('.')
  child.expect_screenshot()
end

T['Highlight surrounding']['respects `config.highlight_duration`'] = function()
  -- Currently tested in every `pre_case()`
end

T['Highlight surrounding']['respects `config.n_lines`'] = function()
  child.set_size(15, 40)
  child.o.cmdheight = 3

  child.lua('MiniSurround.config.n_lines = 2')
  set_lines({ '(', '', '', 'a', '', '', ')' })
  set_cursor(4, 0)
  activate_highlighting()

  -- Shouldn't highlight anything
  child.expect_screenshot()
  has_message_about_not_found(')', 2)
end

T['Highlight surrounding']['works with multiline input surroundings'] = function()
  child.lua('MiniSurround.config.highlight_duration = 5')
  child.lua([[MiniSurround.config.custom_surroundings = {
    a = { input = { find = '%(\na.-a\n%)', extract = '^(...).-(...)$' } },
    b = { input = { find = '%(\n.-\n%)', extract = '^(..).-(..)$' } },
    c = { input = { find = '\na.-a\n', extract = '^(..).-(..)$' } },
    d = { input = { find = '\n.-\n', extract = '^(.).-(.)$' } },
  }]])
  set_lines({ 'xxx(', 'aaa', ')xxx' })
  set_cursor(2, 1)

  type_keys('sh', 'a')
  child.expect_screenshot()
  sleep(10)

  type_keys('sh', 'b')
  child.expect_screenshot()
  sleep(10)

  type_keys('sh', 'c')
  child.expect_screenshot()
  sleep(10)

  type_keys('sh', 'd')
  child.expect_screenshot()
end

T['Highlight surrounding']['removes highlighting in correct buffer'] = function()
  child.set_size(5, 60)
  local test_duration = child.lua_get('MiniSurround.config.highlight_duration')

  set_lines({ '(aaa)' })
  set_cursor(1, 2)
  activate_highlighting()

  child.cmd('vsplit current')
  set_lines({ '(bbb)' })
  set_cursor(1, 2)
  sleep(0.5 * test_duration)
  activate_highlighting()

  -- Highlighting should be removed only in previous buffer
  child.expect_screenshot()
  sleep(0.5 * test_duration + 2)
  child.expect_screenshot()
end

T['Highlight surrounding']['removes highlighting per line'] = function()
  local test_duration = child.lua_get('MiniSurround.config.highlight_duration')
  local half_duration = 0.5 * test_duration
  set_lines({ '(aaa)', '(bbb)' })

  -- Create situation when there are two highlights simultaneously but on
  -- different lines. Check that they are properly and independently removed.
  set_cursor(1, 2)
  activate_highlighting()
  sleep(half_duration)
  set_cursor(2, 2)
  activate_highlighting()

  -- Should highlight in both lines
  child.expect_screenshot()

  -- Should highlight only in second line
  sleep(half_duration + 1)
  child.expect_screenshot()

  -- Should stop highlighting at all
  sleep(half_duration + 1)
  child.expect_screenshot()
end

T['Highlight surrounding']['respects `vim.{g,b}.minisurround_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minisurround_disable = true

    set_lines({ '(aaa)', 'bbb' })
    set_cursor(1, 2)
    type_keys('sh', ')')
    poke_eventloop()

    -- Shouldn't highlight anything (instead moves cursor with `)` motion)
    child.expect_screenshot()
  end,
})

T['Highlight surrounding']['respects `vim.b.minisurround_config`'] = function()
  ---     input = { find = '%b()', extract = '^(.).*(.)$' },
  child.b.minisurround_config = {
    custom_surroundings = { ['<'] = { input = { find = '>.-<', extract = '^(.).*(.)$' } } },
    highlight_duration = 50,
  }
  validate_edit({ '>aaa<' }, { 1, 2 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', '<')

  set_lines({ '>aaa<', 'bbb' })
  set_cursor(1, 2)
  type_keys('sh', '<')
  poke_eventloop()
  child.expect_screenshot()

  -- Should stop highlighting after duration from local config
  sleep(50)
  child.expect_screenshot()
end

T['Update number of lines'] = new_set()

T['Update number of lines']['works'] = function()
  local cur_n_lines = child.lua_get('MiniSurround.config.n_lines')

  -- Should ask for input, display prompt text and current value of `n_lines`
  type_keys('sn')
  eq(child.fn.mode(), 'c')
  eq(child.fn.getcmdline(), tostring(cur_n_lines))

  type_keys('0', '<CR>')
  eq(child.lua_get('MiniSurround.config.n_lines'), 10 * cur_n_lines)
end

T['Update number of lines']['allows cancelling with `<Esc> and <C-c>`'] = function()
  local validate_cancel = function(key)
    child.ensure_normal_mode()
    local cur_n_lines = child.lua_get('MiniSurround.config.n_lines')

    type_keys('sn')
    eq(child.fn.mode(), 'c')

    type_keys(key)
    eq(child.fn.mode(), 'n')
    eq(child.lua_get('MiniSurround.config.n_lines'), cur_n_lines)
  end

  validate_cancel('<Esc>')
  validate_cancel('<C-c>')
end

T['Update number of lines']['works with different mapping'] = function()
  reload_module({ mappings = { update_n_lines = 'SN' } })

  local cur_n_lines = child.lua_get('MiniSurround.config.n_lines')
  type_keys('SN', '0', '<CR>')
  child.api.nvim_del_keymap('n', 'SN')
  eq(child.lua_get('MiniSurround.config.n_lines'), 10 * cur_n_lines)
end

T['Update number of lines']['respects `vim.{g,b}.minisurround_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minisurround_disable = true
    local cur_n_lines = child.lua_get('MiniSurround.config.n_lines')
    type_keys('sn', '0', '<CR>')
    eq(child.lua_get('MiniSurround.config.n_lines'), cur_n_lines)
  end,
})

T['Search method'] = new_set()

T['Search method']['works with "cover_or_prev"'] = function()
  reload_module({ search_method = 'cover_or_prev' })
  local f = function() type_keys('sr', ')', '>') end

  -- Works (on same line and on multiple lines)
  validate_edit({ '(aaa) bbb' }, { 1, 7 }, { '<aaa> bbb' }, { 1, 1 }, f)
  validate_edit({ '(aaa)', 'bbb' }, { 2, 0 }, { '<aaa>', 'bbb' }, { 1, 1 }, f)

  -- Should prefer covering surrounding if both are on the same line
  validate_edit({ '(aaa) (bbb)' }, { 1, 8 }, { '(aaa) <bbb>' }, { 1, 7 }, f)
  validate_edit({ '((aaa) bbb)' }, { 1, 8 }, { '<(aaa) bbb>' }, { 1, 1 }, f)

  -- Should prefer covering surrounding if both are not on the same line
  validate_edit({ '(aaa) (', 'bbb)' }, { 2, 0 }, { '(aaa) <', 'bbb>' }, { 1, 6 }, f)

  -- Should prefer "previous" if it is on the same line, but covering is not
  validate_edit({ '(aaa) (bbb', ')' }, { 1, 8 }, { '<aaa> (bbb', ')' }, { 1, 1 }, f)

  -- Should ignore presence of "next" surrounding (even on same line)
  validate_edit({ '(aaa) bbb (ccc)' }, { 1, 7 }, { '<aaa> bbb (ccc)' }, { 1, 1 }, f)
  validate_edit({ '(aaa)', 'bbb (ccc)' }, { 2, 1 }, { '<aaa>', 'bbb (ccc)' }, { 1, 1 }, f)
  validate_edit({ '(aaa) (', 'bbb (ccc))' }, { 2, 0 }, { '(aaa) <', 'bbb (ccc)>' }, { 1, 6 }, f)
end

T['Search method']['works with "cover_or_next"'] = function()
  reload_module({ search_method = 'cover_or_next' })
  local f = function() type_keys('sr', ')', '>') end

  -- Works (on same line and on multiple lines)
  validate_edit({ 'aaa (bbb)' }, { 1, 0 }, { 'aaa <bbb>' }, { 1, 5 }, f)
  validate_edit({ 'aaa', '(bbb)' }, { 1, 0 }, { 'aaa', '<bbb>' }, { 2, 1 }, f)

  -- Should prefer covering surrounding if both are on the same line
  validate_edit({ '(aaa) (bbb)' }, { 1, 2 }, { '<aaa> (bbb)' }, { 1, 1 }, f)
  validate_edit({ '(aaa (bbb))' }, { 1, 2 }, { '<aaa (bbb)>' }, { 1, 1 }, f)

  -- Should prefer covering surrounding if both are not on the same line
  validate_edit({ '(aaa', ') (bbb)' }, { 1, 2 }, { '<aaa', '> (bbb)' }, { 1, 1 }, f)

  -- Should prefer "next" if it is on the same line, but covering is not
  validate_edit({ '(', 'aaa) (bbb)' }, { 2, 1 }, { '(', 'aaa) <bbb>' }, { 2, 6 }, f)

  -- Should ignore presence of "previous" surrounding (even on same line)
  validate_edit({ '(aaa) bbb (ccc)' }, { 1, 7 }, { '(aaa) bbb <ccc>' }, { 1, 11 }, f)
  validate_edit({ '(aaa) bbb', '(ccc)' }, { 1, 7 }, { '(aaa) bbb', '<ccc>' }, { 2, 1 }, f)
  validate_edit({ '(aaa) (', '(bbb) ccc)' }, { 2, 7 }, { '(aaa) <', '(bbb) ccc>' }, { 1, 6 }, f)
end

T['Search method']['works with "cover_or_nearest"'] = function()
  reload_module({ search_method = 'cover_or_nearest' })
  local f = function() type_keys('sr', ')', '>') end

  -- Works (on same line and on multiple lines)
  validate_edit({ '(aaa) bbb (ccc)' }, { 1, 6 }, { '<aaa> bbb (ccc)' }, { 1, 1 }, f)
  validate_edit({ '(aaa) bbb (ccc)' }, { 1, 7 }, { '(aaa) bbb <ccc>' }, { 1, 11 }, f)
  validate_edit({ '(aaa) bbb (ccc)' }, { 1, 8 }, { '(aaa) bbb <ccc>' }, { 1, 11 }, f)

  validate_edit({ '(aaa)', 'bbb', '(ccc)' }, { 2, 0 }, { '<aaa>', 'bbb', '(ccc)' }, { 1, 1 }, f)
  validate_edit({ '(aaa)', 'bbb', '(ccc)' }, { 2, 1 }, { '(aaa)', 'bbb', '<ccc>' }, { 3, 1 }, f)
  validate_edit({ '(aaa)', 'bbb', '(ccc)' }, { 2, 2 }, { '(aaa)', 'bbb', '<ccc>' }, { 3, 1 }, f)

  -- Should prefer covering surrounding if both are on the same line
  validate_edit({ '(aaa) (bbb) (ccc)' }, { 1, 7 }, { '(aaa) <bbb> (ccc)' }, { 1, 7 }, f)
  validate_edit({ '((aaa) bbb (ccc))' }, { 1, 7 }, { '<(aaa) bbb (ccc)>' }, { 1, 1 }, f)

  -- Should prefer covering surrounding if both are not on the same line
  validate_edit({ '(aaa) (', 'bbb', ') (ccc)' }, { 2, 0 }, { '(aaa) <', 'bbb', '> (ccc)' }, { 1, 6 }, f)

  -- Should prefer "nearest" if it is on the same line, but covering is not
  validate_edit({ '(aaa) (', 'bbb) (ccc)' }, { 2, 1 }, { '(aaa) (', 'bbb) <ccc>' }, { 2, 6 }, f)

  -- Computes "nearest" based on closest part of candidate surroundings
  validate_edit({ '(aaaa) b  (c)' }, { 1, 7 }, { '<aaaa> b  (c)' }, { 1, 1 }, f)
  validate_edit({ '(a)  b (cccc)' }, { 1, 5 }, { '(a)  b <cccc>' }, { 1, 8 }, f)

  -- If either "previous" or "next" is missing, should return the present one
  validate_edit({ '(aaa) bbb' }, { 1, 7 }, { '<aaa> bbb' }, { 1, 1 }, f)
  validate_edit({ '(aaa)', 'bbb' }, { 2, 0 }, { '<aaa>', 'bbb' }, { 1, 1 }, f)
  validate_edit({ 'aaa (bbb)' }, { 1, 0 }, { 'aaa <bbb>' }, { 1, 5 }, f)
  validate_edit({ 'aaa', '(bbb)' }, { 1, 0 }, { 'aaa', '<bbb>' }, { 2, 1 }, f)
end

T['Search method']['throws error on incorrect `config.search_method`'] = function()
  child.lua([[MiniSurround.config.search_method = 'aaa']])
  local lines = { 'aaa (bbb)' }
  -- Account for a big error message
  child.o.cmdheight = 40

  set_lines(lines)
  set_cursor(1, 0)
  expect.error(function() type_keys('sd', ')') end, 'one of')
  eq(get_lines(), lines)
  eq(get_cursor(), { 1, 0 })
end

T['Search method']['respects `vim.b.minisurround_config`'] = function()
  child.b.minisurround_config = { search_method = 'cover_or_next' }
  validate_edit({ 'aaa (bbb)' }, { 1, 0 }, { 'aaa <bbb>' }, { 1, 5 }, type_keys, 'sr', ')', '>')
end

-- Surroundings ---------------------------------------------------------------
T['Balanced pair surrounding'] = new_set()

T['Balanced pair surrounding']['works'] = function()
  local validate = function(key, pair)
    local s = pair:sub(1, 1) .. 'aaa' .. pair:sub(2, 2)
    -- Should work as input surrounding
    validate_edit({ s }, { 1, 2 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', key)

    -- Should work as output surrounding
    validate_edit({ '(aaa)' }, { 1, 2 }, { s }, { 1, 1 }, type_keys, 'sr', ')', key)
  end

  validate('(', '()')
  validate(')', '()')
  validate('[', '[]')
  validate(']', '[]')
  validate('{', '{}')
  validate('}', '{}')
  validate('<', '<>')
  validate('>', '<>')
end

-- All remaining tests are done with ')' and '>' in hope that others work
-- similarly
T['Balanced pair surrounding']['does not work in some cases'] = function()
  -- Although, it would be great if it did
  local f = function() type_keys('sr', ')', '>') end

  -- It does not take into account that part is inside string
  validate_edit({ [[(a, ')', b)]] }, { 1, 1 }, { "<a, '>', b)" }, { 1, 1 }, f)

  -- It does not take into account that part is inside comment
  child.bo.commentstring = '# %s'
  validate_edit({ '(a', '# )', 'b)' }, { 1, 1 }, { '<a', '# >', 'b)' }, { 1, 1 }, f)
end

T['Balanced pair surrounding']['is indeed balanced'] = function()
  local f = function() type_keys('sr', ')', '>') end

  validate_edit({ '(a())' }, { 1, 1 }, { '<a()>' }, { 1, 1 }, f)
  validate_edit({ '(()a)' }, { 1, 3 }, { '<()a>' }, { 1, 1 }, f)

  validate_edit({ '((()))' }, { 1, 0 }, { '<(())>' }, { 1, 1 }, f)
  validate_edit({ '((()))' }, { 1, 1 }, { '(<()>)' }, { 1, 2 }, f)
  validate_edit({ '((()))' }, { 1, 2 }, { '((<>))' }, { 1, 3 }, f)
  validate_edit({ '((()))' }, { 1, 3 }, { '((<>))' }, { 1, 3 }, f)
  validate_edit({ '((()))' }, { 1, 4 }, { '(<()>)' }, { 1, 2 }, f)
  validate_edit({ '((()))' }, { 1, 5 }, { '<(())>' }, { 1, 1 }, f)
end

T['Default single character surrounding'] = new_set()

T['Default single character surrounding']['works'] = function()
  local validate = function(key)
    local key_str = vim.api.nvim_replace_termcodes(key, true, true, true)
    local s = key_str .. 'aaa' .. key_str

    -- Should work as input surrounding
    validate_edit({ s }, { 1, 2 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', key)

    -- Should work as output surrounding
    validate_edit({ '(aaa)' }, { 1, 2 }, { s }, { 1, 1 }, type_keys, 'sr', ')', key)
  end

  validate('<Space>')
  validate('_')
  validate('*')
  validate('"')
  validate("'")
end

T['Default single character surrounding']['does not work in some cases'] = function()
  -- Although, it would be great if it did
  local f = function() type_keys('sr', '_', '>') end

  -- It does not take into account that part is inside string
  validate_edit({ [[_a, '_', b_]] }, { 1, 1 }, { "<a, '>', b_" }, { 1, 1 }, f)

  -- It does not take into account that part is inside comment
  child.bo.commentstring = '# %s'
  validate_edit({ '_a', '# _', 'b_' }, { 1, 1 }, { '<a', '# >', 'b_' }, { 1, 1 }, f)
end

T['Default single character surrounding']['detects covering with smallest width'] = function()
  local f = function() type_keys('sr', '"', ')') end

  validate_edit({ '"a"aa"' }, { 1, 2 }, { '(a)aa"' }, { 1, 1 }, f)
  validate_edit({ '"aa"a"' }, { 1, 3 }, { '"aa(a)' }, { 1, 4 }, f)

  validate_edit({ '"""a"""' }, { 1, 3 }, { '""(a)""' }, { 1, 3 }, f)
end

T['Default single character surrounding']['works in edge cases'] = function()
  local f = function() type_keys('sr', '*', ')') end

  -- Consecutive identical matching characters
  validate_edit({ '****' }, { 1, 0 }, { '()**' }, { 1, 1 }, f)
  validate_edit({ '****' }, { 1, 1 }, { '()**' }, { 1, 1 }, f)
  validate_edit({ '****' }, { 1, 2 }, { '*()*' }, { 1, 2 }, f)
  validate_edit({ '****' }, { 1, 3 }, { '**()' }, { 1, 3 }, f)
end

T['Default single character surrounding']['has limited support of multibyte characters'] = function()
  -- At the moment, multibyte character doesn't pass validation of user
  -- single character input. It would be great to fix this.
  expect.error(function() validate_edit({ 'ыaaaы' }, { 1, 3 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 'ы') end)
  expect.error(function() validate_edit({ '(aaa)' }, { 1, 2 }, { 'ыaaaы' }, { 1, 2 }, type_keys, 'sr', ')', 'ы') end)
end

T['Function call surrounding'] = new_set()

T['Function call surrounding']['works'] = function()
  -- Should work as input surrounding
  validate_edit({ 'myfunc(aaa)' }, { 1, 8 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 'f')

  -- Should work as output surrounding
  validate_edit({ '(aaa)' }, { 1, 2 }, { 'myfunc(aaa)' }, { 1, 7 }, type_keys, 'sr', ')', 'f', 'myfunc<CR>')

  -- Should work with empty arguments
  validate_edit({ 'myfunc()' }, { 1, 0 }, { '' }, { 1, 0 }, type_keys, 'sd', 'f')
end

T['Function call surrounding']['does not work in some cases'] = function()
  -- Although, it would be great if it did
  local f = function() type_keys('sr', 'f', '>') end

  -- It does not take into account that part is inside string
  validate_edit({ [[myfunc(a, ')', b)]] }, { 1, 7 }, { "<a, '>', b)" }, { 1, 1 }, f)

  -- It does not take into account that part is inside comment
  child.bo.commentstring = '# %s'
  validate_edit({ 'myfunc(a', '# )', 'b)' }, { 1, 7 }, { '<a', '# >', 'b)' }, { 1, 1 }, f)
end

T['Function call surrounding']['is detected with "_" and "." in name'] = function()
  validate_edit({ 'my_func(aaa)' }, { 1, 9 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 'f')
  validate_edit({ 'my.func(aaa)' }, { 1, 9 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 'f')
  validate_edit({ 'big-new_my.func(aaa)' }, { 1, 17 }, { 'big-aaa' }, { 1, 4 }, type_keys, 'sd', 'f')
  validate_edit({ 'big new_my.func(aaa)' }, { 1, 17 }, { 'big aaa' }, { 1, 4 }, type_keys, 'sd', 'f')

  validate_edit({ '[(myfun(aaa))]' }, { 1, 9 }, { '[(aaa)]' }, { 1, 2 }, type_keys, 'sd', 'f')
end

T['Function call surrounding']['works in different parts of line and neighborhood'] = function()
  -- This check is viable because of complex nature of Lua patterns
  validate_edit({ 'myfunc(aaa)' }, { 1, 8 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 'f')
  validate_edit({ 'Hello myfunc(aaa)' }, { 1, 14 }, { 'Hello aaa' }, { 1, 6 }, type_keys, 'sd', 'f')
  validate_edit({ 'myfunc(aaa) world' }, { 1, 8 }, { 'aaa world' }, { 1, 0 }, type_keys, 'sd', 'f')
  validate_edit({ 'Hello myfunc(aaa) world' }, { 1, 14 }, { 'Hello aaa world' }, { 1, 6 }, type_keys, 'sd', 'f')

  --stylua: ignore start
  validate_edit({ 'myfunc(aaa)', 'Hello', 'world' }, { 1, 8 }, { 'aaa', 'Hello', 'world' }, { 1, 0 }, type_keys, 'sd', 'f')
  validate_edit({ 'Hello', 'myfunc(aaa)', 'world' }, { 2, 8 }, { 'Hello', 'aaa', 'world' }, { 2, 0 }, type_keys, 'sd', 'f')
  validate_edit({ 'Hello', 'world', 'myfunc(aaa)' }, { 3, 8 }, { 'Hello', 'world', 'aaa' }, { 3, 0 }, type_keys, 'sd', 'f')
  --stylua: ignore end
end

T['Function call surrounding']['has limited support of multibyte characters'] = function()
  -- Due to limitations of Lua patterns used for detecting surrounding, it
  -- currently doesn't support detecting function calls with multibyte
  -- character in name. It would be great to fix this.
  expect.error(function() validate_edit({ 'ыыы(aaa)' }, { 1, 8 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 'f') end)

  -- Should work in output surrounding
  validate_edit({ '(aaa)' }, { 1, 2 }, { 'ыыы(aaa)' }, { 1, 7 }, type_keys, 'sr', ')', 'f', 'ыыы<CR>')
end

T['Function call surrounding']['handles <C-c>, <Esc>, <CR> in user input'] = function()
  -- Should do nothing on `<C-c>` and `<Esc>`
  validate_edit({ '(aaa)' }, { 1, 2 }, { '(aaa)' }, { 1, 2 }, type_keys, 1, 'sr', ')', 'f', '<Esc>')
  validate_edit({ '(aaa)' }, { 1, 2 }, { '(aaa)' }, { 1, 2 }, type_keys, 1, 'sr', ')', 'f', '<C-c>')

  -- Should treat `<CR>` as empty string input
  validate_edit({ '[aaa]' }, { 1, 2 }, { '(aaa)' }, { 1, 1 }, type_keys, 'sr', ']', 'f', '<CR>')
end

T['Tag surrounding'] = new_set()

T['Tag surrounding']['works'] = function()
  -- Should work as input surrounding
  validate_edit({ '<x>aaa</x>' }, { 1, 4 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 't')

  -- Should work as output surrounding
  validate_edit({ '(aaa)' }, { 1, 2 }, { '<x>aaa</x>' }, { 1, 3 }, type_keys, 'sr', ')', 't', 'x<CR>')

  -- Should work with empty tag name
  validate_edit({ '<>aaa</>' }, { 1, 3 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 't')

  -- Should work with empty inside content
  validate_edit({ '<x></x>' }, { 1, 2 }, { '' }, { 1, 0 }, type_keys, 'sd', 't')
end

T['Tag surrounding']['does not work in some cases'] = function()
  -- Although, it would be great if it did
  local f = function() type_keys('sr', 't', '>') end

  -- It does not take into account that part is inside string
  validate_edit({ [[<x>a, '</x>', b</x>]] }, { 1, 3 }, { "<a, '>', b</x>" }, { 1, 1 }, f)

  -- It does not take into account that part is inside comment
  child.bo.commentstring = '# %s'
  validate_edit({ '<x>a', '# </x>', 'b</x>' }, { 1, 3 }, { '<a', '# >', 'b</x>' }, { 1, 1 }, f)

  -- Tags are not "balanced"
  validate_edit({ '<x><x></x></x>' }, { 1, 1 }, { '_<x>_</x>' }, { 1, 1 }, type_keys, 'sr', 't', '_')

  -- Don't work at end of self-nesting tags
  validate_edit({ '<x><x></x></x>' }, { 1, 12 }, { '<x><x></x></x>' }, { 1, 12 }, type_keys, 'sr', 't')
  has_message_about_not_found('t')
end

T['Tag surrounding']['detects tag with the same name'] =
  function() validate_edit({ '<x><y>a</x></y>' }, { 1, 1 }, { '_<y>a_</y>' }, { 1, 1 }, type_keys, 'sr', 't', '_') end

T['Tag surrounding']['allows extra symbols in opening tag on input'] = function()
  validate_edit({ '<x bbb cc_dd!>aaa</x>' }, { 1, 15 }, { '_aaa_' }, { 1, 1 }, type_keys, 'sr', 't', '_')

  -- Symbol `<` is not allowed
  validate_edit({ '<x <>aaa</x>' }, { 1, 6 }, { '<x <>aaa</x>' }, { 1, 6 }, type_keys, 'sr', 't')
  has_message_about_not_found('t')
end

T['Tag surrounding']['allows extra symbols in opening tag on output'] = function()
  validate_edit({ 'aaa' }, { 1, 0 }, { '<a b>aaa</a>' }, { 1, 5 }, type_keys, 'sa', 'iw', 't', 'a b', '<CR>')
  validate_edit({ '<a b>aaa</a>' }, { 1, 5 }, { '<a c>aaa</a>' }, { 1, 5 }, type_keys, 'sr', 't', 't', 'a c', '<CR>')
end

T['Tag surrounding']['detects covering with smallest width'] = function()
  local f = function() type_keys('sr', 't', '_') end

  -- In all cases width of `<y>...</y>` is smaller than of `<x>...</x>`
  validate_edit({ '<x>  <y>a</x></y>' }, { 1, 8 }, { '<x>  _a</x>_' }, { 1, 6 }, f)
  validate_edit({ '<y><x>a</y>  </x>' }, { 1, 6 }, { '_<x>a_  </x>' }, { 1, 1 }, f)

  -- Width should be from the left-most point to right-most
  validate_edit({ '<y><x bbb>a</y></x>' }, { 1, 10 }, { '_<x bbb>a_</x>' }, { 1, 1 }, f)

  -- Works with identical nested tags
  validate_edit({ '<x><x>aaa</x></x>' }, { 1, 7 }, { '<x>_aaa_</x>' }, { 1, 4 }, f)
end

T['Tag surrounding']['works in edge cases'] = function()
  local f = function() type_keys('sr', 't', '_') end

  -- Nesting different tags
  validate_edit({ '<x><y></y></x>' }, { 1, 1 }, { '_<y></y>_' }, { 1, 1 }, f)
  validate_edit({ '<x><y></y></x>' }, { 1, 4 }, { '<x>__</x>' }, { 1, 4 }, f)

  -- End of overlapping tags
  validate_edit({ '<y><x></y></x>' }, { 1, 12 }, { '<y>_</y>_' }, { 1, 4 }, f)

  -- `>` between tags
  validate_edit({ '<x>>aaa</x>' }, { 1, 5 }, { '_>aaa_' }, { 1, 1 }, f)

  -- Similar but different names shouldn't match
  validate_edit({ '<xy>aaa</x>' }, { 1, 5 }, { '<xy>aaa</x>' }, { 1, 5 }, type_keys, 'sd', 't')
end

T['Tag surrounding']['has limited support of multibyte characters'] = function()
  -- Due to limitations of Lua patterns used for detecting surrounding, it
  -- currently doesn't support detecting tag with multibyte character in
  -- name. It would be great to fix this.
  expect.error(function() validate_edit({ '<ы>aaa</ы>' }, { 1, 5 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 't') end)

  -- Should work in output surrounding
  validate_edit({ '(aaa)' }, { 1, 8 }, { '<ы>aaa</ы>' }, { 1, 4 }, type_keys, 'sr', ')', 't', 'ы<CR>')
end

T['Tag surrounding']['handles <C-c>, <Esc>, <CR> in user input'] = function()
  -- Should do nothing on `<C-c>` and `<Esc>`
  validate_edit({ '(aaa)' }, { 1, 2 }, { '(aaa)' }, { 1, 2 }, type_keys, 1, 'sr', ')', 't', '<Esc>')
  validate_edit({ '(aaa)' }, { 1, 2 }, { '(aaa)' }, { 1, 2 }, type_keys, 1, 'sr', ')', 't', '<C-c>')

  -- Should treat `<CR>` as empty string input
  validate_edit({ '(aaa)' }, { 1, 2 }, { '<>aaa</>' }, { 1, 2 }, type_keys, 'sr', ')', 't', '<CR>')
end

T['Interactive surrounding'] = new_set()

T['Interactive surrounding']['works'] = function()
  -- Should work as input surrounding
  validate_edit({ '%*aaa*%' }, { 1, 3 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 'i', '%*<CR>', '*%<CR>')

  -- Should work as output surrounding
  validate_edit({ '(aaa)' }, { 1, 2 }, { '%*aaa*%' }, { 1, 2 }, type_keys, 'sr', ')', 'i', '%*<CR>', '*%<CR>')
end

T['Interactive surrounding']['does not work in some cases'] = function()
  -- Although, it would be great if it did
  local f = function() type_keys('sr', 'i', '**<CR>', '**<CR>', '>') end

  -- It does not take into account that part is inside string
  validate_edit({ [[**a, '**', b**]] }, { 1, 2 }, { "<a, '>', b**" }, { 1, 1 }, f)

  -- It does not take into account that part is inside comment
  child.bo.commentstring = '# %s'
  validate_edit({ '**a', '# **', 'b**' }, { 1, 2 }, { '<a', '# >', 'b**' }, { 1, 1 }, f)

  -- It does not work sometimes in presence of many identical valid parts
  -- (basically because it is a `%(.-%)` and not `%(.*%)`).
  f = function() type_keys('sr', 'i', '(<CR>', ')<CR>', '>') end
  validate_edit({ '((()))' }, { 1, 3 }, { '((<>))' }, { 1, 3 }, f)
  validate_edit({ '((()))' }, { 1, 4 }, { '((()))' }, { 1, 4 }, f)
  validate_edit({ '((()))' }, { 1, 5 }, { '((()))' }, { 1, 5 }, f)
end

T['Interactive surrounding']['detects covering with smallest width'] = function()
  local f = function() type_keys('sr', 'i', '**<CR>', '**<CR>', ')') end

  validate_edit({ '**a**aa**' }, { 1, 4 }, { '(a)aa**' }, { 1, 1 }, f)
  validate_edit({ '**aa**a**' }, { 1, 4 }, { '**aa(a)' }, { 1, 5 }, f)
end

T['Interactive surrounding']['works in edge cases'] = function()
  local f = function() type_keys('sr', 'i', '(<CR>', ')<CR>', '>') end

  -- This version of `()` should not be balanced
  validate_edit({ '((()))' }, { 1, 0 }, { '<((>))' }, { 1, 1 }, f)
  validate_edit({ '((()))' }, { 1, 1 }, { '(<(>))' }, { 1, 2 }, f)
  validate_edit({ '((()))' }, { 1, 2 }, { '((<>))' }, { 1, 3 }, f)
end

T['Interactive surrounding']['works with multibyte characters in parts'] = function()
  -- Should work as input surrounding
  validate_edit({ 'ыtttю' }, { 1, 3 }, { 'ttt' }, { 1, 0 }, type_keys, 'sd', 'i', 'ы<CR>', 'ю<CR>')

  -- Should work as output surrounding
  validate_edit({ 'ыtttю' }, { 1, 3 }, { '(ttt)' }, { 1, 1 }, type_keys, 'sr', 'i', 'ы<CR>', 'ю<CR>', ')')
end

T['Interactive surrounding']['handles <C-c>, <Esc>, <CR> in user input'] = function()
  local validate_single = function(...)
    child.ensure_normal_mode()
    -- Wait before every keygroup because otherwise it seems to randomly
    -- break for `<C-c>`
    validate_edit({ '(aaa)' }, { 1, 2 }, { '(aaa)' }, { 1, 2 }, type_keys, 10, ...)
  end

  local validate_nothing = function(key)
    -- Should do nothing on any `<C-c>` and `<Esc>` (in both input and output)
    validate_single('sr', 'i', key)
    validate_single('sr', 'i', '(<CR>', key)
    validate_single('sr', ')', 'i', key)
    validate_single('sr', ')', 'i', '*<CR>', key)
  end

  validate_nothing('<Esc>')
  validate_nothing('<C-c>')

  -- Should treat `<CR>` as empty string in output surrounding
  validate_edit({ '(aaa)' }, { 1, 2 }, { '_aaa' }, { 1, 1 }, type_keys, 'sr', ')', 'i', '_<CR>', '<CR>')
  validate_edit({ '(aaa)' }, { 1, 2 }, { 'aaa_' }, { 1, 0 }, type_keys, 'sr', ')', 'i', '<CR>', '_<CR>')
  validate_edit({ '(aaa)' }, { 1, 2 }, { 'aaa' }, { 1, 0 }, type_keys, 'sr', ')', 'i', '<CR>', '<CR>')

  -- Should stop on `<CR>` in input surrounding because can't use empty
  -- string in pattern search
  validate_edit({ '**aaa**' }, { 1, 3 }, { '**aaa**' }, { 1, 3 }, type_keys, 'sr', 'i', '<CR>')
  validate_edit({ '**aaa**' }, { 1, 3 }, { '**aaa**' }, { 1, 3 }, type_keys, 'sr', 'i', '**<CR>', '<CR>')
end

T['Custom surrounding'] = new_set()

T['Custom surrounding']['works'] = function()
  reload_module({
    custom_surroundings = {
      q = {
        input = { find = '@.-#', extract = '^(.).*(.)$' },
        output = { left = '@', right = '#' },
      },
    },
  })

  validate_edit({ '@aaa#' }, { 1, 2 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', 'q')
  validate_edit({ '(aaa)' }, { 1, 2 }, { '@aaa#' }, { 1, 1 }, type_keys, 'sr', ')', 'q')
end

T['Custom surrounding']['allows setting partial information'] = function()
  -- Modifying present single character identifier (takes from present)
  reload_module({ custom_surroundings = { [')'] = { output = { left = '( ', right = ' )' } } } })

  validate_edit({ '(aaa)' }, { 1, 2 }, { 'aaa' }, { 1, 0 }, type_keys, 'sd', ')')
  validate_edit({ '<aaa>' }, { 1, 2 }, { '( aaa )' }, { 1, 2 }, type_keys, 'sr', '>', ')')

  -- New single character identifier (takes from default)
  reload_module({ custom_surroundings = { ['#'] = { input = { find = '#_.-_#' } } } })

  -- Should find '#_' and '_#' but extract outer matched ones (as in default)
  validate_edit({ '_#_aaa_#_' }, { 1, 4 }, { '__aaa__' }, { 1, 1 }, type_keys, 'sd', '#')
  -- `output` should be taken from default
  validate_edit({ '(aaa)' }, { 1, 2 }, { '#aaa#' }, { 1, 1 }, type_keys, 'sr', ')', '#')
end

T['Custom surrounding']['validates two captures in `input.extract`'] = function()
  reload_module({ custom_surroundings = { ['#'] = { input = { extract = '^#.*#$' } } } })

  -- Avoid hit-enter-prompt on big error message
  child.o.cmdheight = 40
  expect.error(function() validate_edit({ '#a#' }, { 1, 1 }, { 'a' }, { 1, 0 }, type_keys, 'sd', '#') end)
end

T['Custom surrounding']['works with `.-`'] = function()
  local f = function() type_keys('sr', '#', '>') end

  reload_module({ custom_surroundings = { ['#'] = { input = { find = '#.-@' } } } })

  validate_edit({ '###@@@' }, { 1, 0 }, { '<##>@@' }, { 1, 1 }, f)
  validate_edit({ '###@@@' }, { 1, 1 }, { '#<#>@@' }, { 1, 2 }, f)
  validate_edit({ '###@@@' }, { 1, 2 }, { '##<>@@' }, { 1, 3 }, f)
end

T['Custom surrounding']['has limited support for `+` quantifier'] = function()
  reload_module({ custom_surroundings = { ['#'] = { input = { find = '#+.-#+', extract = '^(#+).*(#+)$' } } } })

  local f = function() type_keys('sr', '#', ')') end

  -- It should find only ones nearest to cursor as it has the smallest width
  validate_edit({ '###aaa###' }, { 1, 4 }, { '##(aaa)##' }, { 1, 3 }, f)

  -- "Working" edge cases
  validate_edit({ '###' }, { 1, 0 }, { '()#' }, { 1, 1 }, f)
  validate_edit({ '###' }, { 1, 1 }, { '#()' }, { 1, 2 }, f)
  validate_edit({ '###' }, { 1, 2 }, { '#()' }, { 1, 2 }, f)

  -- "Non-working" edge cases
  -- Result should be `()a#`.
  validate_edit({ '##a#' }, { 1, 0 }, { '(a)' }, { 1, 1 }, f)
end

T['Custom surrounding']['has limited support for `*` quantifier'] = function()
  reload_module({ custom_surroundings = { ['#'] = { input = { find = '#.*#' } } } })

  local f = function() type_keys('sr', '#', ')') end

  validate_edit({ '###aaa###' }, { 1, 4 }, { '##(aaa)##' }, { 1, 3 }, f)

  -- "Working" edge cases
  validate_edit({ '###' }, { 1, 0 }, { '()#' }, { 1, 1 }, f)
  validate_edit({ '###' }, { 1, 1 }, { '#()' }, { 1, 2 }, f)
  validate_edit({ '###' }, { 1, 2 }, { '#()' }, { 1, 2 }, f)

  -- "Non-working" edge cases
  -- Result should be `()a#`.
  validate_edit({ '##a#' }, { 1, 0 }, { '(#a)' }, { 1, 1 }, f)
end

T['Custom surrounding']['has limited support for frontier pattern `%f[]`'] = function()
  local f = function() type_keys('sr', 'w', ')') end

  local validate = function()
    validate_edit({ ' aaaa ' }, { 1, 1 }, { ' ()aa ' }, { 1, 2 }, f)
    validate_edit({ ' aaaa ' }, { 1, 2 }, { ' ()aa ' }, { 1, 2 }, f)
    validate_edit({ ' aaaa ' }, { 1, 3 }, { ' (a)a ' }, { 1, 2 }, f)
    validate_edit({ ' aaaa ' }, { 1, 4 }, { ' (aa) ' }, { 1, 2 }, f)
  end

  -- In pattern start should work reasonably well
  reload_module({ custom_surroundings = { ['w'] = { input = { find = '%f[%w]%w+', extract = '^(%w).*(%w)$' } } } })
  validate()

  -- In pattern end has limited support. It should match whole word in all
  -- cases but it does not because pattern match is checked on substring (for
  -- which `%f[%W]` matches on all covering substrings).
  reload_module({
    custom_surroundings = { ['w'] = { input = { find = '%f[%w]%w+%f[%W]', extract = '^(%w).*(%w)$' } } },
  })
  validate()
end

return T
