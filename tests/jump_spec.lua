local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('jump', config) end
local unload_module = function() child.mini_unload('jump') end
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
-- Doesn't seem (yet) to be a better way to test exact highlighted places
local highlights_target = function(target, backward, till)
  local n = 0
  local pattern = [[\V%s]]
  if till then
    pattern = backward == true and [[\V%s\.\@=]] or [[\V\.\@<=%s]]
  end
  pattern = string.format(pattern, target)
  for _, match in ipairs(child.fn.getmatches()) do
    if match.group == 'MiniJump' and match.pattern == pattern then
      n = n + 1
    end
  end
  return n == 1
end

-- Data =======================================================================
local example_lines = {
  'Lorem ipsum dolor sit amet,',
  'consectetur adipiscing elit, sed do eiusmod tempor',
  'incididunt ut labore et dolore magna aliqua.',
  '`!@#$%^&*()_+=.,1234567890',
}

local test_times = { highlight = 250 }

-- Unit tests =================================================================
describe('MiniJump.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniJump ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniJump'), 1)

    -- Highlight groups
    assert.truthy(child.cmd_capture('hi MiniJump'):find('links to SpellRare'))
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniJump.config)'), 'table')

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniJump.config.' .. field), value)
    end

    -- Check default values
    assert_config('delay.highlight', 250)
    assert_config('delay.idle_stop', 10000000)
    assert_config('mappings.forward', 'f')
    assert_config('mappings.backward', 'F')
    assert_config('mappings.forward_till', 't')
    assert_config('mappings.backward_till', 'T')
    assert_config('mappings.repeat_jump', ';')
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ delay = { highlight = 500 } })
    eq(child.lua_get('MiniJump.config.delay.highlight'), 500)
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
    assert_config_error({ delay = { highlight = 'a' } }, 'delay.highlight', 'number')
    assert_config_error({ delay = { idle_stop = 'a' } }, 'delay.idle_stop', 'number')
    assert_config_error({ mappings = 'a' }, 'mappings', 'table')
    assert_config_error({ mappings = { forward = 1 } }, 'mappings.forward', 'string')
    assert_config_error({ mappings = { backward = 1 } }, 'mappings.backward', 'string')
    assert_config_error({ mappings = { forward_till = 1 } }, 'mappings.forward_till', 'string')
    assert_config_error({ mappings = { backward_till = 1 } }, 'mappings.backward_till', 'string')
    assert_config_error({ mappings = { repeat_jump = 1 } }, 'mappings.repeat_jump', 'string')
  end)

  it('properly handles `config.mappings`', function()
    local has_map = function(lhs)
      return child.cmd_capture('nmap ' .. lhs):find('MiniJump') ~= nil
    end
    assert.True(has_map('f'))

    unload_module()
    child.api.nvim_del_keymap('n', 'f')

    -- Supplying empty string should mean "don't create keymap"
    load_module({ mappings = { forward = '' } })
    assert.False(has_map('f'))
  end)
end)

describe('MiniJump.state', function()
  child.setup()
  load_module()

  before_each(function()
    child.lua('MiniJump.stop_jumping()')
    set_lines({ '1e2e3e4e' })
    set_cursor(1, 0)
  end)

  local get_state = function()
    return child.lua_get('MiniJump.state')
  end

  it('has correct initial values', function()
    eq(get_state(), {
      target = nil,
      backward = false,
      till = false,
      n_times = 1,
      mode = nil,
      jumping = false,
    })
  end)

  it('updates `target`', function()
    type_keys({ 'f', 'e' })
    eq(get_state().target, 'e')

    child.lua('MiniJump.stop_jumping()')
    child.lua([[MiniJump.jump('3e')]])
    eq(get_state().target, '3e')
  end)

  it('updates `backward`', function()
    set_cursor(1, 7)
    type_keys({ 'F', 'e' })
    eq(get_state().backward, true)

    type_keys({ 'f' })
    eq(get_state().backward, false)
  end)

  it('updates `till`', function()
    type_keys({ 't', 'e' })
    eq(get_state().till, true)

    type_keys({ 'f' })
    eq(get_state().till, false)
  end)

  it('updates `n_times`', function()
    type_keys({ '2', 'f', 'e' })
    eq(get_state().n_times, 2)
  end)

  it('updates `mode`', function()
    type_keys({ 't', 'e' })
    eq(get_state().mode, 'n')
    child.lua('MiniJump.stop_jumping()')

    type_keys({ 'V', 't', 'e' })
    eq(get_state().mode, 'V')
    child.ensure_normal_mode()

    type_keys({ 'd', 't', 'e' })
    eq(get_state().mode, 'nov')
    child.lua('MiniJump.stop_jumping()')
  end)

  it('updates `jumping`', function()
    type_keys({ 'f', 'e' })
    eq(get_state().jumping, true)

    child.lua('MiniJump.stop_jumping()')
    eq(get_state().jumping, false)
  end)
end)

