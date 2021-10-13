-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom somewhat minimal and fast surrounding Lua plugin. This is mostly
--- a reimplementation of the core features of 'machakann/vim-sandwich' with a
--- couple more on top (find surrounding, highlight surrounding).
---
--- Features:
--- - Actions (all of them are dot-repeatable out of the box):
---     - Add surrounding with `sa` (in visual mode or on motion).
---     - Delete surrounding with `sd`.
---     - Replace surrounding with `sr`.
---     - Find surrounding with `sf` or `sF` (move cursor right or left).
---     - Highlight surrounding with `sh`.
---     - Change number of neighbor lines with `sn` (see algorithm details).
--- - Surrounding is identified by a single character as both 'input' (in
---   `delete` and `replace` start) and 'output' (in `add` and `replace` end):
---     - 'f' - function call (string of letters or '_' or '.' followed by
---       balanced '()'). In 'input' finds function call, in 'output'
---       prompts user to enter function name.
---     - 'i' - interactive. Prompts user to enter left and right parts.
---     - 't' - tag. In 'input' finds tab with same identifier, in 'output'
---       prompts user to enter tag name.
---     - All symbols in brackets '()', '[]', '{}', '<>'. In 'input' represents
---       balanced brackets, in 'output' - left and right parts of brackets.
---     - All other alphanumeric, punctuation, or space characters represent
---       surrounding with identical left and right parts.
---
--- Known issues which won't be resolved:
--- - Search for surrounding is done using Lua patterns (regex-like approach).
---   So certain amount of false positives should be expected.
--- - When searching for 'input' surrounding, there is no distinction if it is
---   inside string or comment. So in this case there will be not proper match
---   for a function call: 'f(a = ")", b = 1)'.
--- - Tags are searched using regex-like methods, so issues are inevitable.
---   Overall it is pretty good, but certain cases won't work. Like self-nested
---   tags won't match correctly on both ends: '<a><a></a></a>'.
---
--- # Setup
---
--- This module needs a setup with `require('mini.surround').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`:
--- <pre>
--- {
---   -- Number of lines within which surrounding is searched
---   n_lines = 20,
---
---   -- Duration (in ms) of highlight when calling `MiniSurround.highlight()`
---   highlight_duration = 500,
---
---   -- Pattern to match function name in 'function call' surrounding
---   -- By default it is a string of letters, '_' or '.'
---   funname_pattern = '[%w_%.]+',
---
---   -- Mappings. Use `''` (empty string) to disable one.
---   mappings = {
---     add = 'sa',           -- Add surrounding
---     delete = 'sd',        -- Delete surrounding
---     find = 'sf',          -- Find surrounding (to the right)
---     find_left = 'sF',     -- Find surrounding (to the left)
---     highlight = 'sh',     -- Highlight surrounding
---     replace = 'sr',       -- Replace surrounding
---     update_n_lines = 'sn' -- Update `n_lines`
---   }
--- }
--- </pre>
---
--- # Example usage
---
--- - `saiw)` - add (`sa`) for inner word (`iw`) parenthesis (`)`).
--- - `saiwi[[<CR>]]<CR>` - add (`sa`) for inner word (`iw`) interactive
---   surrounding (`i`): `[[` for left and `]]` for right.
--- - `sdf` - delete (`sd`) surrounding function call (`f`).
--- - `sr)tdiv<CR>` - replace (`sr`) surrounding parenthesis (`)`) with tag
---   (`t`) with identifier 'div' (`div<CR>` in command line prompt).
--- - `sff` - find right (`sf`) part of surrounding function call (`f`).
--- - `sh}` - highlight (`sh`) for a brief period of time surrounding curly
---   brackets (`}`)
---
--- # Algorithm design
---
--- - Adding 'output' surrounding has a fairly straightforward algorithm:
---     - Determine places for left and right parts (via `<>` or `[]` marks).
---     - Determine left and right parts of surrounding.
---     - Properly add.
--- - Finding 'input' surrounding is a lot more complicated and is a reason why
---   this implementation is only somewhat minimal. In a nutshell, current
---   algorithm `searches in the neighborhood lines based on a certain pattern
---   a _smallest_ match that covers cursor`. More detailed:
---     - Extract neighborhood of cursor line: no more than
---       `MiniSurround.config.n_lines` before, cursor line itself, no more than
---       `MiniSurround.config.n_lines` after.
---     - Convert it to '1d neighborhood' by concatenating with '\n' delimiter.
---       Compute location of current cursor position in this line.
---     - Given Lua pattern for a 'input' surrounding, search for a smallest
---       (with minimal width) match that covers cursor position. This is an
---       iterative procedure, duration of which heavily depends on the length
---       of '1d neighborhood' and frequency of pattern matching. If no match is
---       found, there is no surrounding.
---     - Compute parts of '1d neighborhood' that represent left and right part
---       of found surrounding. This is done by using 'extract' pattern computed
---       for every type of surrounding.
---     - Convert '1d offsets' of found parts to their positions in buffer.
---   Actual search is done firstly on cursor line (as it is the most frequent
---   usage) and only then searches in neighborhood.
---
--- # Highlight groups
---
--- 1. `MiniSurround` - highlighting of requested surrounding.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling
---
--- To disable, set `g:minisurround_disable` (globally) or
--- `b:minisurround_disable` (for a buffer) to `v:true`.
---@brief ]]
---@tag MiniSurround mini.surround

