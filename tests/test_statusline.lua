local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

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
  if #child.api.nvim_list_wins() > 1 then child.cmd('only') end
  child.cmd('vsplit')

  local win_list = child.api.nvim_list_wins()
  if win_list[1] == child.api.nvim_get_current_win() then return { active = win_list[1], inactive = win_list[2] } end
  return { active = win_list[2], inactive = win_list[1] }
end

local get_two_windows = function()
  local wins_tabpage = child.api.nvim_tabpage_list_wins(0)
  local cur_win = child.api.nvim_get_current_win()
  return { active = cur_win, inactive = cur_win == wins_tabpage[1] and wins_tabpage[2] or wins_tabpage[1] }
end

-- Mocks
local mock_devicons = function() child.cmd('set rtp+=tests/dir-statusline') end

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

local mock_diagnostics = function() child.cmd('luafile tests/dir-statusline/mock-diagnostics.lua') end

local mocked_filepath = vim.fn.fnamemodify('tests/dir-statusline/mocked.lua', ':p')
local mock_file = function(bytes)
  -- Reduce one byte for '\n' at end
  local lines = { string.rep('a', bytes - 1) }

  vim.fn.writefile(lines, mocked_filepath)
end

local unmock_file = function() pcall(vim.fn.delete, mocked_filepath) end

-- Output test set ============================================================
local T = new_set({
  hooks = {
    pre_case = function()
      child.setup()
      load_module()

      -- Ensure wide enough window
      child.o.columns = 300
      setup_windows()
    end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  -- Global variable
  eq(child.lua_get('type(_G.MiniStatusline)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniStatusline'), 1)

  -- Highlight groups
  child.cmd('hi clear')
  load_module()
  local has_highlight = function(group, value) expect.match(child.cmd_capture('hi ' .. group), value) end

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
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniStatusline.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniStatusline.config.' .. field), value) end

  expect_config('content.active', vim.NIL)
  expect_config('content.inactive', vim.NIL)
  expect_config('set_vim_settings', true)
end

T['setup()']['respects `config` argument'] = function()
  reload_module({ set_vim_settings = false })
  eq(child.lua_get('MiniStatusline.config.set_vim_settings'), false)
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ content = 'a' }, 'content', 'table')
  expect_config_error({ content = { active = 'a' } }, 'content.active', 'function')
  expect_config_error({ content = { inactive = 'a' } }, 'content.inactive', 'function')
  expect_config_error({ set_vim_settings = 'a' }, 'set_vim_settings', 'boolean')
  expect_config_error({ use_icons = 'a' }, 'use_icons', 'boolean')
end

T['setup()']['sets proper autocommands'] = function()
  local validate = function(win_id, field)
    eq(child.api.nvim_win_get_option(win_id, 'statusline'), '%!v:lua.MiniStatusline.' .. field .. '()')
  end

  local wins = get_two_windows()

  validate(wins.active, 'active')
  validate(wins.inactive, 'inactive')

  child.api.nvim_set_current_win(wins.inactive)
  validate(wins.active, 'inactive')
  validate(wins.inactive, 'active')
end

T['setup()']['respects `config.set_vim_settings`'] = function()
  reload_module({ set_vim_settings = true })
  eq(child.o.laststatus, 2)
end

T['setup()']['disables built-in statusline in quickfix window'] = function()
  child.cmd('copen')
  expect.match(child.o.statusline, 'MiniStatusline')
end

T['combine_groups()'] = new_set()

local combine_groups = function(...) return child.lua_get('MiniStatusline.combine_groups(...)', { ... }) end

local example_groups = {
  { hl = 'AA', strings = { 'a1', 'a2' } },
  { hl = 'BB', strings = { 'b1', '', 'b2' } },
  '%=',
  { hl = 'CC', strings = { 'c1' } },
}

T['combine_groups()']['works'] = function() eq(combine_groups(example_groups), '%#AA# a1 a2 %#BB# b1 b2 %=%#CC# c1 ') end

T['combine_groups()']['handles non-table elements'] = function()
  -- Strings should be used as is, other non-table elements - filtered out
  eq(combine_groups({ 1, 'xxx', example_groups[1] }), 'xxx%#AA# a1 a2 ')
  eq(combine_groups({ example_groups[1], 'xxx' }), '%#AA# a1 a2 xxx')
  eq(combine_groups({ 'xxx', 'yyy' }), 'xxxyyy')
end

T['combine_groups()']['uses only non-empty strings from `strings` field'] = function()
  eq(combine_groups({ { hl = 'AA', strings = { 'a', 1, {}, true, '', 'b' } } }), '%#AA# a b ')
end

T['combine_groups()']['allows empty `hl` to use previous highlight group'] = function()
  eq(combine_groups({ { strings = { 'a' } }, { hl = 'BB', strings = { 'b' } } }), ' a %#BB# b ')
  eq(combine_groups({ { hl = 'BB', strings = { 'b' } }, { strings = { 'a' } } }), '%#BB# b  a ')
end

T['combine_groups()']['allows empty `strings` to start new highlight'] = function()
  eq(combine_groups({ { hl = 'AA' }, { strings = { 'b1', 'b2' } } }), '%#AA# b1 b2 ')
  eq(combine_groups({ { hl = 'AA' }, { hl = 'BB', strings = { 'b1', 'b2' } } }), '%#AA#%#BB# b1 b2 ')
  eq(combine_groups({ { strings = { 'a1', 'a2' } }, { hl = 'BB' }, { strings = { 'c1' } } }), ' a1 a2 %#BB# c1 ')
end

local is_truncated = function(...) return child.lua_get('MiniStatusline.is_truncated(...)', { ... }) end

T['is_truncated()'] = new_set()

T['is_truncated()']['works'] = function()
  child.cmd('wincmd v')
  set_width(50)

  -- Should return `false` ("not trauncated") by default
  eq(is_truncated(), false)

  eq(is_truncated(49), false)
  eq(is_truncated(50), false)
  eq(is_truncated(51), true)
end

T['is_truncated()']['respects global statusline'] = function()
  child.o.laststatus = 3
  child.o.columns = 60
  child.cmd('wincmd v')
  set_width(50)

  eq(is_truncated(51), false)
  eq(is_truncated(59), false)
  eq(is_truncated(60), false)
  eq(is_truncated(61), true)
end

local eval_content = function(field) return child.lua_get(('MiniStatusline.%s()'):format(field)) end

T['active()/inactive()'] = new_set({
  parametrize = { { 'active' }, { 'inactive' } },
})

T['active()/inactive()']['respects `config.content`'] = function(field)
  unload_module()
  local command =
    string.format([[require('mini.statusline').setup({ content = { %s = function() return 'aaa' end } })]], field)
  child.lua(command)
  eq(eval_content(field), 'aaa')

  command = string.format([[vim.b.ministatusline_config = { content = { %s = function() return 'bbb' end } }]], field)
  child.lua(command)
  eq(eval_content(field), 'bbb')
end

T['active()/inactive()']['respects `vim.{g,b}.ministatusline_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(field, var_type)
    child[var_type].ministatusline_disable = true
    eq(eval_content(field), '')
  end,
})

