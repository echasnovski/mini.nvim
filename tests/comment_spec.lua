local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('comment', config) end
local unload_module = function() child.mini_unload('comment') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local get_lines = function(...) return child.get_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
--stylua: ignore end

-- Data =======================================================================
-- Reference text
-- aa
--  aa
--   aa
--
--   aa
--  aa
-- aa
local example_lines = { 'aa', ' aa', '  aa', '', '  aa', ' aa', 'aa' }

-- Unit tests =================================================================
describe('MiniComment.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniComment ~= nil'))
  end)

  it('creates `config` field', function()
    assert.True(child.lua_get([[type(_G.MiniComment.config) == 'table']]))

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniComment.config.' .. field), value)
    end

    assert_config('mappings.comment', 'gc')
    assert_config('mappings.comment_line', 'gcc')
    assert_config('mappings.textobject', 'gc')
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ mappings = { comment = 'gC' } })
    assert.True(child.lua_get([[MiniComment.config.mappings.comment == 'gC']]))
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ mappings = 'a' }, 'mappings', 'table')
    assert_config_error({ mappings = { comment = 1 } }, 'mappings.comment', 'string')
    assert_config_error({ mappings = { comment_line = 1 } }, 'mappings.comment_line', 'string')
    assert_config_error({ mappings = { textobject = 1 } }, 'mappings.textobject', 'string')
  end)

  it('properly handles `config.mappings`', function()
    local has_map = function(lhs)
      return child.cmd_capture('omap ' .. lhs):find('MiniComment') ~= nil
    end
    assert.True(has_map('gc'))

    unload_module()
    child.api.nvim_del_keymap('o', 'gc')

    -- Supplying empty string should mean "don't create keymap"
    load_module({ mappings = { textobject = '' } })
    assert.False(has_map('gc'))
  end)
end)

describe('MiniComment.toggle_lines()', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
  end)

  it('works', function()
    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  # aa', '  #', '  # aa' })

    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  aa', '', '  aa' })
  end)

  it('validates arguments', function()
    set_lines({ 'aa', 'aa', 'aa' })

    assert.error_matches(function()
      child.lua('MiniComment.toggle_lines(-1, 1)')
    end, 'line_start.*1')
    assert.error_matches(function()
      child.lua('MiniComment.toggle_lines(100, 101)')
    end, 'line_start.*3')
    assert.error_matches(function()
      child.lua('MiniComment.toggle_lines(1, -1)')
    end, 'line_end.*1')
    assert.error_matches(function()
      child.lua('MiniComment.toggle_lines(1, 100)')
    end, 'line_end.*3')

    assert.error_matches(function()
      child.lua('MiniComment.toggle_lines(2, 1)')
    end, 'line_start.*less than or equal.*line_end')
  end)

  it("works with different 'commentstring' options", function()
    -- Two-sided
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '/* %s */')
    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  /* aa */', '  /**/', '  /* aa */' })

    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  aa', '', '  aa' })

    -- Right-sided
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '%s #')
    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  aa #', '  #', '  aa #' })

    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  aa', '', '  aa' })

    -- Latex (#25)
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '%%s')
    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  % aa', '  %', '  % aa' })

    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  aa', '', '  aa' })
  end)

  it('correctly computes indent', function()
    child.lua('MiniComment.toggle_lines(2, 4)')
    eq(get_lines(1, 4), { ' # aa', ' #  aa', ' #' })

    set_lines(example_lines)
    child.lua('MiniComment.toggle_lines(4, 4)')
    eq(get_lines(3, 4), { '#' })
  end)

  it('correctly detects comment/uncomment', function()
    local lines = { '', 'aa', '# aa', '# aa', 'aa', '' }

    -- It should uncomment only if all lines are comments
    set_lines(lines)
    child.lua('MiniComment.toggle_lines(3, 4)')
    eq(get_lines(), { '', 'aa', 'aa', 'aa', 'aa', '' })

    set_lines(lines)
    child.lua('MiniComment.toggle_lines(2, 4)')
    eq(get_lines(), { '', '# aa', '# # aa', '# # aa', 'aa', '' })

    set_lines(lines)
    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(), { '', 'aa', '# # aa', '# # aa', '# aa', '' })

    set_lines(lines)
    child.lua('MiniComment.toggle_lines(1, 6)')
    eq(get_lines(), { '#', '# aa', '# # aa', '# # aa', '# aa', '#' })
  end)

  it('uncomments on inconsistent indent levels', function()
    set_lines({ '# aa', ' # aa', '  # aa' })
    child.lua('MiniComment.toggle_lines(1, 3)')
    eq(get_lines(), { 'aa', ' aa', '  aa' })
  end)

  it('respects tabs (#20)', function()
    child.api.nvim_buf_set_option(0, 'expandtab', false)
    set_lines({ '\t\taa', '\t\taa' })

    child.lua('MiniComment.toggle_lines(1, 2)')
    eq(get_lines(), { '\t\t# aa', '\t\t# aa' })

    child.lua('MiniComment.toggle_lines(1, 2)')
    eq(get_lines(), { '\t\taa', '\t\taa' })
  end)

  it('adds spaces inside non-empty lines', function()
    -- Two-sided
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '/*%s*/')
    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  /* aa */', '  /**/', '  /* aa */' })

    -- Right-sided
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '%s#')
    child.lua('MiniComment.toggle_lines(3, 5)')
    eq(get_lines(2, 5), { '  aa #', '  #', '  aa #' })
  end)

  it('removes trailing whitespace', function()
    set_lines({ 'aa', 'aa  ', '  ' })
    child.lua('MiniComment.toggle_lines(1, 3)')
    child.lua('MiniComment.toggle_lines(1, 3)')
    eq(get_lines(), { 'aa', 'aa', '' })
  end)
