local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('statusline', config) end
local unload_module = function() child.mini_unload('statusline') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local set_width = function(width, win_id) child.api.nvim_win_set_width(win_id or 0, width) end
local type_keys = function(...) return child.type_keys(...) end
--stylua: ignore end

-- Make helpers
local setup_windows = function()
  child.cmd('%bwipeout!')

  -- Ensure only two windows
  if #child.api.nvim_list_wins() > 1 then
    child.cmd('only')
  end
  child.cmd('vsplit')

  local win_list = child.api.nvim_list_wins()
  if win_list[1] == child.api.nvim_get_current_win() then
    return { active = win_list[1], inactive = win_list[2] }
  end
  return { active = win_list[2], inactive = win_list[1] }
end

local common_setup = function()
  child.setup()
  load_module()

  -- Ensure wide enough window
  child.o.columns = 300
  setup_windows()
end

-- Mocks
local mock_devicons = function()
  child.cmd('set rtp+=tests/statusline-tests')
end

local mock_gitsigns = function(head, status)
  local cmd_head = ([[lua vim.b.gitsigns_head = '%s']]):format(head or 'main')
  local cmd_status = ([[lua vim.b.gitsigns_status = '%s']]):format(status or '+1 ~2 -3')

  -- Mock for current buffer
  child.cmd(cmd_head)
  child.cmd(cmd_status)

  -- Mock for future buffers
  child.cmd('augroup MockGitsigns')
  child.cmd('au!')
  child.cmd(('au BufEnter * %s'):format(cmd_head))
  child.cmd(('au BufEnter * %s'):format(cmd_status))
  child.cmd('augroup END')
end

local mock_diagnostics = function()
  child.cmd('luafile tests/statusline-tests/mock-diagnostics.lua')
end

local mocked_filepath = vim.fn.fnamemodify('tests/statusline-tests/mocked.lua', ':p')
local mock_file = function(bytes)
  -- Reduce one byte for '\n' at end
  local lines = { string.rep('a', bytes - 1) }

  vim.fn.writefile(lines, mocked_filepath)
end

local unmock_file = function()
  vim.fn.delete(mocked_filepath)
end

-- Unit tests =================================================================
describe('MiniStatusline.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniStatusline ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniStatusline'), 1)

    -- Highlight groups
    local has_highlight = function(group, value)
      assert.truthy(child.cmd_capture('hi ' .. group):find(value))
    end

    has_highlight('MiniStatuslineModeNormal', 'links to Cursor')
    has_highlight('MiniStatuslineModeInsert', 'links to DiffChange')
    has_highlight('MiniStatuslineModeVisual', 'links to DiffAdd')
    has_highlight('MiniStatuslineModeReplace', 'links to DiffDelete')
    has_highlight('MiniStatuslineModeCommand', 'links to DiffText')
    has_highlight('MiniStatuslineModeOther', 'links to IncSearch')
    has_highlight('MiniStatuslineDevinfo', 'links to StatusLine')
    has_highlight('MiniStatuslineFilename', 'links to StatusLineNC')
    has_highlight('MiniStatuslineFileinfo', 'links to StatusLine')
    has_highlight('MiniStatuslineInactive', 'links to StatusLineNC')
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniStatusline.config)'), 'table')

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniStatusline.config.' .. field), value)
    end

    assert_config('content.active', vim.NIL)
    assert_config('content.inactive', vim.NIL)
    assert_config('set_vim_settings', true)
  end)

  it('respects `config` argument', function()
    reload_module({ set_vim_settings = false })
    eq(child.lua_get('MiniStatusline.config.set_vim_settings'), false)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ content = 'a' }, 'content', 'table')
    assert_config_error({ content = { active = 'a' } }, 'content.active', 'function')
    assert_config_error({ content = { inactive = 'a' } }, 'content.inactive', 'function')
    assert_config_error({ set_vim_settings = 'a' }, 'set_vim_settings', 'boolean')
  end)

  it('sets proper autocommands', function()
    local validate = function(win_id, field)
      eq(child.api.nvim_win_get_option(win_id, 'statusline'), '%!v:lua.MiniStatusline.' .. field .. '()')
    end

    local wins = setup_windows()
    validate(wins.active, 'active')
    validate(wins.inactive, 'inactive')

    child.api.nvim_set_current_win(wins.inactive)
    validate(wins.active, 'inactive')
    validate(wins.inactive, 'active')
  end)

  it('respects `config.set_vim_settings`', function()
    reload_module({ set_vim_settings = true })
    eq(child.o.laststatus, 2)
  end)
