local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

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

-- Data =======================================================================
local example_lines = {
  'Lorem ipsum dolor sit amet,',
  'consectetur adipiscing elit, sed do eiusmod tempor',
  'incididunt ut labore et dolore magna aliqua.',
  '`!@#$%^&*()_+=.,1234567890',
}

local test_times = { highlight = 250 }

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
  eq(child.lua_get('type(_G.MiniJump)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniJump'), 1)

  -- Highlight groups
  expect.match(child.cmd_capture('hi MiniJump'), 'links to SpellRare')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniJump.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniJump.config.' .. field), value) end

  -- Check default values
  expect_config('delay.highlight', 250)
  expect_config('delay.idle_stop', 10000000)
  expect_config('mappings.forward', 'f')
  expect_config('mappings.backward', 'F')
  expect_config('mappings.forward_till', 't')
  expect_config('mappings.backward_till', 'T')
  expect_config('mappings.repeat_jump', ';')
  expect_config('silent', false)
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ delay = { highlight = 500 } })
  eq(child.lua_get('MiniJump.config.delay.highlight'), 500)
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ delay = 'a' }, 'delay', 'table')
  expect_config_error({ delay = { highlight = 'a' } }, 'delay.highlight', 'number')
  expect_config_error({ delay = { idle_stop = 'a' } }, 'delay.idle_stop', 'number')
  expect_config_error({ mappings = 'a' }, 'mappings', 'table')
  expect_config_error({ mappings = { forward = 1 } }, 'mappings.forward', 'string')
  expect_config_error({ mappings = { backward = 1 } }, 'mappings.backward', 'string')
  expect_config_error({ mappings = { forward_till = 1 } }, 'mappings.forward_till', 'string')
  expect_config_error({ mappings = { backward_till = 1 } }, 'mappings.backward_till', 'string')
  expect_config_error({ mappings = { repeat_jump = 1 } }, 'mappings.repeat_jump', 'string')
  expect_config_error({ silent = 1 }, 'silent', 'boolean')
end

T['setup()']['properly handles `config.mappings`'] = function()
  local has_map = function(lhs, pattern) return child.cmd_capture('nmap ' .. lhs):find(pattern) ~= nil end
  eq(has_map('f', 'Jump'), true)

  unload_module()
  child.api.nvim_del_keymap('n', 'f')

  -- Supplying empty string should mean "don't create keymap"
  load_module({ mappings = { forward = '' } })
  eq(has_map('f', 'Jump'), false)
end

T['state'] = new_set({
  hooks = {
    pre_case = function()
      child.lua('MiniJump.stop_jumping()')
      set_lines({ '1e2e3e4e' })
      set_cursor(1, 0)
    end,
  },
})

local get_state = function() return child.lua_get('MiniJump.state') end

T['state']['has correct initial values'] = function()
  eq(get_state(), {
    target = nil,
    backward = false,
    till = false,
    n_times = 1,
    mode = nil,
    jumping = false,
  })
end

T['state']['updates `target`'] = function()
  type_keys('f', 'e')
  eq(get_state().target, 'e')

  child.lua('MiniJump.stop_jumping()')
  child.lua([[MiniJump.jump('3e')]])
  eq(get_state().target, '3e')
end

T['state']['updates `backward`'] = function()
  set_cursor(1, 7)
  type_keys('F', 'e')
  eq(get_state().backward, true)

  type_keys('f')
  eq(get_state().backward, false)
end

T['state']['updates `till`'] = function()
  type_keys('t', 'e')
  eq(get_state().till, true)

  type_keys('f')
  eq(get_state().till, false)
end

T['state']['updates `n_times`'] = function()
  type_keys('2f', 'e')
  eq(get_state().n_times, 2)
end

T['state']['updates `mode`'] = function()
  type_keys('t', 'e')
  eq(get_state().mode, 'n')
  child.lua('MiniJump.stop_jumping()')

  type_keys('V', 't', 'e')
  eq(get_state().mode, 'V')
  child.ensure_normal_mode()

  type_keys('d', 't', 'e')
  eq(get_state().mode, 'nov')
  child.lua('MiniJump.stop_jumping()')
end

T['state']['updates `jumping`'] = function()
  type_keys('f', 'e')
  eq(get_state().jumping, true)

  child.lua('MiniJump.stop_jumping()')
  eq(get_state().jumping, false)
