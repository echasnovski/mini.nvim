-- MIT License Copyright (c) 2021 Evgeni Chasnovski

-- Documentation ==============================================================
--- Custom somewhat minimal and fast surrounding Lua plugin. This is mostly
--- a reimplementation of the core features of 'machakann/vim-sandwich' with a
--- couple more on top (find surrounding, highlight surrounding). Can be
--- configured to have experience similar to 'tpope/vim-surround'.
---
--- Features:
--- - Actions (all of them are dot-repeatable out of the box):
---     - Add surrounding with `sa` (in visual mode or on motion).
---     - Delete surrounding with `sd`.
---     - Replace surrounding with `sr`.
---     - Find surrounding with `sf` or `sF` (move cursor right or left).
---     - Highlight surrounding with `sh`.
---     - Change number of neighbor lines with `sn` (see |MiniSurround-algorithm|).
--- - Surrounding is identified by a single character as both "input" (in
---   `delete` and `replace` start, `find`, and `highlight`) and "output" (in
---   `add` and `replace` end):
---     - 'f' - function call (string of alphanumeric symbols or '_' or '.'
---       followed by balanced '()'). In "input" finds function call, in
---       "output" prompts user to enter function name.
---     - 'i' - interactive. Prompts user to enter left and right parts.
---     - 't' - tag. In "input" finds tab with same identifier, in "output"
---       prompts user to enter tag name.
---     - All symbols in brackets '()', '[]', '{}', '<>". In "input' represents
---       balanced brackets, in "output" - left and right parts of brackets.
---     - All other alphanumeric, punctuation, or space characters represent
---       surrounding with identical left and right parts.
---
--- Known issues which won't be resolved:
--- - Search for surrounding is done using Lua patterns (regex-like approach).
---   So certain amount of false positives should be expected.
--- - When searching for "input" surrounding, there is no distinction if it is
---   inside string or comment. So in this case there will be not proper match
---   for a function call: 'f(a = ")", b = 1)'.
--- - Tags are searched using regex-like methods, so issues are inevitable.
---   Overall it is pretty good, but certain cases won't work. Like self-nested
---   tags won't match correctly on both ends: '<a><a></a></a>'.
---
--- # Setup~
---
--- This module needs a setup with `require('mini.surround').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniSurround` which you can use for scripting or manually (with
--- `:lua MiniSurround.*`).
---
--- See |MiniSurround.config| for `config` structure and default values. It
--- also has example setup providing experience similar to 'tpope/vim-surround'.
---
--- # Example usage~
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
--- # Highlight groups~
---
--- 1. `MiniSurround` - highlighting of requested surrounding.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling~
---
--- To disable, set `g:minisurround_disable` (globally) or
--- `b:minisurround_disable` (for a buffer) to `v:true`. Considering high
--- number of different scenarios and customization intentions, writing exact
--- rules for disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes.
---@tag mini.surround
---@tag MiniSurround
---@toc_entry Surround

--- Algorithm design
---
--- - Adding "output" surrounding has a fairly straightforward algorithm:
---     - Determine places for left and right parts (via `<>`/`[]` marks or by
---       finding some other surrounding).
---     - Determine left and right parts of surrounding via using custom and
---       builtin surroundings (via `output` field of surrounding info see
---       |MiniSurround.config|).
---     - Properly add.
--- - Finding "input" surrounding is a lot more complicated and is a reason why
---   this implementation is only somewhat minimal. In a nutshell, current
---   algorithm `searches in the neighborhood lines based on a certain pattern
---   and search method a best match`. More detailed:
---     - Extract neighborhood of cursor line: no more than
---       `MiniSurround.config.n_lines` before, cursor line itself, no more than
---       `MiniSurround.config.n_lines` after. Note: actual search is done
---       firstly on cursor line (i.e. with `n_lines = 0`), as it is the most
---       frequent usage and only then searches in wholeneighborhood.
---     - Convert it to "1d neighborhood" by concatenating with '\n' delimiter.
---       Compute location of current cursor position in this line.
---     - Given Lua pattern for an "input" surrounding (`input.find` field of
---       surrounding info; see |MiniSurround.config|), search for best match.
---       That is:
---         - Match with span covering cursor position. If several, try to pick
---           one with smallest width.
---         - If no covering match, pick one of "previous" (nearest
---           non-covering to the left) or "next" (nearest non-covering to the
---           right) matches, depending on `config.search_method` (see
---           |MiniSurround.config| for more details).
---       This computation is an iterative procedure, duration of which heavily
---       depends on the length of "1d neighborhood" and frequency of pattern
---       matching. If no match is found, there is no surrounding. Note: with
---       current approach smallest width of covering match is ensured by
---       checking match on covering substrings. This may have unwanted
---       consequences when using complex Lua patterns (like `%f[]` at the
---       pattern end, for example).
---     - Compute parts of "1d neighborhood" that represent left and right part
---       of found surrounding. This is done by using pattern from
---       `input.extract` field of surrounding info; see |MiniSurround.config|.
---       Note: pattern is used on a matched substring, so using `^` and `$` at
---       start and end of pattern means start and end of substring.
---     - Convert "1d offsets" of found parts to their positions in buffer.
---@tag MiniSurround-algorithm

