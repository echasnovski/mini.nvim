local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('files', config) end
local unload_module = function() child.mini_unload('files') end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Tweak `expect_screenshot()` to test only on Neovim>=0.9 (as it introduced
-- titles). Use `expect_screenshot_orig()` for original testing.
local expect_screenshot_orig = child.expect_screenshot
child.expect_screenshot = function(...)
  if child.fn.has('nvim-0.9') == 0 then return end
  expect_screenshot_orig(...)
end

-- Test paths helpers
local test_dir = 'tests/dir-files'

local join_path = function(...) return table.concat({ ... }, '/') end

local full_path = function(...)
  local res = vim.fn.fnamemodify(join_path(...), ':p'):gsub('(.)/$', '%1')
  return res
end

local short_path = function(...)
  local res = vim.fn.fnamemodify(join_path(...), ':~'):gsub('(.)/$', '%1')
  return res
end

local make_test_path = function(...)
  local path = join_path(test_dir, join_path(...))
  return child.fn.fnamemodify(path, ':p')
end

local make_temp_dir = function(name, children)
  -- Make temporary directory and make sure it is removed after test is done
  local temp_dir = make_test_path(name or 'temp')
  vim.fn.mkdir(temp_dir, 'p')

  MiniTest.finally(function() vim.fn.delete(temp_dir, 'rf') end)

  -- Create children
  for _, path in ipairs(children) do
    local path_ext = temp_dir .. '/' .. path
    if vim.endswith(path, '/') then
      vim.fn.mkdir(path_ext)
    else
      vim.fn.writefile({}, path_ext)
    end
  end

  return temp_dir
end

-- Common validators and helpers
local validate_directory = function(...) eq(child.fn.isdirectory(join_path(...)), 1) end

local validate_no_directory = function(...) eq(child.fn.isdirectory(join_path(...)), 0) end

local validate_file = function(...) eq(child.fn.filereadable(join_path(...)), 1) end

local validate_no_file = function(...) eq(child.fn.filereadable(join_path(...)), 0) end

local validate_file_content = function(path, lines) eq(child.fn.readfile(path), lines) end

local validate_cur_line = function(x) eq(get_cursor()[1], x) end

local validate_n_wins = function(n) eq(#child.api.nvim_tabpage_list_wins(0), n) end

local validate_fs_entry = function(x)
  eq(type(x), 'table')
  eq(x.fs_type == 'file' or x.fs_type == 'directory', true)
  eq(type(x.name), 'string')
  eq(type(x.path), 'string')
end

local validate_confirm_args = function(ref_msg_pattern)
  local args = child.lua_get('_G.confirm_args')
  expect.match(args[1], ref_msg_pattern)
  if args[2] ~= nil then eq(args[2], '&Yes\n&No') end
  if args[3] ~= nil then eq(args[3], 1) end
  if args[4] ~= nil then eq(args[4], 'Question') end
end

local make_plain_pattern = function(...) return table.concat(vim.tbl_map(vim.pesc, { ... }), '.*') end

local is_file_in_buffer = function(buf_id, path)
  return string.find(child.api.nvim_buf_get_name(buf_id), vim.pesc(path) .. '$') ~= nil
end

local is_file_in_window = function(win_id, path) return is_file_in_buffer(child.api.nvim_win_get_buf(win_id), path) end

-- Common test wrappers
local forward_lua = function(fun_str)
  local lua_cmd = fun_str .. '(...)'
  return function(...) return child.lua_get(lua_cmd, { ... }) end
end

local open = forward_lua('MiniFiles.open')
local close = forward_lua('MiniFiles.close')
local go_in = forward_lua('MiniFiles.go_in')
local go_out = forward_lua('MiniFiles.go_out')
local trim_left = forward_lua('MiniFiles.trim_left')
local trim_right = forward_lua('MiniFiles.trim_right')

-- Extmark helper
local get_extmarks_hl = function()
  local ns_id = child.api.nvim_get_namespaces()['MiniFilesHighlight']
  local extmarks = child.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })
  return vim.tbl_map(function(x) return x[4].hl_group end, extmarks)
end

-- Common mocks
local mock_win_functions = function() child.cmd('source tests/dir-files/mock-win-functions.lua') end

local mock_confirm = function(user_choice)
  local lua_cmd = string.format(
    [[vim.fn.confirm = function(...)
        _G.confirm_args = { ... }
        return %d
      end]],
    user_choice
  )
  child.lua(lua_cmd)
end

local mock_stdpath_data = function()
  local data_dir = make_test_path('data')
  local lua_cmd = string.format(
    [[
    _G.stdpath_orig = vim.fn.stpath
    vim.fn.stdpath = function(what)
      if what == 'data' then return '%s' end
      return _G.stdpath_orig(what)
    end]],
    data_dir
  )
  child.lua(lua_cmd)
  return data_dir
end

-- Data =======================================================================
local test_dir_path = 'tests/dir-files/common'
local test_file_path = 'tests/dir-files/common/a-file'

local test_fs_entries = {
  -- Intentionally in proper order
  { fs_type = 'directory', name = '.a-dir', path = full_path('.a-dir') },
  { fs_type = 'directory', name = 'a-dir', path = full_path('a-dir') },
  { fs_type = 'directory', name = 'b-dir', path = full_path('b-dir') },
  { fs_type = 'file', name = '.a-file', path = full_path('.a-file') },
  { fs_type = 'file', name = 'a-file', path = full_path('a-file') },
  { fs_type = 'file', name = 'A-file-2', path = full_path('A-file-2') },
  { fs_type = 'file', name = 'b-file', path = full_path('b-file') },
}

-- Output test set ============================================================
local T = new_set({
  hooks = {
    pre_case = function()
      child.setup()
      mock_win_functions()
      child.set_size(15, 80)
      load_module()
    end,
    post_case = function() vim.fn.delete(make_test_path('data'), 'rf') end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  -- Global variable
  eq(child.lua_get('type(_G.MiniFiles)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniFiles'), 1)

  -- Highlight groups
  child.cmd('hi clear')
  load_module()
  local validate_hl_group = function(name, ref) expect.match(child.cmd_capture('hi ' .. name), ref) end

  validate_hl_group('MiniFilesBorder', 'links to FloatBorder')
  validate_hl_group('MiniFilesBorderModified', 'links to DiagnosticFloatingWarn')
  validate_hl_group('MiniFilesCursorLine', 'links to CursorLine')
  validate_hl_group('MiniFilesDirectory', 'links to Directory')
  eq(child.fn.hlexists('MiniFilesFile'), 1)
  validate_hl_group('MiniFilesNormal', 'links to NormalFloat')
  validate_hl_group('MiniFilesTitle', 'links to FloatTitle')
  validate_hl_group('MiniFilesTitleFocused', 'links to FloatTitle')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniFiles.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniFiles.config.' .. field), value) end

  expect_config('content.filter', vim.NIL)
  expect_config('content.prefix', vim.NIL)
  expect_config('content.sort', vim.NIL)

  expect_config('mappings.close', 'q')
  expect_config('mappings.go_in', 'l')
  expect_config('mappings.go_in_plus', 'L')
  expect_config('mappings.go_out', 'h')
  expect_config('mappings.go_out_plus', 'H')
  expect_config('mappings.reset', '<BS>')
  expect_config('mappings.reveal_cwd', '@')
  expect_config('mappings.show_help', 'g?')
  expect_config('mappings.synchronize', '=')
  expect_config('mappings.trim_left', '<')
  expect_config('mappings.trim_right', '>')

  expect_config('options.use_as_default_explorer', true)
  expect_config('options.permanent_delete', true)

  expect_config('windows.max_number', math.huge)
  expect_config('windows.preview', false)
  expect_config('windows.width_focus', 50)
  expect_config('windows.width_nofocus', 15)
  expect_config('windows.width_preview', 25)
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ mappings = { close = 'gc' } })
  eq(child.lua_get('MiniFiles.config.mappings.close'), 'gc')
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ content = 'a' }, 'content', 'table')
  expect_config_error({ content = { filter = 1 } }, 'content.filter', 'function')
  expect_config_error({ content = { prefix = 1 } }, 'content.prefix', 'function')
  expect_config_error({ content = { sort = 1 } }, 'content.sort', 'function')

  expect_config_error({ mappings = 'a' }, 'mappings', 'table')
  expect_config_error({ mappings = { close = 1 } }, 'mappings.close', 'string')
  expect_config_error({ mappings = { go_in = 1 } }, 'mappings.go_in', 'string')
  expect_config_error({ mappings = { go_in_plus = 1 } }, 'mappings.go_in_plus', 'string')
  expect_config_error({ mappings = { go_out = 1 } }, 'mappings.go_out', 'string')
  expect_config_error({ mappings = { go_out_plus = 1 } }, 'mappings.go_out_plus', 'string')
  expect_config_error({ mappings = { reset = 1 } }, 'mappings.reset', 'string')
  expect_config_error({ mappings = { reveal_cwd = 1 } }, 'mappings.reveal_cwd', 'string')
  expect_config_error({ mappings = { show_help = 1 } }, 'mappings.show_help', 'string')
  expect_config_error({ mappings = { synchronize = 1 } }, 'mappings.synchronize', 'string')
  expect_config_error({ mappings = { trim_left = 1 } }, 'mappings.trim_left', 'string')
  expect_config_error({ mappings = { trim_right = 1 } }, 'mappings.trim_right', 'string')

  expect_config_error({ options = 'a' }, 'options', 'table')
  expect_config_error({ options = { use_as_default_explorer = 1 } }, 'options.use_as_default_explorer', 'boolean')
  expect_config_error({ options = { permanent_delete = 1 } }, 'options.permanent_delete', 'boolean')

  expect_config_error({ windows = 'a' }, 'windows', 'table')
  expect_config_error({ windows = { max_number = 'a' } }, 'windows.max_number', 'number')
  expect_config_error({ windows = { preview = 1 } }, 'windows.preview', 'boolean')
  expect_config_error({ windows = { width_focus = 'a' } }, 'windows.width_focus', 'number')
  expect_config_error({ windows = { width_nofocus = 'a' } }, 'windows.width_nofocus', 'number')
  expect_config_error({ windows = { width_preview = 'a' } }, 'windows.width_preview', 'number')
end

T['open()'] = new_set()

T['open()']['works with directory path'] = function()
  -- Works with relative path
  open(test_dir_path)
  child.expect_screenshot()
  close()
  validate_n_wins(1)

  -- Works with absolute path
  open(vim.fn.fnamemodify(test_dir_path, ':p'))
  child.expect_screenshot()
  close()
  validate_n_wins(1)

  -- Works with trailing slash
  open(test_dir_path .. '/')
  child.expect_screenshot()
end

T['open()']['works with file path'] = function()
  -- Works with relative path
  open(test_file_path)
  -- Should focus on file entry
  child.expect_screenshot()
  close()

  -- Works with absolute path
  open(vim.fn.fnamemodify(test_file_path, ':p'))
  child.expect_screenshot()
end

T['open()']['works per tabpage'] = function()
  open(test_dir_path)
  child.expect_screenshot()

  child.cmd('tabedit')
  open(test_dir_path .. '/a-dir')
  child.expect_screenshot()

  child.cmd('tabnext')
  child.expect_screenshot()
end

T['open()']['handles problematic entry names'] = function()
  local temp_dir = make_temp_dir('temp', { '%a bad-file-name', 'a bad-dir.name/' })

  open(temp_dir)
  child.expect_screenshot()
end

T['open()']["uses 'nvim-web-devicons' if present"] = function()
  -- Mock 'nvim-web-devicons'
  child.cmd('set rtp+=tests/dir-files')

  open(make_test_path('real'))
  child.expect_screenshot()
  --stylua: ignore
  eq(
    get_extmarks_hl(),
    {
      'DevIconLua',      'MiniFilesFile',
      'DevIconTxt',      'MiniFilesFile',
      'DevIconGif',      'MiniFilesFile',
      'DevIconLicense',  'MiniFilesFile',
      'DevIconMakefile', 'MiniFilesFile',
    }
  )
end

T['open()']['history'] = new_set()

T['open()']['history']['opens from history by default'] = function()
  open(test_dir_path)
  type_keys('j')
  go_in()
  type_keys('2j')
  child.expect_screenshot()

  close()
  validate_n_wins(1)
  open(test_dir_path)
  -- Should be exactly the same, including cursors
  child.expect_screenshot()
end

T['open()']['history']['handles external changes between calls'] = function()
  local temp_dir = make_temp_dir('temp', { 'subdir/' })

  open(temp_dir)
  go_in()
  child.expect_screenshot()

  close()
  child.fn.delete(join_path(temp_dir, 'subdir'), 'rf')
  open(temp_dir)
  child.expect_screenshot()
end

T['open()']['history']['respects `use_latest`'] = function()
  open(test_dir_path)
  type_keys('j')
  go_in()
  type_keys('2j')
  child.expect_screenshot()

  close()
  validate_n_wins(1)
  open(test_dir_path, false)
  -- Should be as if opened first time
  child.expect_screenshot()
end

T['open()']['history']['prefers global config before taking from history'] = function()
  child.lua([[
    _G.filter_starts_from_a = function(fs_entry) return vim.startswith(fs_entry.name, 'a') end
    _G.filter_starts_from_b = function(fs_entry) return vim.startswith(fs_entry.name, 'b') end
  ]])

  local lua_cmd = string.format(
    'MiniFiles.open(%s, false, { content = { filter = _G.filter_starts_from_a } })',
    vim.inspect(test_dir_path)
  )
  child.lua(lua_cmd)
  child.expect_screenshot()

  close()
  child.lua('MiniFiles.config.content.filter = _G.filter_starts_from_b')
  open(test_dir_path, true)
  child.expect_screenshot()
end

T['open()']['history']['stores whole branch and not only visible windows'] = function()
  child.set_size(15, 60)
  open(test_dir_path)
  go_in()
  child.expect_screenshot()
  close()

  child.set_size(15, 80)
  -- Should show two windows
  open(test_dir_path, true)
  child.expect_screenshot()
end

T['open()']['history']['is shared across tabpages'] = function()
  -- Prepare history
  open(test_dir_path)
  go_in()
  child.expect_screenshot()
  close()

  -- Open in new tabpage
  child.cmd('tabedit')
  open(test_dir_path, true)
  child.expect_screenshot()
  go_out()
  close()

  child.cmd('tabnext')
  open(test_dir_path, true)
  child.expect_screenshot()