end)

-- Functional tests ===========================================================
describe('Commenting', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
  end)

  it('works in Normal mode', function()
    set_cursor(2, 2)
    type_keys({ 'g', 'c', 'a', 'p' })
    eq(get_lines(), { '# aa', '#  aa', '#   aa', '#', '  aa', ' aa', 'aa' })
    -- Cursor moves to start line
    eq(get_cursor(), { 1, 0 })

    -- Supports `v:count`
    set_lines(example_lines)
    set_cursor(2, 0)
    type_keys({ '2', 'g', 'c', 'a', 'p' })
    eq(get_lines(), { '# aa', '#  aa', '#   aa', '#', '#   aa', '#  aa', '# aa' })
  end)

  it('works in Visual mode', function()
    set_cursor(2, 2)
    type_keys({ 'v', 'a', 'p', 'g', 'c' })
    eq(get_lines(), { '# aa', '#  aa', '#   aa', '#', '  aa', ' aa', 'aa' })

    -- Cursor moves to start line
    eq(get_cursor(), { 1, 0 })
  end)

  it('works with different mapping', function()
    reload_module({ mappings = { comment = 'gC' } })

    set_cursor(2, 2)
    type_keys({ 'g', 'C', 'a', 'p' })
    eq(get_lines(), { '# aa', '#  aa', '#   aa', '#', '  aa', ' aa', 'aa' })
  end)

  it("respects 'commentstring'", function()
    child.api.nvim_buf_set_option(0, 'commentstring', '/*%s*/')
    set_cursor(2, 2)
    type_keys({ 'g', 'c', 'a', 'p' })
    eq(get_lines(), { '/* aa */', '/*  aa */', '/*   aa */', '/**/', '  aa', ' aa', 'aa' })
  end)

  it('allows dot-repeat', function()
    local doubly_commented = { '# # aa', '# #  aa', '# #   aa', '# #', '#   aa', '#  aa', '# aa' }

    set_lines(example_lines)
    set_cursor(2, 2)
    type_keys({ 'g', 'c', 'a', 'p' })
    type_keys('.')
    eq(get_lines(), doubly_commented)

    -- Not immediate dot-repeat
    set_lines(example_lines)
    set_cursor(2, 2)
    type_keys({ 'g', 'c', 'a', 'p' })
    set_cursor(7, 0)
    type_keys('.')
    eq(get_lines(), doubly_commented)
  end)

  it('preserves marks', function()
    set_cursor(2, 0)
    -- Set '`<' and '`>' marks
    type_keys('VV')
    type_keys({ 'g', 'c', 'i', 'p' })
    child.assert_visual_marks(2, 2)
  end)