-- Module definition ==========================================================
local MiniSurround = {}
local H = {}

--- Module setup
---
---@param config table Module config table. See |MiniSurround.config|.
---
---@usage `require('mini.surround').setup({})` (replace `{}` with your `config` table)
function MiniSurround.setup(config)
  -- Export module
  _G.MiniSurround = MiniSurround

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Create highlighting
  vim.api.nvim_exec([[hi default link MiniSurround IncSearch]], false)
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # Setup similar to 'tpope/vim-surround'~
---
--- This module is primarily designed after 'machakann/vim-sandwich'. To get
--- behavior closest to 'tpope/vim-surround' (but not identical), use this setup:
--- >
---   require('mini.surround').setup({
---     custom_surroundings = {
---       ['('] = { output = { left = '( ', right = ' )' } },
---       ['['] = { output = { left = '[ ', right = ' ]' } },
---       ['{'] = { output = { left = '{ ', right = ' }' } },
---       ['<'] = { output = { left = '< ', right = ' >' } },
---     },
---     mappings = {
---       add = 'ys',
---       delete = 'ds',
---       find = '',
---       find_left = '',
---       highlight = '',
---       replace = 'cs',
---       update_n_lines = '',
---     },
---     search_method = 'cover_or_next',
---   })
---
---   -- Remap adding surrounding to Visual mode selection
---   vim.api.nvim_set_keymap('x', 'S', [[:<C-u>lua MiniSurround.add('visual')<CR>]], { noremap = true })
---
---   -- Make special mapping for "add surrounding for line"
---   vim.api.nvim_set_keymap('n', 'yss', 'ys_', { noremap = false })
--- <
--- # Options~
---
--- ## Custom surroundings~
---
--- User can define own surroundings by supplying `config.custom_surroundings`.
--- It should be a table with keys being single character surrounding identifier
--- and values - surround info or function returning it. Surround info itself
--- is a table with keys:
--- - <input> - defines how to find and extract surrounding for "input"
---   operations (like `delete`). A table with fields <find> (Lua pattern
---   applied for search in neighborhood) and <extract> (Lua pattern applied
---   for extracting left and right parts; should have two matches).
--- - <output> - defines what to add on left and right for "output" operations
---   (like `add`). A table with <left> (plain text string) and <right> (plain
---   text string) fields.
---
--- Example of surround info for builtin `(` identifier:>
---   {
---     input = { find = '%b()', extract = '^(.).*(.)$' },
---     output = { left = '(', right = ')' }
---   }
--- <
--- General recommendations:
--- - In `config.custom_surroundings` only some data can be defined (like only
---   `input.find`). Other fields will be taken from builtin surroundings.
--- - Function returning table with surround info instead of table itself is
---   helpful when user input is needed (like asking for function name). Use
---   |input()| or |MiniSurround.user_inpu()|. Return `nil` to stop any current
---   surround operation.
--- - In input patterns try to use lazy quantifier instead of greedy ones (`.-`
---   instead of `.*` or `.+`). That is because the underlying algorithm of
---   finding smallest covering is better designed for lazy quantifier.
--- - Usage of frontier pattern `%f[]` not at the end of pattern can be useful
---   to extend match to the left. Like `%f[%w]%w+%b()` matches simplified
---   function call while capturing whole function name instead of last symbol.
--- - Usage of frontier pattern at the end of match is currently problematic
---   because output "smallest width" match is computed by checking the match
---   on substrings. And frontier pattern matches at the end of substring for
---   appropriate last character. So `%f[%w]%w+%f[%W]` won't match whole word.
---
--- Present builtin surroundings by their single character identifier:
--- - `(` and `)` - balanced pair of `()`.
--- - `[` and `]` - balanced pair of `[]`.
--- - `{` and `}` - balanced pair of `{}`.
--- - `<` and `>` - balanced pair of `<>`.
--- - `f` - function call. Maximum set of allowed symbols (alphanumeric, `_`
---   and `.`) followed by balanced pair of `()`.
--- - `i` - interactive, prompts user to enter left and right parts.
--- - `t` - HTML tags.
--- - Any other non-recognized identifier represents surrounding with identical
---   left and right parts equal to identifier (like `_`, etc.).
---
--- Example of using `config.custom_surroundings`:
--- >
---   require('mini.surround').setup({
---     custom_surroundings = {
---       -- Make `)` insert parts with spaces. `input` pattern stays the same.
---       [')'] = { output = { left = '( ', right = ' )' } },
---
---       -- Modify `f` (function call) to find functions with only alphanumeric
---       -- characters in its name.
---       f = { input = { find = '%f[%w]%w+%b()' } },
---
---       -- Create custom surrouding for Lua's block string `[[...]]`
---       s = {
---         input = { find = '%[%[.-%]%]', extract = '^(..).*(..)$' },
---         output = { left = '[[', right = ']]' },
---       },
---
---       -- Use function to compute surrounding info
---       ['*'] = {
---         input = function()
---           local n_star = MiniSurround.user_input('Number of * to find: ')
---           local many_star = string.rep('%*', tonumber(n_star) or 1)
---           local find = string.format('%s.-%s', many_star, many_star)
---           local extract = string.format('^(%s).*(%s)$', many_star, many_star)
---           return { find = find, extract = extract }
---         end,
---         output = function()
---           local n_star = MiniSurround.user_input('Number of * to output: ')
---           local many_star = string.rep('*', tonumber(n_star) or 1)
---           return { left = many_star, right = many_star }
---         end,
---       },
---     },
---   })
--- <
--- ## Search method~
---
--- Value of `config.search_method` defines how best match search for "input"
--- surrounding is done when there is no covering match (with span covering
--- cursor position) found within searched neighborhood. Based on its value,
--- one of "previous", "next", or neither match is used as output.
--- Its possible values are:
--- - `'cover'` (default) - don't use either "previous" or "next"; report that
---   there is no surrounding found.
--- - `'cover_or_prev'` - use previous.
--- - `'cover_or_next'` - use next.
--- - `'cover_or_nearest'` - use nearest to current cursor position. Distance
---   is computed based on "1d neighborhood" using nearest part of
---   surroundings. Next is used in case of a tie.
---
--- Note: search is first performed on the cursor line and only after failure -
--- on the whole neighborhood defined by `config.n_lines`. This means that with
--- `config.search_method` not equal to `'cover'`, "previous" or "next"
--- surrounding will end up as search result if they present on current line
--- although covering match might be found in bigger, whole neighborhood. This
--- design is based on observation that most of the time operation involving
--- surrounding is done withtin cursor line.
---
--- Here is an example of how replacing `)` with `]` surrounding is done based
--- on a value of `'config.search_method'` when cursor is inside `bbb` word:
--- - `search_method = 'cover'`:         `(a) bbb (c)` -> `(a) bbb (c)` (with message)
--- - `search_method = 'cover_or_prev'`: `(a) bbb (c)` -> `[a] bbb (c)`
--- - `search_method = 'cover_or_next'`: `(a) bbb (c)` -> `(a) bbb [c]`
--- - `search_method = 'cover_or_nearest'`: depends on cursor position.
---   For first `b` - as in `cover_or_prev` (as previous match is nearer), for
---   second and third - as in `cover_or_next` (as next match is nearer).
MiniSurround.config = {
  -- Add custom surroundings to be used on top of builtin ones. For more
  -- information with examples, see `:h MiniSurround.config`.
  custom_surroundings = nil,

  -- Duration (in ms) of highlight when calling `MiniSurround.highlight()`
  highlight_duration = 500,

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    add = 'sa', -- Add surrounding in Normal and Visual modes
    delete = 'sd', -- Delete surrounding
    find = 'sf', -- Find surrounding (to the right)
    find_left = 'sF', -- Find surrounding (to the left)
    highlight = 'sh', -- Highlight surrounding
    replace = 'sr', -- Replace surrounding
    update_n_lines = 'sn', -- Update `n_lines`
  },

  -- Number of lines within which surrounding is searched
  n_lines = 20,

  -- How to search for surrounding (first inside current line, then inside
  -- neighborhood). One of 'cover', 'cover_or_next', 'cover_or_prev',
  -- 'cover_or_nearest'. For more details, see `:h MiniSurround.config`.
  search_method = 'cover',
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Surround operator
---
--- Main function to be used in expression mappings. No need to use it
--- directly, everything is setup in |MiniSurround.setup|.
---
---@param task string Name of surround task.
---@param cache table Task cache.
function MiniSurround.operator(task, cache)
  if H.is_disabled() then
    -- Using `<Esc>` helps to stop moving cursor caused by current
    -- implementation detail of adding `' '` inside expression mapping
    return [[\<Esc>]]
  end

  H.cache = cache or {}

  vim.cmd(string.format('set operatorfunc=v:lua.MiniSurround.%s', task))
  return 'g@'
