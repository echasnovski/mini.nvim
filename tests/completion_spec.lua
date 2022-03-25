-- NOTE: These are basic tests which cover. A lot of nuances are not tested to
-- meet "complexity-necessity" trade-off
local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('completion', config) end
local unload_module = function() child.mini_unload('completion') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
local mock_lsp = function() child.cmd('luafile tests/helper-mock-months-lsp.lua') end
local new_buffer = function() child.api.nvim_set_current_buf(child.api.nvim_create_buf(true, false)) end
--stylua: ignore end

-- Helpers
--- Attempt at getting data about actually shown completion information
---
--- Main reason why it should exist is because there doesn't seem to be a
--- builtin way to get information about which completion items are actually
--- currently shown. `fn.complete_info()` (main function to get information
--- about completion popup) returns **all** items which were present on popup
--- creation and filtering seems to be done internally without any way to
--- externally get that information.
---
--- NOTE: DOES NOT WORK. Seems to be because information for `complete_info()`
--- is updated in the very last minute (probably, by UI). This means that the
--- idea of "Type <C-n> -> get selected item" loop doesn't work (because
--- "selected item" is not updated). Can't find a way to force its update.
---
--- TODO: Try to make this work. Mainly from possible replies at
--- https://github.com/vim/vim/issues/10007 .
---
---@private
local get_shown_completion_data = function(what)
  what = what or 'word'

  local complete_info = vim.fn.complete_info()
  -- No words is shown if no popup is shown or there is no items
  if complete_info.pum_visible ~= 1 or #complete_info.items == 0 then
    return {}
  end

  local res = {}
  local i, n_items = 0, #complete_info.items
  local selected_init, selected_cur = complete_info.selected, nil
  while i < n_items and selected_cur ~= selected_init do
    i = i + 1
    vim.api.nvim_input('<C-n>')
    complete_info = vim.fn.complete_info()
    selected_cur = complete_info.selected
    if selected_cur >= 0 then
      table.insert(res, complete_info.items[selected_cur + 1][what])
    end
  end

  return res
end

local get_completion = function(what)
  what = what or 'word'
  return vim.tbl_map(function(x)
    return x[what]
  end, child.fn.complete_info().items)
end

local get_floating_windows = function()
  return vim.tbl_filter(function(x)
    return child.api.nvim_win_get_config(x).relative ~= ''
  end, child.api.nvim_list_wins())
end

local win_get_lines = function(win_id, start, finish)
  local buf_id = child.api.nvim_win_get_buf(win_id)
  return child.api.nvim_buf_get_lines(buf_id, start or 0, finish or -1, true)
end

