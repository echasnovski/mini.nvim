local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq = helpers.expect, helpers.expect.equality
local new_set = MiniTest.new_set

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

-- Make helpers
local reload_with_hooks = function()
  unload_module()
  child.lua('_G.pre_n = 0; _G.post_n = 0')
  child.lua([[require('mini.comment').setup({
    hooks = {
      pre = function()
        _G.pre_n = _G.pre_n + 1
        -- Allow this to successfully change 'commentstring' option
        vim.bo.commentstring = vim.bo.commentstring == '# %s' and '// %s' or '# %s'
      end,
      post = function() _G.post_n = _G.post_n + 1 end,
    },
  })]])
end

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
  eq(child.lua_get('type(_G.MiniComment)'), 'table')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniComment.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniComment.config.' .. field), value) end

  expect_config('options.ignore_blank_line', false)
  expect_config('options.start_of_line', false)
  expect_config('options.pad_comment_parts', true)
  expect_config('mappings.comment', 'gc')
  expect_config('mappings.comment_line', 'gcc')
  expect_config('mappings.textobject', 'gc')
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ mappings = { comment = 'gC' } })
  eq(child.lua_get('MiniComment.config.mappings.comment'), 'gC')
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ options = 'a' }, 'options', 'table')
  expect_config_error({ options = { ignore_blank_line = 1 } }, 'options.ignore_blank_line', 'boolean')
  expect_config_error({ options = { start_of_line = 1 } }, 'options.start_of_line', 'boolean')
  expect_config_error({ options = { pad_comment_parts = 1 } }, 'options.pad_comment_parts', 'boolean')
  expect_config_error({ mappings = 'a' }, 'mappings', 'table')
  expect_config_error({ mappings = { comment = 1 } }, 'mappings.comment', 'string')
  expect_config_error({ mappings = { comment_line = 1 } }, 'mappings.comment_line', 'string')
  expect_config_error({ mappings = { textobject = 1 } }, 'mappings.textobject', 'string')
  expect_config_error({ hooks = 'a' }, 'hooks', 'table')
  expect_config_error({ hooks = { pre = 1 } }, 'hooks.pre', 'function')
  expect_config_error({ hooks = { post = 1 } }, 'hooks.post', 'function')
end

T['setup()']['properly handles `config.mappings`'] = function()
  local has_map = function(lhs) return child.cmd_capture('omap ' .. lhs):find('MiniComment') ~= nil end
  eq(has_map('gc'), true)

  unload_module()
  child.api.nvim_del_keymap('o', 'gc')

  -- Supplying empty string should mean "don't create keymap"
  load_module({ mappings = { textobject = '' } })
  eq(has_map('gc'), false)
end

T['toggle_lines()'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines)
      child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
    end,
  },
})

T['toggle_lines()']['works'] = function()
  child.lua('MiniComment.toggle_lines(3, 5)')
  eq(get_lines(2, 5), { '  # aa', '  #', '  # aa' })

  child.lua('MiniComment.toggle_lines(3, 5)')
  eq(get_lines(2, 5), { '  aa', '', '  aa' })
end

T['toggle_lines()']['validates arguments'] = function()
  set_lines({ 'aa', 'aa', 'aa' })

  --stylua: ignore start
  expect.error(function() child.lua('MiniComment.toggle_lines(-1, 1)')    end, 'line_start.*1')
  expect.error(function() child.lua('MiniComment.toggle_lines(100, 101)') end, 'line_start.*3')
  expect.error(function() child.lua('MiniComment.toggle_lines(1, -1)')    end, 'line_end.*1')
  expect.error(function() child.lua('MiniComment.toggle_lines(1, 100)')   end, 'line_end.*3')
  expect.error(function() child.lua('MiniComment.toggle_lines(2, 1)')     end, 'line_start.*less than or equal.*line_end')
  --stylua: ignore end
end

T['toggle_lines()']["works with different 'commentstring' options"] = function()
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
end

T['toggle_lines()']['correctly computes indent'] = function()
  child.lua('MiniComment.toggle_lines(2, 4)')
  eq(get_lines(1, 4), { ' # aa', ' #  aa', ' #' })

  set_lines(example_lines)
  child.lua('MiniComment.toggle_lines(4, 4)')
  eq(get_lines(3, 4), { '#' })
end

T['toggle_lines()']['correctly detects comment/uncomment'] = function()
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
end

