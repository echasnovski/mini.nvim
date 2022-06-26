-- NOTE: These are basic tests which cover basic functionality. A lot of
-- nuances are not tested to meet "complexity-necessity" trade-off. Feel free
-- to add tests for new behavior and found edge cases.
local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('starter', config) end
local unload_module = function() child.mini_unload('starter') end
local reload_module = function(config) unload_module(); load_module(config) end
local reload_from_strconfig = function(strconfig) unload_module(); child.mini_load_strconfig('starter', strconfig) end
local get_cursor = function(...) return child.get_cursor(...) end
local get_lines = function(...) return child.get_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
--stylua: ignore end

-- Make helpers
local is_starter_shown = function()
  return child.bo.filetype == 'starter'
end

local validate_starter_shown = function()
  eq(is_starter_shown(), true)
end

local validate_starter_not_shown = function()
  eq(is_starter_shown(), false)
end

local validate_equal_starter = function(strconfig_1, strconfig_2)
  -- Reload with first config
  reload_from_strconfig(strconfig_1)
  child.lua('MiniStarter.open()')
  local lines_1 = get_lines()

  -- Reload with first config
  reload_from_strconfig(strconfig_2)
  child.lua('MiniStarter.open()')
  local lines_2 = get_lines()

  eq(lines_1, lines_2)

  reload_module()
end

local get_latest_message = function()
  return child.cmd_capture('1messages')
end

local get_active_items_names = function()
  local items = child.lua_get('MiniStarter.content_to_items(MiniStarter.content)')
  local active_items = vim.tbl_filter(function(x)
    return x._active == true
  end, items)
  return vim.tbl_map(function(x)
    return x.name
  end, active_items)
end

local mock_item = function(name, section)
  return { name = name, action = ('lua _G.item_name = %s'):format(vim.inspect(name)), section = section }
end

local mock_itemstring = function(name, section)
  return ([[{ name = '%s', action = 'lua _G.item_name = "%s"', section = '%s' }]]):format(name, name, section)
end

-- Data =======================================================================
local example_items = { mock_item('aaab', 'A'), mock_item('aaba', 'A'), mock_item('abaa', 'B'), mock_item('baaa', 'B') }

local example_itemstring = '{ '
  .. table.concat({
    mock_itemstring('aaab', 'A'),
    mock_itemstring('aaba', 'A'),
    mock_itemstring('abaa', 'B'),
    mock_itemstring('baaa', 'B'),
  }, ', ')
  .. ' }'

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
  eq(child.lua_get('type(_G.MiniStarter)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniStarter'), 1)

  -- Highlight groups
  local has_highlight = function(group, value)
    expect.match(child.cmd_capture('hi ' .. group), value)
  end

  has_highlight('MiniStarterCurrent', 'cleared')
  has_highlight('MiniStarterFooter', 'links to Title')
  has_highlight('MiniStarterHeader', 'links to Title')
  has_highlight('MiniStarterInactive', 'links to Comment')
  has_highlight('MiniStarterItem', 'links to Normal')
  has_highlight('MiniStarterItemBullet', 'links to Delimiter')
  has_highlight('MiniStarterItemPrefix', 'links to WarningMsg')
  has_highlight('MiniStarterSection', 'links to Delimiter')
  has_highlight('MiniStarterQuery', 'links to MoreMsg')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniStarter.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value)
    eq(child.lua_get('MiniStarter.config.' .. field), value)
  end

  expect_config('autoopen', true)
  expect_config('evaluate_single', false)
  expect_config('items', vim.NIL)
  expect_config('header', vim.NIL)
  expect_config('footer', vim.NIL)
  expect_config('content_hooks', vim.NIL)
  expect_config('query_updaters', 'abcdefghijklmnopqrstuvwxyz0123456789_-.')
end

T['setup()']['respects `config` argument'] = function()
  reload_module({ autoopen = false })
  eq(child.lua_get('MiniStarter.config.autoopen'), false)
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ autoopen = 'a' }, 'autoopen', 'boolean')
  expect_config_error({ evaluate_single = 'a' }, 'evaluate_single', 'boolean')
  expect_config_error({ items = 'a' }, 'items', 'table')
  -- `header` and `footer` can have any type
  expect_config_error({ content_hooks = 'a' }, 'content_hooks', 'table')
  expect_config_error({ query_updaters = 1 }, 'query_updaters', 'string')
end

-- Work with Starter buffer ---------------------------------------------------
T['open()'] = new_set()

T['open()']['works'] = function()
  local init_buf_id = child.api.nvim_get_current_buf()

  child.lua('MiniStarter.open()')

  expect.no_equality(child.api.nvim_get_current_buf(), init_buf_id)
  eq(child.api.nvim_buf_get_name(0), child.fn.getcwd() .. '/Starter')
  validate_starter_shown()
  eq(child.fn.mode(), 'n')

  expect.match(table.concat(get_lines(), '\n'), 'Builtin actions')
end

T['open()']['sets buffer options'] = function()
  -- Cache initial data for future verification
  child.o.showtabline = 2
  local init_laststatus = child.o.laststatus

  -- Open Starter buffer
  child.lua('MiniStarter.open()')

  -- Should set essential buffer options (not all actualy set are tested)
  eq(child.bo.bufhidden, 'wipe')
  eq(child.bo.buflisted, false)
  eq(child.bo.buftype, 'nofile')
  eq(child.wo.foldlevel, 999)
  eq(child.bo.modifiable, false)
  eq(child.wo.colorcolumn, '')
  eq(child.wo.signcolumn, 'no')

  -- Should hide tabline but not touch statusline
  eq(child.o.showtabline, 1)
  eq(child.o.laststatus, init_laststatus)

  -- Verify that tabline resets to its initial value
  child.cmd('bwipeout')
  eq(child.o.showtabline, 2)
end