-- Module and its helper
local MiniSurround = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.surround').setup({})` (replace `{}` with your `config` table)
function MiniSurround.setup(config)
  -- Export module
  _G.MiniSurround = MiniSurround

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Create highlighting
  vim.api.nvim_exec([[hi link MiniSurround IncSearch]], false)
end

-- Module config
MiniSurround.config = {
  -- Number of lines within which surrounding is searched
  n_lines = 20,

  -- Duration of highlight when calling `MiniSurround.highlight()`
  highlight_duration = 500,

  -- Pattern to match function name in 'function call' surrounding
  funname_pattern = '[%w_%.]+',

  -- Mappings
  mappings = {
    add = 'sa', -- Add surrounding
    delete = 'sd', -- Delete surrounding
    find = 'sf', -- Find surrounding (to the right)
    find_left = 'sF', -- Find surrounding (to the left)
    highlight = 'sh', -- Highlight surrounding
    replace = 'sr', -- Replace surrounding
    update_n_lines = 'sn', -- Update `n_lines`
  },
}

-- Module functionality
--- Surround operator
---
--- Main function to be used in expression mappings. No need to use it
--- directly, everything is setup in |MiniSurround.setup|.
---
---@param task string: Name of surround task.
---@param cache table: Task cache.
function MiniSurround.operator(task, cache)
  if H.is_disabled() then
    return ''
  end

  H.cache = cache or {}

  vim.cmd(string.format('set operatorfunc=v:lua.MiniSurround.%s', task))
  return 'g@'
end

--- Add surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
---
---@param mode string: Mapping mode (normal by default).
function MiniSurround.add(mode)
  -- Needed to disable in visual mode
  if H.is_disabled() then
    return ''
  end

  -- Get marks' positions based on current mode
  local marks = H.get_marks_pos(mode)

  -- Get surround info. Try take from cache only in not visual mode (as there
  -- is no intended dot-repeatability).
  local surr_info
  if mode == 'visual' then
    surr_info = H.get_surround_info('output', false)
  else
    surr_info = H.get_surround_info('output', true)
  end
  if surr_info == nil then
    return ''
  end

  -- Add surrounding. Begin insert with 'end' to not break column numbers
  ---- Insert after the right mark (`+ 1` is for that)
  H.insert_into_line(marks.second.line, marks.second.col + 1, surr_info.right)
  H.insert_into_line(marks.first.line, marks.first.col, surr_info.left)

  -- Tweak cursor position
  H.cursor_adjust(marks.first.line, marks.first.col + surr_info.left:len())
end

--- Delete surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
function MiniSurround.delete()
  -- Find input surrounding
  local surr = H.find_surrounding(H.get_surround_info('input', true))
  if surr == nil then
    return ''
  end

  -- Delete surrounding. Begin with right to not break column numbers
  H.delete_linepart(surr.right)
  H.delete_linepart(surr.left)

  -- Tweak cursor position
  H.cursor_adjust(surr.left.line, surr.left.from)
end