T['toggle_lines()']['respects `config.options.start_of_line`'] = function()
  child.lua('MiniComment.config.options.start_of_line = true')
  local lines = { ' # aa', '  # aa', '#aa', '# aa', '#  aa' }

  -- Should recognize as commented only lines with zero indent
  set_lines(lines)
  child.lua('MiniComment.toggle_lines(1, 2)')
  eq(get_lines(), { '#  # aa', '#   # aa', '#aa', '# aa', '#  aa' })
  child.lua('MiniComment.toggle_lines(1, 2)')
  eq(get_lines(), lines)

  set_lines(lines)
  child.lua('MiniComment.toggle_lines(3, 5)')
  eq(get_lines(), { ' # aa', '  # aa', 'aa', 'aa', ' aa' })
  child.lua('MiniComment.toggle_lines(3, 5)')
  eq(get_lines(), { ' # aa', '  # aa', '# aa', '# aa', '#  aa' })
end

T['toggle_lines()']['respects `config.options.ignore_blank_line`'] = function()
  child.lua('MiniComment.config.options.ignore_blank_line = true')
  local lines = { '  aa', '', '  aa', '  ', '  aa' }

  -- Should not add comment to blank (empty or with only whitespace) lines
  set_lines(lines)
  child.lua('MiniComment.toggle_lines(1, 5)')
  eq(get_lines(), { '  # aa', '', '  # aa', '  ', '  # aa' })

  -- Should ignore blank lines when deciding comment/uncomment action
  child.lua('MiniComment.toggle_lines(1, 5)')
  eq(get_lines(), lines)
end

T['toggle_lines()']['respects `config.options.pad_comment_parts`'] = function()
  child.lua('MiniComment.config.options.pad_comment_parts = false')

  local validate = function(lines_before, lines_after)
    set_lines(lines_before)
    local lua_command = string.format('MiniComment.toggle_lines(1, %s)', #lines_before)
    child.lua(lua_command)
    eq(get_lines(), lines_after)
  end

  -- No whitespace in 'commentstring'
  child.bo.commentstring = '#%s#'

  -- - Should correctly comment
  validate({ 'aa', '  aa', 'aa  ' }, { '#aa#', '#  aa#', '#aa  #' })
  validate({ '\taa', '\taa', '\taa\t' }, { '\t#aa#', '\t#aa#', '\t#aa\t#' })

  -- - Should correctly uncomment
  validate({ '# aa #', '#aa #', '# aa#', '#aa#' }, { ' aa ', 'aa ', ' aa', 'aa' })
  validate({ '#aa#', '  #aa#' }, { 'aa', '  aa' })
  validate({ '\t#aa#', '\t#aa#' }, { '\taa', '\taa' })

  -- Extra whitespace in 'commentstring'
  child.bo.commentstring = '#  %s  #'

  -- - Should correctly comment
  validate({ 'aa', '  aa', 'aa  ' }, { '#  aa  #', '#    aa  #', '#  aa    #' })
  validate({ '\taa', '\taa', '\taa\t' }, { '\t#  aa  #', '\t#  aa  #', '\t#  aa\t  #' })

  --validate({'# aa  #', '# aa #', '#  aa #'}, {'#  # aa  #  #', '#  # aa #  #', '#  #  aa #  #'})
  --
  -- - Should correctly uncomment
  validate({ '#  aa  #', '#   a   #' }, { 'aa', ' a ' })
  validate({ '  #  aa  #', '  #   a   #' }, { '  aa', '   a ' })
  validate({ '\t#  aa  #', '\t#  aa  #' }, { '\taa', '\taa' })
end

T['toggle_lines()']['uncomments on inconsistent indent levels'] = function()
  set_lines({ '# aa', ' # aa', '  # aa' })
  child.lua('MiniComment.toggle_lines(1, 3)')
  eq(get_lines(), { 'aa', ' aa', '  aa' })
end

T['toggle_lines()']['respects tabs (#20)'] = function()
  child.api.nvim_buf_set_option(0, 'expandtab', false)
  set_lines({ '\t\taa', '\t\taa' })

  child.lua('MiniComment.toggle_lines(1, 2)')
  eq(get_lines(), { '\t\t# aa', '\t\t# aa' })

  child.lua('MiniComment.toggle_lines(1, 2)')
  eq(get_lines(), { '\t\taa', '\t\taa' })
end

T['toggle_lines()']['adds spaces inside non-empty lines'] = function()
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
end

T['toggle_lines()']['removes trailing whitespace'] = function()
  set_lines({ 'aa', 'aa  ', '  ' })
  child.lua('MiniComment.toggle_lines(1, 3)')
  child.lua('MiniComment.toggle_lines(1, 3)')
  eq(get_lines(), { 'aa', 'aa', '' })
end

T['toggle_lines()']['applies hooks'] = function()
  set_lines({ 'aa', 'aa' })
  reload_with_hooks()
  eq(child.bo.commentstring, '# %s')

  child.lua('MiniComment.toggle_lines(1, 2)')
  -- It should allow change of `commentstring` in `pre` hook
  eq(get_lines(), { '// aa', '// aa' })
  eq(child.lua_get('_G.pre_n'), 1)
  eq(child.lua_get('_G.post_n'), 1)
end

T['toggle_lines()']['stops when hook returns `false`'] = function()
  local lines = { 'aa', 'aa' }
  set_lines(lines)

  child.lua('MiniComment.config.hooks.pre = function() return false end')
  child.lua('MiniComment.toggle_lines(1, 2)')
  eq(get_lines(), lines)

  -- Currently can't really check for `hooks.post`
end

T['toggle_lines()']['respects `vim.b.minicomment_config`'] = function()
  child.lua('vim.b.minicomment_config = { options = { start_of_line = true } }')
  set_lines({ '  # aa', '  # aa' })

  child.lua('MiniComment.toggle_lines(1, 2)')
  eq(get_lines(), { '#   # aa', '#   # aa' })
end

-- Integration tests ==========================================================
T['Commenting'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines)
      child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
    end,
  },
})