local has_map = function(key, value)
  value = value or ''
  local cmd = 'nmap <buffer> ' .. key
  local pattern = vim.pesc('MiniStarter.' .. value)
  expect.match(child.cmd_capture(cmd), pattern)
end

T['open()']['makes buffer mappings'] = function()
  child.lua('MiniStarter.open()')

  has_map('<CR>', 'eval_current_item()')
  has_map('<Up>', [[update_current_item('prev')]])
  has_map('<C-p>', [[update_current_item('prev')]])
  has_map('<M-k>', [[update_current_item('prev')]])
  has_map('<Down>', [[update_current_item('next')]])
  has_map('<C-n>', [[update_current_item('next')]])
  has_map('<M-j>', [[update_current_item('next')]])
  has_map('<Esc>', [[set_query('')]])
  has_map('<BS>', 'add_to_query()')
  has_map('<C-c>', 'close()')

  -- Defines query updaters
  has_map('a', 'add_to_query("a")')
end

T['open()']['handles special query updaters'] = function()
  reload_module({ query_updaters = [["'\]] })
  child.lua('MiniStarter.open()')

  has_map('"', [[add_to_query('"')]])
  has_map("'", [[add_to_query("'")]])
  has_map([[\]], [[add_to_query("\\")]])
end

T['open()']['makes buffer autocommands'] = function()
  child.lua('MiniStarter.open()')
  expect.match(child.cmd_capture('au MiniStarterBuffer'), 'MiniStarter%.')
end

T['open()']['respects `buf_id` argument'] = function()
  local cur_buf_id = child.api.nvim_get_current_buf()
  child.lua(('MiniStarter.open(%s)'):format(cur_buf_id))
  eq(child.api.nvim_get_current_buf(), cur_buf_id)
end

T['open()']['issues an autocommand after finished opening'] = function()
  -- Finished opening
  child.lua('_G.n = 0')
  child.cmd('au User MiniStarterOpened lua _G.n = _G.n + 1')
  child.lua('MiniStarter.open()')

  eq(child.lua_get('_G.n'), 1)

  -- Not finished opening
  child.lua('_G.n = 0')
  child.lua('pcall(MiniStarter.open, "a")')
  eq(child.lua_get('_G.n'), 0)
end

T['open()']['respects `vim.{g,b}.ministarter_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].ministarter_disable = true

    child.lua('MiniStarter.open()')
    validate_starter_not_shown()
  end,
})

T['refresh()'] = new_set({
  hooks = {
    pre_case = function()
      -- Avoid hit-enter-prompt
      child.o.cmdheight = 10
    end,
  },
})

T['refresh()']['does `header` normalization'] = function()
  validate_equal_starter({ header = '100' }, { header = [['100']] })
  validate_equal_starter({ header = [[function() return 'aaa' end]] }, { header = [['aaa']] })
  validate_equal_starter({ header = [[function() return 'aaa\nbbb' end]] }, { header = [['aaa\nbbb']] })
  validate_equal_starter({ header = 'function() return 100 end' }, { header = [['100']] })
  validate_equal_starter({ header = 'function() return end' }, { header = [['nil']] })
end

T['refresh()']['does `header` normalization for empty string'] = function()
  reload_module({ content_hooks = {}, header = '' })
  child.lua('MiniStarter.open()')
  -- Empty header should result into no header and no empty line after it
  expect.no_equality(get_lines()[1], '')
end

T['refresh()']['does `footer` normalization'] = function()
  validate_equal_starter({ footer = '100' }, { footer = [['100']] })
  validate_equal_starter({ footer = [[function() return 'aaa' end]] }, { footer = [['aaa']] })
  validate_equal_starter({ footer = [[function() return 'aaa\nbbb' end]] }, { footer = [['aaa\nbbb']] })
  validate_equal_starter({ footer = 'function() return 100 end' }, { footer = [['100']] })
  validate_equal_starter({ footer = 'function() return end' }, { footer = [['nil']] })
end

T['refresh()']['does `footer` normalization for empty string'] = function()
  reload_module({ content_hooks = {}, footer = '' })
  child.lua('MiniStarter.open()')
  -- Empty footer should result into no footer and no empty line before it
  local lines = get_lines()
  expect.no_equality(lines[#lines], '')
end

T['refresh()']['does `items` normalization'] = function()
  local item = mock_itemstring('a', 'Section a')
  local item_2 = mock_itemstring('ba', 'Section b')
  local item_3 = mock_itemstring('bb', 'Section b')
  local item_empty = mock_itemstring('empty', '')
  local item_empty_2 = mock_itemstring('empty2', '')

  -- Evaluates functions
  validate_equal_starter({ items = ('{ function() return %s end }'):format(item) }, {
    items = ('{ %s }'):format(item),
  })

  -- Flattens nested tables
  validate_equal_starter({ items = ('{{%s}}'):format(item) }, { items = ('{%s}'):format(item) })

  -- Sorts items
  validate_equal_starter(
    { items = ('{%s, %s, %s}'):format(item_2, item, item_3) },
    { items = ('{%s, %s, %s}'):format(item_2, item_3, item) }
  )

  -- Sorts after flattening
  validate_equal_starter(
    { items = ('{{%s, %s}, {%s}}'):format(item_2, item, item_3) },
    { items = ('{%s, %s, %s}'):format(item_2, item_3, item) }
  )

  -- Sorts empty section name as any other section name
  validate_equal_starter(
    { items = ('{%s, %s, %s, %s}'):format(item_2, item_empty, item_3, item_empty_2) },
    { items = ('{%s, %s, %s, %s}'):format(item_2, item_3, item_empty, item_empty_2) }
  )
end

T['refresh()']['allows empty `items`'] = function()
  validate_equal_starter(
    { items = '{}' },
    { items = [[{ { name = '`MiniStarter.config.items` is empty', action = '', section = '' } }]] }
  )
  -- It shouldn't give any messages
  eq(get_latest_message(), '')
end

T['refresh()']['prevents infinite recursion in `items` normalization'] = function()
  local item = mock_itemstring('a', 'A')
  reload_from_strconfig({ items = ('{ %s }'):format(item) })
  child.lua('MiniStarter.open()')
  local lines_1 = get_lines()

  child.lua('_G.f = function() return _G.f end')
  reload_from_strconfig({ items = ('{ _G.f, %s }'):format(item) })
  child.lua('MiniStarter.open()')
  local lines_2 = get_lines()

  eq(get_latest_message(), '(mini.starter) Too many nested functions in `config.items`.')

  eq(lines_1, lines_2)
end

T['refresh()']['does normalization on every call'] = function()
  child.lua('_G.n = 0')

  local strconfig_1 = {
    header = 'function() _G.n = _G.n + 1; return _G.n end',
    items = [[{ function() return { action = 'echo "a"', name = tostring(_G.n), section = 'Section a' } end }]],
    footer = 'function() return _G.n end',
  }
  local strconfig_2 = {
    header = [['2']],
    items = [[{ action = 'echo "a"', name = '2', section = 'Section a' }]],
    footer = [['2']],
  }

  reload_from_strconfig(strconfig_1)
  child.lua('MiniStarter.open()')
  child.lua('MiniStarter.refresh()')
  local lines_1 = get_lines()

  reload_from_strconfig(strconfig_2)
  child.lua('MiniStarter.open()')
  local lines_2 = get_lines()

  eq(lines_1, lines_2)
end

T['refresh()']['uses current `MiniStarter.config`'] = function()
  child.lua('MiniStarter.open()')
  child.lua('MiniStarter.config.header = "New header"')
  child.lua('MiniStarter.refresh()')
  local lines_1 = get_lines()

  reload_from_strconfig({ header = [['New header']] })
  child.lua('MiniStarter.open()')
  local lines_2 = get_lines()

  eq(lines_1, lines_2)
end

local reload_with_hooks = function()
  unload_module()
  child.lua('_G.hooks_history = {}')
  child.lua([[
    require('mini.starter').setup({ content_hooks = {
      function(x) table.insert(_G.hooks_history, 'a'); return x end,
      function(x) table.insert(_G.hooks_history, 'b'); return x end,
    } })]])
end

T['refresh()']['applies `content_hooks` sequentially'] = function()
  reload_with_hooks()
  child.lua('MiniStarter.open()')
  eq(child.lua_get('_G.hooks_history'), { 'a', 'b' })
end

T['refresh()']['calls `content_hooks` on every call'] = function()
  reload_with_hooks()
  child.lua('MiniStarter.open()')
  child.lua('MiniStarter.refresh()')
  eq(child.lua_get('_G.hooks_history'), { 'a', 'b', 'a', 'b' })
end

T['close()'] = new_set()

T['close()']['works'] = function()
  child.lua('MiniStarter.open()')
  local buf_id = child.api.nvim_get_current_buf()
  validate_starter_shown()

  child.lua('MiniStarter.close()')
  eq(child.api.nvim_buf_is_valid(buf_id), false)
  validate_starter_not_shown()
end

T['close()']['can be used when no Starter buffer is shown'] = function()
  validate_starter_not_shown()
  expect.no_error(function()
    child.lua('MiniStarter.close()')
  end)
end

-- Work with content ----------------------------------------------------------
T['Default content'] = new_set()

local validate_starter_lines = function(pattern)
  if is_starter_shown() then
    child.lua('MiniStarter.close()')
  end
  child.lua('MiniStarter.open()')
  local lines_string = table.concat(get_lines(), '\n')
  child.cmd('bwipeout')
  expect.match(lines_string, pattern)
end

T['Default content']['has correct `header`'] = function()
  -- Mock functions used to compute greeting
  child.lua([[vim.loop.os_get_passwd = function() return { username = 'MINI' } end]])
  local mock_time = function(time)
    local cmd = ([[vim.fn.strftime = function(x) return x == '%%H' and '%s' or '' end]]):format(time)
    child.lua(cmd)
  end

  local test_values = {
    ['00'] = 'Good evening, MINI',
    ['04'] = 'Good morning, MINI',
    ['08'] = 'Good morning, MINI',
    ['12'] = 'Good afternoon, MINI',
    ['16'] = 'Good afternoon, MINI',
    ['20'] = 'Good evening, MINI',
  }

  for time, pattern in pairs(test_values) do
    mock_time(time)
    validate_starter_lines(pattern)
  end
end

T['Default content']['has correct item bullet'] = function()
  validate_starter_lines('░ Quit Neovim')
end

T['Default content']["has 'Sessions' section"] = function()
  -- Shouldn't be present if 'mini.sessions' is not set up
  expect.error(function()
    validate_starter_lines('Sessions')
  end)

  -- Should be present even if there is no detected sessions
  child.lua([[require('mini.sessions').setup({ file = '', directory = '' })]])
  validate_starter_lines([[Sessions%s+░ There are no detected sessions in 'mini%.sessions']])

  -- Should show local (first and with `(local)` note) and global sessions
  child.cmd('cd tests/starter-tests/sessions')
  child.lua([[require('mini.sessions').setup({ directory = '.' })]])
  local pattern = table.concat(
    { 'Sessions', '░ Session%.vim %(local%)', '░ session_global%.lua', 'Recent files' },
    '%s+'
  )
  validate_starter_lines(pattern)
end

T['Default content']["has 'Recent files' section"] = function()
  -- It should display only readable files
  child.v.oldfiles = { 'README.md', 'bbb.lua' }
  validate_starter_lines('Recent files%s+░ README%.md%s+Builtin actions')

  -- Should still display section if there is no recent files
  child.v.oldfiles = {}
  validate_starter_lines('Recent files%s+░ There are no recent files')
end

T['Default content']["has 'Builtin actions' section"] = function()
  validate_starter_lines('Builtin actions%s+░ Edit new buffer%s+░ Quit Neovim')
end

T['Default content']['has correct `footer`'] = function()
  local pattern = table.concat(
    { 'Type query to filter items', '<BS>', '<Esc>', '<Down/Up>, <C%-n/p>, <M%-j/k>', '<CR>', '<C%-c>' },
    '.*'
  )
  validate_starter_lines(pattern)
end

T['Content'] = new_set()

T['Content']['works'] = function()
  local item = mock_item('a', 'Section a')
  local validate_content = function()
    -- Every element of array should contain conent for a particular line
    local content = child.lua_get('MiniStarter.content')
    eq(content[1], { { hl = 'MiniStarterHeader', string = 'Hello', type = 'header' } })
    eq(content[2], { { string = '', type = 'empty' } })
    eq(content[3], { { hl = 'MiniStarterSection', string = 'Section a', type = 'section' } })
    eq(content[4], { { hl = 'MiniStarterItem', item = content[4][1].item, string = 'a', type = 'item' } })
    eq(content[5], { { string = '', type = 'empty' } })
    eq(content[6], { { hl = 'MiniStarterFooter', string = 'World', type = 'footer' } })

    local content_item = content[4][1].item
    eq({ name = content_item.name, action = content_item.action, section = content_item.section }, item)
  end

  load_module({ content_hooks = {}, header = 'Hello', footer = 'World', items = { item } })
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'Hello', '', 'Section a', 'a', '', 'World' })
  validate_content()

  -- Should persist even outside of Starter buffer
  child.cmd('bwipeout')
  validate_starter_not_shown()
  validate_content()
end

T['content_coords()'] = new_set({
  hooks = {
    pre_case = function()
      local item = mock_item('a', 'Section A')
      reload_module({ content_hooks = {}, header = 'Hello', footer = 'World', items = { item } })
      child.lua('MiniStarter.open()')
    end,
  },
})

T['content_coords()']['works with function argument'] = function()
  local coords = child.lua_get([[MiniStarter.content_coords(MiniStarter.content, function(x)
        return vim.tbl_contains({'Hello', 'World'}, x.string)
      end)]])
  eq(coords, { { line = 1, unit = 1 }, { line = 6, unit = 1 } })
end

T['content_coords()']['works with string argument'] = function()
  local coords = child.lua_get([[MiniStarter.content_coords(MiniStarter.content, 'empty')]])
  eq(coords, { { line = 2, unit = 1 }, { line = 5, unit = 1 } })
end

T['content_coords()']['works with no argument'] = function()
  local coords = child.lua_get('MiniStarter.content_coords(MiniStarter.content, nil)')
  for i = 1, 6 do
    eq(coords[i], { line = i, unit = 1 })
  end
end

T['content_to_lines()'] = new_set({
  hooks = {
    pre_case = function()
      child.lua('MiniStarter.open()')
    end,
  },
})

T['content_to_lines()']['works'] = function()
  eq(child.lua_get('MiniStarter.content_to_lines(MiniStarter.content)'), get_lines())
end

T['content_to_items()'] = new_set()

T['content_to_items()']['works'] = function()
  reload_module({ content_hooks = {}, items = example_items })
  child.lua('MiniStarter.open()')

  local output = child.lua_get('MiniStarter.content_to_items(MiniStarter.content)')

  -- Should contain all information from input items
  for i, item in ipairs(output) do
    eq({ name = item.name, action = item.action, section = item.section }, example_items[i])
  end

    -- Should correctly compute length of minimum unique prefix
    --stylua: ignore
    eq( vim.tbl_map(function(x) return x._nprefix end, output), { 3, 3, 2, 1 })
end

T['content_to_items()']["modifies `item`'s name to equal content unit's `string`"] = function()
  local content = {
    { { type = 'item', string = 'aaa', item = mock_item('bbb', '') } },
    { { type = 'item', string = 'c\nc\nc', item = mock_item('ddd', '') } },
    { { type = 'empty', string = 'eee', item = mock_item('fff', '') } },
  }
  local output = child.lua_get('MiniStarter.content_to_items(...)', { content })
  eq(#output, 2)
  eq({ output[1].name, output[1].action }, { 'aaa', content[1][1].item.action })
  eq({ output[2].name, output[2].action }, { 'c c c', content[2][1].item.action })
end

T['gen_hook'] = new_set()

T['gen_hook']['has `adding_bullet()`'] = function()
  reload_from_strconfig({ content_hooks = '{ MiniStarter.gen_hook.adding_bullet() }' })
  child.lua('MiniStarter.open()')
  local lines_string = table.concat(get_lines(), '\n')
  expect.match(lines_string, '%s+░ Quit Neovim%s+')
end

T['gen_hook']['adding_bullet() respects `bullet` argument'] = function()
  reload_from_strconfig({ content_hooks = [[{ MiniStarter.gen_hook.adding_bullet('> ') }]] })
  child.lua('MiniStarter.open()')
  local lines_string = table.concat(get_lines(), '\n')
  expect.match(lines_string, '%s+> Quit Neovim%s+')
end

T['gen_hook']['adding_bullet() respects `place_cursor` argument'] = function()
  local reload = function(place_cursor)
    reload_from_strconfig({
      header = [['']],
      footer = [['']],
      items = ('{ %s }'):format(mock_itemstring('bbb', '')),
      content_hooks = ([[{ MiniStarter.gen_hook.adding_bullet('aaa', %s) }]]):format(place_cursor),
    })
  end

  reload(false)
  child.lua('MiniStarter.open()')
  eq(get_cursor(), { 2, 3 })

  reload(true)
  child.lua('MiniStarter.open()')
  eq(get_cursor(), { 2, 0 })
end

T['gen_hook']['has `aligning()`'] = function()
  -- By default shouldn't do any aligning
  validate_equal_starter({ content_hooks = '{}' }, { content_hooks = '{ MiniStarter.gen_hook.aligning() }' })
end

local has_horizontal_padding = function(lines, n)
  -- Should add left padding only on non-empty lines
  local pattern = '^' .. string.rep(' ', n) .. '%S'
  for _, l in ipairs(lines) do
    eq(l:find(pattern) ~= nil or l == '', true)
  end
end

local has_vertical_padding = function(lines, n)
  for i = 1, n do
    eq(lines[i], '')
  end
  expect.no_equality(lines[n + 1], '')
end

local validate_aligning = function(args, pads)
  reload_from_strconfig({
    content_hooks = ('{ MiniStarter.gen_hook.aligning(%s) }'):format(args),
    header = [['']],
    footer = [['']],
    items = ('{ %s, %s }'):format(mock_itemstring('aaa', 'AAA'), mock_itemstring('bbb', 'AAA')),
  })
  child.lua('MiniStarter.open()')

  local lines = get_lines()
  has_horizontal_padding(lines, pads[1])
  has_vertical_padding(lines, pads[2])

  -- Cleanup. Don't use `bwipeout` because it affects window layout.
  child.cmd('bnext')
end

T['gen_hook']['aligning() respects `horizontal` argument'] = function()
  child.cmd('vsplit | split')
  child.api.nvim_win_set_width(0, 20)
  child.api.nvim_win_set_height(0, 10)

  validate_aligning([['left', 'top']], { 0, 0 })
  validate_aligning([['left', 'center']], { 0, 3 })
  validate_aligning([['left', 'bottom']], { 0, 7 })
  validate_aligning([['center', 'top']], { 8, 0 })
  validate_aligning([['center', 'center']], { 8, 3 })
  validate_aligning([['center', 'bottom']], { 8, 7 })
  validate_aligning([['right', 'top']], { 17, 0 })
  validate_aligning([['right', 'center']], { 17, 3 })
  validate_aligning([['right', 'bottom']], { 17, 7 })
end

T['gen_hook']['aligning() handles small windows'] = function()
  child.cmd('vsplit | split')
  child.api.nvim_win_set_width(0, 2)
  child.api.nvim_win_set_height(0, 2)

  validate_aligning([['right', 'bottom']], { 0, 0 })
end

local reload_indexing = function(args)
  local itemstrings = {
    mock_itemstring('a', 'AAA'),
    mock_itemstring('aa', 'AAA'),
    mock_itemstring('b', 'BBB'),
    mock_itemstring('bb', 'BBB'),
  }
  reload_from_strconfig({
    header = [['']],
    footer = [['']],
    items = '{ ' .. table.concat(itemstrings, ', ') .. '}',
    content_hooks = ('{ MiniStarter.gen_hook.indexing(%s) }'):format(args),
  })
end

T['gen_hook']['has `indexing()`'] = function()
  reload_indexing('')
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'AAA', '1. a', '2. aa', '', 'BBB', '3. b', '4. bb' })
end

T['gen_hook']['indexing() respects `grouping` argument'] = function()
  reload_indexing([['all', nil]])
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'AAA', '1. a', '2. aa', '', 'BBB', '3. b', '4. bb' })
  child.lua('MiniStarter.close()')

  -- With `'section'`, it should prepend with unique letter index per section
  reload_indexing([['section', nil]])
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'AAA', 'a1. a', 'a2. aa', '', 'BBB', 'b1. b', 'b2. bb' })
  child.lua('MiniStarter.close()')