end

T['jump()'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines)
      set_cursor(1, 0)
    end,
  },
})

local validate_jump = function(args, final_cursor_pos)
  -- Usage of string arguments is needed because there seems to be no way to
  -- correctly transfer to `child` `nil` values between non-`nil` onces. Like
  -- `child.lua('MiniJump.jump(...)', {'m', nil, true})`. Gives `Cannot
  -- convert given lua table` error.
  child.lua(('MiniJump.jump(%s)'):format(args))
  eq(get_cursor(), final_cursor_pos)
end

T['jump()']['respects `target` argument'] = function()
  -- Can not jump by default without recent target
  expect.match(child.cmd_capture('lua MiniJump.jump()'), 'no recent `target`')

  -- Jump to one letter target
  validate_jump([['m']], { 1, 4 })

  -- By default uses latest used value
  validate_jump('', { 1, 10 })

  -- Accepts more than one letter
  validate_jump([['sit']], { 1, 18 })

  -- Accepts non-letters
  validate_jump([['!']], { 4, 1 })
  validate_jump([['1']], { 4, 16 })
end

T['jump()']['respects `backward` argument'] = function()
  -- Jumps forward by default at first jump
  validate_jump([['d']], { 1, 12 })

  -- Can jump backward
  validate_jump([['m', true]], { 1, 10 })

  -- By default uses latest used value
  validate_jump([['m']], { 1, 4 })
end

T['jump()']['respects `till` argument'] = function()
  -- Jumps on target by default at first jump
  validate_jump([['m']], { 1, 4 })

  -- Can jump till
  validate_jump([['m', nil, true]], { 1, 9 })

  -- By default uses latest used value
  validate_jump([['m']], { 1, 22 })
end

T['jump()']['respects `n_times` argument'] = function()
  -- Jumps once by default at first jump
  validate_jump([['m']], { 1, 4 })

  -- Can jump multiple times
  validate_jump([['m', nil, nil, 2]], { 1, 23 })

  -- By default uses latest used value
  validate_jump([['m']], { 2, 46 })
end

T['jump()']['allows matches at end of line when `till=true`'] = function()
  set_lines({ 'aaa', 'b', 'aaa' })

  local validate_t = function(start_pos, end_pos)
    set_cursor(unpack(start_pos))
    validate_jump([['b', false, true, 1]], end_pos)
  end
  local validate_T = function(start_pos, end_pos)
    set_cursor(unpack(start_pos))
    validate_jump([['b', true, true, 1]], end_pos)
  end

  -- Normal mode when not allowed to put cursor on end of line
  validate_t({ 1, 0 }, { 1, 2 })
  validate_T({ 3, 2 }, { 2, 0 })

  -- Visual mode (allowed to put cursor on end of line)
  type_keys('v')
  validate_t({ 1, 0 }, { 1, 3 })
  child.ensure_normal_mode()

  type_keys('v')
  validate_T({ 3, 2 }, { 2, 1 })
  child.ensure_normal_mode()

  -- Normal mode when allowed to put cursor on end of line
  child.o.virtualedit = 'onemore'
  validate_t({ 1, 0 }, { 1, 3 })
  validate_T({ 3, 2 }, { 2, 1 })
end

T['jump()']['does not jump if there is no place to jump'] = function() validate_jump([['x']], { 1, 0 }) end

T['jump()']['opens enough folds'] = function()
  set_lines({ 'a', 'b', 'c', 'd' })

  -- Manually create two nested closed folds
  set_cursor(3, 0)
  type_keys('zf', 'G')
  type_keys('zf', 'gg')
  eq(child.fn.foldlevel(1), 1)
  eq(child.fn.foldlevel(3), 2)
  eq(child.fn.foldclosed(2), 1)
  eq(child.fn.foldclosed(3), 1)

  -- Jumping should open just enough folds
  set_cursor(1, 0)
  validate_jump([['b']], { 2, 0 })
  eq(child.fn.foldclosed(2), -1)
  eq(child.fn.foldclosed(3), 3)
end

T['smart_jump()'] = new_set({
  hooks = {
    pre_case = function() set_lines(example_lines) end,
  },
})