describe('MiniJump.jump()', function()
  before_each(function()
    child.setup()
    load_module()

    set_lines(example_lines)
    set_cursor(1, 0)
  end)

  local validate_jump = function(args, final_cursor_pos)
    -- Usage of string arguments is needed because there seems to be no way to
    -- correctly transfer to `child` `nil` values between non-`nil` onces. Like
    -- `child.lua('MiniJump.jump(...)', {'m', nil, true})`. Gives `Cannot
    -- convert given lua table` error.
    child.lua(('MiniJump.jump(%s)'):format(args))
    eq(get_cursor(), final_cursor_pos)
  end

  it('respects `target` argument', function()
    -- Can not jump by default without recent target
    assert.truthy(child.cmd_capture('lua MiniJump.jump()'):find('no recent `target`'))

    -- Jump to one letter target
    validate_jump([['m']], { 1, 4 })

    -- By default uses latest used value
    validate_jump('', { 1, 10 })

    -- Accepts more than one letter
    validate_jump([['sit']], { 1, 18 })

    -- Accepts non-letters
    validate_jump([['!']], { 4, 1 })
    validate_jump([['1']], { 4, 16 })
  end)

  it('respects `backward` argument', function()
    -- Jumps forward by default at first jump
    validate_jump([['d']], { 1, 12 })

    -- Can jump backward
    validate_jump([['m', true]], { 1, 10 })

    -- By default uses latest used value
    validate_jump([['m']], { 1, 4 })
  end)

  it('respects `till` argument', function()
    -- Jumps on target by default at first jump
    validate_jump([['m']], { 1, 4 })

    -- Can jump till
    validate_jump([['m', nil, true]], { 1, 9 })

    -- By default uses latest used value
    validate_jump([['m']], { 1, 22 })
  end)

  it('respects `n_times` argument', function()
    -- Jumps once by default at first jump
    validate_jump([['m']], { 1, 4 })

    -- Can jump multiple times
    validate_jump([['m', nil, nil, 2]], { 1, 23 })

    -- By default uses latest used value
    validate_jump([['m']], { 2, 46 })
  end)

  it('ignores matches with nothing before/after them `till=true`', function()
    set_lines({ 'abc', 'b', 'b', 'abc' })
    set_cursor(1, 2)

    validate_jump([['b', false, true, 1]], { 4, 0 })
    validate_jump([['b', true, true, 1]], { 1, 2 })
  end)

  it('does not jump if there is no place to jump', function()
    validate_jump([['x']], { 1, 0 })
  end)

  it('opens enough folds', function()
    set_lines({ 'a', 'b', 'c', 'd' })

    -- Manually create two nested closed folds
    set_cursor(3, 0)
    type_keys({ 'z', 'f', 'G' })
    type_keys({ 'z', 'f', 'g', 'g' })
    eq(child.fn.foldlevel(1), 1)
    eq(child.fn.foldlevel(3), 2)
    eq(child.fn.foldclosed(2), 1)
    eq(child.fn.foldclosed(3), 1)

    -- Jumping should open just enough folds
    set_cursor(1, 0)
    validate_jump([['b']], { 2, 0 })
    eq(child.fn.foldclosed(2), -1)
    eq(child.fn.foldclosed(3), 3)
  end)
end)

describe('MiniJump.smart_jump()', function()
  -- Most of testing is done in functional tests
  child.setup()
  load_module()
  set_lines(example_lines)

  it('works', function()
    child.lua_notify('MiniJump.smart_jump()')
    poke_eventloop()
    type_keys('m')
    eq(get_cursor(), { 1, 4 })
  end)
end)