--- Replace surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
function MiniSurround.replace()
  -- Find input surrounding
  local surr = H.find_surrounding(H.get_surround_info('input', true))
  if surr == nil then
    return ''
  end

  -- Get output surround info
  local new_surr_info = H.get_surround_info('output', true)
  if new_surr_info == nil then
    return ''
  end

  -- Delete input surrounding. Begin with right to not break column numbers
  H.delete_linepart(surr.right)
  H.delete_linepart(surr.left)

  -- Compute adjustment for adding right surrounding
  local n_del_left = 0
  if surr.left.line == surr.right.line then
    n_del_left = surr.left.to - surr.left.from + 1
  end

  -- Add output surrounding. Begin insert with 'end' to not break column numbers
  H.insert_into_line(surr.right.line, surr.right.from - n_del_left, new_surr_info.right)
  H.insert_into_line(surr.left.line, surr.left.from, new_surr_info.left)

  -- Tweak cursor position
  H.cursor_adjust(surr.left.line, surr.left.from + new_surr_info.left:len())
end

--- Find surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
function MiniSurround.find()
  -- Find surrounding
  local surr = H.find_surrounding(H.get_surround_info('input', true))
  if surr == nil then
    return ''
  end

  -- Make list of positions to cycle through
  local pos_list = H.linepart_to_pos_table(surr.left)
  local pos_table_right = H.linepart_to_pos_table(surr.right)
  for _, v in pairs(pos_table_right) do
    table.insert(pos_list, v)
  end

  -- Cycle cursor through positions
  local dir = H.cache.direction or 'right'
  H.cursor_cycle(pos_list, dir)

  -- Open 'enough folds' to show cursor
  vim.cmd([[normal! zv]])
end

--- Highlight surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
function MiniSurround.highlight()
  -- Find surrounding
  local surr = H.find_surrounding(H.get_surround_info('input', true))
  if surr == nil then
    return ''
  end

  -- Highlight surrounding
  vim.api.nvim_buf_add_highlight(0, H.ns_id, 'MiniSurround', surr.left.line - 1, surr.left.from - 1, surr.left.to)
  vim.api.nvim_buf_add_highlight(0, H.ns_id, 'MiniSurround', surr.right.line - 1, surr.right.from - 1, surr.right.to)

  vim.defer_fn(function()
    vim.api.nvim_buf_clear_namespace(0, H.ns_id, surr.left.line - 1, surr.right.line)
  end, MiniSurround.config.highlight_duration)
end

--- Update `MiniSurround.config.n_lines`
---
--- Convenient wrapper for updating `MiniSurround.config.n_lines` in case the
--- default one is not appropriate.
function MiniSurround.update_n_lines()
  if H.is_disabled() then
    return ''
  end

  local n_lines = H.user_input('New number of neighbor lines', MiniSurround.config.n_lines)
  n_lines = math.floor(tonumber(n_lines) or MiniSurround.config.n_lines)
  MiniSurround.config.n_lines = n_lines
end

-- Helper data
---- Module default config
H.default_config = MiniSurround.config

---- Namespace for highlighting
H.ns_id = vim.api.nvim_create_namespace('MiniSurround')

---- Table of non-special surroundings
H.surroundings = setmetatable({
  -- Brackets that need balancing
  ['('] = { find = '%b()', left = '(', right = ')' },
  [')'] = { find = '%b()', left = '(', right = ')' },
  ['['] = { find = '%b[]', left = '[', right = ']' },
  [']'] = { find = '%b[]', left = '[', right = ']' },
  ['{'] = { find = '%b{}', left = '{', right = '}' },
  ['}'] = { find = '%b{}', left = '{', right = '}' },
  ['<'] = { find = '%b<>', left = '<', right = '>' },
  ['>'] = { find = '%b<>', left = '<', right = '>' },
}, {
  __index = function(table, key)
    local key_esc = vim.pesc(key)
    return { find = key_esc .. '.-' .. key_esc, left = key, right = key }
  end,
})

---- Cache for dot-repeatability. This table is currently used with these keys:
---- - 'input' - surround info for searching (in 'delete' and 'replace' start).
---- - 'output' - surround info for adding (in 'add' and 'replace' end).
---- - 'direction' - direction in which `MiniSurround.find()` should go. Used
----   to enable same `operatorfunc` pattern for dot-repeatability.
H.cache = {}

