local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('pairs', config) end
local unload_module = function() child.mini_unload('pairs') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
--stylua: ignore end

-- Make helpers
local get_term_channel = function()
  local term_chans = vim.tbl_filter(function(x)
    return x.mode == 'terminal'
  end, child.api.nvim_list_chans())[1]['id']
  return term_chans[1]['id']
end

--- Make simple test on empty entity
---@private
local validate_action = function(mode, test)
  mode = mode or 'i'

  -- Expects to start in Normal mode
  if mode == 'i' then
    -- Setup
    local lines, cursor = get_lines(), get_cursor()
    set_lines({})
    child.cmd('startinsert')

    -- Test
    test()

    -- Cleanup
    type_keys('<Esc>')
    set_lines(lines)
    set_cursor(unpack(cursor))
  elseif mode == 'c' then
    -- Setup
    type_keys(':')

    -- Test
    test()

    -- Cleanup
    type_keys('<Esc>')
  elseif mode == 't' then
    -- Setup
    child.cmd('terminal! bash --noprofile --norc')
    -- Wait for terminal to get active
    sleep(50)
    child.cmd('startinsert')

    -- Test
    test()

    -- Cleanup
    type_keys({ [[<C-\>]], '<C-n>' })
    child.cmd('bwipeout!')
  end
end

--- Validate that `key` on its own inserts `pair` (whatever it is: for smaller
--- code, it might be single character to test in 'MiniPairs.close()').
---@private
local validate_open = function(mode, key, pair)
  local test = ({
    i = function()
      type_keys(key)
      eq(get_lines(), { pair })
      eq(get_cursor(), { 1, 1 })
    end,
    c = function()
      type_keys(key)
      eq(child.fn.getcmdline(), pair)
      eq(child.fn.getcmdpos(), 2)
    end,
    t = function()
      -- Need to wait after each keystroke to allow shell to process it
      local wait = 10
      local first_line = get_lines()[1]
      type_keys(key, wait)
      eq(get_lines()[1], first_line .. ' ' .. pair)
    end,
  })[mode]

  validate_action(mode, test)
end

--- Validate that `key` jumps over right hand side of `pair` if it is next.
---@private
local validate_close = function(mode, key, pair)
  local test = ({
    i = function()
      set_lines({ pair })
      set_cursor(1, 1)
      type_keys(key)
      eq(get_lines(), { pair })
      eq(get_cursor(), { 1, 2 })
    end,
    c = function()
      type_keys({ '<C-v>', pair:sub(1, 1), '<C-v>', pair:sub(2, 2), '<Left>' })
      type_keys(key)
      eq(child.fn.getcmdline(), pair)
      eq(child.fn.getcmdpos(), 3)
    end,
    t = function()
      -- Need to wait after each keystroke to allow shell to process it
      local wait = 10
      local term_channel = get_term_channel()

      -- Jumps over right hand side of `pair` if it is next
      local first_line = get_lines()[1]
      child.fn.chansend(term_channel, pair)
      sleep(wait)
      type_keys('<Left>', wait)
      type_keys(key, wait)
      eq(get_lines()[1], first_line .. ' ' .. pair)
    end,
  })[mode]

  validate_action(mode, test)
end

--- Validate that `<BS>` deletes whole pair if inside of it.
---@private
local validate_bs = function(mode, pair)
  local test = ({
    i = function()
      set_lines({ pair })
      set_cursor(1, 1)
      type_keys('<BS>')
      eq(get_lines(), { '' })
    end,
    c = function()
      type_keys({ '<C-v>', pair:sub(1, 1), '<C-v>', pair:sub(2, 2), '<Left>' })
      type_keys('<BS>')
      eq(child.fn.getcmdline(), '')
      eq(child.fn.getcmdpos(), 1)
    end,
    t = function()
      -- Need to wait after each keystroke to allow shell to process it
      local wait = 10
      local term_channel = get_term_channel()

      local first_line = get_lines()[1]
      child.fn.chansend(term_channel, pair)
      sleep(wait)
      type_keys('<Left>', wait)
      type_keys('<BS>', wait)
      eq(get_lines()[1], first_line .. ' ')
    end,
  })[mode]

  validate_action(mode, test)