end)

describe('MiniStatusline.combine_groups()', function()
  child.setup()
  load_module()

  local combine_groups = function(...)
    return child.lua_get('MiniStatusline.combine_groups(...)', { ... })
  end

  local example_groups = {
    { hl = 'AA', strings = { 'a1', 'a2' } },
    { hl = 'BB', strings = { 'b1', '', 'b2' } },
    '%=',
    { hl = 'CC', strings = { 'c1' } },
  }

  it('works', function()
    eq(combine_groups(example_groups), '%#AA# a1 a2 %#BB# b1 b2 %=%#CC# c1 ')
  end)

  it('handles non-table elements', function()
    -- Strings should be used as is, other non-table elements - filtered out
    eq(combine_groups({ 1, 'xxx', example_groups[1] }), 'xxx%#AA# a1 a2 ')
    eq(combine_groups({ example_groups[1], 'xxx' }), '%#AA# a1 a2 xxx')
    eq(combine_groups({ 'xxx', 'yyy' }), 'xxxyyy')
  end)

  it('uses only non-empty strings from `strings` field', function()
    eq(combine_groups({ { hl = 'AA', strings = { 'a', 1, {}, true, '', 'b' } } }), '%#AA# a b ')
  end)

  it('allows empty `hl` to use previous highlight group', function()
    eq(combine_groups({ { strings = { 'a' } }, { hl = 'BB', strings = { 'b' } } }), ' a %#BB# b ')
    eq(combine_groups({ { hl = 'BB', strings = { 'b' } }, { strings = { 'a' } } }), '%#BB# b  a ')
  end)

  it('allows empty `strings` to start new highlight', function()
    eq(combine_groups({ { hl = 'AA' }, { strings = { 'b1', 'b2' } } }), '%#AA# b1 b2 ')
    eq(combine_groups({ { hl = 'AA' }, { hl = 'BB', strings = { 'b1', 'b2' } } }), '%#AA#%#BB# b1 b2 ')
    eq(combine_groups({ { strings = { 'a1', 'a2' } }, { hl = 'BB' }, { strings = { 'c1' } } }), ' a1 a2 %#BB# c1 ')
  end)
end)

local validate_content = function(field)
  local eval_content = function()
    return child.lua_get(('MiniStatusline.%s()'):format(field))
  end

  it(('respects `config.content.%s`'):format(field), function()
    unload_module()
    local command = string.format(
      [[require('mini.statusline').setup({ content = { %s = function() return 'aaa' end } })]],
      field
    )
    child.lua(command)
    eq(eval_content(), 'aaa')
  end)

  it('respects vim.{g,b}.ministatusline_disable', function()
    local validate_disable = function(var_type)
      child[var_type].ministatusline_disable = true
      eq(eval_content(), '')

      child[var_type].ministatusline_disable = nil
    end

    validate_disable('g')
    validate_disable('b')
  end)
end

describe('MiniStatusline.active()', function()
  child.setup()
  load_module()

  validate_content('active')
end)

describe('MiniStatusline.inactive()', function()
  child.setup()
  load_module()

  validate_content('inactive')
end)

-- Sections -------------------------------------------------------------------
describe('MiniStatusline.section_diagnostics()', function()
  common_setup()

  before_each(mock_diagnostics)

  it('works', function()
    eq(child.lua_get('MiniStatusline.section_diagnostics({})'), ' E4 W3 I2 H1')

    -- Should return predefined string if no diagnostic output
    child.lua('vim.lsp.diagnostic.get_count = function(...) return 0 end')
    child.lua('vim.diagnostic.get = function(...) return {} end')
    eq(child.lua_get('MiniStatusline.section_diagnostics({})'), ' -')

    -- Should return empty string if no LSP client attached
    child.lua('vim.lsp.buf_get_clients = function() return {} end')
    eq(child.lua_get('MiniStatusline.section_diagnostics({})'), '')
  end)

  it('respects `args.trunc_width`', function()
    set_width(100)
    eq(child.lua_get('MiniStatusline.section_diagnostics({ trunc_width = 100 })'), ' E4 W3 I2 H1')
    set_width(99)
    eq(child.lua_get('MiniStatusline.section_diagnostics({ trunc_width = 100 })'), '')
  end)

  it('respects `args.icon`', function()
    eq(child.lua_get([[MiniStatusline.section_diagnostics({icon = 'A'})]]), 'A E4 W3 I2 H1')
    eq(child.lua_get([[MiniStatusline.section_diagnostics({icon = 'AAA'})]]), 'AAA E4 W3 I2 H1')
  end)

  it('is shown only in normal buffers', function()
    child.cmd('help')
    eq(child.lua_get('MiniStatusline.section_diagnostics({})'), '')
  end)

  it('respects `config.use_icons`', function()
    child.lua('MiniStatusline.config.use_icons = false')
    eq(child.lua_get([[MiniStatusline.section_diagnostics({})]]), 'LSP E4 W3 I2 H1')
  end)
end)

