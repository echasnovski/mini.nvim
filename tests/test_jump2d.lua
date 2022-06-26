local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('jump2d', config) end
local unload_module = function() child.mini_unload('jump2d') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local poke_eventloop = function() child.api.nvim_eval('1') end
local sleep = function(ms) vim.loop.sleep(ms); poke_eventloop() end
local get_latest_message = function() return child.cmd_capture('1messages') end
--stylua: ignore end

-- Make helpers
-- Work with extmarks
--- Get raw extmarks
---@private
local get_extmarks_raw = function()
  local ns_id = child.api.nvim_get_namespaces()['MiniJump2dSpots']
  local win_id_arr = child.api.nvim_list_wins()
  local res = {}
  for _, win_id in ipairs(win_id_arr) do
    local buf_id = child.api.nvim_win_get_buf(win_id)
    res[win_id] = child.api.nvim_buf_get_extmarks(buf_id, ns_id, 0, -1, { details = true })
  end

  return res
end

--- Get single array of 'MiniJump2dSpots' extmarks
---@private
local get_extmarks = function()
  local raw_extmarks = get_extmarks_raw()

  -- Flatten data structure to be a single array
  local res = {}
  for win_id, extmarks in pairs(raw_extmarks) do
    for _, e_mark in ipairs(extmarks) do
      -- Elements of extmarks: [id, row, col, details]
      local virt_text = e_mark[4].virt_text[1]
      table.insert(res, { win_id = win_id, line = e_mark[2], col = e_mark[3], text = virt_text[1], hl = virt_text[2] })
    end
  end

  -- Ensure order
  --stylua: ignore
  table.sort(res, function(a, b)
    if a.win_id < b.win_id then return true end
    if a.win_id > b.win_id then return false end

    if a.line < b.line then return true end
    if a.line > b.line then return false end

    return a.col < b.col
  end)

  return res
end

local get_extmarks_short = function()
  return vim.tbl_map(function(x)
    return { x.col, x.text }
  end, get_extmarks())
end

--- Convert {{col = 1, text = 'aa'}, {col = 5, text = 'bbb'}} to ' aa  bbb'
---@private
local text_tbl_to_line = function(text_tbl)
  local tbl = {}
  local cur_right_col = 0
  for _, cur_text in ipairs(text_tbl) do
    -- NOTE: this works only in absence of multibyte characters
    table.insert(tbl, (' '):rep(cur_text.col - cur_right_col))
    table.insert(tbl, cur_text.text)
    cur_right_col = cur_text.col + cur_text.text:len()
  end
  return table.concat(tbl, '')
end

--- Get extmark labels in form of lines
---
---@return table Table with fields being window number and elements -
---   consecutive array with lines from "extmark layer" (if line doesn't have
---   an extmark, it is empty; including "trailing empty lines").
---@private
local get_extmark_lines = function()
  -- Use `get_extmarks()` because it ensures order (not fixed from Neovim side)
  local extmarks = get_extmarks()

  -- Group per 'win_id - line'
  local win_line_tables = {}
  for _, e_mark in ipairs(extmarks) do
    local win_id, line = e_mark.win_id, e_mark.line
    local win_tbl = win_line_tables[win_id] or {}
    local line_tbl = win_tbl[line] or {}
    table.insert(line_tbl, { col = e_mark.col, text = e_mark.text })
    win_tbl[line] = line_tbl
    win_line_tables[win_id] = win_tbl
  end

  -- Add possibly missing windows (in case there is no extmarks)
  local win_id_arr = child.api.nvim_list_wins()
  for _, win_id in ipairs(win_id_arr) do
    win_line_tables[win_id] = win_line_tables[win_id] or {}
  end

  -- Transform tables into lines
  local raw_lines = {}
  for win_id, win_table in pairs(win_line_tables) do
    local raw_win_lines = {}
    for line_num, text_tbl in pairs(win_table) do
      -- Fill in empty lines
      -- NOTE: make line numbers 1-based
      for i = #raw_win_lines + 1, line_num do
        raw_win_lines[i] = ''
      end
      raw_win_lines[line_num + 1] = text_tbl_to_line(text_tbl)
    end

    -- Add "trailing" empty lines for consistency
    local buf_id = child.api.nvim_win_get_buf(win_id)
    local n_lines = child.api.nvim_buf_line_count(buf_id)
    for i = #raw_win_lines + 1, n_lines do
      raw_win_lines[i] = ''
    end
    raw_lines[win_id] = raw_win_lines
  end
  return raw_lines
end

local get_extmark_lines_curwin = function()
  return get_extmark_lines()[child.api.nvim_get_current_win()]
end