end

T['open()']['history']['updates target window on every call'] = function()
  -- Prepare windows
  local win_id_1 = child.api.nvim_get_current_win()
  child.cmd('wincmd v')
  local win_id_2 = child.api.nvim_get_current_win()
  eq(win_id_1 ~= win_id_2, true)

  -- Put explorer in history which opened in current window
  open(test_file_path)
  go_in()
  close()
  eq(is_file_in_window(win_id_1, test_file_path), false)
  eq(is_file_in_window(win_id_2, test_file_path), true)

  child.api.nvim_win_set_buf(win_id_2, child.api.nvim_win_get_buf(win_id_1))

  -- New `open()` call should register new target window
  child.api.nvim_set_current_win(win_id_1)
  open(test_file_path)
  go_in()
  close()
  eq(is_file_in_window(win_id_1, test_file_path), true)
  eq(is_file_in_window(win_id_2, test_file_path), false)
end

T['open()']['focuses on file entry when opened from history'] = function()
  local path = make_test_path('common/a-dir/ab-file')

  -- If in branch, just focus on entry
  open(path)
  type_keys('j')
  go_out()
  child.expect_screenshot()

  close()
  open(path)
  child.expect_screenshot()

  -- If not in branch, reset
  go_out()
  trim_right()
  child.expect_screenshot()
  close()

  open(path)
  child.expect_screenshot()
end

T['open()']['normalizes before first refresh when focused on file'] = function()
  -- Prepare explorer state to be opened from history
  open(make_test_path('common'))
  go_in()
  validate_n_wins(3)
  close()

  -- Mock `nvim_open_win()`
  child.lua([[
    _G.init_nvim_open_win = vim.api.nvim_open_win
    _G.open_win_count = 0
    vim.api.nvim_open_win = function(...)
      _G.open_win_count = _G.open_win_count + 1
      return init_nvim_open_win(...)
    end
  ]])

  -- Test. Opening file in 'common' directory makes previous two-window view
  -- not synchronized with cursor (pointing at file while right window is for
  -- previously opened directory). Make sure that it is made one window prior
  -- to rendering, otherwise it might result in flickering.
  open(make_test_path('common/a-file'))
  child.expect_screenshot()
  eq(child.lua_get('_G.open_win_count'), 1)
end

T['open()']['normalizes before first refresh when focused on directory with `windows.preview`'] = function()
  -- Prepare explorer state to be opened from history
  open(test_dir_path)
  validate_n_wins(2)
  close()

  -- Mock `nvim_open_win()`
  child.lua([[
    _G.init_nvim_open_win = vim.api.nvim_open_win
    _G.open_win_count = 0
    vim.api.nvim_open_win = function(...)
      _G.open_win_count = _G.open_win_count + 1
      return init_nvim_open_win(...)
    end
  ]])

  -- Test. It should preview right away without extra window manipulations.
  open(test_dir_path, true, { windows = { preview = true } })
  child.expect_screenshot()
  eq(child.lua_get('_G.open_win_count'), 2)
end

T['open()']['respects `content.filter`'] = function()
  child.lua([[
    _G.filter_arg = {}
    MiniFiles.config.content.filter = function(fs_entry)
      _G.filter_arg = fs_entry

      -- Show only directories
      return fs_entry.fs_type == 'directory'
    end
  ]])

  open(test_dir_path)
  child.expect_screenshot()
  validate_fs_entry(child.lua_get('_G.filter_arg'))

  -- Local value from argument should take precedence
  child.lua([[_G.filter_starts_from_a = function(fs_entry) return vim.startswith(fs_entry.name, 'a') end ]])

  local lua_cmd = string.format(
    [[MiniFiles.open(%s, false, { content = { filter = _G.filter_starts_from_a } })]],
    vim.inspect(test_dir_path)
  )
  child.lua(lua_cmd)
  child.expect_screenshot()
end

T['open()']['respects `content.prefix`'] = function()
  child.set_size(15, 60)

  child.lua([[
    _G.prefix_arg = {}
    MiniFiles.config.content.prefix = function(fs_entry)
      _G.prefix_arg = fs_entry

      if fs_entry.fs_type == 'directory' then
        return '-', 'Comment'
      else
        return '|', 'Special'
      end
    end
  ]])

  open(test_dir_path)
  child.expect_screenshot()
  validate_fs_entry(child.lua_get('_G.prefix_arg'))

  -- Local value from argument should take precedence
  child.lua([[_G.prefix_2 = function(fs_entry) return '|', 'Special' end ]])

  local lua_cmd =
    string.format([[MiniFiles.open(%s, false, { content = { prefix = _G.prefix_2 } })]], vim.inspect(test_dir_path))
  child.lua(lua_cmd)
  child.expect_screenshot()
end

T['open()']['`content.prefix` can be used to not show prefix'] = function()
  child.lua([[MiniFiles.config.content.prefix = function() return '', '' end]])
  open(test_dir_path)
  go_in()
  child.expect_screenshot()
end

T['open()']['`content.prefix` can return `nil`'] = function()
  child.set_size(15, 60)

  local validate = function(return_expr)
    local lua_cmd = string.format([[MiniFiles.config.content.prefix = function() return %s end]], return_expr)
    child.lua(lua_cmd)
    open(test_dir_path)
    child.expect_screenshot()
    close()
  end

  validate()
  validate([['', nil]])
  validate([[nil, '']])
end

T['open()']['respects `content.sort`'] = function()
  child.lua([[
    _G.sort_arg = {}
    MiniFiles.config.content.sort = function(fs_entries)
      _G.sort_arg = fs_entries

      -- Sort alphabetically without paying attention to file system type
      local res = vim.deepcopy(fs_entries)
      table.sort(res, function(a, b) return a.name < b.name end)
      return res
    end
  ]])

  open(test_dir_path)
  child.expect_screenshot()

  local sort_arg = child.lua_get('_G.sort_arg')
  eq(type(sort_arg), 'table')
  for _, val in pairs(sort_arg) do
    validate_fs_entry(val)
  end

  -- Local value from argument should take precedence
  child.lua([[
    _G.sort_rev_alpha = function(fs_entries)
      local res = vim.deepcopy(fs_entries)
      table.sort(res, function(a, b) return a.name > b.name end)
      return res
    end
  ]])

  local lua_cmd =
    string.format([[MiniFiles.open(%s, false, { content = { sort = _G.sort_rev_alpha } })]], vim.inspect(test_dir_path))
  child.lua(lua_cmd)
  child.expect_screenshot()
end

T['open()']['`content.sort` can be used to also filter items'] = function()
  child.lua([[
    MiniFiles.config.content.sort = function(fs_entries)
      -- Sort alphabetically without paying attention to file system type
      local res = vim.tbl_filter(function(x) return x.fs_type == 'directory' end, fs_entries)
      table.sort(res, function(a, b) return a.name > b.name end)
      return res
    end
  ]])

  open(test_dir_path)
  child.expect_screenshot()
end

T['open()']['respects `mappings`'] = function()
  child.lua([[MiniFiles.config.mappings.go_in = '<CR>']])
  open(test_dir_path)
  type_keys('<CR>')
  child.expect_screenshot()
  close()

  -- Local value from argument should take precedence
  open(test_dir_path, false, { mappings = { go_in = 'K' } })
  type_keys('K')
  child.expect_screenshot()
end

T['open()']['does not create mapping for empty string'] = function()
  local has_map = function(lhs, pattern) return child.cmd_capture('nmap ' .. lhs):find(pattern) ~= nil end

  -- Supplying empty string should mean "don't create keymap"
  child.lua('MiniFiles.config.mappings.go_in = ""')
  open()

  eq(has_map('q', 'Close'), true)
  eq(has_map('l', 'Go in'), false)
end

T['open()']['respects `windows.max_number`'] = function()
  child.lua('MiniFiles.config.windows.max_number = 1')
  open(test_dir_path)
  go_in()
  child.expect_screenshot()
  close()

  -- Local value from argument should take precedence
  open(test_dir_path, false, { windows = { max_number = 2 } })
  go_in()
  child.expect_screenshot()
end

T['open()']['respects `windows.preview`'] = function()
  child.lua('MiniFiles.config.windows.preview = true')
  open(test_dir_path)
  child.expect_screenshot()
  close()

  -- Local value from argument should take precedence
  open(test_dir_path, false, { windows = { preview = false } })
  child.expect_screenshot()
end

T['open()']['respects `windows.width_focus` and `windows.width_nofocus`'] = function()
  child.lua('MiniFiles.config.windows.width_focus = 40')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')
  open(test_dir_path)
  go_in()
  child.expect_screenshot()
  close()

  -- Local value from argument should take precedence
  open(test_dir_path, false, { windows = { width_focus = 30, width_nofocus = 20 } })
  go_in()
  child.expect_screenshot()
end

T['open()']['respects `windows.width_preview`'] = function()
  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 20')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')
  child.lua('MiniFiles.config.windows.width_preview = 15')

  local test_path = make_test_path('nested')

  -- Preview window is to the right of focused one (if preview is active)
  open(test_path)
  child.expect_screenshot()
  go_in()
  child.expect_screenshot()
  go_in()
  child.expect_screenshot()
  go_out()
  child.expect_screenshot()
  go_out()
  child.expect_screenshot()

  close()

  -- Local value from argument should take precedence
  open(test_path, false, { windows = { width_focus = 20, width_preview = 30 } })
  child.expect_screenshot()
end

T['open()']['properly closes currently opened explorer'] = function()
  local path_1, path_2 = make_test_path('common'), make_test_path('common/a-dir')
  open(path_1)
  go_in()
  validate_n_wins(3)

  -- Should properly close current opened explorer (at least save to history)
  open(path_2)
  close()

  open(path_1, true)
  child.expect_screenshot()
end

T['open()']['properly closes currently opened explorer with modified buffers'] = function()
  child.set_size(100, 100)

  local path_1, path_2 = make_test_path('common'), make_test_path('common/a-dir')
  open(path_1)
  type_keys('o', 'hello')

  -- Should mention modified buffers and ask for confirmation
  mock_confirm(1)
  open(path_2)
  validate_confirm_args('modified buffer.*close without sync')
end