end

--- Validate that `<CR>` acts like `<CR><C-o>O` in Insert mode if inside pair.
---@private
local validate_cr = function(pair)
  local test = function()
    -- Reference pass
    set_lines({ pair })
    set_cursor(1, 1)

    type_keys('<Esc>')
    -- Use `exe "..."` to allow special characters (as per `:h :normal`)
    child.cmd([[exe "normal! a\<CR>\<C-o>O"]])

    local ref_lines, ref_cursor = get_lines(), get_cursor()

    -- Intermediate cleanup
    -- Test pass
    set_lines({ pair })
    set_cursor(1, 1)

    poke_eventloop()
    type_keys({ 'i', '<CR>' })
    eq(get_lines(), ref_lines)
    eq(get_cursor(), ref_cursor)
    eq(child.fn.mode(), 'i')
  end

  validate_action('i', test)
end

local validate_neigh_disable = function(neigh, key)
  set_lines({ neigh })
  set_cursor(1, 0)
  type_keys('a')

  type_keys(key)
  eq(get_lines(), { neigh:sub(1, 1) .. key .. neigh:sub(2, 2) })

  child.ensure_normal_mode()
end

local validate_slash = function(key)
  validate_neigh_disable([[\]], key)
end

local validate_no = function(action, ...)
  local val_f = ({
    open = validate_open,
    close = validate_close,
    bs = validate_bs,
    cr = validate_cr,
    neigh_disable = validate_neigh_disable,
  })[action]

  -- Validation function `val_f` should throw error
  local ok, _ = pcall(val_f, ...)
  child.ensure_normal_mode()
  assert.False(ok)
end

local validate_disable = function(var_type, key)
  child[var_type].minipairs_disable = true
  set_lines({})
  child.cmd('startinsert')
  type_keys(key)
  eq(get_lines(), { key })

  child[var_type].minipairs_disable = nil
end