---- Helper table for `H.user_surround_id()` to keep track of help messages
H.needs_help_msg = {}

-- Helper functions
---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({
    n_lines = { config.n_lines, 'number' },
    highlight_duration = { config.highlight_duration, 'number' },
    funname_pattern = { config.funname_pattern, 'string' },
    mappings = { config.mappings, 'table' },
    ['mappings.add'] = { config.mappings.add, 'string' },
    ['mappings.delete'] = { config.mappings.delete, 'string' },
    ['mappings.find'] = { config.mappings.find, 'string' },
    ['mappings.find_left'] = { config.mappings.find_left, 'string' },
    ['mappings.highlight'] = { config.mappings.highlight, 'string' },
    ['mappings.replace'] = { config.mappings.replace, 'string' },
    ['mappings.update_n_lines'] = { config.mappings.update_n_lines, 'string' },
  })

  return config
end

function H.apply_config(config)
  MiniSurround.config = config

  -- Make mappings
  -- NOTE: In mappings construct ` . ' '` "disables" motion required by `g@`.
  -- It is used to enable dot-repeatability.
  H.keymap(
    'n',
    config.mappings.add,
    [[v:lua.MiniSurround.operator('add')]],
    { expr = true, noremap = true, silent = true }
  )
  H.keymap(
    'x',
    config.mappings.add,
    [[:<c-u>lua MiniSurround.add('visual')<cr>]],
    { noremap = true, silent = true }
  )
  H.keymap(
    'n',
    config.mappings.delete,
    [[v:lua.MiniSurround.operator('delete') . ' ']],
    { expr = true, noremap = true, silent = true }
  )
  H.keymap(
    'n',
    config.mappings.replace,
    [[v:lua.MiniSurround.operator('replace') . ' ']],
    { expr = true, noremap = true, silent = true }
  )
  H.keymap(
    'n',
    config.mappings.find,
    [[v:lua.MiniSurround.operator('find', {'direction': 'right'}) . ' ']],
    { expr = true, noremap = true, silent = true }
  )
  H.keymap(
    'n',
    config.mappings.find_left,
    [[v:lua.MiniSurround.operator('find', {'direction': 'left'}) . ' ']],
    { expr = true, noremap = true, silent = true }
  )
  H.keymap(
    'n',
    config.mappings.highlight,
    [[v:lua.MiniSurround.operator('highlight') . ' ']],
    { expr = true, noremap = true, silent = true }
  )
  H.keymap(
    'n',
    config.mappings.update_n_lines,
    [[<cmd>lua MiniSurround.update_n_lines()<cr>]],
    { noremap = true, silent = true }
  )
end

function H.is_disabled()
  return vim.g.minisurround_disable == true or vim.b.minisurround_disable == true
end

