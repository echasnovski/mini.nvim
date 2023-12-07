-- NOTE: These are basic tests which cover basic functionliaty. A lot of
-- nuances are not tested to meet "complexity-necessity" trade-off.
local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('completion', config) end
local unload_module = function() child.mini_unload('completion') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
local mock_lsp = function() child.cmd('luafile tests/dir-completion/mock-months-lsp.lua') end
local new_buffer = function() child.api.nvim_set_current_buf(child.api.nvim_create_buf(true, false)) end
--stylua: ignore end

-- NOTE: this can't show "what filtered text is actually shown in window".
-- Seems to be because information for `complete_info()`
--- is updated in the very last minute (probably, by UI). This means that the
--- idea of "Type <C-n> -> get selected item" loop doesn't work (because
--- "selected item" is not updated). Can't find a way to force its update.
---
--- Using screen tests to get information about actually shown filtered items.
---
--- More info: https://github.com/vim/vim/issues/10007
local get_completion = function(what)
  what = what or 'word'
  return vim.tbl_map(function(x) return x[what] end, child.fn.complete_info().items)
end

local get_floating_windows = function()
  return vim.tbl_filter(
    function(x) return child.api.nvim_win_get_config(x).relative ~= '' end,
    child.api.nvim_list_wins()
  )
end

local validate_single_floating_win = function(opts)
  opts = opts or {}
  local wins = get_floating_windows()
  eq(#wins, 1)

  local win_id = wins[1]
  if opts.lines ~= nil then
    local buf_id = child.api.nvim_win_get_buf(win_id)
    local lines = child.api.nvim_buf_get_lines(buf_id, 0, -1, true)
    eq(lines, opts.lines)
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
  eq(child.lua_get('type(_G.MiniCompletion)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniCompletion'), 1)

  -- Highlight groups
  child.cmd('hi clear')
  load_module()
  expect.match(child.cmd_capture('hi MiniCompletionActiveParameter'), 'gui=underline')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniCompletion.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniCompletion.config.' .. field), value) end

  expect_config('delay.completion', 100)
  expect_config('delay.info', 100)
  expect_config('delay.signature', 50)
  expect_config('window.info.height', 25)
  expect_config('window.info.width', 80)
  expect_config('window.info.border', 'none')
  expect_config('window.signature.height', 25)
  expect_config('window.signature.width', 80)
  expect_config('window.signature.border', 'none')
  expect_config('lsp_completion.source_func', 'completefunc')
  expect_config('lsp_completion.auto_setup', true)
  eq(child.lua_get('type(_G.MiniCompletion.config.lsp_completion.process_items)'), 'function')
  eq(child.lua_get('type(_G.MiniCompletion.config.fallback_action)'), 'function')
  expect_config('mappings.force_twostep', '<C-Space>')
  expect_config('mappings.force_fallback', '<A-Space>')
  expect_config('set_vim_settings', true)
end

T['setup()']['respects `config` argument'] = function()
  -- Check setting `MiniCompletion.config` fields
  reload_module({ delay = { completion = 300 } })
  eq(child.lua_get('MiniCompletion.config.delay.completion'), 300)
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ delay = 'a' }, 'delay', 'table')
  expect_config_error({ delay = { completion = 'a' } }, 'delay.completion', 'number')
  expect_config_error({ delay = { info = 'a' } }, 'delay.info', 'number')
  expect_config_error({ delay = { signature = 'a' } }, 'delay.signature', 'number')
  expect_config_error({ window = 'a' }, 'window', 'table')
  expect_config_error({ window = { info = 'a' } }, 'window.info', 'table')
  expect_config_error({ window = { info = { height = 'a' } } }, 'window.info.height', 'number')
  expect_config_error({ window = { info = { width = 'a' } } }, 'window.info.width', 'number')
  expect_config_error({ window = { info = { border = 1 } } }, 'window.info.border', 'string or array')
  expect_config_error({ window = { signature = 'a' } }, 'window.signature', 'table')
  expect_config_error({ window = { signature = { height = 'a' } } }, 'window.signature.height', 'number')
  expect_config_error({ window = { signature = { width = 'a' } } }, 'window.signature.width', 'number')
  expect_config_error({ window = { signature = { border = 1 } } }, 'window.signature.border', 'string or array')
  expect_config_error({ lsp_completion = 'a' }, 'lsp_completion', 'table')
  expect_config_error(
    { lsp_completion = { source_func = 'a' } },
    'lsp_completion.source_func',
    '"completefunc" or "omnifunc"'
  )
  expect_config_error({ lsp_completion = { auto_setup = 'a' } }, 'lsp_completion.auto_setup', 'boolean')
  expect_config_error({ lsp_completion = { process_items = 'a' } }, 'lsp_completion.process_items', 'function')
  expect_config_error({ fallback_action = 1 }, 'fallback_action', 'function or string')
  expect_config_error({ mappings = 'a' }, 'mappings', 'table')
  expect_config_error({ mappings = { force_twostep = 1 } }, 'mappings.force_twostep', 'string')
  expect_config_error({ mappings = { force_fallback = 1 } }, 'mappings.force_fallback', 'string')
  expect_config_error({ set_vim_settings = 1 }, 'set_vim_settings', 'boolean')
