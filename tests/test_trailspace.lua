local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('trailspace', config) end
local unload_module = function() child.mini_unload('trailspace') end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
--stylua: ignore end

-- Make helpers
local get_match = function(win_id)
  win_id = win_id or child.api.nvim_get_current_win()
  return vim.tbl_filter(function(x)
    return x.group == 'MiniTrailspace'
  end, child.fn.getmatches(win_id))
end

local is_trailspace_highlighted = function(win_id)
  return #get_match(win_id) > 0
end

local validate_highlighted = function(win_id)
  eq(is_trailspace_highlighted(win_id), true)
end

local validate_not_highlighted = function(win_id)
  eq(is_trailspace_highlighted(win_id), false)
end

local ensure_no_highlighting = function()
  child.fn.clearmatches()
end

-- Data =======================================================================
local example_lines = { 'aa ', 'aa  ', 'aa\t', 'aa\t\t', 'aa \t', 'aa\t ', '  aa', '\taa' }
local example_trimmed_lines = vim.tbl_map(function(x)
  return x:gsub('%s*$', '')
end, example_lines)

-- Output test set ============================================================
T = new_set({
  hooks = {
    pre_case = function()
      child.setup()
      set_lines(example_lines)
      load_module()
    end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  -- Global variable
  eq(child.lua_get('type(_G.MiniTrailspace)'), 'table')

  -- Autocommand group
  eq(child.fn.exists('#MiniTrailspace'), 1)

  -- Highlight groups
  expect.match(child.cmd_capture('hi MiniTrailspace'), 'links to Error')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniTrailspace.config)'), 'table')

  -- Check default values
  eq(child.lua_get('MiniTrailspace.config.only_in_normal_buffers'), true)
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ only_in_normal_buffers = false })
  eq(child.lua_get('MiniTrailspace.config.only_in_normal_buffers'), false)
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ only_in_normal_buffers = 'a' }, 'only_in_normal_buffers', 'boolean')
end

T['highlight()'] = new_set({ hooks = { pre_case = ensure_no_highlighting } })

T['highlight()']['works'] = function()
  validate_not_highlighted()
  child.lua('MiniTrailspace.highlight()')
  validate_highlighted()
end

T['highlight()']['respects `config.only_in_normal_buffers`'] = function()
  child.o.hidden = true
  local validate_effect = function(not_normal_buf_id)
    child.api.nvim_set_current_buf(not_normal_buf_id)
    ensure_no_highlighting()

    child.lua('MiniTrailspace.highlight()')
    if child.lua_get('MiniTrailspace.config.only_in_normal_buffers') then
      validate_not_highlighted()
    else
      validate_highlighted()
    end
  end

  local validate = function(not_normal_buf_id)
    child.lua('MiniTrailspace.config.only_in_normal_buffers = true')
    validate_effect(not_normal_buf_id)

    child.lua('MiniTrailspace.config.only_in_normal_buffers = false')
    validate_effect(not_normal_buf_id)

    child.api.nvim_buf_delete(not_normal_buf_id, { force = true })
  end

  local buf_id

  -- Check in scratch buffer (not normal)
  buf_id = child.api.nvim_create_buf(true, true)
  validate(buf_id)

  -- Check in help buffer (not normal)
  buf_id = child.api.nvim_create_buf(true, false)
  child.api.nvim_buf_set_option(buf_id, 'buftype', 'help')
  validate(buf_id)
end

T['highlight()']['works only in Normal mode'] = function()
  -- Insert mode
  child.cmd('startinsert')

  ensure_no_highlighting()
  child.lua('MiniTrailspace.highlight()')
  validate_not_highlighted()

  child.cmd('stopinsert')

  -- Visual mode
  type_keys('v')

  ensure_no_highlighting()
  child.lua('MiniTrailspace.highlight()')
  validate_not_highlighted()

  type_keys('v')
end

