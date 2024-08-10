local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

local fs_normalize = vim.fs.normalize
if vim.fn.has('nvim-0.9') == 0 then
  fs_normalize = function(...) return vim.fs.normalize(...):gsub('(.)/+$', '%1') end
end

local project_root = fs_normalize(vim.fn.fnamemodify(vim.fn.getcwd(), ':p'))
local dir_misc_path = project_root .. '/tests/dir-misc'

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('misc', config) end
local unload_module = function() child.mini_unload('misc') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
local make_path = function(...) return fs_normalize(table.concat({...}, '/')) end
local make_abspath = function(...) return make_path(project_root, ...) end
local getcwd = function() return fs_normalize(child.fn.getcwd()) end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local edit = function(x) child.cmd('edit ' .. x) end
--stylua: ignore end

-- Time constants
local small_time = helpers.get_time_const(10)
local no_term_response_delay = 1000

-- Output test set ============================================================
local T = new_set({
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
      child.lua('_G.small_time = ' .. small_time)
      child.lua('_G.f = function(ms) ms = ms or _G.small_time; vim.loop.sleep(ms); return ms end')
    end,
  },
})

local bench_time = function(...) return unpack(child.lua_get('{ MiniMisc.bench_time(_G.f, ...) }', { ... })) end

-- Validate that benchmark is within tolerable error from target. This is
-- needed due to random nature of benchmarks.
local validate_benchmark = function(time_tbl, target)
  helpers.skip_if_slow()

  local s, n = 0, 0
  for _, x in ipairs(time_tbl) do
    s, n = s + x, n + 1
  end

  local error = 0.2
  eq(n * target * (1 - error) < s, true)
  eq(s < target * (1 + error) * n, true)
end