describe('MiniStatusline.section_fileinfo()', function()
  before_each(function()
    common_setup()
    mock_devicons()
  end)

  after_each(unmock_file)

  local validate_fileinfo = function(args, pattern)
    local command = ('MiniStatusline.section_fileinfo({ %s })'):format(args)
    local section = child.lua_get(command)
    assert.truthy(section:find(pattern))
  end

  it('works', function()
    mock_file(10)
    child.cmd('edit ' .. mocked_filepath)
    local encoding = child.bo.fileencoding or child.bo.encoding
    local format = child.bo.fileformat
    local pattern = '^ lua ' .. vim.pesc(encoding) .. '%[' .. vim.pesc(format) .. '%] 10B$'
    validate_fileinfo('', pattern)
  end)

  it('respects `args.trunc_width`', function()
    mock_file(10)
    child.cmd('edit ' .. mocked_filepath)

    set_width(100)
    validate_fileinfo('trunc_width = 100', '^ lua...')
    set_width(99)
    validate_fileinfo('trunc_width = 100', '^ lua$')
  end)

  it("correctly asks 'nvim-web-devicons' for icon", function()
    child.cmd('e tmp.txt')
    eq(child.lua_get('_G.devicons_args'), { filename = 'tmp.txt', extension = 'txt', options = { default = true } })
  end)

  it('uses correct filetype', function()
    child.bo.filetype = 'aaa'
    validate_fileinfo('', ' aaa ')
  end)

  it('uses human friendly size', function()
    mock_file(1024)
    child.cmd('edit ' .. mocked_filepath)
    validate_fileinfo('', '1%.00KiB$')
    unmock_file()

    mock_file(1024 * 1024)
    child.cmd('edit ' .. mocked_filepath)
    validate_fileinfo('', '1%.00MiB$')
    unmock_file()
  end)

  it('is shown only in normal buffers with filetypes', function()
    child.bo.filetype = ''
    validate_fileinfo('', '^$')

    child.cmd('help')
    validate_fileinfo('', '^$')
  end)
end)

describe('MiniStatusline.section_filename()', function()
  before_each(common_setup)

  it('works', function()
    local name = vim.fn.tempname()
    child.cmd('edit ' .. name)
    eq(child.lua_get('MiniStatusline.section_filename({})'), '%F%m%r')

    -- Should work in terminal
    child.cmd('terminal')
    eq(child.lua_get('MiniStatusline.section_filename({})'), '%t')
  end)

  it('respects `args.trunc_width`', function()
    local name = vim.fn.tempname()
    child.cmd('edit ' .. name)

    set_width(100)
    eq(child.lua_get('MiniStatusline.section_filename({ trunc_width = 100 })'), '%F%m%r')
    set_width(99)
    eq(child.lua_get('MiniStatusline.section_filename({ trunc_width = 100 })'), '%f%m%r')
  end)
end)