-- Unit tests =================================================================
describe('MiniPairs.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniPairs ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniPairs'), 1)
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniPairs.config)'), 'table')

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniPairs.config.' .. field), value)
    end

    -- Check default values
    assert_config('modes', { insert = true, command = false, terminal = false })
    assert_config("mappings['(']", { action = 'open', pair = '()', neigh_pattern = '[^\\].' })
    assert_config("mappings['[']", { action = 'open', pair = '[]', neigh_pattern = '[^\\].' })
    assert_config("mappings['{']", { action = 'open', pair = '{}', neigh_pattern = '[^\\].' })
    assert_config("mappings[')']", { action = 'close', pair = '()', neigh_pattern = '[^\\].' })
    assert_config("mappings[']']", { action = 'close', pair = '[]', neigh_pattern = '[^\\].' })
    assert_config("mappings['}']", { action = 'close', pair = '{}', neigh_pattern = '[^\\].' })
    assert_config(
      "mappings['\"']",
      { action = 'closeopen', pair = '""', neigh_pattern = '[^\\].', register = { cr = false } }
    )
    assert_config(
      'mappings["\'"]',
      { action = 'closeopen', pair = "''", neigh_pattern = '[^%a\\].', register = { cr = false } }
    )
    assert_config(
      "mappings['`']",
      { action = 'closeopen', pair = '``', neigh_pattern = '[^\\].', register = { cr = false } }
    )
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ modes = { command = true } })
    eq(child.lua_get('MiniPairs.config.modes.command'), true)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ modes = 'a' }, 'modes', 'table')
    assert_config_error({ modes = { insert = 'a' } }, 'modes.insert', 'boolean')
    assert_config_error({ modes = { command = 'a' } }, 'modes.command', 'boolean')
    assert_config_error({ modes = { terminal = 'a' } }, 'modes.terminal', 'boolean')

    local assert_mapping_pair_info = function(key)
      local quote = key == "'" and '"' or "'"
      local prefix = ('mappings[%s%s%s]'):format(quote, key, quote)
      assert_config_error({ mappings = { [key] = 'a' } }, 'mappings', 'table')
      assert_config_error({ mappings = { [key] = { action = 1 } } }, prefix .. '.action', 'string')
      assert_config_error({ mappings = { [key] = { action = 1 } } }, prefix .. '.action', 'string')
      assert_config_error({ mappings = { [key] = { pair = 1 } } }, prefix .. '.pair', 'string')
      assert_config_error({ mappings = { [key] = { neigh_pattern = 1 } } }, prefix .. '.neigh_pattern', 'string')
      assert_config_error({ mappings = { [key] = { register = 'a' } } }, prefix .. '.register', 'table')
      assert_config_error({ mappings = { [key] = { register = { bs = 1 } } } }, prefix .. '.register.bs', 'boolean')
      assert_config_error({ mappings = { [key] = { register = { cr = 1 } } } }, prefix .. '.register.cr', 'boolean')
    end

    assert_config_error({ mappings = 'a' }, 'mappings', 'table')
    assert_mapping_pair_info('(')
    assert_mapping_pair_info('[')
    assert_mapping_pair_info('{')
    assert_mapping_pair_info(')')
    assert_mapping_pair_info(']')
    assert_mapping_pair_info('}')
    assert_mapping_pair_info('"')
    assert_mapping_pair_info("'")
    assert_mapping_pair_info('`')
  end)

  local has_map = function(lhs, rhs, mode)
    mode = mode or 'i'
    local map_capture = child.cmd_capture(mode .. 'map ' .. lhs)
    return map_capture:find(vim.pesc(rhs)) ~= nil
  end

  local validate_map = function(lhs, rhs, mode)
    assert.True(has_map(lhs, rhs, mode))
  end
  local validate_no_map = function(lhs, rhs, mode)
    assert.False(has_map(lhs, rhs, mode))
  end

  it('makes default `config.mappings`', function()
    validate_map('(', [[v:lua.MiniPairs.open("()", "[^\\].")]])
    validate_map('[', [[v:lua.MiniPairs.open("[]", "[^\\].")]])
    validate_map('{', [[v:lua.MiniPairs.open("{}", "[^\\].")]])
    validate_map(')', [[v:lua.MiniPairs.close("()", "[^\\].")]])
    validate_map(']', [[v:lua.MiniPairs.close("[]", "[^\\].")]])
    validate_map('}', [[v:lua.MiniPairs.close("{}", "[^\\].")]])
    validate_map('"', [[v:lua.MiniPairs.closeopen('""', "[^\\].")]])
    validate_map("'", [[v:lua.MiniPairs.closeopen("''", "[^%a\\].")]])
    validate_map('`', [[v:lua.MiniPairs.closeopen("``", "[^\\].")]])

    validate_map('<CR>', [[v:lua.MiniPairs.cr()]])
    validate_map('<BS>', [[v:lua.MiniPairs.bs()]])
  end)

  it('makes custom `config.mappings`', function()
    reload_module({ mappings = { ['('] = { pair = '[]', action = 'close' } } })
    validate_map('(', [[v:lua.MiniPairs.close("[]", "[^\\].")]])

    reload_module({ mappings = { ['*'] = { pair = '**', action = 'closeopen' } } })
    validate_map('*', [[v:lua.MiniPairs.closeopen("**", "..")]])
  end)

  it('makes mappings in supplied modes', function()
    child.api.nvim_del_keymap('i', '(')
    reload_module({ modes = { insert = false, command = true, terminal = false } })

    validate_no_map('(', [[v:lua.MiniPairs.open("()", "[^\\].")]])
    validate_map('(', [[v:lua.MiniPairs.open("()", "[^\\].")]], 'c')
  end)
end)