-- Window setups
local setup_windows = function()
  child.cmd('%bwipeout!')

  -- Current tabpage. Create four windows.
  local win_topleft = child.api.nvim_get_current_win()

  child.cmd('rightbelow split')
  local win_bottomleft = child.api.nvim_get_current_win()

  child.api.nvim_set_current_win(win_topleft)
  child.cmd('rightbelow vsplit')
  local win_topright = child.api.nvim_get_current_win()

  child.api.nvim_set_current_win(win_bottomleft)
  child.cmd('rightbelow vsplit')
  local win_bottomright = child.api.nvim_get_current_win()

  -- Other tabpage
  child.cmd('tabedit')
  local win_other_tabpage = child.api.nvim_get_current_win()

  -- Construct window table
  child.api.nvim_set_current_win(win_topleft)
  local wins = {
    topleft = win_topleft,
    bottomleft = win_bottomleft,
    topright = win_topright,
    bottomright = win_bottomright,
    other_tabpage = win_other_tabpage,
  }

  -- Ensure different buffers with default text
  local bufs = {}
  for name, win_id in pairs(wins) do
    local buf_id = child.api.nvim_create_buf(true, false)
    child.api.nvim_win_set_buf(win_id, buf_id)
    child.api.nvim_buf_set_lines(buf_id, 0, -1, true, { 'aaaa' })

    bufs[name] = buf_id
  end

  return wins, bufs
end

local setup_two_windows = function()
  child.cmd('%bwipeout!')

  local win_left = child.api.nvim_get_current_win()
  child.cmd('rightbelow vsplit aaa')
  local win_right = child.api.nvim_get_current_win()

  child.api.nvim_set_current_win(win_left)
  local wins = { left = win_left, right = win_right }

  local bufs = {}
  for name, win_id in pairs(wins) do
    local buf_id = child.api.nvim_create_buf(true, false)
    child.api.nvim_buf_set_lines(buf_id, 0, -1, true, { 'aaaa', 'aaaa', 'aaaa' })
    child.api.nvim_win_set_buf(win_id, buf_id)
    child.api.nvim_win_set_cursor(win_id, { 2, 0 })

    bufs[name] = buf_id
  end

  return wins, bufs
end

-- Output test set ============================================================
T = new_set({
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
  eq(child.lua_get('type(_G.MiniJump2d)'), 'table')

  -- Autocommand group (with default config)
  eq(child.fn.exists('#MiniJump2d'), 1)

  -- Highlight groups, depending on background
  child.o.background = 'dark'
  reload_module()
  expect.match(child.cmd_capture('hi MiniJump2dSpot'), 'gui=bold,nocombine guifg=[Ww]hite guibg=[Bb]lack')

  child.cmd('hi clear MiniJump2dSpot')

  child.o.background = 'light'
  reload_module()
  expect.match(child.cmd_capture('hi MiniJump2dSpot'), 'gui=bold,nocombine guifg=[Bb]lack guibg=[Ww]hite')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniJump2d.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value)
    eq(child.lua_get('MiniJump2d.config.' .. field), value)
  end

  expect_config('spotter', vim.NIL)
  expect_config('labels', 'abcdefghijklmnopqrstuvwxyz')
  expect_config(
    'allowed_lines',
    { blank = true, cursor_before = true, cursor_at = true, cursor_after = true, fold = true }
  )
  expect_config('allowed_windows', { current = true, not_current = true })
  expect_config('hooks', { before_start = nil, after_jump = nil })
  expect_config('mappings', { start_jumping = '<CR>' })
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ labels = 'a' })
  eq(child.lua_get('MiniJump2d.config.labels'), 'a')
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ spotter = 'a' }, 'spotter', 'function')
  expect_config_error({ labels = 1 }, 'labels', 'string')
  expect_config_error({ allowed_lines = 'a' }, 'allowed_lines', 'table')
  expect_config_error({ allowed_lines = { blank = 1 } }, 'allowed_lines.blank', 'boolean')
  expect_config_error({ allowed_lines = { cursor_before = 1 } }, 'allowed_lines.cursor_before', 'boolean')
  expect_config_error({ allowed_lines = { cursor_at = 1 } }, 'allowed_lines.cursor_at', 'boolean')
  expect_config_error({ allowed_lines = { cursor_after = 1 } }, 'allowed_lines.cursor_after', 'boolean')
  expect_config_error({ allowed_lines = { fold = 1 } }, 'allowed_lines.fold', 'boolean')
  expect_config_error({ allowed_windows = 'a' }, 'allowed_windows', 'table')
  expect_config_error({ allowed_windows = { current = 'a' } }, 'allowed_windows.current', 'boolean')
  expect_config_error({ allowed_windows = { not_current = 'a' } }, 'allowed_windows.not_current', 'boolean')
  expect_config_error({ hooks = 'a' }, 'hooks', 'table')
  expect_config_error({ hooks = { before_start = 1 } }, 'hooks.before_start', 'function')
  expect_config_error({ hooks = { after_jump = 1 } }, 'hooks.after_jump', 'function')
  expect_config_error({ mappings = 'a' }, 'mappings', 'table')
  expect_config_error({ mappings = { start_jumping = 1 } }, 'mappings.start_jumping', 'string')