T['open()']['tracks lost focus'] = function()
  child.lua('MiniFiles.config.windows.preview = true')

  local validate = function(loose_focus)
    open(test_dir_path)
    loose_focus()
    -- Tracking is done by checking every second
    sleep(1000 + 20)
    validate_n_wins(1)
    eq(#child.api.nvim_list_bufs(), 1)
  end

  local init_win_id = child.api.nvim_get_current_win()
  validate(function() child.api.nvim_set_current_win(init_win_id) end)

  validate(function() child.cmd('quit') end)

  validate(function()
    go_in()
    type_keys('ZZ')
  end)

  -- Should still be possible to open same explorer afterwards
  open(test_dir_path)
  validate_n_wins(3)
end

T['open()']['validates input'] = function()
  -- `path` should be a real path
  expect.error(function() open('aaa') end, 'path.*not a valid path.*aaa')
end

T['open()']['respects `vim.b.minifiles_config`'] = function()
  child.lua([[_G.filter_starts_from_a = function(fs_entry) return vim.startswith(fs_entry.name, 'a') end ]])
  child.lua('vim.b.minifiles_config = { content = { filter = _G.filter_starts_from_a } }')

  open(test_dir_path)
  child.expect_screenshot()
end

T['refresh()'] = new_set()

local refresh = forward_lua('MiniFiles.refresh')

T['refresh()']['works'] = function()
  open(test_dir_path)
  refresh({ windows = { width_focus = 30 } })
  child.expect_screenshot()
end

T['refresh()']['preserves explorer options'] = function()
  open(test_dir_path, false, { windows = { width_focus = 45, width_nofocus = 10 } })
  go_in()
  child.expect_screenshot()
  -- Current explorer options should be preserved
  refresh({ windows = { width_focus = 30 } })
  child.expect_screenshot()
end

T['refresh()']['does not update buffers with `nil` `filter` and `sort`'] = function()
  local temp_dir = make_temp_dir('temp', { 'subdir/' })

  open(temp_dir)
  local buf_id_1 = child.api.nvim_get_current_buf()
  go_in()
  local buf_id_2 = child.api.nvim_get_current_buf()
  child.expect_screenshot()

  local changedtick_1 = child.api.nvim_buf_get_var(buf_id_1, 'changedtick')
  local changedtick_2 = child.api.nvim_buf_get_var(buf_id_2, 'changedtick')

  -- Should not update buffers
  refresh()
  eq(child.api.nvim_buf_get_var(buf_id_1, 'changedtick'), changedtick_1)
  eq(child.api.nvim_buf_get_var(buf_id_2, 'changedtick'), changedtick_2)

  -- Should not update even if there are external changes (there is
  -- `synchronize()` for that)
  vim.fn.mkdir(join_path(temp_dir, 'subdir', 'subsubdir'))
  refresh()
  child.expect_screenshot()
  eq(child.api.nvim_buf_get_var(buf_id_1, 'changedtick'), changedtick_1)
  eq(child.api.nvim_buf_get_var(buf_id_2, 'changedtick'), changedtick_2)
end

T['refresh()']['updates buffers with non-empty `content`'] = function()
  child.lua([[
    _G.hide_dotfiles = function(fs_entry) return not vim.startswith(fs_entry.name, '.') end
    _G.hide_prefix = function() return '', '' end
    _G.sort_rev_alpha = function(fs_entries)
      local res = vim.deepcopy(fs_entries)
      table.sort(res, function(a, b) return a.name > b.name end)
      return res
    end
  ]])

  open(test_dir_path)
  child.expect_screenshot()

  child.lua('MiniFiles.refresh({ content = { filter = _G.hide_dotfiles } })')
  child.expect_screenshot()

  child.lua('MiniFiles.refresh({ content = { prefix = _G.hide_prefix } })')
  child.expect_screenshot()

  child.lua('MiniFiles.refresh({ content = { sort = _G.sort_rev_alpha } })')
  child.expect_screenshot()
end

T['refresh()']['handles presence of modified buffers'] = function()
  child.set_size(10, 60)
  child.lua([[_G.hide_dotfiles = function(fs_entry) return not vim.startswith(fs_entry.name, '.') end ]])

  local temp_dir = make_temp_dir('temp', { 'file', '.file' })
  open(temp_dir)

  -- On confirm should update buffers without synchronization
  type_keys('o', 'new-file', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  child.lua('MiniFiles.refresh({ content = { filter = _G.hide_dotfiles }, windows = { width_focus = 30 } })')
  child.expect_screenshot()

  validate_confirm_args('modified buffer.*Confirm buffer updates without sync')

  -- On no confirm should not update buffers, but still apply other changes
  type_keys('o', 'new-file-2', '<Esc>')
  if child.fn.has('nvim-0.10') == 1 then child.expect_screenshot() end

  mock_confirm(2)
  child.lua('MiniFiles.refresh({ content = { filter = function() return true end }, windows = { width_focus = 15 } })')
  if child.fn.has('nvim-0.10') == 1 then child.expect_screenshot() end
end

T['refresh()']['works when no explorer is opened'] = function() expect.no_error(refresh) end

-- More extensive testing is done in 'File Manipulation'
T['synchronize()'] = new_set()

local synchronize = forward_lua('MiniFiles.synchronize')

T['synchronize()']['can update external file system changes'] = function()
  local temp_dir = make_temp_dir('temp', { 'subdir/' })

  open(temp_dir)
  validate_cur_line(1)

  vim.fn.mkdir(join_path(temp_dir, 'aaa'))
  synchronize()
  child.expect_screenshot()

  -- Cursor should be "sticked" to current entry
  validate_cur_line(2)
end

T['synchronize()']['can apply file system actions'] = function()
  local temp_dir = make_temp_dir('temp', {})

  open(temp_dir)
  type_keys('i', 'new-file', '<Esc>')

  local new_file_path = join_path(temp_dir, 'new-file')
  mock_confirm(1)
  validate_no_file(new_file_path)

  synchronize()
  validate_file(new_file_path)
end

T['synchronize()']['should follow cursor on current entry path'] = function()
  local temp_dir = make_temp_dir('temp', { 'dir/', 'file' })

  open(temp_dir)
  type_keys('G', 'o', 'new-dir/', '<Esc>')
  type_keys('k')

  validate_cur_line(2)

  mock_confirm(1)
  synchronize()
  validate_cur_line(3)
end

T['synchronize()']['should follow cursor on new path'] = function()
  mock_confirm(1)
  local temp_dir = make_temp_dir('temp', { 'dir/' })
  open(temp_dir)

  -- File
  type_keys('O', 'new-file', '<Esc>')
  validate_cur_line(1)
  synchronize()
  validate_cur_line(2)

  -- Directory
  type_keys('o', 'new-dir/', '<Esc>')
  validate_cur_line(3)
  synchronize()
  validate_cur_line(2)

  -- Nested directories
  type_keys('o', 'a/b', '<Esc>')
  validate_cur_line(3)
  synchronize()
  validate_cur_line(1)
end

T['synchronize()']['works when no explorer is opened'] = function() expect.no_error(synchronize) end

T['reset()'] = new_set()

local reset = forward_lua('MiniFiles.reset')

T['reset()']['works'] = function()
  open(test_dir_path)
  type_keys('j')
  go_in()
  child.expect_screenshot()

  reset()
  child.expect_screenshot()
end

T['reset()']['works when anchor is not in branch'] = function()
  open(join_path(test_dir_path, 'a-dir'))
  go_out()
  type_keys('k')
  go_in()
  child.expect_screenshot()

  reset()
  if child.fn.has('nvim-0.10') == 1 then child.expect_screenshot() end
end

T['reset()']['resets all cursors'] = function()
  open(test_dir_path)
  type_keys('j')
  go_in()
  type_keys('G')
  validate_cur_line(3)

  -- Should reset cursors in both visible and invisible buffers
  go_out()
  type_keys('G')
  child.expect_screenshot()

  reset()
  child.expect_screenshot()
  type_keys('j')
  go_in()
  validate_cur_line(1)
end

T['reset()']['works when no explorer is opened'] = function() expect.no_error(reset) end

T['close()'] = new_set()

T['close()']['works'] = function()
  open(test_dir_path)
  child.expect_screenshot()

  -- Should return `true` if closing was successful
  eq(close(), true)
  child.expect_screenshot()

  -- Should close all windows and delete all buffers
  validate_n_wins(1)
  eq(#child.api.nvim_list_bufs(), 1)
end

T['close()']['works per tabpage'] = function()
  open(test_dir_path)
  child.cmd('tabedit')
  open(test_file_path)

  child.cmd('tabprev')
  close()

  -- On different tabpage explorer should still be present
  child.cmd('tabnext')
  child.expect_screenshot()
end

T['close()']['checks for modified buffers'] = function()
  open(test_dir_path)
  type_keys('o', 'new', '<Esc>')
  child.expect_screenshot()

  -- Should confirm close and do nothing if there is none (and return `false`)
  mock_confirm(2)
  eq(close(), false)
  child.expect_screenshot()
  validate_confirm_args('modified buffer.*Confirm close without sync')

  -- Should close if there is confirm
  mock_confirm(1)
  eq(close(), true)
  child.expect_screenshot()
end

T['close()']['results into focus on target window'] = function()
  local init_win_id = child.api.nvim_get_current_win()
  child.cmd('belowright vertical split')
  local ref_win_id = child.api.nvim_get_current_win()

  open(test_dir_path)
  close()
  eq(child.api.nvim_get_current_win(), ref_win_id)

  -- Should handle non-valid target window
  open(test_dir_path)
  child.api.nvim_win_close(ref_win_id, true)
  close()
  eq(child.api.nvim_get_current_win(), init_win_id)
end

T['close()']['closes help window'] = function()
  open(test_dir_path)
  child.lua('MiniFiles.show_help()')
  validate_n_wins(3)
  close()
  validate_n_wins(1)
end

T['close()']['handles invalid target window'] = function()
  child.set_size(15, 60)
  child.o.showtabline = 0
  child.o.laststatus = 0

  child.cmd('tabfind ' .. test_dir_path)
  child.expect_screenshot()
  eq(#child.api.nvim_list_tabpages(), 2)

  close()
  child.expect_screenshot()
  eq(#child.api.nvim_list_bufs(), 1)
  eq(#child.api.nvim_list_tabpages(), 1)
  eq(child.cmd('messages'), '')
end

T['close()']['works when no explorer is opened'] = function() eq(close(), vim.NIL) end

T['go_in()'] = new_set()

T['go_in()']['works on file'] = function()
  open(test_dir_path)
  type_keys('/', [[\.a-file]], '<CR>')
  go_in()
  close()

  expect.match(child.api.nvim_buf_get_name(0), '%.a%-file$')
  eq(get_lines(), { '.a-file' })

  -- Should open with relative path to have better view in `:buffers`
  expect.match(child.cmd_capture('buffers'), '"' .. vim.pesc(test_dir_path))
end

T['go_in()']['respects `opts.close_on_file`'] = function()
  open(test_dir_path)
  type_keys('/', [[\.a-file]], '<CR>')
  go_in({ close_on_file = true })
  expect.match(child.api.nvim_buf_get_name(0), '%.a%-file$')
  eq(get_lines(), { '.a-file' })

  validate_n_wins(1)
end

T['go_in()']['works on files with problematic names'] = function()
  local bad_name = '%a bad-file-name'
  local temp_dir = make_temp_dir('temp', { bad_name })
  vim.fn.writefile({ 'aaa' }, join_path(temp_dir, bad_name))

  open(temp_dir)
  go_in()
  close()

  eq(is_file_in_buffer(0, bad_name), true)
  eq(get_lines(), { 'aaa' })
end

T['go_in()']['uses already opened listed buffer without `:edit`'] = function()
  local temp_dir = make_temp_dir('temp', { 'file' })
  local file_path = join_path(temp_dir, 'file')

  child.cmd('edit ' .. vim.fn.fnameescape(file_path))
  local buf_id = child.api.nvim_get_current_buf()
  child.fn.writefile({ 'New changes' }, file_path)

  open(temp_dir)
  go_in()
  -- If `:edit` was used, then content would have changed
  eq(child.api.nvim_buf_get_lines(buf_id, 0, -1, false), { '' })
  close(temp_dir)

  -- Should make unlisted buffer become listed
  child.cmd('bdelete ' .. buf_id)
  eq(child.api.nvim_buf_get_option(buf_id, 'buflisted'), false)

  open(temp_dir)
  go_in()
  eq(child.api.nvim_buf_get_option(buf_id, 'buflisted'), true)
end

T['go_in()']['uses proper target window'] = function()
  local win_id_1 = child.api.nvim_get_current_win()
  child.cmd('wincmd v')
  local win_id_2 = child.api.nvim_get_current_win()
  eq(win_id_1 ~= win_id_2, true)

  open(test_file_path)
  go_in()
  eq(is_file_in_window(win_id_1, test_file_path), false)
  eq(is_file_in_window(win_id_2, test_file_path), true)
end

T['go_in()']['works if target window is not valid'] = function()
  local win_id_1 = child.api.nvim_get_current_win()
  child.cmd('wincmd v')
  local win_id_2 = child.api.nvim_get_current_win()
  eq(win_id_1 ~= win_id_2, true)

  open(test_file_path)
  child.api.nvim_win_close(win_id_2, true)
  go_in()
  eq(is_file_in_window(win_id_1, test_file_path), true)
end

T['go_in()']['works on directory'] = function()
  open(test_dir_path)

  -- Should open if not already visible
  go_in()
  child.expect_screenshot()

  -- Should focus if already visible
  go_out()
  go_in()
  child.expect_screenshot()
end

T['go_in()']['works when no explorer is opened'] = function() expect.no_error(go_in) end

T['go_out()'] = new_set()

T['go_out()']['works on not branch root'] = function()
  open(test_dir_path)
  type_keys('j')
  go_in()

  -- Should focus parent directory with cursor pointing on entry to the right
  go_out()
  child.expect_screenshot()
end

T['go_out()']['works on branch root'] = function()
  local path = make_test_path('common', 'a-dir')
  open(path)

  -- Should focus parent directory with cursor pointing on entry to the right
  -- Should also preserve visibility of current directory
  go_out()
  child.expect_screenshot()
end

T['go_out()']['root update reuses buffers without their update'] = function()
  local temp_dir = make_temp_dir('temp', { 'dir/' })
  local path = join_path(temp_dir, 'dir')

  open(path)
  child.fn.writefile({}, join_path(path, 'file'))
  go_out()
  -- Present buffer should not be updated with new file system information
  child.expect_screenshot()
end

T['go_out()']['works when no explorer is opened'] = function() expect.no_error(go_out) end

T['trim_left()'] = new_set()

T['trim_left()']['works'] = function()
  open(make_test_path('nested'))
  go_in()
  go_in()
  child.expect_screenshot()

  trim_left()
  child.expect_screenshot()
end

T['trim_left()']['works when in the middle of the branch'] = function()
  child.lua('MiniFiles.config.windows.width_focus = 20')

  open(make_test_path('nested'))
  go_in()
  go_in()
  go_out()
  child.expect_screenshot()

  trim_left()
  child.expect_screenshot()
end

T['trim_left()']['works when no explorer is opened'] = function() expect.no_error(trim_left) end

T['trim_right()'] = new_set()

T['trim_right()']['works'] = function()
  open(make_test_path('nested'))
  go_in()
  go_in()
  go_out()
  go_out()
  child.expect_screenshot()

  trim_right()
  child.expect_screenshot()
end

T['trim_right()']['works when in the middle of the branch'] = function()
  child.lua('MiniFiles.config.windows.width_focus = 20')

  open(make_test_path('nested'))
  go_in()
  go_in()
  go_out()
  child.expect_screenshot()

  trim_right()
  child.expect_screenshot()
end

T['trim_right()']['works when no explorer is opened'] = function() expect.no_error(trim_right) end

T['reveal_cwd()'] = new_set()

local reveal_cwd = forward_lua('MiniFiles.reveal_cwd')

T['reveal_cwd()']['works'] = function()
  child.set_size(10, 80)

  child.lua('MiniFiles.config.windows.width_focus = 20')
  local nested_path = make_test_path('nested')
  child.fn.chdir(nested_path)

  open(nested_path)
  go_in()
  go_in()
  trim_left()
  child.expect_screenshot()

  reveal_cwd()
  child.expect_screenshot()
end

T['reveal_cwd()']['works with preview'] = function()
  child.set_size(10, 80)

  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 20')
  child.lua('MiniFiles.config.windows.width_preview = 10')
  local nested_path = make_test_path('nested')
  child.fn.chdir(nested_path)

  open(nested_path)
  go_in()
  go_in()
  trim_left()
  child.expect_screenshot()

  reveal_cwd()
  child.expect_screenshot()
end

T['reveal_cwd()']['works when not inside cwd'] = function()
  child.lua('MiniFiles.config.windows.width_focus = 20')
  local open_path = full_path(test_dir_path)
  local temp_dir = make_temp_dir('temp', {})
  child.fn.chdir(temp_dir)

  open(open_path)
  child.expect_screenshot()

  reveal_cwd()
  child.expect_screenshot()
end

T['reveal_cwd()']['works when root is already cwd'] = function()
  child.lua('MiniFiles.config.windows.width_focus = 20')
  local open_path = full_path(test_dir_path)
  child.fn.chdir(test_dir_path)

  open(open_path)
  child.expect_screenshot()

  reveal_cwd()
  child.expect_screenshot()
end

T['reveal_cwd()']['properly places cursors'] = function()
  child.lua('MiniFiles.config.windows.width_focus = 20')
  local temp_dir =
    make_temp_dir('temp', { 'dir-1/', 'dir-2/', 'dir-3/', 'dir-2/dir-21/', 'dir-2/dir-22/', 'dir-2/dir-23/' })
  temp_dir = full_path(temp_dir)
  child.fn.chdir(temp_dir)

  open(join_path(temp_dir, 'dir-2', 'dir-23'))
  child.expect_screenshot()

  reveal_cwd()
  child.expect_screenshot()
end

T['reveal_cwd()']['works when no explorer is opened'] = function() expect.no_error(reveal_cwd) end

T['show_help()'] = new_set()

local show_help = forward_lua('MiniFiles.show_help')

T['show_help()']['works'] = function()
  child.set_size(20, 60)
  open(test_dir_path)
  local win_id_explorer = child.api.nvim_get_current_win()

  type_keys('2j')

  show_help()
  child.expect_screenshot()

  -- Should focus on help window
  eq(child.api.nvim_get_current_win() ~= win_id_explorer, true)

  -- Pressing `q` should close help window and focus on explorer at same line
  type_keys('q')
  child.expect_screenshot()
end

T['show_help()']['opens relatively current window'] = function()
  child.set_size(20, 60)
  child.lua('MiniFiles.config.windows.width_focus = 30')

  open(test_dir_path)
  go_in()

  show_help()
  child.expect_screenshot()
end

T['show_help()']['handles non-default mappings'] = function()
  child.set_size(20, 60)
  child.lua('MiniFiles.config.mappings.go_in = ""')
  child.lua('MiniFiles.config.mappings.go_in_plus = "l"')

  open(test_dir_path)
  show_help()
  child.expect_screenshot()
end

T['show_help()']['handles mappings without description'] = function()
  child.set_size(20, 60)

  open(test_dir_path)
  child.lua([[vim.keymap.set('n', 'g.', '<Cmd>echo 1<CR>', { buffer = vim.api.nvim_get_current_buf() })]])
  show_help()
  child.expect_screenshot()
end

T['show_help()']['adjusts window width'] = function()
  child.set_size(20, 60)
  child.lua('MiniFiles.config.mappings.go_in = "<C-l>"')

  open(test_dir_path)
  show_help()
  child.expect_screenshot()
end

T['show_help()']['works when no explorer is opened'] = function() expect.no_error(show_help) end

T['get_fs_entry()'] = new_set()

local get_fs_entry = forward_lua('MiniFiles.get_fs_entry')

T['get_fs_entry()']['works'] = function()
  open(test_dir_path)
  local buf_id = child.api.nvim_get_current_buf()

  -- Directory
  local dir_res = { fs_type = 'directory', name = '.a-dir', path = full_path(test_dir_path, '.a-dir') }
  eq(get_fs_entry(buf_id, 1), dir_res)

  -- - Should use current cursor line by default
  eq(get_fs_entry(), dir_res)

  -- - Should allow 0 as buffer id
  eq(get_fs_entry(0, 1), dir_res)

  -- File
  local file_res = { fs_type = 'file', name = '.a-file', path = full_path(test_dir_path, '.a-file') }
  eq(get_fs_entry(buf_id, 4), file_res)

  -- User modified line. Should return "original" entry data (as long as
  -- entry's path id is not modified)
  set_cursor(4, 0)
  type_keys('A', '111', '<Esc>')
  eq(get_fs_entry(buf_id, 4), file_res)

  -- User created line
  type_keys('o', 'new_entry', '<Esc>')
  eq(get_fs_entry(buf_id, 5), vim.NIL)
end

T['get_fs_entry()']['validates input'] = function()
  expect.error(function() get_fs_entry() end, 'buf_id.*opened directory buffer')

  open(test_dir_path)
  expect.error(function() get_fs_entry(0, 1000) end, 'line.*valid line number in buffer %d')
end

T['get_target_window()'] = new_set()

local get_target_window = forward_lua('MiniFiles.get_target_window')

T['get_target_window()']['works'] = function()
  child.o.laststatus = 0

  child.cmd('belowright vertical split')
  local ref_win_id = child.api.nvim_get_current_win()

  local temp_dir = make_temp_dir('temp', {})
  open(temp_dir)
  eq(get_target_window(), ref_win_id)
end

T['get_target_window()']['ensures valid window'] = function()
  local init_win_id = child.api.nvim_get_current_win()
  child.cmd('belowright vertical split')
  local ref_win_id = child.api.nvim_get_current_win()

  open(test_dir_path)

  eq(get_target_window(), ref_win_id)

  child.api.nvim_win_close(ref_win_id, true)
  eq(get_target_window(), init_win_id)
end

T['get_target_window()']['works when no explorer is opened'] = function() expect.no_error(get_target_window) end

T['set_target_window()'] = new_set()

local set_target_window = forward_lua('MiniFiles.set_target_window')

T['set_target_window()']['works'] = function()
  local init_win_id = child.api.nvim_get_current_win()
  child.cmd('belowright vertical split')
  local ref_win_id = child.api.nvim_get_current_win()

  open(test_file_path)

  eq(get_target_window(), ref_win_id)
  set_target_window(init_win_id)
  eq(get_target_window(), init_win_id)

  go_in()
  eq(is_file_in_buffer(child.api.nvim_win_get_buf(init_win_id), test_file_path), true)
end

T['set_target_window()']['validates input'] = function()
  open(test_dir_path)
  expect.error(function() set_target_window(1) end, 'valid window')
end

T['set_target_window()']['works when no explorer is opened'] = function()
  expect.no_error(function() set_target_window(child.api.nvim_get_current_win()) end)
end

T['get_latest_path()'] = new_set()

local get_latest_path = forward_lua('MiniFiles.get_latest_path')

T['get_latest_path()']['works'] = function()
  -- Initially should return `nil`
  eq(get_latest_path(), vim.NIL)

  -- Should be updated after `open`
  open(test_dir_path)
  eq(get_latest_path(), full_path(test_dir_path))

  -- Should work after `close`
  close()
  eq(get_latest_path(), full_path(test_dir_path))

  -- Should work per tabpage
  child.cmd('tabedit')
  eq(get_latest_path(), vim.NIL)

  -- Should return parent path for file path (as it is anchor path)
  local file_path = join_path(test_dir_path, 'a-file')
  open(file_path)
  eq(get_latest_path(), full_path(test_dir_path))
end

T['default_filter()'] = new_set()

local default_filter = forward_lua('MiniFiles.default_filter')

T['default_filter()']['works'] = function()
  -- Should not filter anything out
  eq(default_filter(test_fs_entries[1]), true)
end

T['default_sort()'] = new_set()

local default_sort = forward_lua('MiniFiles.default_sort')

T['default_sort()']['works'] = function()
  local t = test_fs_entries
  local fs_entries_shuffled = { t[1], t[7], t[6], t[3], t[5], t[2], t[4] }
  eq(default_sort(fs_entries_shuffled), test_fs_entries)
end

-- Integration tests ==========================================================
T['Windows'] = new_set()

T['Windows']['reuses buffers for hidden directories'] = function()
  open(test_dir_path)
  go_in()
  local buf_id_ref = child.api.nvim_get_current_buf()

  -- Open another directory at this depth
  go_out()
  type_keys('j')
  go_in()

  -- Open again initial directory at this depth. Should reuse buffer.
  go_out()
  type_keys('k')
  go_in()

  eq(child.api.nvim_get_current_buf(), buf_id_ref)
end

T['Windows']['does not wrap content'] = function()
  child.set_size(10, 20)
  child.lua('MiniFiles.config.windows.width_focus = 10')
  local temp_dir = make_temp_dir('temp', { 'a a a a a a a a a a', 'file' })

  open(temp_dir)
  child.expect_screenshot()
end

T['Windows']['correctly computes part of branch to show'] = function()
  child.set_size(10, 80)

  child.lua('MiniFiles.config.windows.width_focus = 20')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')

  open(make_test_path('nested'))
  for _ = 1, 5 do
    go_in()
  end
  child.expect_screenshot()

  go_out()
  child.expect_screenshot()
  go_out()
  child.expect_screenshot()
  go_out()
  child.expect_screenshot()
  go_out()
  child.expect_screenshot()
  go_out()
  child.expect_screenshot()
end

T['Windows']['correctly computes part of branch to show with preview'] = function()
  child.set_size(10, 80)

  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_preview = 20')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')
  open(test_dir_path)
  go_in()
  child.expect_screenshot()
end

T['Windows']['is in sync with cursor'] = function()
  child.lua('MiniFiles.config.windows.width_focus = 20')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')

  open(make_test_path('nested'))
  go_in()
  go_in()
  go_in()

  -- No trimming when moving left-right
  go_out()
  child.expect_screenshot()
  go_out()
  go_out()
  go_in()
  child.expect_screenshot()

  -- Trims everything to the right when going up-down
  type_keys('j')
  child.expect_screenshot()

  -- Also trims if cursor is moved in Insert mode
  go_out()
  child.expect_screenshot()
  type_keys('o')
  child.expect_screenshot()
end

T['Windows']['reacts on `VimResized`'] = function()
  open(test_dir_path)
  go_in()

  -- Decreasing width
  child.o.columns = 60
  child.expect_screenshot()

  -- Increasing width
  child.o.columns = 80
  child.expect_screenshot()

  -- Decreasing height
  child.o.lines = 8
  child.expect_screenshot()

  -- Increasing height
  child.o.lines = 15
  child.expect_screenshot()
end

T['Windows']['works with too small dimensions'] = function()
  child.set_size(8, 15)
  open(test_dir_path)
  child.expect_screenshot()
end

T['Windows']['respects tabline when computing position'] = function()
  child.o.showtabline = 2
  open(test_dir_path)
  child.expect_screenshot()
end

T['Windows']['respects tabline and statusline when computing height'] = function()
  child.set_size(8, 60)

  local validate = function()
    open(test_dir_path)
    child.expect_screenshot()
    close()
  end

  child.o.showtabline, child.o.laststatus = 2, 2
  validate()

  child.o.showtabline, child.o.laststatus = 0, 2
  validate()

  child.o.showtabline, child.o.laststatus = 2, 0
  validate()

  child.o.showtabline, child.o.laststatus = 0, 0
  validate()
end

T['Windows']['uses correct UI highlight groups'] = function()
  local validate_winhl_match = function(win_id, from_hl, to_hl)
    -- Setting non-existing highlight group in 'winhighlight' is not supported
    -- in Neovim=0.7
    if child.fn.has('nvim-0.8') == 0 and from_hl == 'FloatTitle' then return end

    local winhl = child.api.nvim_win_get_option(win_id, 'winhighlight')

    -- Make sure entry is match in full
    local base_pattern = from_hl .. ':' .. to_hl
    local is_matched = winhl:find(base_pattern .. ',') ~= nil or winhl:find(base_pattern .. '$') ~= nil
    eq(is_matched, true)
  end

  open(test_dir_path)
  local win_id_1 = child.api.nvim_get_current_win()
  go_in()
  local win_id_2 = child.api.nvim_get_current_win()

  validate_winhl_match(win_id_1, 'NormalFloat', 'MiniFilesNormal')
  validate_winhl_match(win_id_1, 'FloatBorder', 'MiniFilesBorder')
  validate_winhl_match(win_id_1, 'FloatTitle', 'MiniFilesTitle')
  validate_winhl_match(win_id_1, 'CursorLine', 'MiniFilesCursorLine')
  validate_winhl_match(win_id_2, 'NormalFloat', 'MiniFilesNormal')
  validate_winhl_match(win_id_2, 'FloatBorder', 'MiniFilesBorder')
  validate_winhl_match(win_id_2, 'FloatTitle', 'MiniFilesTitleFocused')
  validate_winhl_match(win_id_2, 'CursorLine', 'MiniFilesCursorLine')

  -- Simply going in Insert mode should not add "modified"
  type_keys('i')
  validate_winhl_match(win_id_1, 'FloatBorder', 'MiniFilesBorder')
  validate_winhl_match(win_id_2, 'FloatBorder', 'MiniFilesBorder')

  type_keys('x')
  validate_winhl_match(win_id_1, 'FloatBorder', 'MiniFilesBorder')
  validate_winhl_match(win_id_2, 'FloatBorder', 'MiniFilesBorderModified')
end

T['Windows']['uses correct content highlight groups'] = function()
  open(test_dir_path)
  --stylua: ignore
  eq(
    get_extmarks_hl(),
    {
      "MiniFilesDirectory", "MiniFilesDirectory",
      "MiniFilesDirectory", "MiniFilesDirectory",
      "MiniFilesDirectory", "MiniFilesDirectory",
      "MiniFilesFile",      "MiniFilesFile",
      "MiniFilesFile",      "MiniFilesFile",
      "MiniFilesFile",      "MiniFilesFile",
      "MiniFilesFile",      "MiniFilesFile",
    }
  )
end

T['Windows']['correctly highlight content during editing'] = function()
  open(test_dir_path)
  type_keys('C', 'new-dir', '<Esc>')
  -- Highlighting of typed text should be the same as directories
  -- - Move cursor away for cursorcolumn to not obstruct the view
  type_keys('G')
  child.expect_screenshot()
end

T['Windows']['can be closed manually'] = function()
  open(test_dir_path)
  child.cmd('wincmd l | only')
  validate_n_wins(1)

  open(test_dir_path)
  validate_n_wins(2)

  close(test_dir_path)
  validate_n_wins(1)
end

T['Windows']['never shows past end of buffer'] = function()
  if child.fn.has('nvim-0.10') == 0 then MiniTest.skip('Screenshots are generated for 0.10.') end
  mock_confirm(1)

  -- Modifying buffer in Insert mode
  open(test_dir_path)
  type_keys('G', 'o')
  -- - Should increase height while first line still be visible
  child.expect_screenshot()

  child.ensure_normal_mode()
  close()

  -- Modifying buffer in Normal mode
  open(test_dir_path)
  type_keys('yj', 'G', 'p')
  child.expect_screenshot()

  close()

  -- Works when top line is not first buffer line
  child.set_size(10, 60)
  open(test_dir_path)
  type_keys('yj', 'G', 'p')
  child.expect_screenshot()
end

T['Preview'] = new_set()

T['Preview']['works for directories'] = function()
  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 25')

  -- Should open preview right after `open()`
  open(test_dir_path)
  child.expect_screenshot()

  -- Should update preview after cursor move
  type_keys('j')
  child.expect_screenshot()

  -- Should open preview right after `go_in()`
  go_in()
  child.expect_screenshot()
end

T['Preview']['works for files'] = function()
  local expect_screenshot = function()
    -- Test only on Neovim>=0.10 because there was major tree-sitter update
    if child.fn.has('nvim-0.10') == 1 then child.expect_screenshot() end
  end

  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 25')

  open(make_test_path('real'))

  -- Should preview Lua file with highlighting
  expect_screenshot()

  -- Should preview text file (also with enabled highlighting but as there is
  -- none defined, non should be visible)
  type_keys('j')
  expect_screenshot()

  -- Should read only maximum necessary amount of lines
  local buffers = child.api.nvim_list_bufs()
  local buf_id = buffers[#buffers]
  eq(#child.api.nvim_buf_get_lines(buf_id, 0, -1, false), child.o.lines)

  -- Should not set filetype
  eq(child.api.nvim_buf_get_option(buf_id, 'filetype'), 'minifiles')

  -- Should recognize binary files and show placeholder preview
  type_keys('j')
  expect_screenshot()

  -- Should work for empty files
  type_keys('j')
  expect_screenshot()

  -- Should fall back to built-in syntax highlighting in case of no tree-sitter
  type_keys('j')
  expect_screenshot()
end

T['Preview']['does not highlight big files'] = function()
  local big_file = make_test_path('big.lua')
  MiniTest.finally(function() child.fn.delete(big_file, 'rf') end)

  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 25')

  -- Has limit per line
  child.fn.writefile({ string.format('local a = "%s"', string.rep('a', 1000)) }, big_file)
  open(big_file)
  child.expect_screenshot()
  close()

  -- It also should have total limit, but it is not tested to not overuse file
  -- system accesses during test
end

T['Preview']['is not removed when going out'] = function()
  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 15')
  child.lua('MiniFiles.config.windows.width_preview = 15')

  open(test_dir_path)

  -- Directory preview
  type_keys('j')
  go_in()
  go_out()
  child.expect_screenshot()

  -- File preview
  go_in()
  go_in()
  go_out()
  go_out()
  child.expect_screenshot()
end

T['Preview']['reuses buffers'] = function()
  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 25')

  -- Show two previews (for directory and file) and hide them
  open(test_dir_path)
  type_keys('G')
  go_out()
  local all_buffers = child.api.nvim_list_bufs()
  trim_left()

  -- Show them again which should use same buffers
  go_in()
  type_keys('gg')
  eq(all_buffers, child.api.nvim_list_bufs())
end

T['Preview']['is not shown if not enough space'] = function()
  child.lua('MiniFiles.config.windows.preview = true')
  child.set_size(15, 60)
  open(test_dir_path)
  child.expect_screenshot()
end

T['Preview']['previews only one level deep'] = function()
  child.set_size(10, 80)

  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 25')

  open(make_test_path('nested'))
  child.expect_screenshot()
end

T['Preview']['handles user created lines'] = function()
  child.lua('MiniFiles.config.windows.preview = true')

  open(test_dir_path)
  type_keys('o', 'new_entry', '<Esc>')
  type_keys('k')

  child.expect_screenshot()
  type_keys('j')
  child.expect_screenshot()
  type_keys('j')
  child.expect_screenshot()
end

T['Preview']['works after `trim_left()`'] = function()
  child.set_size(10, 80)
  child.lua('MiniFiles.config.windows.preview = true')
  child.lua('MiniFiles.config.windows.width_focus = 25')

  open(make_test_path('nested'))
  go_in()
  trim_left()
  type_keys('j')
  child.expect_screenshot()
end

T['Mappings'] = new_set()

T['Mappings']['`close` works'] = function()
  -- Default
  open(test_dir_path)
  validate_n_wins(2)
  type_keys('q')
  validate_n_wins(1)
  close()

  -- User-supplied
  open(test_dir_path, false, { mappings = { close = 'Q' } })
  validate_n_wins(2)
  type_keys('Q')
  validate_n_wins(1)
  close()

  -- Empty
  open(test_dir_path, false, { mappings = { close = '' } })
  validate_n_wins(2)
  -- - Needs second `q` to unblock child process after built-in `q`
  type_keys('q', 'q')
  validate_n_wins(2)
end

T['Mappings']['`go_in` works'] = function()
  -- Default
  open(test_dir_path)
  validate_n_wins(2)
  type_keys('l')
  child.expect_screenshot()
  close()

  -- User-supplied
  open(test_dir_path, false, { mappings = { go_in = 'Q' } })
  validate_n_wins(2)
  type_keys('Q')
  validate_n_wins(3)
  close()

  -- Empty
  open(test_dir_path, false, { mappings = { go_in = '' } })
  validate_n_wins(2)
  type_keys('l')
  validate_n_wins(2)
end

T['Mappings']['`go_in` works in linewise Visual mode'] = function()
  -- DIsable statusline for more portable screenshots
  child.o.laststatus = 0

  local has_opened_buffer = function(name)
    local path = join_path(test_dir_path, name)
    for _, buf_id in ipairs(child.api.nvim_list_bufs()) do
      if is_file_in_buffer(buf_id, path) then return true end
    end
    return false
  end

  -- Should open all files
  open(test_dir_path)
  set_cursor(4, 0)
  type_keys('V', '2j')

  type_keys('l')
  eq(has_opened_buffer('.a-file'), true)
  eq(has_opened_buffer('a-file'), true)
  eq(has_opened_buffer('A-file-2'), true)
  -- - Should go back in Normal mode
  eq(child.fn.mode(), 'n')

  -- Should go in only last directory with cursor moved to its entry
  set_cursor(3, 0)
  type_keys('V', 'k')
  child.expect_screenshot()

  type_keys('l')
  child.expect_screenshot()
  eq(child.fn.mode(), 'n')

  -- Should work when selection contains both files and directories
  -- Cursor in initial window still should be moved to target entry
  close()
  child.cmd('%bwipeout')

  open(test_dir_path, false)
  set_cursor(3, 0)
  type_keys('V', 'j')

  type_keys('l')
  child.expect_screenshot()
  eq(has_opened_buffer('.a-file'), true)
  eq(child.fn.mode(), 'n')
end

T['Mappings']['`go_in` ignores non-linewise Visual mode'] = function()
  local validate = function(mode_key)
    open(test_dir_path, false)
    validate_n_wins(2)

    type_keys(mode_key, 'l')
    validate_n_wins(2)
    eq(child.fn.mode(), mode_key)

    child.ensure_normal_mode()
    close()
  end

  validate('v')
  -- '\22' is an escaped version of `<C-v>`
  validate('\22')
end

T['Mappings']['`go_in` supports <count>'] = function()
  child.set_size(15, 60)
  child.o.laststatus = 0
  child.lua('MiniFiles.config.windows.width_focus = 20')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')

  open(make_test_path('nested'))
  type_keys('2l')
  child.expect_screenshot()

  close()

  -- Works with high values ending at file
  open(test_dir_path)
  type_keys('10l')
  child.expect_screenshot()
end

T['Mappings']['`go_in_plus` works'] = function()
  -- Disable statusline for more portable screenshots
  child.o.laststatus = 0

  -- On directories should be the same as `go_in`
  -- Default
  open(test_dir_path)
  validate_n_wins(2)
  type_keys('L')
  child.expect_screenshot()
  close()

  -- User-supplied
  open(test_dir_path, false, { mappings = { go_in_plus = 'Q' } })
  validate_n_wins(2)
  type_keys('Q')
  validate_n_wins(3)
  close()

  -- Empty
  open(test_dir_path, false, { mappings = { go_in_plus = '' } })
  validate_n_wins(2)
  type_keys('L')
  validate_n_wins(2)
end

T['Mappings']['`go_in_plus` works on files'] = function()
  open(test_file_path)
  validate_n_wins(2)

  -- Should open file and close explorer
  type_keys('L')
  validate_n_wins(1)
  eq(is_file_in_buffer(0, test_file_path), true)
end

T['Mappings']['`go_in_plus` works on non-path entry'] = function()
  local temp_dir = make_temp_dir('temp', {})
  open(temp_dir)

  -- Empty line
  type_keys('L')
  eq(child.api.nvim_get_mode().blocking, false)

  -- Non-empty line
  type_keys('i', 'new-entry', '<Esc>')
  type_keys('L')
  eq(child.api.nvim_get_mode().blocking, false)
end

T['Mappings']['`go_in_plus` supports <count>'] = function()
  child.set_size(10, 50)
  child.o.laststatus = 0
  child.lua('MiniFiles.config.windows.width_focus = 20')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')

  open(make_test_path('nested'))
  type_keys('2L')
  child.expect_screenshot()

  close()

  -- Works with high values ending at file
  local temp_dir = make_temp_dir('temp', { 'file' })
  child.fn.writefile({ 'Temp file' }, join_path(temp_dir, 'file'))
  open(temp_dir)
  type_keys('10L')
  child.expect_screenshot()
end

T['Mappings']['`go_out` works'] = function()
  local path = make_test_path('common', 'a-dir')

  -- Default
  open(path)
  validate_n_wins(2)
  type_keys('h')
  child.expect_screenshot()
  close()

  -- User-supplied
  open(path, false, { mappings = { go_out = 'Q' } })
  validate_n_wins(2)
  type_keys('Q')
  validate_n_wins(3)
  close()

  -- Empty
  open(path, false, { mappings = { go_out = '' } })
  validate_n_wins(2)
  type_keys('h')
  validate_n_wins(2)
end

T['Mappings']['`go_out` supports <count>'] = function()
  child.set_size(10, 70)
  child.lua('MiniFiles.config.windows.width_focus = 20')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')

  open(make_test_path('nested', 'dir-1', 'dir-11'))
  go_in()
  go_in()
  child.expect_screenshot()

  type_keys('2h')
  child.expect_screenshot()
  type_keys('2h')
  child.expect_screenshot()
end

T['Mappings']['`go_out_plus` works'] = function()
  local path = make_test_path('common', 'a-dir')

  -- Default
  open(path)
  validate_n_wins(2)
  type_keys('H')
  child.expect_screenshot()
  close()

  -- User-supplied
  open(path, false, { mappings = { go_out_plus = 'Q' } })
  validate_n_wins(2)
  type_keys('Q')
  child.expect_screenshot()
  close()

  -- Empty
  open(path, false, { mappings = { go_out_plus = '' } })
  validate_n_wins(2)
  type_keys('H')
  child.expect_screenshot()
end

T['Mappings']['`go_out_plus` supports <count>'] = function()
  child.set_size(10, 70)
  child.lua('MiniFiles.config.windows.width_focus = 20')
  child.lua('MiniFiles.config.windows.width_nofocus = 10')

  open(make_test_path('nested', 'dir-1', 'dir-11'))
  go_in()
  go_in()
  child.expect_screenshot()

  type_keys('2H')
  child.expect_screenshot()
  type_keys('2H')
  child.expect_screenshot()
end

T['Mappings']['`reset` works'] = function()
  local prepare = function(...)
    close()
    open(...)
    type_keys('j')
    go_in()
  end

  -- Default
  prepare(test_dir_path)
  validate_n_wins(3)
  type_keys('<BS>')
  child.expect_screenshot()

  -- User-supplied
  prepare(test_dir_path, false, { mappings = { reset = 'Q' } })
  validate_n_wins(3)
  type_keys('Q')
  child.expect_screenshot()

  -- Empty
  prepare(test_dir_path, false, { mappings = { reset = '' } })
  validate_n_wins(3)
  type_keys('<BS>')
  child.expect_screenshot()
end

T['Mappings']['`reveal_cwd` works'] = function()
  child.set_size(10, 80)

  child.lua('MiniFiles.config.windows.width_focus = 20')
  local nested_path = make_test_path('nested')
  child.fn.chdir(nested_path)

  local prepare = function(...)
    close()
    open(...)
    go_in()
    go_in()
    trim_left()
  end

  -- Default
  prepare(nested_path)
  type_keys('@')
  child.expect_screenshot()

  -- User-supplied
  prepare(nested_path, false, { mappings = { reveal_cwd = 'Q' } })
  type_keys('Q')
  child.expect_screenshot()

  -- Empty
  prepare(nested_path, false, { mappings = { reveal_cwd = '' } })
  -- - Follow up `@` with register name to avoid blocking child process
  type_keys('@', 'a')
  child.expect_screenshot()
end

T['Mappings']['`show_help` works'] = function()
  child.set_size(20, 60)

  -- Default
  open(test_dir_path)
  validate_n_wins(2)
  type_keys('g?')
  child.expect_screenshot()
  type_keys('q')
  close()

  -- User-supplied
  open(test_dir_path, false, { mappings = { show_help = 'Q' } })
  validate_n_wins(2)
  type_keys('Q')
  child.expect_screenshot()
  type_keys('q')
  close()

  -- Empty
  open(test_dir_path, false, { mappings = { show_help = '' } })
  validate_n_wins(2)
  type_keys('g?')
  child.expect_screenshot()
end

T['Mappings']['`synchronize` works'] = function()
  child.set_size(10, 60)

  local temp_dir = make_temp_dir('temp', {})
  local validate = function(file_name, key)
    child.expect_screenshot()
    child.fn.writefile({}, join_path(temp_dir, file_name))
    type_keys(key)
    child.expect_screenshot()
  end

  -- Default
  open(temp_dir)
  validate('file-1', '=')
  close()

  -- User-supplied
  open(temp_dir, false, { mappings = { synchronize = 'Q' } })
  validate('file-2', 'Q')
  close()

  -- Empty
  open(temp_dir, false, { mappings = { synchronize = '' } })
  validate('file-3', '=')
end

T['Mappings']['`trim_left` works'] = function()
  -- Default
  open(test_dir_path)
  go_in()
  validate_n_wins(3)
  type_keys('<')
  child.expect_screenshot()
  close()

  -- User-supplied
  open(test_dir_path, false, { mappings = { trim_left = 'Q' } })
  go_in()
  validate_n_wins(3)
  type_keys('Q')
  validate_n_wins(2)
  close()

  -- Empty
  open(test_dir_path, false, { mappings = { trim_left = '' } })
  go_in()
  validate_n_wins(3)
  type_keys('<')
  validate_n_wins(3)
end

T['Mappings']['`trim_right` works'] = function()
  local path = make_test_path('common', 'a-dir')

  -- Default
  open(path)
  go_out()
  validate_n_wins(3)
  type_keys('>')
  child.expect_screenshot()
  close()

  -- User-supplied
  open(path, false, { mappings = { trim_right = 'Q' } })
  go_out()
  validate_n_wins(3)
  type_keys('Q')
  validate_n_wins(2)
  close()

  -- Empty
  open(path, false, { mappings = { trim_right = '' } })
  go_out()
  validate_n_wins(3)
  type_keys('>')
  validate_n_wins(3)
end

T['File manipulation'] = new_set()

T['File manipulation']['can create'] = function()
  child.set_size(10, 60)
  local temp_dir = make_temp_dir('temp', {})
  open(temp_dir)

  set_lines({ 'new-file', 'new-dir/' })
  set_cursor(1, 0)
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_file(temp_dir, 'new-file')
  validate_directory(temp_dir, 'new-dir')

  local ref_pattern = make_plain_pattern(
    'CONFIRM FILE SYSTEM ACTIONS',
    short_path(temp_dir) .. ':',
    [[  CREATE: 'new-file' (file)]],
    [[  CREATE: 'new-dir' (directory)]]
  )
  validate_confirm_args(ref_pattern)
end

T['File manipulation']['create does not override existing entry'] = function()
  child.set_size(10, 60)

  local temp_dir = make_temp_dir('temp', { 'file', 'dir/', 'dir/subfile' })
  local file_path = join_path(temp_dir, 'file')
  child.fn.writefile({ 'File' }, file_path)

  open(temp_dir)
  type_keys('o', 'file', '<CR>', 'dir/', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_file(file_path)
  validate_file_content(file_path, { 'File' })
  validate_file(temp_dir, 'dir', 'subfile')
end

T['File manipulation']['creates files in nested directories'] = function()
  child.set_size(10, 60)
  local temp_dir = make_temp_dir('temp', { 'dir/' })
  open(temp_dir)

  local lines = get_lines()
  -- Should work both in present directories and new ones (creating them)
  lines = vim.list_extend(lines, { 'dir/nested-file', 'dir-1/nested-file-1', 'dir-1/nested-file-2' })
  set_lines(lines)
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_file(temp_dir, 'dir', 'nested-file')
  validate_directory(temp_dir, 'dir-1')
  validate_file(temp_dir, 'dir-1', 'nested-file-1')
  validate_file(temp_dir, 'dir-1', 'nested-file-2')

  -- Validate separately because order is not guaranteed
  local ref_pattern_1 = make_plain_pattern(
    'CONFIRM FILE SYSTEM ACTIONS',
    short_path(temp_dir) .. '/dir' .. ':',
    [[  CREATE: 'nested-file' (file)]]
  )
  validate_confirm_args(ref_pattern_1)

  local ref_pattern_2 = make_plain_pattern(
    short_path(temp_dir) .. '/dir-1' .. ':',
    [[  CREATE: 'nested-file-1' (file)]],
    [[  CREATE: 'nested-file-2' (file)]]
  )
  validate_confirm_args(ref_pattern_2)
end

T['File manipulation']['creates nested directories'] = function()
  child.set_size(10, 60)
  local temp_dir = make_temp_dir('temp', { 'dir/' })
  open(temp_dir)

  local lines = get_lines()
  -- Should work both in present directories and new ones (creating them)
  lines = vim.list_extend(lines, { 'dir/nested-dir/', 'dir-1/nested-dir-1/', 'dir-1/nested-dir-2/' })
  set_lines(lines)
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_directory(temp_dir, 'dir', 'nested-dir')
  validate_directory(temp_dir, 'dir-1')
  validate_directory(temp_dir, 'dir-1', 'nested-dir-1')
  validate_directory(temp_dir, 'dir-1', 'nested-dir-2')

  -- Validate separately because order is not guaranteed
  local ref_pattern_1 = make_plain_pattern(
    'CONFIRM FILE SYSTEM ACTIONS',
    short_path(temp_dir) .. '/dir' .. ':',
    [[  CREATE: 'nested-dir' (directory)]]
  )
  validate_confirm_args(ref_pattern_1)

  local ref_pattern_2 = make_plain_pattern(
    short_path(temp_dir) .. '/dir-1' .. ':',
    [[  CREATE: 'nested-dir-1' (directory)]],
    [[  CREATE: 'nested-dir-2' (directory)]]
  )
  validate_confirm_args(ref_pattern_2)
end

T['File manipulation']['can delete'] = function()
  local temp_dir =
    make_temp_dir('temp', { 'file', 'empty-dir/', 'dir/', 'dir/file', 'dir/nested-dir/', 'dir/nested-dir/file' })
  open(temp_dir)

  set_lines({})
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_no_file(temp_dir, 'file')
  validate_no_directory(temp_dir, 'emptry-dir')
  validate_no_directory(temp_dir, 'dir')

  -- Validate separately because order is not guaranteed
  local ref_pattern = make_plain_pattern('CONFIRM FILE SYSTEM ACTIONS', short_path(temp_dir) .. ':')
  validate_confirm_args(ref_pattern)

  validate_confirm_args([[  DELETE: 'dir']])
  validate_confirm_args([[  DELETE: 'empty%-dir']])
  validate_confirm_args([[  DELETE: 'file']])
end

T['File manipulation']['delete respects `options.permanent_delete`'] = function()
  child.set_size(10, 60)

  -- Mock `stdpath()`
  local data_dir = mock_stdpath_data()
  local trash_dir = join_path(data_dir, 'mini.files', 'trash')

  -- Create temporary data and delete it
  child.lua('MiniFiles.config.options.permanent_delete = false')
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/', 'dir/subfile' })

  local validate_move_delete = function()
    -- Should move into special trash directory
    validate_no_file(temp_dir, 'file')
    validate_no_directory(temp_dir, 'dir')
    validate_file(trash_dir, 'file')
    validate_directory(trash_dir, 'dir')
    validate_file(trash_dir, 'dir', 'subfile')
  end

  open(temp_dir)

  type_keys('VGd')
  mock_confirm(1)
  synchronize()

  validate_move_delete()

  -- Deleting entries again with same name should replace previous ones
  -- - Recreate previously deleted entries with different content
  child.fn.writefile({ 'New file' }, join_path(temp_dir, 'file'))
  child.fn.mkdir(join_path(temp_dir, 'dir'))
  child.fn.writefile({ 'New subfile' }, join_path(temp_dir, 'dir', 'subfile'))

  mock_confirm(1)
  synchronize()

  -- - Delete again
  type_keys('VGd')
  mock_confirm(1)
  synchronize()

  validate_move_delete()

  -- - Check that files actually were replaced
  validate_file_content(join_path(trash_dir, 'file'), { 'New file' })
  validate_file_content(join_path(trash_dir, 'dir', 'subfile'), { 'New subfile' })
end

T['File manipulation']['can rename'] = function()
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/' })
  open(temp_dir)

  type_keys('C', 'new-dir', '<Esc>')
  type_keys('j', 'A', '-new', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_no_file(temp_dir, 'file')
  validate_file(temp_dir, 'file-new')
  validate_no_directory(temp_dir, 'dir')
  validate_directory(temp_dir, 'new-dir')

  -- Validate separately because order is not guaranteed
  local ref_pattern = make_plain_pattern('CONFIRM FILE SYSTEM ACTIONS', short_path(temp_dir) .. ':')
  validate_confirm_args(ref_pattern)

  validate_confirm_args([[  RENAME: 'dir' to 'new%-dir']])
  validate_confirm_args([[  RENAME: 'file' to 'file%-new']])
end

T['File manipulation']['rename does not override existing entry'] = function()
  child.set_size(10, 60)

  local temp_dir = make_temp_dir('temp', { 'dir/', 'dir-2/', 'file', 'file-2' })
  open(temp_dir)
  child.expect_screenshot()

  type_keys('A', '-2', '<Esc>')
  type_keys('2j', 'A', '-2', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()
end

T['File manipulation']['rename file renames opened buffers'] = function()
  local temp_dir = make_temp_dir('temp', { 'file' })

  local file_path_prev = join_path(temp_dir, 'file')
  child.cmd('edit ' .. file_path_prev)
  local buf_id = child.api.nvim_get_current_buf()

  open(temp_dir)
  type_keys('C', 'new-file', '<Esc>')

  eq(is_file_in_buffer(buf_id, file_path_prev), true)

  mock_confirm(1)
  synchronize()
  eq(is_file_in_buffer(buf_id, join_path(temp_dir, 'new-file')), true)
end

T['File manipulation']['rename directory renames opened buffers'] = function()
  local temp_dir = make_temp_dir('temp', { 'dir/', 'dir/file', 'dir/nested/', 'dir/nested/file-2' })

  local file_path_prev = join_path(temp_dir, 'dir', 'file')
  child.cmd('edit ' .. file_path_prev)
  local file_buf_id = child.api.nvim_get_current_buf()

  local descendant_path_prev = join_path(temp_dir, 'dir', 'nested', 'file-2')
  child.cmd('edit ' .. descendant_path_prev)
  local descendant_buf_id = child.api.nvim_get_current_buf()

  open(temp_dir)
  type_keys('C', 'new-dir', '<Esc>')

  eq(is_file_in_buffer(file_buf_id, file_path_prev), true)
  eq(is_file_in_buffer(descendant_buf_id, descendant_path_prev), true)

  mock_confirm(1)
  synchronize()
  eq(is_file_in_buffer(file_buf_id, join_path(temp_dir, 'new-dir', 'file')), true)
  eq(is_file_in_buffer(descendant_buf_id, join_path(temp_dir, 'new-dir', 'nested', 'file-2')), true)
end

T['File manipulation']['renames even if lines are rearranged'] = function()
  local temp_dir = make_temp_dir('temp', { 'file-1', 'file-2' })
  open(temp_dir)

  -- Rearrange lines
  type_keys('dd', 'p')

  type_keys('gg', 'C', 'new-file-2', '<Esc>')
  type_keys('j^', 'C', 'new-file-1', '<Esc>')

  mock_confirm(1)
  synchronize()

  validate_confirm_args([[RENAME: 'file%-2' to 'new%-file%-2']])
  validate_confirm_args([[RENAME: 'file%-1' to 'new%-file%-1']])
end

T['File manipulation']['rename works again after undo'] = function()
  local temp_dir = make_temp_dir('temp', { 'file' })
  open(temp_dir)

  type_keys('C', 'file-new', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()

  validate_no_file(temp_dir, 'file')
  validate_file(temp_dir, 'file-new')

  -- Validate confirmation messages
  local ref_pattern = make_plain_pattern('CONFIRM FILE SYSTEM ACTIONS', short_path(temp_dir) .. ':')
  validate_confirm_args(ref_pattern)
  validate_confirm_args([[  RENAME: 'file' to 'file%-new']])

  -- Undo and synchronize should cleanly rename back
  type_keys('u', 'u')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()

  validate_confirm_args([[  RENAME: 'file%-new' to 'file']])
  validate_file(temp_dir, 'file')
  validate_no_file(temp_dir, 'file-new')
end

T['File manipulation']['can move file'] = function()
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/' })
  open(temp_dir)

  -- Write lines in moved file to check actual move and not "delete-create"
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'file'))

  -- Perform manipulation
  type_keys('G', 'dd')
  go_in()
  type_keys('V', 'P')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_no_file(temp_dir, 'file')
  validate_file(temp_dir, 'dir', 'file')
  validate_file_content(join_path(temp_dir, 'dir', 'file'), { 'File' })

  -- Validate separately because order is not guaranteed
  local ref_pattern = make_plain_pattern('CONFIRM FILE SYSTEM ACTIONS', short_path(temp_dir) .. ':')
  validate_confirm_args(ref_pattern)

  -- - Target path should be absolute but can with `~` for home directory
  local target_path = short_path(temp_dir, 'dir', 'file')
  local ref_pattern_2 = string.format([[    MOVE: 'file' to '%s']], vim.pesc(target_path))
  validate_confirm_args(ref_pattern_2)
end

T['File manipulation']['can move directory'] = function()
  local temp_dir = make_temp_dir('temp', { 'dir/', 'dir/file', 'dir/nested/', 'dir/nested/file', 'dir-target/' })
  open(temp_dir)

  -- Write lines in moved file to check actual move and not "delete-create"
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'dir', 'file'))

  type_keys('dd')
  go_in()
  type_keys('V', 'P')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_no_directory(temp_dir, 'dir')
  validate_directory(temp_dir, 'dir-target', 'dir')
  validate_file_content(join_path(temp_dir, 'dir-target', 'dir', 'file'), { 'File' })

  local target_path = short_path(temp_dir, 'dir-target', 'dir')
  local ref_pattern = make_plain_pattern(
    'CONFIRM FILE SYSTEM ACTIONS',
    short_path(temp_dir) .. ':',
    string.format([[    MOVE: 'dir' to '%s']], target_path)
  )
  validate_confirm_args(ref_pattern)
end

T['File manipulation']['move does not override existing entry'] = function()
  child.set_size(10, 80)

  local temp_dir = make_temp_dir('temp', { 'dir/', 'file', 'target-dir/', 'target-dir/dir/', 'target-dir/file' })
  open(temp_dir)
  child.expect_screenshot()

  type_keys('dd', 'l', 'p')
  type_keys('h', 'G', 'dd', 'l', 'p')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()
end

T['File manipulation']['handles move directory inside itself'] = function()
  local temp_dir = make_temp_dir('temp', { 'dir/', 'dir/file', 'dir/nested/' })
  open(temp_dir)

  type_keys('yy')
  go_in()
  go_in()
  type_keys('V', 'p')
  go_out()
  go_out()
  type_keys('dd')
  child.expect_screenshot()

  -- Should ask for confirmation but silently not do this
  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_directory(temp_dir, 'dir')
  validate_no_directory(temp_dir, 'dir', 'nested', 'dir')

  validate_confirm_args([[    MOVE: 'dir' to '.*dir/nested/dir']])
end

T['File manipulation']['can move while changing basename'] = function()
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/' })
  open(temp_dir)

  -- Write lines in moved file to check actual move and not "delete-create"
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'file'))

  -- Perform manipulation
  type_keys('G', 'dd')
  go_in()
  type_keys('V', 'P')
  -- - Rename
  type_keys('C', 'new-file', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_no_file(temp_dir, 'file')
  validate_file(temp_dir, 'dir', 'new-file')
  validate_file_content(join_path(temp_dir, 'dir', 'new-file'), { 'File' })

  -- - Target path should be absolute but can with `~` for home directory
  local target_path = short_path(temp_dir, 'dir', 'new-file')
  local ref_pattern_2 = string.format([[    MOVE: 'file' to '%s']], vim.pesc(target_path))
  validate_confirm_args(ref_pattern_2)
end

T['File manipulation']['can move inside new directory'] = function()
  child.set_size(10, 60)

  local temp_dir = make_temp_dir('temp', { 'file' })
  open(temp_dir)

  -- Write lines in moved file to check actual move and not "delete-create"
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'file'))

  -- Perform manipulation
  type_keys('i', 'new-dir/new-subdir/', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_no_file(temp_dir, 'file')
  validate_file(temp_dir, 'new-dir', 'new-subdir', 'file')
  validate_file_content(join_path(temp_dir, 'new-dir', 'new-subdir', 'file'), { 'File' })
end

T['File manipulation']['move works again after undo'] = function()
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/' })
  open(temp_dir)

  -- Perform manipulation
  type_keys('G', 'dd')
  go_in()
  type_keys('V', 'P')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()

  validate_no_file(temp_dir, 'file')
  validate_file(temp_dir, 'dir', 'file')

  -- Validate confirmation messages
  local ref_pattern = make_plain_pattern('CONFIRM FILE SYSTEM ACTIONS', short_path(temp_dir) .. ':')
  validate_confirm_args(ref_pattern)

  -- - Target path should be absolute but can with `~` for home directory
  local target_path = short_path(temp_dir, 'dir', 'file')
  local ref_pattern_2 = string.format([[    MOVE: 'file' to '%s']], vim.pesc(target_path))
  validate_confirm_args(ref_pattern_2)

  -- Undos and synchronize should cleanly move back
  type_keys('u', 'u')
  go_out()
  type_keys('u', 'u')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()

  validate_file(temp_dir, 'file')
  validate_no_file(temp_dir, 'dir', 'file')

  local target_path_2 = short_path(temp_dir, 'file')
  local ref_pattern_3 = string.format([[    MOVE: 'file' to '%s']], vim.pesc(target_path_2))
  validate_confirm_args(ref_pattern_3)
end

T['File manipulation']['can copy file'] = function()
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/' })
  open(temp_dir)

  -- Write lines in copied file to check actual copy and not create
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'file'))

  -- Perform manipulation
  type_keys('j', 'yy', 'k')
  go_in()
  type_keys('V', 'P')
  -- - Should be able to copy in same directory
  go_out()
  type_keys('p', 'C', 'file-copy', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_file(temp_dir, 'file')
  validate_file_content(join_path(temp_dir, 'file'), { 'File' })
  validate_file(temp_dir, 'dir', 'file')
  validate_file_content(join_path(temp_dir, 'dir', 'file'), { 'File' })
  validate_file(temp_dir, 'file-copy')
  validate_file_content(join_path(temp_dir, 'file-copy'), { 'File' })

  -- Validate separately because order is not guaranteed
  local ref_pattern = make_plain_pattern('CONFIRM FILE SYSTEM ACTIONS', short_path(temp_dir) .. ':')
  validate_confirm_args(ref_pattern)

  -- - Target path should be absolute but can with `~` for home directory
  local target_path_1 = short_path(temp_dir, 'dir', 'file')
  local ref_pattern_1 = string.format([[    COPY: 'file' to '%s']], vim.pesc(target_path_1))
  validate_confirm_args(ref_pattern_1)

  local target_path_2 = short_path(temp_dir, 'file-copy')
  local ref_pattern_2 = string.format([[    COPY: 'file' to '%s']], vim.pesc(target_path_2))
  validate_confirm_args(ref_pattern_2)
end

T['File manipulation']['can copy file inside new directory'] = function()
  child.set_size(10, 60)

  local temp_dir = make_temp_dir('temp', { 'file' })
  open(temp_dir)

  -- Write lines in moved file to check actual move and not "delete-create"
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'file'))

  -- Perform manipulation
  type_keys('yy', 'p')
  type_keys('i', 'new-dir/new-subdir/', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_file(temp_dir, 'file')
  validate_file(temp_dir, 'new-dir', 'new-subdir', 'file')
  validate_file_content(join_path(temp_dir, 'new-dir', 'new-subdir', 'file'), { 'File' })
end

T['File manipulation']['can copy directory'] = function()
  local temp_dir = make_temp_dir('temp', { 'dir/', 'dir/file', 'dir/nested/', 'dir-target/' })
  open(temp_dir)

  -- Write lines in copied file to check actual copy and not create
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'dir', 'file'))

  -- Perform manipulation
  type_keys('yy', 'j')
  go_in()
  type_keys('V', 'P')
  -- - Should be able to copy in same directory
  go_out()
  type_keys('p', 'C', 'dir-copy', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_directory(temp_dir, 'dir')
  validate_file_content(join_path(temp_dir, 'dir', 'file'), { 'File' })

  validate_directory(temp_dir, 'dir-target', 'dir')
  validate_file(temp_dir, 'dir-target', 'dir', 'file')
  validate_file_content(join_path(temp_dir, 'dir-target', 'dir', 'file'), { 'File' })
  validate_directory(temp_dir, 'dir-target', 'dir', 'nested')

  validate_directory(temp_dir, 'dir-copy')
  validate_file(temp_dir, 'dir-copy', 'file')
  validate_file_content(join_path(temp_dir, 'dir-copy', 'file'), { 'File' })
  validate_directory(temp_dir, 'dir-copy', 'nested')

  -- Validate separately because order is not guaranteed
  local ref_pattern = make_plain_pattern('CONFIRM FILE SYSTEM ACTIONS', short_path(temp_dir) .. ':')
  validate_confirm_args(ref_pattern)

  -- - Target path should be absolute but can with `~` for home directory
  local target_path_1 = short_path(temp_dir, 'dir-target', 'dir')
  local ref_pattern_1 = string.format([[    COPY: 'dir' to '%s']], vim.pesc(target_path_1))
  validate_confirm_args(ref_pattern_1)

  local target_path_2 = short_path(temp_dir, 'dir-copy')
  local ref_pattern_2 = string.format([[    COPY: 'dir' to '%s']], vim.pesc(target_path_2))
  validate_confirm_args(ref_pattern_2)
end

T['File manipulation']['can copy directory inside new directory'] = function()
  child.set_size(10, 60)

  local temp_dir = make_temp_dir('temp', { 'dir/', 'dir/file', 'dir/nested/' })
  open(temp_dir)

  -- Write lines in copied file to check actual copy and not create
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'dir', 'file'))

  -- Perform manipulation
  type_keys('yy', 'p')
  type_keys('i', 'new-dir/new-subdir/', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_directory(temp_dir, 'dir')
  validate_directory(temp_dir, 'dir', 'nested')
  validate_file(temp_dir, 'dir', 'file')
  validate_file_content(join_path(temp_dir, 'dir', 'file'), { 'File' })

  validate_directory(temp_dir, 'new-dir', 'new-subdir', 'dir')
  validate_directory(temp_dir, 'new-dir', 'new-subdir', 'dir', 'nested')
  validate_file(temp_dir, 'new-dir', 'new-subdir', 'dir', 'file')
  validate_file_content(join_path(temp_dir, 'new-dir', 'new-subdir', 'dir', 'file'), { 'File' })
end

T['File manipulation']['copy does not override existing entry'] = function()
  child.set_size(10, 80)

  local temp_dir = make_temp_dir('temp', { 'dir/', 'file', 'target-dir/', 'target-dir/dir/', 'target-dir/file' })
  open(temp_dir)
  child.expect_screenshot()

  type_keys('yy', 'j', 'l', 'p')
  type_keys('h', 'G', 'yy', 'k', 'l', 'p')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()
end

T['File manipulation']['can copy directory inside itself'] = function()
  local temp_dir = make_temp_dir('temp', { 'dir/', 'dir/file', 'dir/nested/' })
  open(temp_dir)

  -- Write lines in copied file to check actual copy and not create
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'dir', 'file'))

  -- Perform manipulation
  type_keys('yy')
  go_in()
  type_keys('p')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_directory(temp_dir, 'dir')
  validate_file_content(join_path(temp_dir, 'dir', 'file'), { 'File' })

  validate_directory(temp_dir, 'dir', 'dir')
  validate_file(temp_dir, 'dir', 'dir', 'file')
  validate_file_content(join_path(temp_dir, 'dir', 'dir', 'file'), { 'File' })
  validate_directory(temp_dir, 'dir', 'dir', 'nested')

  -- Target path should be absolute but can with `~` for home directory
  local target_path = short_path(temp_dir, 'dir', 'dir')
  local ref_pattern = string.format([[    COPY: 'dir' to '%s']], vim.pesc(target_path))
  validate_confirm_args(ref_pattern)