end

T['setup()']['properly handles `config.mappings`'] = function()
  local has_map = function(lhs, pattern) return child.cmd_capture('imap ' .. lhs):find(pattern) ~= nil end
  eq(has_map('<C-Space>', 'Complete'), true)

  unload_module()
  child.api.nvim_del_keymap('i', '<C-Space>')

  -- Supplying empty string should mean "don't create keymap"
  load_module({ mappings = { force_twostep = '' } })
  eq(has_map('<C-Space>', 'Complete'), false)
end

T['setup()']['uses `config.lsp_completion`'] = function()
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
end

T['setup()']['respects `config.set_vim_settings`'] = function()
  reload_module({ set_vim_settings = true })
  expect.match(child.api.nvim_get_option('shortmess'), 'c')
  if child.fn.has('nvim-0.9') == 1 then expect.match(child.api.nvim_get_option('shortmess'), 'C') end
  eq(child.api.nvim_get_option('completeopt'), 'menuone,noinsert,noselect')
end

T['setup()']['defines non-linked default highlighting on `ColorScheme`'] = function()
  child.cmd('colorscheme blue')
  expect.match(child.cmd_capture('hi MiniCompletionActiveParameter'), 'gui=underline')
end

-- Integration tests ==========================================================
T['Autocompletion'] = new_set({
  hooks = {
    pre_case = function()
      -- Create new buffer to set buffer-local `completefunc` or `omnifunc`
      new_buffer()
      -- For details see mocking of 'textDocument/completion' request
      mock_lsp()
    end,
  },
})

T['Autocompletion']['works with LSP client'] = function()
  type_keys('i', 'J')
  eq(get_completion(), {})

  -- Shows completion only after delay
  sleep(test_times.completion - 10)
  eq(get_completion(), {})
  sleep(10)
  -- Both completion word and kind are shown
  eq(get_completion(), { 'January', 'June', 'July' })
  eq(get_completion('kind'), { 'Text', 'Function', 'Function' })

  -- Completion menu is filtered after entering characters
  type_keys('u')
  child.set_size(10, 20)
  child.expect_screenshot()
end

T['Autocompletion']['works without LSP clients'] = function()
  -- Mock absence of LSP
  child.lsp.buf_get_clients = function() return {} end

  type_keys('i', 'aab aac aba a')
  eq(get_completion(), {})
  sleep(test_times.completion - 10)
  eq(get_completion(), {})
  sleep(10)
  eq(get_completion(), { 'aab', 'aac', 'aba' })

  -- Completion menu is filtered after entering characters
  type_keys('a')
  child.set_size(10, 20)
  child.expect_screenshot()
end

T['Autocompletion']['implements debounce-style delay'] = function()
  type_keys('i', 'J')

  sleep(test_times.completion - 10)
  eq(get_completion(), {})
  type_keys('u')
  sleep(test_times.completion - 10)
  eq(get_completion(), {})
  sleep(10)
  eq(get_completion(), { 'June', 'July' })
end