-- Sections -------------------------------------------------------------------
T['section_diagnostics()'] = new_set({ hooks = { pre_case = mock_diagnostics } })

T['section_diagnostics()']['works'] = function()
  eq(child.lua_get('MiniStatusline.section_diagnostics({})'), ' E4 W3 I2 H1')

  -- Should return predefined string if no diagnostic output
  child.lua('vim.diagnostic.get = function(...) return {} end')
  child.lua('vim.diagnostic.count = function(...) return {} end')
  child.lua('vim.diagnostic.get = function(...) return {} end')
  eq(child.lua_get('MiniStatusline.section_diagnostics({})'), ' -')

  -- Should return empty string if no LSP client attached
  child.lua('vim.lsp.buf_get_clients = function() return {} end')
  if child.fn.has('nvim-0.8') == 1 then child.lua('_G.detach_lsp()') end
  eq(child.lua_get('MiniStatusline.section_diagnostics({})'), '')
end

T['section_diagnostics()']['respects `args.trunc_width`'] = function()
  set_width(100)
  eq(child.lua_get('MiniStatusline.section_diagnostics({ trunc_width = 100 })'), ' E4 W3 I2 H1')
  set_width(99)
  eq(child.lua_get('MiniStatusline.section_diagnostics({ trunc_width = 100 })'), '')
end

T['section_diagnostics()']['respects `args.icon`'] = function()
  eq(child.lua_get([[MiniStatusline.section_diagnostics({icon = 'A'})]]), 'A E4 W3 I2 H1')
  eq(child.lua_get([[MiniStatusline.section_diagnostics({icon = 'AAA'})]]), 'AAA E4 W3 I2 H1')
end

T['section_diagnostics()']['respects `config.use_icons`'] = function()
  child.lua('MiniStatusline.config.use_icons = false')
  eq(child.lua_get([[MiniStatusline.section_diagnostics({})]]), 'LSP E4 W3 I2 H1')

  -- Should also use buffer local config
  child.b.ministatusline_config = { use_icons = true }
  eq(child.lua_get([[MiniStatusline.section_diagnostics({})]]), ' E4 W3 I2 H1')
end