end

T['File manipulation']['handles simultaneous copy and move'] = function()
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/' })
  open(temp_dir)

  -- Write lines in copied file to check actual move/copy
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'file'))

  -- Perform manipulation
  type_keys('j', 'dd')
  go_in()
  -- - Move
  type_keys('V', 'P')
  -- - Copy
  type_keys('P', 'C', 'file-1', '<Esc>')

  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_no_file(temp_dir, 'file')
  validate_file(temp_dir, 'dir', 'file')
  validate_file_content(join_path(temp_dir, 'dir', 'file'), { 'File' })
  validate_file(temp_dir, 'dir', 'file-1')
  validate_file_content(join_path(temp_dir, 'dir', 'file-1'), { 'File' })

  -- Validate separately as there is no guarantee which file is copied and
  -- which is moved
  validate_confirm_args('    COPY:')
  validate_confirm_args('    MOVE:')
end

T['File manipulation']['handles simultaneous copy and rename'] = function()
  local temp_dir = make_temp_dir('temp', { 'file' })
  open(temp_dir)

  -- Write lines in copied file to check actual move/copy
  child.fn.writefile({ 'File' }, join_path(temp_dir, 'file'))

  -- Perform manipulation
  type_keys('yy')
  -- - Rename
  type_keys('C', 'file-1', '<Esc>')
  -- - Copy
  type_keys('"0p', 'C', 'file-2', '<Esc>')
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()
  child.expect_screenshot()

  validate_no_file(temp_dir, 'file')
  validate_file(temp_dir, 'file-1')
  validate_file_content(join_path(temp_dir, 'file-1'), { 'File' })
  validate_file(temp_dir, 'file-2')
  validate_file_content(join_path(temp_dir, 'file-2'), { 'File' })

  -- Validate separately as there is no guarantee which file is copied and
  -- which is moved
  validate_confirm_args('    COPY:')
  validate_confirm_args('  RENAME:')