T['Autocompletion']['uses fallback'] = function()
  set_lines({ 'Jackpot', '' })
  set_cursor(2, 0)

  type_keys('i', 'Ja')
  sleep(test_times.completion + 1)
  eq(get_completion(), { 'January' })

  -- Due to how 'completefunc' and 'omnifunc' currently work, fallback won't
  -- trigger after the first character which lead to empty completion list.
  -- The reason seems to be that at that point Neovim's internal filtering of
  -- completion items is still "in charge" (backspace leads to previous
  -- completion item list without reevaluating completion function). It is
  -- only after the next character completion function gets reevaluated
  -- leading to zero items from LSP which triggers fallback action.
  type_keys('c')
  eq(child.fn.pumvisible(), 0)
  type_keys('k')
  eq(get_completion(), { 'Jackpot' })
end

T['Autocompletion']['respects `config.delay.completion`'] = function()
  child.lua('MiniCompletion.config.delay.completion = 300')

  type_keys('i', 'J')
  sleep(300 - 10)
  eq(get_completion(), {})
  sleep(10)
  eq(get_completion(), { 'January', 'June', 'July' })

  -- Should also use buffer local config
  child.ensure_normal_mode()
  set_lines({ '' })
  set_cursor(1, 0)
  child.b.minicompletion_config = { delay = { completion = 50 } }
  type_keys('i', 'J')
  sleep(50 - 10)
  eq(get_completion(), {})
  sleep(10)
  eq(get_completion(), { 'January', 'June', 'July' })
end

T['Autocompletion']['respects `config.lsp_completion.process_items`'] = function()
  child.lua('_G.process_items = function(items, base) return { items[2], items[3] } end')
  child.lua('MiniCompletion.config.lsp_completion.process_items = _G.process_items')

  type_keys('i', 'J')
  sleep(test_times.completion + 1)
  eq(get_completion(), { 'February', 'March' })

  child.ensure_normal_mode()
  set_lines({ '' })
  set_cursor(1, 0)
  child.lua('_G.process_items_2 = function(items, base) return { items[4], items[5] } end')
  child.lua('vim.b.minicompletion_config = { lsp_completion = { process_items = _G.process_items_2 } }')

  type_keys('i', 'J')
  sleep(test_times.completion + 1)
  eq(get_completion(), { 'April', 'May' })
end

T['Autocompletion']['respects string `config.fallback_action`'] = function()
  child.set_size(10, 25)
  child.lua([[MiniCompletion.config.fallback_action = '<C-x><C-l>']])

  set_lines({ 'Line number 1', '' })
  set_cursor(2, 0)
  type_keys('i', 'L')
  sleep(test_times.completion + 1)
  child.expect_screenshot()

  -- Should also use buffer local config
  child.ensure_normal_mode()
  child.b.minicompletion_config = { fallback_action = '<C-p>' }
  set_lines({ 'Line number 1', '' })
  set_cursor(2, 0)
  type_keys('i', 'L')
  sleep(test_times.completion + 1)
  child.expect_screenshot()
end

T['Autocompletion']['respects function `config.fallback_action`'] = function()
  child.lua([[MiniCompletion.config.fallback_action = function() _G.inside_fallback = true end]])
  type_keys('i', 'a')
  sleep(test_times.completion + 1)
  eq(child.lua_get('_G.inside_fallback'), true)

  child.ensure_normal_mode()
  child.lua('vim.b.minicompletion_config = { fallback_action = function() _G.inside_local_fallback = true end }')
  type_keys('i', 'a')
  sleep(test_times.completion + 1)
  eq(child.lua_get('_G.inside_local_fallback'), true)
end

T['Autocompletion']['respects `vim.{g,b}.minicompletion_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minicompletion_disable = true
    type_keys('i', 'J')
    sleep(test_times.completion + 1)
    eq(get_completion(), {})
  end,
})

T['Manual completion'] = new_set({
  hooks = {
    pre_case = function()
      -- Virtually disable auto-completion
      child.lua('MiniCompletion.config.delay.completion = 100000')
      -- Create new buffer to set buffer-local `completefunc` or `omnifunc`
      new_buffer()
      -- For details see mocking of 'textDocument/completion' request
      mock_lsp()

      set_lines({ 'Jackpot', '' })
      set_cursor(2, 0)
    end,
  },
})