describe('MiniStatusline.section_git()', function()
  common_setup()

  before_each(mock_gitsigns)

  it('works', function()
    eq(child.lua_get('MiniStatusline.section_git({})'), ' main +1 ~2 -3')

    -- Should show signs even if there is no branch
    child.b.gitsigns_head = nil
    eq(child.lua_get('MiniStatusline.section_git({})'), ' - +1 ~2 -3')

    -- Should not have trailing whitespace if git status is empty
    child.b.gitsigns_head, child.b.gitsigns_status = 'main', ''
    eq(child.lua_get('MiniStatusline.section_git({})'), ' main')

    -- Should return empty string if no Git is found
    child.b.gitsigns_head, child.b.gitsigns_status = nil, nil
    eq(child.lua_get('MiniStatusline.section_git({})'), '')

    child.b.gitsigns_head, child.b.gitsigns_status = '', ''
    eq(child.lua_get('MiniStatusline.section_git({})'), '')
  end)

  it('respects `args.trunc_width`', function()
    set_width(100)
    eq(child.lua_get('MiniStatusline.section_git({ trunc_width = 100 })'), ' main +1 ~2 -3')
    set_width(99)
    eq(child.lua_get('MiniStatusline.section_git({ trunc_width = 100 })'), ' main')
  end)

  it('respects `args.icon`', function()
    eq(child.lua_get([[MiniStatusline.section_git({icon = 'A'})]]), 'A main +1 ~2 -3')
    eq(child.lua_get([[MiniStatusline.section_git({icon = 'AAA'})]]), 'AAA main +1 ~2 -3')
  end)

  it('is shown only in normal buffers', function()
    child.cmd('help')
    eq(child.lua_get('MiniStatusline.section_git({})'), '')
  end)

  it('respects `config.use_icons`', function()
    child.lua('MiniStatusline.config.use_icons = false')
    eq(child.lua_get([[MiniStatusline.section_git({})]]), 'Git main +1 ~2 -3')
  end)
end)

describe('MiniStatusline.section_location()', function()
  common_setup()

  it('works', function()
    eq(child.lua_get('MiniStatusline.section_location({})'), '%l|%L│%2v|%-2{virtcol("$") - 1}')
  end)

  it('respects `args.trunc_width`', function()
    set_width(100)
    eq(child.lua_get('MiniStatusline.section_location({ trunc_width = 100 })'), '%l|%L│%2v|%-2{virtcol("$") - 1}')
    set_width(99)
    eq(child.lua_get('MiniStatusline.section_location({ trunc_width = 100 })'), '%l│%2v')
  end)
end)

describe('MiniStatusline.section_mode()', function()
  common_setup()

  after_each(child.ensure_normal_mode)

  local section_mode = function(args)
    return child.lua_get('{ MiniStatusline.section_mode(...) }', { args or {} })
  end

  it('works', function()
    eq(section_mode(), { 'Normal', 'MiniStatuslineModeNormal' })
  end)

  it('shows correct mode', function()
    local validate = function(output)
      eq(section_mode(), output)
      child.ensure_normal_mode()
    end

    child.cmd('startinsert')
    validate({ 'Insert', 'MiniStatuslineModeInsert' })

    type_keys('v')
    validate({ 'Visual', 'MiniStatuslineModeVisual' })

    type_keys('V')
    validate({ 'V-Line', 'MiniStatuslineModeVisual' })

    type_keys('<C-V>')
    validate({ 'V-Block', 'MiniStatuslineModeVisual' })

    type_keys(':')
    validate({ 'Command', 'MiniStatuslineModeCommand' })

    type_keys('R')
    validate({ 'Replace', 'MiniStatuslineModeReplace' })

    child.cmd('terminal')
    child.cmd('startinsert')
    validate({ 'Terminal', 'MiniStatuslineModeOther' })
  end)

  it('respects `args.trunc_width`', function()
    set_width(100)
    eq(section_mode({ trunc_width = 100 }), { 'Normal', 'MiniStatuslineModeNormal' })
    set_width(99)
    eq(section_mode({ trunc_width = 100 }), { 'N', 'MiniStatuslineModeNormal' })
  end)
end)