end

T['File manipulation']['respects modified hidden buffers'] = function()
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/' })
  open(temp_dir)

  go_in()
  type_keys('C', 'new-file', '<Esc>')
  go_out()
  trim_right()
  child.expect_screenshot()

  mock_confirm(1)
  synchronize()

  validate_file(temp_dir, 'dir', 'new-file')
end

T['File manipulation']['can be not confirmed'] = function()
  open(test_dir_path)
  type_keys('o', 'new-file', '<Esc>')

  child.expect_screenshot()
  mock_confirm(2)
  synchronize()
  child.expect_screenshot()
  validate_no_file(test_dir_path, 'new-file')
end

T['File manipulation']['can be not confirmed with preview'] = function()
  child.lua('MiniFiles.config.windows.preview = true')
  open(test_dir_path)
  type_keys('o', 'new-file', '<Esc>')

  child.expect_screenshot()
  mock_confirm(2)
  synchronize()
  child.expect_screenshot()
  validate_no_file(test_dir_path, 'new-file')
end

T['File manipulation']['works with problematic names'] = function()
  local temp_dir = make_temp_dir('temp', { [[a %file-]], 'b file' })
  open(temp_dir)

  -- Perform manipulation
  -- - Delete
  type_keys('dd')
  -- - Rename
  type_keys('C', 'c file', '<Esc>')
  -- - Create
  type_keys('o', 'd file', '<Esc>')
  if child.fn.has('nvim-0.10') == 1 then child.expect_screenshot() end

  mock_confirm(1)
  synchronize()
  if child.fn.has('nvim-0.10') == 1 then child.expect_screenshot() end

  validate_no_file(temp_dir, [[a %file-]])
  validate_no_file(temp_dir, 'b file')
  validate_file(temp_dir, 'c file')
  validate_file(temp_dir, 'd file')