local validate_map_function = function(fun_name)
  local is_buf_local = fun_name == 'map_buf'

  local apply_map = function(args_string)
    -- If testing `MiniPairs.map_buf()`, apply it in current buffer
    local command = ('MiniPairs.%s(%s%s)'):format(fun_name, is_buf_local and '0, ' or '', args_string)
    child.lua(command)
  end

  it('works', function()
    validate_no('open', 'i', '<', '<>')
    validate_no('bs', 'i', '<>')
    validate_no('cr', '<>')

    apply_map([['i', '<', { action = 'open', pair = '<>' }]])

    validate_open('i', '<', '<>')
    validate_bs('i', '<>')
    validate_cr('<>')
  end)

  it(('creates mapping %s'):format(is_buf_local and 'for buffer' or 'globally'), function()
    local has_open = function()
      validate_open('i', '<', '<>')
      validate_bs('i', '<>')
      validate_cr('<>')
    end
    local no_open = function()
      validate_no('open', 'i', '<', '<>')
      validate_no('bs', 'i', '<>')
      validate_no('cr', '<>')
    end

    -- Set up two buffers
    local buffers = { cur = child.api.nvim_get_current_buf(), new = child.api.nvim_create_buf(true, false) }

    child.api.nvim_set_current_buf(buffers.cur)
    no_open()
    child.api.nvim_set_current_buf(buffers.new)
    no_open()

    child.api.nvim_set_current_buf(buffers.cur)
    apply_map([['i', '<', { action = 'open', pair = '<>' }]])
    has_open()

    child.api.nvim_set_current_buf(buffers.new)
    if is_buf_local then
      no_open()
    else
      has_open()
    end
  end)

  it('respects `mode` argument', function()
    local validate = function(mode)
      local command = ([['%s', '<', { action = 'open', pair = '<>' }]]):format(mode)
      apply_map(command)
      validate_open(mode, '<', '<>')
    end

    validate('i')
    -- If making global mapping, also test in other modes
    if fun_name == 'map' then
      validate('c')
      validate('t')
    end
  end)

  it('respects `lhs` argument', function()
    apply_map([['i', '<', { action = 'open', pair = '<>' }]])
    validate_open('i', '<', '<>')

    apply_map([['i', '$', { action = 'open', pair = '$%' }]])
    validate_open('i', '$', '$%')
  end)

  it('respects `action` and `pair` of `pair_info` argument', function()
    apply_map([['i', '>', { action = 'close', pair = '<>' }]])
    validate_close('i', '>', '<>')
  end)

  it('respects `neigh_pattern` of `pair_info` argument', function()
    -- It should insert pair only when cursor after whitespace and before
    -- letter 'a'
    apply_map([['i', '<', { action = 'open', pair = '<>', neigh_pattern = '%sa' }]])

    local test = function()
      -- Use typing delay to poke eventloop and enable correct neighbor pattern
      -- checks
      local wait = 1

      -- Shouldn't work in general
      type_keys({ 'a', '<' }, wait)
      eq(get_lines(), { 'a<' })

      -- Should work only within specified pattern
      set_lines({})
      type_keys({ ' ', 'a', '<Left>', '<' }, wait)
      eq(get_lines(), { ' <>a' })
    end

    validate_action('i', test)
  end)

  it('respects `register` of `pair_info` argument', function()
    apply_map([['i', '<', { action = 'open', pair = '<>', register = { bs = true, cr = false } }]])

    validate_bs('i', '<>')
    validate_no('cr', '<>')
  end)

  it('respects `opts` or `pair_info` argument', function()
    -- Throws error because mapping `(` should already exist
    assert.error(function()
      apply_map([['i', '(', { action = 'open', pair = '()' }, { unique = true })]])
    end)
  end)

  it('creates mappings for `<BS>` in new mode', function()
    assert.truthy(child.cmd_capture('cmap <BS>'):find('No mapping found'))
    validate_no('bs', 'c', '<>')

    apply_map([['c', '<', { action = 'open', pair = '<>' }]])

    -- assert.truthy(child.cmd_capture('cmap <BS>'):find('MiniPairs%.bs'))
    validate_bs('c', '<>')
  end)

  it('creates mappings for `<CR>` in new mode', function()
    child.api.nvim_del_keymap('i', '<CR>')

    assert.truthy(child.cmd_capture('imap <CR>'):find('No mapping found'))
    validate_no('cr', '<>')

    apply_map([['i', '<', { action = 'open', pair = '<>' }]])

    assert.truthy(child.cmd_capture('imap <CR>'):find('MiniPairs%.cr'))
    validate_cr('<>')
  end)
end

describe('MiniPairs.map()', function()
  before_each(function()
    child.setup()
    load_module()

    -- Allow switching between buffers with unsaved changes
    child.o.hidden = true
  end)

  validate_map_function('map')
end)