T['Manual completion']['works with two-step completion'] = function()
  type_keys('i', 'J', '<C-Space>')
  eq(get_completion(), { 'January', 'June', 'July' })

  type_keys('ac')
  eq(child.fn.pumvisible(), 0)

  type_keys('<C-Space>')
  eq(get_completion(), { 'Jackpot' })
end

T['Manual completion']['works with fallback action'] = function()
  type_keys('i', 'J', '<M-Space>')
  eq(get_completion(), { 'Jackpot' })
end

T['Manual completion']['respects `config.mappings'] = function()
  reload_module({ mappings = { force_twostep = '<C-z>', force_fallback = '<C-x>' } })
  type_keys('i', 'J', '<C-z>')
  eq(get_completion(), { 'January', 'June', 'July' })
  type_keys('<C-x>')
  eq(get_completion(), { 'Jackpot' })
end

T['Manual completion']['applies `additionalTextEdits` from "textDocument/completion"'] = function()
  local validate = function(confirm_key)
    child.ensure_normal_mode()
    set_lines({})
    type_keys('i', 'Se', '<C-space>')
    poke_eventloop()
    type_keys('<C-n>', confirm_key)

    eq(child.fn.mode(), 'i')
    local is_explicit_confirm = confirm_key == '<C-y>'
    eq(
      get_lines(),
      { 'from months.completion import September', 'September' .. (is_explicit_confirm and '' or confirm_key) }
    )
    -- Text edits shouldn't interfere with relative cursor position
    eq(get_cursor(), { 2, 9 + (is_explicit_confirm and 0 or 1) })
  end

  -- 'Confirmation' should be either explicit ('<C-y>') or implicit
  -- (continued typing)
  validate('<C-y>')
  validate(' ')
end

T['Manual completion']['applies `additionalTextEdits` from "completionItem/resolve"'] = function()
  local validate = function(word_start, word)
    child.ensure_normal_mode()
    set_lines({})
    type_keys('i', word_start, '<C-space>')
    poke_eventloop()
    type_keys('<C-n>')
    -- Wait until `completionItem/resolve` request is sent
    sleep(test_times.info + 1)
    type_keys('<C-y>')

    eq(child.fn.mode(), 'i')
    eq(get_lines(), { 'from months.resolve import ' .. word, word })
    -- Text edits shouldn't interfere with relative cursor position
    eq(get_cursor(), { 2, word:len() })
  end

  -- Case when `textDocument/completion` doesn't have `additionalTextEdits`
  validate('Oc', 'October')

  -- Case when `textDocument/completion` does have `additionalTextEdits`
  validate('No', 'November')

  -- Should clear all possible cache for `additionalTextEdits`
  child.ensure_normal_mode()
  set_lines({})
  type_keys('i', 'Ja', '<C-space>')
  poke_eventloop()
  type_keys('<C-n>', '<C-y>')
  eq(get_lines(), { 'January' })
end

T['Manual completion']['respects `vim.{g,b}.minicompletion_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minicompletion_disable = true
    type_keys('i', '<C-Space>')
    poke_eventloop()
    eq(get_completion(), {})

    type_keys('i', '<M-Space>')
    poke_eventloop()
    eq(get_completion(), {})
  end,
})

T['Information window'] = new_set({
  hooks = {
    pre_case = function()
      -- Create new buffer to set buffer-local `completefunc` or `omnifunc`
      new_buffer()
      -- For details see mocking of 'textDocument/completion' request
      mock_lsp()
    end,
  },
})

local validate_info_win = function(delay)
  type_keys('i', 'J', '<C-Space>')
  eq(get_completion(), { 'January', 'June', 'July' })

  type_keys('<C-n>')
  eq(get_floating_windows(), {})
  sleep(delay - 10)
  eq(get_floating_windows(), {})
  sleep(10 + 1)
  validate_single_floating_win({ lines = { 'Month #01' } })
end

T['Information window']['works'] = function()
  child.set_size(10, 40)
  validate_info_win(test_times.info)
  child.expect_screenshot()