end

T['File manipulation']['ignores blank lines'] = function()
  open(test_dir_path)
  type_keys('o', '<Esc>', 'yy', 'p')
  child.expect_screenshot()

  -- Should synchronize without confirmation
  synchronize()
  child.expect_screenshot()
end

T['File manipulation']['ignores identical user-copied entries'] = function()
  open(test_dir_path)
  type_keys('yj', 'p')
  child.expect_screenshot()

  -- Should synchronize without confirmation
  synchronize()
  child.expect_screenshot()
end

T['Cursors'] = new_set()

T['Cursors']['are preserved'] = function()
  open(test_dir_path)

  -- During navigation
  type_keys('j')
  go_in()
  go_in()
  go_out()
  validate_cur_line(1)
  type_keys('j')

  go_out()
  validate_cur_line(2)

  go_in()
  validate_cur_line(2)

  -- In hidden buffers
  go_out()
  trim_left()
  go_in()
  validate_cur_line(2)

  -- When opening from history
  close()
  open(test_dir_path, true)
  validate_cur_line(2)
  go_out()
  validate_cur_line(2)
end

T['Cursors']['not allowed to the left of the entry name'] = function()
  open(test_dir_path)
  local cursor = get_cursor()

  -- Normal mode
  type_keys('b')
  eq(get_cursor(), cursor)
  type_keys('10b')
  eq(get_cursor(), cursor)
  type_keys('0')
  eq(get_cursor(), cursor)

  set_cursor(cursor[1], 0)
  eq(get_cursor(), cursor)

  -- Insert mode
  type_keys('i')
  type_keys('<Left>')
  eq(get_cursor(), cursor)