describe('MiniPairs.map_buf()', function()
  before_each(function()
    child.setup()
    load_module()

    -- Allow switching between buffers with unsaved changes
    child.o.hidden = true
  end)

  validate_map_function('map_buf')
end)

local validate_unmap_function = function(fun_name)
  local is_buf_local = fun_name == 'unmap_buf'

  local apply_unmap = function(args_string)
    -- If testing `MiniPairs.unmap_buf()`, apply it in current buffer
    local command = ('MiniPairs.%s(%s%s)'):format(fun_name, is_buf_local and '0, ' or '', args_string)
    child.lua(command)
  end

  -- These functions needed to test mapping of the same "global/local" type
  -- (`unmap()` deletes mapping from `map()`, `unmap_buf()` - from `map_buf()`)
  local apply_map = function(args_string)
    local command = ('MiniPairs.%s(%s%s)'):format(
      is_buf_local and 'map_buf' or 'map',
      is_buf_local and '0, ' or '',
      args_string
    )
    child.lua(command)
  end

  local make_test_map = function()
    apply_map([['i', '<', { action = 'open', pair = '<>' }]])
  end

  local has_test_map = function()
    validate_open('i', '<', '<>')
    validate_bs('i', '<>')
    validate_cr('<>')
  end

  local no_test_map = function()
    validate_no('open', 'i', '<', '<>')
    validate_no('bs', 'i', '<>')
    validate_no('cr', '<>')
  end

  it('works', function()
    make_test_map()
    has_test_map()

    apply_unmap([['i', '<', '<>']])
    no_test_map()
  end)

  it(('deletes mapping %s'):format(is_buf_local and 'for buffer' or 'globally'), function()
    -- Set up two buffers
    local buffers = { cur = child.api.nvim_get_current_buf(), new = child.api.nvim_create_buf(true, false) }

    child.api.nvim_set_current_buf(buffers.cur)
    make_test_map()
    has_test_map()
    child.api.nvim_set_current_buf(buffers.new)
    make_test_map()
    has_test_map()

    child.api.nvim_set_current_buf(buffers.cur)
    apply_unmap([['i', '<', '<>']])
    no_test_map()

    child.api.nvim_set_current_buf(buffers.new)
    if is_buf_local then
      has_test_map()
    else
      no_test_map()
    end
  end)

  it('respects `mode` argument', function()
    apply_map([['c', '<', { action = 'open', pair = '<>' }]])
    validate_open('c', '<', '<>')
    validate_bs('c', '<>')

    apply_unmap([['c', '<', '<>']])
    validate_no('open', 'c', '<', '<>')
    validate_no('bs', 'c', '<>')
  end)

  it('requires explicit `pair` argument', function()
    assert.error(function()
      apply_unmap([['i', '(']])
    end)
  end)

  it('allows empty string for `pair` argument to not unregister pair', function()
    make_test_map()
    has_test_map()

    apply_unmap([['i', '<', '']])
    validate_no('open', 'i', '<', '<>')
    validate_bs('i', '<>')
    validate_cr('<>')
  end)

  it('works for already missing mapping', function()
    assert.not_error(function()
      apply_unmap([['c', '%', '%%']])
    end)
  end)
end

describe('MiniPairs.unmap()', function()
  before_each(function()
    child.setup()
    load_module()

    -- Allow switching between buffers with unsaved changes
    child.o.hidden = true
  end)

  validate_unmap_function('unmap')
end)

describe('MiniPairs.unmap_buf()', function()
  before_each(function()
    child.setup()
    load_module()

    -- Allow switching between buffers with unsaved changes
    child.o.hidden = true
  end)

  validate_unmap_function('unmap_buf')
end)