T['smart_jump()']['works'] = function()
  child.lua_notify('MiniJump.smart_jump()')
  poke_eventloop()
  type_keys('m')
  eq(get_cursor(), { 1, 4 })
end

-- Integration tests ==========================================================
T['Jumping with f/t/F/T'] = new_set()

T['Jumping with f/t/F/T']['works in Normal and Visual modes'] = new_set({
  parametrize = {
    { 'Normal', 'f', { { 1, 2 }, { 1, 5 }, { 2, 5 }, { 3, 2 } } },
    { 'Normal', 't', { { 1, 1 }, { 1, 4 }, { 2, 4 }, { 3, 1 } } },
    { 'Normal', 'F', { { 3, 5 }, { 3, 2 }, { 2, 2 }, { 1, 5 } } },
    { 'Normal', 'T', { { 3, 6 }, { 3, 3 }, { 2, 3 }, { 1, 6 } } },

    { 'Visual', 'f', { { 1, 2 }, { 1, 5 }, { 2, 5 }, { 3, 2 } } },
    { 'Visual', 't', { { 1, 1 }, { 1, 4 }, { 2, 4 }, { 3, 1 } } },
    { 'Visual', 'F', { { 3, 5 }, { 3, 2 }, { 2, 2 }, { 1, 5 } } },
    { 'Visual', 'T', { { 3, 6 }, { 3, 3 }, { 2, 3 }, { 1, 6 } } },
  },
}, {
  test = function(test_mode, key, positions)
    set_lines({ '11e22e__', '33e44e__', '55e66e__' })

    local start_pos = key == key:lower() and { 1, 0 } or { 3, 7 }
    set_cursor(unpack(start_pos))

    if test_mode == 'Visual' then
      type_keys('v')
      eq(child.fn.mode(), 'v')
    end

    -- First time should jump and start "jumping" mode
    type_keys(key, 'e')
    eq(get_cursor(), positions[1])

    -- Typing same key should repeat jump
    type_keys(key)
    eq(get_cursor(), positions[2])

    -- Prepending with `count` should work
    type_keys('2', key)
    eq(get_cursor(), positions[3])

    -- Typing same key should ignore previous `count`
    type_keys(key)
    eq(get_cursor(), positions[4])
  end,
})

-- NOTE: for some reason it seems to be very important to do cases for
-- Operator-pending mode in parametrized form, because this way child process
-- is restarted every time. Otherwise it will lead to hanging process somewhere.
T['Jumping with f/t/F/T']['works in Operator-pending mode'] = new_set({
  parametrize = {
    { 'f', { '2e3e4e5e_ ', '4e5e_ ', '_ ' } },
    { 't', { 'e2e3e4e5e_ ', 'e4e5e_ ', 'e_ ' } },
    { 'F', { ' 1e2e3e4e5', ' 1e2e3', ' 1' } },
    { 'T', { ' 1e2e3e4e5e', ' 1e2e3e', ' 1e' } },
  },
}, {
  test = function(key, line_seq)
    set_lines({ ' 1e2e3e4e5e_ ' })

    if key == key:lower() then
      set_cursor(1, 0)
    else
      set_cursor(1, 12)
    end

    -- Apply once
    type_keys('d', key, 'e')
    eq(get_lines(), { line_seq[1] })

    -- Prepending with `count` should work
    type_keys('2d', key, 'e')
    eq(get_lines(), { line_seq[2] })

    -- Another prepending with `count` should work
    type_keys('d', '2', key, 'e')
    eq(get_lines(), { line_seq[3] })

    -- Just typing `key` shouldn't repeat action
    local cur_pos = get_cursor()
    type_keys(key)
    eq(get_cursor(), cur_pos)
    -- Stop asking for user input
    type_keys('<Esc>')
  end,
})

T['Jumping with f/t/F/T']['allows dot-repeat'] = new_set({
  parametrize = { { 'f' }, { 't' }, { 'F' }, { 'T' } },
}, {
  test = function(key)
    -- Start with two equal lines (with enough targets) to check equal effect
    set_lines({ ' 1e2e3e4e_ ', ' 1e2e3e4e_ ' })

    local lines = get_lines()
    local start_col = key == key:lower() and 0 or lines[1]:len()
    set_cursor(1, start_col)

    type_keys('2d', key, 'e')

    -- Immediate dot-repeat
    type_keys('.')

    -- Not immediate dot-repeat
    set_cursor(2, start_col)
    type_keys('.', '.')

    -- Check equal effect
    lines = get_lines()
    eq(lines[1], lines[2])
  end,
})