end

T['Cursors']['handle `content.prefix` returning different lengths'] = function()
  child.lua([[
    _G.cur_prefix = ''
    MiniFiles.config.content.prefix = function()
      local res_prefix = _G.cur_prefix
      _G.cur_prefix = _G.cur_prefix .. '+'
      return res_prefix, 'Comment'
    end
  ]])

  open(test_dir_path)
  child.expect_screenshot()

  local cur_cursor = get_cursor()
  eq(cur_cursor, { 1, 4 })

  local offset = 0
  local validate_cursor = function()
    type_keys('j')
    offset = offset + 1
    eq(get_cursor(), { cur_cursor[1] + offset, cur_cursor[2] + offset })
  end

  validate_cursor()
  validate_cursor()
  validate_cursor()
end

T['Cursors']['shows whole line after horizontal scroll'] = function()
  child.set_size(10, 60)

  open(test_dir_path)

  type_keys('7zl')
  child.expect_screenshot()

  type_keys('2B')
  child.expect_screenshot()
end

T['Events'] = new_set()

local track_event = function(event_name)
  local lua_cmd = string.format(
    [[
    _G.callback_args_data = {}
    vim.api.nvim_create_autocmd(
      'User',
      {
        pattern = '%s',
        callback = function(args) table.insert(_G.callback_args_data, args.data or {}) end,
      }
    )
    ]],
    event_name
  )
  child.lua(lua_cmd)