T['section_diagnostics()']['is shown only in normal buffers'] = function()
  child.cmd('help')
  eq(child.lua_get('MiniStatusline.section_diagnostics({})'), '')
end

T['section_fileinfo()'] = new_set({ hooks = { pre_case = mock_devicons, post_case = unmock_file } })

local validate_fileinfo = function(args, pattern)
  local command = ('MiniStatusline.section_fileinfo({ %s })'):format(args)
  expect.match(child.lua_get(command), pattern)
end

T['section_fileinfo()']['works'] = function()
  mock_file(10)
  child.cmd('edit ' .. mocked_filepath)
  local encoding = child.bo.fileencoding or child.bo.encoding
  local format = child.bo.fileformat
  local pattern = '^ lua ' .. vim.pesc(encoding) .. '%[' .. vim.pesc(format) .. '%] 10B$'
  validate_fileinfo('', pattern)
end

T['section_fileinfo()']['respects `args.trunc_width`'] = function()
  mock_file(10)
  child.cmd('edit ' .. mocked_filepath)

  set_width(100)
  validate_fileinfo('trunc_width = 100', '^ lua...')
  set_width(99)
  validate_fileinfo('trunc_width = 100', '^ lua$')
end

T['section_fileinfo()']['respects `config.use_icons`'] = function()
  mock_file(10)
  child.cmd('edit ' .. mocked_filepath)

  child.lua('MiniStatusline.config.use_icons = false')
  validate_fileinfo('', '^lua...')

  -- Should also use buffer local config
  child.b.ministatusline_config = { use_icons = true }
  validate_fileinfo('', ' lua...')
end

T['section_fileinfo()']["correctly asks 'nvim-web-devicons' for icon"] = function()
  child.cmd('e tmp.txt')
  eq(child.lua_get('_G.devicons_args'), { filename = 'tmp.txt', extension = 'txt', options = { default = true } })
end

T['section_fileinfo()']['uses correct filetype'] = function()
  child.bo.filetype = 'aaa'
  validate_fileinfo('', ' aaa ')
end

T['section_fileinfo()']['uses human friendly size'] = function()
  mock_file(1024)
  child.cmd('edit ' .. mocked_filepath)
  validate_fileinfo('', '1%.00KiB$')
  unmock_file()

  mock_file(1024 * 1024)
  child.cmd('edit ' .. mocked_filepath)
  validate_fileinfo('', '1%.00MiB$')
  unmock_file()
end

T['section_fileinfo()']['is shown only in normal buffers with filetypes'] = function()
  child.bo.filetype = ''
  validate_fileinfo('', '^$')

  child.cmd('help')
  validate_fileinfo('', '^$')
end

T['section_filename()'] = new_set()

T['section_filename()']['works'] = function()
  local name = vim.fn.tempname()
  child.cmd('edit ' .. name)
  eq(child.lua_get('MiniStatusline.section_filename({})'), '%F%m%r')

  -- Should work in terminal
  child.cmd('terminal')
  eq(child.lua_get('MiniStatusline.section_filename({})'), '%t')
end

T['section_filename()']['respects `args.trunc_width`'] = function()
  local name = vim.fn.tempname()
  child.cmd('edit ' .. name)

  set_width(100)
  eq(child.lua_get('MiniStatusline.section_filename({ trunc_width = 100 })'), '%F%m%r')
  set_width(99)
  eq(child.lua_get('MiniStatusline.section_filename({ trunc_width = 100 })'), '%f%m%r')
end

T['section_git()'] = new_set({ hooks = { pre_case = mock_gitsigns } })

T['section_git()']['works'] = function()
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
end

T['section_git()']['respects `args.trunc_width`'] = function()
  set_width(100)
  eq(child.lua_get('MiniStatusline.section_git({ trunc_width = 100 })'), ' main +1 ~2 -3')
  set_width(99)
  eq(child.lua_get('MiniStatusline.section_git({ trunc_width = 100 })'), ' main')
end

T['section_git()']['respects `args.icon`'] = function()
  eq(child.lua_get([[MiniStatusline.section_git({icon = 'A'})]]), 'A main +1 ~2 -3')
  eq(child.lua_get([[MiniStatusline.section_git({icon = 'AAA'})]]), 'AAA main +1 ~2 -3')
end

T['section_git()']['respects `config.use_icons`'] = function()
  child.lua('MiniStatusline.config.use_icons = false')
  eq(child.lua_get([[MiniStatusline.section_git({})]]), 'Git main +1 ~2 -3')

  -- Should also use buffer local config
  child.b.ministatusline_config = { use_icons = true }
  eq(child.lua_get([[MiniStatusline.section_git({})]]), ' main +1 ~2 -3')
end

T['section_git()']['is shown only in normal buffers'] = function()
  child.cmd('help')
  eq(child.lua_get('MiniStatusline.section_git({})'), '')