T['Jumping with f/t/F/T']['stops jumping when non-jump movement is done'] = function()
  set_lines({ 'TF', ' 1e2e3e ', 'ft' })

  -- General idea: move once, make non-jump movement 'l', test typing `key`
  -- twice. Can't test once because it should ask for user input and make an
  -- actual movement to `key` letter.
  set_cursor(2, 0)
  type_keys('f', 'e', 'l', 'f', 'f')
  eq(get_cursor(), { 3, 0 })

  set_cursor(2, 0)
  type_keys('t', 'e', 'l', 't', 't')
  eq(get_cursor(), { 3, 0 })

  set_cursor(2, 7)
  type_keys('F', 'e', 'l', 'F', 'F')
  eq(get_cursor(), { 1, 1 })

  set_cursor(2, 7)
  type_keys('T', 'e', 'l', 'T', 'T')
  eq(get_cursor(), { 1, 1 })
end

T['Jumping with f/t/F/T']['works with different mappings'] = function()
  for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
    child.api.nvim_del_keymap('n', key)
  end
  reload_module({ mappings = { forward = 'gf', backward = 'gF', forward_till = 'gt', backward_till = 'gT' } })
  set_lines({ ' 1e2e3e_ ' })

  set_cursor(1, 0)
  type_keys('gf', 'e')
  eq(get_cursor(), { 1, 2 })

  set_cursor(1, 0)
  type_keys('gt', 'e')
  eq(get_cursor(), { 1, 1 })

  set_cursor(1, 8)
  type_keys('gF', 'e')
  eq(get_cursor(), { 1, 6 })

  set_cursor(1, 8)
  type_keys('gT', 'e')
  eq(get_cursor(), { 1, 7 })
end

T['Jumping with f/t/F/T']['allows changing direction during jumping'] = function()
  set_lines({ ' 1e2e3e_ ' })

  -- After typing either one of ftFt, it should enter "jumping" mode, in
  -- which typing any of the five jump keys (including `;`) jumps around
  -- present targets.
  set_cursor(1, 0)
  type_keys('f', 'e', 't')
  eq(get_cursor(), { 1, 3 })

  set_cursor(1, 0)
  type_keys('2f', 'e', 'F')
  eq(get_cursor(), { 1, 2 })

  set_cursor(1, 8)
  type_keys('F', 'e', 'T')
  eq(get_cursor(), { 1, 5 })

  set_cursor(1, 8)
  type_keys('2F', 'e', 't')
  eq(get_cursor(), { 1, 5 })

  set_cursor(1, 0)
  type_keys('f', 'e', 'f', 'T', 't', 'F')
  eq(get_cursor(), { 1, 4 })
end

T['Jumping with f/t/F/T']['enters jumping mode even if first jump is impossible'] = function()
  set_lines({ '1e2e3e' })
  set_cursor(1, 0)

  -- There is no target in backward direction...
  type_keys('F', 'e')

  -- ...but it still should enter jumping mode because target is present
  type_keys('f', 'f')
  eq(get_cursor(), { 1, 3 })
end

T['Jumping with f/t/F/T']['does nothing if there is no place to jump'] = function()
  set_lines({ 'aaaaaaa' })

  for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
    local start_col = key == key:lower() and 0 or 6
    set_cursor(1, start_col)
    type_keys(key, 'e')
    -- It shouldn't move anywhere
    eq(get_cursor(), { 1, start_col })
    -- If implemented incorrectly, this can also fail because of consecutive
    -- tests for different letters. Ensure there is no jumping.
    child.lua('MiniJump.stop_jumping()')
  end
end