-- Functional tests ===========================================================
describe('Jumping with f/t/F/T', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('works in Normal and Visual modes', function()
    local validate = function(key, positions)
      -- First time should jump and start "jumping" mode
      type_keys({ key, 'e' })
      eq(get_cursor(), positions[1])

      -- Typing same key should repeat jump
      type_keys({ key })
      eq(get_cursor(), positions[2])

      -- Prepending with `count` should work
      type_keys({ '2', key })
      eq(get_cursor(), positions[3])

      -- Typing same key should ignore previous `count`
      type_keys({ key })
      eq(get_cursor(), positions[4])
    end

    -- Having multiple lines also tests for jumping between lines
    set_lines({ '11e22e__', '33e44e__', '55e66e__' })

    local positions = {
      f = { { 1, 2 }, { 1, 5 }, { 2, 5 }, { 3, 2 } },
      t = { { 1, 1 }, { 1, 4 }, { 2, 4 }, { 3, 1 } },
      F = { { 3, 5 }, { 3, 2 }, { 2, 2 }, { 1, 5 } },
      T = { { 3, 6 }, { 3, 3 }, { 2, 3 }, { 1, 6 } },
    }

    for _, is_visual in ipairs({ false, true }) do
      for key, pos in pairs(positions) do
        local start_pos = key == key:lower() and { 1, 0 } or { 3, 7 }
        set_cursor(unpack(start_pos))

        if is_visual then
          type_keys('v')
          eq(child.fn.mode(), 'v')
        end

        validate(key, pos)
        child.ensure_normal_mode()
      end
    end
  end)

  it('works in Operator-pending mode', function()
    local validate = function(key, line_seq)
      -- Apply once
      type_keys({ 'd', key, 'e' })
      eq(get_lines(), { line_seq[1] })

      -- Prepending with `count` should work
      type_keys({ '2', 'd', key, 'e' })
      eq(get_lines(), { line_seq[2] })

      -- Another prepending with `count` should work
      type_keys({ 'd', '2', key, 'e' })
      eq(get_lines(), { line_seq[3] })

      -- Just typing `key` shouldn't repeat action
      local cur_pos = get_cursor()
      type_keys(key)
      eq(get_cursor(), cur_pos)
      -- Stop asking for user input
      type_keys('<Esc>')
    end

    local line_seq = {
      f = { '2e3e4e5e_ ', '4e5e_ ', '_ ' },
      t = { 'e2e3e4e5e_ ', 'e4e5e_ ', 'e_ ' },
      F = { ' 1e2e3e4e5', ' 1e2e3', ' 1' },
      T = { ' 1e2e3e4e5e', ' 1e2e3e', ' 1e' },
    }

    for key, seq in pairs(line_seq) do
      set_lines({ ' 1e2e3e4e5e_ ' })

      if key == key:lower() then
        set_cursor(1, 0)
      else
        set_cursor(1, 12)
      end

      validate(key, seq)
    end
  end)

  it('allows dot-repeat', function()
    local validate = function(key)
      -- Start with two equal lines (wth enough targets) to check equal effect
      local lines = get_lines()
      eq(lines[1], lines[2])
      local start_col = key == key:lower() and 0 or lines[1]:len()
      set_cursor(1, start_col)

      type_keys({ '2', 'd', key, 'e' })

      -- Immediate dot-repeat
      type_keys('.')

      -- Not immediate dot-repeat
      set_cursor(2, start_col)
      type_keys({ '.', '.' })

      -- Check equal effect
      lines = get_lines()
      eq(lines[1], lines[2])
    end

    for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
      set_lines({ ' 1e2e3e4e_ ', ' 1e2e3e4e_ ' })
      validate(key)
    end
  end)

  it('stops jumping when non-jump movement is done', function()
    set_lines({ 'TF', ' 1e2e3e ', 'ft' })

    -- General idea: move once, make non-jump movement 'l', test typing `key`
    -- twice. Can't test once because it should ask for user input and make an
    -- actual movement to `key` letter.
    set_cursor(2, 0)
    type_keys({ 'f', 'e', 'l', 'f', 'f' })
    eq(get_cursor(), { 3, 0 })

    set_cursor(2, 0)
    type_keys({ 't', 'e', 'l', 't', 't' })
    eq(get_cursor(), { 3, 0 })

    set_cursor(2, 7)
    type_keys({ 'F', 'e', 'l', 'F', 'F' })
    eq(get_cursor(), { 1, 1 })

    set_cursor(2, 7)
    type_keys({ 'T', 'e', 'l', 'T', 'T' })
    eq(get_cursor(), { 1, 1 })
  end)

  it('works with different mappings', function()
    for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
      child.api.nvim_del_keymap('n', key)
    end
    reload_module({ mappings = { forward = 'gf', backward = 'gF', forward_till = 'gt', backward_till = 'gT' } })
    set_lines({ ' 1e2e3e_ ' })

    set_cursor(1, 0)
    type_keys({ 'g', 'f', 'e' })
    eq(get_cursor(), { 1, 2 })

    set_cursor(1, 0)
    type_keys({ 'g', 't', 'e' })
    eq(get_cursor(), { 1, 1 })

    set_cursor(1, 8)
    type_keys({ 'g', 'F', 'e' })
    eq(get_cursor(), { 1, 6 })

    set_cursor(1, 8)
    type_keys({ 'g', 'T', 'e' })
    eq(get_cursor(), { 1, 7 })
  end)

  it('allows changing direction during jumping', function()
    set_lines({ ' 1e2e3e_ ' })

    -- After typing either one of ftFt, it should enter "jumping" mode, in
    -- which typing any of the five jump keys (including `;`) jumps around
    -- present targets.
    set_cursor(1, 0)
    type_keys({ 'f', 'e', 't' })
    eq(get_cursor(), { 1, 3 })

    set_cursor(1, 0)
    type_keys({ '2', 'f', 'e', 'F' })
    eq(get_cursor(), { 1, 2 })

    set_cursor(1, 8)
    type_keys({ 'F', 'e', 'T' })
    eq(get_cursor(), { 1, 5 })

    set_cursor(1, 8)
    type_keys({ '2', 'F', 'e', 't' })
    eq(get_cursor(), { 1, 5 })

    set_cursor(1, 0)
    type_keys({ 'f', 'e', 'f', 'T', 't', 'F' })
    eq(get_cursor(), { 1, 4 })
  end)

  it('enters jumping mode even if first jump is impossible', function()
    set_lines({ '1e2e3e' })
    set_cursor(1, 0)

    -- There is no target in backward direction...
    type_keys({ 'F', 'e' })

    -- ...but it still should enter jumping mode because target is present
    type_keys({ 'f', 'f' })
    eq(get_cursor(), { 1, 3 })
  end)

  it('does nothing if there is no place to jump', function()
    set_lines({ 'aaaaaaa' })

    for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
      local start_col = key == key:lower() and 0 or 6
      set_cursor(1, start_col)
      type_keys({ key, 'e' })
      -- It shouldn't move anywhere
      eq(get_cursor(), { 1, start_col })
      -- If implemented incorrectly, this can also fail because of consecutive
      -- tests for different letters. Ensure there is no jumping.
      child.lua('MiniJump.stop_jumping()')
    end
  end)

  it('stops prompting for target if hit `<Esc>` or `<C-c>`', function()
    local validate = function(key, test_key)
      set_lines({ 'abcd' })
      set_cursor(1, 0)
      -- Here 'o' should act just like Normal mode 'o'
      -- Wait after every key to poke eventloop
      type_keys({ key, test_key, 'o' }, 1)
      eq(get_lines(), { 'abcd', '' })

      -- Cleanup from Insert mode
      type_keys('<Esc>')
      -- Cleanup from possible entering jumping mode
      child.lua('MiniJump.stop_jumping()')
    end

    for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
      validate(key, '<Esc>')
      validate(key, '<C-c>')
    end
  end)

  it('ignores current position if it is acceptable target', function()
    set_lines({ 'xxxx' })

    set_cursor(1, 0)
    type_keys({ 'f', 'x' })
    eq(get_cursor(), { 1, 1 })

    set_cursor(1, 0)
    type_keys({ 't', 'x' })
    eq(get_cursor(), { 1, 1 })

    set_cursor(1, 3)
    type_keys({ 'F', 'x' })
    eq(get_cursor(), { 1, 2 })

    set_cursor(1, 3)
    type_keys({ 'T', 'x' })
    eq(get_cursor(), { 1, 2 })
  end)

  it('for t/T ignores matches with nothing before/after them', function()
    set_lines({ 'exx', 'e', 'e', 'xxe' })

    set_cursor(1, 1)
    type_keys({ 't', 'e' })
    eq(get_cursor(), { 4, 1 })

    set_cursor(4, 0)
    type_keys({ 'T', 'e' })
    eq(get_cursor(), { 1, 1 })
  end)

  it('asks for target letter after one idle second', function()
    local get_last_message = function()
      local messages = vim.split(child.cmd_capture('messages'), '\n')
      return messages[#messages]
    end

    set_cursor(1, 0)
    type_keys('f')
    poke_eventloop()
    eq(get_last_message(), '')
    sleep(1000 - 10)
    eq(get_last_message(), '')
    sleep(10)
    eq(get_last_message(), '(mini.jump) Enter target single character ')
  end)

  it('stops jumping if no target is found', function()
    set_lines('ooo')

    -- General idea: there was a bug which didn't reset jumping state if target
    -- was not found by `vim.fn.search()`. In that case, next typing of jumping
    -- key wouldn't make effect, but it should.
    for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
      local start_col = key == key:lower() and 0 or 3
      set_cursor(1, start_col)
      type_keys({ key, 'e', key, 'o' })
      eq(get_cursor(), { 1, 1 })
      -- Ensure no jumping mode
      child.lua('MiniJump.stop_jumping()')
    end
  end)

  it('jumps as far as it can with big `count`', function()
    set_lines({ ' 1e2e3e4e_ ' })

    set_cursor(1, 0)
    type_keys({ '1', '0', 'f', 'e' })
    eq(get_cursor(), { 1, 8 })

    set_cursor(1, 0)
    type_keys({ '1', '0', 't', 'e' })
    eq(get_cursor(), { 1, 7 })

    set_cursor(1, 10)
    type_keys({ '1', '0', 'F', 'e' })
    eq(get_cursor(), { 1, 2 })

    set_cursor(1, 10)
    type_keys({ '1', '0', 'T', 'e' })
    eq(get_cursor(), { 1, 3 })
  end)
end)

describe('Repeat jump with ;', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('works', function()
    set_lines({ ' 1e2e3e4e_ ' })

    set_cursor(1, 0)
    type_keys({ 'f', 'e', ';' })
    eq(get_cursor(), { 1, 4 })

    set_cursor(1, 0)
    type_keys({ 't', 'e', ';' })
    eq(get_cursor(), { 1, 3 })

    set_cursor(1, 10)
    type_keys({ 'F', 'e', ';' })
    eq(get_cursor(), { 1, 6 })

    set_cursor(1, 10)
    type_keys({ 'T', 'e', ';' })
    eq(get_cursor(), { 1, 7 })
  end)

  -- Other tests are done with 'f' in hope that others keys act the same
  it('works in Normal and Visual mode', function()
    set_lines({ '1e2e3e4e' })

    local validate = function()
      -- Repeats simple motion
      set_cursor(1, 0)
      type_keys({ 'f', 'e', ';' })
      eq(get_cursor(), { 1, 3 })

      -- Repeats not immediately
      set_cursor(1, 0)
      type_keys(';')
      eq(get_cursor(), { 1, 1 })

      -- Repeats with `count`
      set_cursor(1, 0)
      type_keys({ '2', 'f', 'e', ';' })
      eq(get_cursor(), { 1, 7 })
    end

    -- Normal mode
    eq(vim.fn.mode(), 'n')
    validate()

    -- Visual mode
    type_keys('v')
    eq(child.fn.mode(), 'v')
    validate()
    child.ensure_normal_mode()
  end)

  it('works in Operator-pending mode', function()
    -- It doesn't repeat actual operation, just performs same jump
    set_lines({ '1e2e3e4e5e' })
    set_cursor(1, 0)

    type_keys({ 'd', 'f', 'e', ';' })
    eq(get_lines(), { '2e3e4e5e' })
    eq(get_cursor(), { 1, 1 })

    -- It jumps preserving `count`
    set_lines({ '1e2e3e4e5e' })
    set_cursor(1, 0)

    type_keys({ 'd', '2', 'f', 'e', ';' })
    eq(get_lines(), { '3e4e5e' })
    eq(get_cursor(), { 1, 3 })
  end)

  it('works with different mapping', function()
    child.api.nvim_del_keymap('n', ';')
    reload_module({ mappings = { repeat_jump = 'g;' } })

    set_lines({ '1e2e' })
    type_keys({ 'f', 'e', 'g', ';' })
    eq(get_cursor(), { 1, 3 })
  end)

  it('works not immediately after failed first jump', function()
    set_lines({ 'aaa' })
    set_cursor(1, 0)
    type_keys({ 'f', 'e' })
    eq(get_cursor(), { 1, 0 })

    set_lines({ 'aaa', 'eee' })
    set_cursor(1, 0)
    type_keys(';')
    eq(get_cursor(), { 2, 0 })
  end)
end)

describe('Delayed highlighting', function()
  before_each(function()
    child.setup()
    load_module()
    set_lines({ '1e2e' })
  end)

  local validate_highlight = function(key, delay)
    local backward = ({ f = false, t = false, F = true, T = true })[key]
    local till = ({ f = false, t = true, F = false, T = true })[key]

    type_keys({ key, 'e' })
    eq(child.fn.getmatches(), {})
    sleep(delay - 10)
    eq(child.fn.getmatches(), {})
    sleep(10)
    eq(highlights_target('e', backward, till), true)
  end

  it('works', function()
    for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
      local start_col = key == key:lower() and 0 or 3
      set_cursor(1, start_col)
      validate_highlight(key, test_times.highlight)
      child.lua('MiniJump.stop_jumping()')
    end
  end)

  it('respects `config.delay.highlight`', function()
    reload_module({ delay = { highlight = 100 } })
    for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
      local start_col = key == key:lower() and 0 or 3
      set_cursor(1, start_col)
      validate_highlight(key, 100)
    end
  end)

  it('implements debounce-style delay', function()
    set_lines('1e2e3e')
    set_cursor(1, 0)
    type_keys({ 'f', 'e' })
    sleep(test_times.highlight - 10)
    eq(highlights_target('e', false, false), false)

    type_keys({ 'f' })
    sleep(test_times.highlight - 10)
    eq(highlights_target('e', false, false), false)
    sleep(10)
    eq(highlights_target('e', false, false), true)
  end)

  it('stops immediately when not jumping', function()
    type_keys({ 'f', 'e' })
    sleep(test_times.highlight)
    eq(highlights_target('e', false, false), true)
    type_keys('l')
    eq(highlights_target('e', false, false), false)
  end)

  it('updates immediately within same jumping', function()
    set_lines({ '1e2e', 'ee' })

    set_cursor(1, 0)
    type_keys({ 'f', 'e' })

    sleep(test_times.highlight)
    eq(highlights_target('e', false, false), true)
    type_keys({ 't' })
    eq(highlights_target('e', false, true), true)
    type_keys({ 'T' })
    eq(highlights_target('e', true, true), true)
  end)
end)

describe('Stop jumping after idle', function()
  local delay = test_times.highlight + 25

  before_each(function()
    child.setup()
    load_module({ delay = { idle_stop = delay } })
    set_lines({ '1e2e3e4e', 'ff' })
    set_cursor(1, 0)
  end)

  it('works', function()
    type_keys({ 'f', 'e' })
    eq(get_cursor(), { 1, 1 })

    -- It works
    sleep(delay - 10)
    type_keys('f')
    eq(get_cursor(), { 1, 3 })

    -- It implements debounce-style delay
    sleep(delay + 1)
    -- It should have stopped jumping and this should initiate new jump
    type_keys({ 'f', 'f' })
    eq(get_cursor(), { 2, 0 })
  end)

  it('works if should be done before target highlighting', function()
    reload_module({ delay = { idle_stop = test_times.highlight - 50 } })

    type_keys({ 'f', 'e' })
    eq(get_cursor(), { 1, 1 })
    sleep(test_times.highlight + 1)
    eq(highlights_target('e', false, false), false)
  end)
end)

child.stop()
