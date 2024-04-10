local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('pick', config) end
local unload_module = function() child.mini_unload('pick') end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Tweak `expect_screenshot()` to test only on Neovim=0.9 (as it introduced
-- titles and 0.10 introduced footer).
-- Use `child.expect_screenshot_orig()` for original testing.
child.expect_screenshot_orig = child.expect_screenshot
child.expect_screenshot = function(opts, allow_past_09)
  -- TODO: Regenerate all screenshots with 0.10 after its stable release
  if child.fn.has('nvim-0.9') == 0 or child.fn.has('nvim-0.10') == 1 then return end
  child.expect_screenshot_orig(opts)
end

child.has_float_footer = function()
  -- https://github.com/neovim/neovim/pull/24739
  return child.fn.has('nvim-0.10') == 1
end

-- Test paths helpers
local test_dir = 'tests/dir-pick'
local real_files_dir = 'tests/dir-pick/real-files'

local join_path = function(...) return table.concat({ ... }, '/') end

local full_path = function(x)
  local res = vim.fn.fnamemodify(x, ':p'):gsub('/$', '')
  return res
end

local real_file = function(basename) return join_path(real_files_dir, basename) end

local setup_windows_pair = function()
  child.cmd('botright wincmd v')
  local win_id_1 = child.api.nvim_get_current_win()
  child.cmd('wincmd h')
  local win_id_2 = child.api.nvim_get_current_win()
  child.api.nvim_set_current_win(win_id_1)
  return win_id_1, win_id_2
end

-- Common test wrappers
local forward_lua = function(fun_str)
  local lua_cmd = fun_str .. '(...)'
  return function(...) return child.lua_get(lua_cmd, { ... }) end
end

local forward_lua_notify = function(fun_str)
  local lua_cmd = fun_str .. '(...)'
  return function(...) return child.lua_notify(lua_cmd, { ... }) end
end

local stop = forward_lua('MiniPick.stop')
local get_picker_items = forward_lua('MiniPick.get_picker_items')
local get_picker_stritems = forward_lua('MiniPick.get_picker_stritems')
local get_picker_matches = forward_lua('MiniPick.get_picker_matches')
local get_picker_state = forward_lua('MiniPick.get_picker_state')
local get_picker_query = forward_lua('MiniPick.get_picker_query')
local set_picker_items = forward_lua('MiniPick.set_picker_items')
local set_picker_query = forward_lua('MiniPick.set_picker_query')
local get_querytick = forward_lua('MiniPick.get_querytick')
local is_picker_active = forward_lua('MiniPick.is_picker_active')

-- Use `child.api_notify` to allow user input while child process awaits for
-- `start()` to return a value
local start = function(...) child.lua_notify('MiniPick.start(...)', { ... }) end

local start_with_items = function(items, name) start({ source = { items = items, name = name } }) end

-- Common test helpers
local validate_buf_option = function(buf_id, option_name, option_value)
  eq(child.api.nvim_buf_get_option(buf_id, option_name), option_value)
end

local validate_win_option = function(win_id, option_name, option_value)
  eq(child.api.nvim_win_get_option(win_id, option_name), option_value)
end

local validate_buf_name = function(buf_id, name)
  buf_id = buf_id or child.api.nvim_get_current_buf()
  name = name ~= '' and full_path(name) or ''
  name = name:gsub('/+$', '')
  eq(child.api.nvim_buf_get_name(buf_id), name)
end

local validate_contains_all = function(base, to_be_present)
  local is_present_map, is_all_present = {}, true
  for _, x in pairs(to_be_present) do
    is_present_map[x] = vim.tbl_contains(base, x)
    is_all_present = is_all_present and is_present_map[x]
  end
  if is_all_present then return end
  local err_msg = string.format(
    'Not all elements are present:\nActual: %s\nReference map: %s',
    vim.inspect(base),
    vim.inspect(is_present_map)
  )
  error(err_msg)
end

local validate_picker_option = function(string_index, ref)
  local value = child.lua_get('MiniPick.get_picker_opts().' .. string_index)
  eq(value, ref)
end

local validate_picker_view = function(view_name)
  eq(child.api.nvim_get_current_buf(), get_picker_state().buffers[view_name])
end

local validate_current_ind = function(ref_ind) eq(get_picker_matches().current_ind, ref_ind) end

local seq_along = function(x)
  local res = {}
  for i = 1, #x do
    res[i] = i
  end
  return res
end

local make_match_with_count = function()
  child.lua('_G.match_n_calls = 0')
  local validate_match_calls = function(n_calls_ref, match_inds_ref)
    eq(child.lua_get('_G.match_n_calls'), n_calls_ref)
    eq(get_picker_matches().all_inds, match_inds_ref)
  end

  child.lua_notify([[_G.match_with_count = function(...)
    _G.match_n_calls = _G.match_n_calls + 1
    return MiniPick.default_match(...)
  end]])
  return validate_match_calls
end

local make_event_log = function()
  child.lua([[
  _G.event_log = {}
  _G.track_event = function()
    local buf_id = MiniPick.get_picker_state().buffers.main
    local entry
    if not vim.api.nvim_buf_is_valid(buf_id) then
      entry = 'Main buffer is invalid'
    else
      entry = #vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    end
    table.insert(_G.event_log, entry)
  end]])
end

-- Common mocks
local mock_fn_executable = function(available_executables)
  local lua_cmd = string.format(
    'vim.fn.executable = function(x) return vim.tbl_contains(%s, x) and 1 or 0 end',
    vim.inspect(available_executables)
  )
  child.lua(lua_cmd)
end

local mock_picker_cwd = function(cwd)
  child.lua('vim.fn.fnamemodify = function(x) return x end')
  child.lua(string.format('MiniPick.set_picker_opts({ source = { cwd = %s } })', vim.inspect(cwd)))
end

local mock_spawn = function()
  local mock_file = join_path(test_dir, 'mocks', 'spawn.lua')
  local lua_cmd = string.format('dofile(%s)', vim.inspect(mock_file))
  child.lua(lua_cmd)
end

local mock_stdout_feed = function(feed) child.lua('_G.stdout_data_feed = ' .. vim.inspect(feed)) end

local mock_cli_return = function(items) mock_stdout_feed({ table.concat(items, '\n') }) end

local get_spawn_log = function() return child.lua_get('_G.spawn_log') end

local clear_spawn_log = function() child.lua('_G.spawn_log = {}') end

local validate_spawn_log = function(ref, index)
  local present = get_spawn_log()
  if type(index) == 'number' then present = present[index] end
  eq(present, ref)
end

local get_process_log = function() return child.lua_get('_G.process_log') end

local clear_process_log = function() child.lua('_G.process_log = {}') end

-- Data =======================================================================
local test_items = { 'a_b_c', 'abc', 'a_b_b', 'c_a_a', 'b_c_c' }

local many_items = {}
for i = 1, 1000000 do
  many_items[3 * i - 2] = 'ab'
  many_items[3 * i - 1] = 'ac'
  many_items[3 * i] = 'bb'
end

-- Output test set ============================================================
local T = new_set({
  hooks = {
    pre_case = function()
      child.setup()

      -- Make more comfortable screenshots
      child.set_size(15, 40)
      child.o.laststatus = 0
      child.o.ruler = false

      load_module()

      -- Make border differentiable in screenshots
      child.cmd('hi MiniPickBorder ctermfg=2')
    end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  -- Global variable
  eq(child.lua_get('type(_G.MiniPick)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniPick'), 1)

  -- Highlight groups
  child.cmd('hi clear')
  load_module()
  local validate_hl_group = function(name, ref) expect.match(child.cmd_capture('hi ' .. name), ref) end

  -- - Make sure to clear highlight groups defined for better screenshots
  child.cmd('hi clear MiniPickBorder')
  load_module()

  validate_hl_group('MiniPickBorder', 'links to FloatBorder')
  validate_hl_group('MiniPickBorderBusy', 'links to DiagnosticFloatingWarn')
  validate_hl_group('MiniPickBorderText', 'links to FloatTitle')
  validate_hl_group('MiniPickIconDirectory', 'links to Directory')
  validate_hl_group('MiniPickIconFile', 'links to MiniPickNormal')
  validate_hl_group('MiniPickHeader', 'links to DiagnosticFloatingHint')
  validate_hl_group('MiniPickMatchCurrent', 'links to CursorLine')
  validate_hl_group('MiniPickMatchMarked', 'links to Visual')
  validate_hl_group('MiniPickMatchRanges', 'links to DiagnosticFloatingHint')
  validate_hl_group('MiniPickNormal', 'links to NormalFloat')
  validate_hl_group('MiniPickPreviewLine', 'links to CursorLine')
  validate_hl_group('MiniPickPreviewRegion', 'links to IncSearch')
  validate_hl_group('MiniPickPrompt', 'links to DiagnosticFloatingInfo')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniPick.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniPick.config.' .. field), value) end

  expect_config('delay.async', 10)
  expect_config('delay.busy', 50)

  expect_config('mappings.caret_left', '<Left>')
  expect_config('mappings.caret_right', '<Right>')
  expect_config('mappings.choose', '<CR>')
  expect_config('mappings.choose_in_split', '<C-s>')
  expect_config('mappings.choose_in_tabpage', '<C-t>')
  expect_config('mappings.choose_in_vsplit', '<C-v>')
  expect_config('mappings.choose_marked', '<M-CR>')
  expect_config('mappings.delete_char', '<BS>')
  expect_config('mappings.delete_char_right', '<Del>')
  expect_config('mappings.delete_left', '<C-u>')
  expect_config('mappings.delete_word', '<C-w>')
  expect_config('mappings.mark', '<C-x>')
  expect_config('mappings.mark_all', '<C-a>')
  expect_config('mappings.move_down', '<C-n>')
  expect_config('mappings.move_start', '<C-g>')
  expect_config('mappings.move_up', '<C-p>')
  expect_config('mappings.paste', '<C-r>')
  expect_config('mappings.refine', '<C-Space>')
  expect_config('mappings.refine_marked', '<M-Space>')
  expect_config('mappings.scroll_down', '<C-f>')
  expect_config('mappings.scroll_left', '<C-h>')
  expect_config('mappings.scroll_right', '<C-l>')
  expect_config('mappings.scroll_up', '<C-b>')
  expect_config('mappings.stop', '<Esc>')
  expect_config('mappings.toggle_info', '<S-Tab>')
  expect_config('mappings.toggle_preview', '<Tab>')

  expect_config('options.content_from_bottom', false)
  expect_config('options.use_cache', false)

  expect_config('source.items', vim.NIL)
  expect_config('source.name', vim.NIL)
  expect_config('source.cwd', vim.NIL)
  expect_config('source.match', vim.NIL)
  expect_config('source.show', vim.NIL)
  expect_config('source.preview', vim.NIL)
  expect_config('source.choose', vim.NIL)
  expect_config('source.choose_marked', vim.NIL)

  expect_config('window.config', vim.NIL)
  expect_config('window.prompt_cursor', '▏')
  expect_config('window.prompt_prefix', '> ')
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ options = { use_cache = true } })
  eq(child.lua_get('MiniPick.config.options.use_cache'), true)
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ delay = 'a' }, 'delay', 'table')
  expect_config_error({ delay = { async = 'a' } }, 'delay.async', 'number')
  expect_config_error({ delay = { busy = 'a' } }, 'delay.busy', 'number')

  expect_config_error({ mappings = 'a' }, 'mappings', 'table')
  expect_config_error({ mappings = { caret_left = 1 } }, 'mappings.caret_left', 'string')
  expect_config_error({ mappings = { caret_right = 1 } }, 'mappings.caret_right', 'string')
  expect_config_error({ mappings = { choose = 1 } }, 'mappings.choose', 'string')
  expect_config_error({ mappings = { choose_in_split = 1 } }, 'mappings.choose_in_split', 'string')
  expect_config_error({ mappings = { choose_in_tabpage = 1 } }, 'mappings.choose_in_tabpage', 'string')
  expect_config_error({ mappings = { choose_in_vsplit = 1 } }, 'mappings.choose_in_vsplit', 'string')
  expect_config_error({ mappings = { choose_marked = 1 } }, 'mappings.choose_marked', 'string')
  expect_config_error({ mappings = { delete_char = 1 } }, 'mappings.delete_char', 'string')
  expect_config_error({ mappings = { delete_char_right = 1 } }, 'mappings.delete_char_right', 'string')
  expect_config_error({ mappings = { delete_left = 1 } }, 'mappings.delete_left', 'string')
  expect_config_error({ mappings = { delete_word = 1 } }, 'mappings.delete_word', 'string')
  expect_config_error({ mappings = { mark = 1 } }, 'mappings.mark', 'string')
  expect_config_error({ mappings = { mark_all = 1 } }, 'mappings.mark_all', 'string')
  expect_config_error({ mappings = { move_down = 1 } }, 'mappings.move_down', 'string')
  expect_config_error({ mappings = { move_start = 1 } }, 'mappings.move_start', 'string')
  expect_config_error({ mappings = { move_up = 1 } }, 'mappings.move_up', 'string')
  expect_config_error({ mappings = { paste = 1 } }, 'mappings.paste', 'string')
  expect_config_error({ mappings = { refine = 1 } }, 'mappings.refine', 'string')
  expect_config_error({ mappings = { refine_marked = 1 } }, 'mappings.refine_marked', 'string')
  expect_config_error({ mappings = { scroll_down = 1 } }, 'mappings.scroll_down', 'string')
  expect_config_error({ mappings = { scroll_left = 1 } }, 'mappings.scroll_left', 'string')
  expect_config_error({ mappings = { scroll_right = 1 } }, 'mappings.scroll_right', 'string')
  expect_config_error({ mappings = { scroll_up = 1 } }, 'mappings.scroll_up', 'string')
  expect_config_error({ mappings = { stop = 1 } }, 'mappings.stop', 'string')
  expect_config_error({ mappings = { toggle_info = 1 } }, 'mappings.toggle_info', 'string')
  expect_config_error({ mappings = { toggle_preview = 1 } }, 'mappings.toggle_preview', 'string')

  expect_config_error({ options = 'a' }, 'options', 'table')
  expect_config_error({ options = { content_from_bottom = 1 } }, 'options.content_from_bottom', 'boolean')
  expect_config_error({ options = { use_cache = 1 } }, 'options.use_cache', 'boolean')

  expect_config_error({ source = 'a' }, 'source', 'table')
  expect_config_error({ source = { items = 1 } }, 'source.items', 'table')
  expect_config_error({ source = { name = 1 } }, 'source.name', 'string')
  expect_config_error({ source = { cwd = 1 } }, 'source.cwd', 'string')
  expect_config_error({ source = { match = 1 } }, 'source.match', 'function')
  expect_config_error({ source = { show = 1 } }, 'source.show', 'function')
  expect_config_error({ source = { preview = 1 } }, 'source.preview', 'function')
  expect_config_error({ source = { choose = 1 } }, 'source.choose', 'function')
  expect_config_error({ source = { choose_marked = 1 } }, 'source.choose_marked', 'function')

  expect_config_error({ window = 'a' }, 'window', 'table')
  expect_config_error({ window = { config = 1 } }, 'window.config', 'table or callable')
  expect_config_error({ window = { prompt_cursor = 1 } }, 'window.prompt_cursor', 'string')
  expect_config_error({ window = { prompt_prefix = 1 } }, 'window.prompt_prefix', 'string')
end

-- This set mostly contains general function testing which doesn't fit into
-- more specialized integration tests later
T['start()'] = new_set()

T['start()']['works'] = function()
  child.lua_notify('_G.picked_item = MiniPick.start(...)', { { source = { items = test_items } } })
  child.expect_screenshot()

  -- Should focus on floating window
  eq(child.api.nvim_get_current_win(), get_picker_state().windows.main)

  -- Should close window after an item and print it (as per `default_choose()`)
  type_keys('<CR>')
  child.expect_screenshot()

  -- Should return picked value
  eq(child.lua_get('_G.picked_item'), test_items[1])
end

T['start()']['returns `nil` when there is no current match'] = function()
  child.lua_notify('_G.picked_item = MiniPick.start(...)', { { source = { items = test_items } } })
  type_keys('x')
  type_keys('<CR>')
  eq(child.lua_get('_G.picked_item'), vim.NIL)
end

T['start()']['works with window footer'] = function()
  -- TODO: Use this as primary test after support for Neovim<=0.9 is dropped
  if not child.has_float_footer() then return end

  child.lua_notify('_G.picked_item = MiniPick.start(...)', { { source = { items = test_items } } })
  child.expect_screenshot_orig()

  eq(child.api.nvim_get_current_win(), get_picker_state().windows.main)
  type_keys('<CR>')
  child.expect_screenshot_orig()
  eq(child.lua_get('_G.picked_item'), test_items[1])
end

T['start()']['works on Neovim<0.9'] = function()
  if child.fn.has('nvim-0.9') == 1 then return end

  child.lua_notify('_G.picked_item = MiniPick.start(...)', { { source = { items = test_items } } })
  child.expect_screenshot_orig()

  -- Should focus on floating window
  eq(child.api.nvim_get_current_win(), get_picker_state().windows.main)

  -- Should close window after an item and print it (as per `default_choose()`)
  type_keys('<CR>')
  child.expect_screenshot_orig()

  -- Should return picked value
  eq(child.lua_get('_G.picked_item'), test_items[1])
end

T['start()']['can be started without explicit items'] = function()
  child.lua_notify('_G.picked_item = MiniPick.start()')
  child.expect_screenshot()
  type_keys('<CR>')
  eq(child.lua_get('_G.picked_item'), vim.NIL)
end

T['start()']['creates proper window'] = function()
  start_with_items(test_items)
  local win_id = get_picker_state().windows.main
  eq(child.api.nvim_win_is_valid(win_id), true)

  local win_config = child.api.nvim_win_get_config(win_id)
  eq(win_config.relative, 'editor')
  eq(win_config.focusable, true)

  validate_win_option(win_id, 'list', true)
  validate_win_option(win_id, 'listchars', 'extends:…')
  validate_win_option(win_id, 'wrap', false)
end

T['start()']['creates proper main buffer'] = function()
  start_with_items(test_items)
  local buf_id = get_picker_state().buffers.main
  eq(child.api.nvim_buf_is_valid(buf_id), true)
  validate_buf_option(buf_id, 'filetype', 'minipick')
  validate_buf_option(buf_id, 'buflisted', false)
  validate_buf_option(buf_id, 'buftype', 'nofile')
end

T['start()']['tracks lost focus'] = function()
  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b' } },
    mappings = { error = { char = 'e', func = function() error() end } },
  })]])
  child.expect_screenshot()
  type_keys('e')
  -- By default it checks inside a timer with 1 second period
  sleep(1000 + 50)
  child.expect_screenshot()
end

T['start()']['validates `opts`'] = function()
  local validate = function(opts, error_pattern)
    expect.error(function() child.lua('MiniPick.start(...)', { opts }) end, error_pattern)
  end

  validate(1, 'Picker options.*table')

  validate({ delay = { async = 'a' } }, '`delay.async`.*number')
  validate({ delay = { async = 0 } }, '`delay.async`.*positive')
  validate({ delay = { busy = 'a' } }, '`delay.busy`.*number')
  validate({ delay = { busy = 0 } }, '`delay.busy`.*positive')

  validate({ options = { content_from_bottom = 1 } }, '`options%.content_from_bottom`.*boolean')
  validate({ options = { use_cache = 1 } }, '`options%.use_cache`.*boolean')

  validate({ mappings = { [1] = '<C-f>' } }, '`mappings`.*only string fields')
  validate({ mappings = { choose = 1 } }, 'Mapping for built%-in action "choose".*string')
  expect.error(
    function() child.lua('MiniPick.start({ mappings = { choose = { char = "a", func = function() end } } })') end,
    'built%-in action.*string'
  )
  validate(
    { mappings = { ['Custom action'] = 1 } },
    'Mapping for custom action "Custom action".*table with `char` and `func`'
  )

  validate({ source = { items = 1 } }, '`source%.items`.*array or callable')
  validate({ source = { cwd = 1 } }, '`source%.cwd`.*valid directory path')
  validate({ source = { cwd = 'not-existing-path' } }, '`source%.cwd`.*valid directory path')
  validate({ source = { match = 1 } }, '`source%.match`.*callable')
  validate({ source = { show = 1 } }, '`source%.show`.*callable')
  validate({ source = { preview = 1 } }, '`source%.preview`.*callable')
  validate({ source = { choose = 1 } }, '`source%.choose`.*callable')
  validate({ source = { choose_marked = 1 } }, '`source%.choose_marked`.*callable')

  validate({ window = { config = 1 } }, '`window%.config`.*table or callable')
end

T['start()']['respects `source.items`'] = function()
  -- Array
  start_with_items({ 'a', 'b' })
  child.expect_screenshot()
  stop()

  -- Callable returning array of items
  child.lua([[_G.items_callable_return = function() return { 'c', 'd' } end]])
  child.lua_notify('MiniPick.start({ source = { items = _G.items_callable_return } })')
  child.expect_screenshot()
  stop()

  -- Callable setting items manually
  child.lua([[_G.items_callable_later = function() MiniPick.set_picker_items({ 'e', 'f' }) end]])
  child.lua_notify('MiniPick.start({ source = { items = _G.items_callable_later } })')
  poke_eventloop()
  child.expect_screenshot()
  stop()

  -- Callable setting items manually *later*
  child.lua([[_G.items_callable_later = function()
    vim.schedule(function() MiniPick.set_picker_items({ 'g', 'h' }) end)
  end]])
  child.lua_notify('MiniPick.start({ source = { items = _G.items_callable_later } })')
  poke_eventloop()
  child.expect_screenshot()
  stop()
end

T['start()']['correctly computes stritems'] = function()
  child.set_size(15, 80)
  child.lua_notify([[MiniPick.start({ source = { items = {
    'string_item',
    { text = 'table_item' },
    { a = 'fallback item', b = 1 },
    function() return 'string_item_from_callable' end,
    function() return { text = 'table_item_from_callable' } end,
    function() return { c = 'fallback item from callable', d = 1 } end,
  } } })]])
  child.expect_screenshot()
end

T['start()']['resolves items after making picker active'] = function()
  child.lua_notify([[MiniPick.start({ source = {
    items = function()
      _G.picker_is_active = MiniPick.is_picker_active()
      _G.picker_name = MiniPick.get_picker_opts().source.name
      return { 'a', 'b' }
    end,
    name = 'This picker'
  } })]])
  eq(get_picker_stritems(), { 'a', 'b' })
  eq(child.lua_get('_G.picker_is_active'), true)
  eq(child.lua_get('_G.picker_name'), 'This picker')
end

T['start()']['respects `source.name`'] = function()
  start({ source = { items = test_items, name = 'Hello' } })
  validate_picker_option('source.name', 'Hello')
  if child.has_float_footer() then child.expect_screenshot_orig() end
end

T['start()']['respects `source.cwd`'] = function()
  local lua_cmd = string.format(
    [[MiniPick.start({ source = {
      items = function() return { MiniPick.get_picker_opts().source.cwd } end,
      cwd = %s,
    } })]],
    vim.inspect(test_dir)
  )
  child.lua_notify(lua_cmd)
  local actual_cwd = get_picker_stritems()[1]
  eq(actual_cwd, full_path(test_dir))
  eq(actual_cwd:find('/$'), nil)
end

T['start()']['respects `source.match`'] = function()
  child.lua_notify([[MiniPick.start({ source = {
    items = { 'a', 'b', 'c' },
    match = function(...)
      _G.match_args = { ... }
      return { 2 }
    end,
  } })]])

  child.expect_screenshot()
  eq(get_picker_matches().all, { 'b' })
  eq(child.lua_get('_G.match_args'), { { 'a', 'b', 'c' }, { 1, 2, 3 }, {} })

  type_keys('x')
  eq(get_picker_matches().all, { 'b' })
  eq(child.lua_get('_G.match_args'), { { 'a', 'b', 'c' }, { 2 }, { 'x' } })