describe('MiniStatusline.section_searchcount()', function()
  before_each(function()
    common_setup()
    mock_file(10)
    child.cmd('edit! ' .. mocked_filepath)
  end)

  after_each(unmock_file)

  local section_searchcount = function(args)
    return child.lua_get('MiniStatusline.section_searchcount(...)', { args or {} })
  end

  it('works', function()
    set_lines({ '', 'a a a ' })

    -- Shows nothing if search is not initiated
    eq(section_searchcount(), '')

    type_keys('/', 'a', '<CR>')
    set_cursor(1, 0)
    eq(section_searchcount(), '0/3')

    set_cursor(2, 0)
    eq(section_searchcount(), '1/3')

    set_cursor(2, 1)
    eq(section_searchcount(), '1/3')

    set_cursor(2, 5)
    eq(section_searchcount(), '3/3')
  end)

  it('works with many search matches', function()
    set_lines({ string.rep('a ', 101) })
    type_keys('/', 'a', '<CR>')
    set_cursor(1, 0)
    eq(section_searchcount(), '1/>99')

    set_cursor(1, 197)
    eq(section_searchcount(), '99/>99')

    set_cursor(1, 198)
    eq(section_searchcount(), '>99/>99')
  end)

  it('respects `args.trunc_width`', function()
    set_lines({ '', 'a a a ' })
    type_keys('/', 'a', '<CR>')
    set_cursor(1, 0)

    set_width(100)
    eq(section_searchcount({ trunc_width = 100 }), '0/3')
    set_width(99)
    eq(section_searchcount({ trunc_width = 100 }), '')
  end)

  it('respects `args.options`', function()
    set_lines({ '', 'a a a ' })
    type_keys('/', 'a', '<CR>')

    eq(section_searchcount({ options = { recompute = false } }), '1/3')
    set_cursor(2, 5)
    eq(section_searchcount({ options = { recompute = false } }), '1/3')
  end)

  it('does not fail on `searchcount()` error', function()
    -- This matters because it is assumed that `section_searchcount` will be
    -- called on every statusline update, which will happen during typing `/\(`
    -- to search for something like `\(\)`.
    child.fn.setreg('/', [[\(]])
    assert.no_error(function()
      section_searchcount()
    end)
  end)
end)

-- Functional tests ===========================================================
describe('MiniStatusline default `active` content', function()
  child.setup()
  load_module()

  mock_devicons()
  mock_gitsigns()
  mock_diagnostics()
  mock_file(10)

  child.o.columns = 300
  local wins = setup_windows()
  child.cmd('edit ' .. mocked_filepath)

  after_each(unmock_file)

  it('works', function()
    -- Check that option is set correctly
    eq(child.api.nvim_win_get_option(wins.active, 'statusline'), '%!v:lua.MiniStatusline.active()')

    -- Validate
    local validate = function(expected)
      eq(child.lua_get('MiniStatusline.active()'), expected)
    end

    set_width(140)
    validate(
      '%#MiniStatuslineModeNormal# Normal %#MiniStatuslineDevinfo#  main +1 ~2 -3  E4 W3 I2 H1 %<%'
        .. '#MiniStatuslineFilename# %F%m%r %=%#MiniStatuslineFileinfo#  lua utf-8[unix] 10B '
        .. '%#MiniStatuslineModeNormal# %l|%L│%2v|%-2{virtcol("$") - 1} '
    )

    -- After 140 `section_filename` should be truncated
    set_width(120)
    validate(
      '%#MiniStatuslineModeNormal# Normal %#MiniStatuslineDevinfo#  main +1 ~2 -3  E4 W3 I2 H1 %<%'
        .. '#MiniStatuslineFilename# %f%m%r %=%#MiniStatuslineFileinfo#  lua utf-8[unix] 10B '
        .. '%#MiniStatuslineModeNormal# %l|%L│%2v|%-2{virtcol("$") - 1} '
    )

    -- After 120 `section_mode` and `section_fileinfo` should be truncated
    set_width(75)
    validate(
      '%#MiniStatuslineModeNormal# N %#MiniStatuslineDevinfo#  main +1 ~2 -3  E4 W3 I2 H1 %<%'
        .. '#MiniStatuslineFilename# %f%m%r %=%#MiniStatuslineFileinfo#  lua '
        .. '%#MiniStatuslineModeNormal# %l|%L│%2v|%-2{virtcol("$") - 1} '
    )

    -- After 75 all sections should truncated
    set_width(74)
    validate(
      '%#MiniStatuslineModeNormal# N %#MiniStatuslineDevinfo#  main %<%'
        .. '#MiniStatuslineFilename# %f%m%r %=%#MiniStatuslineFileinfo#  lua '
        .. '%#MiniStatuslineModeNormal# %l│%2v '
    )
  end)
end)

describe('MiniStatusline default `inactive` content', function()
  child.setup()
  load_module()
  child.o.columns = 300
  local wins = setup_windows()

  it('works', function()
    -- Check that option is set correctly
    eq(child.api.nvim_win_get_option(wins.inactive, 'statusline'), '%!v:lua.MiniStatusline.inactive()')

    -- Validate
    eq(child.lua_get('MiniStatusline.inactive()'), '%#MiniStatuslineInactive#%F%=')
  end)
end)

child.stop()