---- Find surrounding
---- NOTE: more simple approach for `find_surrounding()` would have been to use
---- combination of `searchpairpos()` (to search for balanced pair) and
---- `searchpos()` (to search end of balanced search and for unbalanced pairs).
---- However, there are several problems with it:
---- - It is slower (around 2-5 times) than current Lua pattern approach.
---- - It has limitations when dealing with crucial 'function call' search.
----   Function call is defined as 'non-empty function name followed by
----   balanced pair of "(" and ")"'. Naive use of `searchpairpos()` is to use
----   `searchpairpos('\w\+(', '', ')')` which works most of the time.
----   However, in example `foo(a = (1 + 1), b = c(1, 2))` this will match
----   `o(a = (1 + 1)` when cursor is on 'a'. This is because '(' inside it is
----   not recognized for balancing because it doesn't match '\w\+('.
----
---- Vim's approach also has some upsides:
---- - `searchpairpos()` allows skipping of certain matches, like if it is
----   inside string or comment. It works decently well with example from help
----   (with `synIDattr`, etc.) but this only works when Vim's builtin
----   highlighting is used. When treesitter's highlighting is active, this
----   doesn't work.
----
---- All in all, using Vim's builtin functions is doable, but leads to roughly
---- same efforts as Lua pattern approach.
function H.find_surrounding(surround_info)
  -- `surround_info` should have `find` field with surrounding pattern. If
  -- needed, it should also have a `extract` field with extract pattern for two
  -- parts of surrounding assuming they are at the start and end of string.
  if surround_info == nil then
    return nil
  end
  local n_lines = MiniSurround.config.n_lines

  -- First try only current line as it is the most common use case
  local surr = H.find_surrounding_in_neighborhood(surround_info, 0)
    or H.find_surrounding_in_neighborhood(surround_info, n_lines)

  if surr == nil then
    H.notify(string.format([[No surrounding '%s' found within %d lines.]], surround_info.id, n_lines))
  end

  return surr
end

---- Work with operator marks
function H.get_marks_pos(mode)
  -- Region is inclusive on both ends
  local mark1, mark2
  if mode == 'visual' then
    mark1, mark2 = '<', '>'
  else
    mark1, mark2 = '[', ']'
  end

  local pos1 = vim.api.nvim_buf_get_mark(0, mark1)
  local pos2 = vim.api.nvim_buf_get_mark(0, mark2)

  -- Tweak position in linewise mode as marks are placed on the first column
  local is_linewise = (mode == 'line') or (mode == 'visual' and vim.fn.visualmode() == 'V')
  if is_linewise then
    -- Move start mark past the indent
    pos1[2] = vim.fn.indent(pos1[1])
    -- Move end mark to the last character (` - 2` here because `col()` returns
    -- column right after the last 1-based column)
    pos2[2] = vim.fn.col({ pos2[1], '$' }) - 2
  end

  -- Make columns 1-based instead of 0-based. This is needed because
  -- `nvim_buf_get_mark()` returns the first 0-based byte of mark symbol and
  -- all the following operations are done with Lua's 1-based indexing.
  pos1[2], pos2[2] = pos1[2] + 1, pos2[2] + 1

  -- Tweak second position to respect multibyte characters. Reasoning:
  -- - These positions will be used with 'insert_into_line(line, col, text)' to
  --   add some text. Its logic is `line[1:(col - 1)] + text + line[col:]`,
  --   where slicing is meant on byte level.
  -- - For the first mark we want the first byte of symbol, then text will be
  --   insert to the left of the mark.
  -- - For the second mark we want last byte of symbol. To add surrounding to
  --   the right, use `pos2[2] + 1`.
  local line2 = vim.fn.getline(pos2[1])
  ---- This returns the last byte inside character because
  ---- `vim.str_byteindex()` 'rounds upwards to the end of that sequence'.
  pos2[2] = vim.str_byteindex(
    line2,
    -- Use `math.min()` because it might lead to 'index out of range' error
    -- when mark is positioned at the end of line (that extra space which is
    -- selected when selecting with `v$`)
    vim.str_utfindex(line2, math.min(#line2, pos2[2]))
  )

  return {
    first = { line = pos1[1], col = pos1[2] },
    second = { line = pos2[1], col = pos2[2] },
  }
end

---- Work with cursor
function H.cursor_adjust(line, col)
  local cur_pos = vim.api.nvim_win_get_cursor(0)

  -- Only adjust cursor if it is on the same line
  if cur_pos[1] ~= line then
    return
  end

  vim.api.nvim_win_set_cursor(0, { line, col - 1 })
end

function H.compare_pos(pos1, pos2)
  if pos1.line < pos2.line then
    return '<'
  end
  if pos1.line > pos2.line then
    return '>'
  end
  if pos1.col < pos2.col then
    return '<'
  end
  if pos1.col > pos2.col then
    return '>'
  end
  return '='
end

function H.cursor_cycle(pos_list, dir)
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  cur_pos = { line = cur_pos[1], col = cur_pos[2] + 1 }

  local compare, to_left, to_right, res_pos
  -- NOTE: `pos_list` should be an increasingly ordered list of positions
  for _, pos in pairs(pos_list) do
    compare = H.compare_pos(cur_pos, pos)
    -- Take position when moving to left if cursor is strictly on right.
    -- This will lead to updating `res_pos` until the rightmost such position.
    to_left = compare == '>' and dir == 'left'
    -- Take position when moving to right if cursor is strictly on left.
    -- This will update result only once leading to the leftmost such position.
    to_right = res_pos == nil and compare == '<' and dir == 'right'
    if to_left or to_right then
      res_pos = pos
    end
  end

  res_pos = res_pos or (dir == 'right' and pos_list[1] or pos_list[#pos_list])
  vim.api.nvim_win_set_cursor(0, { res_pos.line, res_pos.col - 1 })
end

---- Work with user input
function H.notify(msg)
  vim.notify(string.format('(mini.surround) %s', msg))
end

function H.user_surround_id(sur_type)
  -- Get from user single character surrounding identifier
  ---- Helper message needs to depend on surrounding type to work better in
  ---- 'replace' case: when input surrounding was entered before needing a
  ---- message but output wasn't. If this is a simple boolean, there will be
  ---- two consecutive messages (even if first one already is not needed).
  H.needs_help_msg[sur_type] = true
  vim.defer_fn(function()
    if not H.needs_help_msg[sur_type] then
      return
    end
    local msg = string.format('Enter %s surrounding identifier (single character) ', sur_type)
    H.notify(msg)
  end, 1000)
  local char = vim.fn.getchar()
  H.needs_help_msg = {}

  -- Terminate if input is `<Esc>`
  if char == 27 then
    return nil
  end

  if type(char) == 'number' then
    char = vim.fn.nr2char(char)
  end
  if char:find('^[%w%p%s]$') == nil then
    H.notify([[Input must be single character: alphanumeric, punctuation, or space.]])
    return nil
  end

  return char
end

function H.user_input(msg, text)
  return vim.fn.input('(mini.surround) ' .. msg .. ': ', text or '')
end

---- Work with line parts and text.
---- Line part - table with fields `line`, `from`, `to`. Represent part of line
---- from `from` character (inclusive) to `to` character (inclusive).
function H.new_linepart(pos_left, pos_right)
  if pos_left.line ~= pos_right.line then
    H.notify('Positions span over multiple lines.')
    return nil
  end

  return { line = pos_left.line, from = pos_left.col, to = pos_right.col }
end

function H.linepart_to_pos_table(linepart)
  local res = { { line = linepart.line, col = linepart.from } }
  if linepart.from ~= linepart.to then
    table.insert(res, { line = linepart.line, col = linepart.to })
  end
  return res
end

function H.delete_linepart(linepart)
  local line = vim.fn.getline(linepart.line)
  local new_line = line:sub(1, linepart.from - 1) .. line:sub(linepart.to + 1)
  vim.fn.setline(linepart.line, new_line)
end

function H.insert_into_line(line_num, col, text)
  -- Important to remember when working with multibyte characters: `col` here
  -- represents byte index, not character
  local line = vim.fn.getline(line_num)
  local new_line = line:sub(1, col - 1) .. text .. line:sub(col)
  vim.fn.setline(line_num, new_line)
end

---- Work with regular expressions
------ Find the smallest (with the smallest width) covering (left and right
------ offsets in `line`) which inclused `offset` and within which `pattern` is
------ matched. Output is a table with two numbers (or `nil` in case of no
------ covering match): indexes of left and right parts of match. They have two
------ properties:
------ - `left <= offset <= right`.
------ - `line:sub(left, right)` matches `'^' .. pattern .. '$'`.
function H.find_smallest_covering(line, pattern, offset)
  local left, right, match_left, match_right
  local stop = false
  local init = 1
  while not stop do
    match_left, match_right = line:find(pattern, init)
    if (match_left == nil) or (match_left > offset) then
      -- Stop if first match is gone over `offset` to the right
      stop = true
    elseif match_right < offset then
      -- Try find covering match. Originally this was `init = math.max(init +
      -- 1, match_right)`.  Generally, this works fine, but there is an edge
      -- case with tags.  Consider example: '<a>hello<b>world</a></b>' and
      -- cursor inside '</b>'.  First match is '<a>...</a>'. It doesn't cover
      -- cursor, this branch is
      -- executed. If move to `match_right`, next iteration will match inside
      -- '></b>' and will find no match.
      -- This increases execution time, but tolerably so. On the plus side,
      -- this edge case currently gives wrong result even in 'vim-sandwich' :)
      init = match_left + 1
    else
      -- Successful match: match_left <= offset <= match_right
      -- Update result only if current has smaller width. This ensures
      -- "smallest width" condition. Useful when pattern is something like
      -- `".-"` and `line = '"a"aa"', offset = 3`.
      if (left == nil) or (match_right - match_left < right - left) then
        left, right = match_left, match_right
      end
      -- Try find smaller match
      init = match_left + 1
    end
  end

  if left == nil then
    return nil
  end

  -- Try make match even smaller. Can happen if there is `+` flag at the end.
  -- For example `line = '((()))', pattern = '%(.-%)+', offset = 3`.
  local line_pattern = '^' .. pattern .. '$'
  while left < right and line:sub(left, right - 1):find(line_pattern) do
    right = right - 1
  end

  return { left = left, right = right }
end

------ Extend covering to capture possible whole groups with count modifiers.
------ Primar usage is to match whole function call with pattern
------ `[%w_%.]+%b()`. Example:
------ `covering = {left = 4, right = 10}, line = '(aaa(b()b))',
------ pattern = '%g+%b()', direction = 'left'` should return
------ `{left = 2, right = 10}`.
------ NOTE: when used for pattern without count modifiers, can remove
------ "smallest width" property. For example:
------ `covering = {left = 2, right = 5}, line = '((()))',
------ pattern = '%(%(.-%)%)', direction = 'left'`
function H.extend_covering(covering, line, pattern, direction)
  local left, right = covering.left, covering.right
  local line_pattern = '^' .. pattern .. '$'
  local n = line:len()
  local is_matched = function(l, r)
    return l >= 1 and r <= n and line:sub(l, r):find(line_pattern) ~= nil
  end

  if direction ~= 'right' then
    while is_matched(left - 1, right) do
      left = left - 1
    end
  end
  if direction ~= 'left' then
    while is_matched(left, right + 1) do
      right = right + 1
    end
  end

  return { left = left, right = right }
end

---- Work with cursor neighborhood
function H.get_cursor_neighborhood(n_neighbors)
  -- Cursor position
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  ---- Convert from 0-based column to 1-based
  cur_pos = { line = cur_pos[1], col = cur_pos[2] + 1 }

  -- '2d neighborhood': position is determined by line and column
  local line_start = math.max(1, cur_pos.line - n_neighbors)
  local line_end = math.min(vim.api.nvim_buf_line_count(0), cur_pos.line + n_neighbors)
  local neigh2d = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)
  ---- Append 'newline' character to distinguish between lines in 1d case. This
  ---- is crucial to not allow detecting surrounding spanning several lines
  for k, v in pairs(neigh2d) do
    neigh2d[k] = v .. '\n'
  end

  -- '1d neighborhood': position is determined by offset from start
  local neigh1d = table.concat(neigh2d, '')

  -- Convert from buffer position to 1d offset
  local pos_to_offset = function(pos)
    local line_num = line_start
    local offset = 0
    while line_num < pos.line do
      offset = offset + neigh2d[line_num - line_start + 1]:len()
      line_num = line_num + 1
    end

    return offset + pos.col
  end

  -- Convert from 1d offset to buffer position
  local offset_to_pos = function(offset)
    local line_num = 1
    local line_offset = 0
    while line_num <= #neigh2d and line_offset + neigh2d[line_num]:len() < offset do
      line_offset = line_offset + neigh2d[line_num]:len()
      line_num = line_num + 1
    end

    return { line = line_start + line_num - 1, col = offset - line_offset }
  end

  return {
    cursor_pos = cur_pos,
    ['1d'] = neigh1d,
    ['2d'] = neigh2d,
    pos_to_offset = pos_to_offset,
    offset_to_pos = offset_to_pos,
  }
end

-- Get surround information
---- `sur_type` is one of 'input' or 'output'
function H.get_surround_info(sur_type, use_cache)
  local res

  -- Try using cache
  if use_cache then
    res = H.cache[sur_type]
    if res ~= nil then
      return res
    end
  end

  -- Prompt user to enter identifier of surrounding
  local char = H.user_surround_id(sur_type)

  -- Compute surround info
  ---- Return `nil` in case of a bad identifier
  if char == nil then
    return nil
  end

  ---- Handle special cases first
  if char == 'f' then
    res = H.special_funcall(sur_type)
  elseif char == 'i' then
    res = H.special_interactive(sur_type)
  elseif char == 't' then
    res = H.special_tag(sur_type)
  else
    res = H.surroundings[char]
  end

  ---- Do nothing if supplied nothing
  if res == nil then
    return nil
  end

  ----- Add identifier
  res.id = char

  -- Cache result
  if use_cache then
    H.cache[sur_type] = res
  end

  return res
end

function H.special_funcall(sur_type)
  -- Differentiate input and output because input doesn't need user action
  if sur_type == 'input' then
    -- Allowed symbols followed by a balanced parenthesis.
    -- Can't use `%g` instead of allowed characters because of possible
    -- '[(fun(10))]' case
    return {
      find = string.format('%s%%b()', MiniSurround.config.funname_pattern),
      extract = string.format('^(%s%%().*(%%))$', MiniSurround.config.funname_pattern),
    }
  else
    local fun_name = H.user_input('Function name')
    -- Don't add anything if user supplied empty string (or hit `<Esc>`)
    if fun_name == '' then
      return nil
    end
    return { left = fun_name .. '(', right = ')' }
  end
end

function H.special_interactive(sur_type)
  -- Prompt for surroundings. Empty surrounding is not allowed for input.
  local left = H.user_input('Left surrounding')
  if sur_type == 'input' and left == '' then
    return nil
  end
  local right = H.user_input('Right surrounding')
  if sur_type == 'input' and right == '' then
    return nil
  end

  local left_esc, right_esc = vim.pesc(left), vim.pesc(right)
  local find = string.format('%s.-%s', left_esc, right_esc)
  local extract = string.format('^(%s).-(%s)$', left_esc, right_esc)
  return { find = find, extract = extract, left = left, right = right }
end

function H.special_tag(sur_type)
  -- Differentiate input and output because input doesn't need user action
  if sur_type == 'input' then
    -- NOTEs:
    -- - Here `%f[^%w]` denotes 'end of word' and is needed to capture whole
    --   tag id. This is needed to not match in case '<ab></a>'.
    -- - This approach won't match in the end of 'self nested' tags like
    -- '<a>_<a>_</a>_</a>'.
    -- - Having group capture and backreference in 'find' pattern increases
    --   execution time. This is mostly visible when searching in a very big
    --   '1d neighborhood'.
    return { find = '<(%a%w*)%f[^%w][^>]->.-</%1>', extract = '^(<.->).*(</[^/]->)$' }
  else
    local tag_name = H.user_input('Tag name')
    -- Don't add anything if user supplied empty string (or hit `<Esc>`)
    if tag_name == '' then
      return nil
    end
    return { left = '<' .. tag_name .. '>', right = '</' .. tag_name .. '>' }
  end
end

-- Find surrounding in neighborhood
function H.find_surrounding_in_neighborhood(surround_info, n_neighbors)
  local neigh = H.get_cursor_neighborhood(n_neighbors)
  local cur_offset = neigh.pos_to_offset(neigh.cursor_pos)

  -- Find covering of surrounding
  local covering = H.find_smallest_covering(neigh['1d'], surround_info.find, cur_offset)
  if covering == nil then
    return nil
  end
  ---- Tweak covering for function call surrounding
  if surround_info.id == 'f' then
    covering = H.extend_covering(covering, neigh['1d'], surround_info.find, 'left')
  end
  local substring = neigh['1d']:sub(covering.left, covering.right)

  -- Compute lineparts for left and right surroundings
  ---- If there is no `extract` pattern, extract one character from start and end
  local extract = surround_info.extract or '^(.).*(.)$'
  local left, right = substring:match(extract)
  local l, r = covering.left, covering.right

  local left_from, left_to = neigh.offset_to_pos(l), neigh.offset_to_pos(l + left:len() - 1)
  local right_from, right_to = neigh.offset_to_pos(r - right:len() + 1), neigh.offset_to_pos(r)

  local left_linepart = H.new_linepart(left_from, left_to)
  if left_linepart == nil then
    return nil
  end
  local right_linepart = H.new_linepart(right_from, right_to)
  if right_linepart == nil then
    return nil
  end

  return { left = left_linepart, right = right_linepart }
end

-- Utilities
function H.keymap(mode, keys, cmd, opts)
  if keys == '' then
    return
  end
  vim.api.nvim_set_keymap(mode, keys, cmd, opts)
end

return MiniSurround