end

T['setup()']['applies `config.mappings`'] = function()
  set_lines({ 'aaaa', 'aaaa' })
  type_keys('<CR>')
  eq(get_extmark_lines_curwin(), { 'a  b', 'c  d' })
end

T['setup()']['properly handles `config.mappings`'] = function()
  local has_map = function(lhs)
    return child.cmd_capture('nmap ' .. lhs):find('MiniJump2d') ~= nil
  end
  eq(has_map('<CR>'), true)

  unload_module()
  child.api.nvim_del_keymap('n', '<CR>')

  -- Supplying empty string should mean "don't create keymap"
  load_module({ mappings = { start_jumping = '' } })
  eq(has_map('<CR>'), false)
end

T['start()'] = new_set({
  hooks = {
    pre_case = function()
      -- Reference lines:
      -- aaaa
      --
      -- aaaa
      set_lines({ 'aaaa', '', 'aaaa' })
    end,
  },
})

local start = function(...)
  child.lua('MiniJump2d.start(...)', { ... })
  poke_eventloop()
end

T['start()']['works'] = function()
  local init_curpos = get_cursor()

  start()
  eq(get_extmark_lines_curwin(), { 'a  b', 'c', 'd  e' })
  type_keys('e')
  eq(get_extmark_lines_curwin(), { '', '', '' })
  eq(get_cursor(), { 3, 3 })

  -- Adds previous position to jumplist
  type_keys('<C-o>')
  eq(get_cursor(), init_curpos)
end

T['start()']['works in Visual mode'] = function()
  type_keys('v')

  start()
  eq(get_extmark_lines_curwin(), { 'a  b', 'c', 'd  e' })
  type_keys('e')
  eq(get_extmark_lines_curwin(), { '', '', '' })
  eq(get_cursor(), { 3, 3 })
  eq(child.api.nvim_get_mode().mode, 'v')
end

T['start()']['works in Operator-pending mode'] = function()
  type_keys('d')
  -- Use default mapping because otherwise it hangs child process
  type_keys('<CR>')
  type_keys('e')

  eq(get_lines(), { 'a' })
  eq(get_cursor(), { 1, 0 })
  eq(get_extmark_lines_curwin(), { '' })
end

T['start()']['uses only visible lines'] = function()
  set_lines({ 'aaaa', 'aaaa', 'aaaa', 'aaaa' })

  -- Make window show only lines 2 and 3
  child.api.nvim_win_set_height(0, 2)
  set_cursor(2, 0)
  type_keys('zt')
  eq({ child.fn.line('w0'), child.fn.line('w$') }, { 2, 3 })

  -- Validate
  start()
  eq(get_extmark_lines_curwin(), { '', 'a  b', 'c  d', '' })
  type_keys('d')
  eq(get_cursor(), { 3, 3 })
end

T['start()']['does not account for current cursor position during label computation'] = function()
  local validate = function(test_curpos)
    local init_curpos = child.api.nvim_win_get_cursor(0)
    child.api.nvim_win_set_cursor(0, test_curpos)
    start()
    local extmark_lines = get_extmark_lines_curwin()
    child.lua('MiniJump2d.stop()')
    child.api.nvim_win_set_cursor(0, init_curpos)

    eq(extmark_lines, { 'a  b', 'c', 'd  e' })
  end

  validate({ 1, 1 })
  validate({ 2, 0 })
  validate({ 3, 0 })
  validate({ 3, 3 })
end

T['start()']['uses `<CR>` to jump to first available spot'] = function()
  -- Spots should be labeled `a a b b c d e...`
  set_lines({ string.rep('a ', 28) })

  -- On first step
  set_cursor(1, 20)
  start()
  type_keys('<CR>')
  eq(get_extmark_lines_curwin(), { '' })
  eq(get_cursor(), { 1, 0 })

  -- On later steps
  set_cursor(1, 20)
  start()
  type_keys(1, 'b', '<CR>')
  eq(get_extmark_lines_curwin(), { '' })
  eq(get_cursor(), { 1, 4 })
end

T['start()']['prompts helper message after one idle second'] = function()
  start()
  eq(get_latest_message(), '')
  sleep(1000 - 10)
  eq(get_latest_message(), '')
  sleep(10 + 1)
  eq(get_latest_message(), '(mini.jump2d) Enter encoding symbol to advance jump')
end

T['start()']['stops jumping if not label was typed'] = function()
  local validate = function(key)
    set_cursor(1, 0)
    start()

    type_keys(key)

    eq(get_extmark_lines_curwin(), { '', '', '' })
    -- Cursor shouldn't move
    eq(get_cursor(), { 1, 0 })
  end

  validate('<Down>')
  validate('<Esc>')

  -- `<C-c>` should not result in error
  validate('<C-c>')
