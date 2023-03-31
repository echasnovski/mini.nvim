--- *mini.comment* Comment lines
--- *MiniComment*
---
--- MIT License Copyright (c) 2021 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Features:
--- - Commenting in Normal mode respects |count| and is dot-repeatable.
---
--- - Comment structure is inferred from 'commentstring'.
---
--- - Allows custom hooks before and after successful commenting.
---
--- - Configurable options for some nuanced behavior.
---
--- What it doesn't do:
--- - Block and sub-line comments. This will only support per-line commenting.
---
--- - Configurable (from module) comment structure. Modify |commentstring|
---   instead. To enhance support for commenting in multi-language files, see
---   "JoosepAlviste/nvim-ts-context-commentstring" plugin along with `hooks`
---   option of this module (see |MiniComment.config|).
---
--- - Handle indentation with mixed tab and space.
---
--- - Preserve trailing whitespace in empty lines.
---
--- # Setup~
---
--- This module needs a setup with `require('mini.comment').setup({})` (replace
--- `{}` with your `config` table). It will create global Lua table
--- `MiniComment` which you can use for scripting or manually (with
--- `:lua MiniComment.*`).
---
--- See |MiniComment.config| for `config` structure and default values.
---
--- You can override runtime config settings locally to buffer inside
--- `vim.b.minicomment_config` which should have same structure as
--- `MiniComment.config`. See |mini.nvim-buffer-local-config| for more details.
---
--- # Disabling~
---
--- To disable core functionality, set `vim.g.minicomment_disable` (globally) or
--- `vim.b.minicomment_disable` (for a buffer) to `true`. Considering high number
--- of different scenarios and customization intentions, writing exact rules
--- for disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes.

-- Module definition ==========================================================
local MiniComment = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniComment.config|.
---
---@usage `require('mini.comment').setup({})` (replace `{}` with your `config` table)
MiniComment.setup = function(config)
  -- TODO: Remove after Neovim<=0.6 support is dropped
  if vim.fn.has('nvim-0.7') == 0 then
    vim.notify(
      '(mini.comment) Neovim<0.7 is soft deprecated (module works but not supported).'
        .. ' It will be deprecated after Neovim 0.9.0 release (module will not work).'
        .. ' Please update your Neovim version.'
    )
  end

  -- Export module
  _G.MiniComment = MiniComment

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniComment.config = {
  -- Options which control module behavior
  options = {
    -- Whether to ignore blank lines
    ignore_blank_line = false,

    -- Whether to recognize as comment only lines without indent
    start_of_line = false,

    -- Whether to ensure single space pad for comment parts
    pad_comment_parts = true,
  },

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    -- Toggle comment (like `gcip` - comment inner paragraph) for both
    -- Normal and Visual modes
    comment = 'gc',

    -- Toggle comment on current line
    comment_line = 'gcc',

    -- Define 'comment' textobject (like `dgc` - delete whole comment block)
    textobject = 'gc',
  },

  -- Hook functions to be executed at certain stage of commenting
  hooks = {
    -- Before successful commenting. Does nothing by default.
    pre = function() end,
    -- After successful commenting. Does nothing by default.
    post = function() end,
  },
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Main function to be mapped
---
--- It is meant to be used in expression mappings (see |map-<expr>|) to enable
--- dot-repeatability and commenting on range. There is no need to do this
--- manually, everything is done inside |MiniComment.setup()|.
---
--- It has a somewhat unintuitive logic (because of how expression mapping with
--- dot-repeatability works): it should be called without arguments inside
--- expression mapping and with argument when action should be performed.
---
---@param mode string|nil Optional string with 'operatorfunc' mode (see |g@|).
---
---@return string 'g@' if called without argument, '' otherwise (but after
---   performing action).
MiniComment.operator = function(mode)
  if H.is_disabled() then return '' end

  -- If used without arguments inside expression mapping:
  -- - Set itself as `operatorfunc` to be called later to perform action.
  -- - Return 'g@' which will then be executed resulting into waiting for a
  --   motion or text object. This textobject will then be recorded using `'[`
  --   and `']` marks. After that, `operatorfunc` is called with `mode` equal
  --   to one of "line", "char", or "block".
  -- NOTE: setting `operatorfunc` inside this function enables usage of 'count'
  -- like `10gc_` toggles comments of 10 lines below (starting with current).
  if mode == nil then
    vim.cmd('set operatorfunc=v:lua.MiniComment.operator')
    return 'g@'
  end

  -- If called with non-nil `mode`, get target region and perform comment
  -- toggling over it.
  local mark_left, mark_right = '[', ']'
  if mode == 'visual' then
    mark_left, mark_right = '<', '>'
  end

  local line_left, col_left = unpack(vim.api.nvim_buf_get_mark(0, mark_left))
  local line_right, col_right = unpack(vim.api.nvim_buf_get_mark(0, mark_right))

  -- Do nothing if "left" mark is not on the left (earlier in text) of "right"
  -- mark (indicating that there is nothing to do, like in comment textobject).
  if (line_left > line_right) or (line_left == line_right and col_left > col_right) then return end

  -- Using `vim.cmd()` wrapper to allow usage of `lockmarks` command, because
  -- raw execution will delete marks inside region (due to
  -- `vim.api.nvim_buf_set_lines()`).
  vim.cmd(string.format('lockmarks lua MiniComment.toggle_lines(%d, %d)', line_left, line_right))
  return ''
