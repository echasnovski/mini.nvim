-- General design of testing sessions is to have each session file define
-- `_G.session_file` variable with value being path to sourced session. So
-- these assumptions are assumed:
-- - If `_G.session_file` is `nil`, no session file was sourced.
-- - If `_G.session_file` is not `nil`, its value is a relative (to project
--   root) path to a session file that was sourced.
local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

local path_sep = package.config:sub(1, 1)
local project_root = vim.fn.getcwd()
local empty_dir_relpath = 'tests/sessions-tests/empty'
local empty_dir_path = vim.fn.fnamemodify(empty_dir_relpath, ':p')

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('sessions', config) end
local unload_module = function() child.mini_unload('sessions') end
local reload_module = function(config) unload_module(); load_module(config) end
local reload_from_strconfig = function(strconfig) unload_module(); child.mini_load_strconfig('sessions', strconfig) end
local set_lines = function(...) return child.set_lines(...) end
local make_path = function(...) return table.concat({...}, path_sep):gsub(path_sep .. path_sep, path_sep) end
local cd = function(...) child.cmd('cd ' .. make_path(...)) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Make helpers
local cleanup_directories = function()
  -- Cleanup files for directories to have invariant properties
  -- Ensure 'empty' directory doesn't exist
  child.fn.delete(empty_dir_path, 'rf')

  -- Ensure 'global' does not contain file 'Session.vim'
  local files = { 'tests/sessions-tests/global/Session.vim' }

  for _, f in ipairs(files) do
    child.fn.delete(f)
  end
end

local common_setup = function()
  child.setup()

  -- Ensure `require('mini.sessions')` is always possible (which might not be
  -- the case with all present `cd` calls)
  child.cmd('set rtp+=' .. project_root)

  -- Ensure always identical starting current directory
  cd(project_root)

  -- Avoid 'hit-enter-prompt' during setup. It seems to happen because child
  -- process can't find "stdpath('data')/session".
  child.o.cmdheight = 10

  -- Ensure directory structure invariants
  cleanup_directories()

  load_module()
end

local get_latest_message = function()
  return child.cmd_capture('1messages')
end

local get_buf_names = function()
  return child.lua_get('vim.tbl_map(function(x) return vim.fn.bufname(x) end, vim.api.nvim_list_bufs())')
end

