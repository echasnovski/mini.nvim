local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('notify', config) end
local unload_module = function() child.mini_unload('notify') end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Common test helpers
local get_notif_win_id = function(tabpage_id)
  tabpage_id = tabpage_id or child.api.nvim_get_current_tabpage()
  local all_wins = child.api.nvim_tabpage_list_wins(tabpage_id)
  for _, win_id in ipairs(all_wins) do
    local win_buf = child.api.nvim_win_get_buf(win_id)
    local shows_notifications = child.api.nvim_buf_get_option(win_buf, 'filetype') == 'mininotify'
    if shows_notifications then return win_id end
  end
end

local is_notif_window_shown = function(tabpage_id) return get_notif_win_id(tabpage_id) ~= nil end

-- Common test wrappers
local forward_lua = function(fun_str)
  local lua_cmd = fun_str .. '(...)'
  return function(...) return child.lua_get(lua_cmd, { ... }) end
end

local get = forward_lua('MiniNotify.get')
local get_all = forward_lua('MiniNotify.get_all')

-- Common mocks
local ref_seconds, ref_microseconds = 1703673296, 0.123456
local mock_gettimeofday = function()
  -- Ensure reproducibility of `vim.fn.strftime`
  child.lua([[
    vim.loop.os_setenv('TZ', 'Europe/Kiev')
    vim.cmd('language time en_US.utf8')
  ]])
  local lua_cmd = string.format(
    [[local start, n = %d, -1
      vim.loop.gettimeofday = function()
        n = n + 1
        return start + n, %d
      end]],
    ref_seconds,
    1000000 * ref_microseconds
  )
  child.lua(lua_cmd)
end

-- Output test set ============================================================
local T = new_set({
  hooks = {
    pre_case = function()
      child.setup()

      -- Load module
      load_module()

      -- Make more comfortable screenshots
      child.set_size(7, 45)
      child.o.laststatus = 0
      child.o.ruler = false
    end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  -- Global variable
  eq(child.lua_get('type(_G.MiniNotify)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniNotify'), 1)

  -- Highlight groups
  child.cmd('hi clear')
  load_module()
  local has_highlight = function(group, value) expect.match(child.cmd_capture('hi ' .. group), value) end

  has_highlight('MiniNotifyBorder', 'links to FloatBorder')
  has_highlight('MiniNotifyNormal', 'links to NormalFloat')
  has_highlight('MiniNotifyTitle', 'links to FloatTitle')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniNotify.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniNotify.config.' .. field), value) end

  expect_config('content.format', vim.NIL)
  expect_config('content.sort', vim.NIL)

  expect_config('lsp_progress.enable', true)
  expect_config('lsp_progress.duration_last', 1000)

  expect_config('window.config', {})
  expect_config('window.max_width_share', 0.382)
  expect_config('window.winblend', 25)
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ window = { winblend = 0 } })
  eq(child.lua_get('MiniNotify.config.window.winblend'), 0)
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ content = 'a' }, 'content', 'table')
  expect_config_error({ content = { format = 'a' } }, 'content.format', 'function')
  expect_config_error({ content = { sort = 'a' } }, 'content.sort', 'function')

  expect_config_error({ lsp_progress = 'a' }, 'lsp_progress', 'table')
  expect_config_error({ lsp_progress = { enable = 'a' } }, 'lsp_progress.enable', 'boolean')
  expect_config_error({ lsp_progress = { duration_last = 'a' } }, 'lsp_progress.duration_last', 'number')

  expect_config_error({ window = 'a' }, 'window', 'table')
  expect_config_error({ window = { config = 'a' } }, 'window.config', 'table or callable')
  expect_config_error({ window = { max_width_share = 'a' } }, 'window.max_width_share', 'number')
  expect_config_error({ window = { winblend = 'a' } }, 'window.winblend', 'number')
end

T['make_notify()'] = new_set()

local notify = forward_lua('vim.notify')