end

T['start()']['does not account for current window during label computation'] = function()
  local wins = setup_windows()

  local validate = function(test_win_id)
    local init_win = child.api.nvim_get_current_win()
    child.api.nvim_set_current_win(test_win_id)
    start()
    local extmark_lines = get_extmark_lines()
    child.lua('MiniJump2d.stop()')
    child.api.nvim_set_current_win(init_win)

    eq(extmark_lines, {
      [wins.topleft] = { 'a  b' },
      [wins.bottomleft] = { 'c  d' },
      [wins.topright] = { 'e  f' },
      [wins.bottomright] = { 'g  h' },
      [wins.other_tabpage] = { '' },
    })
  end

  validate(wins.bottomright)
  validate(wins.topright)
  validate(wins.topleft)
end

T['start()']['uses all visible windows by default'] = function()
  local wins = setup_windows()

  start()
  --stylua: ignore
  eq(get_extmark_lines(), {
    [wins.topleft]       = { 'a  b' },
    [wins.bottomleft]    = { 'c  d' },
    [wins.topright]      = { 'e  f' },
    [wins.bottomright]   = { 'g  h' },
    [wins.other_tabpage] = { '' },
  })

  child.lua('MiniJump2d.stop()')
  child.api.nvim_set_current_win(wins.other_tabpage)
  start()
  --stylua: ignore
  eq(get_extmark_lines(), {
    [wins.topleft]       = { '' },
    [wins.bottomleft]    = { '' },
    [wins.topright]      = { '' },
    [wins.bottomright]   = { '' },
    [wins.other_tabpage] = { 'a  b' },
  })
end

T['start()']['traverses visible "regular" windows based on their layout'] = function()
  local wins = setup_windows()

  -- Make topright window be "on the right" of bottomright
  child.api.nvim_set_current_win(wins.topright)
  child.cmd('vertical resize -1')
  child.api.nvim_set_current_win(wins.topleft)

  start()

  -- Order should be top to bottom, left to right
  --stylua: ignore
  eq(get_extmark_lines(), {
    [wins.topleft]       = { 'a  b' },
    [wins.bottomleft]    = { 'c  d' },
    -- Topright is on the right of bottomright, so labels are processed later
    [wins.topright]      = { 'g  h' },
    [wins.bottomright]   = { 'e  f' },
    [wins.other_tabpage] = { '' },
  })
end

T['start()']['traverses floating windows at the end'] = function()
  -- Set up windows and buffers
  local buf_regular = child.api.nvim_get_current_buf()
  local win_regular = child.api.nvim_get_current_win()
  local buf_floating = child.api.nvim_create_buf(true, false)
  local win_floating = child.api.nvim_open_win(
    buf_floating,
    false,
    { relative = 'win', win = win_regular, width = 10, height = 10, row = 0, col = 0 }
  )

  child.api.nvim_buf_set_lines(buf_regular, 0, -1, true, { 'aaaa' })
  child.api.nvim_buf_set_lines(buf_floating, 0, -1, true, { 'aaaa' })

  -- Both windos have same "positions" but different "zindex"
  eq(child.api.nvim_win_get_position(win_regular), child.api.nvim_win_get_position(win_floating))

  start()
  eq(get_extmark_lines(), { [win_regular] = { 'a  b' }, [win_floating] = { 'c  d' } })
end

T['start()']['overrides `config` from `opts` argument'] = function()
  reload_module({ labels = 'jk' })
  start({ allowed_lines = { blank = false } })
  eq(get_extmark_lines_curwin(), { 'j  j', '', 'k  k' })
end

T['start()']['respects `spotter`'] = function()
  child.lua('MiniJump2d.start({ spotter = function() return { 1 } end })')
  eq(get_extmark_lines_curwin(), { 'a', 'b', 'c' })
end

