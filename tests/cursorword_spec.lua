local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('cursorword', config) end
local unload_module = function() child.mini_unload('cursorword') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Make helpers
local word_is_highlighted = function(word)
  local general_n, current_n = 0, 0
  local general_pattern = ([[\V\<%s\>]]):format(word)
  for _, m in ipairs(child.fn.getmatches()) do
    if m.group == 'MiniCursorword' and m.pattern == general_pattern and m.priority == -2 then
      general_n = general_n + 1
    end
    if m.group == 'MiniCursorwordCurrent' and m.pattern == [[\k*\%#\k*]] and m.priority == -1 then
      current_n = current_n + 1
    end
  end
  return general_n == 1 and current_n == 1
end

local get_match = function(hl_group)
  return vim.tbl_filter(function(x)
    return x.group == hl_group
  end, child.fn.getmatches())
end

-- Data =======================================================================
local example_lines = { 'aa', 'aa', 'aaa' }

local test_times = { delay = 100 }

-- Unit tests =================================================================
describe('MiniCursorword.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniCursorword ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniCursorword'), 1)

    -- Autocommand on `ModeChanged` event
    if child.fn.has('nvim-0.7.0') == 1 then
      eq(child.fn.exists('#MiniCursorword#ModeChanged'), 1)
    end

    -- Highlight groups
    assert.truthy(child.cmd_capture('hi MiniCursorword'):find('gui=underline'))
    assert.truthy(child.cmd_capture('hi MiniCursorwordCurrent'):find('links to MiniCursorword'))
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniCursorword.config)'), 'table')

    -- Check default values
    eq(child.lua_get('MiniCursorword.config.delay'), 100)
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ delay = 300 })
    eq(child.lua_get('MiniCursorword.config.delay'), 300)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ delay = 'a' }, 'delay', 'number')
  end)
end)

-- Functional tests ===========================================================
describe('Cursorword autohighlighting', function()
  before_each(function()
    child.setup()
    set_lines(example_lines)
    load_module()
  end)

  local validate_cursorword = function(delay)
    set_cursor(2, 0)
    eq(word_is_highlighted('aa'), false)
    sleep(delay - 10)
    eq(word_is_highlighted('aa'), false)
    sleep(10)
    eq(word_is_highlighted('aa'), true)
  end

  it('works', function()
    validate_cursorword(test_times.delay)
  end)

  it('respects `config.delay`', function()
    reload_module({ delay = 200 })
    validate_cursorword(200)
  end)

  it('removes highlight immediately after move', function()
    set_cursor(2, 0)
    sleep(test_times.delay)
    eq(word_is_highlighted('aa'), true)
    set_cursor(3, 0)
    eq(child.fn.getmatches(), {})
  end)

  local validate_immediate = function(move_command)
    set_cursor(2, 0)
    sleep(test_times.delay)
    eq(word_is_highlighted('aa'), true)

    local match_gen = get_match('MiniCursorword')
    child.cmd(move_command)
    sleep(0)
    eq(word_is_highlighted('aa'), true)

    -- Check that general match group didn't change (as word is same)
    eq(match_gen, get_match('MiniCursorword'))
  end

  it('highlights immediately inside current word', function()
    validate_immediate('normal! l')
  end)

  it('highlights immediately same word in other place', function()
    validate_immediate('normal! k')
  end)

  it('highlights only "keyword" symbols', function()
    local validate_highlighted = function(cursor_pos, hl_word)
      set_cursor(unpack(cursor_pos))
      if hl_word == nil then
        eq(child.fn.getmatches(), {})
      else
        eq(word_is_highlighted(hl_word), true)
      end
    end

    reload_module({ delay = 0 })
    set_lines({ 'a_111', '  ', 'aa bb', 'aa.bb', '!!!' })

    validate_highlighted({ 1, 1 }, 'a_111')
    validate_highlighted({ 1, 2 }, 'a_111')
    validate_highlighted({ 2, 0 }, nil)
    validate_highlighted({ 3, 1 }, 'aa')
    validate_highlighted({ 3, 2 }, nil)
    validate_highlighted({ 4, 0 }, 'aa')
    validate_highlighted({ 4, 2 }, nil)
    validate_highlighted({ 4, 3 }, 'bb')
    validate_highlighted({ 5, 0 }, nil)
  end)

  it('stops in Insert mode', function()
    set_cursor(2, 0)
    sleep(test_times.delay)
    eq(word_is_highlighted('aa'), true)
    type_keys('i')
    poke_eventloop()
    eq(word_is_highlighted('aa'), false)
  end)

  it('stops in Terminal mode', function()
    set_cursor(2, 0)
    sleep(test_times.delay)
    eq(word_is_highlighted('aa'), true)
    child.cmd('doautocmd TermEnter')
    eq(word_is_highlighted('aa'), false)
  end)

  it('respects ModeChanged', function()
    if child.fn.exists('##ModeChanged') ~= 1 then
      return
    end

    -- Add disabling in Visual mode
    unload_module()
    child.cmd([[
      augroup VisualDisable
        au!
        au ModeChanged *:[vV\x16]* lua vim.b.minicursorword_disable = true
        au ModeChanged [vV\x16]*:* lua vim.b.minicursorword_disable = false
      augroup END
    ]])
    child.lua([[require('mini.cursorword').setup({ delay = 0 })]])

    set_cursor(2, 0)
    poke_eventloop()
    eq(word_is_highlighted('aa'), true)

    type_keys('v')
    poke_eventloop()
    eq(word_is_highlighted('aa'), false)

    type_keys('v')
    poke_eventloop()
    eq(word_is_highlighted('aa'), true)
  end)

  it('respects vim.{g,b}.minicursorword_disable', function()
    local validate_disable = function(var_type)
      set_cursor(1, 1)

      child[var_type].minicursorword_disable = true
      set_cursor(1, 0)
      sleep(test_times.delay)
      eq(word_is_highlighted('aa'), false)

      child[var_type].minicursorword_disable = false
      set_cursor(1, 1)
      sleep(test_times.delay)
      eq(word_is_highlighted('aa'), true)

      child[var_type].minicursorword_disable = nil
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

child.stop()