T['make_notify()']['works'] = function()
  child.set_size(10, 45)
  mock_gettimeofday()

  child.lua([[
    local level_opts = {
      ERROR = { duration = 300 },
      WARN  = { duration = 250 },
      INFO  = { duration = 200 },
      DEBUG = { duration = 150 },
      TRACE = { duration = 100 },
      OFF   = { duration = 50  },
    }
    vim.notify = MiniNotify.make_notify(level_opts)
  ]])

  local validate_active = function(ref)
    local active = vim.tbl_filter(function(notif) return notif.ts_remove == nil end, get_all())
    eq(vim.tbl_map(function(notif) return notif.msg end, active), ref)
  end

  local levels = child.lua_get('vim.log.levels')

  notify('error', levels.ERROR)
  notify('warn', levels.WARN)
  notify('info', levels.INFO)
  notify('debug', levels.DEBUG)
  notify('trace', levels.TRACE)
  notify('off', levels.OFF)

  child.expect_screenshot()

  -- Should add all notifications to history with proper `level` and `hl_group`
  local history = vim.tbl_map(
    function(notif) return { msg = notif.msg, level = notif.level, hl_group = notif.hl_group } end,
    get_all()
  )
  --stylua: ignore
  eq(history, {
    { msg = 'error', level = 'ERROR', hl_group = 'DiagnosticError' },
    { msg = 'warn',  level = 'WARN',  hl_group = 'DiagnosticWarn' },
    { msg = 'info',  level = 'INFO',  hl_group = 'DiagnosticInfo' },
    { msg = 'debug', level = 'DEBUG', hl_group = 'DiagnosticHint' },
    { msg = 'trace', level = 'TRACE', hl_group = 'DiagnosticOk' },
    { msg = 'off',   level = 'OFF',   hl_group = 'MiniNotifyNormal' },
  })

  -- Should make notifications disappear after configured duration
  validate_active({ 'error', 'warn', 'info', 'debug', 'trace', 'off' })
  sleep(50 + 10)
  validate_active({ 'error', 'warn', 'info', 'debug', 'trace' })
  sleep(50)
  validate_active({ 'error', 'warn', 'info', 'debug' })
  sleep(50)
  validate_active({ 'error', 'warn', 'info' })
  sleep(50)
  validate_active({ 'error', 'warn' })
  sleep(50)
  validate_active({ 'error' })
  sleep(50)
  validate_active({})
end

T['make_notify()']['uses INFO level by default'] = function()
  child.lua([[vim.notify = MiniNotify.make_notify()]])
  notify('Hello')
  local notif = get_all()[1]
  eq(notif.level, 'INFO')
  eq(notif.hl_group, 'DiagnosticInfo')
end

T['make_notify()']['does not show some levels by default'] = function()
  child.lua('vim.notify = MiniNotify.make_notify()')
  notify('debug', child.lua_get('vim.log.levels.DEBUG'))
  notify('trace', child.lua_get('vim.log.levels.TRACE'))
  if child.fn.has('nvim-0.8') == 1 then notify('off', child.lua_get('vim.log.levels.OFF')) end
  eq(get_all(), {})
end

T['make_notify()']['respects `opts.hl_group`'] = function()
  child.lua([[vim.notify = MiniNotify.make_notify({ ERROR = { hl_group = 'Comment' } })]])
  notify('Hello', child.lua_get('vim.log.levels.ERROR'))
  eq(get_all()[1].hl_group, 'Comment')
end

T['make_notify()']['validates arguments'] = function()
  local validate = function(opts, err_pattern)
    expect.error(function() child.lua('MiniNotify.make_notify(...)', { opts }) end, err_pattern)
  end

  local validate_level = function(level)
    validate({ [level] = 1 }, 'Level data.*table')
    validate({ [level] = { duration = 'a' } }, '`duration`.*number')
    validate({ [level] = { hl_group = 1 } }, '`hl_group`.*string')
  end

  validate({ error = {} }, 'Keys.*log level names')

  validate_level('ERROR')
  validate_level('WARN')
  validate_level('INFO')
  validate_level('DEBUG')
  validate_level('TRACE')
  validate_level('OFF')
end

T['make_notify()']['has output validating arguments'] = function()
  child.lua('vim.notify = MiniNotify.make_notify()')
  expect.error(function() child.lua([[vim.notify('Hello', 'ERROR')]]) end, 'valid values.*vim%.log%.levels')
end

T['make_notify()']['allows non-positive `duration`'] = function()
  -- Should not show notification at all
  child.lua([[vim.notify = MiniNotify.make_notify({ ERROR = { duration = -100 }, WARN = { duration = 0 } })]])
  notify('error', child.lua_get('vim.log.levels.ERROR'))
  notify('warn', child.lua_get('vim.log.levels.WARN'))
  eq(get_all(), {})
end

T['add()'] = new_set()

local add = forward_lua('MiniNotify.add')