T['start()']['uses `spotter` with correct arguments'] = function()
  child.cmd('%bwipeout!')

  -- Set up windows and buffers. One with empty line, other - with fold
  local win_init, buf_init = child.api.nvim_get_current_win(), child.api.nvim_get_current_buf()
  child.api.nvim_buf_set_lines(buf_init, 0, -1, true, { 'aaaa', '', 'aaaa' })

  child.cmd('rightbelow vsplit aaa')
  local win_other, buf_other = child.api.nvim_get_current_win(), child.api.nvim_get_current_buf()
  child.api.nvim_buf_set_lines(buf_other, 0, -1, true, { 'bbbb', 'bbbb', 'bbbb' })

  set_cursor(2, 0)
  type_keys('zf', 'j')
  eq({ child.fn.foldclosed(2), child.fn.foldclosed(3) }, { 2, 2 })
  set_cursor(1, 0)

  child.api.nvim_set_current_win(win_init)

  -- Validate. `spotter` should be called with signature:
  -- `<line number>, {win_id = <number>, win_id_init = <number>}`
  -- Shouldn't be called on blank and fold lines
  child.lua('_G.args_history = {}')
  child.lua([[MiniJump2d.start({
      labels = 'jk',
      spotter = function(...) table.insert(_G.args_history, { ... }); return { 1 } end
    })]])
  eq(get_extmark_lines(), { [win_init] = { 'j', 'j', 'j' }, [win_other] = { 'k', 'k', '' } })
  eq(child.lua_get('_G.args_history'), {
    { 1, { win_id = win_init, win_id_init = win_init } },
    { 3, { win_id = win_init, win_id_init = win_init } },
    { 1, { win_id = win_other, win_id_init = win_init } },
  })

  -- Should call `spotter` only on jumpt start, not on every step
  child.lua('_G.args_history = {}')
  type_keys('j')
  eq(get_extmark_lines(), { [win_init] = { 'j', 'j', 'k' }, [win_other] = { '', '', '' } })
  eq(child.lua_get('_G.args_history'), {})
end

T['start()']['respects `labels`'] = function()
  start({ labels = 'jk' })
  eq(get_extmark_lines_curwin(), { 'j  j', 'j', 'k  k' })
  type_keys('j')
  eq(get_extmark_lines_curwin(), { 'j  j', 'k', '' })
  type_keys('k')
  eq(get_extmark_lines_curwin(), { '', '', '' })
  eq(get_cursor(), { 2, 0 })
end

T['start()']['respects `allowed_lines.blank`'] = function()
  start({ allowed_lines = { blank = false } })
  eq(get_extmark_lines_curwin(), { 'a  b', '', 'c  d' })
end

T['start()']['respects `allowed_lines.cursor_before`'] = function()
  -- Should affect all allowed windows and their cursor position
  local wins = setup_two_windows()

  start({ allowed_lines = { cursor_before = false } })
  eq(get_extmark_lines(), { [wins.left] = { '', 'a  b', 'c  d' }, [wins.right] = { '', 'e  f', 'g  h' } })
end

T['start()']['respects `allowed_lines.cursor_at`'] = function()
  -- Should affect all allowed windows and their cursor position
  local wins = setup_two_windows()

  start({ allowed_lines = { cursor_at = false } })
  eq(get_extmark_lines(), { [wins.left] = { 'a  b', '', 'c  d' }, [wins.right] = { 'e  f', '', 'g  h' } })
end

T['start()']['respects `allowed_lines.cursor_after`'] = function()
  -- Should affect all allowed windows and their cursor position
  local wins = setup_two_windows()

  start({ allowed_lines = { cursor_at = false } })
  eq(get_extmark_lines(), { [wins.left] = { 'a  b', '', 'c  d' }, [wins.right] = { 'e  f', '', 'g  h' } })
end

T['start()']['respects folds'] = function()
  -- Make fold on lines 2-3
  set_cursor(2, 0)
  type_keys('zf', 'j')
  eq({ child.fn.foldclosed(2), child.fn.foldclosed(3) }, { 2, 2 })
  set_cursor(1, 0)

  -- Validate
  start()
  eq(get_extmark_lines_curwin(), { 'a  b', 'c', '' })

  -- Folds should still be present
  eq({ child.fn.foldclosed(2), child.fn.foldclosed(3) }, { 2, 2 })

  -- After jump should open enough folds to show cursor
  type_keys('c')
  eq(get_extmark_lines_curwin(), { '', '', '' })
  eq(get_cursor(), { 2, 0 })
  eq({ child.fn.foldclosed(2), child.fn.foldclosed(3) }, { -1, -1 })
end

T['start()']['respects `allowed_lines.fold`'] = function()
  -- Make fold on lines 2-3
  set_cursor(2, 0)
  type_keys('zf', 'j')
  eq({ child.fn.foldclosed(2), child.fn.foldclosed(3) }, { 2, 2 })
  set_cursor(1, 0)

  -- Validate
  start({ allowed_lines = { fold = false } })
  eq(get_extmark_lines_curwin(), { 'a  b', '', '' })
end

T['start()']['respects `allowed_windows`'] = function()
  local validate = function(allowed_windows_opts, marks_current, marks_other)
    local wins = setup_two_windows()
    child.api.nvim_set_current_win(wins.left)
    local win_current, win_other = wins.left, wins.right

    start({ allowed_windows = allowed_windows_opts })
    eq(get_extmark_lines(), { [win_current] = marks_current, [win_other] = marks_other })
    child.lua('MiniJump2d.stop()')
  end

  validate({ current = false }, { '', '', '' }, { 'a  b', 'c  d', 'e  f' })
  validate({ not_current = false }, { 'a  b', 'c  d', 'e  f' }, { '', '', '' })

  -- Shouldn't error in this case
  validate({ current = false, not_current = false }, { '', '', '' }, { '', '', '' })
  eq(child.cmd_capture('1messages'), '(mini.jump2d) No spots to show.')