T['Jumping with f/t/F/T']['stops prompting for target if hit `<Esc>` or `<C-c>`'] = new_set({
  parametrize = {
    { 'f', '<Esc>' },
    { 't', '<Esc>' },
    { 'F', '<Esc>' },
    { 'T', '<Esc>' },
    { 'f', '<C-c>' },
    { 't', '<C-c>' },
    { 'F', '<C-c>' },
    { 'T', '<C-c>' },
  },
}, {
  test = function(key, test_key)
    set_lines({ 'oooo' })
    set_cursor(1, 0)
    -- Here 'o' should act just like Normal mode 'o'
    -- Wait after every key to poke eventloop
    type_keys(1, key, test_key, 'o')
    eq(get_lines(), { 'oooo', '' })

    child.ensure_normal_mode()

    -- Should also work in Operator-pending mode
    set_lines({ 'oooo' })
    set_cursor(1, 0)
    type_keys(1, 'd', key, test_key, 'o')
    eq(get_lines(), { 'oooo', '' })
  end,
})

T['Jumping with f/t/F/T']['ignores current position if it is acceptable target'] = new_set({
  parametrize = { { 'f' }, { 't' }, { 'F' }, { 'T' } },
}, {
  test = function(key)
    set_lines({ 'xxxx' })
    local start_col, finish_col = 0, 1
    if key ~= key:lower() then
      start_col, finish_col = 3, 2
    end
    set_cursor(1, start_col)

    type_keys(key, 'x')
    eq(get_cursor(), { 1, finish_col })
  end,
})

T['Jumping with f/t/F/T']['for t/T allows matches on end of line'] = function()
  set_lines({ 'aaa', 'b', 'aaa' })

  local validate_t = function(start_pos, end_pos)
    set_cursor(unpack(start_pos))
    type_keys('t', 'b')
    eq(get_cursor(), end_pos)
  end
  local validate_T = function(start_pos, end_pos)
    set_cursor(unpack(start_pos))
    type_keys('T', 'b')
    eq(get_cursor(), end_pos)
  end

  -- Normal mode when not allowed to put cursor on end of line
  validate_t({ 1, 0 }, { 1, 2 })
  validate_T({ 3, 2 }, { 2, 0 })

  -- Visual mode (allowed to put cursor on end of line)
  type_keys('v')
  validate_t({ 1, 0 }, { 1, 3 })
  child.ensure_normal_mode()

  type_keys('v')
  validate_T({ 3, 2 }, { 2, 1 })
  child.ensure_normal_mode()

  -- Normal mode when allowed to put cursor on end of line
  child.o.virtualedit = 'onemore'
  validate_t({ 1, 0 }, { 1, 3 })
  validate_T({ 3, 2 }, { 2, 1 })
end

T['Jumping with f/t/F/T']['shows helper message after one idle second'] = function()
  child.set_size(10, 40)

  -- Execute one time to test if 'needs help message' flag is set per call
  set_lines(example_lines)
  set_cursor(1, 0)
  type_keys('f', 'e')
  sleep(200)

  -- Start another jump
  type_keys('h', 'f')
  sleep(1000)
  -- Should show colored helper message without adding it to `:messages` and
  -- causing hit-enter-prompt
  child.expect_screenshot()
  eq(child.cmd_capture('1messages'), '')

  -- Should clean command line after starting jumping
  type_keys('m')
  child.expect_screenshot()
end

T['Jumping with f/t/F/T']['stops jumping if no target is found'] = function()
  set_lines('ooo')

  -- General idea: there was a bug which didn't reset jumping state if target
  -- was not found by `vim.fn.search()`. In that case, next typing of jumping
  -- key wouldn't make effect, but it should.
  for _, key in ipairs({ 'f', 't', 'F', 'T' }) do
    local start_col = key == key:lower() and 0 or 3
    set_cursor(1, start_col)
    type_keys(key, 'e', key, 'o')
    eq(get_cursor(), { 1, 1 })
    -- Ensure no jumping mode
    child.lua('MiniJump.stop_jumping()')
  end
end

T['Jumping with f/t/F/T']['jumps as far as it can with big `count`'] = function()
  set_lines({ ' 1e2e3e4e_ ' })

  set_cursor(1, 0)
  type_keys('10f', 'e')
  eq(get_cursor(), { 1, 8 })

  set_cursor(1, 0)
  type_keys('10t', 'e')
  eq(get_cursor(), { 1, 7 })

  set_cursor(1, 10)
  type_keys('10F', 'e')
  eq(get_cursor(), { 1, 2 })

  set_cursor(1, 10)
  type_keys('10T', 'e')
  eq(get_cursor(), { 1, 3 })