local compare_buffer_names = function(x, y)
  -- Don't test exact equality because different Neovim versions create
  -- different buffer order when sourcing session (see
  -- https://github.com/vim/vim/pull/9520)
  table.sort(x)
  table.sort(y)
  eq(x, y)
end

-- Helpers for validating sessions
local populate_sessions = function(delay)
  delay = delay or 0

  child.fn.delete(empty_dir_path, 'rf')
  child.fn.mkdir(empty_dir_path)

  local make_file = function(name)
    local path = make_path(empty_dir_path, name)
    local value = make_path(empty_dir_relpath, name)
    child.fn.writefile({ ([[lua _G.session_file = '%s']]):format(value) }, path)
  end

  make_file('session_a')
  -- Modification time is up to seconds, so wait to ensure correct order
  sleep(delay)
  make_file('session_b')

  return empty_dir_path
end

local validate_session_loaded = function(relative_path)
  local path = make_path('tests/sessions-tests', relative_path)

  -- It should actually source file
  eq(child.lua_get('_G.session_file'), path)

  -- It should set `this_session`
  eq(child.v.this_session, make_path(project_root, path))
end

local validate_no_session_loaded = function()
  assert.True(child.lua_get('_G.session_file == nil'))
end

local reset_session_indicator = function()
  child.lua('_G.session_file = nil')
end

-- Helpers for testing hooks
--stylua: ignore start
local make_hook_string = function(pre_post, action, hook_type)
  if hook_type == 'config' then
    return string.format(
      [[{ %s = { %s = function() _G.hooks_%s_%s = 'config' end }}]],
      pre_post, action, pre_post, action
    )
  end
  if hook_type == 'opts' then
    return string.format(
      [[{ %s = function() _G.hooks_%s_%s = 'opts' end }]],
      pre_post, pre_post, action
    )
  end
end
--stylua: ignore end

local validate_executed_hook = function(pre_post, action, value)
  local var_name = ('_G.hooks_%s_%s'):format(pre_post, action)
  eq(child.lua_get(var_name), value)
end

-- Unit tests =================================================================
describe('MiniSessions.setup()', function()
  before_each(common_setup)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniSessions ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniSessions'), 1)
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniSessions.config)'), 'table')

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniSessions.config.' .. field), value)
    end

    assert_config('autoread', false)
    assert_config('autowrite', true)
    assert_config('directory', ('%s%ssession'):format(child.fn.stdpath('data'), path_sep))
    assert_config('file', 'Session.vim')
    assert_config('force', { read = false, write = true, delete = false })
    assert_config('hooks.pre', { read = nil, write = nil, delete = nil })
    assert_config('hooks.post', { read = nil, write = nil, delete = nil })
    assert_config('verbose', { read = false, write = true, delete = true })
  end)

  it('respects `config` argument', function()
    reload_module({ autoread = true })
    eq(child.lua_get('MiniSessions.config.autoread'), true)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ autoread = 'a' }, 'autoread', 'boolean')
    assert_config_error({ autowrite = 'a' }, 'autowrite', 'boolean')
    assert_config_error({ directory = 1 }, 'directory', 'string')
    assert_config_error({ file = 1 }, 'file', 'string')
    assert_config_error({ force = 'a' }, 'force', 'table')
    assert_config_error({ force = { read = 'a' } }, 'force.read', 'boolean')
    assert_config_error({ force = { write = 'a' } }, 'force.write', 'boolean')
    assert_config_error({ force = { delete = 'a' } }, 'force.delete', 'boolean')
    assert_config_error({ hooks = 'a' }, 'hooks', 'table')
    assert_config_error({ hooks = { pre = 'a' } }, 'hooks.pre', 'table')
    assert_config_error({ hooks = { pre = { read = 'a' } } }, 'hooks.pre.read', 'function')
    assert_config_error({ hooks = { pre = { write = 'a' } } }, 'hooks.pre.write', 'function')
    assert_config_error({ hooks = { pre = { delete = 'a' } } }, 'hooks.pre.delete', 'function')
    assert_config_error({ hooks = { post = 'a' } }, 'hooks.post', 'table')
    assert_config_error({ hooks = { post = { read = 'a' } } }, 'hooks.post.read', 'function')
    assert_config_error({ hooks = { post = { write = 'a' } } }, 'hooks.post.write', 'function')
    assert_config_error({ hooks = { post = { delete = 'a' } } }, 'hooks.post.delete', 'function')
    assert_config_error({ verbose = 'a' }, 'verbose', 'table')
    assert_config_error({ verbose = { read = 'a' } }, 'verbose.read', 'boolean')
    assert_config_error({ verbose = { write = 'a' } }, 'verbose.write', 'boolean')
    assert_config_error({ verbose = { delete = 'a' } }, 'verbose.delete', 'boolean')
  end)

  it('detects sessions and respects `config.directory`', function()
    cd('tests', 'sessions-tests')

    reload_module({ directory = 'global' })
    local detected = child.lua_get('MiniSessions.detected')

    -- Should be a table with correct keys
    eq(type(detected), 'table')
    local keys = vim.tbl_keys(detected)
    table.sort(keys)
    eq(keys, { 'Session.vim', 'session1', 'session2.vim', 'session3.lua' })

    -- Elements should have correct structure
    local cur_dir = child.fn.getcwd()
    local session_dir = make_path(cur_dir, 'global')
    for key, val in pairs(detected) do
      eq(type(val.modify_time), 'number')
      eq(val.name, key)

      if val.name == 'Session.vim' then
        eq(val.type, 'local')
        eq(val.path, make_path(cur_dir, 'Session.vim'))
      else
        eq(val.type, 'global')
        eq(val.path, make_path(session_dir, val.name))
      end
    end
  end)

  it('prefers local session file over global', function()
    -- Make file 'Session.vim' be in both `config.directory` and current one
    local path_local = 'tests/sessions-tests/global/Session.vim'
    child.fn.writefile({ ([[lua _G.session_file = '%s']]):format(path_local) }, path_local)

    cd('tests', 'sessions-tests')

    reload_module({ directory = 'global' })
    local detected = child.lua_get('MiniSessions.detected')
    local expected_path = vim.fn.fnamemodify('.', ':p') .. 'tests/sessions-tests/Session.vim'

    eq(detected['Session.vim'].path, expected_path)
  end)

  it('allows empty string for `config.directory`', function()
    reload_module({ directory = '' })
    eq(child.lua_get('MiniSessions.detected'), {})
  end)

  it('gives feedback about absent `config.directory`', function()
    reload_module({ directory = 'aaa' })
    assert.truthy(get_latest_message():find('%(mini%.sessions%).*aaa.*is not a directory path'))
  end)

  it('respects `config.file`', function()
    cd('tests', 'sessions-tests', 'local')

    reload_module({ autowrite = false, file = 'alternative-local-session' })
    local detected = child.lua_get('MiniSessions.detected')

    eq(detected['Session.vim'], nil)
    eq(detected['alternative-local-session'].type, 'local')
  end)

  it('allows empty string for `config.file`', function()
    cd('tests/sessions-tests')
    reload_module({ file = '' })
    local detected = child.lua_get('MiniSessions.detected')
    --stylua: ignore
    eq(vim.tbl_filter(function(x) return x.type == 'local' end, detected), {})
  end)