T['add()']['works'] = function()
  mock_gettimeofday()

  local id = add('Hello')

  -- Should return notification identifier number
  eq(type(id), 'number')

  -- Should show notification in a floating window
  child.expect_screenshot()

  -- Should add proper notification object to history
  local notif = get(id)
  local notif_fields = vim.tbl_keys(notif)
  table.sort(notif_fields)
  eq(notif_fields, { 'hl_group', 'level', 'msg', 'ts_add', 'ts_update' })

  eq(notif.msg, 'Hello')

  -- Non-message arguments should have defaults
  eq(notif.level, 'INFO')
  eq(notif.hl_group, 'MiniNotifyNormal')

  -- Timestamp fields should use `vim.loop.gettimeofday()`
  eq(notif.ts_add, ref_seconds + ref_microseconds)
  eq(notif.ts_update, notif.ts_add)
end

T['add()']['allows empty string message'] = function()
  mock_gettimeofday()

  add('')
  child.expect_screenshot()
end

T['add()']['respects arguments'] = function()
  local validate = function(level)
    local id = add('Hello', level, 'Comment')
    eq(get(id).level, level)
    eq(get(id).hl_group, 'Comment')
  end

  validate('ERROR')
  validate('WARN')
  validate('INFO')
  validate('DEBUG')
  validate('TRACE')
  if child.fn.has('nvim-0.8') == 1 then validate('OFF') end
end

T['add()']['validates arguments'] = function()
  expect.error(function() add(1, 'ERROR', 'Comment') end, '`msg`.*string')
  expect.error(function() add('Hello', 1, 'Comment') end, '`level`.*key of `vim%.log%.levels`')
  expect.error(function() add('Hello', 'Error', 'Comment') end, '`level`.*key of `vim%.log%.levels`')
  expect.error(function() add('Hello', 'ERROR', 1) end, '`hl_group`.*string')
end

T['update()'] = new_set()

local update = forward_lua('MiniNotify.update')

T['update()']['works'] = function()
  mock_gettimeofday()

  local id = add('Hello', 'ERROR', 'Comment')
  child.expect_screenshot()
  local init_notif = get(id)

  update(id, { msg = 'World', level = 'WARN', hl_group = 'String' })

  -- Should show updated notification in a floating window
  child.expect_screenshot()

  -- Should properly update notification object in history
  local notif = get(id)

  eq(notif.msg, 'World')
  eq(notif.level, 'WARN')
  eq(notif.hl_group, 'String')

  -- Add time should be untouched
  eq(notif.ts_add, init_notif.ts_add)

  -- Update time should be increased
  eq(init_notif.ts_update < notif.ts_update, true)
end

T['update()']['allows partial new data'] = function()
  local id = add('Hello', 'ERROR', 'Comment')
  update(id, { msg = 'World' })
  local notif = get(id)
  eq(notif.msg, 'World')
  eq(notif.level, 'ERROR')
  eq(notif.hl_group, 'Comment')

  -- Empty table
  update(id, {})
  eq(notif.msg, 'World')
  eq(notif.level, 'ERROR')
  eq(notif.hl_group, 'Comment')
end

T['update()']['can update only active notification'] = function()
  local id = child.lua([[
    local id = MiniNotify.add('Hello')
    MiniNotify.remove(id)
    return id
  ]])
  expect.error(function() update(id, { msg = 'World' }) end, '`id`.*not.*active')
end

T['update()']['validates arguments'] = function()
  local id = add('Hello')
  expect.error(function() update('a', { msg = 'World' }) end, '`id`.*identifier')
  expect.error(function() update(id, 1) end, '`new_data`.*table')
  expect.error(function() update(id, { msg = 1 }) end, '`msg`.*string')
  expect.error(function() update(id, { level = 1 }) end, '`level`.*key of `vim%.log%.levels`')
  expect.error(function() update(id, { level = 'Error' }) end, '`level`.*key of `vim%.log%.levels`')
  expect.error(function() update(id, { hl_group = 1 }) end, '`hl_group`.*string')
end

T['remove()'] = new_set()

local remove = forward_lua('MiniNotify.remove')

T['remove()']['works'] = function()
  mock_gettimeofday()

  local id = add('Hello', 'ERROR', 'Comment')
  child.expect_screenshot()
  local init_notif = get(id)
  eq(init_notif.ts_remove, nil)

  remove(id)

  -- Should update notification window (and remove it completely in this case)
  child.expect_screenshot()

  -- Should only udpate `ts_remove` field
  local notif = get(id)

  eq(notif.ts_remove, ref_seconds + 1 + ref_microseconds)

  init_notif.ts_remove, notif.ts_remove = nil, nil
  eq(init_notif, notif)