end)

describe('Commenting current line', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
  end)

  it('works', function()
    set_lines(example_lines)
    set_cursor(1, 1)
    type_keys({ 'g', 'c', 'c' })
    eq(get_lines(0, 2), { '# aa', ' aa' })

    -- Works on empty line
    set_lines(example_lines)
    set_cursor(4, 0)
    type_keys({ 'g', 'c', 'c' })
    eq(get_lines(2, 5), { '  aa', '#', '  aa' })

    -- Supports `v:count`
    set_lines(example_lines)
    set_cursor(2, 0)
    type_keys({ '2', 'g', 'c', 'c' })
    eq(get_lines(0, 3), { 'aa', ' # aa', ' #  aa' })
  end)

  it('works with different mapping', function()
    reload_module({ mappings = { comment_line = 'gCC' } })

    set_cursor(1, 0)
    type_keys({ 'g', 'C', 'C' })
    eq(get_lines(0, 1), { '# aa' })
  end)

  it('allows dot-repeat', function()
    set_lines(example_lines)
    set_cursor(1, 1)
    type_keys({ 'g', 'c', 'c' })
    type_keys('.')
    eq(get_lines(), example_lines)

    -- Not immediate dot-repeat
    set_lines(example_lines)
    set_cursor(1, 1)
    type_keys({ 'g', 'c', 'c' })
    set_cursor(7, 0)
    type_keys('.')
    eq(get_lines(6, 7), { '# aa' })
  end)
end)

describe('Comment textobject', function()
  child.setup()
  load_module()

  before_each(function()
    set_lines(example_lines)
    child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
  end)

  it('works', function()
    set_lines({ 'aa', '# aa', '# aa', 'aa' })
    set_cursor(2, 0)
    type_keys({ 'd', 'g', 'c' })
    eq(get_lines(), { 'aa', 'aa' })
  end)

  it('does nothing when not inside textobject', function()
    -- Builtin operators
    type_keys({ 'd', 'g', 'c' })
    eq(get_lines(), example_lines)

    -- Comment operator
    -- Main problem here at time of writing happened while calling `gc` on
    -- comment textobject when not on comment line. This sets `]` mark right to
    -- the left of `[` (but not when cursor in (1, 0)).
    local validate_no_action = function(line, col)
      set_lines(example_lines)
      set_cursor(line, col)
      type_keys({ 'g', 'c', 'g', 'c' })
      eq(get_lines(), example_lines)
    end

    validate_no_action(1, 1)
    validate_no_action(2, 2)

    -- Doesn't work (but should) because both `[` and `]` are set to (1, 0)
    -- (instead of more reasonable (1, -1) or (0, 2147483647)).
    -- validate_no_action(1, 0)
  end)

  it('works with different mapping', function()
    reload_module({ mappings = { textobject = 'gC' } })

    set_lines({ 'aa', '# aa', '# aa', 'aa' })
    set_cursor(2, 0)
    type_keys({ 'd', 'g', 'C' })
    eq(get_lines(), { 'aa', 'aa' })
  end)

  it('allows dot-repeat', function()
    set_lines({ 'aa', '# aa', '# aa', 'aa', '# aa' })
    set_cursor(2, 0)
    type_keys({ 'd', 'g', 'C' })
    set_cursor(3, 0)
    type_keys('.')
    eq(get_lines(), { 'aa', 'aa' })
  end)
end)

child.stop()