end

T['start()']['respects `hooks`'] = function()
  child.lua('_G.n_before_start = 0; _G.n_after_jump = 0')

  child.lua([[MiniJump2d.start({
      hooks = {
        before_start = function() _G.n_before_start = _G.n_before_start + 1 end,
        after_jump = function() _G.n_after_jump = _G.n_after_jump + 1 end,
      },
    })]])
  eq(child.lua_get('{ _G.n_before_start, _G.n_after_jump }'), { 1, 0 })
  type_keys('<CR>')
  eq(child.lua_get('{ _G.n_before_start, _G.n_after_jump }'), { 1, 1 })
end

T['start()']['allows `hook.before_start` to modify spotter'] = function()
  child.lua('_G.opts = { spotter = function() return { 1 } end }')
  child.lua([[_G.opts.hooks = {
      before_start = function()
        _G.opts.spotter = function() return { 2 } end
      end
    }]])

  set_lines({ 'aaaa', 'aaaa' })
  child.lua('MiniJump2d.start(_G.opts)')
  eq(get_extmark_lines_curwin(), { ' a', ' b' })
end

T['start()']['does not call `hook.after_jump` on jump cancel'] = function()
  local validate = function(cancel_action)
    child.lua('_G.n_after_jump = 0')

    child.lua([[MiniJump2d.start({
        hooks = { after_jump = function() _G.n_after_jump = _G.n_after_jump + 1 end },
      })]])

    eq(child.lua_get('_G.n_after_jump'), 0)
    cancel_action()
    eq(child.lua_get('_G.n_after_jump'), 0)
  end

  --stylua: ignore start
  validate(function() child.lua('MiniJump2d.stop()') end)
  validate(function() type_keys('<Esc>') end)
  validate(function() type_keys('<C-c>') end)
  --stylua: ignore end
end

local validate_hl_group = function(hl_group)
  local extmarks = get_extmarks()
  local all_correct_hl_group = true
  for _, e_mark in ipairs(extmarks) do
    if e_mark.hl ~= hl_group then
      all_correct_hl_group = false
    end
  end

  eq(all_correct_hl_group, true)
end

T['start()']['uses `MiniJump2dSpot` highlight group by default'] = function()
  start()
  validate_hl_group('MiniJump2dSpot')
end

T['start()']['respects `opts.hl_group`'] = function()
  start({ hl_group = 'Search' })
  validate_hl_group('Search')
end

T['start()']['respects `vim.{g,b}.minijump2d_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minijump2d_disable = true

    start()
    eq(get_extmarks(), {})
  end,
})

T['stop()'] = new_set()

T['stop()']['works'] = function()
  set_lines({ 'aaaa', 'aaaa' })
  child.lua('MiniJump2d.start()')
  eq(get_extmark_lines_curwin(), { 'a  b', 'c  d' })
  child.lua('MiniJump2d.stop()')
  eq(get_extmark_lines_curwin(), { '', '' })
end

T['stop()']['works even if not jumping'] = function()
  expect.no_error(function()
    child.lua('MiniJump2d.stop()')
  end)
end

T['gen_pattern_spotter()'] = new_set({
  hooks = {
    pre_case = function()
      set_lines({ 'aaa a_a a.a aaa' })
    end,
  },
})

local start_gen_pattern = function(pattern, side)
  local command = string.format(
    [[MiniJump2d.start({ spotter = MiniJump2d.gen_pattern_spotter(%s, %s) })]],
    vim.inspect(pattern),
    vim.inspect(side)
  )
  child.lua(command)
end

local validate_pattern_spotter = function(pattern, side, extmark_lines)
  start_gen_pattern(pattern, side)
  local observed_extmark_lines = get_extmark_lines_curwin()
  child.lua('MiniJump2d.stop()')

  eq(observed_extmark_lines, extmark_lines)
end

T['gen_pattern_spotter()']['works'] = function()
  -- By default it matches group of non-whitespace non-punctuation
  validate_pattern_spotter(nil, nil, { 'a   b c d e f' })
end

T['gen_pattern_spotter()']['respects `pattern` argument'] = function()
  validate_pattern_spotter('%s', nil, { '   a   b   c' })
end

-- stylua: ignore
T['gen_pattern_spotter()']['respects `side` argument'] = function()
  validate_pattern_spotter(nil   , 'start', { 'a   b c d e f' })
  validate_pattern_spotter(nil   , 'end'  , { '  a b c d e   f' })
  validate_pattern_spotter('.().', 'none' , { ' a b c d e f g' })