end

T['gen_hook']['indexing() respects `exclude_sections` argument'] = function()
  reload_indexing('nil, {}')
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'AAA', '1. a', '2. aa', '', 'BBB', '3. b', '4. bb' })
  child.lua('MiniStarter.close()')

  -- It should exclude from indexing sections from `exclude_sections`
  reload_indexing([[nil, {'AAA'}]])
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'AAA', 'a', 'aa', '', 'BBB', '1. b', '2. bb' })
  child.lua('MiniStarter.close()')
end

T['gen_hook']['has `padding()`'] = function()
  -- By default shouldn't add any padding
  validate_equal_starter({ content_hooks = '{}' }, { content_hooks = '{ MiniStarter.gen_hook.padding() }' })
end

T['gen_hook']['padding() respects `left` argument'] = function()
  reload_from_strconfig({ content_hooks = '{ MiniStarter.gen_hook.padding(2, 0) }' })
  child.lua('MiniStarter.open()')
  local lines = get_lines()
  has_horizontal_padding(lines, 2)
  expect.no_equality(lines[1], '')
end

T['gen_hook']['padding() respects `top` argument'] = function()
  reload_from_strconfig({ content_hooks = '{ MiniStarter.gen_hook.padding(0, 2) }' })
  child.lua('MiniStarter.open()')
  local lines = get_lines()
  has_vertical_padding(lines, 2)
  expect.no_equality(lines[3], '')
