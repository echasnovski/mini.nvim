local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('trailspace', config) end
local unload_module = function() child.mini_unload('trailspace') end
local reload_module = function(config) unload_module(); load_module(config) end
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
  assert.True(is_trailspace_highlighted(win_id))
end

local validate_not_highlighted = function(win_id)
  assert.False(is_trailspace_highlighted(win_id))
end

local ensure_no_highlighting = function()
  child.fn.clearmatches()
end

-- Data =======================================================================
local example_lines = { 'aa ', 'aa  ', 'aa\t', 'aa\t\t', 'aa \t', 'aa\t ', '  aa', '\taa' }
local example_trimmed_lines = vim.tbl_map(function(x)
  return x:gsub('%s*$', '')
end, example_lines)

-- Unit tests =================================================================
describe('MiniTrailspace.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniTrailspace ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniTrailspace'), 1)

    -- Highlight groups
    assert.truthy(child.cmd_capture('hi MiniTrailspace'):find('links to Error'))
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniTrailspace.config)'), 'table')

    -- Check default values
    eq(child.lua_get('MiniTrailspace.config.only_in_normal_buffers'), true)
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ only_in_normal_buffers = false })
    eq(child.lua_get('MiniTrailspace.config.only_in_normal_buffers'), false)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ only_in_normal_buffers = 'a' }, 'only_in_normal_buffers', 'boolean')
  end)
end)

describe('MiniTrailspace.highlight()', function()
  child.setup()
  load_module()

  before_each(function()
    reload_module()
    set_lines(example_lines)
    ensure_no_highlighting()
    child.ensure_normal_mode()
  end)

  it('works', function()
    validate_not_highlighted()
    child.lua('MiniTrailspace.highlight()')
    validate_highlighted()
  end)

  it('respects `config.only_in_normal_buffers`', function()
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
  end)

  it('works only in Normal mode', function()
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
  end)

  it('does not unnecessarily create match entry', function()
    child.lua('MiniTrailspace.highlight()')
    local match_1 = get_match()
    eq(#match_1, 1)

    child.lua('MiniTrailspace.highlight()')
    local match_2 = get_match()
    eq(#match_2, 1)
    eq(match_1.id, match_2.id)
  end)

  it('works after `clearmatches()` called to remove highlight', function()
    child.lua('MiniTrailspace.highlight()')
    child.fn.clearmatches()
    validate_not_highlighted()

    child.lua('MiniTrailspace.highlight()')
    validate_highlighted()
  end)

  it('respects vim.{g,b}.minitrailspace_disable', function()
    local validate_disable = function(var_type)
      child[var_type].minitrailspace_disable = true
      validate_not_highlighted()
      child.lua('MiniTrailspace.highlight()')
      validate_not_highlighted()

      child[var_type].minitrailspace_disable = nil
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

describe('MiniTrailspace.unhighlight()', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines)
    child.lua('MiniTrailspace.highlight()')
  end)

  it('works', function()
    validate_highlighted()
    child.lua('MiniTrailspace.unhighlight()')
    validate_not_highlighted()
  end)

  it('does not throw error if matches were manually cleared', function()
    validate_highlighted()
    child.fn.clearmatches()
    child.lua('MiniTrailspace.unhighlight()')
    validate_not_highlighted()
  end)
end)

describe('MiniTrailspace.trim()', function()
  child.setup()
  load_module()

  --stylua: ignore
  before_each(function() set_lines(example_lines) end)

  it('works', function()
    child.lua('MiniTrailspace.trim()')
    eq(get_lines(), example_trimmed_lines)
  end)

  it('does not move cursor', function()
    set_cursor(4, 1)
    child.lua('MiniTrailspace.trim()')
    eq(get_cursor(), { 4, 1 })
  end)

  it('does not update search pattern', function()
    type_keys('/', 'aa', '<CR>')
    child.lua('MiniTrailspace.trim()')
    eq(child.fn.getreg('/'), 'aa')
  end)
end)

-- Functional tests ===========================================================
describe('Trailspace autohighlighting', function()
  before_each(function()
    child.setup()
    set_lines(example_lines)
    load_module()
  end)

  it('respects InsertEnter/InsertLeave', function()
    child.lua('MiniTrailspace.highlight()')
    validate_highlighted()

    child.cmd('startinsert')
    validate_not_highlighted()

    child.cmd('stopinsert')
    validate_highlighted()
  end)

  it('respects WinEnter/WinLeave', function()
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
  end)

  it('respects OptionSet', function()
    child.lua('MiniTrailspace.highlight()')

    child.api.nvim_buf_set_option(0, 'buftype', 'nowrite')
    validate_not_highlighted()

    child.api.nvim_buf_set_option(0, 'buftype', '')
    validate_highlighted()
  end)

  it('respects vim.{g,b}.minitrailspace_disable', function()
    local validate_disable = function(var_type)
      child.lua('MiniTrailspace.highlight()')

      child[var_type].minitrailspace_disable = true
      -- Ensure "restarted" highlighting
      child.cmd('startinsert')
      child.cmd('stopinsert')

      validate_not_highlighted()

      child[var_type].minitrailspace_disable = nil
    end

    validate_disable('g')
    validate_disable('b')
  end)
end)

describe('Trailspace highlighting on startup', function()
  it('works', function()
    child.restart({
      '-u',
      'scripts/minimal_init.vim',
      '-c',
      [[lua require('mini.trailspace').setup()]],
      '--',
      'tests/trailspace-tests/file',
    })
    validate_highlighted()
  end)
end)

child.stop()