end

T['Jumping with f/t/F/T']['respects `vim.{g,b}.minijump_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minijump_disable = true
    set_lines({ '1e2e3e4e' })
    set_cursor(1, 0)
    type_keys('f', 'e')
    -- `f` does nothing, while `e` jumps to end of word (otherwise it would
    -- have been `{1, 1}`)
    eq(get_cursor(), { 1, 7 })
  end,
})

T['Jumping with f/t/F/T']['respects `config.silent`'] = function()
  child.lua('MiniJump.config.silent = true')
  child.set_size(10, 20)

  -- Execute one time to test if 'needs help message' flag is set per call
  set_lines({ '1e2e3e4e' })
  set_cursor(1, 0)
  type_keys('f')
  sleep(1000 + 15)

  -- Should not show helper message
  child.expect_screenshot()
end

T['Jumping with f/t/F/T']["respects 'ignorecase'"] = function()
  child.o.ignorecase = true
  set_lines({ ' 1e2E3E4e_ ' })

  set_cursor(1, 0)
  type_keys('2f', 'E')
  eq(get_cursor(), { 1, 4 })

  set_cursor(1, 0)
  type_keys('2t', 'E')
  eq(get_cursor(), { 1, 3 })

  set_cursor(1, 10)
  type_keys('2F', 'E')
  eq(get_cursor(), { 1, 6 })

  set_cursor(1, 10)
  type_keys('2T', 'E')
  eq(get_cursor(), { 1, 7 })
end

T['Jumping with f/t/F/T']["respects 'smartcase'"] = function()
  child.o.ignorecase = true
  child.o.smartcase = true
  set_lines({ ' 1e2E3E4e_ ' })

  set_cursor(1, 0)
  type_keys('2f', 'E')
  eq(get_cursor(), { 1, 6 })

  set_cursor(1, 0)
  type_keys('2t', 'E')
  eq(get_cursor(), { 1, 5 })

  set_cursor(1, 10)
  type_keys('2F', 'E')
  eq(get_cursor(), { 1, 4 })

  set_cursor(1, 10)
  type_keys('2T', 'E')
  eq(get_cursor(), { 1, 5 })
end

T['Jumping with f/t/F/T']["respects 'selection=exclusive'"] = function()
  child.o.selection = 'exclusive'
  set_lines({ ' 1e2e' })

  set_cursor(1, 0)
  type_keys('v', 'f', 'e')
  eq({ child.fn.col('v'), child.fn.col('.') }, { 1, 4 })

  type_keys('d')
  eq(get_lines(), { '2e' })
end

T['Jumping with f/t/F/T']['can be used with `:normal-range`'] = function()
  -- Basically, it should check that jumping state is restarted even outside of
  -- `CursorMoved` event (which is not issued in this case)
  set_lines({ '11e22e', '11e22e', '11e22e' })
  set_cursor(1, 0)
  type_keys('vip', ':normal fefx<CR>')
  eq(get_lines(), { '11e22', '11e22', '11e22' })
end

T['Repeat jump with ;'] = new_set()

T['Repeat jump with ;']['works'] = function()
  set_lines({ ' 1e2e3e4e_ ' })

  set_cursor(1, 0)
  type_keys('f', 'e', ';')
  eq(get_cursor(), { 1, 4 })

  set_cursor(1, 0)
  type_keys('t', 'e', ';')
  eq(get_cursor(), { 1, 3 })

  set_cursor(1, 10)
  type_keys('F', 'e', ';')
  eq(get_cursor(), { 1, 6 })

  set_cursor(1, 10)
  type_keys('T', 'e', ';')
  eq(get_cursor(), { 1, 7 })
end

-- Other tests are done with 'f' in hope that others keys act the same
T['Repeat jump with ;']['works in Normal and Visual mode'] = new_set({
  parametrize = { { 'Normal' }, { 'Visual' } },
}, {
  test = function(test_mode)
    set_lines({ '1e2e3e4e' })

    if test_mode == 'Visual' then
      type_keys('v')
      eq(child.fn.mode(), 'v')
    end

    -- Repeats simple motion
    set_cursor(1, 0)
    type_keys('f', 'e', ';')
    eq(get_cursor(), { 1, 3 })

    -- Repeats not immediately
    set_cursor(1, 0)
    type_keys(';')
    eq(get_cursor(), { 1, 1 })

    -- Repeats with `count`
    set_cursor(1, 0)
    type_keys('2f', 'e', ';')
    eq(get_cursor(), { 1, 7 })
  end,
})