end

--- Add surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
---
---@param mode string Mapping mode (normal by default).
function MiniSurround.add(mode)
  -- Needed to disable in visual mode
  if H.is_disabled() then
    return '<Esc>'
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
    return '<Esc>'
  end

  -- Add surrounding. Begin insert from right to not break column numbers
  -- Insert after the right mark (`+ 1` is for that)
  H.insert_into_line(marks.second.line, marks.second.col + 1, surr_info.right)
  H.insert_into_line(marks.first.line, marks.first.col, surr_info.left)

  -- Set cursor to be on the right of left surrounding
  H.set_cursor(marks.first.line, marks.first.col + surr_info.left:len())
end

--- Delete surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
function MiniSurround.delete()
  -- Find input surrounding
  local surr = H.find_surrounding(H.get_surround_info('input', true))
  if surr == nil then
    return '<Esc>'
  end

  -- Delete surrounding. Begin with right to not break column numbers.
  H.delete_linepart(surr.right)
  H.delete_linepart(surr.left)

  -- Set cursor to be on the right of deleted left surrounding
  H.set_cursor(surr.left.line, surr.left.from)
end

--- Replace surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
function MiniSurround.replace()
  -- Find input surrounding
  local surr = H.find_surrounding(H.get_surround_info('input', true))
  if surr == nil then
    return '<Esc>'
  end

  -- Get output surround info
  local new_surr_info = H.get_surround_info('output', true)
  if new_surr_info == nil then
    return '<Esc>'
  end

  -- Replace by parts starting from right to not break column numbers
  H.delete_linepart(surr.right)
  H.insert_into_line(surr.right.line, surr.right.from, new_surr_info.right)

  H.delete_linepart(surr.left)
  H.insert_into_line(surr.left.line, surr.left.from, new_surr_info.left)

  -- Set cursor to be on the right of left surrounding
  H.set_cursor(surr.left.line, surr.left.from + new_surr_info.left:len())