end

T['Information window']['respects `config.delay.info`'] = function()
  child.lua('MiniCompletion.config.delay.info = 300')
  validate_info_win(300)

  -- Should also use buffer local config
  child.ensure_normal_mode()
  set_lines({ '' })
  child.b.minicompletion_config = { delay = { info = 50 } }
  validate_info_win(50)
end

local validate_info_window_config = function(keys, completion_items, win_config)
  type_keys('i', keys, '<C-Space>')
  eq(get_completion(), completion_items)

  type_keys('<C-n>')
  -- Some windows can take a while to process on slow machines. So add `10`
  -- to ensure that processing is finished.
  sleep(test_times.info + 10)
  validate_single_floating_win({ config = win_config })
end

T['Information window']['respects `config.window.info`'] = function()
  child.set_size(25, 60)
  local win_config = { height = 20, width = 40, border = 'single' }
  child.lua('MiniCompletion.config.window.info = ' .. vim.inspect(win_config))
  validate_info_window_config('D', { 'December' }, {
    height = 20,
    width = 40,
    border = { '┌', '─', '┐', '│', '┘', '─', '└', '│' },
  })
  child.expect_screenshot()

  -- Should also use buffer local config
  child.ensure_normal_mode()
  set_lines({ '' })
  local test_border = { '1', '2', '3', '4', '5', '6', '7', '8' }
  child.b.minicompletion_config = { window = { info = { height = 10, width = 20, border = test_border } } }
  validate_info_window_config('D', { 'December' }, { height = 10, width = 20, border = test_border })
  child.expect_screenshot()
end

T['Information window']['accounts for border when picking side'] = function()
  child.set_size(10, 40)
  child.lua([[MiniCompletion.config.window.info.border = 'single']])

  set_lines({ 'aaaaaaaaaaaa ' })
  type_keys('A', 'J', '<C-Space>', '<C-n>')
  sleep(test_times.info + 10)
  child.expect_screenshot()
end

T['Information window']['has minimal dimensions for small text'] = function()
  child.set_size(10, 40)
  local win_config = { height = 1, width = 9 }
  child.lua('MiniCompletion.config.window.info = ' .. vim.inspect(win_config))
  validate_info_window_config('J', { 'January', 'June', 'July' }, win_config)
  child.expect_screenshot()
end

T['Information window']['adjusts window width'] = function()
  child.set_size(10, 27)
  child.lua([[MiniCompletion.config.window.info= { height = 15, width = 10, border = 'single' }]])

  type_keys('i', 'J', '<C-Space>', '<C-n>')
  sleep(test_times.info + 10)
  child.expect_screenshot()
end