T['Commenting']['works in Normal mode'] = function()
  set_cursor(2, 2)
  type_keys('gc', 'ap')
  eq(get_lines(), { '# aa', '#  aa', '#   aa', '#', '  aa', ' aa', 'aa' })
  -- Cursor moves to start line
  eq(get_cursor(), { 1, 0 })

  -- Supports `v:count`
  set_lines(example_lines)
  set_cursor(2, 0)
  type_keys('2gc', 'ap')
  eq(get_lines(), { '# aa', '#  aa', '#   aa', '#', '#   aa', '#  aa', '# aa' })
end

T['Commenting']['works in Visual mode'] = function()
  set_cursor(2, 2)
  type_keys('v', 'ap', 'gc')
  eq(get_lines(), { '# aa', '#  aa', '#   aa', '#', '  aa', ' aa', 'aa' })

  -- Cursor moves to start line
  eq(get_cursor(), { 1, 0 })
end

T['Commenting']['works with different mapping'] = function()
  reload_module({ mappings = { comment = 'gC' } })

  set_cursor(2, 2)
  type_keys('gC', 'ap')
  eq(get_lines(), { '# aa', '#  aa', '#   aa', '#', '  aa', ' aa', 'aa' })
end

T['Commenting']["respects 'commentstring'"] = function()
  child.api.nvim_buf_set_option(0, 'commentstring', '/*%s*/')
  set_cursor(2, 2)
  type_keys('gc', 'ap')
  eq(get_lines(), { '/* aa */', '/*  aa */', '/*   aa */', '/**/', '  aa', ' aa', 'aa' })
end

T['Commenting']["works with empty 'commentstring'"] = function()
  child.api.nvim_buf_set_option(0, 'commentstring', '')
  set_cursor(2, 2)
  type_keys('gc', 'ap')
  eq(get_lines(), example_lines)
  eq(child.cmd_capture('1messages'), [[(mini.comment) Option 'commentstring' is empty.]])
end

T['Commenting']['allows dot-repeat'] = function()
  local doubly_commented = { '# # aa', '# #  aa', '# #   aa', '# #', '#   aa', '#  aa', '# aa' }

  set_lines(example_lines)
  set_cursor(2, 2)
  type_keys('gc', 'ap')
  type_keys('.')
  eq(get_lines(), doubly_commented)

  -- Not immediate dot-repeat
  set_lines(example_lines)
  set_cursor(2, 2)
  type_keys('gc', 'ap')
  set_cursor(7, 0)
  type_keys('.')
  eq(get_lines(), doubly_commented)
end

T['Commenting']['preserves marks'] = function()
  set_cursor(2, 0)
  -- Set '`<' and '`>' marks
  type_keys('VV')
  type_keys('gc', 'ip')
  child.expect_visual_marks(2, 2)
end

T['Commenting']['respects `vim.{g,b}.minicomment_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minicomment_disable = true
    set_cursor(2, 2)
    local lines = get_lines()
    type_keys('gc', 'j')
    eq(get_lines(), lines)
  end,
})