-- Functional tests ===========================================================
describe('Open action', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('works', function()
    validate_open('i', '(', '()')
    validate_open('i', '[', '[]')
    validate_open('i', '{', '{}')
  end)

  it('does not break undo sequence in Insert mode', function()
    type_keys({ 'i', '(', '(', '<Esc>' })
    eq(get_lines(), { '(())' })
    eq(get_cursor(), { 1, 1 })

    type_keys('u')
    eq(get_lines(), { '' })
  end)

  it('respects neighbor pattern', function()
    validate_slash('(')
    validate_slash('[')
    validate_slash('{')
  end)

  it('is correctly initiated in `config.mappings`', function()
    child.api.nvim_del_keymap('i', '(')
    reload_module({ mappings = { ['('] = { action = 'open', pair = '()', neigh_pattern = '..' } } })
    validate_no('neigh_disable', [[\]], '(')
  end)

  it('respects vim.{g,b}.minipairs_disable', function()
    validate_disable('g', '(')
    validate_disable('g', '[')
    validate_disable('g', '{')
    validate_disable('b', '(')
    validate_disable('b', '[')
    validate_disable('b', '{')
  end)
end)

describe('Close action', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('works', function()
    validate_open('i', ')', ')')
    validate_open('i', ']', ']')
    validate_open('i', '}', '}')
    validate_close('i', ')', '()')
    validate_close('i', ']', '[]')
    validate_close('i', '}', '{}')
  end)

  it('does not break undo sequence in Insert mode', function()
    set_lines({ '(())' })
    set_cursor(1, 2)

    type_keys({ 'i', ')', ')', ' ', '<Esc>' })
    type_keys('u')
    eq(get_lines(), { '(())' })
  end)

  local validate_slash_close = function(key, pair)
    set_lines({ pair })
    set_cursor(1, 1)
    child.cmd('startinsert')

    type_keys([[\]])
    poke_eventloop()
    type_keys(key)
    eq(get_lines(), { pair:sub(1, 1) .. [[\]] .. key .. pair:sub(2, 2) })
  end

  it('respects neighbor pattern', function()
    validate_slash_close(')', '()')
    validate_slash_close(']', '[]')
    validate_slash_close('}', '{}')
  end)

  it('is correctly initiated in `config.mappings`', function()
    child.api.nvim_del_keymap('i', ')')
    reload_module({ mappings = { [')'] = { action = 'close', pair = '()', neigh_pattern = '..' } } })
    assert.error(function()
      validate_slash_close(')', '()')
    end)
  end)

  it('respects vim.{g,b}.minipairs_disable', function()
    validate_disable('g', ')')
    validate_disable('g', ']')
    validate_disable('g', '}')
    validate_disable('b', ')')
    validate_disable('b', ']')
    validate_disable('b', '}')
  end)
end)

describe('Closeopen action', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('works', function()
    validate_open('i', '"', '""')
    validate_open('i', "'", "''")
    validate_open('i', '`', '``')
    validate_close('i', '"', '""')
    validate_close('i', "'", "''")
    validate_close('i', '`', '``')
  end)

  it('does not break undo sequence in Insert mode', function()
    -- Open
    set_lines({})

    type_keys({ 'i', '"', '"', '<Esc>' })
    type_keys('u')
    eq(get_lines(), { '' })

    -- Close
    set_lines({ '""""' })
    set_cursor(1, 2)

    type_keys({ 'i', '"', '"', ' ', '<Esc>' })
    type_keys('u')
    eq(get_lines(), { '""""' })
  end)

  it('respects neighbor pattern', function()
    validate_slash('"')
    validate_slash("'")
    validate_slash('`')

    validate_neigh_disable('a ', "'")

    validate_no('neigh_disable', '__', '"')
    validate_no('neigh_disable', '__', "'")
    validate_no('neigh_disable', '__', '`')
  end)

  it('is correctly initiated in `config.mappings`', function()
    child.api.nvim_del_keymap('i', '"')
    reload_module({ mappings = { ['"'] = { action = 'closeopen', pair = '""', neigh_pattern = '..' } } })
    validate_no('neigh_disable', [[\]], '"')
  end)

  it('respects vim.{g,b}.minipairs_disable', function()
    validate_disable('g', '"')
    validate_disable('g', "'")
    validate_disable('g', '`')
    validate_disable('b', '"')
    validate_disable('b', "'")
    validate_disable('b', '`')
  end)
end)