end

--- Toggle comments between two line numbers
---
--- It uncomments if lines are comment (every line is a comment) and comments
--- otherwise. It respects indentation and doesn't insert trailing
--- whitespace. Toggle commenting not in visual mode is also dot-repeatable
--- and respects |count|.
---
--- Before successful commenting it executes `config.hooks.pre`.
--- After successful commenting it executes `config.hooks.post`.
--- If hook returns `false`, any further action is terminated.
---
--- # Notes~
---
--- 1. Currently call to this function will remove marks inside written range.
---    Use |lockmarks| to preserve marks.
---
---@param line_start number Start line number (inclusive from 1 to number of lines).
---@param line_end number End line number (inclusive from 1 to number of lines).
MiniComment.toggle_lines = function(line_start, line_end)
  if H.is_disabled() then return end

  local n_lines = vim.api.nvim_buf_line_count(0)
  if not (1 <= line_start and line_start <= n_lines and 1 <= line_end and line_end <= n_lines) then
    error(('(mini.comment) `line_start` and `line_end` should be within range [1; %s].'):format(n_lines))
  end
  if not (line_start <= line_end) then
    error('(mini.comment) `line_start` should be less than or equal to `line_end`.')
  end

  local config = H.get_config()
  if config.hooks.pre() == false then return end

  local comment_parts = H.make_comment_parts()
  local lines = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)
  local indent, is_comment = H.get_lines_info(lines, comment_parts, H.get_config().options)

  local f
  if is_comment then
    f = H.make_uncomment_function(comment_parts)
  else
    f = H.make_comment_function(comment_parts, indent)
  end

  for n, l in pairs(lines) do
    lines[n] = f(l)
  end

  -- NOTE: This function call removes marks inside written range. To write
  -- lines in a way that saves marks, use one of:
  -- - `lockmarks` command when doing mapping (current approach).
  -- - `vim.fn.setline(line_start, lines)`, but this is **considerably**
  --   slower: on 10000 lines 280ms compared to 40ms currently.
  vim.api.nvim_buf_set_lines(0, line_start - 1, line_end, false, lines)

  if config.hooks.post() == false then return end
end