T['highlight()']['does not unnecessarily create match entry'] = function()
  child.lua('MiniTrailspace.highlight()')
  local match_1 = get_match()
  eq(#match_1, 1)

  child.lua('MiniTrailspace.highlight()')
  local match_2 = get_match()
  eq(#match_2, 1)
  eq(match_1.id, match_2.id)
end

T['highlight()']['works after `clearmatches()` called to remove highlight'] = function()
  child.lua('MiniTrailspace.highlight()')
  child.fn.clearmatches()
  validate_not_highlighted()

  child.lua('MiniTrailspace.highlight()')
  validate_highlighted()
end

T['highlight()']['respects `vim.{g,b}.minitrailspace_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minitrailspace_disable = true
    validate_not_highlighted()
    child.lua('MiniTrailspace.highlight()')
    validate_not_highlighted()
  end,
})

T['unhighlight()'] = new_set({
  hooks = {
    pre_case = function()
      child.lua('MiniTrailspace.highlight()')
    end,
  },
})

T['unhighlight()']['works'] = function()
  validate_highlighted()
  child.lua('MiniTrailspace.unhighlight()')
  validate_not_highlighted()
end

T['unhighlight()']['does not throw error if matches were manually cleared'] = function()
  validate_highlighted()
  child.fn.clearmatches()
  child.lua('MiniTrailspace.unhighlight()')
  validate_not_highlighted()
end

T['trim()'] = new_set()

T['trim()']['works'] = function()
  child.lua('MiniTrailspace.trim()')
  eq(get_lines(), example_trimmed_lines)
end

T['trim()']['does not move cursor'] = function()
  set_cursor(4, 1)
  child.lua('MiniTrailspace.trim()')
  eq(get_cursor(), { 4, 1 })
end

T['trim()']['does not update search pattern'] = function()
  type_keys('/', 'aa', '<CR>')
  child.lua('MiniTrailspace.trim()')
  eq(child.fn.getreg('/'), 'aa')
end

-- Integration tests ==========================================================
T['Trailspace autohighlighting'] = new_set()

T['Trailspace autohighlighting']['respects InsertEnter/InsertLeave'] = function()
  child.lua('MiniTrailspace.highlight()')
  validate_highlighted()

  child.cmd('startinsert')
  validate_not_highlighted()

  child.cmd('stopinsert')
  validate_highlighted()
end

T['Trailspace autohighlighting']['respects BufEnter/BufLeave'] = function()
  child.lua('MiniTrailspace.highlight()')
  validate_highlighted()

  child.cmd('doautocmd BufLeave')
  validate_not_highlighted()

  child.cmd('doautocmd BufEnter')
  validate_highlighted()
end

T['Trailspace autohighlighting']['respects WinEnter/WinLeave'] = function()
  child.lua('MiniTrailspace.highlight()')
  child.cmd('vsplit')
  local win_list = child.api.nvim_list_wins()
  local cur_win_id = child.api.nvim_get_current_win()
  local alt_win_id = win_list[1] == cur_win_id and win_list[2] or win_list[1]

  validate_highlighted(cur_win_id)
  validate_not_highlighted(alt_win_id)

  child.api.nvim_set_current_win(alt_win_id)

  validate_not_highlighted(cur_win_id)
  validate_highlighted(alt_win_id)

  child.api.nvim_set_current_win(cur_win_id)

  validate_highlighted(cur_win_id)
  validate_not_highlighted(alt_win_id)
end

T['Trailspace autohighlighting']['respects OptionSet'] = function()
  child.lua('MiniTrailspace.highlight()')

  child.api.nvim_buf_set_option(0, 'buftype', 'nowrite')
  validate_not_highlighted()

  child.api.nvim_buf_set_option(0, 'buftype', '')
  validate_highlighted()
end

T['Trailspace autohighlighting']['respects `vim.{g,b}.minitrailspace_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child.lua('MiniTrailspace.highlight()')

    child[var_type].minitrailspace_disable = true
    -- Ensure "restarted" highlighting
    child.cmd('startinsert')
    child.cmd('stopinsert')

    validate_not_highlighted()
  end,
})

T['Trailspace highlighting on startup'] = new_set()

T['Trailspace highlighting on startup']['works'] = function()
  child.restart({
    '-u',
    'scripts/minimal_init.lua',
    '-c',
    [[lua require('mini.trailspace').setup()]],
    '--',
    'tests/trailspace-tests/file',
  })
  validate_highlighted()
end

return T