end

T['sections'] = new_set()

T['gen_hook']['correctly present'] = function()
  local types = child.lua_get('vim.tbl_map(type, MiniStarter.sections)')
  eq(types, { builtin_actions = 'function', recent_files = 'function', sessions = 'function', telescope = 'function' })
end

-- Work with query ------------------------------------------------------------
T['set_query()'] = new_set({
  hooks = {
    pre_case = function()
      -- Avoid hit-enter-prompt
      child.o.cmdheight = 10

      reload_module({ items = example_items })
      child.lua('MiniStarter.open()')
    end,
  },
})

T['set_query()']['works'] = function()
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })

  child.lua([[MiniStarter.set_query('aaa')]])
  eq(get_active_items_names(), { 'aaab' })

  child.lua([[MiniStarter.set_query('a')]])
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })

  child.lua([[MiniStarter.set_query('aa')]])
  eq(get_active_items_names(), { 'aaab', 'aaba' })
end

T['set_query()']['validates argument'] = function()
  expect.error(function()
    child.lua('MiniStarter.set_query(1)')
  end, '`query`.*`nil` or string')
end

T['set_query()']['does not allow query resulting in no active items'] = function()
  child.lua([[MiniStarter.set_query('a')]])
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })

  child.lua([[MiniStarter.set_query('c')]])
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })
  expect.match(get_latest_message(), '%(mini%.starter%) Query "c" results into no active items%. Current query: a')