--- Comment textobject
---
--- This selects all commented lines adjacent to cursor line (if it itself is
--- commented). Designed to be used with operator mode mappings (see |mapmode-o|).
---
--- Before successful textobject usage it executes `config.hooks.pre`.
--- After successful textobject usage it executes `config.hooks.post`.
--- If hook returns `false`, any further action is terminated.
MiniComment.textobject = function()
  if H.is_disabled() then return end

  local config = H.get_config()
  if config.hooks.pre() == false then return end

  local comment_parts = H.make_comment_parts()
  local comment_check = H.make_comment_check(comment_parts)
  local line_cur = vim.api.nvim_win_get_cursor(0)[1]

  if comment_check(vim.fn.getline(line_cur)) then
    local line_start = line_cur
    while (line_start >= 2) and comment_check(vim.fn.getline(line_start - 1)) do
      line_start = line_start - 1
    end

    local line_end = line_cur
    local n_lines = vim.api.nvim_buf_line_count(0)
    while (line_end <= n_lines - 1) and comment_check(vim.fn.getline(line_end + 1)) do
      line_end = line_end + 1
    end

    -- This visual selection doesn't seem to change `'<` and `'>` marks when
    -- executed as `onoremap` mapping
    vim.cmd(string.format('normal! %dGV%dG', line_start, line_end))
  end

  if config.hooks.post() == false then return end
end

-- Helper data ================================================================
-- Module default config
H.default_config = MiniComment.config

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  -- Validate per nesting level to produce correct error message
  vim.validate({
    options = { config.options, 'table' },
    mappings = { config.mappings, 'table' },
    hooks = { config.hooks, 'table' },
  })

  vim.validate({
    ['options.ignore_blank_line'] = { config.options.ignore_blank_line, 'boolean' },
    ['options.start_of_line'] = { config.options.start_of_line, 'boolean' },
    ['options.pad_comment_parts'] = { config.options.pad_comment_parts, 'boolean' },
    ['mappings.comment'] = { config.mappings.comment, 'string' },
    ['mappings.comment_line'] = { config.mappings.comment_line, 'string' },
    ['mappings.textobject'] = { config.mappings.textobject, 'string' },
    ['hooks.pre'] = { config.hooks.pre, 'function' },
    ['hooks.post'] = { config.hooks.post, 'function' },
  })

  return config
end

H.apply_config = function(config)
  MiniComment.config = config

  -- Make mappings
  H.map('n', config.mappings.comment, 'v:lua.MiniComment.operator()', { expr = true, desc = 'Comment' })
  H.map(
    'x',
    config.mappings.comment,
    -- Using `:<c-u>` instead of `<cmd>` as latter results into executing before
    -- proper update of `'<` and `'>` marks which is needed to work correctly.
    [[:<c-u>lua MiniComment.operator('visual')<cr>]],
    { desc = 'Comment selection' }
  )
  H.map('n', config.mappings.comment_line, 'v:lua.MiniComment.operator() . "_"', { expr = true, desc = 'Comment line' })
  H.map('o', config.mappings.textobject, '<cmd>lua MiniComment.textobject()<cr>', { desc = 'Comment textobject' })
end

H.is_disabled = function() return vim.g.minicomment_disable == true or vim.b.minicomment_disable == true end

H.get_config = function(config)
  return vim.tbl_deep_extend('force', MiniComment.config, vim.b.minicomment_config or {}, config or {})
end

-- Core implementations -------------------------------------------------------
H.make_comment_parts = function()
  local options = H.get_config().options

  local cs = vim.api.nvim_buf_get_option(0, 'commentstring')

  if cs == '' then
    vim.api.nvim_echo({ { '(mini.comment) ', 'WarningMsg' }, { [[Option 'commentstring' is empty.]] } }, true, {})
    return { left = '', right = '' }
  end

  -- Assumed structure of 'commentstring':
  -- <space> <left> <'%s'> <right> <space>
  -- So this extracts parts without surrounding whitespace
  local left, right = cs:match('^%s*(.*)%%s(.-)%s*$')
  -- Trim comment parts from inner whitespace to ensure single space pad
  if options.pad_comment_parts then
    left, right = vim.trim(left), vim.trim(right)
  end
  return { left = left, right = right }
end