T['Repeat jump with ;']['works after jump in Operator-pending mode'] = function()
  -- It doesn't repeat actual operation, just performs same jump
  set_lines({ '1e2e3e4e5e' })
  set_cursor(1, 0)

  type_keys('d', 'f', 'e', ';')
  eq(get_lines(), { '2e3e4e5e' })
  eq(get_cursor(), { 1, 1 })

  -- It jumps preserving `count`
  set_lines({ '1e2e3e4e5e' })
  set_cursor(1, 0)

  type_keys('d', '2f', 'e', ';')
  eq(get_lines(), { '3e4e5e' })
  eq(get_cursor(), { 1, 3 })
end

T['Repeat jump with ;']['works in Operator-pending mode'] = function()
  set_lines({ '1e2e3e4e5e' })
  set_cursor(1, 0)

  -- Should repeat without asking for target
  type_keys('f', 'e', 'd', ';')
  eq(get_lines(), { '13e4e5e' })
  eq(get_cursor(), { 1, 1 })
end

T['Repeat jump with ;']['works with different mapping'] = function()
  child.api.nvim_del_keymap('n', ';')
  reload_module({ mappings = { repeat_jump = 'g;' } })

  set_lines({ '1e2e' })
  type_keys('f', 'e', 'g;')
  eq(get_cursor(), { 1, 3 })
end

T['Repeat jump with ;']['works not immediately after failed first jump'] = function()
  set_lines({ 'aaa' })
  set_cursor(1, 0)
  type_keys('f', 'e')
  eq(get_cursor(), { 1, 0 })

  set_lines({ 'aaa', 'eee' })
  set_cursor(1, 0)
  type_keys(';')
  eq(get_cursor(), { 2, 0 })
end

T['Repeat jump with ;']['respects `vim.{g,b}.minijump_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    set_lines({ '1e2e3e4e' })
    set_cursor(1, 0)
    type_keys('f', 'e')

    child[var_type].minijump_disable = true
    type_keys(';')
    eq(get_cursor(), { 1, 1 })
  end,
})

T['Delayed highlighting'] = new_set({
  hooks = {
    pre_case = function()
      set_lines({ '1e2e', 'e4e5e_' })
      child.set_size(5, 12)
    end,
  },
})

-- NOTE: Don't use `'f', 't', 'F', 'T'` as parameters because this will lead to
-- conflicting file names for reference screenshots in case-insensitive OS
T['Delayed highlighting']['works'] = new_set(
  { parametrize = { { 'forward' }, { 'forward_till' }, { 'backward' }, { 'backward_till' } } },
  {
    test = function(direction)
      local key = vim.endswith(direction, '_till') and 't' or 'f'
      key = vim.startswith(direction, 'backward') and key:upper() or key

      set_cursor(1, key == key:lower() and 0 or 3)
      type_keys(key, 'e')

      sleep(test_times.highlight - 10)
      -- Nothing should yet be shown
      child.expect_screenshot()
      sleep(10)
      -- Everything should be shown
      child.expect_screenshot()
    end,
  }
)

T['Delayed highlighting']['respects `config.delay.highlight`'] = new_set(
  { parametrize = { { 'forward' }, { 'forward_till' }, { 'backward' }, { 'backward_till' } } },
  {
    test = function(direction)
      local key = vim.endswith(direction, '_till') and 't' or 'f'
      key = vim.startswith(direction, 'backward') and key:upper() or key

      child.lua('MiniJump.config.delay.highlight = 100')

      set_cursor(1, key == key:lower() and 0 or 3)
      type_keys(key, 'e')

      sleep(100 - 10)
      -- Nothing should yet be shown
      child.expect_screenshot()
      sleep(10)
      -- Everything should be shown
      child.expect_screenshot()
    end,
  }
)