end

T['start()']['respects `source.show`'] = function()
  child.lua_notify([[MiniPick.start({ source = {
    items = { 'a', { text = 'b' }, 'bb' },
    show = function(buf_id, items_to_show, query, ...)
      _G.show_args = { buf_id, items_to_show, query, ... }
      local lines = vim.tbl_map(
        function(x) return '__' .. (type(x) == 'table' and x.text or x) end,
        items_to_show
      )
      vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    end,
  } })]])
  local buf_id = get_picker_state().buffers.main

  child.expect_screenshot()
  eq(child.lua_get('_G.show_args'), { buf_id, { 'a', { text = 'b' }, 'bb' }, {} })

  type_keys('b')
  child.expect_screenshot()
  eq(child.lua_get('_G.show_args'), { buf_id, { { text = 'b' }, 'bb' }, { 'b' } })
end

T['start()']['respects `source.preview`'] = function()
  child.lua_notify([[MiniPick.start({ source = {
    items = { 'a', { text = 'b' }, 'bb' },
    preview = function(buf_id, item, ...)
      _G.preview_args = { buf_id, item, ... }
      local stritem = type(item) == 'table' and item.text or item
      vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { 'Preview: ' .. stritem })
    end,
  } })]])
  local validate_preview_args = function(item_ref)
    local preview_args = child.lua_get('_G.preview_args')
    eq(child.api.nvim_buf_is_valid(preview_args[1]), true)
    eq(preview_args[2], item_ref)
  end

  type_keys('<Tab>')

  child.expect_screenshot()
  validate_preview_args('a')
  local preview_buf_id_1 = child.lua_get('_G.preview_args')[1]

  type_keys('<C-n>')
  child.expect_screenshot()
  validate_preview_args({ text = 'b' })
  eq(preview_buf_id_1 ~= child.lua_get('_G.preview_args')[1], true)
end

T['start()']['respects `source.choose`'] = function()
  child.lua_notify([[MiniPick.start({ source = {
    items = { 'a', { text = 'b' }, 'bb' },
    choose = function(...) _G.choose_args = { ... } end,
  } })]])

  type_keys('<C-n>', '<CR>')
  eq(child.lua_get('_G.choose_args'), { { text = 'b' } })
  eq(is_picker_active(), false)
end

T['start()']['respects `source.choose_marked`'] = function()
  child.lua_notify([[MiniPick.start({ source = {
    items = { 'a', { text = 'b' }, 'bb' },
    choose_marked = function(...) _G.choose_marked_args = { ... } end,
  } })]])

  type_keys('<C-x>', '<C-n>', '<C-x>', '<M-CR>')
  eq(child.lua_get('_G.choose_marked_args'), { { 'a', { text = 'b' } } })
  eq(is_picker_active(), false)
end

T['start()']['respects `delay.async`'] = function()
  child.set_size(15, 15)
  child.lua_notify([[
    _G.buf_id, _G.n = vim.api.nvim_get_current_buf(), 0
    local timer = vim.loop.new_timer()
    local f = vim.schedule_wrap(function()
      _G.n = _G.n + 1
      vim.fn.appendbufline(_G.buf_id, '$', { 'Line ' .. _G.n })
    end)
    timer:start(50, 50, f)
  ]])
  local validate = function(n, lines)
    eq(child.lua_get('_G.n'), n)
    eq(child.lua_get('vim.api.nvim_buf_get_lines(_G.buf_id, 0, -1, false)'), lines)
    child.expect_screenshot({ redraw = false })
  end

  child.lua_notify([[MiniPick.start({ source = { items = { 'a' } }, delay = { async = 80 } })]])
  validate(0, { '' })

  -- Callback should have already been executed, but not redraw
  sleep(50 + 5)
  validate(1, { '', 'Line 1' })

  -- No new callback should have been executed, but redraw should
  sleep(30)
  validate(1, { '', 'Line 1' })

  -- Test that redraw is done repeatedly
  sleep(80)
  validate(3, { '', 'Line 1', 'Line 2', 'Line 3' })
end

T['start()']['respects `delay.busy`'] = function()
  local validate = function(is_busy)
    local win_id = get_picker_state().windows.main
    local ref_winhl = 'FloatBorder:MiniPickBorder' .. (is_busy and 'Busy' or '')
    expect.match(child.api.nvim_win_get_option(win_id, 'winhighlight'), ref_winhl)
  end

  local new_busy_delay = math.floor(0.5 * child.lua_get('MiniPick.config.delay.busy'))
  child.lua_notify(string.format('MiniPick.start({ delay = { busy = %d } })', new_busy_delay))

  validate(false)
  sleep(new_busy_delay + 10)
  validate(true)
end

T['start()']['respects `mappings`'] = function()
  start({ source = { items = { 'a', 'b' } }, mappings = { stop = 'c' } })
  eq(is_picker_active(), true)
  type_keys('a')
  eq(is_picker_active(), true)
  type_keys('c')
  eq(is_picker_active(), false)
end

T['start()']['respects `options.content_from_bottom`'] = function()
  start({ source = { items = { 'a', 'b' } }, options = { content_from_bottom = true } })
  child.expect_screenshot()
end

T['start()']['respects `options.use_cache`'] = function()
  local validate_match_calls = make_match_with_count()
  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b', 'bb' }, match = _G.match_with_count },
    options = { use_cache = true },
  })]])
  validate_match_calls(0, { 1, 2, 3 })

  type_keys('b')
  validate_match_calls(1, { 2, 3 })

  type_keys('b')
  validate_match_calls(2, { 3 })

  type_keys('<BS>')
  validate_match_calls(2, { 2, 3 })

  type_keys('<BS>')
  validate_match_calls(2, { 1, 2, 3 })

  type_keys('b')
  validate_match_calls(2, { 2, 3 })

  type_keys('x')
  validate_match_calls(3, {})
end

T['start()']['allows custom mappings'] = function()
  -- Both in global and local config
  child.lua([[MiniPick.config.mappings.custom_global = {
    char = '<C-d>',
    func = function(...) _G.args_global = { ... } end,
  }]])

  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b' } },
    mappings = {
      -- Return value is treated as "should stop picker after execution"
      custom = { char = 'm', func = function(...) _G.args_local = { ... }; return true end },
    },
  })]])

  type_keys('<C-d>')
  eq(child.lua_get('_G.args_global'), {})
  eq(is_picker_active(), true)

  type_keys('m')
  eq(child.lua_get('_G.args_local'), {})
  eq(is_picker_active(), false)
end

T['start()']['allows overriding built-in mappings'] = function()
  -- Both in global/local config **but** only as strings
  child.lua([[MiniPick.config.mappings.caret_left = '<C-e>']])

  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b' } },
    mappings = { caret_right = 'm' },
  })]])

  type_keys('a')
  eq(get_picker_state().caret, 2)
  type_keys('<C-e>')
  eq(get_picker_state().caret, 1)
  type_keys('m')
  eq(get_picker_state().caret, 2)
end

T['start()']['respects `window.config`'] = function()
  -- As table
  start({ source = { items = { 'a', 'b', 'c' } }, window = { config = { border = 'double' } } })
  child.expect_screenshot()
  stop()

  -- As callable
  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b', 'c' } },
    window = { config = function() return { anchor = 'NW', row = 2, width = vim.o.columns } end },
  })]])
  child.expect_screenshot()
  stop()
end

T['start()']['respects `window.prompt_cursor`'] = function()
  start({ source = { items = { 'a', 'b', 'c' } }, window = { prompt_cursor = '+' } })
  child.expect_screenshot()
  type_keys('a', 'b', '<Left>')
  child.expect_screenshot()
end

T['start()']['respects `window.prompt_prefix`'] = function()
  start({ source = { items = { 'a', 'b', 'c' } }, window = { prompt_prefix = '$>  ' } })
  child.expect_screenshot()
  type_keys('a', 'b', '<Left>')
  child.expect_screenshot()
end

T['start()']['stops currently active picker'] = function()
  start_with_items({ 'a', 'b', 'c' })
  eq(is_picker_active(), true)
  start_with_items({ 'd', 'e', 'f' })
  sleep(2)
  child.expect_screenshot()
end

T['start()']['stops impoperly aborted previous picker'] = function()
  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b', 'c' } },
    mappings = { error = { char = 'e', func = function() error() end } },
  })]])
  child.expect_screenshot()
  type_keys('e')

  start({ source = { items = { 'd', 'e', 'f' } }, window = { config = { width = 10 } } })
  child.expect_screenshot()
end