H.make_comment_check = function(comment_parts)
  local l, r = comment_parts.left, comment_parts.right
  -- String is commented if it has structure:
  -- <possible space> <left> <anything> <right> <space>
  local start_blank = H.get_config().options.start_of_line and '' or '%s-'
  local regex = '^' .. start_blank .. vim.pesc(l) .. '.*' .. vim.pesc(r) .. '%s-$'

  return function(line) return line:find(regex) ~= nil end
end

H.get_lines_info = function(lines, comment_parts, options)
  local n_indent, n_indent_cur = math.huge, math.huge
  local indent, indent_cur

  local is_comment = true
  local comment_check = H.make_comment_check(comment_parts)
  local ignore_blank_line = options.ignore_blank_line

  for _, l in pairs(lines) do
    -- Update lines indent: minimum of all indents except blank lines
    _, n_indent_cur, indent_cur = l:find('^(%s*)')
    local is_blank = n_indent_cur == l:len()

    if n_indent_cur < n_indent and not is_blank then
      -- NOTE: Copy of actual indent instead of recreating it with `n_indent`
      -- allows to handle both tabs and spaces
      n_indent = n_indent_cur
      indent = indent_cur
    end

    -- Update comment info: lines are comment if every single line is comment
    -- Ignore blank lines if corresponding option is set to `true`
    if not (ignore_blank_line and is_blank) then is_comment = is_comment and comment_check(l) end
  end

  -- `indent` can still be `nil` in case all `lines` are empty
  return indent or '', is_comment
end

H.make_comment_function = function(comment_parts, indent)
  local options = H.get_config().options

  -- NOTE: this assumes that indent doesn't mix tabs with spaces
  local nonindent_start = indent:len() + 1

  local l, r = comment_parts.left, comment_parts.right
  local lpad = (options.pad_comment_parts and l ~= '') and ' ' or ''
  local rpad = (options.pad_comment_parts and r ~= '') and ' ' or ''

  local blank_comment = indent .. l .. r

  -- Escape literal '%' symbols in comment parts (like in LaTeX) to be '%%'
  -- because they have special meaning in `string.format` input. NOTE: don't
  -- use `vim.pesc()` here because it also escapes other special characters
  -- (like '-', '*', etc.).
  local l_esc, r_esc = l:gsub('%%', '%%%%'), r:gsub('%%', '%%%%')
  local left = options.start_of_line and (l_esc .. indent) or (indent .. l_esc)
  local nonblank_format = left .. lpad .. '%s' .. rpad .. r_esc

  local ignore_blank_line = options.ignore_blank_line
  return function(line)
    -- Line is blank if it doesn't have anything except whitespace
    if line:find('^%s*$') ~= nil then return ignore_blank_line and line or blank_comment end

    return string.format(nonblank_format, line:sub(nonindent_start))
  end
end

H.make_uncomment_function = function(comment_parts)
  local options = H.get_config().options

  local l, r = comment_parts.left, comment_parts.right
  local lpad = (options.pad_comment_parts and l ~= '') and '[ ]?' or ''
  local rpad = (options.pad_comment_parts and r ~= '') and '[ ]?' or ''

  -- Usage of `lpad` and `rpad` as possbile single space enables uncommenting
  -- of commented empty lines without trailing whitespace (like '  #').
  local uncomment_regex = string.format('^(%%s*)%s%s(.-)%s%s%%s-$', vim.pesc(l), lpad, rpad, vim.pesc(r))

  return function(line)
    local indent, new_line = string.match(line, uncomment_regex)
    -- Return original if line is not commented
    if new_line == nil then return line end
    -- Remove indent if line is a commented empty line
    if new_line == '' then indent = '' end
    return ('%s%s'):format(indent, new_line)
  end
end

-- Utilities ------------------------------------------------------------------
H.map = function(mode, key, rhs, opts)
  if key == '' then return end

  opts = vim.tbl_deep_extend('force', { noremap = true, silent = true }, opts or {})

  -- Use mapping description only in Neovim>=0.7
  if vim.fn.has('nvim-0.7') == 0 then opts.desc = nil end

  vim.api.nvim_set_keymap(mode, key, rhs, opts)
end

return MiniComment