end

T['remove()']['works with several active notifications'] = function()
  mock_gettimeofday()

  local id_1 = add('Hello', 'ERROR', 'Comment')
  local id_2 = add('World', 'ERROR', 'String')
  child.expect_screenshot()

  remove(id_2)
  child.expect_screenshot()

  eq(get(id_1).ts_remove, nil)
  eq(type(get(id_2).ts_remove), 'number')
end

T['remove()']['does nothing on not proper input'] = function()
  local id = add('Hello', 'ERROR', 'Comment')
  local validate = function(...)
    local args = { ... }
    expect.no_error(function() remove(unpack(args)) end)
  end

  validate(nil)
  validate(id + 1)
  validate('a')
end

T['clear()'] = new_set()

local clear = forward_lua('MiniNotify.clear')

T['clear()']['works'] = function()
  mock_gettimeofday()

  local id_1 = add('Hello', 'ERROR', 'Comment')
  local id_2 = add('World', 'ERROR', 'String')
  child.expect_screenshot()

  clear()
  child.expect_screenshot()

  eq(type(get(id_1).ts_remove), 'number')
  eq(type(get(id_2).ts_remove), 'number')
end

T['clear()']['affects only active notifications'] = function()
  local id_1 = add('Hello', 'ERROR', 'Comment')
  local id_2 = add('World', 'ERROR', 'String')
  remove(id_1)
  local ts_remove_1 = get(id_1).ts_remove
  eq(type(ts_remove_1), 'number')
  eq(get(id_2).ts_remove, nil)

  clear()
  eq(get(id_1).ts_remove, ts_remove_1)
  local ts_remove_2 = get(id_2).ts_remove
  eq(type(ts_remove_2), 'number')
  eq(ts_remove_1 < ts_remove_2, true)
end

T['refresh()'] = new_set()

local refresh = forward_lua('MiniNotify.refresh')

-- Most tests are done in 'Window' set and tests for other functions
T['refresh()']['works'] = function() eq(child.lua_get('type(MiniNotify.refresh)'), 'function') end