end

T['set_query()']['resets query with empty string'] = function()
  child.lua([[MiniStarter.set_query('a')]])
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })

  child.lua([[MiniStarter.set_query('')]])
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })
end

T['add_to_query()'] = new_set({
  hooks = {
    pre_case = function()
      -- Avoid hit-enter-prompt
      child.o.cmdheight = 10

      child.lua('MiniStarter.config.items = ' .. vim.inspect(example_items))
      child.lua('MiniStarter.open()')
    end,
  },
})

T['add_to_query()']['works'] = function()
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })

  child.lua([[MiniStarter.add_to_query('a')]])
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })

  child.lua([[MiniStarter.add_to_query('a')]])
  eq(get_active_items_names(), { 'aaab', 'aaba' })

  child.lua([[MiniStarter.add_to_query('a')]])
  eq(get_active_items_names(), { 'aaab' })

  child.lua([[MiniStarter.add_to_query('b')]])
  eq(get_active_items_names(), { 'aaab' })

  -- Allows empty string with no effect
  child.lua([[MiniStarter.add_to_query('')]])
  eq(get_active_items_names(), { 'aaab' })

  -- Doesn't allow adding to query resulting into no active items
  child.lua([[MiniStarter.add_to_query('c')]])
  eq(get_active_items_names(), { 'aaab' })
  expect.match(get_latest_message(), 'Query "aaabc".*no active items.*Current query: aaab')