T['start()']['triggers `MiniPickStart` User event'] = function()
  make_event_log()
  child.cmd('au User MiniPickStart lua _G.track_event()')
  start_with_items(test_items)

  -- User event should be triggered when all elements are usually set
  eq(child.lua_get('_G.event_log'), { #test_items })
end

T['start()']['can be called in non-Normal modes'] = function()
  child.lua('_G.choose = function() vim.schedule(function() _G.cur_mode = vim.fn.mode(1) end) end')
  local validate = function()
    local cur_mode = child.fn.mode(1)
    eq(cur_mode ~= 'n', true)
    child.lua_notify([[MiniPick.start({ source = { items = { 'a' }, choose = _G.choose } })]])
    type_keys('<CR>')
    eq(child.lua_get('_G.cur_mode'), cur_mode)

    -- Cleanup
    child.lua('_G.cur_mode = nil')
  end

  -- Insert mode
  type_keys('i')
  validate()
  child.ensure_normal_mode()

  -- Command mode
  type_keys(':')
  validate()
  child.ensure_normal_mode()

  -- Operator-pending mode
  type_keys('d')
  validate()
  child.ensure_normal_mode()

  -- Doesn't work in Visual mode as opening floating window stops it.
  -- Use `gv` in picker if want to preserve Visual mode.
end

T['start()']['respects global config'] = function()
  child.lua([[MiniPick.config.window.config = { anchor = 'NW', row = 1 }]])
  start_with_items({ 'a', 'b', 'c' })
  child.expect_screenshot()
end

T['start()']['respects `vim.b.minipick_config`'] = function()
  child.lua([[MiniPick.config.window.config = { anchor = 'NW', row = 1 }]])
  child.b.minipick_config = { window = { config = { row = 3, width = 10 } } }
  start_with_items({ 'a', 'b', 'c' })
  child.expect_screenshot()
end

T['stop()'] = new_set()

T['stop()']['works'] = function()
  start_with_items(test_items)
  child.expect_screenshot()
  stop()
  child.expect_screenshot()
  eq(is_picker_active(), false)
end

T['stop()']['can be called without active picker'] = function() expect.no_error(stop) end

T['stop()']['triggers `MiniPickStop` User event'] = function()
  make_event_log()
  child.cmd('au User MiniPickStop lua _G.track_event()')
  start_with_items(test_items)
  stop()
  -- User event should be triggered while buffer is still valid
  eq(child.lua_get('_G.event_log'), { #test_items })
end

T['refresh()'] = new_set()

local refresh = forward_lua('MiniPick.refresh')

T['refresh()']['works'] = function()
  start_with_items(test_items)
  child.expect_screenshot()

  child.lua('MiniPick.set_picker_opts({ window = { config = { width = 10 } } })')
  refresh()
  child.expect_screenshot()
end

T['refresh()']['is called on `VimResized`'] = function()
  child.set_size(15, 40)
  start_with_items(test_items)
  child.expect_screenshot()

  child.set_size(15, 20)
  child.expect_screenshot()
end

T['refresh()']['can be called without active picker'] = function() expect.no_error(refresh) end

T['refresh()']['recomputes window config'] = function()
  child.lua([[
    _G.width = 0
    _G.win_config = function()
      _G.width = _G.width + 10
      return { width = _G.width }
    end
  ]])

  child.lua_notify([[MiniPick.start({ source = { items = { 'a', 'b', 'c' } }, window = { config = _G.win_config } })]])
  child.expect_screenshot()
  refresh()
  child.expect_screenshot()
end

T['default_match()'] = new_set()

local default_match = forward_lua('MiniPick.default_match')

local validate_match = function(stritems, query, output_ref)
  eq(default_match(stritems, seq_along(stritems), query), output_ref)
end

T['default_match()']['works with active picker'] = function()
  start_with_items(test_items)
  type_keys('a')
  child.expect_screenshot()
  type_keys('b')
  child.expect_screenshot()
end

T['default_match()']['does not block query update'] = function()
  child.lua([[
    _G.log = {}
    _G.default_match_wrapper = function(stritems, inds, query)
      table.insert(_G.log, { n_match_inds = #inds, query = vim.deepcopy(query) })
      MiniPick.default_match(stritems, inds, query)
    end
  ]])
  child.lua_notify('MiniPick.start({ source = { match = _G.default_match_wrapper }, delay = { async = 1 } })')

  -- Set many items and wait until it completely sets
  set_picker_items(many_items)
  for i = 1, 50 do
    sleep(100)
    if child.lua_get([[type(MiniPick.get_picker_items()) == 'table']]) then break end
  end

  -- Type three characters very quickly. If `default_match()` were blocking,
  -- each press would lead to calling `source.match` with the result of
  -- matching on prior query. In this test every key press should interrupt
  -- currently active matching and start a new one with the latest available
  -- set of `match_inds` (which should be all inds as match is, hopefully,
  -- never finishes).
  type_keys('a')
  sleep(1)
  type_keys('b')
  sleep(1)
  type_keys('c')
  sleep(1)
  child.expect_screenshot()
  eq(child.lua_get('_G.log'), {
    { n_match_inds = #many_items, query = {} },
    { n_match_inds = #many_items, query = { 'a' } },
    { n_match_inds = #many_items, query = { 'a', 'b' } },
    { n_match_inds = #many_items, query = { 'a', 'b', 'c' } },
  })
end

T['default_match()']['works without active picker'] = function()
  local stritems, query = { 'aab', 'ac', 'ab' }, { 'a', 'b' }
  eq(default_match(stritems, { 1, 2, 3 }, query), { 3, 1 })
  eq(default_match(stritems, { 2, 3 }, query), { 3 })
end

T['default_match()']['works with empty inputs'] = function()
  local match_inds, stritems, query = seq_along(test_items), { 'ab', 'cd' }, { 'a' }
  eq(default_match(stritems, {}, query), {})
  eq(default_match({}, {}, query), {})
  eq(default_match(stritems, match_inds, {}), seq_along(stritems))
end

T['default_match()']['filters items that match query with gaps'] = function()
  -- Regular cases
  validate_match({ 'a__', 'b' }, { 'a' }, { 1 })
  validate_match({ '_a_', 'b' }, { 'a' }, { 1 })
  validate_match({ '__a', 'b' }, { 'a' }, { 1 })
  validate_match({ 'b', 'a__' }, { 'a' }, { 2 })
  validate_match({ 'b', '_a_' }, { 'a' }, { 2 })
  validate_match({ 'b', '__a' }, { 'a' }, { 2 })

  validate_match({ 'a', 'ab', 'a_b', 'a_b_b', 'ba' }, { 'a', 'b' }, { 2, 3, 4 })
  validate_match({ 'a', 'ab', 'a_b', 'a_b_b', 'ba' }, { 'a', 'b', 'b' }, { 4 })

  validate_match({ 'a', 'ab', 'axb', 'a?b', 'a\tb' }, { 'a', 'b' }, { 2, 3, 4, 5 })

  -- Non-single-char-entries queries (each should match exactly)
  validate_match({ 'a', 'b', 'ab_', 'a_b', '_ab' }, { 'ab' }, { 3, 5 })
  validate_match({ 'abcd_', '_abcd', 'a_bcd', 'ab_cd', 'abc_d' }, { 'ab', 'cd' }, { 1, 2, 4 })

  -- Edge casees
  validate_match({ 'a', 'b', '' }, { 'a' }, { 1 })

  validate_match({ 'a', 'b', '' }, { '' }, { 1, 2, 3 })
  validate_match({ 'a', 'b', '' }, { '', '' }, { 1, 2, 3 })
end

T['default_match()']['sorts by match width -> match start -> item index'] = function()
  local query_ab, query_abc = { 'a', 'b' }, { 'a', 'b', 'c' }

  -- Width differs
  validate_match({ 'ab', 'a_b', 'a__b' }, query_ab, { 1, 2, 3 })
  validate_match({ 'ab', 'a__b', 'a_b' }, query_ab, { 1, 3, 2 })
  validate_match({ 'a__b', 'ab', 'a_b' }, query_ab, { 2, 3, 1 })
  validate_match({ 'a_b', 'ab', 'a__b' }, query_ab, { 2, 1, 3 })
  validate_match({ 'a_b', 'a__b', 'ab' }, query_ab, { 3, 1, 2 })
  validate_match({ 'a__b', 'a_b', 'ab' }, query_ab, { 3, 2, 1 })

  validate_match({ '_a__b', '_a_b', '_ab' }, query_ab, { 3, 2, 1 })

  validate_match({ 'a__b_a___b', 'a_b_a___b', 'ab_a___b' }, query_ab, { 3, 2, 1 })

  validate_match({ 'a_b_c', 'a_bc', 'abc' }, query_abc, { 3, 2, 1 })
  validate_match({ '_a_b_c', '_a_bc', '_abc' }, query_abc, { 3, 2, 1 })
  validate_match({ 'a_b_c_a__b__c', 'a_bc_a__b__c', 'abc_a__b__c' }, query_abc, { 3, 2, 1 })

  validate_match({ 'ab__cd', 'ab_cd', 'abcd' }, { 'ab', 'cd' }, { 3, 2, 1 })

  -- Start differs with equal width
  validate_match({ 'ab', '_ab', '__ab' }, query_ab, { 1, 2, 3 })
  validate_match({ 'ab', '__ab', '_ab' }, query_ab, { 1, 3, 2 })
  validate_match({ '_ab', 'ab', '__ab' }, query_ab, { 2, 1, 3 })
  validate_match({ '__ab', 'ab', '_ab' }, query_ab, { 2, 3, 1 })
  validate_match({ '_ab', '__ab', 'ab' }, query_ab, { 3, 1, 2 })
  validate_match({ '__ab', '_ab', 'ab' }, query_ab, { 3, 2, 1 })

  validate_match({ '__abc', '_abc', 'abc' }, query_abc, { 3, 2, 1 })

  validate_match({ '__abc_a_b_c', '_abc_a_b_c', 'abc_a_b_c' }, query_abc, { 3, 2, 1 })
  validate_match({ 'a_b_c__abc', 'a_b_c_abc', 'a_b_cabc' }, query_abc, { 3, 2, 1 })

  validate_match({ '__a_b_c', '_a__bc', 'ab__c' }, query_abc, { 3, 2, 1 })

  validate_match({ '__ab_cd_e', '_ab__cde', 'abcd__e' }, { 'ab', 'cd', 'e' }, { 3, 2, 1 })

  -- Index differs with equal width and start
  validate_match({ 'a_b_c', 'a__bc', 'ab__c' }, query_abc, { 1, 2, 3 })
  validate_match({ 'axbxc', 'a??bc', 'ab\t\tc' }, query_abc, { 1, 2, 3 })

  validate_match({ 'ab_cd_e', 'ab__cde', 'abcd__e' }, { 'ab', 'cd', 'e' }, { 1, 2, 3 })
end

T['default_match()']['filters and sorts'] = function()
  validate_match({ 'a_b_c', 'abc', 'a_b_b', 'c_a_a', 'b_c_c' }, { 'a', 'b' }, { 2, 1, 3 })
  validate_match({ 'xabcd', 'axbcd', 'abxcd', 'abcxd', 'abcdx' }, { 'ab', 'cd' }, { 5, 1, 3 })
end

T['default_match()']['respects special queries'] = function()
  --stylua: ignore
  local stritems = {
    '*abc',    -- 1
    '_*_a_bc', -- 2
    "'abc",    -- 3
    "_'_a_bc", -- 4
    '^abc',    -- 5
    '_^_a_bc', -- 6
    'abc$',    -- 7
    'ab_c_$_', -- 8
    'a b c',   -- 9
    ' a  bc',  -- 10
  }
  local all_inds = seq_along(stritems)
  local validate = function(query, output_ref) validate_match(stritems, query, output_ref) end
  local validate_same_as = function(query, query_ref)
    eq(default_match(stritems, all_inds, query), default_match(stritems, all_inds, query_ref))
  end

  -- Precedence:
  -- "forced fuzzy" = "forced exact" > "exact start/end" > "grouped fuzzy"

  -- Forced fuzzy
  validate_same_as({ '*' }, { '' })
  validate_same_as({ '*', 'a' }, { 'a' })
  validate_same_as({ '*', 'a', 'b' }, { 'a', 'b' })

  validate({ '*', '*', 'a' }, { 1, 2 })
  validate({ '*', "'", 'a' }, { 3, 4 })
  validate({ '*', '^', 'a' }, { 5, 6 })
  validate({ '*', 'a', '$' }, { 7, 8 })
  validate({ '*', 'a', ' ', 'b' }, { 9, 10 })

  -- Forced exact
  validate_same_as({ "'" }, { '' })
  validate_same_as({ "'", 'a' }, { 'a' })
  validate_same_as({ "'", 'a', 'b' }, { 'ab' })

  validate({ "'", '*', 'a' }, { 1 })
  validate({ "'", "'", 'a' }, { 3 })
  validate({ "'", '^', 'a' }, { 5 })
  validate({ "'", 'c', '$' }, { 7 })
  validate({ "'", 'a', ' ', 'b' }, { 9 })

  -- Exact start
  validate_same_as({ '^' }, { '' })
  validate({ '^', 'a' }, { 7, 8, 9 })
  validate({ '^', 'a', 'b' }, { 7, 8 })

  validate({ '^', '^', 'a' }, { 5 })
  validate({ '^', "'", 'a' }, { 3 })
  validate({ '^', '*', 'a' }, { 1 })
  validate({ '^', ' ', 'a' }, { 10 })

  -- Exact end
  validate({ '$' }, all_inds)
  validate({ 'c', '$' }, { 1, 3, 5, 9, 10, 2, 4, 6 })
  validate({ 'b', 'c', '$' }, { 1, 3, 5, 10, 2, 4, 6 })

  validate({ ' ', 'c', '$' }, { 9 })

  -- Grouped
  validate_same_as({ 'a', ' ' }, { 'a' })
  validate_same_as({ 'a', ' ', ' ' }, { 'a' })
  validate_same_as({ 'a', ' ', 'b' }, { 'a', 'b' })
  validate_same_as({ 'a', ' ', ' ', 'b' }, { 'a', 'b' })
  validate_same_as({ 'a', ' ', 'b', ' ' }, { 'a', 'b' })
  validate_same_as({ 'a', ' ', 'b', ' ', 'c' }, { 'a', 'b', 'c' })
  validate_same_as({ 'a', ' ', 'b', ' ', ' ', 'c' }, { 'a', 'b', 'c' })
  validate_same_as({ 'a', ' ', 'b', ' ', 'c', ' ' }, { 'a', 'b', 'c' })

  validate({ 'a', 'b', ' ', 'c' }, { 7, 1, 3, 5, 8 })
  validate({ 'a', ' ', 'b', 'c' }, { 7, 1, 3, 5, 2, 4, 6, 10 })
  validate({ 'a', 'b', 'c', ' ' }, { 7, 1, 3, 5 })

  validate({ 'ab', ' ', 'c' }, { 7, 1, 3, 5, 8 })

  -- - Whitespace inside non-whitespace elements shouldn't matter
  validate({ 'a b', ' ', 'c' }, { 9 })

  -- - Amount and type of whitespace inside "split" elements shouldn't matter
  validate_same_as({ 'ab', '  ', 'c' }, { 'ab', ' ', 'c' })
  validate_same_as({ 'ab', '\t', 'c' }, { 'ab', ' ', 'c' })

  -- - Only whitespace is allowed
  validate_same_as({ ' ' }, { '' })
  validate_same_as({ ' ', ' ' }, { '' })

  -- Combination
  validate_same_as({ '^', '$' }, { '' })
  validate({ '^', 'a', ' ', 'b', ' ', 'c', '$' }, { 9 })

  -- Not special
  validate({ 'a', '*' }, {})
  validate({ 'a', "'" }, {})
  validate({ 'a', '^' }, {})
  validate({ '$', 'a' }, {})
end

T['default_match()']['only input indexes can be in the output'] = function()
  eq(default_match({ 'a', '_a', '__a', 'b' }, { 1, 2, 4 }, { 'a' }), { 1, 2 })

  -- Special modes
  eq(default_match({ 'a', '_a', '__a', 'b' }, { 1, 2, 4 }, { "'", 'a' }), { 1, 2 })
  eq(default_match({ 'a', '_a', '__a', 'b' }, { 1, 2, 4 }, { '*', 'a' }), { 1, 2 })
  eq(default_match({ 'a', 'a_', 'a__', 'b' }, { 1, 2, 4 }, { '^', 'a' }), { 1, 2 })
  eq(default_match({ 'a', '_a', '__a', 'b' }, { 1, 2, 4 }, { 'a', '$' }), { 1, 2 })

  eq(default_match({ 'abc', 'ab_c', 'ab__c', 'a_b_c' }, { 1, 2, 4 }, { 'a', 'b', ' ', 'c' }), { 1, 2 })
end

T['default_match()']['works with multibyte characters'] = function()
  -- In query
  validate_match({ 'ы', 'ф', 'd' }, { 'ы' }, { 1 })

  validate_match({ 'ы__ф', 'ы_ф', 'ыф', 'ы', 'фы' }, { 'ы', 'ф' }, { 3, 2, 1 })
  validate_match({ '__ыф', '_ыф', 'ыф' }, { 'ы', 'ф' }, { 3, 2, 1 })
  validate_match({ '__ы_ф_я', '__ы__фя', '__ыф__я' }, { 'ы', 'ф', 'я' }, { 1, 2, 3 })

  validate_match({ 'ы_ф', '_ыф', 'ы' }, { '*', 'ы', 'ф' }, { 2, 1 })
  validate_match({ 'ы_ф', '_ыф', 'ы' }, { "'", 'ы', 'ф' }, { 2 })
  validate_match({ 'ы_ф', '_ыф', 'ы' }, { '^', 'ы' }, { 1, 3 })
  validate_match({ 'ы_ф', '_ыф', 'ы' }, { 'ф', '$' }, { 1, 2 })
  validate_match({ 'ыы_ф', 'ы_ыф' }, { 'ы', 'ы', ' ', 'ф' }, { 1 })

  validate_match({ '_│_│', '│_│_', '_│_' }, { '│', '│' }, { 2, 1 })

  validate_match({ 'ыdф', '_ы_d_ф' }, { 'ы', 'd', 'ф' }, { 1, 2 })

  -- In stritems
  validate_match({ 'aыbыc', 'abыc' }, { 'a', 'b', 'c' }, { 2, 1 })
end

T['default_match()']['works with special characters'] = function()
  -- function() validate_match('(.+*%-)', 'a(a.a+a*a%a-a)', { 2, 4, 6, 8, 10, 12, 14 }) end
  local validate_match_special_char = function(char)
    local stritems = { 'a' .. char .. 'b', 'a_b' }
    validate_match(stritems, { char }, { 1 })
    validate_match(stritems, { 'a', char, 'b' }, { 1 })
  end

  validate_match_special_char('.')
  validate_match_special_char('+')
  validate_match_special_char('%')
  validate_match_special_char('-')
  validate_match_special_char('(')
  validate_match_special_char(')')

  validate_match({ 'a*b', 'a_b' }, { 'a', '*', 'b' }, { 1 })
  validate_match({ 'a^b', 'a_b' }, { 'a', '^', 'b' }, { 1 })
  validate_match({ 'a$b', 'a_b' }, { 'a', '$', 'b' }, { 1 })
end

T['default_match()']['respects case'] = function()
  -- Ignore and smart case should come from how picker uses `source.match`
  validate_match({ 'ab', 'aB', 'Ba', 'AB' }, { 'a', 'b' }, { 1 })
  validate_match({ 'ab', 'aB', 'Ba', 'AB' }, { 'a', 'B' }, { 2 })
end

T['default_match()']['respects `do_sync` argument'] = function()
  start_with_items({ 'aa', 'ab', 'bb' })
  -- Should process synchronously and return output even if picker is active
  eq(child.lua_get([[MiniPick.default_match({'xx', 'xy', 'yy'}, { 1, 2, 3 }, { 'y' }, true)]]), { 3, 2 })
  eq(get_picker_matches().all, { 'aa', 'ab', 'bb' })
end

T['default_show()'] = new_set({ hooks = { pre_case = function() child.set_size(10, 20) end } })

local default_show = forward_lua('MiniPick.default_show')

T['default_show()']['works'] = function()
  child.set_size(15, 40)
  start_with_items({ 'abc', 'a_bc', 'a__bc' })
  type_keys('a', 'b')
  child.expect_screenshot()
end

T['default_show()']['works without active picker'] = function()
  -- Allows 0 buffer id for current buffer
  default_show(0, { 'abc', 'a_bc', 'a__bc' }, { 'a', 'b' })
  child.expect_screenshot()

  -- Allows non-current buffer
  local new_buf_id = child.api.nvim_create_buf(false, true)
  default_show(new_buf_id, { 'def', 'd_ef', 'd__ef' }, { 'd', 'e' })
  child.api.nvim_set_current_buf(new_buf_id)
  child.expect_screenshot()
end

T['default_show()']['shows best match'] = function()
  default_show(0, { 'a__b_a__b_ab', 'a__b_ab_a__b', 'ab_a__b_a__b', 'ab__ab' }, { 'a', 'b' })
  child.expect_screenshot()

  default_show(0, { 'aabbccddee' }, { 'a', 'b', 'c', 'd', 'e' })
  child.expect_screenshot()
end

T['default_show()']['respects `opts.show_icons`'] = function()
  child.set_size(10, 45)
  local items = vim.tbl_map(real_file, vim.fn.readdir(real_files_dir))
  table.insert(items, test_dir)
  table.insert(items, join_path(test_dir, 'file'))
  table.insert(items, 'non-existing')
  table.insert(items, { text = 'non-string' })
  local query = { 'i', 'i' }

  -- Without 'nvim-web-devicons'
  default_show(0, items, query, { show_icons = true })
  child.expect_screenshot()

  -- With 'nvim-web-devicons'
  child.cmd('set rtp+=tests/dir-pick')
  default_show(0, items, query, { show_icons = true })
  child.expect_screenshot()
end

T['default_show()']['respects `opts.icons`'] = function()
  child.set_size(10, 45)
  local items = vim.tbl_map(real_file, vim.fn.readdir(real_files_dir))
  table.insert(items, test_dir)
  table.insert(items, join_path(test_dir, 'file'))
  table.insert(items, 'non-existing')
  table.insert(items, { text = 'non-string' })
  local query = { 'i', 'i' }

  local icon_opts = { show_icons = true, icons = { directory = 'DD', file = 'FF', none = 'NN' } }

  -- Without 'nvim-web-devicons'
  default_show(0, items, query, icon_opts)
  child.expect_screenshot()

  -- With 'nvim-web-devicons'
  child.cmd('set rtp+=tests/dir-pick')
  default_show(0, items, query, icon_opts)
  child.expect_screenshot()
end

T['default_show()']['handles stritems with non-trivial whitespace'] = function()
  child.o.tabstop = 3
  default_show(0, { 'With\nnewline', 'With\ttab' }, {})
  child.expect_screenshot()
end

T['default_show()']["respects 'ignorecase'/'smartcase'"] = function()
  child.set_size(7, 12)
  local items = { 'a_b', 'a_B', 'A_b', 'A_B' }

  local validate = function()
    default_show(0, items, { 'a', 'b' })
    child.expect_screenshot()
    default_show(0, items, { 'a', 'B' })
    child.expect_screenshot()
  end

  -- Respect case
  child.o.ignorecase, child.o.smartcase = false, false
  validate()

  -- Ignore case
  child.o.ignorecase, child.o.smartcase = true, false
  validate()

  -- Smart case
  child.o.ignorecase, child.o.smartcase = true, true
  validate()
end

T['default_show()']['handles query similar to `default_match`'] = function()
  child.set_size(15, 15)
  local items = { 'abc', '_abc', 'a_bc', 'ab_c', 'abc_', '*abc', "'abc", '^abc', 'abc$', 'a b c' }

  local validate = function(query)
    default_show(0, items, query)
    child.expect_screenshot()
  end

  validate({ '*', 'a', 'b' })
  validate({ "'", 'a', 'b' })
  validate({ '^', 'a', 'b' })
  validate({ 'b', 'c', '$' })
  validate({ 'a', 'b', ' ', 'c' })
end

T['default_show()']['works with multibyte characters'] = function()
  local items = { 'ыdф', 'ыы_d_ф', '_ыы_d_ф' }

  -- In query
  default_show(0, items, { 'ы', 'ф' })
  child.expect_screenshot()

  -- Not in query
  default_show(0, items, { 'd' })
  child.expect_screenshot()
end

T['default_show()']['works with non-single-char-entries queries'] = function()
  local items = { '_abc', 'a_bc', 'ab_c', 'abc_' }
  local validate = function(query)
    default_show(0, items, query)
    child.expect_screenshot()
  end

  validate({ 'ab', 'c' })
  validate({ 'abc' })
  validate({ 'a b', ' ', 'c' })
end

T['default_show()']['handles edge cases'] = function()
  child.set_size(5, 15)

  -- Should not treat empty string as directory
  default_show(0, { ':1', ':1:1' }, {}, { show_icons = true })
  child.expect_screenshot()
end

T['default_preview()'] = new_set()

local default_preview = forward_lua('MiniPick.default_preview')

local validate_preview = function(items)
  start_with_items(items)
  type_keys('<Tab>')
  child.expect_screenshot()

  for _ = 1, (#items - 1) do
    type_keys('<C-n>')
    child.expect_screenshot()
  end
end

T['default_preview()']['works'] = function() validate_preview({ real_file('b.txt') }) end

T['default_preview()']['works without active picker'] = function()
  -- Allows 0 buffer id for current buffer
  default_preview(0, real_file('b.txt'))
  child.expect_screenshot()

  -- Allows non-current buffer
  local new_buf_id = child.api.nvim_create_buf(false, true)
  default_preview(new_buf_id, real_file('LICENSE'))
  child.api.nvim_set_current_buf(new_buf_id)
  child.expect_screenshot()
end

T['default_preview()']['works for file path'] = function()
  local items = {
    -- Item as string
    real_file('b.txt'),

    -- Item as table with `path` field
    { text = real_file('LICENSE'), path = real_file('LICENSE') },

    -- Non-text file
    real_file('c.gif'),
  }
  validate_preview(items)
end

T['default_preview()']['works for relative file path'] = function()
  local lua_cmd =
    string.format([[MiniPick.start({ source = { items = { 'a.lua' }, cwd = '%s' } })]], full_path(real_files_dir))
  child.lua_notify(lua_cmd)
  type_keys('<Tab>')
  child.expect_screenshot()
end

T['default_preview()']['works for file path with tilde'] = function()
  local path = real_file('LICENSE')
  local path_tilde = child.fn.fnamemodify(full_path(path), ':~')
  if path_tilde:sub(1, 1) ~= '~' then return end

  child.set_size(5, 15)
  validate_preview({ path_tilde })
end

T['default_preview()']['shows line in file path'] = function()
  local path = real_file('b.txt')
  local items = {
    path .. ':3',
    { text = path .. ':as-table', path = path, lnum = 6 },
  }
  validate_preview(items)
end

T['default_preview()']['shows position in file path'] = function()
  local path = real_file('b.txt')
  local items = {
    path .. ':3:4',
    { text = path .. ':as-table', path = path, lnum = 6, col = 2 },
  }
  validate_preview(items)
end

T['default_preview()']['shows region in file path'] = function()
  local path = real_file('b.txt')
  local items = {
    { text = path .. ':region-oneline', path = path, lnum = 8, col = 3, end_lnum = 8, end_col = 5 },
    { text = path .. ':region-manylines', path = path, lnum = 9, col = 3, end_lnum = 11, end_col = 4 },
  }
  validate_preview(items)
end

T['default_preview()']['has syntax highlighting in file path'] = function()
  local items = {
    -- With tree-sitter
    real_file('a.lua'),

    -- With built-in syntax
    real_file('Makefile'),
  }
  validate_preview(items)
end

T['default_preview()']['loads context in file path'] = function()
  start_with_items({ real_file('b.txt') })
  type_keys('<Tab>')
  child.expect_screenshot()
  type_keys('<C-f>')
  child.expect_screenshot()
  type_keys('<C-f>')
  child.expect_screenshot()
end

T['default_preview()']['works for directory path'] = function()
  validate_preview({ test_dir, { text = real_files_dir, path = real_files_dir } })
end

T['default_preview()']['works for buffer'] = function()
  local buf_id_1 = child.api.nvim_create_buf(false, false)
  local buf_id_2 = child.api.nvim_create_buf(true, false)
  local buf_id_3 = child.api.nvim_create_buf(false, true)
  local buf_id_4 = child.api.nvim_create_buf(true, true)

  child.api.nvim_buf_set_lines(buf_id_1, 0, -1, false, { 'This is buffer #1' })
  child.api.nvim_buf_set_lines(buf_id_2, 0, -1, false, { 'This is buffer #2' })
  child.api.nvim_buf_set_lines(buf_id_3, 0, -1, false, { 'This is buffer #3' })
  child.api.nvim_buf_set_lines(buf_id_4, 0, -1, false, { 'This is buffer #4' })

  local items = {
    -- As number
    buf_id_1,

    -- As string convertible to number
    tostring(buf_id_1),

    -- As table with `bufnr` field
    { text = 'Buffer #2', bufnr = buf_id_2 },

    -- As table with `buf_id` field
    { text = 'Buffer #3', buf_id = buf_id_3 },

    -- As table with `buf` field
    { text = 'Buffer #4', buf = buf_id_4 },
  }
  validate_preview(items)
end

local mock_buffer_for_preview = function()
  local buf_id = child.api.nvim_create_buf(true, false)
  local lines = {}
  for i = 1, 20 do
    table.insert(lines, string.format('Line %d in buffer %d', i, buf_id))
  end
  child.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  return buf_id
end

T['default_preview()']['shows line in buffer'] = function()
  local buf_id = mock_buffer_for_preview()
  validate_preview({ { text = 'Line in buffer', bufnr = buf_id, lnum = 4 } })
end

T['default_preview()']['shows position in buffer'] = function()
  local buf_id = mock_buffer_for_preview()
  validate_preview({ { text = 'Position in buffer', bufnr = buf_id, lnum = 6, col = 3 } })
end

T['default_preview()']['shows region in buffer'] = function()
  local buf_id = mock_buffer_for_preview()
  local items = {
    { text = 'Oneline region in buffer', bufnr = buf_id, lnum = 8, col = 3, end_lnum = 8, end_col = 6 },
    { text = 'Manylines region in buffer', bufnr = buf_id, lnum = 10, col = 3, end_lnum = 12, end_col = 4 },
  }
  validate_preview(items)
end

T['default_preview()']['has syntax highlighting in buffer'] = function()
  child.cmd('edit ' .. real_file('a.lua'))
  local buf_id_lua = child.api.nvim_get_current_buf()
  child.cmd('edit ' .. real_file('Makefile'))
  local buf_id_makefile = child.api.nvim_get_current_buf()
  child.cmd('enew')

  local items = {
    { text = 'Tree-sitter highlighting', bufnr = buf_id_lua },
    { text = 'Built-in syntax', bufnr = buf_id_makefile },
  }
  validate_preview(items)
end

T['default_preview()']['loads context in buffer'] = function()
  child.cmd('edit ' .. real_file('b.txt'))
  local buf_id = child.api.nvim_get_current_buf()
  child.cmd('enew')

  start_with_items({ { text = 'Buffer', bufnr = buf_id } })
  type_keys('<Tab>')
  child.expect_screenshot()
  type_keys('<C-f>')
  child.expect_screenshot()
  type_keys('<C-f>')
  child.expect_screenshot()
end

T['default_preview()']['has fallback'] = function()
  child.set_size(10, 40)
  validate_preview({ -1, { text = 'Random table' } })
end

T['default_preview()']['does not highlight big files'] = function()
  local big_file = real_file('big.lua')
  MiniTest.finally(function() child.fn.delete(big_file, 'rf') end)

  -- Has limit per line
  child.fn.writefile({ string.format('local a = "%s"', string.rep('a', 1000)) }, big_file)
  child.cmd('edit ' .. big_file)
  local buf_id = child.api.nvim_get_current_buf()
  child.cmd('enew')
  validate_preview({ big_file, { bufnr = buf_id, text = 'Buffer item' } })

  -- It also should have total limit, but it is not tested to not overuse file
  -- system accesses during test
end

T['default_preview()']['respects `opts.n_context_lines`'] = function()
  child.lua([[MiniPick.config.source.preview = function(buf_id, item)
    return MiniPick.default_preview(buf_id, item, { n_context_lines = 2 })
  end]])
  local path = real_file('b.txt')
  child.cmd('edit ' .. path)
  local buf_id = child.api.nvim_get_current_buf()
  child.cmd('enew')

  local items = {
    -- File line
    path .. ':4',

    -- Buffer line
    { text = 'Buffer', bufnr = buf_id, lnum = 7 },
  }
  validate_preview(items)
end

T['default_preview()']['respects `opts.line_position`'] = new_set({
  parametrize = { { 'top' }, { 'center' }, { 'bottom' } },
}, {
  function(line_position)
    child.lua('_G.line_position = ' .. vim.inspect(line_position))
    child.lua([[MiniPick.config.source.preview = function(buf_id, item)
        return MiniPick.default_preview(buf_id, item, { line_position = _G.line_position })
      end]])
    local path = real_file('b.txt')
    child.cmd('edit ' .. path)
    local buf_id = child.api.nvim_get_current_buf()
    child.cmd('enew')

    local items = {
      -- File line
      path .. ':10',

      -- Buffer line
      { text = 'Buffer', bufnr = buf_id, lnum = 12 },
    }
    validate_preview(items)
  end,
})

T['default_preview()']['respects `source.cwd`'] = function()
  local lua_cmd = string.format([[MiniPick.start({ source = { items = { 'b.txt' }, cwd = '%s' } })]], real_files_dir)
  child.lua_notify(lua_cmd)
  type_keys('<Tab>')
  child.expect_screenshot()
end

T['default_choose()'] = new_set()

local default_choose = forward_lua('MiniPick.default_choose')

local choose_item = function(item)
  start_with_items({ item })
  type_keys('<CR>')
  eq(is_picker_active(), false)
end

T['default_choose()']['works'] = function()
  local path = real_file('b.txt')
  choose_item(path)
  validate_buf_name(0, path)
end

T['default_choose()']['respects picker target window'] = function()
  local win_id_1, win_id_2 = setup_windows_pair()
  local buf_id_1 = child.api.nvim_create_buf(false, true)
  child.api.nvim_win_set_buf(win_id_1, buf_id_1)
  local buf_id_2 = child.api.nvim_create_buf(false, true)
  child.api.nvim_win_set_buf(win_id_2, buf_id_2)

  local path = real_file('b.txt')
  start_with_items({ path })
  child.lua(string.format('MiniPick.set_picker_target_window(%d)', win_id_2))
  type_keys('<CR>')

  eq(child.api.nvim_win_get_buf(win_id_1), buf_id_1)
  validate_buf_name(buf_id_1, '')
  eq(child.api.nvim_win_get_buf(win_id_2), buf_id_2)
  validate_buf_name(buf_id_2, path)
end

T['default_choose()']['works without active picker'] = function()
  local win_id_1, win_id_2 = setup_windows_pair()
  local path = real_file('b.txt')
  default_choose(path)

  -- Should use current window as target
  validate_buf_name(child.api.nvim_win_get_buf(win_id_1), path)
  validate_buf_name(child.api.nvim_win_get_buf(win_id_2), '')
end

T['default_choose()']['works for file path'] = function()
  local validate = function(item, path, pos)
    local win_id = child.api.nvim_get_current_win()
    default_choose(item)

    local buf_id = child.api.nvim_win_get_buf(win_id)
    validate_buf_name(buf_id, path)
    if pos ~= nil then eq(child.api.nvim_win_get_cursor(win_id), pos) end

    -- Cleanup
    child.api.nvim_buf_delete(buf_id, { force = true })
  end

  local path = real_file('b.txt')

  -- Path
  validate(path, path, { 1, 0 })
  validate({ text = path, path = path }, path, { 1, 0 })

  -- Path with line
  validate(path .. ':4', path, { 4, 0 })
  validate({ text = path, path = path, lnum = 6 }, path, { 6, 0 })

  -- Path with position
  validate(path .. ':8:2', path, { 8, 1 })
  validate({ text = path, path = path, lnum = 10, col = 4 }, path, { 10, 3 })

  -- Path with region
  validate({ text = path, path = path, lnum = 12, col = 5, end_lnum = 14, end_col = 3 }, path, { 12, 4 })
end

T['default_choose()']['works for relative file path'] = function()
  local lua_cmd =
    string.format([[MiniPick.start({ source = { items = { 'a.lua' }, cwd = '%s' } })]], full_path(real_files_dir))
  child.lua_notify(lua_cmd)
  type_keys('<CR>')
  validate_buf_name(0, real_file('a.lua'))

  -- Should open with relative path to have better view in `:buffers`
  expect.match(child.cmd_capture('buffers'), '"' .. vim.pesc(real_files_dir))
end

T['default_choose()']['works for file path with tilde'] = function()
  local path = real_file('LICENSE')
  local path_tilde = child.fn.fnamemodify(full_path(path), ':~')
  if path_tilde:sub(1, 1) ~= '~' then return end

  child.set_size(5, 15)
  start_with_items({ path_tilde })
  type_keys('<CR>')
  validate_buf_name(0, path)
end

T['default_choose()']['reuses opened listed buffer for file path'] = function()
  local path = real_file('b.txt')
  child.cmd('edit ' .. path)
  local buf_id_path = child.api.nvim_get_current_buf()
  validate_buf_name(buf_id_path, path)
  set_cursor(5, 3)

  local buf_id_alt = child.api.nvim_create_buf(true, false)

  local validate = function(pos)
    eq(child.api.nvim_win_get_buf(0), buf_id_path)
    validate_buf_name(buf_id_path, path)
    eq(child.api.nvim_win_get_cursor(0), pos)
  end

  -- Reuses without setting cursor
  child.api.nvim_set_current_buf(buf_id_alt)
  default_choose(path)
  validate({ 5, 3 })

  -- Reuses with setting cursor
  child.api.nvim_set_current_buf(buf_id_alt)
  default_choose(path .. ':7:2')
  validate({ 7, 1 })

  -- Doesn't reuse if unlisted
  child.api.nvim_set_current_buf(buf_id_alt)
  child.cmd('bdelete ' .. buf_id_path)
  eq(child.api.nvim_buf_get_option(buf_id_path, 'buflisted'), false)
  default_choose(path)
  validate({ 1, 0 })
  eq(child.api.nvim_buf_get_option(buf_id_path, 'buflisted'), true)
end

T['default_choose()']['works for directory path'] = function()
  local validate = function(item, path)
    local buf_id_init = child.api.nvim_get_current_buf()
    default_choose(item)

    local buf_id_cur = child.api.nvim_get_current_buf()
    eq(child.bo.filetype, 'netrw')
    validate_buf_name(buf_id_init, path)

    -- Cleanup
    child.api.nvim_buf_delete(buf_id_init, { force = true })
    child.api.nvim_buf_delete(buf_id_cur, { force = true })
  end

  validate(test_dir, test_dir)
  validate({ text = test_dir, path = test_dir }, test_dir)
end

T['default_choose()']['works for buffer'] = function()
  local buf_id_tmp = child.api.nvim_create_buf(false, true)

  local setup_buffer = function(pos)
    local buf_id = child.api.nvim_create_buf(true, false)
    child.api.nvim_buf_set_lines(buf_id, 0, -1, false, vim.fn['repeat']({ 'aaaaaaaaaaaaaaaaaaaa' }, 20))

    local cur_buf = child.api.nvim_win_get_buf(0)
    child.api.nvim_set_current_buf(buf_id)
    child.api.nvim_win_set_cursor(0, pos)
    child.api.nvim_win_set_buf(0, cur_buf)

    return buf_id
  end

  local validate = function(item, buf_id, pos)
    local win_id = child.api.nvim_get_current_win()
    child.api.nvim_win_set_buf(0, buf_id_tmp)

    default_choose(item)

    eq(child.api.nvim_win_get_buf(win_id), buf_id)
    if pos ~= nil then eq(child.api.nvim_win_get_cursor(win_id), pos) end

    -- Cleanup
    child.api.nvim_buf_delete(buf_id, { force = true })
  end

  local buf_id

  -- Buffer without position should reuse current cursor
  buf_id = setup_buffer({ 1, 1 })
  validate(buf_id, buf_id, { 1, 1 })

  buf_id = setup_buffer({ 2, 2 })
  validate(tostring(buf_id), buf_id, { 2, 2 })

  -- Buffer in table
  buf_id = setup_buffer({ 3, 3 })
  validate({ text = 'buffer', bufnr = buf_id }, buf_id, { 3, 3 })

  buf_id = setup_buffer({ 4, 4 })
  validate({ text = 'buffer', buf_id = buf_id }, buf_id, { 4, 4 })

  buf_id = setup_buffer({ 5, 5 })
  validate({ text = 'buffer', buf = buf_id }, buf_id, { 5, 5 })

  -- Buffer with line
  buf_id = setup_buffer({ 6, 6 })
  validate({ text = 'buffer', bufnr = buf_id, lnum = 7 }, buf_id, { 7, 0 })

  -- Buffer with position
  buf_id = setup_buffer({ 6, 6 })
  validate({ text = 'buffer', bufnr = buf_id, lnum = 8, col = 8 }, buf_id, { 8, 7 })

  -- Buffer with region
  buf_id = setup_buffer({ 6, 6 })
  validate({ text = 'buffer', bufnr = buf_id, lnum = 9, col = 9, end_lnum = 10, end_col = 8 }, buf_id, { 9, 8 })

  -- Already shown buffer
  local setup_current_buf = function(pos)
    child.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn['repeat']({ 'aaaaaaaaaaaaaaaaaaaa' }, 20))
    child.api.nvim_win_set_cursor(0, pos)
    return child.api.nvim_get_current_buf()
  end

  buf_id = setup_current_buf({ 11, 11 })
  validate(buf_id, buf_id, { 11, 11 })

  buf_id = setup_current_buf({ 12, 12 })
  validate({ text = 'buffer', bufnr = buf_id, lnum = 13 }, buf_id, { 13, 0 })

  buf_id = setup_current_buf({ 12, 12 })
  validate({ text = 'buffer', bufnr = buf_id, lnum = 14, col = 14 }, buf_id, { 14, 13 })

  buf_id = setup_current_buf({ 12, 12 })
  validate({ text = 'buffer', bufnr = buf_id, lnum = 15, col = 15, end_lnum = 16, end_col = 14 }, buf_id, { 15, 14 })
end

T['default_choose()']['ensures valid target window'] = function()
  local choose_with_bad_target_window = function(item)
    child.cmd('botright wincmd v')
    local win_id = child.api.nvim_get_current_win()

    start_with_items({ item })
    local lua_cmd = string.format([[vim.api.nvim_win_call(%d, function() vim.cmd('close') end)]], win_id)
    child.lua(lua_cmd)

    type_keys('<CR>')
  end

  -- Path
  local path = real_file('b.txt')
  choose_with_bad_target_window(path)
  validate_buf_name(child.api.nvim_get_current_buf(), path)

  -- Buffer
  local buf_id = child.api.nvim_create_buf(true, false)
  choose_with_bad_target_window({ text = 'buffer', bufnr = buf_id })
  eq(child.api.nvim_get_current_buf(), buf_id)
end

T['default_choose()']['centers cursor'] = function()
  local validate = function(item, ref_topline)
    choose_item(item)
    eq(child.fn.line('w0'), ref_topline)
  end

  -- Path
  local path = real_file('b.txt')
  validate({ text = path, path = path, lnum = 10 }, 4)

  -- Buffer
  local buf_id = child.api.nvim_create_buf(true, false)
  child.api.nvim_buf_set_lines(buf_id, 0, -1, false, vim.fn['repeat']({ 'aaaaaaaaaa' }, 100))
  validate({ text = 'buffer', bufnr = buf_id, lnum = 12 }, 6)
end

T['default_choose()']['opens just enough folds'] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn['repeat']({ 'aaaaaaaaaa' }, 100))
  child.cmd('2,3fold')
  child.cmd('12,13fold')

  eq(child.fn.foldclosed(2), 2)
  eq(child.fn.foldclosed(3), 2)
  eq(child.fn.foldclosed(12), 12)
  eq(child.fn.foldclosed(13), 12)

  default_choose({ text = 'buffer', bufnr = child.api.nvim_get_current_buf(), lnum = 12 })

  eq(child.fn.foldclosed(2), 2)
  eq(child.fn.foldclosed(3), 2)
  eq(child.fn.foldclosed(12), -1)
  eq(child.fn.foldclosed(13), -1)
end

T['default_choose()']['has print fallback'] = function()
  choose_item({ text = 'regular-table' })
  eq(child.cmd_capture('messages'), '\n{\n  text = "regular-table"\n}')
end

T['default_choose()']['does nothing for `nil` input'] = function()
  expect.no_error(function() default_choose() end)
  eq(child.cmd_capture('messages'), '')
end

T['default_choose_marked()'] = new_set()

local default_choose_marked = forward_lua('MiniPick.default_choose_marked')

local validate_qfitem = function(input, ref)
  local eq_if_nonnil = function(x, y)
    if y ~= nil then eq(x, y) end
  end

  eq_if_nonnil(input.bufnr, ref.bufnr)
  if ref.filename ~= nil then validate_buf_name(input.bufnr, ref.filename) end
  eq_if_nonnil(input.lnum, ref.lnum)
  eq_if_nonnil(input.col, ref.col)
  eq_if_nonnil(input.end_lnum, ref.end_lnum)
  eq_if_nonnil(input.end_col, ref.end_col)
  eq_if_nonnil(input.text, ref.text)
end

T['default_choose_marked()']['works'] = function()
  local path = real_file('b.txt')
  start_with_items({ path })
  type_keys('<C-x>', '<M-CR>')
  eq(is_picker_active(), false)

  -- Should create and open quickfix list
  eq(#child.api.nvim_list_wins(), 2)
  eq(child.bo.filetype, 'qf')

  local qflist = child.fn.getqflist()
  eq(#qflist, 1)
  validate_qfitem(qflist[1], { filename = path, lnum = 1, col = 1, end_lnum = 0, end_col = 0, text = '' })
end

T['default_choose_marked()']['creates proper title'] = function()
  local validate = function(keys, title)
    local path = real_file('b.txt')
    start_with_items({ path }, 'Picker name')
    type_keys(keys, '<C-x>', '<M-CR>')
    eq(is_picker_active(), false)
    eq(child.fn.getqflist({ title = true }).title, title)
  end

  validate({}, 'Picker name')
  validate({ 'b', '.', 't' }, 'Picker name : b.t')
end

T['default_choose_marked()']['sets as last list'] = function()
  local path = real_file('b.txt')
  child.fn.setqflist({}, ' ', { items = { { filename = path, lnum = 2, col = 2 } }, nr = '$' })
  child.fn.setqflist({}, ' ', { items = { { filename = path, lnum = 3, col = 3 } }, nr = '$' })
  child.cmd('colder')

  start_with_items({ path })
  type_keys('<C-x>', '<M-CR>')
  local list_data = child.fn.getqflist({ all = true })
  validate_qfitem(list_data.items[1], { filename = path, lnum = 1, col = 1 })
  eq(list_data.nr, 3)
end

T['default_choose_marked()']['works without active picker'] = function()
  local path_1, path_2 = real_file('b.txt'), real_file('LICENSE')
  default_choose_marked({ path_1, path_2 })

  eq(#child.api.nvim_list_wins(), 2)
  eq(child.bo.filetype, 'qf')

  local list_data = child.fn.getqflist({ all = true })
  eq(#list_data.items, 2)
  validate_qfitem(list_data.items[1], { filename = path_1, lnum = 1, col = 1, end_lnum = 0, end_col = 0, text = '' })
  validate_qfitem(list_data.items[2], { filename = path_2, lnum = 1, col = 1, end_lnum = 0, end_col = 0, text = '' })

  eq(list_data.title, '<No picker>')
end

T['default_choose_marked()']['creates quickfix list from file/buffer positions'] = function()
  local path = real_file('b.txt')
  local buf_id = child.api.nvim_create_buf(true, false)
  local buf_id_scratch = child.api.nvim_create_buf(false, true)

  local items = {
    -- File path
    path,

    { text = 'filepath', path = path },

    path .. ':3',
    { text = path, path = path, lnum = 4 },

    path .. ':5:5',
    path .. ':6:6:' .. 'extra text',
    { text = path, path = path, lnum = 7, col = 7 },

    { text = path, path = path, lnum = 8, col = 8, end_lnum = 9, end_col = 9 },
    { text = path, path = path, lnum = 8, col = 9, end_lnum = 9 },

    -- Buffer
    buf_id,
    tostring(buf_id),
    { text = 'buffer', bufnr = buf_id },

    buf_id_scratch,

    { text = 'buffer', bufnr = buf_id, lnum = 5 },

    { text = 'buffer', bufnr = buf_id, lnum = 6, col = 6 },

    { text = 'buffer', bufnr = buf_id, lnum = 7, col = 7, end_lnum = 8, end_col = 8 },
    { text = 'buffer', bufnr = buf_id, lnum = 7, col = 8, end_lnum = 8 },
  }

  start_with_items(items)
  type_keys('<C-a>', '<M-CR>')
  local qflist = child.fn.getqflist()
  eq(#qflist, #items)

  validate_qfitem(qflist[1], { filename = path, lnum = 1, col = 1, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[2], { filename = path, lnum = 1, col = 1, end_lnum = 0, end_col = 0, text = 'filepath' })
  validate_qfitem(qflist[3], { filename = path, lnum = 3, col = 1, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[4], { filename = path, lnum = 4, col = 1, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[5], { filename = path, lnum = 5, col = 5, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[6], { filename = path, lnum = 6, col = 6, end_lnum = 0, end_col = 0, text = 'extra text' })
  validate_qfitem(qflist[7], { filename = path, lnum = 7, col = 7, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[8], { filename = path, lnum = 8, col = 8, end_lnum = 9, end_col = 9 })
  validate_qfitem(qflist[9], { filename = path, lnum = 8, col = 9, end_lnum = 9, end_col = 0 })

  validate_qfitem(qflist[10], { bufnr = buf_id, lnum = 1, col = 1, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[11], { bufnr = buf_id, lnum = 1, col = 1, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[12], { bufnr = buf_id, lnum = 1, col = 1, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[13], { bufnr = buf_id_scratch, lnum = 1, col = 1, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[14], { bufnr = buf_id, lnum = 5, col = 1, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[15], { bufnr = buf_id, lnum = 6, col = 6, end_lnum = 0, end_col = 0 })
  validate_qfitem(qflist[16], { bufnr = buf_id, lnum = 7, col = 7, end_lnum = 8, end_col = 8 })
  validate_qfitem(qflist[17], { bufnr = buf_id, lnum = 7, col = 8, end_lnum = 8, end_col = 0 })
end

T['default_choose_marked()']['falls back to choosing first item'] = function()
  child.lua_notify(
    [[MiniPick.start({source = { items = { -1, { text = 'some_table' }, -3 }, choose = function(item) _G.chosen_item = item end, }})]]
  )
  type_keys('<C-n>', '<C-x>', '<C-n>', '<C-x>', '<M-CR>')
  eq(is_picker_active(), false)

  eq(child.lua_get('_G.chosen_item'), { text = 'some_table' })

  -- Can also be called without active picker and error
  expect.no_error(function() default_choose_marked({ -1, { text = 'some_table' } }) end)
end

T['default_choose_marked()']['works for edge case input'] = function()
  expect.error(default_choose_marked, '`items`.*array')
  expect.no_error(function() default_choose_marked({}) end)
end

T['default_choose_marked()']['respects `opts.list_type`'] = function()
  local win_id = child.api.nvim_get_current_win()
  local buf_id = child.api.nvim_create_buf(true, false)

  child.lua([[MiniPick.config.source.choose_marked = function(items)
    return MiniPick.default_choose_marked(items, { list_type = 'location' })
  end]])
  start_with_items({ { bufnr = buf_id } }, 'list_type test')
  type_keys('<C-x>', '<M-CR>')
  eq(is_picker_active(), false)

  -- Should create and open location list
  eq(#child.api.nvim_list_wins(), 2)
  eq(child.bo.filetype, 'qf')

  local loclist = child.fn.getloclist(win_id, { all = true })
  eq(#loclist.items, 1)
  validate_qfitem(loclist.items[1], { bufnr = buf_id, lnum = 1, col = 1, end_lnum = 0, end_col = 0, text = '' })

  eq(loclist.title, 'list_type test')

  -- No quickfix lists should be created
  eq(child.fn.getqflist({ nr = true }).nr, 0)
end

T['default_choose_marked()']['ensures valid target window for location list'] = function()
  local win_id_1, win_id_2 = setup_windows_pair()

  local buf_id = child.api.nvim_create_buf(true, false)
  child.lua([[MiniPick.config.source.choose_marked = function(items)
    return MiniPick.default_choose_marked(items, { list_type = 'location' })
  end]])

  start_with_items({ { bufnr = buf_id } }, 'ensure valid window')
  local lua_cmd = string.format([[vim.api.nvim_win_call(%d, function() vim.cmd('close') end)]], win_id_1)
  child.lua(lua_cmd)
  type_keys('<C-x>', '<M-CR>')
  eq(is_picker_active(), false)

  eq(child.fn.getloclist(win_id_2, { title = true }).title, 'ensure valid window')
end

T['ui_select()'] = new_set()

local ui_select = function(items, opts, on_choice_str)
  opts = opts or {}
  on_choice_str = on_choice_str or 'function(...) _G.args = { ... } end'
  local lua_cmd = string.format('MiniPick.ui_select(%s, %s, %s)', vim.inspect(items), vim.inspect(opts), on_choice_str)
  child.lua_notify(lua_cmd)
end

T['ui_select()']['works'] = function()
  ui_select({ -1, -2 })
  child.expect_screenshot()
  type_keys('<C-n>', '<CR>')
  eq(child.lua_get('_G.args'), { -2, 2 })
end

T['ui_select()']['calls `on_choice(nil)` in case of abort'] = function()
  ui_select({ -1, -2 })
  type_keys('<C-c>')
  eq(child.lua_get('_G.args'), {})
end

T['ui_select()']['preserves target window after `on_choice`'] = function()
  local _, win_id_2 = setup_windows_pair()

  local on_choice_str = string.format('function() vim.api.nvim_set_current_win(%d) end', win_id_2)
  ui_select({ -1, -2 }, {}, on_choice_str)
  type_keys('<CR>')
  eq(child.api.nvim_get_current_win(), win_id_2)
end

T['ui_select()']['calls `on_choice` with target window being current'] = function()
  local buf_target = child.api.nvim_get_current_buf()
  local win_target = child.api.nvim_get_current_win()
  ui_select(
    { -1, -2 },
    {},
    'function() _G.cur_data = { buf = vim.api.nvim_get_current_buf(), win = vim.api.nvim_get_current_win() } end'
  )
  type_keys('<CR>')
  eq(child.lua_get('_G.cur_data'), { buf = buf_target, win = win_target })
end

T['ui_select()']['respects `opts.prompt` and `opts.kind`'] = function()
  local validate = function(opts, source_name)
    ui_select({ -1, -2 }, opts)
    validate_picker_option('source.name', source_name)
    stop()
  end

  -- Should try using use both as source name (preferring `prompt` over `kind`)
  validate({ prompt = 'Prompt' }, 'Prompt')
  validate({ prompt = 'Prompt', kind = 'Kind' }, 'Prompt')
end

T['ui_select()']['respects `opts.format_item`'] = function()
  child.lua_notify([[MiniPick.ui_select(
    { { var = 'abc' }, { var = 'def' } },
    { format_item = function(x) return x.var end },
    function(...) _G.args = { ... } end
  )]])

  -- Should use formatted output as regular stritems
  eq(get_picker_stritems(), { 'abc', 'def' })
  type_keys('d', '<CR>')
  eq(child.lua_get('_G.args'), { { var = 'def' }, 2 })
end

T['ui_select()']['shows only original item in preview'] = function()
  child.lua_notify([[MiniPick.ui_select({ { var = 'abc' } }, { format_item = function(x) return x.var end })]])
  type_keys('<Tab>')
  child.expect_screenshot()
end

T['ui_select()']['respects `opts.preview_item`'] = function()
  child.lua_notify([[MiniPick.ui_select(
    { { var = 'abc' } },
    {
      format_item = function(x) return x.var end,
      preview_item = function(x) return { 'My preview', 'Var = ' .. x.var } end,
    }
  )]])
  type_keys('<Tab>')
  child.expect_screenshot()
end

T['builtin.files()'] = new_set({ hooks = { pre_case = mock_spawn } })

local builtin_files = forward_lua_notify('MiniPick.builtin.files')

T['builtin.files()']['works'] = function()
  child.set_size(10, 60)
  mock_fn_executable({ 'rg' })
  local items = { real_file('b.txt'), real_file('LICENSE'), test_dir }
  mock_cli_return(items)

  child.lua_notify('_G.file_item = MiniPick.builtin.files()')

  -- Should use icons by default
  child.expect_screenshot()

  -- Should set correct name
  validate_picker_option('source.name', 'Files (rg)')

  -- Should return chosen value
  type_keys('<CR>')
  eq(child.lua_get('_G.file_item'), items[1])
end

T['builtin.files()']['works with bad file names'] = function()
  -- Paths with ":" may not be allowed on Windows
  if child.loop.os_uname().sysname == 'Windows_NT' then return end

  local path = join_path(test_dir, 'file:1')
  child.fn.writefile({ 'File with ":" in the name' }, path)
  MiniTest.finally(function() child.fn.delete(path) end)

  mock_fn_executable({ 'rg' })
  local items = { path }
  mock_cli_return(items)

  child.lua_notify('_G.file_item = MiniPick.builtin.files()')
  type_keys('<CR>')
  eq(child.lua_get('_G.file_item'), { path = path, text = path })

  eq(child.api.nvim_buf_get_name(0), full_path(path))
end

T['builtin.files()']['correctly chooses default tool'] = function()
  local validate = function(executables, ref_tool)
    mock_fn_executable(executables)
    mock_cli_return({ real_file('b.txt') })
    builtin_files()
    if ref_tool ~= 'fallback' then eq(child.lua_get('_G.spawn_log[1].executable'), ref_tool) end
    validate_picker_option('source.name', string.format('Files (%s)', ref_tool))

    -- Cleanup
    type_keys('<C-c>')
    clear_spawn_log()
  end

  validate({ 'rg', 'fd', 'git' }, 'rg')
  validate({ 'fd', 'git' }, 'fd')
  validate({ 'git' }, 'git')
  validate({}, 'fallback')
end

T['builtin.files()']['respects `local_opts.tool`'] = function()
  local validate = function(tool, ref_args)
    mock_fn_executable({ tool })
    mock_cli_return({})
    builtin_files({ tool = tool })
    local spawn_data = child.lua_get('_G.spawn_log[1]')
    eq(spawn_data.executable, tool)

    -- Tool should be called with proper arguments
    validate_contains_all(spawn_data.options.args, ref_args)

    -- Cleanup
    type_keys('<C-c>')
    clear_spawn_log()
  end

  validate('rg', { '--files', '--no-follow' })
  validate('fd', { '--type=f', '--no-follow' })
  validate('git', { 'ls-files', '--cached', '--others' })
end

T['builtin.files()']['has fallback tool'] = function()
  if child.fn.has('nvim-0.9') == 0 then
    local f = function() child.lua([[MiniPick.builtin.files({ tool = 'fallback' })]]) end
    expect.error(f, 'Tool "fallback" of `files`.*0%.9')
    return
  end

  local cwd = join_path(test_dir, 'builtin-tests')
  builtin_files({ tool = 'fallback' }, { source = { cwd = cwd } })
  validate_picker_option('source.cwd', full_path(cwd))

  -- Sleep because fallback is async
  sleep(5)
  eq(get_picker_items(), { 'file', 'dir1/file1-1', 'dir1/file1-2', 'dir2/file2-1' })
end

T['builtin.files()']['respects `source.show` from config'] = function()
  child.set_size(10, 60)

  -- A recommended way to disable icons
  child.lua('MiniPick.config.source.show = MiniPick.default_show')
  mock_fn_executable({ 'rg' })
  mock_cli_return({ real_file('b.txt'), test_dir })
  builtin_files()
  child.expect_screenshot()
end

T['builtin.files()']['respects `opts`'] = function()
  mock_fn_executable({ 'rg' })
  mock_cli_return({ real_file('b.txt') })
  builtin_files({}, { source = { name = 'My name' } })
  validate_picker_option('source.name', 'My name')
end

T['builtin.files()']['respects `opts.source.cwd` for cli spawn'] = function()
  mock_fn_executable({ 'rg' })
  mock_cli_return({})
  builtin_files({}, { source = { cwd = test_dir } })

  local test_dir_absolute = full_path(test_dir)
  validate_picker_option('source.cwd', test_dir_absolute)
  eq(get_spawn_log()[1].options.cwd, test_dir_absolute)
end

T['builtin.grep()'] = new_set({ hooks = { pre_case = mock_spawn } })

local builtin_grep = forward_lua_notify('MiniPick.builtin.grep')

T['builtin.grep()']['works'] = function()
  child.set_size(10, 70)
  mock_fn_executable({ 'rg' })
  local items = { real_file('a.lua') .. ':3:3:a', real_file('b.txt') .. ':1:1:b' }
  mock_cli_return(items)

  child.lua_notify([[_G.grep_item = MiniPick.builtin.grep()]])
  -- - By default asks for pattern interactively
  type_keys('b', '<CR>')

  -- Should use icons by default
  child.expect_screenshot()

  -- Should set correct name
  validate_picker_option('source.name', 'Grep (rg)')

  -- Should return chosen value
  type_keys('<CR>')
  eq(child.lua_get('_G.grep_item'), items[1])
end

T['builtin.grep()']['correctly chooses default tool'] = function()
  local validate = function(executables, ref_tool)
    mock_fn_executable(executables)
    mock_cli_return({ real_file('b.txt') .. ':3:3:b' })
    builtin_grep({ pattern = 'b' })
    if ref_tool ~= 'fallback' then eq(child.lua_get('_G.spawn_log[1].executable'), ref_tool) end
    validate_picker_option('source.name', string.format('Grep (%s)', ref_tool))

    -- Cleanup
    type_keys('<C-c>')
    clear_spawn_log()
  end

  validate({ 'rg', 'git' }, 'rg')
  validate({ 'git' }, 'git')
  validate({}, 'fallback')
end

T['builtin.grep()']['respects `local_opts.tool`'] = new_set({ parametrize = { { 'default' }, { 'supplied' } } }, {
  test = function(pattern_type)
    local pattern, keys
    if pattern_type == 'default' then
      keys = { 'test', '<CR>' }
    elseif pattern_type == 'supplied' then
      pattern = 'test'
    end

    local validate = function(tool, ref_args)
      mock_fn_executable({ tool })
      mock_cli_return({})
      builtin_grep({ tool = tool, pattern = pattern })
      type_keys(keys)

      local spawn_data = child.lua_get('_G.spawn_log[1]')
      eq(spawn_data.executable, tool)

      -- Tool should be called with proper arguments
      validate_contains_all(spawn_data.options.args, ref_args)

      -- Cleanup
      type_keys('<C-c>')
      clear_spawn_log()
    end

    validate('rg', { '--column', '--line-number', '--no-heading', '--', 'test' })
    validate('git', { 'grep', '--column', '--line-number', '--', 'test' })
  end,
})

T['builtin.grep()']['has fallback tool'] = new_set({ parametrize = { { 'default' }, { 'supplied' } } }, {
  test = function(pattern_type)
    if child.fn.has('nvim-0.9') == 0 then
      local f = function() child.lua([[MiniPick.builtin.grep({ tool = 'fallback', pattern = 'x' })]]) end
      expect.error(f, 'Tool "fallback" of `grep`.*0%.9')
      return
    end

    local pattern, keys
    if pattern_type == 'default' then
      keys = { 'aaa', '<CR>' }
    elseif pattern_type == 'supplied' then
      pattern = 'aaa'
    end

    local cwd = join_path(test_dir, 'builtin-tests')
    builtin_grep({ tool = 'fallback', pattern = pattern }, { source = { cwd = cwd } })
    type_keys(keys)
    validate_picker_option('source.cwd', full_path(cwd))

    -- Sleep because fallback is async
    sleep(5)
    eq(get_picker_items(), { 'file:3:1:aaa', 'dir1/file1-1:3:1:aaa', 'dir1/file1-2:3:1:aaa', 'dir2/file2-1:3:1:aaa' })
  end,
})

T['builtin.grep()']['respects `source.show` from config'] = function()
  child.set_size(10, 70)

  -- A recommended way to disable icons
  child.lua('MiniPick.config.source.show = MiniPick.default_show')
  mock_fn_executable({ 'rg' })
  mock_cli_return({ real_file('b.txt') .. ':1:1' })
  builtin_grep({ pattern = 'b' })
  child.expect_screenshot()
end

T['builtin.grep()']['respects `opts`'] = function()
  mock_fn_executable({ 'rg' })
  mock_cli_return({ real_file('b.txt') .. ':1:1' })
  builtin_grep({ pattern = 'b' }, { source = { name = 'My name' } })
  validate_picker_option('source.name', 'My name')
end

T['builtin.grep()']['respects `opts.source.cwd` for cli spawn'] = function()
  mock_fn_executable({ 'rg' })
  mock_cli_return({})
  builtin_grep({ pattern = 'b' }, { source = { cwd = test_dir } })

  local test_dir_absolute = full_path(test_dir)
  validate_picker_option('source.cwd', test_dir_absolute)
  eq(get_spawn_log()[1].options.cwd, test_dir_absolute)
end

T['builtin.grep()']['can have empty string pattern interactively'] = function()
  mock_fn_executable({ 'rg' })
  mock_cli_return({})
  builtin_grep({ tool = 'rg' })
  type_keys('<CR>')

  local args = child.lua_get('_G.spawn_log[1]').options.args
  eq({ args[#args - 1], args[#args] }, { '--', '' })
end

T['builtin.grep_live()'] = new_set({ hooks = { pre_case = mock_spawn } })

local builtin_grep_live = forward_lua_notify('MiniPick.builtin.grep_live')

local validate_last_grep_pattern = function(pattern)
  local log = get_spawn_log()
  local spawn_args = log[#log].options.args
  eq({ spawn_args[#spawn_args - 1], spawn_args[#spawn_args] }, { '--', pattern })
end

T['builtin.grep_live()']['works'] = function()
  child.set_size(10, 70)
  mock_fn_executable({ 'rg' })
  local items = { real_file('a.lua') .. ':3:3:a', real_file('b.txt') .. ':1:1:b' }

  -- Should show no items for empty query
  child.lua_notify([[_G.grep_live_item = MiniPick.builtin.grep_live()]])
  eq(get_picker_items(), {})

  -- Should grep pattern after every query update
  mock_cli_return(items)
  type_keys('b')
  eq(get_picker_items(), items)
  validate_last_grep_pattern('b')

  mock_cli_return({ items[2] })
  type_keys('t')
  eq(get_picker_items(), { items[2] })
  validate_last_grep_pattern('bt')

  -- Should use icons by default
  child.expect_screenshot()

  -- Should set correct name
  validate_picker_option('source.name', 'Grep live (rg)')

  -- Should return chosen value
  type_keys('<CR>')
  eq(child.lua_get('_G.grep_live_item'), items[2])
end

T['builtin.grep_live()']['always shows no items for empty query'] = function()
  mock_fn_executable({ 'rg' })
  local items = { real_file('a.lua') .. ':3:3:a', real_file('b.txt') .. ':1:1:b' }

  -- Showing empty query should be done without extra spawn
  mock_cli_return(items)
  builtin_grep_live()
  eq(get_picker_items(), {})
  eq(#get_spawn_log(), 0)

  mock_cli_return(items)
  type_keys('b')
  eq(get_picker_items(), items)
  eq(#get_spawn_log(), 1)

  mock_cli_return({ items[1] })
  type_keys('<C-u>')
  eq(get_picker_items(), {})
  eq(#get_spawn_log(), 1)
end

T['builtin.grep_live()']['kills grep process on every non-empty query update'] = function()
  mock_fn_executable({ 'rg' })
  local items = { real_file('a.lua') .. ':3:3:a', real_file('b.txt') .. ':1:1:b' }

  builtin_grep_live()
  eq(get_process_log(), {})

  mock_cli_return(items)
  type_keys('b')
  -- - No process to kill before making query non-empty
  eq(get_process_log(), { 'Stdout Stdout_1 was closed.', 'Process Pid_1 was closed.' })
  clear_process_log()

  mock_cli_return({ items[2] })
  type_keys('y')
  --Stylua: ignore
  eq(get_process_log(), { 'Process Pid_1 was killed.', 'Stdout Stdout_2 was closed.', 'Process Pid_2 was closed.' })
  clear_process_log()

  type_keys('<C-u>')
  eq(get_process_log(), { 'Process Pid_2 was killed.' })
end

T['builtin.grep_live()']['works with programmatic query update'] = function()
  mock_fn_executable({ 'rg' })
  builtin_grep_live()

  mock_cli_return({ real_file('b.txt') .. ':1:1:b' })
  set_picker_query({ 'b', 't' })
  validate_last_grep_pattern('bt')

  set_picker_query({ 'ab', '', 'cd' })
  validate_last_grep_pattern('abcd')
end

T['builtin.grep_live()']['correctly chooses default tool'] = function()
  local validate = function(executables, ref_tool)
    mock_fn_executable(executables)
    mock_cli_return({ real_file('b.txt') .. ':3:3:b' })
    builtin_grep_live()
    type_keys('b')
    eq(child.lua_get('_G.spawn_log[1].executable'), ref_tool)
    validate_picker_option('source.name', string.format('Grep live (%s)', ref_tool))

    -- Cleanup
    type_keys('<C-c>')
    clear_spawn_log()
  end

  -- Needs executable non-fallback "grep" tool
  validate({ 'rg', 'git' }, 'rg')
  validate({ 'git' }, 'git')

  mock_fn_executable({})
  expect.error(function() child.lua('MiniPick.builtin.grep_live()') end, '`grep_live`.*non%-fallback')
end

T['builtin.grep_live()']['respects `local_opts.tool`'] = function()
  local validate = function(tool, ref_args)
    mock_fn_executable({ tool })
    mock_cli_return({})
    builtin_grep_live({ tool = tool })
    type_keys('b')

    local spawn_data = child.lua_get('_G.spawn_log[1]')
    eq(spawn_data.executable, tool)

    -- Tool should be called with proper arguments
    validate_contains_all(spawn_data.options.args, ref_args)

    -- Cleanup
    type_keys('<C-c>')
    clear_spawn_log()
  end

  validate('rg', { '--column', '--line-number', '--no-heading', '--', 'b' })
  validate('git', { 'grep', '--column', '--line-number', '--', 'b' })

  -- Should not accept "fallback" tool
  mock_fn_executable({})
  expect.error(
    function() child.lua([[MiniPick.builtin.grep_live({ tool = 'fallback' })]]) end,
    '`grep_live`.*non%-fallback'
  )
end

T['builtin.grep_live()']['respects `source.show` from config'] = function()
  child.set_size(10, 70)

  -- A recommended way to disable icons
  child.lua('MiniPick.config.source.show = MiniPick.default_show')
  mock_fn_executable({ 'rg' })
  builtin_grep_live()
  mock_cli_return({ real_file('b.txt') .. ':1:1' })
  type_keys('b')
  child.expect_screenshot()
end

T['builtin.grep_live()']['respects `opts`'] = function()
  mock_fn_executable({ 'rg' })
  builtin_grep_live({}, { source = { name = 'My name' } })
  validate_picker_option('source.name', 'My name')
end

T['builtin.grep_live()']['respects `opts.source.cwd` for cli spawn'] = function()
  mock_fn_executable({ 'rg' })
  builtin_grep_live({}, { source = { cwd = test_dir } })
  mock_cli_return({ real_file('b.txt') .. ':1:1' })
  type_keys('b')

  local test_dir_absolute = full_path(test_dir)
  validate_picker_option('source.cwd', test_dir_absolute)
  eq(get_spawn_log()[1].options.cwd, test_dir_absolute)
end

T['builtin.help()'] = new_set()

local builtin_help = forward_lua_notify('MiniPick.builtin.help')

T['builtin.help()']['works'] = function()
  child.lua_notify('_G.help_item = MiniPick.builtin.help()')
  child.expect_screenshot()

  -- Should set correct name
  validate_picker_option('source.name', 'Help')

  -- Should return chosen value
  local item = get_picker_matches().current
  type_keys('<CR>')
  eq(child.lua_get('_G.help_item'), item)

  -- Should open help page as choosing
  child.expect_screenshot()
end

T['builtin.help()']['has proper preview'] = function()
  child.set_size(15, 80)

  -- Shouldn't have side effects for search pattern and `v:hlsearch`
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa', 'bb', 'aa' })
  type_keys('/', 'aa', '<CR>')
  child.cmd('let v:hlsearch=0')

  builtin_help()
  type_keys('<Tab>')
  child.expect_screenshot()
  eq(child.bo.buftype, 'nofile')
  -- Neovim<0.8 should use built-in syntax, while Neovim>=0.8 - tree-sitter
  if child.fn.has('nvim-0.8') == 0 then eq(child.bo.syntax, 'help') end

  eq(child.v.hlsearch, 0)
  eq(child.fn.getreg('/'), 'aa')
end

T['builtin.help()']['has customized `choose` modifications'] = function()
  local has_help = function()
    for _, win_id in ipairs(child.api.nvim_tabpage_list_wins(0)) do
      if child.api.nvim_buf_get_option(child.api.nvim_win_get_buf(win_id), 'buftype') == 'help' then return true end
    end
    return false
  end

  local validate = function(key, win_layout, n_tabpages)
    builtin_help()
    type_keys(key)
    eq(child.fn.winlayout()[1], win_layout)
    eq(#child.api.nvim_list_tabpages(), n_tabpages)
    eq(has_help(), true)
    child.cmd('%bw')
  end

  validate('<C-s>', 'col', 1)
  validate('<C-v>', 'row', 1)
  validate('<C-t>', 'leaf', 2)
end

T['builtin.help()']['works for help tags with special characters'] = function()
  child.set_size(15, 80)
  builtin_help()
  set_picker_query({ 'c_CTRL-K' })
  type_keys('<Tab>')
  child.expect_screenshot()
end

T['builtin.help()']['works when help window is already opened'] = function()
  -- Open non-current help window
  child.cmd('help')
  child.cmd('wincmd w')

  builtin_help()

  -- Should open help in already opened help window (just like `:help`)
  type_keys('<CR>')
  child.expect_screenshot()
  eq(#child.api.nvim_list_wins(), 2)
end

T['builtin.help()']['can be properly aborted'] = function()
  builtin_help()
  type_keys('<C-c>')
  eq(#child.api.nvim_list_wins(), 1)
end

T['builtin.help()']['handles consecutive applications'] = function()
  builtin_help()
  set_picker_query({ ':help' })
  type_keys('<CR>')

  builtin_help()
  set_picker_query({ ':helpg' })
  type_keys('<CR>')

  child.expect_screenshot()
end

T['builtin.help()']['works with `builtin.resume()`'] = function()
  builtin_help()
  set_picker_query({ ':help' })
  type_keys('<CR>')
  sleep(2)
  child.expect_screenshot()

  child.cmd('close')
  eq(#child.api.nvim_list_wins(), 1)

  child.lua_notify('MiniPick.builtin.resume()')
  type_keys('<CR>')
  sleep(2)
  child.expect_screenshot()
end

T['builtin.help()']['respects `opts`'] = function()
  builtin_help({}, { source = { name = 'My name' } })
  validate_picker_option('source.name', 'My name')
end

local mock_opened_buffers = function()
  child.cmd('edit ' .. real_file('b.txt'))
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(false, true)
  child.cmd('edit ' .. real_file('LICENSE'))
end

T['builtin.buffers()'] = new_set({ hooks = { pre_case = mock_opened_buffers } })

local builtin_buffers = forward_lua_notify('MiniPick.builtin.buffers')

T['builtin.buffers()']['works'] = function()
  child.set_size(10, 70)

  -- Should show no items for empty query
  child.lua_notify([[_G.buffers_item = MiniPick.builtin.buffers()]])

  -- Should use icons by default
  child.expect_screenshot()

  -- Should set correct name
  validate_picker_option('source.name', 'Buffers')

  -- Should return chosen value
  local item = get_picker_matches().current
  type_keys('<CR>')
  eq(child.lua_get('_G.buffers_item'), item)
end

T['builtin.buffers()']['respects `local_opts.include_current`'] = function()
  child.set_size(10, 70)
  builtin_buffers({ include_current = false })
  child.expect_screenshot()
end

T['builtin.buffers()']['respects `local_opts.include_unlisted`'] = function()
  builtin_buffers({ include_unlisted = true })
  child.expect_screenshot()
end

T['builtin.buffers()']['respects `source.show` from config'] = function()
  -- A recommended way to disable icons
  child.lua('MiniPick.config.source.show = MiniPick.default_show')
  builtin_buffers()
  child.expect_screenshot()
end

T['builtin.buffers()']['respects `opts`'] = function()
  builtin_buffers({}, { source = { name = 'My name' } })
  validate_picker_option('source.name', 'My name')
end

T['builtin.cli()'] = new_set({ hooks = { pre_case = mock_spawn } })

local builtin_cli = forward_lua_notify('MiniPick.builtin.cli')

T['builtin.cli()']['works'] = function()
  mock_cli_return({ 'aa', 'bb' })
  child.lua_notify([[_G.cli_item = MiniPick.builtin.cli({ command = { 'echo', 'xx\nyy' } })]])

  -- - Sleep as items are set inside `schedule_wrap`ed function
  sleep(1)
  eq(get_picker_items(), { 'aa', 'bb' })

  -- Should set correct name
  validate_picker_option('source.name', 'CLI (echo)')

  -- Should return chosen value
  type_keys('<CR>')
  eq(child.lua_get('_G.cli_item'), 'aa')
end

T['builtin.cli()']['respects `local_opts.postprocess`'] = function()
  mock_cli_return({ 'aa', 'bb' })
  child.lua([[_G.postprocess = function(...) _G.args = { ... }; return { 'x', 'y', 'z' } end]])
  child.lua_notify([[MiniPick.builtin.cli({ command = { 'echo', 'xx\nyy' }, postprocess = postprocess })]])
  sleep(1)
  eq(child.lua_get('_G.args'), { { 'aa', 'bb' } })
  eq(get_picker_items(), { 'x', 'y', 'z' })
end

T['builtin.cli()']['respects `local_opts.spawn_opts`'] = function()
  builtin_cli({ command = { 'echo', 'aa\nbb' }, spawn_opts = { env = { AAA = 'xxx' } } })
  eq(get_spawn_log()[1].options, { args = { 'aa\nbb' }, env = { AAA = 'xxx' } })
end

T['builtin.cli()']['respects `opts.source.cwd` for cli spawn'] = function()
  local command = { 'echo', 'aa\nbb' }
  local test_dir_absolute = full_path(test_dir)

  local validate = function(local_opts, opts, ref_cwd, source_cwd)
    builtin_cli(local_opts, opts)
    validate_picker_option('source.cwd', source_cwd or ref_cwd)
    eq(get_spawn_log()[1].options.cwd, ref_cwd)

    -- Cleanup
    type_keys('<C-c>')
    clear_spawn_log()
  end

  -- Should use it as `spawn_opts.cwd` if it is not present
  validate({ command = command }, { source = { cwd = test_dir } }, test_dir_absolute)
  validate(
    { command = command, spawn_opts = { cwd = real_files_dir } },
    { source = { cwd = test_dir } },
    full_path(real_files_dir),
    test_dir_absolute
  )
end

T['builtin.cli()']['respects `opts`'] = function()
  builtin_cli({}, { source = { name = 'My name' } })
  validate_picker_option('source.name', 'My name')
end

T['builtin.resume()'] = new_set()

local builtin_resume = forward_lua_notify('MiniPick.builtin.resume')

T['builtin.resume()']['works'] = function()
  local items = { 'a', 'b', 'bb' }
  start_with_items(items)
  type_keys('b')
  eq(get_picker_matches().all, { 'b', 'bb' })
  type_keys('<CR>')

  make_event_log()
  child.cmd('au User MiniPickStart lua _G.track_event()')

  child.lua_notify('_G.resume_item = MiniPick.builtin.resume()')

  -- User event should be triggered when all elements are usually set
  eq(child.lua_get('_G.event_log'), { 2 })

  -- Should preserve as much as state as possible from latest picker
  child.expect_screenshot()
  eq(get_picker_items(), items)
  eq(get_picker_matches().all, { 'b', 'bb' })
  eq(get_picker_query(), { 'b' })

  type_keys('<C-u>')
  eq(get_picker_matches().all, items)
  type_keys('a')
  eq(get_picker_matches().all, { 'a' })

  -- Should return value
  type_keys('<CR>')
  eq(child.lua_get('_G.resume_item'), 'a')
end

T['builtin.resume()']['can be called after previous picker was aborted'] = function()
  start_with_items({ 'aa', 'bb' })
  type_keys('a', '<C-c>')

  builtin_resume()
  eq(get_picker_query(), { 'a' })
  eq(get_picker_matches().all, { 'aa' })
  eq(get_picker_items(), { 'aa', 'bb' })
end

T['builtin.resume()']['always starts in main view'] = function()
  start_with_items({ 'a' })
  type_keys('<Tab>')
  validate_picker_view('preview')
  type_keys('<C-c>')

  builtin_resume()
  validate_picker_view('main')

  type_keys('<S-Tab>')
  validate_picker_view('info')
  type_keys('<C-c>')

  builtin_resume()
  validate_picker_view('main')
end

T['builtin.resume()']['preserves current working directory'] = function()
  local dir_1, dir_2 = full_path(test_dir), full_path(real_files_dir)
  child.fn.chdir(dir_1)
  start_with_items({ 'a' })
  validate_picker_option('source.cwd', full_path(dir_1))
  type_keys('<C-c>')

  child.fn.chdir(dir_2)
  builtin_resume()
  validate_picker_option('source.cwd', full_path(dir_1))
end

T['builtin.resume()']['preserves query cache'] = function()
  local validate_match_calls = make_match_with_count()
  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b', 'bb' }, match = _G.match_with_count },
    options = { use_cache = true },
  })]])
  validate_match_calls(0, { 1, 2, 3 })

  type_keys('b')
  validate_match_calls(1, { 2, 3 })

  type_keys('b')
  validate_match_calls(2, { 3 })

  -- Close and resume
  type_keys('<C-c>')
  builtin_resume()
  validate_match_calls(2, { 3 })

  type_keys('<BS>')
  validate_match_calls(2, { 2, 3 })

  type_keys('<BS>')
  validate_match_calls(2, { 1, 2, 3 })
end

T['builtin.resume()']['preserves marked items'] = function()
  start_with_items({ 'aa', 'bb' })
  type_keys('<C-x>', '<C-c>')

  builtin_resume()
  eq(get_picker_matches().marked_inds, { 1 })
end

T['builtin.resume()']['recomputes target window'] = function()
  local win_id_1, win_id_2 = setup_windows_pair()

  start_with_items({ 'a' })
  eq(get_picker_state().windows.target, win_id_1)
  type_keys('<C-c>')

  child.api.nvim_set_current_win(win_id_2)
  builtin_resume()
  eq(get_picker_state().windows.target, win_id_2)
end

T['builtin.resume()']['can be called consecutively'] = function()
  local validate = function(query, matches, items)
    eq(get_picker_query(), query)
    eq(get_picker_matches().all, matches)
    eq(get_picker_items(), items)
  end

  start_with_items({ 'aa', 'bb' })
  type_keys('a')
  validate({ 'a' }, { 'aa' }, { 'aa', 'bb' })
  type_keys('<C-c>')

  builtin_resume()
  type_keys('<C-u>', 'b')
  validate({ 'b' }, { 'bb' }, { 'aa', 'bb' })
  type_keys('<C-c>')

  builtin_resume()
  type_keys('b')
  validate({ 'b', 'b' }, { 'bb' }, { 'aa', 'bb' })
  type_keys('<C-c>')
end

T['builtin.resume()']["restores 'cmdheight'"] = function()
  start_with_items({ 'a' }, 'My name')
  type_keys('<C-c>')

  local validate = function(cmdheight)
    child.o.cmdheight = cmdheight
    builtin_resume()
    -- Should *temporarily* force 'cmdheight=1' to both have place where to hide
    -- cursor (in case of `cmdheight=0`) and increase available space for picker
    eq(child.o.cmdheight, 1)
    type_keys('<C-c>')
    eq(child.o.cmdheight, cmdheight)
  end

  validate(3)

  if child.fn.has('nvim-0.8') == 0 then return end
  validate(0)
end

T['builtin.resume()']['validates if no picker was previously called'] = function()
  expect.error(function() child.lua('MiniPick.builtin.resume()') end, 'no picker to resume')
end

T['registry'] = new_set()

T['registry']['works'] = function()
  eq(child.lua_get('type(MiniPick.registry)'), 'table')

  -- All methods from `builtin` should be present
  local builtin_methods = child.lua_get('vim.tbl_keys(MiniPick.builtin)')
  table.sort(builtin_methods)
  local registry_methods = child.lua_get('vim.tbl_keys(MiniPick.registry)')
  table.sort(registry_methods)
  eq(builtin_methods, registry_methods)

  local actual_types = child.lua_get('vim.tbl_map(type, MiniPick.registry)')
  local ref_types = {}
  for _, key in ipairs(builtin_methods) do
    ref_types[key] = 'function'
  end
  eq(actual_types, ref_types)
end

T['registry']['should contain values from `MiniExtra.pickers` if present'] = function()
  unload_module()
  child.lua([[package.loaded['mini.pick'] = nil]])

  child.lua('_G.MiniExtra = { pickers = { miniextra_method = function() end } }')
  load_module()
  eq(child.lua_get('type(MiniPick.registry.miniextra_method)'), 'function')
end

T['registry']['is not reloaded in `setup()`'] = function()
  child.lua([[MiniPick.registry.custom = function() end]])
  child.lua([[require('mini.pick').setup()]])
  eq(child.lua_get('type(MiniPick.registry.custom)'), 'function')
end

T['get_picker_items()'] = new_set()

T['get_picker_items()']['works'] = function()
  local items = { 'aa', { text = 'bb' } }
  start_with_items(items)
  child.lua('_G.res = MiniPick.get_picker_items()')
  eq(child.lua_get('_G.res'), items)

  -- Returns copy
  child.lua([[_G.res[2].text = 'xx']])
  eq(child.lua_get('MiniPick.get_picker_items()'), items)

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(get_picker_items(), vim.NIL)
end

T['get_picker_items()']['handles callables'] = function()
  -- Should return actual `items` after global callable expansion
  child.lua_notify([[MiniPick.start({ source = { items = function() return { 'aa' } end } })]])
  eq(get_picker_items(), { 'aa' })
  type_keys('<C-c>')

  -- Should not expand callable item
  child.lua_notify([[MiniPick.start({ source = { items = { function() return 'aa' end } } })]])
  eq(child.lua_get('type(MiniPick.get_picker_items()[1])'), 'function')
end

T['get_picker_stritems()'] = new_set()

T['get_picker_stritems()']['works'] = function()
  local items, stritems = { 'aa', { text = 'bb' } }, { 'aa', 'bb' }
  start_with_items(items)
  child.lua('_G.res = MiniPick.get_picker_stritems()')
  eq(child.lua_get('_G.res'), stritems)

  -- Returns copy
  child.lua([[_G.res[2] = 'xx']])
  eq(child.lua_get('MiniPick.get_picker_stritems()'), stritems)

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(get_picker_stritems(), vim.NIL)
end

T['get_picker_stritems()']['handles callables'] = function()
  -- Should always return array of strings
  child.lua_notify([[MiniPick.start({ source = { items = function() return { 'aa' } end } })]])
  eq(get_picker_stritems(), { 'aa' })
  type_keys('<C-c>')

  child.lua_notify([[MiniPick.start({ source = { items = { function() return 'aa' end } } })]])
  eq(get_picker_stritems(), { 'aa' })
end

T['get_picker_stritems()']["ignores 'ignorecase'"] = function()
  child.o.ignorecase = true
  start_with_items({ 'ab', 'Ab', 'AB' })
  eq(get_picker_stritems(), { 'ab', 'Ab', 'AB' })
end

T['get_picker_matches()'] = new_set()

T['get_picker_matches()']['works'] = function()
  local items = { { text = 'aa' }, 'bb', 'cc' }
  start_with_items(items)
  child.lua('_G.res = MiniPick.get_picker_matches()')

  local ref =
    { all = items, all_inds = { 1, 2, 3 }, current = items[1], current_ind = 1, marked = {}, marked_inds = {} }
  eq(child.lua_get('_G.res'), ref)

  -- Returns copy
  child.lua([[_G.res.all[1], _G.res.all_inds[1] = 'xx', 100]])
  child.lua([[_G.res.current, _G.res.current_ind = 'yy', 200]])
  child.lua([[_G.res.marked[1], _G.res.marked_inds[1] = 'tt', 300]])
  eq(get_picker_matches(), ref)
end

T['get_picker_matches()']['reacts to change in all matches'] = function()
  local validate = function(ref_all, ref_all_inds)
    local matches = get_picker_matches()
    eq(matches.all, ref_all)
    eq(matches.all_inds, ref_all_inds)
  end

  local items = { 'a', 'bb', 'b' }
  start_with_items(items)
  validate(items, { 1, 2, 3 })

  type_keys('b')
  validate({ 'bb', 'b' }, { 2, 3 })

  type_keys('b')
  validate({ 'bb' }, { 2 })

  type_keys('x')
  validate({}, {})
end

T['get_picker_matches()']['reacts to change in current match'] = function()
  local validate = function(ref_current, ref_current_ind)
    local matches = get_picker_matches()
    eq(matches.current, ref_current)
    eq(matches.current_ind, ref_current_ind)
  end

  local items = { 'a', 'b', 'c' }
  start_with_items(items)
  validate(items[1], 1)

  type_keys('<C-n>')
  validate(items[2], 2)

  type_keys('<C-p>')
  validate(items[1], 1)
end

T['get_picker_matches()']['reacts to change in marked matches'] = function()
  local validate = function(ref_marked, ref_marked_inds)
    local matches = get_picker_matches()
    eq(matches.marked, ref_marked)
    eq(matches.marked_inds, ref_marked_inds)
  end

  local items = { 'a', 'b', 'c' }
  start_with_items(items)
  validate({}, {})

  type_keys('<C-x>')
  validate({ items[1] }, { 1 })

  type_keys('<C-n>', '<C-n>', '<C-x>')
  validate({ items[1], items[3] }, { 1, 3 })
end

T['get_picker_matches()']['handles no matches'] = function()
  -- When no active picker
  eq(get_picker_matches(), vim.NIL)

  -- When no items are set
  start_with_items()
  eq(get_picker_items(), vim.NIL)
  eq(get_picker_matches(), {})

  -- When `items` is empty table
  set_picker_items({})
  eq(get_picker_items(), {})
  eq(get_picker_matches(), {})
end

T['get_picker_opts()'] = new_set()

T['get_picker_opts()']['works'] = function()
  child.lua('MiniPick.config.window.config = { col = 2 }')
  child.lua('_G.choose = function(item) print(item) end')
  child.lua_notify([[MiniPick.start({ source = { items = { 'a', 'b' }, name = 'My name', choose = _G.choose } })]])

  child.lua([[_G.res = MiniPick.get_picker_opts()]])

  local validate_as_config = function(field)
    local lua_cmd = string.format('vim.deep_equal(_G.res.%s, MiniPick.config.%s)', field, field)
    eq(child.lua_get(lua_cmd), true)
  end

  validate_as_config('delay')
  validate_as_config('mappings')
  validate_as_config('options')
  validate_as_config('config')

  -- - Not supplied `source` callables should be inferred
  eq(child.lua_get('_G.res.source.items'), { 'a', 'b' })
  eq(child.lua_get('_G.res.source.name'), 'My name')
  eq(child.lua_get('_G.res.source.cwd'), full_path(child.fn.getcwd()))

  eq(child.lua_get('_G.res.source.match == MiniPick.default_match'), true)
  eq(child.lua_get('_G.res.source.show == MiniPick.default_show'), true)
  eq(child.lua_get('_G.res.source.preview == MiniPick.default_preview'), true)
  eq(child.lua_get('_G.res.source.choose == _G.choose'), true)
  eq(child.lua_get('_G.res.source.choose_marked == MiniPick.default_choose_marked'), true)

  -- Returns copy
  child.lua([[_G.res.delay.busy, _G.res.source.name = -10, 'Hello']])
  child.lua('_G.opts_2 = MiniPick.get_picker_opts()')
  eq(child.lua_get('_G.opts_2.delay.busy == MiniPick.config.delay.busy'), true)

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(child.lua_get('MiniPick.get_picker_opts()'), vim.NIL)
end

T['get_picker_state()'] = new_set()

T['get_picker_state()']['works'] = function()
  local items = { { text = 'aa' }, 'bb', 'cc' }
  start_with_items(items)
  child.lua('_G.res = MiniPick.get_picker_state()')
  local res = child.lua_get('_G.res')

  eq(child.api.nvim_buf_is_valid(res.buffers.main), true)
  eq(child.api.nvim_win_is_valid(res.windows.main), true)
  eq(child.api.nvim_win_is_valid(res.windows.target), true)
  eq(res.caret, 1)
  eq(res.is_busy, false)

  -- Returns copy
  child.lua([[_G.res.buffers.main, _G.res.windows.main = -100, -101]])
  local state = get_picker_state()
  eq(child.api.nvim_buf_is_valid(state.buffers.main), true)
  eq(child.api.nvim_win_is_valid(state.windows.main), true)

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(get_picker_state(), vim.NIL)
end

T['get_picker_state()']['reacts to creation of preview and info views'] = function()
  local validate = function(ref)
    local actual = vim.tbl_map(function(x)
      if x == nil then return nil end
      return child.api.nvim_buf_is_valid(x)
    end, get_picker_state().buffers)
    eq(actual, ref)
  end

  start_with_items({ 'a', 'b', 'c' })
  validate({ main = true, preview = nil, info = nil })

  type_keys('<Tab>')
  validate({ main = true, preview = true, info = nil })

  type_keys('<S-Tab>')
  -- - Preview buffers have 'bufhidden' set to 'wipe', so become not valid
  validate({ main = true, preview = false, info = true })

  type_keys('<Tab>')
  -- - Info buffers are persistent during picker session
  validate({ main = true, preview = true, info = true })
end

T['get_picker_state()']['reacts to change in target window'] = function()
  local win_id_1, win_id_2 = setup_windows_pair()

  start_with_items()
  eq(get_picker_state().windows.target, win_id_1)

  child.lua(string.format('MiniPick.set_picker_target_window(%d)', win_id_2))
  eq(get_picker_state().windows.target, win_id_2)
end

T['get_picker_state()']['properly detects when picker is busy'] = function()
  child.lua([[_G.match_defer = function()
    local f = function()
      local co = coroutine.running()
      vim.defer_fn(function() coroutine.resume(co) end, 10)
      coroutine.yield()

      MiniPick.set_picker_match_inds({ 1 })
    end

    coroutine.resume(coroutine.create(f))
  end]])
  child.lua_notify('MiniPick.start({ source = { match = match_defer } })')

  -- Between starting picker and first setting items
  eq(get_picker_state().is_busy, true)
  set_picker_items({ 'a', 'b' }, { do_match = false })
  eq(get_picker_state().is_busy, false)

  -- Between starting match and displaying its results
  type_keys('a')
  eq(get_picker_state().is_busy, true)
  sleep(10 + 10)
  eq(get_picker_state().is_busy, false)
end

T['get_picker_state()']['reacts to caret update'] = function()
  start_with_items({ 'a', 'b', 'bb' })
  eq(get_picker_state().caret, 1)

  type_keys('abc')
  eq(get_picker_state().caret, 4)

  type_keys('<Left>')
  eq(get_picker_state().caret, 3)

  type_keys('<BS>')
  eq(get_picker_state().caret, 2)
end

T['get_picker_query()'] = new_set()

T['get_picker_query()']['works'] = function()
  start_with_items()
  child.lua('_G.res = MiniPick.get_picker_query()')
  eq(child.lua_get('_G.res'), {})

  -- Returns copy
  child.lua([[_G.res[1] = 'a']])
  eq(get_picker_query(), {})

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(get_picker_query(), vim.NIL)
end

T['get_picker_query()']['reacts to query update'] = function()
  local items = { 'a', 'b', 'bb' }
  start_with_items(items)

  -- Manual
  eq(get_picker_query(), {})
  type_keys('b')
  eq(get_picker_query(), { 'b' })
  type_keys('b')
  eq(get_picker_query(), { 'b', 'b' })
  type_keys('b')
  eq(get_picker_query(), { 'b', 'b', 'b' })
  type_keys('<BS>')
  eq(get_picker_query(), { 'b', 'b' })
  type_keys('<C-u>')
  eq(get_picker_query(), {})

  -- Programmatic
  set_picker_query({ 'aa', 'bb' })
  eq(get_picker_query(), { 'aa', 'bb' })
end

T['set_picker_items()'] = new_set()

local set_picker_items = forward_lua('MiniPick.set_picker_items')

T['set_picker_items()']['works'] = function()
  start_with_items()
  set_picker_items({ 'a', 'b' })
  eq(get_picker_items(), { 'a', 'b' })

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(get_picker_query(), vim.NIL)
end

T['set_picker_items()']['resets match inds prior to matching'] = function()
  start_with_items({ 'a', 'b', 'bb' })
  type_keys('b')
  eq(get_picker_matches().all_inds, { 2, 3 })

  set_picker_items({ 'b', 'bb', 'a' })
  eq(get_picker_matches().all_inds, { 1, 2 })
end

T['set_picker_items()']['resets marked inds'] = function()
  start_with_items({ 'a', 'b', 'bb' })
  type_keys('<C-x>', '<C-n>', '<C-x>')
  eq(get_picker_matches().marked_inds, { 1, 2 })

  set_picker_items({ 'a', 'b', 'bb' })
  eq(get_picker_matches().marked_inds, {})
end

T['set_picker_items()']['resets query cache'] = function()
  child.lua_notify([[MiniPick.start({ source = { items = { 'a', 'b' } }, options = { use_cache = true } })]])
  type_keys('a')
  eq(get_picker_matches().all_inds, { 1 })
  type_keys('<BS>')

  set_picker_items({ 'x', 'a', 'aa' })
  type_keys('a')
  eq(get_picker_matches().all_inds, { 2, 3 })
end

T['set_picker_items()']['respects `opts.do_match`'] = function()
  local validate_match_calls = make_match_with_count()
  child.lua_notify([[MiniPick.start({ source = { match = _G.match_with_count } })]])
  validate_match_calls(0, nil)

  set_picker_items({ 'a', 'b' }, { do_match = false })
  validate_match_calls(0, { 1, 2 })

  type_keys('a')
  validate_match_calls(1, { 1 })

  set_picker_items({ 'aa', 'bb' }, { do_match = false })
  validate_match_calls(1, { 1, 2 })
end

T['set_picker_items()']['respects `opts.querytick`'] = function()
  -- Should check every `delay.async` milliseconds if global querytick is the
  -- same as supplied. If not - abort without setting items.
  child.lua('MiniPick.config.delay.async = 1')

  start_with_items()
  set_picker_items(many_items, { querytick = -1 })
  eq(get_picker_items(), vim.NIL)
end

T['set_picker_items()']['does not block picker'] = function()
  child.lua([[
    _G.log = {}
    _G.log_func = function()
      local entry = { is_busy = MiniPick.get_picker_state().is_busy, items_type = type(MiniPick.get_picker_items()) }
      table.insert(_G.log, entry)
    end
    _G.mappings = { append_log = { char = 'l', func = _G.log_func } }
  ]])
  child.lua_notify('MiniPick.start({ mappings = _G.mappings, delay = { async = 1 } })')

  -- Set many items and start typing right away. Key presses should be
  -- processed right away even though there is an items preprocessing is going.
  set_picker_items(many_items)
  type_keys('l')
  sleep(1)
  stop()
  eq(child.lua_get('_G.log'), { { is_busy = true, items_type = 'nil' } })
end

T['set_picker_items()']['validates arguments'] = function()
  start_with_items()
  expect.error(function() set_picker_items(1) end, '`items`.*array')
end

T['set_picker_items_from_cli()'] = new_set({ hooks = { pre_case = mock_spawn } })

local set_picker_items_from_cli = function(...)
  -- Work around tuples and callables being not transferrable through RPC
  local tuple = child.lua(
    [[local process, pid = MiniPick.set_picker_items_from_cli(...)
      local process_keys = vim.tbl_keys(process)
      table.sort(process_keys)
      return { process_keys, pid }]],
    { ... }
  )
  return unpack(tuple)
end

local test_command = { 'echo', 'a\nb\nc' }

T['set_picker_items_from_cli()']['works'] = function()
  start_with_items()
  mock_stdout_feed({ 'abc\ndef\n', 'ghi' })
  local process_keys, pid = set_picker_items_from_cli({ 'command', 'arg1', 'arg2' })

  -- Should actually set picker items
  eq(get_picker_items(), { 'abc', 'def', 'ghi' })

  -- Should properly call `vim.spawn`
  validate_spawn_log({ { executable = 'command', options = { args = { 'arg1', 'arg2' } } } })

  -- Should properly handle process and stdout
  eq(get_process_log(), { 'Stdout Stdout_1 was closed.', 'Process Pid_1 was closed.' })

  -- Should return proper data
  eq(process_keys, { 'close', 'pid' })
  eq(pid, 'Pid_1')
end

T['set_picker_items_from_cli()']['can override items'] = function()
  start_with_items({ 'a', 'b', 'c' })
  mock_stdout_feed({ 'd\ne\nf' })
  set_picker_items_from_cli({ 'echo' })
  eq(get_picker_items(), { 'd', 'e', 'f' })
end

T['set_picker_items_from_cli()']['can be called without active picker'] = function()
  expect.no_error(function()
    local output = child.lua_get([[MiniPick.set_picker_items_from_cli({ 'echo', '1\n2\n' }, {})]])
    eq(output, vim.NIL)
  end)
end

T['set_picker_items_from_cli()']['correctly processes stdout feed'] = function()
  -- Should stich items together without adding '\n'
  start_with_items()
  mock_stdout_feed({ 'aa\n', 'bb', 'cc\n', 'dd', '\nee' })
  set_picker_items_from_cli(test_command)
  eq(get_picker_items(), { 'aa', 'bbcc', 'dd', 'ee' })
end

T['set_picker_items_from_cli()']['correctly detects error in stdout feed'] = function()
  start_with_items()
  mock_stdout_feed({ 'aa\n', 'bb', { err = 'Test stdout error' } })
  expect.error(function() set_picker_items_from_cli(test_command) end, 'Test stdout error')
end

T['set_picker_items_from_cli()']['has default postprocess'] = function()
  -- Should remove all trailing empty lines
  start_with_items()
  mock_stdout_feed({ 'aa\nbb \n  \n\t\n\n\n' })
  set_picker_items_from_cli(test_command)
  eq(get_picker_items(), { 'aa', 'bb ', '  ', '\t' })
end

T['set_picker_items_from_cli()']['respects `opts.postprocess`'] = function()
  start_with_items()
  mock_stdout_feed({ 'aa\nbb\n' })
  child.lua([[MiniPick.set_picker_items_from_cli(
    { 'echo', 'aa\nbb' },
    { postprocess = function(lines)
        _G.postprocess_input = lines
        -- Should be possible to call `vim.fn` functions inside of it
        local n_chars = vim.fn.strchars(lines[1])
        -- Can return any number of items
        return { 'item 1', 'item 2', 'item 3', 'item 4' }
      end
    }
  )]])
  eq(get_picker_items(), { 'item 1', 'item 2', 'item 3', 'item 4' })
  eq(child.lua_get('_G.postprocess_input'), { 'aa', 'bb', '' })
end

T['set_picker_items_from_cli()']['respects `opts.set_item_opts`'] = function()
  child.lua('MiniPick.set_picker_items = function(...) _G.args = { ... } end')
  start_with_items()
  mock_stdout_feed({ 'aa\nbb' })
  set_picker_items_from_cli(test_command, { set_items_opts = { custom_option = true } })
  eq(child.lua_get('_G.args'), { { 'aa', 'bb' }, { custom_option = true } })
end

T['set_picker_items_from_cli()']['respects `opts.spawn_opts`'] = function()
  start_with_items()
  set_picker_items_from_cli({ 'echo', 'arg1', 'arg2' }, { spawn_opts = { env = { HELLO = 'WORLD' } } })
  validate_spawn_log({
    executable = 'echo',
    options = { args = { 'arg1', 'arg2' }, env = { HELLO = 'WORLD' } },
  }, 1)
end

T['set_picker_items_from_cli()']['forces absolute path of `opts.spawn_opts.cwd`'] = function()
  start_with_items()
  set_picker_items_from_cli({ 'echo', 'arg' }, { spawn_opts = { cwd = 'tests' } })
  validate_spawn_log({
    executable = 'echo',
    options = { args = { 'arg' }, cwd = full_path('tests') },
  }, 1)
end

T['set_picker_items_from_cli()']['validates arguments'] = function()
  start_with_items()
  expect.error(function() set_picker_items_from_cli(1) end, '`command`.*array of strings')
  expect.error(function() set_picker_items_from_cli({}) end, '`command`.*array of strings')
  expect.error(function() set_picker_items_from_cli({ 'a', 2, 'c' }) end, '`command`.*array of strings')
end

T['set_picker_match_inds()'] = new_set()

local set_picker_match_inds = forward_lua('MiniPick.set_picker_match_inds')

T['set_picker_match_inds()']['works'] = function()
  child.lua_notify([[MiniPick.start({
    source = {
      items = { 'a', 'b', 'bb' },
      match = function() MiniPick.set_picker_match_inds({ 2 }) end,
    },
  })]])
  child.expect_screenshot()
  eq(get_picker_matches().all_inds, { 2 })

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(set_picker_match_inds({ 1 }), vim.NIL)
end

T['set_picker_match_inds()']['updates cache'] = function()
  local validate_match_calls = make_match_with_count()
  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b', 'bb' }, match = _G.match_with_count },
    options = { use_cache = true },
  })]])
  validate_match_calls(0, { 1, 2, 3 })

  type_keys('a')
  validate_match_calls(1, { 1 })

  -- - Setting match inds should not trigger `source.match`
  set_picker_match_inds({ 2, 3 })
  validate_match_calls(1, { 2, 3 })

  type_keys('<BS>')
  validate_match_calls(1, { 1, 2, 3 })

  type_keys('a')
  validate_match_calls(1, { 2, 3 })
end

T['set_picker_match_inds()']['sets first index as current'] = function()
  child.lua_notify([[MiniPick.start({ source = { items = { 'a', 'b', 'bb' }, match = function() end } })]])

  type_keys('<C-n>', '<C-n>')
  validate_current_ind(3)

  set_picker_match_inds({ 2, 3 })
  validate_current_ind(2)
end

T['set_picker_match_inds()']['validates arguments'] = function()
  start_with_items()
  expect.error(function() set_picker_match_inds(1) end, '`match_inds`.*array')
  expect.error(function() set_picker_match_inds({ 'a' }) end, '`match_inds`.*numbers')
end

T['set_picker_opts()'] = new_set()

T['set_picker_opts()']['works'] = function()
  local expect_screenshot = function()
    if child.has_float_footer() then child.expect_screenshot_orig() end
  end

  start_with_items({ 'a', 'b', 'bb' })
  expect_screenshot()

  child.lua([[MiniPick.set_picker_opts({ source = { name = 'My name' }, window = { config = { col = 5 } } })]])
  expect_screenshot()

  -- Should rerun match
  child.lua('MiniPick.set_picker_opts({ source = { match = function() return { 2 } end } })')
  eq(get_picker_matches().all_inds, { 2 })
  expect_screenshot()

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(child.lua([[MiniPick.set_picker_opts({ source = { name = 'New name' } })]]), vim.NIL)
end

T['set_picker_target_window()'] = new_set()

T['set_picker_target_window()']['works'] = function()
  local win_id_1, win_id_2 = setup_windows_pair()
  local path = real_file('b.txt')
  start_with_items({ path })
  child.lua(string.format('MiniPick.set_picker_target_window(%d)', win_id_2))
  type_keys('<CR>')

  validate_buf_name(child.api.nvim_win_get_buf(win_id_1), '')
  validate_buf_name(child.api.nvim_win_get_buf(win_id_2), path)

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  local lua_cmd = string.format('MiniPick.set_picker_target_window(%d)', win_id_2)
  eq(child.lua_get(lua_cmd), vim.NIL)
end

T['set_picker_target_window()']['validates arguments'] = function()
  start_with_items()
  expect.error(function() child.lua('MiniPick.set_picker_target_window(-1)') end, '`win_id`.*not a valid window')
end

T['set_picker_query()'] = new_set()

T['set_picker_query()']['works'] = function()
  start_with_items({ 'a', 'b', 'bb' })

  -- Should update querytick
  local querytick = get_querytick()
  set_picker_query({ 'b', 'b' })
  eq(get_querytick(), querytick + 1)

  -- Should match and update visual feedback
  child.expect_screenshot()

  -- Can be called without active picker
  type_keys('<C-c>')
  eq(is_picker_active(), false)
  eq(set_picker_query({ 'a' }), vim.NIL)
end

T['set_picker_query()']['resets caret'] = function()
  start_with_items({ 'a', 'b', 'bb' })
  type_keys('b', 'b', '<Left>')
  eq(get_picker_state().caret, 2)

  set_picker_query({ 'x', 'x', 'x', 'x' })
  eq(get_picker_state().caret, 5)

  set_picker_query({ 'x' })
  eq(get_picker_state().caret, 2)
end

T['set_picker_query()']['respects cache'] = function()
  local validate_match_calls = make_match_with_count()
  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b', 'bb' }, match = _G.match_with_count },
    options = { use_cache = true },
  })]])
  validate_match_calls(0, { 1, 2, 3 })

  -- Should update it
  set_picker_query({ 'b' })
  validate_match_calls(1, { 2, 3 })

  type_keys('<BS>', 'b')
  validate_match_calls(1, { 2, 3 })

  -- Should use it
  type_keys('<BS>')
  set_picker_query({ 'b' })
  validate_match_calls(1, { 2, 3 })
end

T['set_picker_query()']['resets match inds prior to matching'] = function()
  start_with_items({ 'a', 'b', 'bb' })
  type_keys('b')
  eq(get_picker_matches().all_inds, { 2, 3 })

  set_picker_query({ 'a' })
  eq(get_picker_matches().all_inds, { 1 })
end

T['set_picker_query()']['validates arguments'] = function()
  start_with_items()
  expect.error(function() set_picker_query(1) end, '`query`.*array')
  expect.error(function() set_picker_query({ 1 }) end, '`query`.*strings')
end

T['get_querytick()'] = new_set()

local get_querytick = forward_lua('MiniPick.get_querytick')

T['get_querytick()']['works'] = function()
  local init_querytick = get_querytick()
  eq(type(init_querytick), 'number')

  local validate = function(increase) eq(get_querytick(), init_querytick + increase) end

  -- Should increase after start, any query update, and stop, but not on move
  -- - Start
  start_with_items({ 'a', 'b', 'bb' })
  validate(1)

  -- - Query update
  type_keys('a')
  validate(2)

  type_keys('<C-u>')
  validate(3)

  set_picker_query({ 'a', 'b' })
  validate(4)

  type_keys('<BS>')
  validate(5)

  -- - Move
  type_keys('<Left>')
  validate(5)

  type_keys('<C-n>')
  validate(5)

  type_keys('<C-p>')
  validate(5)

  type_keys('<C-f>')
  validate(5)

  -- - Change view
  type_keys('<Tab>')
  validate(5)

  type_keys('<S-Tab>')
  validate(5)

  -- - Stop
  type_keys('<C-c>')
  validate(6)
end

T['get_querytick()']['updates even with enabled cache'] = function()
  child.lua_notify([[MiniPick.start({ source = { items = { 'a', 'b' } }, options = { use_cache = true } })]])
  local init_querytick = get_querytick()

  type_keys('a')
  eq(get_querytick(), init_querytick + 1)

  type_keys('<BS>')
  eq(get_querytick(), init_querytick + 2)

  type_keys('a')
  eq(get_querytick(), init_querytick + 3)
end

T['is_picker_active()'] = new_set()

T['is_picker_active()']['works'] = function()
  eq(is_picker_active(), false)
  start_with_items()
  eq(is_picker_active(), true)
  type_keys('<C-c>')
  eq(is_picker_active(), false)
end

T['poke_is_picker_active()'] = new_set()

local poke_is_picker_active = forward_lua('MiniPick.poke_is_picker_active')

T['poke_is_picker_active()']['works without running coroutine'] = function()
  eq(poke_is_picker_active(), false)
  start_with_items()
  eq(poke_is_picker_active(), true)
  type_keys('<C-c>')
  eq(poke_is_picker_active(), false)
end

T['poke_is_picker_active()']['works with running coroutine'] = function()
  start_with_items()
  eq(poke_is_picker_active(), true)

  child.lua([[
    -- Poke on next event loop
    local f = function() _G.is_active_poke = MiniPick.poke_is_picker_active() end
    coroutine.resume(coroutine.create(f))
    _G.is_active_direct = MiniPick.is_picker_active()

    -- Detect no poking before
    _G.has_not_poked_yet = _G.is_active_poke == nil
  ]])
  eq(child.lua_get('_G.is_active_direct'), true)
  eq(child.lua_get('_G.has_not_poked_yet'), true)
  eq(child.lua_get('_G.is_active_poke'), true)
end

-- Integration tests ==========================================================
T[':Pick'] = new_set()

T[':Pick']['works'] = function()
  mock_opened_buffers()

  local validate = function(args)
    child.api_notify.nvim_exec('Pick ' .. args, false)
    eq(is_picker_active(), true)
    child.expect_screenshot()
    type_keys('<C-c>')
  end

  validate('buffers')
  validate('buffers include_unlisted=true')
end

T[':Pick']['correctly parses arguments'] = function()
  child.lua('MiniPick.registry.aaa = function(...) _G.args = { ... } end')

  child.cmd([[Pick aaa b='b' c=3 d={x=1,\ y=2}]])
  eq(child.lua_get('_G.args'), { { b = 'b', c = 3, d = { x = 1, y = 2 } } })

  -- Expands arguments
  child.cmd('edit ' .. real_file('b.txt'))
  child.cmd([[Pick aaa basename='%:t' extension='%:e']])
  eq(child.lua_get('_G.args'), { { basename = 'b.txt', extension = 'txt' } })

  -- Throws informative error (here because of not escaped whitespace)
  expect.error(function() child.cmd([[Pick aaa t={ a = 1}]]) end, 'Could not convert.*to table.*t={,')
end

T[':Pick']['has proper complete'] = function()
  child.set_size(10, 20)
  local validate = function(keys)
    type_keys(':Pick ', keys, '<Tab>')
    child.expect_screenshot()
    type_keys('<C-c>')
  end

  validate({})
  validate({ 'f' })
  validate({ 'f x', '<Left>', '<Left>' })
end

T[':Pick']['validates arguments'] = function()
  expect.error(function() child.cmd('Pick aaa') end, 'no picker named "aaa"')
end

T['Overall view'] = new_set()

T['Overall view']['shows prompt'] = function()
  child.set_size(10, 20)
  start_with_items()

  -- Initial
  child.expect_screenshot()

  -- After typical typing
  type_keys('a')
  child.expect_screenshot()
  type_keys(' b')
  child.expect_screenshot()

  -- After moving caret
  type_keys('<Left>')
  child.expect_screenshot()
  type_keys('<Left>')
  child.expect_screenshot()
end

T['Overall view']['uses footer for extra info'] = function()
  if not child.has_float_footer() then return end

  start_with_items({ 'a', 'b', 'bb', 'bbb' }, 'My name')
  child.expect_screenshot_orig()

  -- Should update after matching
  type_keys('b')
  child.expect_screenshot_orig()

  -- Should update after moving
  type_keys('<C-n>')
  child.expect_screenshot_orig()

  -- Should update after marking and unmarking
  type_keys('<C-x>')
  child.expect_screenshot_orig()
  type_keys('<C-x>')
  child.expect_screenshot_orig()

  -- Should correctly show no matches
  type_keys('x')
  child.expect_screenshot_orig()
end

T['Overall view']['correctly infers footer empty space'] = function()
  if not child.has_float_footer() then return end

  local validate = function(win_config)
    local lua_cmd = string.format('MiniPick.config.window.config = %s', vim.inspect(win_config))
    child.lua(lua_cmd)
    start_with_items({ 'a' })
    child.expect_screenshot_orig()
    type_keys('<C-c>')
  end

  -- Check both `border = 'double'` and `border = <custom_array>`
  validate({ border = 'double' })
  validate({ border = { '!', '@', '#', '$', '%', '^', '&', '*' } })
  --stylua: ignore
  validate({
    border = {
      { '!', 'Normal' }, { '@', 'Normal' }, { '#', 'Normal' }, { '$', 'Normal' },
      { '%', 'Normal' }, { '^', 'Normal' }, { '&', 'Normal' }, { '*', 'Normal' }
    },
  })
end

T['Overall view']['does not show footer if items are not set'] = function()
  if not child.has_float_footer() then return end
  start_with_items()
  child.expect_screenshot_orig()
end

T['Overall view']['respects `options.content_from_bottom` with footer'] = function()
  if not child.has_float_footer() then return end

  start({ source = { items = { 'a', 'b' } }, options = { content_from_bottom = true } })
  child.expect_screenshot_orig()
end

T['Overall view']['truncates border text'] = function()
  if not child.has_float_footer() then return end

  local validate = function(...)
    child.set_size(...)
    start_with_items({ 'a' }, 'Very long name')
    set_picker_query({ 'very long query' })
    child.expect_screenshot_orig()
    type_keys('<C-c>')
  end

  validate(10, 20)
  -- Should not partially show footer indexes, only in full (when space allows)
  validate(10, 35)
end

T['Overall view']['allows "none" as border'] = function()
  if not child.has_float_footer() then return end

  child.lua([[MiniPick.config.window.config = { border = 'none' }]])
  start_with_items({ 'a' }, 'My name')
  child.expect_screenshot_orig()
end

T['Overall view']["respects tabline, statusline, 'cmdheight'"] = function()
  local validate = function()
    start_with_items({ 'a' }, 'My name')
    child.expect_screenshot()
    type_keys('<C-c>')
  end

  child.set_size(10, 20)

  child.o.showtabline, child.o.laststatus = 2, 2
  validate()

  child.o.showtabline, child.o.laststatus = 2, 0
  validate()

  child.o.showtabline, child.o.laststatus = 0, 2
  validate()

  child.o.showtabline, child.o.laststatus = 0, 0
  validate()
end

T['Overall view']["respects 'cmdheight'"] = function()
  local validate = function(cmdheight)
    child.o.cmdheight = cmdheight
    start_with_items({ 'a' }, 'My name')
    -- Should *temporarily* force 'cmdheight=1' to both have place where to hide
    -- cursor (in case of `cmdheight=0`) and increase available space for picker
    eq(child.o.cmdheight, 1)
    type_keys('<C-c>')
    eq(child.o.cmdheight, cmdheight)
  end

  validate(3)

  if child.fn.has('nvim-0.8') == 0 then return end
  validate(0)
end

T['Overall view']['allows very large dimensions'] = function()
  child.lua('MiniPick.config.window.config = { height = 100, width = 200 }')
  start_with_items({ 'a' }, 'My name')
  child.expect_screenshot()
end

T['Overall view']['uses dedicated highlight groups'] = function()
  start_with_items(nil, 'My name')
  local win_id = get_picker_state().windows.main
  sleep(child.lua_get('MiniPick.config.delay.busy') + 5)

  -- Busy picker
  eq(get_picker_state().is_busy, true)

  local winhighlight = child.api.nvim_win_get_option(win_id, 'winhighlight')
  expect.match(winhighlight, 'NormalFloat:MiniPickNormal')
  expect.match(winhighlight, 'FloatBorder:MiniPickBorderBusy')

  local win_config = child.api.nvim_win_get_config(win_id)
  if child.fn.has('nvim-0.9') == 1 then eq(win_config.title, { { '> ▏', 'MiniPickPrompt' } }) end

  -- Not busy picker
  set_picker_items({ 'a' })
  eq(get_picker_state().is_busy, false)

  winhighlight = child.api.nvim_win_get_option(win_id, 'winhighlight')
  expect.match(winhighlight, 'FloatBorder:MiniPickBorder')

  if child.has_float_footer() then
    win_config = child.api.nvim_win_get_config(win_id)
    local footer = win_config.footer
    eq(footer[1], { ' My name ', 'MiniPickBorderText' })
    eq(footer[2][2], 'MiniPickBorder')
    eq(footer[3], { ' 1|1|1 ', 'MiniPickBorderText' })
  end
end

T['Overall view']['is shown over number and sign columns'] = function()
  child.set_size(10, 20)
  child.o.number, child.o.signcolumn = true, 'yes'
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c', 'd', 'e' })
  start_with_items({ 'a' })
  child.expect_screenshot()
end

T['Main view'] = new_set()

T['Main view']['uses dedicated highlight groups'] = function()
  local validate_extmark = function(extmark_data, line, hl_group)
    eq({ extmark_data[2], extmark_data[4].hl_group }, { line - 1, hl_group })
  end

  child.lua([[MiniPick.config.source.show = function(buf_id, items, query)
    return MiniPick.default_show(buf_id, items, query, { show_icons = true })
  end]])
  start_with_items({ real_file('b.txt'), test_dir, 'marked', 'current' })
  local buf_id = get_picker_state().buffers.main
  type_keys('<C-n>', '<C-n>', '<C-x>', '<C-n>')

  local match_ns_id = child.api.nvim_get_namespaces().MiniPickMatches
  local match_extmarks = child.api.nvim_buf_get_extmarks(buf_id, match_ns_id, 0, -1, { details = true })
  validate_extmark(match_extmarks[1], 3, 'MiniPickMatchMarked')
  validate_extmark(match_extmarks[2], 4, 'MiniPickMatchCurrent')

  type_keys('d', 'i', 'r')

  local ranges_ns_id = child.api.nvim_get_namespaces().MiniPickRanges
  local ranges_extmarks = child.api.nvim_buf_get_extmarks(buf_id, ranges_ns_id, 0, -1, { details = true })
  validate_extmark(ranges_extmarks[1], 1, 'MiniPickIconFile')
  validate_extmark(ranges_extmarks[2], 1, 'MiniPickMatchRanges')
  validate_extmark(ranges_extmarks[3], 1, 'MiniPickMatchRanges')
  validate_extmark(ranges_extmarks[4], 1, 'MiniPickMatchRanges')
  validate_extmark(ranges_extmarks[5], 2, 'MiniPickIconDirectory')
  validate_extmark(ranges_extmarks[6], 2, 'MiniPickMatchRanges')
  validate_extmark(ranges_extmarks[7], 2, 'MiniPickMatchRanges')
  validate_extmark(ranges_extmarks[8], 2, 'MiniPickMatchRanges')
end

T['Main view']['works with `content_from_bottom`=true'] = function()
  child.set_size(10, 30)
  child.lua([[MiniPick.config.options.content_from_bottom = true]])
  local items = { 'a', 'b', 'bb', 'x1', 'x2', 'x3', 'x4', 'x5', 'x6', 'x7' }

  local validate = function()
    child.expect_screenshot()

    type_keys('<C-p>')
    child.expect_screenshot()

    type_keys('b')
    child.expect_screenshot()

    type_keys('<C-p>')
    child.expect_screenshot()

    type_keys('<C-p>')
    child.expect_screenshot()

    type_keys('<C-c>')
  end

  -- With `default_show`
  start_with_items(items)
  validate()

  -- With custom `show`
  local lua_cmd = string.format(
    [[_G.custom_show = function(buf_id, items, query)
        local lines = vim.tbl_map(function(x) return 'Item ' .. x end, items)
        -- Lines should still be set as if direction is from top
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
      end

      MiniPick.start({ source = { items = %s, show = _G.custom_show } })]],
    vim.inspect(items)
  )
  child.lua_notify(lua_cmd)
  validate()
end

T['Main view']['shows marked items across queries'] = function()
  child.set_size(10, 20)
  start_with_items({ 'a', 'ab', 'b', 'bb' })
  type_keys('a', 'b', '<C-x>', '<C-u>')
  child.expect_screenshot()
  type_keys('b')
  child.expect_screenshot()
end

T['Main view']['supports vertical scroll'] = function()
  child.set_size(10, 15)

  local items = {}
  for i = 1, 100 do
    items[i] = 'Very big line ' .. i
  end
  start_with_items(items)
  validate_current_ind(1)

  local height = child.api.nvim_win_get_config(get_picker_state().windows.main).height

  -- Vertical scroll should update current item
  type_keys('<C-f>')
  validate_current_ind(height + 1)
  type_keys('<C-f>')
  validate_current_ind(2 * height + 1)

  type_keys('<C-b>')
  validate_current_ind(height + 1)
  type_keys('<C-b>')
  validate_current_ind(1)
end

T['Main view']['supports horizontal scroll'] = function()
  child.set_size(10, 15)

  start_with_items({ 'Short 1', 'Very long item 2', 'Short 3' })

  -- Horizontal scroll should move window view as if cursor is on current item
  type_keys('<C-l>')
  child.expect_screenshot()
  type_keys('<C-l>')
  child.expect_screenshot()
  -- - Can't move further because cursor is already on the last item column
  type_keys('<C-l>')
  child.expect_screenshot()

  -- Moving item at non-trivial right scroll should preserve horizontal
  -- view as much as items width allows
  type_keys('<C-n>')
  child.expect_screenshot()

  -- Should be able to scroll further horizontally on longer
  type_keys('<C-l>')
  child.expect_screenshot()

  -- Should be able to move item from longer to shorter
  type_keys('<C-n>')
  child.expect_screenshot()
end

T['Main view']['properly computes items range to show'] = function()
  child.set_size(7, 15)
  child.lua_notify([[MiniPick.start({
    source = { items = { 1, 2, 3, 4, 5, 6, 7, 8, 9 } },
    window = { config = { height = 4 } },
  })]])

  child.expect_screenshot()
  for _ = 1, 9 do
    type_keys('<C-n>')
    child.expect_screenshot()
  end

  for _ = 1, 9 do
    type_keys('<C-p>')
    child.expect_screenshot()
  end

  for _ = 1, 3 do
    type_keys('<C-f>')
    child.expect_screenshot()
  end

  for _ = 1, 3 do
    type_keys('<C-b>')
    child.expect_screenshot()
  end
end

T['Main view']['does not inherit highlighting from `matchparen`'] = function()
  -- child.set_lines({ 'hello', 'world' })
  -- child.fn.matchaddpos('Comment', { { 1, 1 }, { 1, 3 } })
  child.cmd('packadd matchparen')
  child.set_lines({ '(  )' })
  child.set_cursor(1, 0)
  if #child.fn.getmatches() == 0 then return MiniTest.skip('No "matchparen"') end

  start_with_items({ 'aaaaaaaa' })
  eq(child.fn.getmatches(get_picker_state().windows.main), {})
end

T['Info view'] = new_set()

T['Info view']['works'] = function()
  child.set_size(40, 60)
  child.lua('MiniPick.config.window.config = { height = 40 }')

  start_with_items({ 'a', 'b', 'bb' }, 'My name')
  mock_picker_cwd('mock/current-dir')
  type_keys('<S-Tab>')
  child.expect_screenshot()
end

T['Info view']['respects custom mappings'] = function()
  child.set_size(20, 60)
  child.lua([[MiniPick.config.mappings.custom_action = { char = '<C-d>', func = function() print('Hello') end }]])
  child.lua([[MiniPick.config.mappings.another_action = { char = '<C-e>', func = function() print('World') end }]])
  child.lua([[MiniPick.config.mappings.choose = 'a']])
  child.lua([[MiniPick.config.window.config = { height = 20 }]])

  start_with_items({ 'a', 'b', 'bb' }, 'My name')
  mock_picker_cwd('mock/current-dir')
  type_keys('<S-Tab>')
  child.expect_screenshot()
end

T['Info view']['uses dedicated highlight groups'] = function()
  local validate_extmark = function(extmark_data, line, hl_group)
    eq({ extmark_data[2], extmark_data[4].hl_group }, { line - 1, hl_group })
  end

  child.lua([[MiniPick.config.mappings.custom_action = { char = '<C-d>', func = function() print('Hello') end }]])
  start_with_items({ 'a', 'b', 'bb' }, 'My name')
  type_keys('<S-Tab>')
  local buf_id = get_picker_state().buffers.info

  local header_ns_id = child.api.nvim_get_namespaces().MiniPickHeaders
  local header_extmarks = child.api.nvim_buf_get_extmarks(buf_id, header_ns_id, 0, -1, { details = true })
  validate_extmark(header_extmarks[1], 1, 'MiniPickHeader')
  validate_extmark(header_extmarks[2], 9, 'MiniPickHeader')
  validate_extmark(header_extmarks[3], 12, 'MiniPickHeader')
end

T['Info view']['is updated after moving/marking current item'] = function()
  child.set_size(15, 40)
  start_with_items({ 'a', 'b', 'bb' }, 'My name')
  mock_picker_cwd('mock/current-dir')
  type_keys('<S-Tab>')
  child.expect_screenshot()

  -- Move
  type_keys('<C-n>')
  child.expect_screenshot()

  -- Mark
  type_keys('<C-x>')
  child.expect_screenshot()

  -- Unmark
  type_keys('<C-x>')
  child.expect_screenshot()
end

T['Info view']['switches to main after query update'] = function()
  local validate = function(key)
    type_keys('<S-Tab>')
    validate_picker_view('info')
    type_keys(key)
    validate_picker_view('main')
  end

  start_with_items({ 'a', 'b', 'bb' }, 'My name')

  validate('b')
  validate('<C-u>')
  -- Even if query did not change
  validate('<C-u>')
end

T['Info view']['supports vertical and horizontal scroll'] = function()
  start_with_items({ 'a' })
  mock_picker_cwd('mock/current-dir')
  type_keys('<S-Tab>')

  local validate = function(key)
    type_keys(key)
    child.expect_screenshot()
  end

  validate('<C-l>')
  validate('<C-h>')
  validate('<C-f>')
  validate('<C-b>')
end

T['Preview'] = new_set()

T['Preview']['works'] = function()
  start_with_items({ real_file('b.txt') }, 'My name')
  type_keys('<Tab>')
  child.expect_screenshot()
end

T['Preview']['uses dedicated highlight groups'] = function()
  local preview_ns_id = child.api.nvim_get_namespaces().MiniPickPreview
  local validate_preview_extmark = function(line, pos)
    local buf_id = get_picker_state().buffers.preview
    local preview_extmarks = child.api.nvim_buf_get_extmarks(buf_id, preview_ns_id, 0, -1, { details = true })

    eq({ preview_extmarks[1][2], preview_extmarks[1][4].hl_group }, { line - 1, 'MiniPickPreviewLine' })
    if pos ~= nil then
      eq({ preview_extmarks[2][2], preview_extmarks[2][4].hl_group }, { pos - 1, 'MiniPickPreviewRegion' })
    end
  end

  local path = real_file('b.txt')
  local items = {
    { text = 'Preview line', path = path, lnum = 3 },
    { text = 'Preview position', path = path, lnum = 4, col = 2 },
    { text = 'Preview region', path = path, lnum = 5, col = 3, end_lnum = 6, end_col = 2 },
  }
  start_with_items(items, 'My name')

  type_keys('<Tab>')
  validate_preview_extmark(3, nil, nil)

  type_keys('<C-n>')
  validate_preview_extmark(4, 4)

  type_keys('<C-n>')
  validate_preview_extmark(5, 5)
end

T['Preview']['is updated after moving current item'] = function()
  child.set_size(15, 40)
  start_with_items({ 'a', 'b', 'bb' }, 'My name')
  type_keys('<Tab>')
  child.expect_screenshot()

  type_keys('<C-n>')
  child.expect_screenshot()
end

T['Preview']['remains same during (un)marking'] = function()
  start_with_items({ 'a', 'b', 'bb' }, 'My name')
  type_keys('<Tab>')
  local buf_id = get_picker_state().buffers.preview
  eq(child.api.nvim_get_current_buf(), buf_id)

  type_keys('<C-x>')
  eq(child.api.nvim_get_current_buf(), buf_id)

  type_keys('<C-x>')
  eq(child.api.nvim_get_current_buf(), buf_id)
end

T['Preview']['switches to main after query update'] = function()
  local validate = function(key)
    type_keys('<Tab>')
    validate_picker_view('preview')
    type_keys(key)
    validate_picker_view('main')
  end

  start_with_items({ 'a', 'b', 'bb' }, 'My name')

  validate('b')
  validate('<C-u>')
  -- Even if query did not change
  validate('<C-u>')
end

T['Preview']['supports vertical and horizontal scroll'] = function()
  start_with_items({ real_file('b.txt') })
  type_keys('<Tab>')

  local validate = function(key)
    type_keys(key)
    child.expect_screenshot()
  end

  validate('<C-l>')
  validate('<C-h>')
  validate('<C-f>')
  validate('<C-b>')
end

T['Matching'] = new_set()

local start_with_items_matchlog = function(items)
  child.lua([[
    _G.match_log = {}
    _G.match_with_log = function(...)
      table.insert(_G.match_log, vim.deepcopy({ ... }))
      MiniPick.default_match(...)
    end]])
  local lua_cmd =
    string.format('MiniPick.start({ source = { items = %s, match = _G.match_with_log } })', vim.inspect(items))
  child.lua_notify(lua_cmd)
end

local validate_match_log = function(ref) eq(child.lua_get('_G.match_log'), ref) end
local validate_last_match_log = function(ref) eq(child.lua_get('_G.match_log[#_G.match_log]'), ref) end
local clean_match_log = function() child.lua('_G.match_log = {}') end

T['Matching']['works'] = function()
  start_with_items_matchlog({ 'a', 'b', 'bb' })
  -- - `match()` should be called on start for empty query
  validate_match_log({ { { 'a', 'b', 'bb' }, { 1, 2, 3 }, {} } })
  clean_match_log()

  -- In regular query increase should use previous match inds (for performance)
  type_keys('b')
  validate_match_log({ { { 'a', 'b', 'bb' }, { 1, 2, 3 }, { 'b' } } })
  clean_match_log()

  type_keys('b')
  validate_match_log({ { { 'a', 'b', 'bb' }, { 2, 3 }, { 'b', 'b' } } })
  clean_match_log()

  type_keys('x')
  validate_match_log({ { { 'a', 'b', 'bb' }, { 3 }, { 'b', 'b', 'x' } } })
end

T['Matching']['uses stritems'] = function()
  child.lua_notify([[MiniPick.start({ source = {
    items = { 'a', { text = 'b' }, function() return 'bb' end },
    match = function(...) _G.match_args = { ... }; return { 1 } end,
  }})]])
  eq(child.lua_get('_G.match_args'), { { 'a', 'b', 'bb' }, { 1, 2, 3 }, {} })
end

T['Matching']['uses cache'] = function()
  child.lua('_G.match_n_calls = 0')
  local validate_match_calls = function(n_calls_ref, match_inds_ref)
    eq(child.lua_get('_G.match_n_calls'), n_calls_ref)
    eq(get_picker_matches().all_inds, match_inds_ref)
  end

  child.lua_notify([[_G.match_shrink = function(stritems, match_inds, query)
    _G.match_n_calls = _G.match_n_calls + 1
    if #query == 0 then return { 1, 2, 3, 4 } end
    return vim.list_slice(match_inds, 2, #match_inds)
  end]])

  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'ab', 'b', 'bb' }, match = _G.match_shrink },
    options = { use_cache = true },
  })]])

  -- As all indexes are matched against empty query when setting them,
  -- `match()` should not be called after start
  validate_match_calls(0, { 1, 2, 3, 4 })

  type_keys('b')
  validate_match_calls(1, { 2, 3, 4 })

  type_keys('b')
  validate_match_calls(2, { 3, 4 })

  type_keys('<BS>')
  validate_match_calls(2, { 2, 3, 4 })

  type_keys('<BS>')
  validate_match_calls(2, { 1, 2, 3, 4 })

  type_keys('b')
  validate_match_calls(2, { 2, 3, 4 })

  type_keys('x')
  validate_match_calls(3, { 3, 4 })

  type_keys('<C-u>')
  validate_match_calls(3, { 1, 2, 3, 4 })
end

T['Matching']['resets matched indexes when needed'] = function()
  local items = { 'a', 'b', 'bb' }
  local validate_all_match_inds = function() validate_last_match_log({ items, { 1, 2, 3 }, get_picker_query() }) end

  start_with_items_matchlog(items)

  -- Any deleting
  type_keys('b', 'b')

  type_keys('<BS>')
  validate_all_match_inds()

  type_keys('<C-u>')
  validate_all_match_inds()

  type_keys('b', 'b', '<Left>')

  type_keys('<Del>')
  validate_all_match_inds()

  type_keys('<C-w>')
  validate_all_match_inds()

  -- Adding character inside query
  type_keys('b', '<Left>')
  type_keys('x')
  validate_all_match_inds()

  type_keys('b', 'b', '<Left>')
  type_keys('x')
  validate_all_match_inds()
end

T['Matching']['allows returning wider than input set of match indexes'] = function()
  child.lua_notify([[_G.match_increase = function(stritems, match_inds, query)
    if query[#query] == 'x' then return { 1, 2, 3, 4 } end
    local prompt_pattern = vim.pesc(table.concat(query))
    return vim.tbl_filter(function(i) return stritems[i]:find(prompt_pattern) ~= nil end, match_inds)
  end]])

  child.lua_notify([[MiniPick.start({ source = { items = { 'a', 'ab', 'b', 'bb' }, match = _G.match_increase } })]])
  type_keys('b', 'b')
  eq(get_picker_matches().all_inds, { 4 })

  type_keys('x')
  eq(get_picker_matches().all_inds, { 1, 2, 3, 4 })
end

T['Matching']["respects 'ignorecase' and 'smartcase'"] = function()
  -- Should precompute and supply lowered versions of stritems and query if
  -- case should be ignored. Which to use is computed before every matching.
  local items = { 'ab', 'Ab', 'AB' }
  local items_lowered = { 'ab', 'ab', 'ab' }
  start_with_items_matchlog(items)

  local validate = function(query, ref_state)
    set_picker_query(query)
    local ref_stritems = ref_state == 'lowered' and items_lowered or items
    local ref_query = ref_state == 'lowered' and vim.tbl_map(string.lower, query) or query
    validate_last_match_log({ ref_stritems, { 1, 2, 3 }, ref_query })
    clean_match_log()
    type_keys('<C-u>')
  end

  child.o.ignorecase, child.o.smartcase = false, false
  validate({ 'ab' }, 'non-lowered')
  validate({ 'Ab' }, 'non-lowered')
  validate({ 'AB' }, 'non-lowered')

  child.o.ignorecase, child.o.smartcase = true, false
  validate({ 'ab' }, 'lowered')
  validate({ 'Ab' }, 'lowered')
  validate({ 'AB' }, 'lowered')

  child.o.ignorecase, child.o.smartcase = false, true
  validate({ 'ab' }, 'non-lowered')
  validate({ 'Ab' }, 'non-lowered')
  validate({ 'AB' }, 'non-lowered')

  child.o.ignorecase, child.o.smartcase = true, true
  validate({ 'ab' }, 'lowered')
  validate({ 'Ab' }, 'non-lowered')
  validate({ 'AB' }, 'non-lowered')
end

T['Matching']['uses proper `tolower` for ignoring case'] = function()
  local items, items_lowered = { 'ыф', 'Ыф', 'ЫФ' }, { 'ыф', 'ыф', 'ыф' }
  start_with_items_matchlog(items)

  child.o.ignorecase, child.o.smartcase = true, false
  type_keys('ы')
  validate_last_match_log({ items_lowered, { 1, 2, 3 }, { 'ы' } })
  type_keys('Ф')
  validate_last_match_log({ items_lowered, { 1, 2, 3 }, { 'ы', 'ф' } })
  type_keys('<C-u>')

  child.o.ignorecase, child.o.smartcase = true, true
  type_keys('ы')
  validate_last_match_log({ items_lowered, { 1, 2, 3 }, { 'ы' } })
  type_keys('Ф')
  validate_last_match_log({ items, { 1, 2, 3 }, { 'ы', 'Ф' } })
end

T['Matching']["works with non-default 'regexpengine'"] = function()
  child.o.regexpengine = 1

  -- Determining if query is smartcase should be unaffected
  child.o.ignorecase, child.o.smartcase = true, true
  start_with_items_matchlog({ 'ab', 'Ab', 'AB' })
  type_keys('a')
  validate_last_match_log({ { 'ab', 'ab', 'ab' }, { 1, 2, 3 }, { 'a' } })

  -- Matching keyword should be unaffected
  type_keys(' ', 'b', 'b')
  eq(get_picker_query(), { 'a', ' ', 'b', 'b' })
  type_keys('<C-w>')
  eq(get_picker_query(), { 'a', ' ' })
  type_keys('<C-w>')
  eq(get_picker_query(), { 'a' })
end

T['Key query process'] = new_set()

T['Key query process']['respects mouse click'] = function()
  child.set_size(10, 15)

  -- Should ignore if inside main window
  local validate_press_inside = function(button, row, col)
    child.api.nvim_input_mouse(button, 'press', '', 0, row, col)
    eq(is_picker_active(), true)
  end

  start_with_items({ 'a' })

  -- - Press on all four courners
  validate_press_inside('left', 2, 0)
  validate_press_inside('left', 8, 0)
  validate_press_inside('left', 8, 10)
  validate_press_inside('left', 2, 10)

  -- - Actual button should not matter
  validate_press_inside('right', 2, 0)
  validate_press_inside('middle', 2, 0)

  type_keys('<C-c>')

  -- Should stop picker if outside of main window
  local validate_press_outside = function(button, row, col)
    start_with_items({ 'a' })
    sleep(10)
    child.api.nvim_input_mouse(button, 'press', '', 0, row, col)
    sleep(10)
    eq(is_picker_active(), false)
  end

  validate_press_outside('left', 1, 0)
  validate_press_outside('left', 9, 0)
  validate_press_outside('left', 9, 10)
  validate_press_outside('left', 8, 11)
  validate_press_outside('left', 1, 10)
  validate_press_outside('left', 2, 11)

  validate_press_outside('right', 1, 0)
  validate_press_outside('middle', 1, 0)
end

T['Key query process']['handles not configured key presses'] = function()
  start_with_items({ 'a' })

  -- Should not add them to query
  local validate = function(key)
    type_keys(key)
    eq(get_picker_query(), {})
  end

  validate('<M-a>')
  validate('<S-right>')
  validate('<C-d>')
  validate('\1')
  validate('\31')
end

T['Key query process']['always stops on `<C-c>`'] = function()
  child.api.nvim_set_keymap('n', '<C-c>', '<Cmd>echo 1<CR>', {})
  start_with_items({ 'a' })
  type_keys('<C-c>')
  eq(is_picker_active(), false)
end

T['Caret'] = new_set({ hooks = { pre_case = function() child.set_size(10, 15) end } })

local validate_caret = function(n) eq(get_picker_state().caret, n) end

T['Caret']['works'] = function()
  start_with_items({ 'a' })
  validate_caret(1)

  -- Should move along right edge
  type_keys('a')
  validate_caret(2)

  type_keys('b')
  validate_caret(3)

  -- Should insert character at its place
  type_keys('<Left>', 'c')
  validate_caret(3)
  child.expect_screenshot()

  -- Should delete character at its place
  type_keys('<BS>')
  validate_caret(2)
  child.expect_screenshot()

  type_keys('<Del>')
  validate_caret(2)
  child.expect_screenshot()
end

T['Caret']['moves by query parts'] = function()
  start_with_items({ 'a' })
  set_picker_query({ 'ab', 'cd' })
  validate_caret(3)
  child.expect_screenshot()

  type_keys('<Left>')
  validate_caret(2)
  child.expect_screenshot()

  type_keys('<Left>')
  validate_caret(1)
  child.expect_screenshot()
end

T['Caret']['can not go past query boundaries'] = function()
  start_with_items({ 'a' })
  type_keys('<Left>')
  validate_caret(1)
  type_keys('<Right>')
  validate_caret(1)

  type_keys('a', 'b', '<Right>')
  validate_caret(3)
  type_keys('<Left>', '<Left>', '<Left>')
  validate_caret(1)
end

T['Caret']['works without items'] = function()
  start_with_items()
  type_keys('<Left>')
  validate_caret(1)
  type_keys('<Right>')
  validate_caret(1)
end

T['Choose'] = new_set()

T['Choose']['works for split/tab variations'] = function()
  local validate = function(key)
    local win_id_init = child.api.nvim_get_current_win()
    child.lua_notify([[MiniPick.start({
      source = {
        items = { 'a' },
        choose = function() _G.target_window = MiniPick.get_picker_state().windows.target end,
      },
    })]])

    type_keys(key)
    -- Should create split/tab
    child.expect_screenshot()
    -- Should modify target window
    eq(child.lua_get('_G.target_window') ~= win_id_init, true)

    -- Cleanup
    child.lua('_G.target_window = nil')
  end

  validate('<C-s>')
  validate('<C-v>')
  validate('<C-t>')
end

T['Choose']['works without items'] = function()
  local validate = function(key)
    child.lua_notify('MiniPick.start({ source = { choose = function(...) _G.been_here = true end } })')
    type_keys(key)
    -- Should not do any split/tab
    eq(#child.api.nvim_list_wins(), 1)
    -- Should not call `source.choose()` function
    eq(child.lua_get('_G.been_here'), vim.NIL)
  end

  validate('<CR>')
  validate('<C-s>')
  validate('<C-v>')
  validate('<C-t>')
end

T['Choose']['works with no matching items'] = function()
  local validate = function(key)
    child.lua_notify([[MiniPick.start({
      source = { items = { 'a' }, choose = function(...) _G.been_here = true end },
    })]])
    type_keys('b', key)
    -- Should not do any split/tab
    eq(#child.api.nvim_list_wins(), 1)
    -- Should not call `source.choose()` function
    eq(child.lua_get('_G.been_here'), vim.NIL)
  end

  validate('<CR>')
  validate('<C-s>')
  validate('<C-v>')
  validate('<C-t>')
end

T['Choose']['uses output as "should continue"'] = function()
  local validate = function(key)
    child.lua_notify([[MiniPick.start({
      source = {
        items = { 'a', 'b' },
        choose = function(item) _G.latest_item = item; return item == 'a' end,
        choose_marked = function(items) _G.latest_item = items[#items]; return #items == 1 end,
      },
    })]])

    type_keys(key)
    eq(child.lua_get('_G.latest_item'), 'a')
    eq(is_picker_active(), true)

    type_keys('<C-n>', key)
    eq(child.lua_get('_G.latest_item'), 'b')
    eq(is_picker_active(), false)
  end

  validate('<CR>')
  validate('<C-s>')
  validate('<C-v>')
  validate('<C-t>')

  validate({ '<C-x>', '<M-CR>' })
end

T['Mark'] = new_set()

T['Mark']['works'] = function()
  local validate = function(keys, marked_items)
    child.lua_notify([[MiniPick.start({ source = {
      items = { 'a', 'b', 'bb' },
      choose_marked = function(items) _G.choose_marked_items = items end,
    } })]])
    type_keys(keys)
    type_keys('<M-CR>')
    eq(child.lua_get('_G.choose_marked_items'), marked_items)
    eq(is_picker_active(), false)
  end

  validate({ '<C-x>' }, { 'a' })
  validate({ '<C-x>', '<C-n>', '<C-x>' }, { 'a', 'b' })

  -- Should be returned in the original order, not how they were marked
  validate({ '<C-n>', '<C-x>', '<C-p>', '<C-x>' }, { 'a', 'b' })

  -- Should not return unmarked item
  validate({ '<C-x>', '<C-x>' }, {})

  -- Marked items should be preserved across queries
  validate({ 'b', '<C-n>', '<C-x>', '<BS>', 'a', '<C-x>' }, { 'a', 'bb' })

  -- Works with 'mark_all': mark all if not all marked, unmark otherwise
  validate({ '<C-a>' }, { 'a', 'b', 'bb' })
  validate({ '<C-x>', '<C-a>' }, { 'a', 'b', 'bb' })
  validate({ '<C-a>', '<C-a>' }, {})
end

T['Mark']['works without items set'] = function()
  child.set_size(5, 15)
  start_with_items()
  type_keys('<C-x>')
  type_keys('<C-a>')
  child.expect_screenshot()
end

T['Move'] = new_set()

T['Move']['works'] = function()
  start_with_items({ 'a', 'b', 'bb', 'bbb' })

  -- Next/prev
  type_keys('<C-n>')
  validate_current_ind(2)
  type_keys('<C-n>')
  validate_current_ind(3)
  type_keys('<C-p>')
  validate_current_ind(2)

  -- First
  type_keys('<C-n>')
  validate_current_ind(3)
  type_keys('<C-g>')
  validate_current_ind(1)
end

T['Move']['works with non-overridable keys'] = function()
  start_with_items({ 'a', 'b', 'bb', 'bbb' })

  type_keys('<Down>')
  validate_current_ind(2)
  type_keys('<Down>')
  validate_current_ind(3)
  type_keys('<Up>')
  validate_current_ind(2)
  type_keys('<Down>')
  validate_current_ind(3)
  type_keys('<Home>')
  validate_current_ind(1)
end

T['Move']['next/prev wraps around edges'] = function()
  start_with_items({ 'a', 'b' })

  type_keys('<C-n>')
  validate_current_ind(2)
  type_keys('<C-n>')
  validate_current_ind(1)

  type_keys('<C-p>')
  validate_current_ind(2)
  type_keys('<C-p>')
  validate_current_ind(1)
end

T['Move']['scrolls to edge without wrap and then wraps'] = function()
  start_with_items({ 'a', 'b', 'bb' })

  type_keys('<C-f>')
  validate_current_ind(3)
  type_keys('<C-f>')
  validate_current_ind(1)

  type_keys('<C-b>')
  validate_current_ind(3)
  type_keys('<C-b>')
  validate_current_ind(1)
end

T['Move']['works when no items are set'] = function()
  child.set_size(5, 15)
  start_with_items()
  type_keys('<C-n>')
  type_keys('<C-p>')
  type_keys('<C-g>')
  child.expect_screenshot()
end

T['Paste'] = new_set()

T['Paste']['works'] = function()
  child.set_size(5, 15)
  local validate = function(regcontents, ref_query)
    child.fn.setreg('a', regcontents)
    start_with_items({ 'a' })
    type_keys('<C-r>', 'a')
    eq(get_picker_query(), ref_query)
    child.expect_screenshot()
    type_keys('<C-c>')
  end

  validate('hello', { 'h', 'e', 'l', 'l', 'o' })
  validate('ыфя', { 'ы', 'ф', 'я' })

  -- Should sanitize register content
  validate('a\nb\tc', { 'a', ' ', 'b', ' ', 'c' })
end

T['Paste']['pastes at caret'] = function()
  child.fn.setreg('a', 'hello ')
  start_with_items({ 'a' })
  type_keys('w', 'o', 'r', 'l', 'd')
  type_keys('<Left>', '<Left>', '<Left>', '<Left>', '<Left>')
  type_keys('<C-r>', 'a')
  eq(get_picker_query(), { 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' })
end

T['Paste']['does not error on non-existing register label'] = function()
  start_with_items({ 'a' })
  type_keys('<C-r>', '<C-y>')
  eq(get_picker_query(), {})
  type_keys('a')
  eq(get_picker_query(), { 'a' })
end

T['Paste']['respects `delay.async` when waiting for register label'] = function()
  child.set_size(15, 15)
  child.lua_notify([[
    _G.buf_id, _G.n = vim.api.nvim_get_current_buf(), 0
    local timer = vim.loop.new_timer()
    local f = vim.schedule_wrap(function()
      _G.n = _G.n + 1
      vim.fn.appendbufline(_G.buf_id, '$', { 'Line ' .. _G.n })
    end)
    timer:start(50, 50, f)
  ]])
  local validate = function(n, lines)
    eq(child.lua_get('_G.n'), n)
    eq(child.lua_get('vim.api.nvim_buf_get_lines(_G.buf_id, 0, -1, false)'), lines)
    child.expect_screenshot({ redraw = false })
  end

  child.lua_notify([[MiniPick.start({ source = { items = { 'a' } }, delay = { async = 80 } })]])
  validate(0, { '' })
  type_keys('<C-r>')

  -- Callback should have already been executed, but not redraw
  sleep(50 + 5)
  validate(1, { '', 'Line 1' })

  -- No new callback should have been executed, but redraw should
  sleep(30)
  validate(1, { '', 'Line 1' })

  -- Test that redraw is done repeatedly
  sleep(80)
  validate(3, { '', 'Line 1', 'Line 2', 'Line 3' })
end

T['Refine'] = new_set()

T['Refine']['works'] = function()
  child.set_size(10, 15)
  start_with_items({ 'a', 'ab', 'b', 'ba', 'bb' }, 'My name')

  type_keys('b')
  child.expect_screenshot()

  type_keys('<C-Space>')
  -- - Should use matches in the sorted order, not their original one.
  -- - Also should remove matched ranges highlight.
  child.expect_screenshot()
  -- - Should reset data and update name
  validate_picker_option('source.name', 'My name (Refine)')

  -- Can be used several times
  type_keys('a')
  type_keys('<C-Space>')
  child.expect_screenshot()
  validate_picker_option('source.name', 'My name (Refine 2)')
end

T['Refine']['works with marked'] = function()
  child.set_size(10, 15)
  start_with_items({ 'a', 'b', 'c' }, 'My name')

  type_keys('<C-n>', '<C-x>', '<C-n>', '<C-x>')
  type_keys('<M-Space>')
  eq(get_picker_items(), { 'b', 'c' })
  validate_picker_option('source.name', 'My name (Refine)')

  -- Can be used several times
  type_keys('<C-a>')
  type_keys('<M-Space>')
  eq(get_picker_items(), { 'b', 'c' })
  validate_picker_option('source.name', 'My name (Refine 2)')
end

T['Refine']['uses config match'] = function()
  child.lua_notify([[MiniPick.start({
    source = { items = { 'a', 'b', 'bb' }, name = 'My name', match = function() return { 1, 2, 3 } end },
  })]])

  type_keys('b')
  eq(get_picker_matches().all_inds, { 1, 2, 3 })
  type_keys('<C-Space>')
  type_keys('b')
  eq(get_picker_matches().all_inds, { 2, 3 })
end

T['Refine']['works when no items are set'] = function()
  child.set_size(5, 15)
  start_with_items()
  type_keys('<C-Space>')
  type_keys('<M-Space>')
  child.expect_screenshot()
end

T['Stop'] = new_set()

T['Stop']['triggers User event'] = function()
  child.cmd('au User MiniPickStop lua _G.track_event()')
  local validate = function(key)
    make_event_log()
    start_with_items({ 'a', 'b', 'bb' })
    type_keys('b', key)
    eq(child.lua_get('_G.event_log'), { 2 })
  end

  validate('<Esc>')
  validate('<C-c>')
end

return T