end

--- Find surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
function MiniSurround.find()
  -- Find surrounding
  local surr = H.find_surrounding(H.get_surround_info('input', true))
  if surr == nil then
    return '<Esc>'
  end

  -- Make array of positions to cycle through
  local pos_array = H.linepart_to_pos_table(surr.left)
  vim.list_extend(pos_array, H.linepart_to_pos_table(surr.right))

  -- Cycle cursor through positions
  local dir = H.cache.direction or 'right'
  H.cursor_cycle(pos_array, dir)

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
    return '<Esc>'
  end

  -- Highlight surrounding
  local buf_id = vim.api.nvim_get_current_buf()
  H.highlight_surrounding(buf_id, surr)
  --stylua: ignore
  vim.defer_fn(function() H.unhighlight_surrounding(buf_id, surr) end, MiniSurround.config.highlight_duration)
end

--- Update `MiniSurround.config.n_lines`
---
--- Convenient wrapper for updating `MiniSurround.config.n_lines` in case the
--- default one is not appropriate.
function MiniSurround.update_n_lines()
  if H.is_disabled() then
    return '<Esc>'
  end

  local n_lines = MiniSurround.user_input('New number of neighbor lines', MiniSurround.config.n_lines)
  n_lines = math.floor(tonumber(n_lines) or MiniSurround.config.n_lines)
  MiniSurround.config.n_lines = n_lines
end

--- Ask user for input
---
--- This is mainly a wrapper for |input()| which allows empty string as input,
--- cancelling with `<Esc>` and `<C-c>`, and slightly modifies prompt. Use it
--- to ask for input inside function custom surrounding (see |MiniSurround.config|).
function MiniSurround.user_input(prompt, text)
  -- Major issue with both `vim.fn.input()` is that the only way to distinguish
  -- cancelling with `<Esc>` and entering empty string with immediate `<CR>` is
  -- through `cancelreturn` option (see `:h input()`). In that case the return
  -- of `cancelreturn` will mean actual cancel, which removes possibility of
  -- using that string. Although doable with very obscure string, this is not
  -- very clean.
  -- Overcome this by adding temporary keystroke listener.
  local on_key = vim.on_key or vim.register_keystroke_callback
  local was_cancelled = false
  on_key(function(key)
    if key == vim.api.nvim_replace_termcodes('<Esc>', true, true, true) then
      was_cancelled = true
    end
  end, H.ns_id.input)

  -- Ask for input
  -- NOTE: it would be GREAT to make this work with `vim.ui.input()` but I
  -- didn't find a way to make it work without major refactor of whole module.
  -- The main issue is that `vim.ui.input()` is designed to perform action in
  -- callback and current module design is to get output immediately. Although
  -- naive approach of
  -- `local res; vim.ui.input({...}, function(input) res = input end)`
  -- works in default `vim.ui.input`, its reimplementations can return from it
  -- immediately and proceed in main event loop. Couldn't find a relatively
  -- simple way to stop execution of this current function until `ui.input()`'s
  -- callback finished execution.
  local opts = { prompt = '(mini.surround) ' .. prompt .. ': ', default = text or '' }
  -- Use `pcall` to allow `<C-c>` to cancel user input
  local ok, res = pcall(vim.fn.input, opts)

  -- Stop key listening
  on_key(nil, H.ns_id.input)

  if not ok or was_cancelled then
    return
  end
  return res