end

T['add_to_query()']['removes from query with no argument'] = function()
  child.lua([[MiniStarter.add_to_query('a')]])
  child.lua([[MiniStarter.add_to_query('a')]])
  eq(get_active_items_names(), { 'aaab', 'aaba' })

  child.lua('MiniStarter.add_to_query()')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })

  child.lua('MiniStarter.add_to_query()')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })

  -- Works even when current query is already empty
  child.lua('MiniStarter.add_to_query()')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })
end

-- Integration tests ==========================================================
T['Autoopening'] = new_set()

T['Autoopening']['works'] = function()
  child.restart({ '-u', 'tests/starter-tests/init-files/test-init.lua' })
  validate_starter_shown()

  -- It should result into total single buffer
  eq(#child.api.nvim_list_bufs(), 1)
end

T['Autoopening']['does not autoopen if Neovim started to show something'] = function()
  local init_autoopen = 'tests/starter-tests/init-files/test-init.lua'

  -- Current buffer has any lines (something opened explicitly)
  child.restart({ '-u', init_autoopen, '-c', [[call setline(1, 'a')]] })
  validate_starter_not_shown()

  -- Several buffers are listed (like session with placeholder buffers)
  child.restart({ '-u', init_autoopen, '-c', 'e foo | set buflisted | e bar | set buflisted' })
  validate_starter_not_shown()

  -- Unlisted buffers (like from `nvim-tree`) don't affect decision
  child.restart({ '-u', init_autoopen, '-c', 'e foo | set nobuflisted | e bar | set buflisted' })
  validate_starter_shown()

  -- There are files in arguments (like `nvim foo.txt` with new file).
  child.restart({ '-u', init_autoopen, 'new-file.txt' })
  validate_starter_not_shown()
end

T['Querying'] = new_set({
  hooks = {
    pre_case = function()
      -- Avoid hit-enter-prompt
      child.o.cmdheight = 10
    end,
  },
})

T['Querying']['works'] = function()
  reload_module({ items = example_items })
  child.lua('MiniStarter.open()')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })

  type_keys('a')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })

  type_keys('b')
  eq(get_active_items_names(), { 'abaa' })

  -- Doesn't allow adding to query resulting into no active items
  type_keys('c')
  eq(get_active_items_names(), { 'abaa' })
  expect.match(get_latest_message(), 'Query "abc".*no active items.*Current query: ab')
end

T['Querying']['respects `config.query_updaters`'] = function()
  reload_module({ items = example_items, query_updaters = 'a' })
  child.lua('MiniStarter.open()')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })

  type_keys('a')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })

  type_keys('b')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })
  eq(get_latest_message(), '')
end

T['Querying']['respects `config.evaluate_single`'] = function()
  reload_module({ evaluate_single = true, items = example_items })
  child.lua('MiniStarter.open()')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })
  child.lua('_G.item_name = nil')

  type_keys('b')
  eq(get_active_items_names(), { 'baaa' })
  eq(child.lua_get('_G.item_name'), 'baaa')
end

T['Keybindings'] = new_set({
  hooks = {
    pre_case = function()
      -- Avoid hit-enter-prompt
      child.o.cmdheight = 10
      reload_module({ items = example_items, content_hooks = {}, header = '', footer = '' })
      child.lua('MiniStarter.open()')
    end,
  },
})

T['Keybindings']['have working <BS>'] = function()
  child.lua([[MiniStarter.set_query('aa')]])
  eq(get_active_items_names(), { 'aaab', 'aaba' })

  type_keys('<BS>')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa' })
end

T['Keybindings']['have working <Esc>'] = function()
  child.lua([[MiniStarter.set_query('aa')]])
  eq(get_active_items_names(), { 'aaab', 'aaba' })

  type_keys('<Esc>')
  eq(get_active_items_names(), { 'aaab', 'aaba', 'abaa', 'baaa' })
end