T['Information window']['implements debounce-style delay'] = function()
  type_keys('i', 'J', '<C-Space>')
  eq(get_completion(), { 'January', 'June', 'July' })

  type_keys('<C-n>')
  sleep(test_times.info - 10)
  eq(#get_floating_windows(), 0)
  type_keys('<C-n>')
  sleep(test_times.info - 10)
  eq(#get_floating_windows(), 0)
  sleep(10 + 1)
  validate_single_floating_win({ lines = { 'Month #06' } })
end

T['Information window']['handles all buffer wipeout'] = function()
  validate_info_win(test_times.info)
  child.ensure_normal_mode()

  child.cmd('%bw!')
  new_buffer()
  mock_lsp()

  validate_info_win(test_times.info)
end

T['Information window']['respects `vim.{g,b}.minicompletion_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minicompletion_disable = true

    set_lines({ 'aa ab ', '' })
    set_cursor(2, 0)
    type_keys('i', '<C-n>', '<C-n>')
    sleep(test_times.info + 1)
    eq(#get_floating_windows(), 0)
  end,
})

T['Signature help'] = new_set({
  hooks = {
    pre_case = function()
      -- Create new buffer to set buffer-local `completefunc` or `omnifunc`
      new_buffer()
      -- For details see mocking of 'textDocument/completion' request
      mock_lsp()
    end,
  },
})

local validate_signature_win = function(delay)
  type_keys('i', 'abc(')

  eq(get_floating_windows(), {})
  sleep(delay - 10)
  eq(get_floating_windows(), {})
  sleep(10 + 1)
  validate_single_floating_win({ lines = { 'abc(param1, param2)' } })
end

T['Signature help']['works'] = function()
  child.set_size(5, 30)
  validate_signature_win(test_times.signature)
  child.expect_screenshot()
end

T['Signature help']['respects `config.delay.signature`'] = function()
  child.lua('MiniCompletion.config.delay.signature = 300')
  validate_signature_win(300)

  -- Should also use buffer local config
  child.ensure_normal_mode()
  set_lines({ '' })
  child.b.minicompletion_config = { delay = { signature = 50 } }
  validate_signature_win(50)
end

T['Signature help']['updates highlighting of active parameter'] = function()
  child.set_size(5, 30)
  child.cmd('startinsert')

  type_keys('abc(')
  sleep(test_times.signature + 1)
  child.expect_screenshot()

  type_keys('1,')
  sleep(test_times.signature + 1)
  child.expect_screenshot()

  -- As there are only two parameters, nothing should be highlighted
  type_keys('2,')
  sleep(test_times.signature + 1)
  child.expect_screenshot()
end

local validate_signature_window_config = function(keys, win_config)
  child.cmd('startinsert')
  type_keys(keys)
  sleep(test_times.signature + 2)
  validate_single_floating_win({ config = win_config })
end

T['Signature help']['respects `config.window.signature`'] = function()
  local keys = { 'l', 'o', 'n', 'g', '(' }
  local win_config = { height = 15, width = 40, border = 'single' }
  child.lua('MiniCompletion.config.window.signature = ' .. vim.inspect(win_config))
  validate_signature_window_config(keys, {
    height = 15,
    width = 40,
    border = { '┌', '─', '┐', '│', '┘', '─', '└', '│' },
  })
  child.expect_screenshot()

  -- Should also use buffer local config
  child.ensure_normal_mode()
  set_lines({ '' })
  local test_border = { '1', '2', '3', '4', '5', '6', '7', '8' }
  child.b.minicompletion_config = { window = { signature = { height = 10, width = 20, border = test_border } } }
  validate_signature_window_config(keys, { height = 10, width = 20, border = test_border })
  child.expect_screenshot()
end

T['Signature help']['accounts for border when picking side'] = function()
  child.set_size(10, 40)
  child.lua([[MiniCompletion.config.window.signature.border = 'single']])

  type_keys('o<CR>', 'abc(')
  sleep(test_times.signature + 10)
  child.expect_screenshot()
end

T['Signature help']['has minimal dimensions for small text'] = function()
  child.set_size(5, 30)
  local keys = { 'a', 'b', 'c', '(' }
  local win_config = { height = 1, width = 19 }
  child.lua('MiniCompletion.config.window.signature = ' .. vim.inspect(win_config))
  validate_signature_window_config(keys, win_config)
  child.expect_screenshot()
end

T['Signature help']['adjusts window height'] = function()
  child.set_size(10, 25)
  child.lua([[MiniCompletion.config.window.signature = { height = 15, width = 10, border = 'single' }]])

  type_keys('i', 'long(')
  sleep(test_times.signature + 10)
  child.expect_screenshot()
end

T['Signature help']['implements debounce-style delay'] = function()
  child.cmd('startinsert')
  type_keys('abc(')
  sleep(test_times.signature - 10)
  type_keys('d')
  sleep(test_times.signature + 1)
  eq(#get_floating_windows(), 0)

  type_keys(',')
  sleep(test_times.signature + 1)
  validate_single_floating_win({ lines = { 'abc(param1, param2)' } })
end

T['Signature help']['handles all buffer wipeout'] = function()
  validate_signature_win(test_times.signature)
  child.ensure_normal_mode()

  child.cmd('%bw!')
  new_buffer()
  mock_lsp()

  validate_signature_win(test_times.signature)
end

T['Signature help']['respects `vim.{g,b}.minicompletion_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minicompletion_disable = true

    type_keys('i', 'abc(')
    sleep(test_times.signature + 1)
    eq(#get_floating_windows(), 0)
  end,
})

return T