end

-- Helper data ================================================================
-- Module default config
H.default_config = MiniSurround.config

-- Namespaces to be used withing module
H.ns_id = {
  highlight = vim.api.nvim_create_namespace('MiniSurroundHighlight'),
  input = vim.api.nvim_create_namespace('MiniSurroundInput'),
}

-- Table of builtin surroundings
H.builtin_surroundings = {
  -- Brackets that need balancing
  ['('] = { input = { find = '%b()', extract = '^(.).*(.)$' }, output = { left = '(', right = ')' } },
  [')'] = { input = { find = '%b()', extract = '^(.).*(.)$' }, output = { left = '(', right = ')' } },
  ['['] = { input = { find = '%b[]', extract = '^(.).*(.)$' }, output = { left = '[', right = ']' } },
  [']'] = { input = { find = '%b[]', extract = '^(.).*(.)$' }, output = { left = '[', right = ']' } },
  ['{'] = { input = { find = '%b{}', extract = '^(.).*(.)$' }, output = { left = '{', right = '}' } },
  ['}'] = { input = { find = '%b{}', extract = '^(.).*(.)$' }, output = { left = '{', right = '}' } },
  ['<'] = { input = { find = '%b<>', extract = '^(.).*(.)$' }, output = { left = '<', right = '>' } },
  ['>'] = { input = { find = '%b<>', extract = '^(.).*(.)$' }, output = { left = '<', right = '>' } },
  -- Function call
  ['f'] = {
    input = { find = '%f[%w_%.][%w_%.]+%b()', extract = '^(.-%().*(%))$' },
    output = function()
      local fun_name = MiniSurround.user_input('Function name')
      --stylua: ignore
      if fun_name == nil then return nil end
      return { left = ('%s('):format(fun_name), right = ')' }
    end,
  },
  -- Interactive
  ['i'] = {
    input = function()
      local left = MiniSurround.user_input('Left surrounding')
      --stylua: ignore
      if left == nil or left == '' then return end
      local right = MiniSurround.user_input('Right surrounding')
      --stylua: ignore
      if right == nil or right == '' then return end

      local left_esc, right_esc = vim.pesc(left), vim.pesc(right)
      local find = ('%s.-%s'):format(left_esc, right_esc)
      local extract = ('^(%s).-(%s)$'):format(left_esc, right_esc)
      return { find = find, extract = extract }
    end,
    output = function()
      local left = MiniSurround.user_input('Left surrounding')
      --stylua: ignore
      if left == nil then return end
      local right = MiniSurround.user_input('Right surrounding')
      --stylua: ignore
      if right == nil then return end
      return { left = left, right = right }
    end,
  },
  -- Tag
  ['t'] = {
    -- NOTEs:
    -- - Here `%f[^%w]` denotes 'end of word' and is needed to capture whole
    --   tag id. This is needed to not match in case '<ab></a>'.
    -- - This approach won't match in the end of 'self nested' tags like
    --   '<a>_<a>_</a>_</a>'.
    -- - Having group capture and backreference in 'find' pattern increases
    --   execution time. This is mostly visible when searching in a very big
    --   '1d neighborhood'.
    input = { find = '<(%w-)%f[^<%w][^<>]->.-</%1>', extract = '^(<.->).*(</[^/]->)$' },
    output = function()
      local tag_name = MiniSurround.user_input('Tag name')
      --stylua: ignore
      if tag_name == nil then return nil end
      return { left = ('<%s>'):format(tag_name), right = ('</%s>'):format(tag_name) }
    end,
  },
}