local validate_single_floating_win = function(opts)
  opts = opts or {}
  local wins = get_floating_windows()
  eq(#wins, 1)

  local win_id = wins[1]
  if opts.lines ~= nil then
    eq(win_get_lines(win_id), opts.lines)
  end
  if opts.config ~= nil then
    local true_config = child.api.nvim_win_get_config(win_id)
    local compare_config = {}
    for key, _ in pairs(opts.config) do
      compare_config[key] = true_config[key]
    end
    eq(compare_config, opts.config)
  end
end

-- Data =======================================================================
local test_times = { completion = 100, info = 100, signature = 50 }

-- Unit tests =================================================================
describe('MiniCompletion.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniCompletion ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniCompletion'), 1)

    -- Highlight groups
    assert.truthy(child.cmd_capture('hi MiniCompletionActiveParameter'):find('gui=underline'))
  end)

  it('creates `config` field', function()
    assert.True(child.lua_get([[type(_G.MiniCompletion.config) == 'table']]))

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniCompletion.config.' .. field), value)
    end

    assert_config('delay.completion', 100)
    assert_config('delay.info', 100)
    assert_config('delay.signature', 50)
    assert_config('window_dimensions.info.height', 25)
    assert_config('window_dimensions.info.width', 80)
    assert_config('window_dimensions.signature.height', 25)
    assert_config('window_dimensions.signature.width', 80)
    assert_config('lsp_completion.source_func', 'completefunc')
    assert_config('lsp_completion.auto_setup', true)
    eq(child.lua_get('type(_G.MiniCompletion.config.lsp_completion.process_items)'), 'function')
    eq(child.lua_get('type(_G.MiniCompletion.config.fallback_action)'), 'function')
    assert_config('mappings.force_twostep', '<C-Space>')
    assert_config('mappings.force_fallback', '<A-Space>')
    assert_config('set_vim_settings', true)
  end)

  it('respects `config` argument', function()
    -- Check setting `MiniCompletion.config` fields
    reload_module({ delay = { completion = 300 } })
    eq(child.lua_get('MiniCompletion.config.delay.completion'), 300)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ delay = 'a' }, 'delay', 'table')
    assert_config_error({ delay = { completion = 'a' } }, 'delay.completion', 'number')
    assert_config_error({ delay = { info = 'a' } }, 'delay.info', 'number')
    assert_config_error({ delay = { signature = 'a' } }, 'delay.signature', 'number')
    assert_config_error({ window_dimensions = 'a' }, 'window_dimensions', 'table')
    assert_config_error({ window_dimensions = { info = 'a' } }, 'window_dimensions.info', 'table')
    assert_config_error({ window_dimensions = { info = { height = 'a' } } }, 'window_dimensions.info.height', 'number')
    assert_config_error({ window_dimensions = { info = { width = 'a' } } }, 'window_dimensions.info.width', 'number')
    assert_config_error({ window_dimensions = { signature = 'a' } }, 'window_dimensions.signature', 'table')
    assert_config_error(
      { window_dimensions = { signature = { height = 'a' } } },
      'window_dimensions.signature.height',
      'number'
    )
    assert_config_error(
      { window_dimensions = { signature = { width = 'a' } } },
      'window_dimensions.signature.width',
      'number'
    )
    assert_config_error({ lsp_completion = 'a' }, 'lsp_completion', 'table')
    assert_config_error(
      { lsp_completion = { source_func = 'a' } },
      'lsp_completion.source_func',
      '"completefunc" or "omnifunc"'
    )
    assert_config_error({ lsp_completion = { auto_setup = 'a' } }, 'lsp_completion.auto_setup', 'boolean')
    assert_config_error({ lsp_completion = { process_items = 'a' } }, 'lsp_completion.process_items', 'function')
    assert_config_error({ fallback_action = 1 }, 'fallback_action', 'function or string')
    assert_config_error({ mappings = 'a' }, 'mappings', 'table')
    assert_config_error({ mappings = { force_twostep = 1 } }, 'mappings.force_twostep', 'string')
    assert_config_error({ mappings = { force_fallback = 1 } }, 'mappings.force_fallback', 'string')
    assert_config_error({ set_vim_settings = 1 }, 'set_vim_settings', 'boolean')
  end)

  it('properly handles `config.mappings`', function()
    local has_map = function(lhs)
      return child.cmd_capture('imap ' .. lhs):find('MiniCompletion') ~= nil
    end
    assert.True(has_map('<C-Space>'))

    unload_module()
    child.api.nvim_del_keymap('i', '<C-Space>')

    -- Supplying empty string should mean "don't create keymap"
    load_module({ mappings = { force_twostep = '' } })
    assert.False(has_map('<C-Space>'))
  end)

  it('uses `config.lsp_completion`', function()
    local validate = function(auto_setup, source_func)
      reload_module({ lsp_completion = { auto_setup = auto_setup, source_func = source_func } })
      local buf_id = child.api.nvim_create_buf(true, false)
      child.api.nvim_set_current_buf(buf_id)

      local omnifunc, completefunc
      if auto_setup == false then
        omnifunc, completefunc = '', ''
      else
        local val = 'v:lua.MiniCompletion.completefunc_lsp'
        omnifunc = source_func == 'omnifunc' and val or ''
        completefunc = source_func == 'completefunc' and val or ''
      end

      eq(child.api.nvim_buf_get_option(0, 'omnifunc'), omnifunc)
      eq(child.api.nvim_buf_get_option(0, 'completefunc'), completefunc)
    end

    validate(false)
    validate(true, 'omnifunc')
    validate(true, 'completefunc')
  end)

  it('uses `config.set_vim_settings`', function()
    reload_module({ set_vim_settings = true })
    assert.truthy(child.api.nvim_get_option('shortmess'):find('c'))
    eq(child.api.nvim_get_option('completeopt'), 'menuone,noinsert,noselect')
  end)