T['Delayed highlighting']['respects `vim.b.minijump_config`'] = function()
  child.lua('MiniJump.config.delay.highlight = 100')
  child.b.minijump_config = { delay = { highlight = 50 } }

  set_cursor(1, 0)
  type_keys('f', 'e')

  sleep(50 - 10)
  -- Nothing should yet be shown
  child.expect_screenshot()
  sleep(10)
  -- Everything should be shown
  child.expect_screenshot()
end

T['Delayed highlighting']['implements debounce-style delay'] = function()
  set_lines('1e2e3e')
  set_cursor(1, 0)

  type_keys('f', 'e')
  sleep(test_times.highlight - 10)
  -- Nothing should yet be shown
  child.expect_screenshot()

  type_keys('f')
  sleep(test_times.highlight - 10)
  -- Nothing should yet be shown (because debounce-style)
  child.expect_screenshot()

  sleep(10)
  -- Nothing should yet be shown
  child.expect_screenshot()
end

T['Delayed highlighting']['stops immediately when not jumping'] = function()
  type_keys('f', 'e')
  sleep(test_times.highlight)
  -- Should be highlighted
  child.expect_screenshot()

  type_keys('l')
  -- Should stop highlighting immediately
  child.expect_screenshot()
end

T['Delayed highlighting']['updates immediately within same jumping'] = function()
  set_lines({ 'e1e2', 'ee' })

  set_cursor(1, 0)
  type_keys('f', 'e')

  sleep(test_times.highlight)
  child.expect_screenshot()
  type_keys('t')
  child.expect_screenshot()
  type_keys('T')
  -- Last `T` match is highlighted because there is an end of line after it
  child.expect_screenshot()
end

T['Delayed highlighting']['never highlights in Insert mode'] = function()
  child.set_size(5, 15)

  set_lines({ '1e2f' })

  set_cursor(1, 0)
  type_keys('f', 'e')

  sleep(test_times.highlight)
  child.expect_screenshot()

  type_keys('ct', 'f')
  sleep(test_times.highlight + 10)
  -- Shouldn't start highlighting
  child.expect_screenshot()
end

T['Delayed highlighting']["respects 'ignorecase'"] = function()
  child.o.ignorecase = true
  set_lines({ '1e2E' })

  set_cursor(1, 0)
  type_keys('f', 'e')

  sleep(test_times.highlight)
  -- Should highlight both 'e'and 'E'
  child.expect_screenshot()
end

T['Delayed highlighting']["respects 'smartcase'"] = function()
  child.o.ignorecase = true
  child.o.smartcase = true
  set_lines({ '1e2E3e4E' })

  set_cursor(1, 0)
  type_keys('f', 'E')

  sleep(test_times.highlight)
  -- Should highlight only 'E'
  child.expect_screenshot()
end

local delay = test_times.highlight + 25

T['Stop jumping after idle'] = new_set({
  hooks = {
    pre_case = function()
      child.lua('MiniJump.config.delay.idle_stop = ' .. delay)
      set_lines({ '1e2e3e4e', 'ff' })
      set_cursor(1, 0)
      child.set_size(5, 12)
    end,
  },
})

T['Stop jumping after idle']['works'] = function()
  type_keys('f', 'e')
  eq(get_cursor(), { 1, 1 })

  -- It works
  sleep(delay - 10)
  type_keys('f')
  eq(get_cursor(), { 1, 3 })
  -- Should highlight
  child.expect_screenshot()

  -- It implements debounce-style delay
  sleep(delay + 1)
  -- It should have stopped jumping and this should initiate new jump
  type_keys('f', 'f')
  eq(get_cursor(), { 2, 0 })
  -- Should also stop highlighting
  child.expect_screenshot()
end

T['Stop jumping after idle']['works if should be done before target highlighting'] = function()
  child.lua('MiniJump.config.delay.idle_stop = ' .. test_times.highlight - 50)

  type_keys('f', 'e')
  eq(get_cursor(), { 1, 1 })
  sleep(test_times.highlight + 1)
  -- Should also not trigger highlighting
  child.expect_screenshot()
end

T['Stop jumping after idle']['respects `vim.b.minijump_config`'] = function()
  child.b.minijump_config = { delay = { idle_stop = 50 } }
  type_keys('f', 'e')
  sleep(50)

  -- It should have stopped jumping and this should initiate new jump
  type_keys('f', 'f')
  eq(get_cursor(), { 2, 0 })
end

return T