-- Cache for dot-repeatability. This table is currently used with these keys:
-- - 'input' - surround info for searching (in 'delete' and 'replace' start).
-- - 'output' - surround info for adding (in 'add' and 'replace' end).
-- - 'direction' - direction in which `MiniSurround.find()` should go. Used to
--   enable same `operatorfunc` pattern for dot-repeatability.
H.cache = {}

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  -- TODO: remove after 0.4.0 release
  if config.funname_pattern ~= nil then
    H.message(
      '`config.funname_pattern` is deprecated. '
        .. 'If you explicitly supply its default value, remove it from `config`. '
        .. 'If not, manually modifying `f` surrounding in `config.custom_surroundings`. '
        .. 'See `:h MiniSurround.config`.'
    )
  end

  -- Validate per nesting level to produce correct error message
  vim.validate({
    custom_surroundings = { config.custom_surroundings, 'table', true },
    highlight_duration = { config.highlight_duration, 'number' },
    mappings = { config.mappings, 'table' },
    n_lines = { config.n_lines, 'number' },
    search_method = { config.search_method, H.is_search_method },
  })

  vim.validate({
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

  --stylua: ignore start
  -- Make mappings
  -- NOTE: In mappings construct ` . ' '` "disables" motion required by `g@`.
  -- It is used to enable dot-repeatability.
  H.map('n', config.mappings.add, [[v:lua.MiniSurround.operator('add')]], { expr = true, desc = 'Add surrounding' })
  H.map('x', config.mappings.add, [[:<C-u>lua MiniSurround.add('visual')<CR>]], { desc = 'Add surrounding to selection' })
  H.map('n', config.mappings.delete, [[v:lua.MiniSurround.operator('delete') . ' ']], { expr = true, desc = 'Delete surrounding' })
  H.map('n', config.mappings.replace, [[v:lua.MiniSurround.operator('replace') . ' ']], { expr = true, desc = 'Replace surrounding' })
  H.map('n', config.mappings.find, [[v:lua.MiniSurround.operator('find', {'direction': 'right'}) . ' ']], { expr = true, desc = 'Find right surrounding' })
  H.map('n', config.mappings.find_left, [[v:lua.MiniSurround.operator('find', {'direction': 'left'}) . ' ']], { expr = true, desc = 'Find left surrounding' })
  H.map('n', config.mappings.highlight, [[v:lua.MiniSurround.operator('highlight') . ' ']], { expr = true, desc = 'Highlight surrounding' })
  H.map('n', config.mappings.update_n_lines, [[<Cmd>lua MiniSurround.update_n_lines()<CR>]], { desc = 'Update `MiniSurround.config.n_lines`' })
  --stylua: ignore end
end

function H.is_disabled()
  return vim.g.minisurround_disable == true or vim.b.minisurround_disable == true
end

function H.is_search_method(x, x_name)
  x = x or MiniSurround.config.search_method
  x_name = x_name or '`config.search_method`'

  if vim.tbl_contains({ 'cover', 'cover_or_prev', 'cover_or_next', 'cover_or_nearest' }, x) then
    return true
  end
  local msg = ([[%s should be one of 'cover', 'cover_or_prev', 'cover_or_next', 'cover_or_nearest'.]]):format(x_name)
  return false, msg
end

function H.validate_search_method(x, x_name)
  local is_valid, msg = H.is_search_method(x, x_name)
  --stylua: ignore
  if not is_valid then H.error(msg) end
end

-- Work with finding surrounding ----------------------------------------------
-- Find surrounding
-- NOTE: more simple approach for `find_surrounding()` would have been to use
-- combination of `searchpairpos()` (to search for balanced pair) and
-- `searchpos()` (to search end of balanced search and for unbalanced pairs).
-- However, there are several problems with it:
-- - It is slower (around 2-5 times) than current Lua pattern approach.
-- - It has limitations when dealing with crucial 'function call' search.
--   Function call is defined as 'non-empty function name followed by balanced
--   pair of "(" and ")"'. Naive use of `searchpairpos()` is to use
--   `searchpairpos('\w\+(', '', ')')` which works most of the time. However,
--   in example `foo(a = (1 + 1), b = c(1, 2))` this will match
--   `o(a = (1 + 1)` when cursor is on 'a'. This is because '(' inside it is
--   not recognized for balancing because it doesn't match '\w\+('.
--
-- Vim's approach also has some upsides:
-- - `searchpairpos()` allows skipping of certain matches, like if it is inside
--   string or comment. It works decently well with example from help (with
--   `synIDattr`, etc.) but this only works when Vim's builtin highlighting is
--   used. When treesitter's highlighting is active, this doesn't work.
--
-- All in all, using Vim's builtin functions is doable, but leads to roughly
-- same efforts as Lua pattern approach.
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
    local msg = ([[No surrounding '%s' found within %d line%s and `config.search_method = '%s'`.]]):format(
      surround_info.id,
      n_lines,
      n_lines > 1 and 's' or '',
      MiniSurround.config.search_method
    )
    H.message(msg)
  end

  return surr
end

function H.find_surrounding_in_neighborhood(surround_info, n_neighbors)
  local neigh = H.get_cursor_neighborhood(n_neighbors)
  local cur_offset = neigh.pos_to_offset(neigh.cursor_pos)

  -- Find span of surrounding
  local span = H.find_best_match(neigh['1d'], surround_info.find, cur_offset)
  if span == nil then
    return nil
  end

  -- Compute lineparts for left and right surroundings
  local l, r = span.left, span.right
  local left, right = neigh['1d']:sub(l, r):match(surround_info.extract)
  if left == nil or right == nil then
    H.error(
      'Could not extract two surrounding parts. '
        .. 'Does your `config.custom_surroundings.input.extract` pattern has two captures?'
    )
  end

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

-- Work with operator marks ---------------------------------------------------
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
  -- This returns the last byte inside character because `vim.str_byteindex()`
  -- 'rounds upwards to the end of that sequence'.
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

-- Work with cursor -----------------------------------------------------------
function H.set_cursor(line, col)
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

function H.cursor_cycle(pos_array, dir)
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  cur_pos = { line = cur_pos[1], col = cur_pos[2] + 1 }

  local compare, to_left, to_right, res_pos
  -- NOTE: `pos_array` should be an increasingly ordered array of positions
  for _, pos in pairs(pos_array) do
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

  res_pos = res_pos or (dir == 'right' and pos_array[1] or pos_array[#pos_array])
  vim.api.nvim_win_set_cursor(0, { res_pos.line, res_pos.col - 1 })
end

-- Work with user input -------------------------------------------------------
function H.user_surround_id(sur_type)
  -- Get from user single character surrounding identifier
  local needs_help_msg = true
  vim.defer_fn(function()
    --stylua: ignore
    if not needs_help_msg then return end

    local msg = string.format('Enter %s surrounding identifier (single character) ', sur_type)
    H.message(msg)
  end, 1000)
  local ok, char = pcall(vim.fn.getchar)
  needs_help_msg = false

  -- Terminate if couldn't get input (like with <C-c>) or it is `<Esc>`
  if not ok or char == 27 then
    return nil
  end

  if type(char) == 'number' then
    char = vim.fn.nr2char(char)
  end
  if char:find('^[%w%p%s]$') == nil then
    H.message([[Input must be single character: alphanumeric, punctuation, or space.]])
    return nil
  end

  return char
end

-- Work with line parts and text ----------------------------------------------
-- Line part - table with fields `line`, `from`, `to`. Represent part of line
-- from `from` character (inclusive) to `to` character (inclusive).
function H.new_linepart(pos_left, pos_right)
  if pos_left.line ~= pos_right.line then
    H.message('Positions span over multiple lines.')
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

-- Work with Lua patterns -----------------------------------------------------
-- Find the best match (left and right offsets in `line`). Here "best" is:
-- - Covering (`left <= offset <= right`) with smallest width.
-- - If no covering, one of "previous" or "next", depending on
--   `config.search_method`.
-- Output is a table with two numbers (or `nil` in case of no match):
-- indexes of left and right parts of match. They have the following property:
-- `line:sub(left, right)` matches `'^' .. pattern .. '$'`.
function H.find_best_match(line, pattern, offset)
  H.validate_search_method()

  local left_prev, right_prev, left, right, left_next, right_next
  local stop = false
  local init = 1
  while not stop do
    local match_left, match_right = line:find(pattern, init)
    if match_left == nil then
      -- Stop if first match is gone over `offset` to the right
      stop = true
    elseif match_right < offset then
      left_prev, right_prev = match_left, match_right
      -- Try find covering match. Originally this was `init = math.max(init +
      -- 1, match_right)`. Generally, this works fine, but there is an edge
      -- case with tags. Consider example: '<a>hello<b>world</a></b>' and
      -- cursor inside '</b>'.  First match is '<a>...</a>'. It doesn't cover
      -- cursor, this branch is executed. If move to `match_right`, next
      -- iteration will match inside '></b>' and will find no match.
      -- This increases execution time, but tolerably so. On the plus side,
      -- this edge case currently gives wrong result even in 'vim-sandwich' :)
      init = match_left + 1
    elseif match_left > offset then
      left_next, right_next = match_left, match_right
      -- Stop searching because already went past offset
      stop = true
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

  -- If didn't find covering match, try to infer from previous and next
  if left == nil then
    left, right = H.infer_match(
      { left = left_prev, right = right_prev },
      { left = left_next, right = right_next },
      offset
    )
  end

  -- If still didn't find anything, return nothing
  if left == nil then
    return
  end

  -- Try make covering match even smaller. Can happen if there are greedy
  -- quantifiers. For example:
  -- `line = '((()))', pattern = '%(.-%)+', offset = 3`.
  -- This approach has some non-working edge cases, but is quite better
  -- performance wise than bruteforce "find from current offset"
  local line_pattern = '^' .. pattern .. '$'
  while
    -- Ensure covering
    left <= offset
    and offset <= (right - 1)
    -- Ensure at least 2 symbols
    and left < right - 1
    -- Ensure match
    and line:sub(left, right - 1):find(line_pattern)
  do
    right = right - 1
  end

  -- -- Alternative bruteforce approach
  -- for i = math.max(offset, left + 1), right - 1 do
  --   if line:sub(left, i):find(line_pattern) then
  --     right = i
  --     break
  --   end
  -- end

  return { left = left, right = right }
end

--stylua: ignore start
function H.infer_match(prev, next, offset)
  local has_prev = prev.left ~= nil and prev.right ~= nil
  local has_next = next.left ~= nil and next.right ~= nil
  local search_method = MiniSurround.config.search_method

  if not (has_prev or has_next) or search_method == 'cover' then return end
  if search_method == 'cover_or_prev' then return prev.left, prev.right end
  if search_method == 'cover_or_next' then return next.left, next.right end

  if search_method == 'cover_or_nearest' then
    local dist_prev = has_prev and math.abs(offset - prev.right) or math.huge
    local dist_next = has_next and math.abs(next.left - offset) or math.huge

    if dist_next <= dist_prev then
      return next.left, next.right
    else
      return prev.left, prev.right
    end
  end
end
--stylua: ignore end

-- Work with cursor neighborhood ----------------------------------------------
function H.get_cursor_neighborhood(n_neighbors)
  -- Cursor position
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  -- Convert from 0-based column to 1-based
  cur_pos = { line = cur_pos[1], col = cur_pos[2] + 1 }

  -- '2d neighborhood': position is determined by line and column
  local line_start = math.max(1, cur_pos.line - n_neighbors)
  local line_end = math.min(vim.api.nvim_buf_line_count(0), cur_pos.line + n_neighbors)
  local neigh2d = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)
  -- Append 'newline' character to distinguish between lines in 1d case. This
  -- is crucial to not allow detecting surrounding spanning several lines
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

-- Work with highlighting -----------------------------------------------------
function H.highlight_surrounding(buf_id, surr)
  local ns_id = H.ns_id.highlight

  local l_line, l_from, l_to = surr.left.line - 1, surr.left.from - 1, surr.left.to
  vim.highlight.range(buf_id, ns_id, 'MiniSurround', { l_line, l_from }, { l_line, l_to })

  local r_line, r_from, r_to = surr.right.line - 1, surr.right.from - 1, surr.right.to
  vim.highlight.range(buf_id, ns_id, 'MiniSurround', { r_line, r_from }, { r_line, r_to })
end

function H.unhighlight_surrounding(buf_id, surr)
  local ns_id = H.ns_id.highlight

  -- Remove highlights from whole lines as it is the best available granularity
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, surr.left.line - 1, surr.left.line)
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, surr.right.line - 1, surr.right.line)
end

-- Work with surrounding info -------------------------------------------------
--stylua: ignore start
---@param sur_type string One of 'input' or 'output'.
---@private
function H.get_surround_info(sur_type, use_cache)
  local res

  -- Try using cache
  if use_cache then
    res = H.cache[sur_type]
    if res ~= nil then return res end
  end

  -- Prompt user to enter identifier of surrounding
  local char = H.user_surround_id(sur_type)
  if char == nil then return nil end

  -- Get surround info
  res = H.make_surrounding_table()[char][sur_type]
  if type(res) == 'function' then res = res() end

  -- Do nothing if supplied nothing
  if res == nil then return nil end

  -- Track identifier for possible messages
  res.id = char

  -- Cache result
  if use_cache then
    H.cache[sur_type] = res
  end

  return res
end
--stylua: ignore end

function H.make_surrounding_table()
  -- Use data from `config` and extend with builtins
  local surroundings = vim.tbl_deep_extend(
    'force',
    H.builtin_surroundings,
    MiniSurround.config.custom_surroundings or {}
  )

  -- Add possibly missing information from default surrounding info
  for char, info in pairs(surroundings) do
    local default = H.get_default_surrounding_info(char)
    surroundings[char] = vim.tbl_deep_extend('force', default, info)
  end

  -- Use default surrounding info for not supplied single character identifier
  --stylua: ignore start
  return setmetatable(surroundings, {
    __index = function(_, key) return H.get_default_surrounding_info(key) end,
  })
  --stylua: ignore end
end

function H.get_default_surrounding_info(char)
  local char_esc = vim.pesc(char)
  return {
    input = { find = ('%s.-%s'):format(char_esc, char_esc), extract = '^(.).*(.)$' },
    output = { left = char, right = char },
  }
end

-- Utilities ------------------------------------------------------------------
function H.message(msg)
  vim.cmd('echomsg ' .. vim.inspect('(mini.surround) ' .. msg))
end

function H.error(msg)
  error(string.format('(mini.surround) %s', msg))
end

function H.map(mode, key, rhs, opts)
  --stylua: ignore
  if key == '' then return end

  opts = vim.tbl_deep_extend('force', { noremap = true, silent = true }, opts or {})

  -- Use mapping description only in Neovim>=0.7
  if vim.fn.has('nvim-0.7') == 0 then
    opts.desc = nil
  end

  vim.api.nvim_set_keymap(mode, key, rhs, opts)
end

return MiniSurround