T['Keybindings']['arrows'] = new_set({
  parametrize = {
    { { down = '<Down>', up = '<Up>' } },
    { { down = '<C-n>', up = '<C-p>' } },
    { { down = '<M-j>', up = '<M-k>' } },
  },
}, {
  function(keys)
    eq(get_lines(), { 'A', 'aaab', 'aaba', '', 'B', 'abaa', 'baaa' })
    eq(get_cursor(), { 2, 0 })

    -- Basics work
    type_keys(keys.down)
    eq(get_cursor(), { 3, 0 })
    type_keys(keys.up)
    eq(get_cursor(), { 2, 0 })

    -- Movement ignores not active items
    child.lua([[MiniStarter.set_query('aa')]])
    eq(get_cursor(), { 2, 0 })

    type_keys(keys.down)
    type_keys(keys.down)
    eq(get_cursor(), { 2, 0 })

    type_keys(keys.up)
    type_keys(keys.up)
    eq(get_cursor(), { 2, 0 })

    -- Works with single active item
    child.lua([[MiniStarter.set_query('aaab')]])
    eq(get_cursor(), { 2, 0 })

    type_keys(keys.down)
    eq(get_cursor(), { 2, 0 })

    type_keys(keys.up)
    eq(get_cursor(), { 2, 0 })
  end,
})

T['Keybindings']['have working <CR>'] = function()
  child.lua([[MiniStarter.set_query('aaab')]])
  eq(get_active_items_names(), { 'aaab' })
  child.lua('_G.item_name = nil')

  type_keys('<CR>')
  eq(child.lua_get('_G.item_name'), 'aaab')
end

T['Keybindings']['have working <C-c>'] = function()
  validate_starter_shown()
  type_keys('<C-c>')
  validate_starter_not_shown()
end

-- It would be great to test highlighting directly (if something is highlighted
-- as it should be), but currently mocking seems like the only way
T['Highlighting'] = new_set({
  hooks = {
    pre_case = function()
      reload_module({ items = example_items, content_hooks = {}, header = 'Hello', footer = 'World' })

      -- Mock basic highlighting function
      child.lua('_G.hl_history = {}')
      child.lua('vim.highlight.range = function(...) table.insert(_G.hl_history, { ... }) end')
    end,
  },
})

local get_hl_history = function(filter)
  filter = filter or {}

  local history = vim.tbl_map(function(x)
    return { hl = x[3], start = x[4], finish = x[5], priority = (x[6] or {}).priority }
  end, child.lua_get('_G.hl_history'))

  return vim.tbl_filter(function(x)
    for key, val in pairs(filter) do
      if not (x[key] == nil or x[key] == val) then
        return false
      end
    end

    -- Use special `line` key to filter by line
    if not (filter.line == nil or filter.line == x.start[1]) then
      return false
    end

    return true
  end, history)
end

local reset_hl_history = function()
  child.lua('_G.hl_history = {}')
end

local validate_hl_history = function(filter, expected)
  local hl_history = get_hl_history(filter)
  -- Don't test equality of `priority` values on Neovim<0.7 because it was
  -- only introduced in Neovim 0.7 (and forced to be used in 'mini.starter'
  -- due to regression bug in `vim.highlight.range`; see source code)
  if vim.fn.has('nvim-0.7') == 0 then
    for _, history_element in ipairs(expected) do
      history_element.priority = nil
    end
  end

  eq(hl_history, expected)
end

T['Highlighting']['works on open'] = function()
  MiniTest.add_note('Rework with screen tests')
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'Hello', '', 'A', 'aaab', 'aaba', '', 'B', 'abaa', 'baaa', '', 'World' })

  --stylua: ignore start
  validate_hl_history({ line = 0 }, { { hl = 'MiniStarterHeader',  start = { 0, 0 }, finish = { 0, 5 }, priority = 50 } })
  validate_hl_history({ line = 1 }, {})
  validate_hl_history({ line = 2 }, { { hl = 'MiniStarterSection', start = { 2, 0 }, finish = { 2, 1 }, priority = 50 } })
  validate_hl_history({ line = 3 }, {
    { hl = 'MiniStarterItem',       start = { 3, 0 }, finish = { 3, 4 }, priority = 50 },
    { hl = 'MiniStarterItemPrefix', start = { 3, 0 }, finish = { 3, 3 }, priority = 51 },
    { hl = 'MiniStarterCurrent',    start = { 3, 0 }, finish = { 3, 4 }, priority = 52 },
    { hl = 'MiniStarterQuery',      start = { 3, 0 }, finish = { 3, 0 }, priority = 53 },
  })
  validate_hl_history({ line = 4 }, {
    { hl = 'MiniStarterItem',       start = { 4, 0 }, finish = { 4, 4 }, priority = 50 },
    { hl = 'MiniStarterItemPrefix', start = { 4, 0 }, finish = { 4, 3 }, priority = 51 },
    { hl = 'MiniStarterQuery',      start = { 4, 0 }, finish = { 4, 0 }, priority = 53 },
  })
  validate_hl_history({ line = 5 }, {})
  validate_hl_history({ line = 6 }, { { hl = 'MiniStarterSection', start = { 6, 0 }, finish = { 6, 1 }, priority = 50 } })
  validate_hl_history({ line = 7 }, {
    { hl = 'MiniStarterItem',       start = { 7, 0 }, finish = { 7, 4 }, priority = 50 },
    { hl = 'MiniStarterItemPrefix', start = { 7, 0 }, finish = { 7, 2 }, priority = 51 },
    { hl = 'MiniStarterQuery',      start = { 7, 0 }, finish = { 7, 0 }, priority = 53 },
  })
  validate_hl_history({ line = 8 }, {
    { hl = 'MiniStarterItem',       start = { 8, 0 }, finish = { 8, 4 }, priority = 50 },
    { hl = 'MiniStarterItemPrefix', start = { 8, 0 }, finish = { 8, 1 }, priority = 51 },
    { hl = 'MiniStarterQuery',      start = { 8, 0 }, finish = { 8, 0 }, priority = 53 },
  })
  validate_hl_history({ line = 9 }, {})
  validate_hl_history({ line = 10 }, { { hl = 'MiniStarterFooter', start = { 10, 0 }, finish = { 10, 5 }, priority = 50 } })
  --stylua: ignore end