T['refresh()']['handles manual buffer/window delete'] = function()
  add('Hello')

  -- Window
  child.cmd('wincmd o')
  eq(is_notif_window_shown(), false)
  refresh()
  eq(is_notif_window_shown(), true)

  -- Buffer
  child.cmd('%bw')
  eq(#child.api.nvim_list_bufs(), 1)
  eq(is_notif_window_shown(), false)
  refresh()
  eq(#child.api.nvim_list_bufs(), 2)
  eq(is_notif_window_shown(), true)
end

T['refresh()']['respects `vim.{g,b}.mininotify_disable`'] = new_set({ parametrize = { { 'g' }, { 'b' } } }, {
  test = function(var_type)
    mock_gettimeofday()
    add('Hello')

    child[var_type].mininotify_disable = true
    child.expect_screenshot()
    refresh()
    child.expect_screenshot()
    child[var_type].mininotify_disable = false
    refresh()
    child.expect_screenshot()
  end,
})

T['get()'] = new_set()

T['get()']['returns copy'] = function()
  local res = child.lua([[
    local id = MiniNotify.add('Hello')
    local notif = MiniNotify.get(id)
    notif.msg = 'Should not change history'
    return MiniNotify.get(id).msg == 'Hello'
  ]])
  eq(res, true)
end

T['get_all()'] = new_set()

T['get_all()']['works'] = function()
  local id_1 = add('Hello')
  local id_2 = add('World')
  remove(id_2)

  local history = get_all()
  eq(vim.tbl_count(history), 2)

  eq(history[id_1].msg, 'Hello')
  eq(history[id_2].msg, 'World')
end

T['get_all()']['returns copy'] = function()
  local res = child.lua([[
    local id_1 = MiniNotify.add('Hello')
    local id_2 = MiniNotify.add('World')
    local history = MiniNotify.get_all()
    history[id_1].msg = 'Should not change history'
    history[id_2].msg = 'Nowhere'

    local new_history = MiniNotify.get_all()
    return new_history[id_1].msg == 'Hello' and new_history[id_2].msg == 'World'
  ]])
  eq(res, true)
end

T['show_history()'] = new_set()

local show_history = forward_lua('MiniNotify.show_history')

T['show_history()']['works'] = function()
  mock_gettimeofday()

  add('Hello')
  add('World', 'WARN', 'Comment')
  show_history()
  child.expect_screenshot()

  -- Should set proper filetype
  eq(child.bo.filetype, 'mininotify-history')
end

T['show_history()']['shows all notifications'] = function()
  mock_gettimeofday()

  add('Hello')
  local id = add('World', 'WARN', 'Comment')
  add('Brave', 'INFO', 'String')
  remove(id)
  show_history()
  child.expect_screenshot()
end

T['show_history()']['reuses history buffer'] = function()
  mock_gettimeofday()

  add('Hello')
  show_history()
  local buf_id = child.api.nvim_get_current_buf()
  local n_bufs = #child.api.nvim_list_bufs()

  add('World')
  show_history()
  child.expect_screenshot()

  eq(child.api.nvim_get_current_buf(), buf_id)
  eq(#child.api.nvim_list_bufs(), n_bufs)
end

T['show_history()']['respects `content.format`'] = function()
  mock_gettimeofday()

  add('Hello')
  child.lua([[MiniNotify.config.content.format = function() return 'New message' end]])
  show_history()
  child.expect_screenshot()
end

T['show_history()']['sorts by update time'] = function()
  mock_gettimeofday()

  add('Hello', 'ERROR', 'Comment')
  local id = add('World', 'WARN', 'Comment')
  add('Brave', 'ERROR', 'Comment')

  update(id, { msg = 'WORLD' })

  show_history()
  child.expect_screenshot()
end

T['default_format()'] = new_set()

local default_format = forward_lua('MiniNotify.default_format')

T['default_format()']['works'] = function()
  mock_gettimeofday()
  eq(default_format({ msg = 'Hello', ts_update = ref_seconds + ref_microseconds }), '12:34:56 │ Hello')
end

T['default_sort()'] = new_set()

local default_sort = forward_lua('MiniNotify.default_sort')

T['default_sort()']['works'] = function()
  --stylua: ignore
  -- First should sort by level and then by update time
  local notif_arr = {
    { msg = 'Thirteen', level = 'OFF',   ts_add = ref_seconds + 1, ts_update = ref_seconds + 62 },
    { msg = 'Twelve',   level = 'OFF',   ts_add = ref_seconds,     ts_update = ref_seconds + 63 },
    { msg = 'Eleven',   level = 'TRACE', ts_add = ref_seconds + 1, ts_update = ref_seconds + 52 },
    { msg = 'Ten',      level = 'TRACE', ts_add = ref_seconds,     ts_update = ref_seconds + 53 },
    { msg = 'Nine',     level = 'DEBUG', ts_add = ref_seconds + 1, ts_update = ref_seconds + 42 },
    { msg = 'Eight',    level = 'DEBUG', ts_add = ref_seconds,     ts_update = ref_seconds + 43 },
    { msg = 'Seven',    level = 'INFO',  ts_add = ref_seconds + 1, ts_update = ref_seconds + 32 },
    { msg = 'Six',      level = 'INFO',  ts_add = ref_seconds,     ts_update = ref_seconds + 33 },
    { msg = 'Five',     level = 'WARN',  ts_add = ref_seconds + 1, ts_update = ref_seconds + 22 },
    { msg = 'Four',     level = 'WARN',  ts_add = ref_seconds,     ts_update = ref_seconds + 23 },
    { msg = 'Three',    level = 'ERROR', ts_add = ref_seconds + 1, ts_update = ref_seconds + 1, ts_remove = ref_seconds + 4 },
    { msg = 'Two',      level = 'ERROR', ts_add = ref_seconds + 1, ts_update = ref_seconds + 12 },
    { msg = 'One',      level = 'ERROR', ts_add = ref_seconds,     ts_update = ref_seconds + 13 },
  }
  local ref = {}
  for i = #notif_arr, 1, -1 do
    table.insert(ref, notif_arr[i])
  end
  eq(default_sort(notif_arr), ref)
end

T['default_sort()']['does not affect input'] = function()
  local lua_cmd = string.format(
    [[local notif_arr = {
        { msg = 'Hello', level = 'WARN',  ts_update = %d },
        { msg = 'World', level = 'ERROR', ts_update = %d },
      }
      MiniNotify.default_sort(notif_arr)
      return notif_arr[1].msg == 'Hello']],
    ref_seconds,
    ref_seconds
  )
  eq(child.lua(lua_cmd), true)
end

-- Integration tests ----------------------------------------------------------
T['Window'] = new_set({ hooks = {
  pre_case = function()
    mock_gettimeofday()
    child.set_size(12, 45)
  end,
} })

T['Window']['uses notification `hl_group` to highlight its lines'] = function()
  add('Hello', 'ERROR', 'Comment')
  add('World', 'WARN', 'String')
  local ns_id = child.api.nvim_get_namespaces()['MiniNotifyHighlight']
  local win_id = get_notif_win_id()
  local buf_id = child.api.nvim_win_get_buf(win_id)
  local extmarks = child.api.nvim_buf_get_extmarks(buf_id, ns_id, 0, -1, { details = true })
  eq(#extmarks, 2)
  eq(extmarks[1][4].hl_group, 'Comment')
  eq(extmarks[2][4].hl_group, 'String')
end

T['Window']['works with multiline messages'] = function()
  add('Hello\nBrave\nWorld')
  add('Hello\nAgain')
  child.expect_screenshot()
end

T['Window']['computes default dimensions based on buffer content'] = function()
  add('a')
  child.expect_screenshot()
  add('aaa')
  child.expect_screenshot()
end

T['Window']['wraps text'] = function()
  -- Should also correctly compute dimensions
  add('A very big notification message which should be wrapped')
  child.expect_screenshot()
  add('Another wrapped message')
  child.expect_screenshot()
end

T['Window']['shows start of buffer if it does not fit whole'] = function()
  for i = 1, 20 do
    add('#' .. i)
  end
  child.expect_screenshot()
end

T['Window']['uses proper buffer filetype'] = function()
  child.cmd('au FileType mininotify lua _G.been_here = true')
  add('Hello')
  eq(child.lua_get('_G.been_here'), true)
end

T['Window']['respects `content.format`'] = function()
  child.lua('MiniNotify.config.content.format = function(notif) return notif.msg end')
  add('Hello')
  child.expect_screenshot()
end

T['Window']['respects `content.sort`'] = function()
  child.lua([[MiniNotify.config.content.sort = function(notif_arr)
    -- Show from earliest to latest
    table.sort(notif_arr, function(a, b) return a.ts_update < b.ts_update end)
    return notif_arr
  end]])
  add('Hello')
  add('World')
  child.expect_screenshot()
end

T['Window']['respects `window.config`'] = function()
  -- As table
  child.lua([[MiniNotify.config.window.config = { border = 'none', zindex = 100, width = 30, height = 1 }]])
  add('Hello')
  add('World')
  child.expect_screenshot()

  -- As callable
  child.lua([[MiniNotify.config.window.config = function(buf_id)
    _G.buffer_filetype = vim.bo[buf_id].filetype
    return { border = 'double', width = 25, height = 5 }
  end]])
  refresh()
  child.expect_screenshot()

  -- Allows title
  if child.fn.has('nvim-0.9') == 0 then return end
  child.lua([[MiniNotify.config.window.config = { border = 'single', title = 'Notif' }]])
  refresh()
  child.expect_screenshot()
end

T['Window']['respects `window.max_width_share`'] = function()
  child.lua('MiniNotify.config.window.max_width_share = 0.75')
  add('A very-very-very-very-very long notification')
  child.expect_screenshot()
  child.lua('MiniNotify.config.window.max_width_share = 1')
  refresh()
  child.expect_screenshot()

  -- Handles out of range values
  child.lua('MiniNotify.config.window.max_width_share = 10')
  refresh()
  child.expect_screenshot()

  child.lua('MiniNotify.config.window.max_width_share = 0')
  refresh()
  child.expect_screenshot()
end

T['Window']['respects `window.winblend`'] = function()
  local validate_winblend = function(ref)
    local win_id = get_notif_win_id()
    eq(child.api.nvim_win_get_option(win_id, 'winblend'), ref)
  end

  add('Hello')
  validate_winblend(child.lua_get('MiniNotify.config.window.winblend'))
  clear()

  child.lua('MiniNotify.config.window.winblend = 50')
  add('Hello')
  validate_winblend(50)
end

T['Window']['respects tabline/statusline/cmdline'] = function()
  if child.fn.has('nvim-0.10') == 0 then MiniTest.skip('Screenshots are generated for 0.10.') end
  child.set_size(7, 20)
  child.lua('MiniNotify.config.content.format = function(notif) return notif.msg end')
  for i = 1, 7 do
    add('#' .. i)
  end

  -- Validate tabline/statusline
  local validate = function()
    refresh()
    child.expect_screenshot()
  end

  local validate_ui_lines = function()
    child.o.showtabline, child.o.laststatus = 2, 2
    validate()

    child.o.showtabline, child.o.laststatus = 2, 0
    validate()

    child.o.showtabline, child.o.laststatus = 0, 2
    validate()

    child.o.showtabline, child.o.laststatus = 0, 0
    validate()
  end

  -- Both with and without border
  validate_ui_lines()
  child.lua([[MiniNotify.config.window.config = { border = 'none' }]])
  validate_ui_lines()

  -- Command line
  child.o.showtabline, child.o.laststatus = 0, 0
  child.o.cmdheight = 3
  validate()

  child.o.cmdheight = 0
  validate()
end

T['Window']['persists across tabpages'] = function()
  add('Hello')
  local init_tabpage_id = child.api.nvim_get_current_tabpage()
  eq(is_notif_window_shown(init_tabpage_id), true)

  -- Window should appear only in current tabpage
  child.cmd('tabe')
  local new_tabpage_id = child.api.nvim_get_current_tabpage()
  eq(is_notif_window_shown(init_tabpage_id), false)
  eq(is_notif_window_shown(new_tabpage_id), true)

  child.cmd('tabnext')
  eq(is_notif_window_shown(init_tabpage_id), true)
  eq(is_notif_window_shown(new_tabpage_id), false)
end

T['Window']['fully updates on vim resize'] = function()
  -- With default window config
  child.set_size(10, 50)
  add('A very long notification')
  child.expect_screenshot()
  child.o.columns = 25
  child.expect_screenshot()
  clear()

  -- With callable window config
  child.set_size(15, 50)
  child.lua([[MiniNotify.config.window.config = function()
    return { row = math.floor(0.2 * vim.o.lines), col = math.floor(0.8 * vim.o.columns) }
  end]])
  add('A very long notification')
  child.expect_screenshot()
  child.o.lines, child.o.columns = 10, 25
  child.expect_screenshot()
end

T['Window']['does not affect normal window navigation'] = function()
  local win_id_1 = child.api.nvim_get_current_win()
  child.cmd('botright wincmd v')
  local win_id_2 = child.api.nvim_get_current_win()
  add('Hello')

  child.cmd('wincmd w')
  eq(child.api.nvim_get_current_win(), win_id_1)
  child.cmd('wincmd w')
  eq(child.api.nvim_get_current_win(), win_id_2)
  child.cmd('wincmd w')
  eq(child.api.nvim_get_current_win(), win_id_1)
end

T['Window']['uses dedicated UI highlight groups'] = function()
  add('Hello')
  local win_id = get_notif_win_id()
  local winhighlight = child.api.nvim_win_get_option(win_id, 'winhighlight')
  expect.match(winhighlight, 'NormalFloat:MiniNotifyNormal')
  expect.match(winhighlight, 'FloatBorder:MiniNotifyBorder')
  if child.fn.has('nvim-0.9') == 1 then expect.match(winhighlight, 'FloatTitle:MiniNotifyTitle') end
end

T['Window']['handles width computation for empty lines inside notification buffer'] = function()
  child.set_size(7, 20)
  child.lua('MiniNotify.config.content.format = function(notif) return notif.msg end')

  add('')
  add('')
  child.expect_screenshot()
end

T['LSP progress'] = new_set({
  hooks = {
    pre_case = function()
      child.set_size(7, 50)
      mock_gettimeofday()
      child.lua('MiniNotify.config.window.config = { width = 45, height = 1 }')

      -- Mock LSP
      child.lua([[
        -- Use source table for better mock (to be compatible with Neovim<=0.9)
        _G.clients = {}

        vim.lsp.get_client_by_id = function(id)
          if _G.clients[id] ~= nil then return _G.clients[id] end

          local res = {
            name = 'mock-lsp',

            -- Mock methods for testing relevancy of `LspProgress` event
            progress = { pending = {}, push = function() end },

            -- Mock methods to be compatible with Neovim<=0.9
            messages = { progress = {} },
          }
          if id == 2 then res.name = nil end

          _G.clients[id] = res
          return res
        end]])
    end,
  },
})

local call_handler = function(result, ctx)
  local result_str = vim.inspect(result, { newline = ' ', indent = '' })
  local ctx_str = vim.inspect(ctx, { newline = ' ', indent = '' })
  local lua_cmd = string.format([[vim.lsp.handlers['$/progress'](nil, %s, %s, {})]], result_str, ctx_str)
  child.lua(lua_cmd)
end

T['LSP progress']['works'] = function()
  local ctx = { bufnr = vim.api.nvim_get_current_buf(), client_id = 1 }

  local result = { token = 'test', value = { kind = 'begin', title = 'Testing', message = '0/1', percentage = 0 } }
  call_handler(result, ctx)
  child.expect_screenshot()

  result.value.kind, result.value.message, result.value.percentage = 'report', '1/1', 100
  call_handler(result, ctx)
  child.expect_screenshot()

  result.value.kind, result.value.message, result.value.percentage = 'end', 'done', nil
  call_handler(result, ctx)
  -- Should show the last 'report' message as it is usually more informative
  child.expect_screenshot()

  -- Should wait some time and then hide notifications
  sleep(child.lua_get('MiniNotify.config.lsp_progress.duration_last') - 10)
  child.expect_screenshot()
  sleep(10 + 10)
  child.expect_screenshot()

  -- Should update single notification (and not remove/add new ones)
  eq(#get_all(), 1)
end

T['LSP progress']['handles not present data'] = function()
  -- Absent client name
  local ctx = { bufnr = vim.api.nvim_get_current_buf(), client_id = 2 }

  -- All data which is allowed to be absent (as per LSP spec) is absent
  local result = { token = 'test', value = { kind = 'begin', title = 'Testing' } }
  call_handler(result, ctx)
  child.expect_screenshot()

  result.value.kind, result.value.title = 'report', nil
  call_handler(result, ctx)
  child.expect_screenshot()

  result.value.kind = 'end'
  call_handler(result, ctx)
  child.expect_screenshot()
end

T['LSP progress']['handles sent error'] = function()
  child.lua('vim.notify = function(...) _G.notify_args = {...} end')
  child.lua([[vim.lsp.handlers['$/progress'](
    { code = 1, message = 'Error' },
    {},
    {bufnr = vim.api.nvim_get_current_buf(), client_id = 1},
    {}
  )]])
  eq(
    child.lua_get('_G.notify_args'),
    { vim.inspect({ code = 1, message = 'Error' }), child.lua_get('vim.log.levels.ERROR') }
  )
end

T['LSP progress']['respects `lsp_progress.enable`'] = function()
  local ctx = { bufnr = vim.api.nvim_get_current_buf(), client_id = 1 }
  local result = { token = 'test', value = { kind = 'begin', title = 'Testing', message = '0/1', percentage = 0 } }

  child.lua('MiniNotify.config.lsp_progress.enable = false')
  call_handler(result, ctx)
  eq(is_notif_window_shown(), false)

  child.lua('MiniNotify.config.lsp_progress.enable = true')
  call_handler(result, ctx)
  eq(is_notif_window_shown(), true)
end

T['LSP progress']['respects `lsp_progress.duration_last`'] = function()
  local ctx = { bufnr = vim.api.nvim_get_current_buf(), client_id = 1 }
  local result = { token = 'test', value = { kind = 'begin', title = 'Testing', message = '0/1', percentage = 0 } }
  call_handler(result, ctx)

  result.value.kind, result.value.message, result.value.percentage = 'report', '1/1', 100
  call_handler(result, ctx)

  child.lua('MiniNotify.config.lsp_progress.duration_last = 50')
  result.value.kind, result.value.message, result.value.percentage = 'end', 'done', nil
  call_handler(result, ctx)
  sleep(50 - 10)
  child.expect_screenshot()
  sleep(10 + 10)
  child.expect_screenshot()
end

T['LSP progress']['reuses previous LSP handler'] = function()
  -- Test only on Neovim>=0.10 as previously it was different event and
  -- (possibly) different implementation (which makes mocking difficult).
  -- But relevant event should still be triggered in Neovim<0.10.
  if child.fn.has('nvim-0.10') == 0 then return end
  child.cmd('au LspProgress * lua _G.n_been_here = (_G.n_been_here or 0) + 1')

  local ctx = { bufnr = vim.api.nvim_get_current_buf(), client_id = 1 }
  local result = { token = 'test', value = { kind = 'begin', title = 'Testing' } }
  call_handler(result, ctx)

  eq(child.lua_get('_G.n_been_here'), 1)

  -- Should persist even if module was removed
  package.loaded['mini.notify'] = nil
  child.lua([[require('mini.notify').setup()]])
  call_handler(result, ctx)
  eq(child.lua_get('_G.n_been_here'), 2)

  -- Should be callable multiple times
  call_handler(result, ctx)
  eq(child.lua_get('_G.n_been_here'), 3)
end

return T