T['Commenting']['applies hooks'] = function()
  set_lines({ 'aa', 'aa' })
  set_cursor(1, 0)
  reload_with_hooks()
  eq(child.bo.commentstring, '# %s')

  type_keys('gc', 'ip')
  -- It should allow change of `commentstring` in `pre` hook
  eq(get_lines(), { '// aa', '// aa' })
  eq(child.lua_get('_G.pre_n'), 1)
  eq(child.lua_get('_G.post_n'), 1)

  -- It should work with dot-repeat
  type_keys('.')
  eq(get_lines(), { '# // aa', '# // aa' })
  eq(child.lua_get('_G.pre_n'), 2)
  eq(child.lua_get('_G.post_n'), 2)
end

T['toggle_lines()']['stops when hook returns `false`'] = function()
  local lines = { 'aa', 'aa' }
  set_lines(lines)
  set_cursor(1, 0)

  child.lua('MiniComment.config.hooks.pre = function() return false end')
  type_keys('gc', 'ip')
  eq(get_lines(), lines)

  -- Currently can't really check for `hooks.post`
end

T['Commenting']['respects `vim.b.minicomment_config`'] = function()
  if vim.fn.has('nvim-0.7') == 0 then
    MiniTest.skip('Function values inside buffer variables are not supported in Neovim<0.7.')
  end

  set_lines({ 'aa', 'aa' })
  set_cursor(1, 0)
  reload_with_hooks()
  child.lua('vim.b.minicomment_config = { hooks = { pre = function() _G.pre_n = _G.pre_n + 10 end } }')

  type_keys('gc', 'ip')
  eq(child.lua_get('_G.pre_n'), 10)
  eq(child.lua_get('_G.post_n'), 1)
end

T['Commenting current line'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines)
      child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
    end,
  },
})

T['Commenting current line']['works'] = function()
  set_lines(example_lines)
  set_cursor(1, 1)
  type_keys('gcc')
  eq(get_lines(0, 2), { '# aa', ' aa' })

  -- Works on empty line
  set_lines(example_lines)
  set_cursor(4, 0)
  type_keys('gcc')
  eq(get_lines(2, 5), { '  aa', '#', '  aa' })

  -- Supports `v:count`
  set_lines(example_lines)
  set_cursor(2, 0)
  type_keys('2gcc')
  eq(get_lines(0, 3), { 'aa', ' # aa', ' #  aa' })
end

T['Commenting current line']['works with different mapping'] = function()
  reload_module({ mappings = { comment_line = 'gCC' } })

  set_cursor(1, 0)
  type_keys('gCC')
  eq(get_lines(0, 1), { '# aa' })
end

T['Commenting current line']['allows dot-repeat'] = function()
  set_lines(example_lines)
  set_cursor(1, 1)
  type_keys('gcc')
  type_keys('.')
  eq(get_lines(), example_lines)

  -- Not immediate dot-repeat
  set_lines(example_lines)
  set_cursor(1, 1)
  type_keys('gcc')
  set_cursor(7, 0)
  type_keys('.')
  eq(get_lines(6, 7), { '# aa' })
end

T['Commenting current line']['applies hooks'] = function()
  set_lines({ 'aa', 'aa' })
  set_cursor(1, 0)
  reload_with_hooks()
  eq(child.bo.commentstring, '# %s')

  type_keys('gcc')
  -- It should allow change of `commentstring` in `pre` hook
  eq(get_lines(), { '// aa', 'aa' })
  eq(child.lua_get('_G.pre_n'), 1)
  eq(child.lua_get('_G.post_n'), 1)

  -- It should work with dot-repeat
  type_keys('.')
  eq(get_lines(), { '# // aa', 'aa' })
  eq(child.lua_get('_G.pre_n'), 2)
  eq(child.lua_get('_G.post_n'), 2)
end

T['Commenting current line']['respects `vim.b.minicomment_config`'] = function()
  if vim.fn.has('nvim-0.7') == 0 then
    MiniTest.skip('Function values inside buffer variables are not supported in Neovim<0.7.')
  end

  set_lines({ 'aa', 'aa' })
  set_cursor(1, 0)
  reload_with_hooks()
  child.lua('vim.b.minicomment_config = { hooks = { pre = function() _G.pre_n = _G.pre_n + 10 end } }')

  type_keys('gcc')
  eq(child.lua_get('_G.pre_n'), 10)
  eq(child.lua_get('_G.post_n'), 1)
end

T['Comment textobject'] = new_set({
  hooks = {
    pre_case = function()
      set_lines(example_lines)
      child.api.nvim_buf_set_option(0, 'commentstring', '# %s')
    end,
  },
})