describe('<BS> action', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('works', function()
    validate_bs('i', '()')
    validate_bs('i', '[]')
    validate_bs('i', '{}')
    validate_bs('i', '""')
    validate_bs('i', "''")
    validate_bs('i', '``')
  end)

  it('does not break undo sequence in Insert mode', function()
    set_lines({ 'a()' })
    set_cursor(1, 2)
    child.cmd('startinsert')

    type_keys({ '<BS>', '<BS>', '<Esc>' })
    eq(get_lines(), { '' })
    type_keys('u')
    eq(get_lines(), { 'a()' })
  end)

  local reload_unregister = function()
    child.api.nvim_del_keymap('i', '<BS>')
    reload_module({
      mappings = {
        ['('] = { register = { bs = false } },
        ['['] = { register = { bs = false } },
        ['{'] = { register = { bs = false } },
        [')'] = { register = { bs = false } },
        [']'] = { register = { bs = false } },
        ['}'] = { register = { bs = false } },
        ['"'] = { register = { bs = false } },
        ["'"] = { register = { bs = false } },
        ['`'] = { register = { bs = false } },
      },
    })
  end

  it('does not create mapping if nothing is registered in `config.mappings`', function()
    assert.truthy(child.cmd_capture('imap <BS>'):find('MiniPairs%.bs'))
    reload_unregister()
    assert.truthy(child.cmd_capture('imap <BS>'):find('No mapping found'))
  end)

  it('works as normal if nothing is registered', function()
    reload_unregister()

    set_lines({ '()' })
    set_cursor(1, 1)
    child.cmd('startinsert')

    type_keys('<BS>')
    eq(get_lines(), { ')' })
    eq(get_cursor(), { 1, 0 })
  end)

  it('respects vim.{g,b}.minipairs_disable', function()
    local validate_disable_bs = function(var_type)
      child[var_type].minipairs_disable = true
      set_lines({ '()' })
      set_cursor(1, 1)
      child.cmd('startinsert')
      type_keys('<BS>')
      eq(get_lines(), { ')' })

      child[var_type].minipairs_disable = nil
    end

    validate_disable_bs('g')
    validate_disable_bs('b')
  end)
end)

describe('<CR> action', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('works', function()
    validate_cr('()')
    validate_cr('[]')
    validate_cr('{}')
    validate_no('cr', '""')
    validate_no('cr', "''")
    validate_no('cr', '``')
  end)

  it('does not break undo sequence in Insert mode', function()
    set_lines({ '()' })
    set_cursor(1, 1)
    child.cmd('startinsert')

    type_keys({ '<CR>', 'a', '<Esc>' })
    type_keys('u')
    eq(get_lines(), { '()' })
  end)

  local reload_unregister = function()
    child.api.nvim_del_keymap('i', '<CR>')
    reload_module({
      mappings = {
        ['('] = { register = { cr = false } },
        ['['] = { register = { cr = false } },
        ['{'] = { register = { cr = false } },
        [')'] = { register = { cr = false } },
        [']'] = { register = { cr = false } },
        ['}'] = { register = { cr = false } },
        ['"'] = { register = { cr = false } },
        ["'"] = { register = { cr = false } },
        ['`'] = { register = { cr = false } },
      },
    })
  end

  it('does not create mapping if nothing is registered in `config.mappings`', function()
    assert.truthy(child.cmd_capture('imap <CR>'):find('MiniPairs%.cr'))
    reload_unregister()
    assert.truthy(child.cmd_capture('imap <CR>'):find('No mapping found'))
  end)

  it('works as normal if nothing is registered', function()
    reload_unregister()

    set_lines({ '()' })
    set_cursor(1, 1)
    child.cmd('startinsert')

    type_keys('<CR>')
    eq(get_lines(), { '(', ')' })
    eq(get_cursor(), { 2, 0 })
  end)

  it('respects vim.{g,b}.minipairs_disable', function()
    local validate_disable_cr = function(var_type)
      child[var_type].minipairs_disable = true
      set_lines({ '()' })
      set_cursor(1, 1)
      child.cmd('startinsert')
      type_keys('<CR>')
      eq(get_lines(), { '(', ')' })

      child[var_type].minipairs_disable = nil
    end

    validate_disable_cr('g')
    validate_disable_cr('b')
  end)
end)

child.stop()