end

-- stylua: ignore
T['gen_pattern_spotter()']['handles patterns with "^" and "$"'] = function()
  set_lines({ 'aaa aaa', '', 'aa' })

  -- '^'
  validate_pattern_spotter('^...'  , 'start', {'a'  , 'b', ''})
  validate_pattern_spotter('^...'  , 'end'  , {'  a', 'b', ''})
  validate_pattern_spotter('^.()..', 'none' , {' a' , 'b', ''})

  -- '$'
  validate_pattern_spotter('...$'  , 'start', {'    a'  , 'b', ''})
  validate_pattern_spotter('...$'  , 'end'  , {'      a', 'b', ''})
  validate_pattern_spotter('.()..$', 'none' , {'     a' , 'b', ''})
end

T['gen_pattern_spotter()']['works with multibyte characters'] = function()
  set_lines({ 'ы ыыы ы_ы ыы' })
  start_gen_pattern('%S')
    -- stylua: ignore
    local extmarks = get_extmarks_short()

  -- This corresponds to this displayed extmark line: 'a bcd efg hi'
  eq(extmarks, { { 1, 'a' }, { 4, 'b' }, { 6, 'c' }, { 8, 'd' }, { 11, 'ef' }, { 14, 'g' }, { 17, 'h' }, { 19, 'i' } })
end

T['gen_pattern_spotter()']['works in edge cases'] = function()
  start_gen_pattern('.%f[%W]')
  eq(get_extmark_lines_curwin(), { '  a b c d e   f' })
end

T['default_spotter()'] = new_set()

local validate_default_spooter = function(extmark_lines)
  child.lua('MiniJump2d.start({ spotter = MiniJump2d.default_spotter })')
  local observed_extmark_lines = get_extmark_lines_curwin()
  child.lua('MiniJump2d.stop()')

  eq(observed_extmark_lines, extmark_lines)
end

--stylua: ignore start
T['default_spotter()']['works'] = function()
  set_lines({ 'aaa a_a (a) aAAa aAAA' })
  validate_default_spooter({  'a b c d efg hi j kl m' })
end

T['default_spotter()']['spots start and end of words'] = function()
  set_lines({ 'a aa aaa' })
  validate_default_spooter({  'a bc d e' })
end

T['default_spotter()']['spots before and after punctuation'] = function()
  set_lines({ 'aaa_____aaa (a)' })
  validate_default_spooter({  'a b     c d efg' })
end

T['default_spotter()']['spots first capital letter'] = function()
  set_lines({ 'AaaAAaaAAAa' })
  validate_default_spooter({  'a  b   c  d' })
end

T['default_spotter()']['corectly merges "overlapping" spots'] = function()
  set_lines({ 'AA () A_A' })
  validate_default_spooter({  'ab cd e f' })
end

T['default_spotter()']['works (almost) with multibyte character'] = function()
  set_lines({ 'ы ыы ыыы ы_ы ыЫыы' })
  child.lua('MiniJump2d.start({ spotter = MiniJump2d.default_spotter })')
  local extmarks = get_extmarks_short()
  child.lua('MiniJump2d.stop()')

  -- This corresponds to this displayed extmark line: 'a bc d e f g h  i'.
  -- NOTE: ideally it should end with 'hi j' but 'Ы' is not recognized as
  -- captial letter in Lua patterns (because of different locale)
  eq(
    extmarks,
    { { 1, 'a' }, { 4, 'b' }, { 6, 'c' }, { 9, 'd' }, { 13, 'e' }, { 16, 'f' }, { 19, 'g' }, { 22, 'h' }, { 28, 'i' } }
  )
end
--stylua: ignore end

T['builtin_opts.line_start'] = new_set()

T['builtin_opts.line_start']['works'] = function()
  set_lines({ 'aaa', '  aaa', '' })
  child.lua('MiniJump2d.start(MiniJump2d.builtin_opts.line_start)')
  eq(get_extmark_lines_curwin(), { 'a', 'b', 'c' })

  -- It should jump to first non-blank character
  type_keys('b')
  eq(get_cursor(), { 2, 2 })
end

T['builtin_opts.word_start'] = new_set()

T['builtin_opts.word_start']['works'] = function()
  set_lines({ 'a aa aaa _aa' })
  child.lua('MiniJump2d.start(MiniJump2d.builtin_opts.word_start)')
  eq(get_extmark_lines_curwin(), { 'a b  c    d' })
end

T['builtin_opts.word_start']['works with multibyte characters'] = function()
  set_lines({ 'ы ыы ыыы _ыы' })
  child.lua('MiniJump2d.start(MiniJump2d.builtin_opts.word_start)')
  --stylua: ignore
  local extmarks = get_extmarks_short()
  eq(extmarks, { { 1, 'a' }, { 4, 'b' }, { 9, 'c' }, { 17, 'd' } })