end

local get_event_track = function() return child.lua_get('_G.callback_args_data') end

local clear_event_track = function() child.lua('_G.callback_args_data = {}') end

local validate_event_track = function(ref, do_sort)
  local event_track = child.lua_get('_G.callback_args_data')

  -- Neovim<0.8 doesn't have `data` field in event callback
  if child.fn.has('nvim-0.8') == 0 then
    eq(#event_track, #ref)
    return
  end

  if do_sort then table.sort(event_track, function(a, b) return a.buf_id < b.buf_id end) end
  eq(event_track, ref)
end

local validate_n_events = function(n_ref) eq(#child.lua_get('_G.callback_args_data'), n_ref) end

T['Events']['`MiniFilesBufferCreate` triggers'] = function()
  track_event('MiniFilesBufferCreate')

  open(test_dir_path)
  validate_event_track({ { buf_id = child.api.nvim_get_current_buf() } })
  clear_event_track()

  go_in()
  validate_event_track({ { buf_id = child.api.nvim_get_current_buf() } })
  clear_event_track()

  -- No event should be triggered if buffer is reused
  go_out()
  trim_right()
  go_in()

  validate_event_track({})
end

T['Events']['`MiniFilesBufferCreate` triggers inside preview'] = function()
  track_event('MiniFilesBufferCreate')

  child.lua('MiniFiles.config.windows.preview = true')
  open(test_dir_path)
  validate_n_events(2)

  type_keys('j')
  validate_n_events(3)

  -- No event should be triggered when going inside preview buffer (as it
  -- should be reused). But should also be triggered for file previews.
  clear_event_track()
  type_keys('k')
  go_in()
  validate_n_events(1)
end

T['Events']['`MiniFilesBufferCreate` can be used to create buffer-local mappings'] = function()
  if child.fn.has('nvim-0.8') == 0 then MiniTest.skip('`data` in autocmd callback was introduced in Neovim=0.8.') end

  child.lua([[
    _G.n = 0
    local rhs = function() _G.n = _G.n + 1 end
    vim.api.nvim_create_autocmd(
      'User',
      {
        pattern = 'MiniFilesBufferCreate',
        callback = function(args) vim.keymap.set('n', 'W', rhs, { buffer = args.data.buf_id }) end,
      }
    )
  ]])

  type_keys('W')
  eq(child.lua_get('_G.n'), 0)

  open(test_dir_path)
  type_keys('W')
  eq(child.lua_get('_G.n'), 1)

  go_in()
  type_keys('W')
  eq(child.lua_get('_G.n'), 2)
end

T['Events']['`MiniFilesBufferUpdate` triggers'] = function()
  track_event('MiniFilesBufferUpdate')

  open(test_dir_path)
  local buf_id_1, win_id_1 = child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()
  -- No `win_id` on first buffer update
  validate_event_track({ { buf_id = buf_id_1 } })
  clear_event_track()

  -- Force buffer updates
  synchronize()
  validate_event_track({ { buf_id = buf_id_1, win_id = win_id_1 } })
  clear_event_track()

  go_in()
  local buf_id_2, win_id_2 = child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()
  validate_event_track({ { buf_id = buf_id_2 } })
  clear_event_track()

  -- Force all buffer to update
  synchronize()

  -- - Force order, as there is no order guarantee of event trigger
  validate_event_track({ { buf_id = buf_id_1, win_id = win_id_1 }, { buf_id = buf_id_2, win_id = win_id_2 } }, true)
end

T['Events']['`MiniFilesWindowOpen` triggers'] = function()
  track_event('MiniFilesWindowOpen')

  open(test_dir_path)
  local buf_id_1, win_id_1 = child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()
  -- Should provide both `buf_id` and `win_id`
  validate_event_track({ { buf_id = buf_id_1, win_id = win_id_1 } })
  clear_event_track()

  go_in()
  local buf_id_2, win_id_2 = child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()
  validate_event_track({ { buf_id = buf_id_2, win_id = win_id_2 } })
  clear_event_track()

  -- Should indicate reused buffer but not window
  go_out()
  trim_right()
  go_in()
  local win_id_3 = child.api.nvim_get_current_win()
  validate_event_track({ { buf_id = buf_id_2, win_id = win_id_3 } })
end

T['Events']['`MiniFilesWindowOpen` can be used to create window-local mappings'] = function()
  if child.fn.has('nvim-0.8') == 0 then MiniTest.skip('`data` in autocmd callback was introduced in Neovim=0.8.') end

  child.lua([[
    vim.api.nvim_create_autocmd('User', {
      pattern = 'MiniFilesWindowOpen',
      callback = function(args)
        vim.api.nvim_win_set_config(args.data.win_id, { border = 'double' })
      end,
    })
  ]])

  open(test_dir_path)
  child.expect_screenshot()

  go_in()
  child.expect_screenshot()

  go_out()
  trim_right()
  go_in()
  child.expect_screenshot()
end

T['Events']['`MiniFilesWindowUpdate` triggers'] = function()
  track_event('MiniFilesWindowUpdate')

  open(test_dir_path)
  local buf_id_1, win_id_1 = child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()
  -- Should provide both `buf_id` and `win_id`
  validate_event_track({ { buf_id = buf_id_1, win_id = win_id_1 } })
  clear_event_track()

  go_in()
  local buf_id_2, win_id_2 = child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()

  -- - Force order, as there is no order guarantee of event trigger
  -- - Both windows should be updated
  validate_event_track({ { buf_id = buf_id_1, win_id = win_id_1 }, { buf_id = buf_id_2, win_id = win_id_2 } }, true)
end

T['Events']['`MiniFilesWindowUpdate` is not triggered for cursor move'] = function()
  track_event('MiniFilesWindowUpdate')

  open(test_dir_path)
  clear_event_track()

  type_keys('j')
  type_keys('<Right>')
  type_keys('i', '<Left>')
  validate_event_track({})
end

T['Events']['`MiniFilesActionCreate` triggers'] = function()
  track_event('MiniFilesActionCreate')

  local validate = function(entry, inject_external_create)
    local temp_dir = make_temp_dir('temp', {})
    local entry_name = entry:gsub('(.)/$', '%1')
    local entry_path = join_path(temp_dir, entry_name)
    open(temp_dir, false)

    -- Perform create
    type_keys('i', entry, '<Esc>')

    mock_confirm(1)
    if inject_external_create then child.fn.writefile({}, entry_path) end
    synchronize()

    -- If there was external create, then action was not successful and thus
    -- event should not trigger
    local ref = inject_external_create and {} or { { action = 'create', to = entry_path } }
    validate_event_track(ref)

    -- Cleanup
    close()
    child.fn.delete(temp_dir, 'rf')
    clear_event_track()
  end

  validate('file', false)
  validate('file', true)
  validate('dir/', false)
  validate('dir/', true)
end

T['Events']['`MiniFilesActionDelete` triggers'] = function()
  track_event('MiniFilesActionDelete')

  local validate = function(entry, inject_external_delete)
    local temp_dir = make_temp_dir('temp', { entry })
    local entry_name = entry:gsub('(.)/$', '%1')
    local entry_path = join_path(temp_dir, entry_name)
    open(temp_dir, false)

    -- Perform delete
    type_keys('dd')

    mock_confirm(1)
    if inject_external_delete then child.fn.delete(entry_path, 'rf') end
    synchronize()

    -- If there was external delete, then action was not successful and thus
    -- event should not trigger
    local ref = inject_external_delete and {} or { { action = 'delete', from = entry_path } }
    validate_event_track(ref)

    -- Cleanup
    close()
    child.fn.delete(temp_dir, 'rf')
    clear_event_track()
  end

  validate('file', false)
  validate('file', true)
  validate('dir/', false)
  validate('dir/', true)
end

T['Events']['`MiniFilesActionDelete` triggers for `options.permanent_delete = false`'] = function()
  track_event('MiniFilesActionDelete')

  child.lua('MiniFiles.config.options.permanent_delete = false')
  local temp_dir = make_temp_dir('temp', { 'file', 'dir/', 'dir/subfile' })
  open(temp_dir)

  type_keys('VGd')
  mock_confirm(1)
  synchronize()

  local event_track = get_event_track()
  if child.fn.has('nvim-0.8') == 0 then
    eq(#event_track, 2)
    return
  end

  table.sort(event_track, function(a, b) return a.from < b.from end)
  eq(event_track, {
    { action = 'delete', from = join_path(temp_dir, 'dir') },
    { action = 'delete', from = join_path(temp_dir, 'file') },
  })
end

T['Events']['`MiniFilesActionRename` triggers'] = function()
  track_event('MiniFilesActionRename')

  local validate = function(entry, inject_external_delete)
    local temp_dir = make_temp_dir('temp', { entry })
    local entry_name = entry:gsub('(.)/$', '%1')
    local entry_path = join_path(temp_dir, entry_name)
    open(temp_dir, false)

    -- Perform rename
    type_keys('A', '-new', '<Esc>')
    local new_entry_path = join_path(temp_dir, entry_name .. '-new')

    mock_confirm(1)
    if inject_external_delete then child.fn.delete(entry_path, 'rf') end
    synchronize()

    -- If there was external delete, then action was not successful and thus
    -- event should not trigger
    local ref = inject_external_delete and {} or { { action = 'rename', from = entry_path, to = new_entry_path } }
    validate_event_track(ref)

    -- Cleanup
    close()
    child.fn.delete(temp_dir, 'rf')
    clear_event_track()
  end

  validate('file', false)
  validate('file', true)
  validate('dir/', false)
  validate('dir/', true)
end

T['Events']['`MiniFilesActionCopy` triggers'] = function()
  track_event('MiniFilesActionCopy')

  local validate = function(entry, inject_external_delete)
    local temp_dir = make_temp_dir('temp', { entry })
    if entry == 'dir/' then
      -- Test on non-empty directory
      child.fn.mkdir(join_path(temp_dir, 'dir', 'subdir'))
      child.fn.writefile({}, join_path(temp_dir, 'dir', 'subdir', 'subfile'))
    end

    local entry_name = entry:gsub('(.)/$', '%1')
    local entry_path = join_path(temp_dir, entry_name)
    open(temp_dir, false)

    -- Perform copy in same parent directory
    type_keys('yy', 'p', 'A', '-new', '<Esc>')
    local new_entry_path = join_path(temp_dir, entry_name .. '-new')

    mock_confirm(1)
    if inject_external_delete then child.fn.delete(entry_path, 'rf') end
    synchronize()

    -- If there was external delete, then action was not successful and thus
    -- event should not trigger
    local ref = inject_external_delete and {} or { { action = 'copy', from = entry_path, to = new_entry_path } }
    validate_event_track(ref)

    -- Cleanup
    close()
    child.fn.delete(temp_dir, 'rf')
    clear_event_track()
  end

  validate('file', false)
  validate('file', true)
  validate('dir/', false)
  validate('dir/', true)
end

T['Events']['`MiniFilesActionMove` triggers'] = function()
  track_event('MiniFilesActionMove')

  local validate = function(entry, inject_external_delete)
    local temp_dir = make_temp_dir('temp', { entry, 'a-dir/' })
    local entry_name = entry:gsub('(.)/$', '%1')
    local entry_path = join_path(temp_dir, entry_name)
    open(temp_dir, false)

    -- Perform move
    type_keys('j', 'dd', 'l', 'p')
    local new_entry_path = join_path(temp_dir, 'a-dir', entry_name)

    mock_confirm(1)
    if inject_external_delete then child.fn.delete(entry_path, 'rf') end
    synchronize()

    -- If there was external delete, then action was not successful and thus
    -- event should not trigger
    local ref = inject_external_delete and {} or { { action = 'move', from = entry_path, to = new_entry_path } }
    validate_event_track(ref)

    -- Cleanup
    close()
    child.fn.delete(temp_dir, 'rf')
    clear_event_track()
  end

  validate('file', false)
  validate('file', true)
  validate('dir/', false)
  validate('dir/', true)
end

T['Default explorer'] = new_set()

T['Default explorer']['works on startup'] = function()
  vim.loop.os_setenv('USE_AS_DEFAULT_EXPLORER', 'true')
  child.restart({ '-u', make_test_path('init-default-explorer.lua'), '--', test_dir_path })
  child.expect_screenshot()

  -- Should hide scratch buffer on file open
  type_keys('G')
  go_in()
  close()
  eq(#child.api.nvim_list_bufs(), 1)
end

T['Default explorer']['respects `options.use_as_default_explorer`'] = function()
  vim.loop.os_setenv('USE_AS_DEFAULT_EXPLORER', 'false')
  child.restart({ '-u', make_test_path('init-default-explorer.lua'), '--', test_dir_path })
  eq(child.bo.filetype, 'netrw')
end

T['Default explorer']['works in `:edit .`'] = function()
  child.o.laststatus = 0
  child.cmd('edit ' .. test_dir_path)
  child.expect_screenshot()
end

T['Default explorer']['works in `:vsplit .`'] = function()
  child.o.laststatus = 0

  child.cmd('vsplit ' .. test_dir_path)
  child.expect_screenshot()

  type_keys('G')
  go_in()
  close()
  child.expect_screenshot()
  eq(#child.api.nvim_list_bufs(), 2)
end

T['Default explorer']['works in `:tabfind .`'] = function()
  child.set_size(15, 60)
  child.o.showtabline = 0
  child.o.laststatus = 0

  child.cmd('tabfind ' .. test_dir_path)
  child.expect_screenshot()

  type_keys('G')
  go_in()
  close()
  child.expect_screenshot()
  eq(#child.api.nvim_list_bufs(), 2)
  eq(#child.api.nvim_list_tabpages(), 2)
  eq(child.cmd('messages'), '')
end

T['Default explorer']['handles close without opening file'] = function()
  child.o.laststatus = 0
  child.cmd('edit ' .. test_dir_path)
  child.expect_screenshot()

  -- Should close and delete "scratch directory buffer"
  close()
  child.expect_screenshot()
  eq(child.api.nvim_buf_get_name(0), '')
end

return T