T['Comment textobject']['works'] = function()
  set_lines({ 'aa', '# aa', '# aa', 'aa' })
  set_cursor(2, 0)
  type_keys('d', 'gc')
  eq(get_lines(), { 'aa', 'aa' })
end

T['Comment textobject']['does nothing when not inside textobject'] = function()
  -- Builtin operators
  type_keys('d', 'gc')
  eq(get_lines(), example_lines)

  -- Comment operator
  -- Main problem here at time of writing happened while calling `gc` on
  -- comment textobject when not on comment line. This sets `]` mark right to
  -- the left of `[` (but not when cursor in (1, 0)).
  local validate_no_action = function(line, col)
    set_lines(example_lines)
    set_cursor(line, col)
    type_keys('gc', 'gc')
    eq(get_lines(), example_lines)
  end

  validate_no_action(1, 1)
  validate_no_action(2, 2)

  -- Doesn't work (but should) because both `[` and `]` are set to (1, 0)
  -- (instead of more reasonable (1, -1) or (0, 2147483647)).
  -- validate_no_action(1, 0)
end

T['Comment textobject']['works with different mapping'] = function()
  reload_module({ mappings = { textobject = 'gC' } })

  set_lines({ 'aa', '# aa', '# aa', 'aa' })
  set_cursor(2, 0)
  type_keys('d', 'gC')
  eq(get_lines(), { 'aa', 'aa' })
end

T['Comment textobject']['allows dot-repeat'] = function()
  set_lines({ 'aa', '# aa', '# aa', 'aa', '# aa' })
  set_cursor(2, 0)
  type_keys('d', 'gc')
  set_cursor(3, 0)
  type_keys('.')
  eq(get_lines(), { 'aa', 'aa' })
end

T['Comment textobject']['respects `config.options.start_of_line`'] = function()
  child.lua('MiniComment.config.options.start_of_line = true')

  local lines = { ' # aa', '  # aa', '#aa', '# aa', '#  aa' }
  set_lines(lines)

  set_cursor(1, 0)
  type_keys('d', 'gc')
  eq(get_lines(), lines)

  set_cursor(3, 0)
  type_keys('d', 'gc')
  eq(get_lines(), { ' # aa', '  # aa' })
end

T['Comment textobject']['respects `vim.{g,b}.minicomment_disable`'] = new_set({
  parametrize = { { 'g' }, { 'b' } },
}, {
  test = function(var_type)
    child[var_type].minicomment_disable = true
    local lines = { 'aa', '# aa', '# aa', 'aa' }
    set_lines(lines)
    set_cursor(2, 0)
    type_keys('d', 'gc')
    eq(get_lines(), lines)
  end,
})

T['Comment textobject']['applies hooks'] = function()
  -- It should allow change of `commentstring` in `pre` hook
  set_lines({ '// aa', 'aa' })
  set_cursor(1, 0)
  reload_with_hooks()
  eq(child.bo.commentstring, '# %s')

  type_keys('d', 'gc')
  eq(get_lines(), { 'aa' })
  eq(child.lua_get('_G.pre_n'), 1)
  eq(child.lua_get('_G.post_n'), 1)

  -- It should work with dot-repeat
  set_lines({ '# aa', 'aa' })
  set_cursor(1, 0)
  type_keys('.')
  eq(get_lines(), { 'aa' })
  eq(child.lua_get('_G.pre_n'), 2)
  eq(child.lua_get('_G.post_n'), 2)

  -- Correctly not detecting absence of comment textobject should still be
  -- considered a successful usage of a textobject
  set_lines({ 'aa', 'aa' })
  set_cursor(1, 0)
  type_keys('d', 'gc')
  eq(get_lines(), { 'aa', 'aa' })
  eq(child.lua_get('_G.pre_n'), 3)
  eq(child.lua_get('_G.post_n'), 3)
end

T['Comment textobject']['respects `vim.b.minicomment_config`'] = function()
  if vim.fn.has('nvim-0.7') == 0 then
    MiniTest.skip('Function values inside buffer variables are not supported in Neovim<0.7.')
  end

  set_lines({ '// aa', 'aa' })
  set_cursor(1, 0)
  reload_with_hooks()
  child.lua('vim.b.minicomment_config = { hooks = { pre = function() _G.pre_n = _G.pre_n + 10 end } }')

  type_keys('d', 'gc')
  eq(child.lua_get('_G.pre_n'), 10)
  eq(child.lua_get('_G.post_n'), 1)
end

return T