end)

-- Functional tests ===========================================================
describe('Autocompletion', function()
  before_each(function()
    child.setup()
    load_module()
    -- Create new buffer to set buffer-local `completefunc` or `omnifunc`
    new_buffer()
    -- For details see mocking of 'textDocument/completion' request
    mock_lsp()
  end)

  it('works with LSP client', function()
    type_keys({ 'i', 'J' })
    eq(get_completion(), {})

    -- Shows completion only after delay
    sleep(test_times.completion - 10)
    eq(get_completion(), {})
    sleep(10)
    -- Both completion word and kind are shown
    eq(get_completion(), { 'January', 'June', 'July' })
    eq(get_completion('kind'), { 'Text', 'Function', 'Function' })

    -- -- Completion menu is filtered after entering characters
    -- -- NOTE: this is currently not tested because couldn't find a way to get
    -- -- actually shown items (see annotation of `get_shown_completion_data()`).
    -- type_keys({ 'u' })
    -- eq(get_completion(), { 'June', 'July' })
  end)

  it('works without LSP clients', function()
    -- Mock absence of LSP
    child.lua([[vim.lsp.buf_get_clients = function() return {} end]])

    type_keys('i')
    type_keys(vim.split('aa ab a', ''))
    eq(get_completion(), {})
    sleep(test_times.completion - 10)
    eq(get_completion(), {})
    sleep(10)
    eq(get_completion(), { 'aa', 'ab' })
  end)

  it('implements debounce-style delay', function()
    type_keys({ 'i', 'J' })

    sleep(test_times.completion - 10)
    eq(get_completion(), {})
    type_keys('u')
    sleep(test_times.completion - 10)
    eq(get_completion(), {})
    sleep(10)
    eq(get_completion(), { 'June', 'July' })
  end)

  it('uses fallback', function()
    set_lines({ 'Jackpot', '' })
    set_cursor(2, 0)

    type_keys({ 'i', 'J', 'a' })
    sleep(test_times.completion + 1)
    eq(get_completion(), { 'January' })

    -- Due to how 'completefunc' and 'omnifunc' currently work, fallback won't
    -- trigger after the first character which lead to empty completion list.
    -- The reason seems to be that at that point Neovim's internal filtering of
    -- completion items is still "in charge" (backspace leads to previous
    -- completion item list without reevaluating completion function). It is
    -- only after the next character completion function gets reevaluated
    -- leading to zero items from LSP which triggers fallback action.
    type_keys({ 'c' })
    eq(child.fn.pumvisible(), 0)
    type_keys({ 'k' })
    eq(get_completion(), { 'Jackpot' })
  end)

  it('respects `config.delay.completion`', function()
    reload_module({ delay = { completion = 300 } })

    type_keys({ 'i', 'J' })
    sleep(300 - 10)
    sleep(10)
    eq(get_completion(), { 'January', 'June', 'July' })
  end)

  it('respects `config.lsp_completion.process_items`', function()
    child.lua([[
      _G.process_items = function(items, base)
        -- Don't show 'Text' kind
        items = vim.tbl_filter(function(x) return x.kind ~= 1 end, items)
        return MiniCompletion.default_process_items(items, base)
      end
    ]])
    unload_module()
    child.lua([[require('mini.completion').setup({ lsp_completion = { process_items = _G.process_items } })]])

    type_keys({ 'i', 'J' })
    sleep(test_times.completion + 1)
    eq(get_completion(), { 'June', 'July' })
  end)

  it('respects string `config.fallback_action`', function()
    reload_module({ fallback_action = '<C-x><C-l>' })
    set_lines({ 'Line number 1', '' })
    set_cursor(2, 0)
    type_keys({ 'i', 'L' })
    sleep(test_times.completion + 1)
    eq(get_completion(), { 'Line number 1' })
  end)

  it('respects function `config.fallback_action`', function()
    unload_module()
    child.lua([[require('mini.completion').setup({ fallback_action = function() _G.inside_fallback = true end })]])
    type_keys({ 'i', 'a' })
    sleep(test_times.completion + 1)
    eq(child.lua_get('_G.inside_fallback'), true)
  end)

  it('respects vim.{g,b}.minicompletion_disable', function()
    local validate_disable = function(var_type)
      child.lua(('vim.%s.minicompletion_disable = true'):format(var_type))
      type_keys({ 'i', 'J' })
      sleep(test_times.completion + 1)
      eq(get_completion(), {})

      child.lua(('vim.%s.minicompletion_disable = nil'):format(var_type))
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

describe('Manual completion', function()
  before_each(function()
    child.setup()
    -- Virtually disable auto-completion
    load_module({ delay = { completion = 100000 } })
    -- Create new buffer to set buffer-local `completefunc` or `omnifunc`
    new_buffer()
    -- For details see mocking of 'textDocument/completion' request
    mock_lsp()

    set_lines({ 'Jackpot', '' })
    set_cursor(2, 0)
  end)

  it('works with two-step completion', function()
    type_keys({ 'i', 'J', '<C-Space>' })
    eq(get_completion(), { 'January', 'June', 'July' })

    type_keys({ 'a', 'c' })
    eq(child.fn.pumvisible(), 0)

    type_keys('<C-Space>')
    eq(get_completion(), { 'Jackpot' })
  end)

  it('works with fallback action', function()
    type_keys({ 'i', 'J', '<M-Space>' })
    eq(get_completion(), { 'Jackpot' })
  end)

  it('respects `config.mappings', function()
    reload_module({ mappings = { force_twostep = '<C-z>', force_fallback = '<C-x>' } })
    type_keys({ 'i', 'J', '<C-z>' })
    eq(get_completion(), { 'January', 'June', 'July' })
    type_keys('<C-x>')
    eq(get_completion(), { 'Jackpot' })
  end)

  it('respects vim.{g,b}.minicompletion_disable', function()
    local validate_disable = function(var_type)
      child.lua(('vim.%s.minicompletion_disable = true'):format(var_type))
      type_keys({ 'i', '<C-Space>' })
      poke_eventloop()
      eq(get_completion(), {})

      type_keys({ 'i', '<M-Space>' })
      poke_eventloop()
      eq(get_completion(), {})

      child.lua(('vim.%s.minicompletion_disable = nil'):format(var_type))
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

describe('Information window', function()
  before_each(function()
    child.setup()
    load_module()
    -- Create new buffer to set buffer-local `completefunc` or `omnifunc`
    new_buffer()
    -- For details see mocking of 'completionItem/resolve' request
    mock_lsp()
  end)

  local validate_info_win = function(delay)
    type_keys({ 'i', 'J', '<C-Space>' })
    eq(get_completion(), { 'January', 'June', 'July' })

    type_keys('<C-n>')
    eq(get_floating_windows(), {})
    sleep(delay - 10)
    eq(get_floating_windows(), {})
    sleep(10 + 1)
    validate_single_floating_win({ lines = { 'Month #01' } })
  end

  it('works', function()
    validate_info_win(test_times.info)
  end)

  it('respects `config.delay.info`', function()
    reload_module({ delay = { info = 300 } })
    validate_info_win(300)
  end)

  local validate_dimensions = function(keys, completion_items, dimensions)
    reload_module({ window_dimensions = { info = { height = 20, width = 40 } } })
    type_keys('i')
    type_keys(keys)
    type_keys('<C-Space>')
    eq(get_completion(), completion_items)

    type_keys('<C-n>')
    -- Some windows can take a while to process on slow machines. So add `10`
    -- to ensure that processing is finished.
    sleep(test_times.info + 10)
    validate_single_floating_win({ config = dimensions })
  end

  it('respects `config.window_dimensions.info`', function()
    validate_dimensions('D', { 'December' }, { height = 20, width = 40 })
  end)

  it('has minimal dimensions for small text', function()
    validate_dimensions('J', { 'January', 'June', 'July' }, { height = 1, width = 9 })
  end)

  it('implements debounce-style delay', function()
    type_keys({ 'i', 'J', '<C-Space>' })
    eq(get_completion(), { 'January', 'June', 'July' })

    type_keys('<C-n>')
    sleep(test_times.info - 10)
    eq(#get_floating_windows(), 0)
    type_keys('<C-n>')
    sleep(test_times.info - 10)
    eq(#get_floating_windows(), 0)
    sleep(10 + 1)
    validate_single_floating_win({ lines = { 'Month #06' } })
  end)

  it('respects vim.{g,b}.minicompletion_disable', function()
    local validate_disable = function(var_type)
      child.lua(('vim.%s.minicompletion_disable = true'):format(var_type))

      set_lines({ 'aa ab ', '' })
      set_cursor(2, 0)
      type_keys({ 'i', '<C-n>' })
      type_keys('<C-n>')
      sleep(test_times.info + 1)
      eq(#get_floating_windows(), 0)

      child.lua(('vim.%s.minicompletion_disable = nil'):format(var_type))
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

describe('Signature help', function()
  before_each(function()
    child.setup()
    load_module()
    -- See mocking of 'textDocument/signatureHelp' request
    mock_lsp()
  end)

  local validate_signature_win = function(delay)
    type_keys({ 'i', 'a', 'b', 'c', '(' })

    eq(get_floating_windows(), {})
    sleep(delay - 10)
    eq(get_floating_windows(), {})
    sleep(10 + 1)
    validate_single_floating_win({ lines = { 'abc(param1, param2)' } })
  end

  it('works', function()
    validate_signature_win(test_times.signature)
  end)

  it('respects `config.delay.signature`', function()
    reload_module({ delay = { signature = 300 } })
    validate_signature_win(300)
  end)

  it('updates highlighting of active parameter', function()
    -- Mock `vim.api.nvim_buf_add_highlight()`
    -- Elements of `_G.buf_highlighting_calls` should be tables with values:
    -- {buffer}, {ns_id}, {hl_group}, {line}, {col_start}, {col_end}
    child.lua([[
      _G.buf_highlighting_calls = {}
      vim.api.nvim_buf_add_highlight = function(...)
        table.insert(_G.buf_highlighting_calls, {...})
      end
    ]])
    local calls

    type_keys({ 'a', 'b', 'c', '(' })
    sleep(test_times.signature + 1)
    calls = child.lua_get('_G.buf_highlighting_calls')
    eq(#calls, 1)
    eq({ calls[1][3], calls[1][5], calls[1][6] }, { 'MiniCompletionActiveParameter', 4, 10 })

    type_keys({ '1', ',' })
    sleep(test_times.signature + 1)
    calls = child.lua_get('_G.buf_highlighting_calls')
    eq(#calls, 2)
    eq({ calls[2][3], calls[2][5], calls[2][6] }, { 'MiniCompletionActiveParameter', 12, 18 })

    -- As there are only two parameters, nothing should be highlighted
    type_keys({ '2', ',' })
    sleep(test_times.signature + 1)
    calls = child.lua_get('_G.buf_highlighting_calls')
    eq(#calls, 2)
  end)

  local validate_dimensions = function(keys, dimensions)
    reload_module({ window_dimensions = { signature = { height = 20, width = 40 } } })
    type_keys('i')
    type_keys(keys)
    sleep(test_times.signature + 2)
    validate_single_floating_win({ config = dimensions })
  end

  it('respects `config.window_dimensions.signature`', function()
    validate_dimensions({ 'l', 'o', 'n', 'g', '(' }, { height = 20, width = 40 })
  end)

  it('has minimal dimensions for small text', function()
    validate_dimensions({ 'a', 'b', 'c', '(' }, { height = 1, width = 19 })
  end)

  it('implements debounce-style delay', function()
    type_keys({ 'i', 'a', 'b', 'c', '(' })
    sleep(test_times.signature - 10)
    type_keys('d')
    sleep(test_times.signature + 1)
    eq(#get_floating_windows(), 0)

    type_keys(',')
    sleep(test_times.signature + 1)
    validate_single_floating_win({ lines = { 'abc(param1, param2)' } })
  end)

  it('respects vim.{g,b}.minicompletion_disable', function()
    local validate_disable = function(var_type)
      child.lua(('vim.%s.minicompletion_disable = true'):format(var_type))

      type_keys({ 'i', 'a', 'b', 'c', '(' })
      sleep(test_times.signature + 1)
      eq(#get_floating_windows(), 0)

      child.lua(('vim.%s.minicompletion_disable = nil'):format(var_type))
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

child.stop()