T['bench_time()']['works'] = function()
  local b, res = bench_time()
  -- By default should run function once
  eq(#b, 1)
  validate_benchmark(b, 0.001 * small_time)
  -- Second value is function output
  eq(res, small_time)
end

T['bench_time()']['respects `n` argument'] = function()
  local b, _ = bench_time(5)
  -- By default should run function once
  eq(#b, 5)
  validate_benchmark(b, 0.001 * small_time)
end

T['bench_time()']['respects `...` as benched time arguments'] = function()
  local b, res = bench_time(1, 5 * small_time)
  validate_benchmark(b, 0.001 * 5 * small_time)
  -- Second value is function output
  eq(res, 5 * small_time)
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

local git_repo_path = make_abspath('tests/dir-misc/mocked-git-repo')
local git_path = make_abspath('tests/dir-misc/mocked-git-repo/.git')
local test_file_makefile = make_abspath('tests/dir-misc/aaa.lua')
local test_file_git = make_abspath('tests/dir-misc/mocked-git-repo/bbb.lua')

local init_mock_git = function(git_type)
  if git_type == 'file' then
    -- File '.git' is used inside submodules
    child.fn.writefile({ '' }, git_path)
  else
    child.fn.mkdir(git_path)
  end
end

local cleanup_mock_git = function() child.fn.delete(git_path, 'rf') end

T['setup_auto_root()'] = new_set({ hooks = { post_case = cleanup_mock_git } })

local setup_auto_root = function(...) child.lua('MiniMisc.setup_auto_root(...)', { ... }) end

T['setup_auto_root()']['works'] = function()
  eq(getcwd(), project_root)
  child.o.autochdir = true

  setup_auto_root()

  -- Resets 'autochdir'
  eq(child.o.autochdir, false)

  -- Creates autocommand
  eq(child.lua_get([[#vim.api.nvim_get_autocmds({ group = 'MiniMiscAutoRoot' })]]) > 0, true)

  -- Respects 'Makefile'
  child.cmd('edit ' .. test_file_makefile)
  eq(getcwd(), dir_misc_path)

  -- Respects '.git' directory and file
  for _, git_type in ipairs({ 'directory', 'file' }) do
    init_mock_git(git_type)
    child.cmd('edit ' .. test_file_git)
    eq(getcwd(), git_repo_path)
    cleanup_mock_git()
  end
end

T['setup_auto_root()']['validates input'] = function()
  expect.error(function() setup_auto_root('a') end, '`names`.*array')
  expect.error(function() setup_auto_root({ 1 }) end, '`names`.*string')
  expect.error(function() setup_auto_root({ '.git' }, 1) end, '`fallback`.*callable')
end

T['setup_auto_root()']['respects `names` argument'] = function()
  init_mock_git('directory')
  setup_auto_root({ 'Makefile' })

  -- Should not stop on git repo directory, but continue going up
  child.cmd('edit ' .. test_file_git)
  eq(getcwd(), dir_misc_path)
end

T['setup_auto_root()']['allows callable `names`'] = function()
  init_mock_git('directory')
  child.lua([[_G.find_aaa = function(x) return x == 'aaa.lua' end]])
  child.lua('MiniMisc.setup_auto_root(_G.find_aaa)')

  -- Should not stop on git repo directory, but continue going up
  child.cmd('edit ' .. test_file_git)
  eq(child.lua_get('MiniMisc.find_root(0, _G.find_aaa)'), dir_misc_path)
  eq(getcwd(), dir_misc_path)
end

T['setup_auto_root()']['respects `fallback` argument'] = function()
  -- Should return and cache fallback result if not found root by going up
  -- NOTE: More tests are done in `find_root()`
  local lua_cmd = string.format(
    [[MiniMisc.setup_auto_root({ 'non-existing' }, function(path) _G.path_arg = path; return %s end)]],
    vim.inspect(dir_misc_path)
  )
  child.lua(lua_cmd)

  child.cmd('edit ' .. test_file_git)
  eq(child.lua_get('_G.path_arg'), fs_normalize(child.api.nvim_buf_get_name(0)))
  eq(getcwd(), dir_misc_path)
end

T['setup_auto_root()']['works in buffers without path'] = function()
  setup_auto_root()

  local scratch_buf_id = child.api.nvim_create_buf(false, true)

  local cur_dir = getcwd()
  child.api.nvim_set_current_buf(scratch_buf_id)
  eq(getcwd(), cur_dir)
end

T['find_root()'] = new_set({ hooks = { post_case = cleanup_mock_git } })

local find_root = function(...) return child.lua_get('MiniMisc.find_root(...)', { ... }) end

T['find_root()']['works'] = function()
  -- Respects 'Makefile'
  child.cmd('edit ' .. test_file_makefile)
  eq(find_root(), dir_misc_path)
  child.cmd('%bwipeout')

  -- Respects '.git' directory and file
  for _, git_type in ipairs({ 'directory', 'file' }) do
    init_mock_git(git_type)
    child.cmd('edit ' .. test_file_git)
    eq(find_root(), git_repo_path)
    child.cmd('%bwipeout')
    cleanup_mock_git()
  end
end

T['find_root()']['validates arguments'] = function()
  expect.error(function() find_root('a') end, '`buf_id`.*number')
  expect.error(function() find_root(0, 1) end, '`names`.*string')
  expect.error(function() find_root(0, '.git') end, '`names`.*array')
  expect.error(function() find_root(0, { '.git' }, 1) end, '`fallback`.*callable')
end

T['find_root()']['respects `buf_id` argument'] = function()
  init_mock_git('directory')

  child.cmd('edit ' .. test_file_makefile)
  local init_buf_id = child.api.nvim_get_current_buf()
  child.cmd('edit ' .. test_file_git)
  eq(child.api.nvim_get_current_buf() ~= init_buf_id, true)

  eq(find_root(init_buf_id), dir_misc_path)
end

T['find_root()']['respects `names` argument'] = function()
  init_mock_git('directory')

  -- Should not stop on git repo directory, but continue going up
  child.cmd('edit ' .. test_file_git)
  eq(find_root(0, { 'aaa.lua' }), dir_misc_path)
end

T['find_root()']['allows callable `names`'] = function()
  init_mock_git('directory')
  child.cmd('edit ' .. test_file_git)

  child.lua([[_G.find_aaa = function(x) return x == 'aaa.lua' end]])
  eq(child.lua_get('MiniMisc.find_root(0, _G.find_aaa)'), dir_misc_path)
end

T['find_root()']['respects `fallback` argument'] = function()
  local validate = function(fallback_output, ref)
    local lua_cmd = string.format(
      [[MiniMisc.find_root(
        0,
        { 'non-existing' },
        function(path) _G.path_arg = path; return %s end
      )]],
      vim.inspect(fallback_output)
    )
    eq(child.lua_get(lua_cmd), ref)

    -- Fallback should be called with buffer path
    eq(child.lua_get('_G.path_arg'), fs_normalize(child.api.nvim_buf_get_name(0)))

    -- Cleanup
    child.lua('_G.path_arg = nil')
  end

  child.cmd('edit ' .. test_file_git)

  -- Should handle incorrect fallback return without setting it to cache
  validate(nil, vim.NIL)
  validate(1, vim.NIL)
  validate('non-existing', vim.NIL)

  -- Should return and cache fallback result if not found root by going up
  validate(dir_misc_path, dir_misc_path)

  local after_cache = child.lua_get([[MiniMisc.find_root(0, { 'non-existing' }, function() _G.been_here = true end)]])
  eq(after_cache, dir_misc_path)
  eq(child.lua_get('_G.been_here'), vim.NIL)
end

T['find_root()']['works in buffers without path'] = function()
  local scratch_buf_id = child.api.nvim_create_buf(false, true)
  child.api.nvim_set_current_buf(scratch_buf_id)
  eq(find_root(), vim.NIL)
end

T['find_root()']['uses cache'] = function()
  child.cmd('edit ' .. test_file_git)
  -- Returns root based on 'Makefile' as there is no git root
  eq(find_root(), dir_misc_path)

  -- Later creation of git root should not affect output as it should be cached
  -- from first call
  init_mock_git('directory')
  eq(find_root(), dir_misc_path)
end

T['setup_termbg_sync()'] = new_set({
  hooks = {
    pre_case = function()
      -- Mock `io.write` used to send control sequences to terminal emulator
      child.lua([[
        _G.log = {}
        io.write = function(...) table.insert(_G.log, { ... }) end
      ]])
    end,
  },
})

T['setup_termbg_sync()']['works'] = function()
  local eq_log = function(ref_log)
    eq(child.lua_get('_G.log'), ref_log)
    child.lua('_G.log = {}')
  end

  child.cmd('hi Normal guifg=#222222 guibg=#dddddd')
  child.lua('MiniMisc.setup_termbg_sync()')

  -- Should first ask if terminal emulator supports the feature
  eq_log({ { '\027]11;?\007' } })

  -- Mock typical response assuming '#11262d' as background color
  child.api.nvim_exec_autocmds('TermResponse', { data = '\27]11;rgb:1111/2626/2d2d' })

  -- Should sync immediately
  eq_log({ { '\027]11;#dddddd\007' } })

  -- Should sync on appropriate events
  local validate_event = function(event, log_entry)
    child.api.nvim_exec_autocmds(event, {})
    eq_log({ { log_entry } })
  end
  validate_event('UIEnter', '\027]11;#dddddd\007')
  validate_event('ColorScheme', '\027]11;#dddddd\007')
  validate_event('UILeave', '\027]11;#11262d\007')
end

T['setup_termbg_sync()']['can be called multiple times'] = function()
  child.cmd('hi Normal guifg=#222222 guibg=#dddddd')
  child.lua('MiniMisc.setup_termbg_sync()')
  child.api.nvim_exec_autocmds('TermResponse', { data = '\27]11;rgb:1111/2626/2d2d' })
  eq(child.lua_get('_G.log'), { { '\27]11;?\a' }, { '\27]11;#dddddd\a' } })
  child.lua('_G.log = {}')

  -- If called second time, the terminal background color is already synced
  child.lua('MiniMisc.setup_termbg_sync()')
  child.api.nvim_exec_autocmds('TermResponse', { data = '\27]11;rgb:dddd/dddd/dddd' })
  eq(child.lua_get('_G.log'), { { '\27]11;?\a' }, { '\27]11;#dddddd\a' } })
  child.lua('_G.log = {}')

  -- Should reset to the color from the very first call
  child.api.nvim_exec_autocmds('UILeave', {})
  eq(child.lua_get('_G.log'), { { '\27]11;#11262d\a' } })
end

T['setup_termbg_sync()']['handles no response from terminal emulator'] = function()
  child.lua('_G.notify_log = {}; vim.notify = function(...) table.insert(_G.notify_log, { ... }) end')
  child.lua('MiniMisc.setup_termbg_sync()')
  local validate_n_autocmds = function(ref_n)
    eq(#child.api.nvim_get_autocmds({ group = 'MiniMiscTermbgSync', event = 'TermResponse' }), ref_n)
  end
  validate_n_autocmds(1)

  -- If there is no response from terminal emulator for 1s, delete autocmd
  vim.loop.sleep(no_term_response_delay + small_time)
  validate_n_autocmds(0)

  -- Should show informative notification
  local ref_notify = {
    '(mini.misc) `setup_termbg_sync()` did not get response from terminal emulator',
    child.lua_get('vim.log.levels.WARN'),
  }
  eq(child.lua_get('_G.notify_log'), { ref_notify })
end

T['setup_termbg_sync()']['handles bad response from terminal emulator'] = function()
  child.lua('_G.notify_log = {}; vim.notify = function(...) table.insert(_G.notify_log, { ... }) end')
  child.lua('MiniMisc.setup_termbg_sync()')
  child.api.nvim_exec_autocmds('TermResponse', { data = 'something-bad' })
  -- Should not create any delete 'TermResponse' autocommand and not create any
  -- new ones
  eq(#child.api.nvim_get_autocmds({ group = 'MiniMiscTermbgSync' }), 0)

  -- Should show informative notification
  local ref_notify = {
    '(mini.misc) `setup_termbg_sync()` could not parse terminal emulator response "something-bad"',
    child.lua_get('vim.log.levels.WARN'),
  }
  eq(child.lua_get('_G.notify_log'), { ref_notify })
end

T['setup_termbg_sync()']['handles different color formats'] = function()
  local validate = function(term_response_color, ref_color)
    -- Mock clean start to overcome that color is parsed only once per session
    child.lua('package.loaded["mini.misc"] = nil')
    child.lua('require("mini.misc").setup_termbg_sync()')
    child.api.nvim_exec_autocmds('TermResponse', { data = '\27]11;' .. term_response_color })

    -- Should properly parse initial background and use it to reset on exit
    child.lua('_G.log = {}')
    child.api.nvim_exec_autocmds('UILeave', {})
    eq(child.lua_get('_G.log'), { { '\027]11;' .. ref_color .. '\007' } })

    -- Clean up
    child.lua('_G.log = {}')
    child.api.nvim_create_augroup('MiniMiscTermbgSync', { clear = true })
  end

  validate('rgb:1234/5678/9abc', '#12569a')
  validate('rgb:213/546/879', '#215487')
  validate('rgb:31/75/b9', '#3175b9')
  validate('rgb:4/8/c', '#4488cc')
  validate('rgb:1/23/456', '#112345')

  validate('rgba:1234/5678/9abc/1234', '#12569a')
  validate('rgba:213/546/879/1234', '#215487')
  validate('rgba:31/75/b9/1234', '#3175b9')
  validate('rgba:4/8/c/1234', '#4488cc')
  validate('rgba:1/23/456/1234', '#112345')
end

local restore_cursor_test_file = make_path(dir_misc_path, 'restore-cursor.lua')
local restore_cursor_init_file = make_path(dir_misc_path, 'init-restore-cursor.lua')
local restore_cursor_shada_path = make_path(dir_misc_path, 'restore-cursor.shada')

local cursor_set_test_type = function(x)
  vim.env.RESTORE_CURSOR_TEST_TYPE = x
  MiniTest.finally(function() vim.env.RESTORE_CURSOR_TEST_TYPE = '' end)
end

T['setup_restore_cursor()'] = new_set({
  hooks = {
    pre_case = function()
      -- Ensure that shada file is correctly set
      child.o.shadafile = restore_cursor_shada_path
    end,
    post_case = function()
      -- Don't save new shada file on child stop
      child.o.shadafile = 'NONE'

      -- Clean up
      child.fn.delete(restore_cursor_shada_path)
    end,
  },
})

T['setup_restore_cursor()']['works'] = function()
  edit(restore_cursor_test_file)
  set_cursor(10, 3)
  child.cmd('wshada!')

  child.restart({ '-u', restore_cursor_init_file, '--', restore_cursor_test_file })

  eq(get_cursor(), { 10, 3 })
  -- Should center by default
  eq(child.fn.line('w0'), 7)
end

T['setup_restore_cursor()']['validates input'] = function()
  local setup_restore_cursor = function(...) child.lua('MiniMisc.setup_restore_cursor(...)', { ... }) end

  expect.error(setup_restore_cursor, '`opts.center`.*boolean', { center = 1 })
  expect.error(setup_restore_cursor, '`opts.ignore_filetype`.*array', { ignore_filetype = 1 })
end

T['setup_restore_cursor()']['respects `opts.center`'] = function()
  edit(restore_cursor_test_file)
  set_cursor(10, 3)
  child.cmd('wshada!')

  cursor_set_test_type('not-center')
  child.restart({ '-u', restore_cursor_init_file, '--', restore_cursor_test_file })

  eq(get_cursor(), { 10, 3 })
  -- Should not center line
  eq(child.fn.line('w$'), 10)
end

T['setup_restore_cursor()']['respects `opts.ignore_filetype`'] = function()
  edit(restore_cursor_test_file)
  set_cursor(10, 3)
  child.cmd('wshada!')

  cursor_set_test_type('ignore-lua')
  child.restart({ '-u', restore_cursor_init_file, '--', restore_cursor_test_file })

  eq(get_cursor(), { 1, 0 })
end

T['setup_restore_cursor()']['restores only in normal buffer'] = function()
  edit(restore_cursor_test_file)
  set_cursor(10, 3)
  child.cmd('wshada!')

  cursor_set_test_type('set-not-normal-buftype')
  child.restart({ '-u', restore_cursor_init_file, '--', restore_cursor_test_file })

  eq(get_cursor(), { 1, 0 })
end

T['setup_restore_cursor()']['does not restore if position is already set'] = function()
  edit(restore_cursor_test_file)
  set_cursor(10, 3)
  child.cmd('wshada!')

  cursor_set_test_type('set-position')
  child.restart({ '-u', restore_cursor_init_file, '--', restore_cursor_test_file })

  eq(get_cursor(), { 4, 0 })

  -- Double check that `setup_restore_cursor()` was run
  expect.match(child.cmd_capture('au MiniMiscRestoreCursor'), 'BufRead')
end

T['setup_restore_cursor()']['does not restore if position is outdated'] = function()
  edit(restore_cursor_test_file)

  -- Ensure that file content won't change even on test case error
  local true_lines = get_lines()
  MiniTest.finally(function() vim.fn.writefile(true_lines, restore_cursor_test_file) end)

  set_cursor(10, 3)
  child.cmd('wshada!')
  child.cmd('bwipeout')

  -- Modify file so that position will appear outdated
  child.fn.writefile({ '-- bbb', '-- bbb' }, restore_cursor_test_file)

  child.restart({ '-u', restore_cursor_init_file, '--', restore_cursor_test_file })

  eq(get_cursor(), { 1, 0 })

  -- Double check that `setup_restore_cursor()` was run
  expect.match(child.cmd_capture('au MiniMiscRestoreCursor'), 'BufRead')
end

T['setup_restore_cursor()']['opens just enough folds'] = function()
  edit(restore_cursor_test_file)
  set_cursor(10, 3)
  child.cmd('wshada!')

  cursor_set_test_type('make-folds')
  child.restart({ '-u', restore_cursor_init_file, '--', restore_cursor_test_file })

  -- Should open only needed folds
  eq(get_cursor(), { 10, 3 })

  eq({ child.fn.foldclosed(2), child.fn.foldclosed(3) }, { 2, 2 })
  eq({ child.fn.foldclosed(9), child.fn.foldclosed(10) }, { -1, -1 })

  -- Double check that `setup_restore_cursor()` was run
  expect.match(child.cmd_capture('au MiniMiscRestoreCursor'), 'BufRead')
end

local stat_summary = function(...) return child.lua_get('MiniMisc.stat_summary({ ... })', { ... }) end

T['stat_summary()'] = new_set()

T['stat_summary()']['works'] = function()
  eq(stat_summary(10, 4, 3, 2, 1), { minimum = 1, mean = 4, median = 3, maximum = 10, n = 5, sd = math.sqrt(50 / 4) })
end

T['stat_summary()']['validates input'] = function()
  expect.error(stat_summary, 'array', 'a')
  expect.error(stat_summary, 'array', { a = 1 })
  expect.error(stat_summary, 'numbers', { 'a' })
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
  return vim.tbl_filter(
    function(x) return child.api.nvim_win_get_config(x).relative ~= '' end,
    child.api.nvim_list_wins()
  )
end

T['zoom()']['works'] = function()
  child.set_size(5, 20)
  set_lines({ 'aaa', 'bbb' })
  child.o.statusline = 'Statusline should not be visible in floating window'
  child.o.winblend = 50

  local buf_id = child.api.nvim_get_current_buf()
  child.lua('MiniMisc.zoom()')
  local floating_wins = get_floating_windows()

  eq(#floating_wins, 1)
  local win_id = floating_wins[1]
  eq(child.api.nvim_win_get_buf(win_id), buf_id)
  local config = child.api.nvim_win_get_config(win_id)
  eq({ config.height, config.width }, { 1000, 1000 })
  eq(child.api.nvim_win_get_option(win_id, 'winblend'), 0)

  -- No statusline should be present
  child.expect_screenshot()
end

T['zoom()']['respects `buf_id` argument'] = function()
  local buf_id = child.api.nvim_create_buf(true, false)
  child.lua('MiniMisc.zoom(...)', { buf_id })
  local floating_wins = get_floating_windows()

  eq(#floating_wins, 1)
  eq(child.api.nvim_win_get_buf(floating_wins[1]), buf_id)
end

T['zoom()']['respects `config` argument'] = function()
  child.set_size(5, 30)

  local custom_config = { width = 20 }
  child.lua('MiniMisc.zoom(...)', { 0, custom_config })
  local floating_wins = get_floating_windows()

  eq(#floating_wins, 1)
  local config = child.api.nvim_win_get_config(floating_wins[1])
  eq({ config.height, config.width }, { 1000, 20 })

  child.expect_screenshot()
end

return T