end)

describe('MiniSessions.detected', function()
  before_each(common_setup)

  it('is present', function()
    cd('tests', 'sessions-tests')
    reload_module({ directory = 'global' })
    eq(child.lua_get('type(MiniSessions.detected)'), 'table')
  end)

  it('is an empty table if no sessions are detected', function()
    eq(child.lua_get('MiniSessions.detected'), {})
  end)
end)

describe('MiniSessions.read()', function()
  before_each(common_setup)

  it('works', function()
    reload_module({ autowrite = false, directory = 'tests/sessions-tests/global' })
    child.lua([[MiniSessions.read('session1')]])
    validate_session_loaded('global/session1')
  end)

  it('works with no detected sessions', function()
    reload_module({ directory = '', file = '' })
    eq(child.lua_get('MiniSessions.detected'), {})
    assert.error_matches(function()
      child.lua('MiniSessions.read()')
    end, '%(mini%.sessions%) There is no detected sessions')
  end)

  it('accepts only name of detected session', function()
    reload_module({ autowrite = false, directory = 'tests/sessions-tests/global' })
    assert.error_matches(function()
      child.lua([[MiniSessions.read('session-absent')]])
    end, '%(mini%.sessions%) "session%-absent" is not a name for detected session')
    validate_no_session_loaded()
  end)

  local setup_unsaved_buffers = function()
    child.o.hidden = true
    local res = {}
    set_lines({ 'aaa' })
    table.insert(res, child.api.nvim_get_current_buf())

    child.cmd('e foo')
    set_lines({ 'bbb' })
    table.insert(res, child.api.nvim_get_current_buf())

    return res
  end

  it('does not source if there are unsaved changes', function()
    reload_module({ autowrite = false, directory = 'tests/sessions-tests/global' })

    -- Setup unsaved buffers
    local unsaved_buffers = setup_unsaved_buffers()

    -- Session should not be sourced
    local error_pattern = vim.pesc(
      '(mini.sessions) There are unsaved buffers: ' .. table.concat(unsaved_buffers, ', ') .. '.'
    )
    assert.error_matches(function()
      child.lua([[MiniSessions.read('session1')]])
    end, error_pattern)
    validate_no_session_loaded()
  end)

  it('uses by default local session', function()
    cd('tests', 'sessions-tests', 'local')
    reload_module({ autowrite = false, directory = 'tests/sessions-tests/global' })

    eq(child.lua_get([[MiniSessions.detected['Session.vim'].type]]), 'local')
    child.lua([[MiniSessions.read()]])
    validate_session_loaded('local/Session.vim')
  end)

  it('uses by default latest global session', function()
    local session_dir = populate_sessions(1000)

    reload_module({ autowrite = false, directory = session_dir })
    child.lua([[MiniSessions.read()]])
    validate_session_loaded('empty/session_b')
  end)

  it('respects `force` from `config` and `opts` argument', function()
    reload_module({ autowrite = false, directory = 'tests/sessions-tests/global', force = { read = true } })

    -- Should overwrite unsaved buffers and load session if `force` is `true`
    setup_unsaved_buffers()
    child.lua([[MiniSessions.read('session1')]])
    validate_session_loaded('global/session1')

    -- Should prefer `opts` over `config`
    setup_unsaved_buffers()
    reset_session_indicator()
    assert.error_matches(function()
      child.lua([[MiniSessions.read('session2.vim', { force = false })]])
    end, '%(mini%.sessions%) There are unsaved buffers')
    validate_no_session_loaded()
  end)

  local validate_hook = function(pre_post)
    -- Should use `config`
    local hook_string_config = make_hook_string(pre_post, 'read', 'config')
    reload_from_strconfig({
      autowrite = 'false',
      directory = [['tests/sessions-tests/global']],
      hooks = hook_string_config,
    })
    child.lua([[MiniSessions.read('session1')]])

    validate_session_loaded('global/session1')
    validate_executed_hook(pre_post, 'read', 'config')

    -- Should prefer `opts` over `config`
    local hook_string_opts = make_hook_string(pre_post, 'read', 'opts')
    child.lua(([[MiniSessions.read('session2.vim', { hooks = %s })]]):format(hook_string_opts))

    validate_session_loaded('global/session2.vim')
    validate_executed_hook(pre_post, 'read', 'opts')
  end

  it('respects `hooks.pre` from `config` and `opts` argument', function()
    validate_hook('pre')
  end)

  it('respects `hooks.post` from `config` and `opts` argument', function()
    validate_hook('post')
  end)

  it('respects `verbose` from `config` and `opts` argument', function()
    reload_module({ autowrite = false, directory = 'tests/sessions-tests/global', verbose = { read = true } })

    -- Should give message about read session
    child.lua([[MiniSessions.read('session1')]])
    validate_session_loaded('global/session1')
    assert.truthy(get_latest_message():find('%(mini%.sessions%) Read session.*session1'))

    -- Should prefer `opts` over `config`
    reset_session_indicator()
    child.lua([[MiniSessions.read('session2.vim', { verbose = false })]])
    validate_session_loaded('global/session2.vim')
  end)

  it('respects vim.{g,b}.minisessions_disable', function()
    reload_module({ autowrite = false, directory = 'tests/sessions-tests/global' })
    local validate_disable = function(var_type)
      child[var_type].minisessions_disable = true

      reset_session_indicator()
      child.lua([[MiniSessions.read('session1')]])
      validate_no_session_loaded()

      child[var_type].minisessions_disable = nil
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

describe('MiniSessions.write()', function()
  before_each(common_setup)

  it('works', function()
    child.fn.mkdir(empty_dir_path)
    reload_module({ autowrite = false, directory = empty_dir_path })

    -- Setup buffers
    child.cmd('e foo | e bar')
    local buf_names_expected = get_buf_names()
    child.lua([[MiniSessions.write('new_session')]])

    -- Should update `v:this_session`
    local path_expected = make_path(empty_dir_path, 'new_session')
    eq(child.v.this_session, path_expected)

    -- Verify that written session is correct
    child.cmd('%bwipeout')
    child.cmd('source ' .. path_expected)
    compare_buffer_names(get_buf_names(), buf_names_expected)
  end)

  it('updates `v:this_session`', function()
    child.fn.mkdir(empty_dir_path)
    reload_module({ autowrite = false, directory = empty_dir_path })

    eq(child.v.this_session, '')
    child.lua([[MiniSessions.write('new_session')]])
    eq(child.v.this_session, make_path(empty_dir_path, 'new_session'))
  end)

  it('updates `MiniSessions.detected` with new session', function()
    child.fn.mkdir(empty_dir_path)
    reload_module({ autowrite = false, directory = empty_dir_path })

    eq(child.lua_get('MiniSessions.detected'), {})
    child.lua([[MiniSessions.write('new_session')]])
    eq(child.lua_get('MiniSessions.detected.new_session').path, make_path(empty_dir_path, 'new_session'))
  end)

  it('updates `MiniSessions.detected` for present session', function()
    local session_dir = populate_sessions(1000)
    reload_module({ directory = session_dir })

    child.lua([[MiniSessions.read('session_a')]])
    sleep(1000)
    child.lua([[MiniSessions.write('session_a')]])

    local detected = child.lua_get('MiniSessions.detected')
    assert.True(detected.session_a.modify_time > detected.session_b.modify_time)
  end)

  it('validates `session_name`', function()
    reload_module({ autowrite = false, directory = 'tests/sessions-tests/global' })
    assert.error_matches(function()
      child.lua([[MiniSessions.write('')]])
    end, '%(mini%.sessions%) Supply non%-empty session name')
  end)

  it('writes by default to `v:this_session`', function()
    local session_dir = populate_sessions()
    reload_module({ directory = session_dir })
    child.lua([[MiniSessions.read('session_a')]])

    -- Verify that `v:this_session` points to correct place
    local session_path = make_path(session_dir, 'session_a')
    eq(child.v.this_session, session_path)

    -- Write session with `session_name = nil`
    child.cmd('e foo | e bar')
    local buf_names_expected = get_buf_names()
    child.lua('MiniSessions.write()')

    -- Verify that it was actually written to `v:this_session`
    child.cmd('%bwipeout!')
    child.cmd('source ' .. session_path)
    compare_buffer_names(get_buf_names(), buf_names_expected)
  end)

  it('writes to current directory if passed name of local session file', function()
    reload_module({ file = 'new-local-session', directory = '' })

    child.fn.mkdir(empty_dir_path)
    cd(empty_dir_path)
    child.lua([[MiniSessions.write('new-local-session')]])

    local path = make_path(empty_dir_path, 'new-local-session')
    assert.True(child.fn.filereadable(path) == 1)
  end)

  it('writes to global directory', function()
    child.fn.mkdir(empty_dir_path)
    reload_module({ file = '', directory = empty_dir_path })

    child.lua([[MiniSessions.write('new-global-session')]])

    local target_path = make_path(empty_dir_path, 'new-global-session')
    assert.True(child.fn.filereadable(target_path) == 1)
  end)

  it('respects `force` from `config` and `opts` argument', function()
    child.fn.mkdir(empty_dir_path)
    reload_module({ directory = empty_dir_path, force = { write = false } })

    -- Should not allow writing to existing file if `force` is `false`
    local path = make_path(empty_dir_path, 'existing-file')
    child.fn.writefile({}, path)

    assert.error_matches(function()
      child.lua([[MiniSessions.write('existing-file')]])
    end, [[%(mini%.sessions%) Can't write to existing]])
    eq(child.fn.readfile(path), {})

    -- Should prefer `opts` over `config`
    child.lua([[MiniSessions.write('existing-file', { force = true })]])
    assert.True(#child.fn.readfile(path) > 0)
  end)

  local validate_hook = function(pre_post)
    child.fn.mkdir(empty_dir_path)
    local path

    -- Should use `config`
    local hook_string_config = make_hook_string(pre_post, 'write', 'config')
    reload_from_strconfig({ directory = vim.inspect(empty_dir_path), hooks = hook_string_config })
    child.lua([[MiniSessions.write('file_01')]])

    path = make_path(empty_dir_path, 'file_01')
    assert.True(#child.fn.readfile(path) > 0)
    validate_executed_hook(pre_post, 'write', 'config')

    -- Should prefer `opts` over `config`
    local hook_string_opts = make_hook_string(pre_post, 'write', 'opts')
    child.lua(([[MiniSessions.write('file_02', { hooks = %s })]]):format(hook_string_opts))

    path = make_path(empty_dir_path, 'file_02')
    assert.True(#child.fn.readfile(path) > 0)
    validate_executed_hook(pre_post, 'write', 'opts')
  end

  it('respects `hooks.pre` from `config` and `opts` argument', function()
    validate_hook('pre')
  end)

  it('respects `hooks.post` from `config` and `opts` argument', function()
    validate_hook('post')
  end)

  it('respects `verbose` from `config` and `opts` argument', function()
    child.fn.mkdir(empty_dir_path)
    reload_module({ directory = empty_dir_path, verbose = { write = false } })
    local msg_pattern = '%(mini%.sessions%) Written session.*session%-written'

    -- Should not give message about written session
    child.lua([[MiniSessions.write('session-written')]])
    local path = make_path(empty_dir_path, 'session-written')
    assert.True(#child.fn.readfile(path) > 0)
    assert.falsy(get_latest_message():find(msg_pattern))

    -- Should prefer `opts` over `config`
    child.fn.delete(path)
    child.lua([[MiniSessions.write('session-written', { verbose = true })]])
    assert.True(#child.fn.readfile(path) > 0)
    assert.truthy(get_latest_message():find(msg_pattern))
  end)

  it('respects vim.{g,b}.minisessions_disable', function()
    child.fn.mkdir(empty_dir_path)
    reload_module({ directory = empty_dir_path })
    local path = make_path(empty_dir_path, 'session-file')

    local validate_disable = function(var_type)
      child[var_type].minisessions_disable = true

      child.fn.delete(path)
      child.lua([[MiniSessions.write('session-file')]])
      eq(child.fn.filereadable('session-file'), 0)

      child[var_type].minisessions_disable = nil
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

describe('MiniSessions.delete()', function()
  before_each(common_setup)

  it('works', function()
    local session_dir = populate_sessions()
    reload_module({ directory = session_dir })
    local path = make_path(session_dir, 'session_a')

    eq(child.lua_get('MiniSessions.detected')['session_a'].path, path)
    child.lua([[MiniSessions.delete('session_a')]])
    assert.True(child.fn.filereadable(path) == 0)
  end)

  it('validates presence of detected sessions', function()
    reload_module({ file = '', directory = '' })

    assert.error_matches(function()
      child.lua([[MiniSessions.delete('aaa')]])
    end, '%(mini%.sessions%) There is no detected sessions')
  end)

  it('validates `session_name`', function()
    reload_module({ directory = 'tests/sessions-tests/global' })
    assert.error_matches(function()
      child.lua([[MiniSessions.delete('')]])
    end, '%(mini%.sessions%) Supply non%-empty session name')
  end)

  it('deletes by default `v:this_session`', function()
    local session_dir = populate_sessions()
    reload_module({ directory = session_dir, force = { delete = true } })

    child.lua([[MiniSessions.read('session_a')]])
    local path = make_path(session_dir, 'session_a')
    eq(child.v.this_session, path)

    child.lua([[MiniSessions.delete()]])
    assert.True(child.fn.filereadable(path) == 0)

    -- Should also update `v:this_session`
    assert.True(child.v.this_session == '')
  end)

  it('deletes from current directory if passed name of local session file', function()
    local session_dir = populate_sessions()
    cd(session_dir)
    reload_module({ file = 'session_a', directory = '' })
    eq(child.lua_get('MiniSessions.detected.session_a.type'), 'local')

    child.lua([[MiniSessions.delete('session_a')]])

    local path = make_path(session_dir, 'session_a')
    assert.True(child.fn.filereadable(path) == 0)
  end)

  it('deletes from global directory', function()
    local session_dir = populate_sessions()
    reload_module({ file = '', directory = session_dir })
    eq(child.lua_get('MiniSessions.detected.session_a.type'), 'global')

    child.lua([[MiniSessions.delete('session_a')]])

    local path = make_path(session_dir, 'session_a')
    assert.True(child.fn.filereadable(path) == 0)
  end)

  it('deletes only detected session', function()
    local session_dir = populate_sessions()
    cd(session_dir)
    reload_module({ directory = session_dir })

    child.cmd('mksession')
    local path = make_path(session_dir, 'Session.vim')
    assert.True(child.fn.filereadable(path) == 1)
    assert.True(child.lua_get([[MiniSessions.detected['Session.vim'] == nil]]))

    -- Shouldn't delete `Session.vim` because it is not detected
    assert.error_matches(function()
      child.lua([[MiniSessions.delete('Session.vim')]])
    end, '%(mini%.sessions%) "Session%.vim" is not a name for detected session')
  end)

  it('respects `force` from `config` and `opts` argument', function()
    local session_dir = populate_sessions()
    reload_module({ directory = session_dir, force = { delete = true } })
    local path

    -- Should allow deleting current session if `force` is `false`
    child.lua([[MiniSessions.read('session_a')]])
    path = make_path(session_dir, 'session_a')
    eq(child.v.this_session, path)

    child.lua([[MiniSessions.delete('session_a')]])
    assert.True(child.fn.filereadable(path) == 0)

    -- Should prefer `opts` over `config`
    child.lua([[MiniSessions.read('session_b')]])
    path = make_path(session_dir, 'session_b')
    eq(child.v.this_session, path)

    assert.error_matches(function()
      child.lua([[MiniSessions.delete('session_b', { force = false })]])
    end, [[%(mini%.sessions%) Can't delete current session]])
    assert.True(child.fn.filereadable(path) == 1)
  end)

  local validate_hook = function(pre_post)
    local session_dir = populate_sessions()
    local path

    -- Should use `config`
    local hook_string_config = make_hook_string(pre_post, 'delete', 'config')
    reload_from_strconfig({ directory = vim.inspect(session_dir), hooks = hook_string_config })
    child.lua([[MiniSessions.delete('session_a')]])

    path = make_path(session_dir, 'session_a')
    assert.True(child.fn.filereadable(path) == 0)
    validate_executed_hook(pre_post, 'delete', 'config')

    -- Should prefer `opts` over `config`
    local hook_string_opts = make_hook_string(pre_post, 'delete', 'opts')
    child.lua(([[MiniSessions.delete('session_b', { hooks = %s })]]):format(hook_string_opts))

    path = make_path(session_dir, 'session_b')
    assert.True(child.fn.filereadable(path) == 0)
    validate_executed_hook(pre_post, 'delete', 'opts')
  end

  it('respects `hooks.pre` from `config` and `opts` argument', function()
    validate_hook('pre')
  end)

  it('respects `hooks.post` from `config` and `opts` argument', function()
    validate_hook('post')
  end)

  it('respects `verbose` from `config` and `opts` argument', function()
    local session_dir = populate_sessions()
    reload_module({ directory = session_dir, verbose = { delete = false } })
    local msg_pattern = '%(mini%.sessions%) Deleted session.*'
    local path

    -- Should not give message about deleted session
    child.lua([[MiniSessions.delete('session_a')]])
    path = make_path(session_dir, 'session_a')
    assert.True(child.fn.filereadable(path) == 0)
    assert.falsy(get_latest_message():find(msg_pattern .. 'session_a'))

    -- Should prefer `opts` over `config`
    child.lua([[MiniSessions.delete('session_b', { verbose = true })]])
    path = make_path(session_dir, 'session_b')
    assert.True(child.fn.filereadable(path) == 0)
    assert.truthy(get_latest_message():find(msg_pattern .. 'session_b'))
  end)

  it('respects vim.{g,b}.minisessions_disable', function()
    local session_dir = populate_sessions()
    reload_module({ directory = session_dir })
    local path = make_path(session_dir, 'session_a')

    local validate_disable = function(var_type)
      child[var_type].minisessions_disable = true

      if child.fn.filereadable(path) == 0 then
        populate_sessions()
      end
      child.lua([[MiniSessions.delete('session_a')]])
      assert.True(child.fn.filereadable(path) == 1)

      child[var_type].minisessions_disable = nil
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

describe('MiniSessions.select()', function()
  local session_dir
  before_each(function()
    common_setup()

    -- Mock `vim.ui.select`
    child.lua([[vim.ui = { select = function(...) _G.ui_select_args = { ... } end }]])

    -- Load module with detected sessions
    session_dir = populate_sessions()

    -- Add local session
    cd(session_dir)
    child.fn.writefile({}, make_path(session_dir, 'Session.vim'), '')

    reload_module({ directory = session_dir })

    -- Cleanup of current directory
    cd(project_root)
  end)

  it('works', function()
    child.lua('MiniSessions.select()')

    -- Should place local session first and then others alphabetically
    eq(child.lua_get('_G.ui_select_args[1]'), { 'Session.vim', 'session_a', 'session_b' })

    -- Should give informative prompt
    eq(child.lua_get('_G.ui_select_args[2].prompt'), 'Select session to read')

    -- Should format items by appending session type
    eq(child.lua_get([[_G.ui_select_args[2].format_item('Session.vim')]]), 'Session.vim (local)')
    eq(child.lua_get([[_G.ui_select_args[2].format_item('session_a')]]), 'session_a (global)')

    -- By default should read selected session
    validate_no_session_loaded()
    child.lua([[_G.ui_select_args[3]('session_a', 2)]])
    validate_session_loaded('empty/session_a')
  end)

  it('verifies presense of `vim.ui` and `vim.ui.select`', function()
    child.lua('vim.ui = 1')
    assert.error_matches(function()
      child.lua([[MiniSessions.select()]])
    end, '%(mini%.sessions%).*vim%.ui')

    child.lua('vim.ui = {}')
    assert.error_matches(function()
      child.lua([[MiniSessions.select()]])
    end, '%(mini%.sessions%).*vim%.ui%.select')
  end)

  it('validates `action` argument', function()
    assert.error_matches(function()
      child.lua([[MiniSessions.select('aaa')]])
    end, [[%(mini%.sessions%) `action` should be one of 'read', 'write', or 'delete'.]])
  end)

  it('respects `action` argument', function()
    local path = make_path(session_dir, 'session_a')
    assert.True(child.fn.filereadable(path) == 1)

    child.lua([[MiniSessions.select('delete')]])
    child.lua([[_G.ui_select_args[3]('session_a', 2)]])
    assert.True(child.fn.filereadable(path) == 0)
  end)

  it('respects `opts` argument', function()
    child.lua([[MiniSessions.select('read', { verbose = true })]])

    local msg_pattern = '%(mini%.sessions%) Read session.*session_a'
    assert.falsy(get_latest_message():find(msg_pattern))
    child.lua([[_G.ui_select_args[3]('session_a', 2)]])
    validate_session_loaded('empty/session_a')
    assert.truthy(get_latest_message():find(msg_pattern))
  end)
end)

describe('MiniSessions.get_latest()', function()
  before_each(function()
    child.setup()
    child.o.cmdheight = 10
    load_module()
  end)

  it('works', function()
    local session_dir = populate_sessions(1000)
    reload_module({ directory = session_dir })
    eq(child.lua_get('MiniSessions.get_latest()'), 'session_b')
  end)

  it('works if there is no detected sessions', function()
    reload_module({ directory = '', file = '' })
    eq(child.lua_get('MiniSessions.get_latest()'), vim.NIL)
  end)
end)

-- Functional tests ===========================================================
describe('Autoreading sessions', function()
  before_each(function()
    cd(project_root)
    cleanup_directories()
  end)

  it('works', function()
    child.restart({ '-u', 'tests/sessions-tests/init-files/autoread.lua' })
    validate_session_loaded('local/Session.vim')
  end)

  it('does not autoread if Neovim started to show something', function()
    local init_autoread = 'tests/sessions-tests/init-files/autoread.lua'

    -- Current buffer has any lines (something opened explicitly)
    child.restart({ '-u', init_autoread, '-c', [[call setline(1, 'a')]] })
    validate_no_session_loaded()

    -- Several buffers are listed (like session with placeholder buffers)
    child.restart({ '-u', init_autoread, '-c', 'e foo | set buflisted | e bar | set buflisted' })
    validate_no_session_loaded()

    -- Unlisted buffers (like from `nvim-tree`) don't affect decision
    child.restart({ '-u', init_autoread, '-c', 'e foo | set nobuflisted | e bar | set buflisted' })
    validate_session_loaded('local/Session.vim')

    -- There are files in arguments (like `nvim foo.txt` with new file).
    child.restart({ '-u', init_autoread, 'new-file.txt' })
    validate_no_session_loaded()
  end)
end)

describe('Autowriting sessions', function()
  before_each(function()
    cd(project_root)
    cleanup_directories()
  end)

  it('works', function()
    local init_autowrite = 'tests/sessions-tests/init-files/autowrite.lua'
    child.restart({ '-u', init_autowrite })

    -- Create session with one buffer, expect to autowrite it to have second
    child.fn.mkdir(empty_dir_path)
    cd(empty_dir_path)
    child.cmd('e aaa | w | mksession')
    local path_local = make_path(empty_dir_path, 'Session.vim')
    eq(child.fn.filereadable(path_local), 1)

    child.cmd('e bbb | w')
    child.restart()
    child.cmd('source ' .. path_local)
    compare_buffer_names(get_buf_names(), { 'aaa', 'bbb' })
  end)
end)

cleanup_directories()
child.stop()