end

T['builtin_opts.single_character'] = new_set({
  hooks = {
    pre_case = function()
      -- Avoid hit-enter-prompt
      child.o.cmdheight = 10
    end,
  },
})

local start_single_char = function()
  child.lua_notify('MiniJump2d.start(MiniJump2d.builtin_opts.single_character)')
end

local validate_single_char = function(key, extmark_lines)
  start_single_char()
  type_keys(key)
  local observed_extmark_lines = get_extmark_lines_curwin()
  child.lua('MiniJump2d.stop()')

  eq(observed_extmark_lines, extmark_lines)
end

--stylua: ignore
T['builtin_opts.single_character']['works'] = function()
  set_lines({    'a_a b_b ccc' })

  validate_single_char('a', {'a b'})
  validate_single_char('b', {'    a b'})
  validate_single_char('c', {'        abc'})
end

--stylua: ignore
T['builtin_opts.single_character']['works multibyte characters'] = function()
  set_lines({    'aa ыы' })

  start_single_char()
  type_keys('ы')
  local extmarks = get_extmarks_short()
  eq(extmarks, { { 4, 'a' }, { 6, 'b' } })
end

--stylua: ignore
T['builtin_opts.single_character']['works with problematic characters'] = function()
  set_lines({    '.. %%' })

  validate_single_char('.', {'ab'})
  validate_single_char('%', {'   ab'})
end

local validate_no_spots_single_char = function(key)
  child.cmd('messages clear')
  validate_single_char(key, { '' })
  eq(get_latest_message(), '(mini.jump2d) No spots to show.')
end

T['builtin_opts.single_character']['notifies if there is no spots'] = function()
  set_lines({ 'aaa' })

  validate_no_spots_single_char('b')
end

T['builtin_opts.single_character']['handles <C-c>, <Esc>, <CR> in user input'] = function()
  set_lines({ 'a_a b_b ccc' })

  validate_no_spots_single_char('<C-c>')
  validate_no_spots_single_char('<Esc>')
  validate_no_spots_single_char('<CR>')
end

T['builtin_opts.single_character']['prompts helper message after one idle second'] = function()
  start_single_char()
  eq(get_latest_message(), '')
  sleep(1000 - 10)
  eq(get_latest_message(), '')
  sleep(10 + 1)
  eq(get_latest_message(), '(mini.jump2d) Enter single character to search')
end

T['builtin_opts.query'] = new_set({
  hooks = {
    pre_case = function()
      -- Avoid hit-enter-prompt
      child.o.cmdheight = 10
    end,
  },
})

local start_query = function()
  child.lua_notify('MiniJump2d.start(MiniJump2d.builtin_opts.query)')
end

--stylua: ignore
local validate_query = function(keys, extmark_lines, enter_cr)
  if enter_cr == nil then enter_cr = true end

  start_query()
  type_keys(keys)
  if enter_cr then type_keys('<CR>') end
  local observed_extmark_lines = get_extmark_lines_curwin()
  child.lua('MiniJump2d.stop()')

  eq(observed_extmark_lines, extmark_lines)
end

--stylua: ignore
T['builtin_opts.query']['works'] = function()
  set_lines({     'abcab' })

  validate_query('ab', {'a  b'})
  validate_query('bc', {' a'})
  validate_query('c',  {'  a'})
end

--stylua: ignore
T['builtin_opts.query']['works multibyte characters'] = function()
  set_lines({    'aa ыы ыы' })

  start_query()
  type_keys('ыы', '<CR>')
  local extmarks = get_extmarks_short()
  eq(extmarks, { { 4, 'a' }, { 9, 'b' } })
end

--stylua: ignore
T['builtin_opts.query']['works with problematic characters'] = function()
  set_lines({     '.. %%' })

  validate_query('..', {'a'})
  validate_query('%%', {'   a'})
  validate_query('.',  {'ab'})
end

local validate_no_spots_query = function(key, enter_cr)
  child.cmd('messages clear')
  validate_query(key, { '' }, enter_cr)
  eq(get_latest_message(), '(mini.jump2d) No spots to show.')
end

T['builtin_opts.query']['notifies if there is no spots'] = function()
  set_lines({ 'abc' })

  validate_no_spots_query('bb')
end

T['builtin_opts.query']['handles <C-c>, <Esc>, <CR> in user input'] = function()
  set_lines({ 'a_a b_b ccc' })

  validate_no_spots_query('<C-c>', false)
  validate_no_spots_query('<Esc>', false)

  -- Empty query should be like matching any character
  validate_query('<CR>', { 'abcdefghijk' }, false)
end

T['builtin_opts.query']['works in edge cases'] = function()
  set_lines({ 'aaaaaa' })
  validate_query('aa', { 'a b c' })
end

return T