end

T['section_location()'] = new_set()

T['section_location()']['works'] = function()
  eq(child.lua_get('MiniStatusline.section_location({})'), '%l|%L│%2v|%-2{virtcol("$") - 1}')
end

T['section_location()']['respects `args.trunc_width`'] = function()
  set_width(100)
  eq(child.lua_get('MiniStatusline.section_location({ trunc_width = 100 })'), '%l|%L│%2v|%-2{virtcol("$") - 1}')
  set_width(99)
  eq(child.lua_get('MiniStatusline.section_location({ trunc_width = 100 })'), '%l│%2v')
end

T['section_mode()'] = new_set()

local section_mode = function(args) return child.lua_get('{ MiniStatusline.section_mode(...) }', { args or {} }) end

T['section_mode()']['works'] = function() eq(section_mode(), { 'Normal', 'MiniStatuslineModeNormal' }) end

T['section_mode()']['shows correct mode'] = function()
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
end

T['section_mode()']['respects `args.trunc_width`'] = function()
  set_width(100)
  eq(section_mode({ trunc_width = 100 }), { 'Normal', 'MiniStatuslineModeNormal' })
  set_width(99)
  eq(section_mode({ trunc_width = 100 }), { 'N', 'MiniStatuslineModeNormal' })
end

T['section_searchcount()'] = new_set({
  hooks = {
    pre_case = function()
      mock_file(10)
      child.cmd('edit! ' .. mocked_filepath)
    end,
    post_case = unmock_file,
  },
})

local section_searchcount = function(args)
  return child.lua_get('MiniStatusline.section_searchcount(...)', { args or {} })
end

T['section_searchcount()']['works'] = function()
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
end

T['section_searchcount()']['works with many search matches'] = function()
  set_lines({ string.rep('a ', 101) })
  type_keys('/', 'a', '<CR>')
  set_cursor(1, 0)
  eq(section_searchcount(), '1/>99')

  set_cursor(1, 197)
  eq(section_searchcount(), '99/>99')

  set_cursor(1, 198)
  eq(section_searchcount(), '>99/>99')
end

T['section_searchcount()']['respects `args.trunc_width`'] = function()
  set_lines({ '', 'a a a ' })
  type_keys('/', 'a', '<CR>')
  set_cursor(1, 0)

  set_width(100)
  eq(section_searchcount({ trunc_width = 100 }), '0/3')
  set_width(99)
  eq(section_searchcount({ trunc_width = 100 }), '')
end

T['section_searchcount()']['respects `args.options`'] = function()
  -- Disable recomputation from section in default content
  child.lua([[MiniStatusline.config.content.active = function() return '%f' end]])
  set_lines({ '', 'a a a ' })
  type_keys('/', 'a', '<CR>')

  eq(section_searchcount({ options = { recompute = false } }), '1/3')
  set_cursor(2, 5)
  eq(section_searchcount({ options = { recompute = false } }), '1/3')
end

T['section_searchcount()']['does not fail on `searchcount()` error'] = function()
  -- This matters because it is assumed that `section_searchcount` will be
  -- called on every statusline update, which will happen during typing `/\(`
  -- to search for something like `\(\)`.
  child.fn.setreg('/', [[\(]])
  expect.no_error(section_searchcount)
end

-- Integration tests ==========================================================
T['Default content'] = new_set()

T['Default content']['active'] = new_set({
  hooks = {
    pre_case = function()
      child.set_size(5, 150)

      mock_devicons()
      mock_gitsigns()
      mock_file(10)

      -- Mock filename section to use relative path for consistent screenshots
      child.lua([[MiniStatusline.section_filename = function() return '%f%m%r' end]])
      child.cmd('edit ' .. vim.fn.fnamemodify(mocked_filepath, ':.'))
      mock_diagnostics()
      type_keys('/a', '<CR>')
    end,
    post_case = unmock_file,
  },
  -- There should also be test for 140, but it is for truncating in
  -- `section_filename` from full to relative paths
  parametrize = { { 120 }, { 75 }, { 74 } },
}, {
  test = function(window_width)
    eq(child.api.nvim_win_get_option(0, 'statusline'), '%!v:lua.MiniStatusline.active()')
    set_width(window_width)
    child.expect_screenshot()
  end,
})

T['Default content']['inactive'] = function()
  local wins = get_two_windows()

  -- Check that option is set correctly
  eq(child.api.nvim_win_get_option(wins.inactive, 'statusline'), '%!v:lua.MiniStatusline.inactive()')

  -- Validate
  eq(child.lua_get('MiniStatusline.inactive()'), '%#MiniStatuslineInactive#%F%=')
end

return T