end

T['Highlighting']['works for querying'] = function()
  MiniTest.add_note('Rework with screen tests')
  child.lua('MiniStarter.open()')

  reset_hl_history()
  type_keys('a')
  validate_hl_history({ hl = 'MiniStarterQuery' }, {
    { hl = 'MiniStarterQuery', start = { 3, 0 }, finish = { 3, 1 }, priority = 53 },
    { hl = 'MiniStarterQuery', start = { 4, 0 }, finish = { 4, 1 }, priority = 53 },
    { hl = 'MiniStarterQuery', start = { 7, 0 }, finish = { 7, 1 }, priority = 53 },
  })
  validate_hl_history(
    { hl = 'MiniStarterInactive' },
    { { hl = 'MiniStarterInactive', start = { 8, 0 }, finish = { 8, 4 }, priority = 53 } }
  )

  reset_hl_history()
  type_keys('b')
  validate_hl_history({ hl = 'MiniStarterQuery' }, {
    { hl = 'MiniStarterQuery', start = { 7, 0 }, finish = { 7, 2 }, priority = 53 },
  })
  validate_hl_history({ hl = 'MiniStarterInactive' }, {
    { hl = 'MiniStarterInactive', start = { 3, 0 }, finish = { 3, 4 }, priority = 53 },
    { hl = 'MiniStarterInactive', start = { 4, 0 }, finish = { 4, 4 }, priority = 53 },
    { hl = 'MiniStarterInactive', start = { 8, 0 }, finish = { 8, 4 }, priority = 53 },
  })
end

T['Highlighting']['works for current item'] = function()
  MiniTest.add_note('Rework with screen tests')
  child.lua('MiniStarter.open()')
  validate_hl_history(
    { hl = 'MiniStarterCurrent' },
    { { hl = 'MiniStarterCurrent', start = { 3, 0 }, finish = { 3, 4 }, priority = 52 } }
  )

  reset_hl_history()
  type_keys('<Down>')
  validate_hl_history(
    { hl = 'MiniStarterCurrent' },
    { { hl = 'MiniStarterCurrent', start = { 4, 0 }, finish = { 4, 4 }, priority = 52 } }
  )
end

T['Highlighting']['uses `MiniStarterItemBullet`'] = function()
  MiniTest.add_note('Rework with screen tests')
  reload_from_strconfig({
    items = example_itemstring,
    content_hooks = '{ MiniStarter.gen_hook.adding_bullet() }',
    header = [['']],
    footer = [['']],
  })
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'A', '░ aaab', '░ aaba', '', 'B', '░ abaa', '░ baaa' })

  -- `col_end` shows byte column and '░' has 3 bytes
  validate_hl_history({ hl = 'MiniStarterItemBullet' }, {
    { hl = 'MiniStarterItemBullet', start = { 1, 0 }, finish = { 1, 4 }, priority = 50 },
    { hl = 'MiniStarterItemBullet', start = { 2, 0 }, finish = { 2, 4 }, priority = 50 },
    { hl = 'MiniStarterItemBullet', start = { 5, 0 }, finish = { 5, 4 }, priority = 50 },
    { hl = 'MiniStarterItemBullet', start = { 6, 0 }, finish = { 6, 4 }, priority = 50 },
  })
end

T['Cursor positioning'] = new_set({
  hooks = {
    pre_case = function()
      reload_module({ items = example_items, content_hooks = {}, header = '', footer = '' })
    end,
  },
})

T['Cursor positioning']['reacts to keys'] = function()
  MiniTest.add_note('Rework with screen tests')
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'A', 'aaab', 'aaba', '', 'B', 'abaa', 'baaa' })
  eq(get_cursor(), { 2, 0 })

  type_keys('<Down>')
  eq(get_cursor(), { 3, 0 })

  type_keys('<Down>')
  eq(get_cursor(), { 6, 0 })

  type_keys('<Down><Down>')
  eq(get_cursor(), { 2, 0 })

  type_keys('<Up>')
  eq(get_cursor(), { 7, 0 })
end

T['Cursor positioning']['updates when current item becomes inactive'] = function()
  MiniTest.add_note('Rework with screen tests')
  child.lua('MiniStarter.open()')
  eq(get_cursor(), { 2, 0 })

  child.lua([[MiniStarter.set_query('baaa')]])
  eq(get_cursor(), { 7, 0 })

  -- It should stay the same even if previous item again becomes active
  child.lua([[MiniStarter.set_query('')]])
  eq(get_cursor(), { 7, 0 })
end

local reload_with_bullets = function(place_cursor)
  reload_from_strconfig({
    items = example_itemstring,
    content_hooks = ('{ MiniStarter.gen_hook.adding_bullet(nil, %s) }'):format(place_cursor),
    header = [['']],
    footer = [['']],
  })
end

T['Cursor positioning']['works with bullets and `place_cursor=true`'] = function()
  MiniTest.add_note('Rework with screen tests')
  reload_with_bullets(true)
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'A', '░ aaab', '░ aaba', '', 'B', '░ abaa', '░ baaa' })
  eq(get_cursor(), { 2, 0 })

  type_keys('<Down>')
  eq(get_cursor(), { 3, 0 })
end

T['Cursor positioning']['works with bullets and `place_cursor=false`'] = function()
  MiniTest.add_note('Rework with screen tests')
  reload_with_bullets(false)
  child.lua('MiniStarter.open()')
  eq(get_lines(), { 'A', '░ aaab', '░ aaba', '', 'B', '░ abaa', '░ baaa' })
  eq(get_cursor(), { 2, 4 })

  type_keys('<Down>')
  eq(get_cursor(), { 3, 4 })
end

return T
