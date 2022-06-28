-- MIT License Copyright (c) 2022 Evgeni Chasnovski

-- Documentation ==============================================================
--- Minimal and fast Lua plugin for jumping (moving cursor) within
--- visible lines via iterative label filtering. Main inspiration is a
--- "phaazon/hop.nvim" plugin, but this module has a slightly different idea
--- about how target jump spot is chosen.
---
--- Features:
--- - Make jump by iterative filtering of possible, equally considered jump
---   spots until there is only one. Filtering is done by typing a label
---   character that is visualized at jump spot.
--- - Customizable:
---     - Way of computing possible jump spots with opinionated default.
---     - Characters used to label jump spots during iterative filtering.
---     - Action hooks to be executed at certain events during jump.
---     - Allowed windows: current and/or not current.
---     - Allowed lines: whether to process blank or folded lines, lines
---       before/at/after cursor line, etc. Example: user can configure to look
---       for spots only inside current window at or after cursor line.
---     Example: user can configure to look for word starts only inside current
---     window at or after cursor line with 'j' and 'k' labels performing some
---     action after jump.
--- - Works in Visual and Operator-pending (with dot-repeat) modes.
--- - Preconfigured ways of computing jump spots (see |MiniJump2d.builtin_opts|).
--- - Works with multibyte characters.
---
--- General overview of how jump is intended to be performed:
--- - Lock eyes on desired location ("spot") recognizable by future jump.
---   Should be within visible lines at place where cursor can be placed.
--- - Initiate jump. Either by custom keybinding or with a call to
---   |MiniJump2d.start()| (allows customization options). This will highlight
---   all possible jump spots with their labels (letters from "a" to "z" by
---   default). For more details, read |MiniJump2d.start()| and |MiniJump2d.config|.
--- - Type character that appeared over desired location. If its label was
---   unique, jump is performed. If it wasn't unique, possible jump spots are
---   filtered to those having the same label character.
--- - Repeat previous step until there is only one possible jump spot or type `<CR>`
---   to jump to first available jump spot. Typing anything else stops jumping
---    without moving cursor.
---
--- # Setup~
---
--- This module needs a setup with `require('mini.jump2d').setup({})` (replace
--- `{}` with your `config` table). It will create global Lua table
--- `MiniJump2d` which you can use for scripting or manually (with
--- `:lua MiniJump2d.*`). See |MiniJump2d.config| for available config settings.
---
--- # Example usage~
---
--- - Modify default jumping to use only current window at or after cursor line: >
---   require('mini.jump2d').setup({
---     allowed_lines = { cursor_before = false },
---     allowed_windows = { not_current = false },
---   })
--- - `lua MiniJump2d.start(MiniJump2d.builtin_opts.line_start)` - jump to word
---   start using combination of options supplied in |MiniJump2d.config| and
---   |MiniJump2d.builtin_opts.line_start|.
--- - `lua MiniJump2d.start(MiniJump2d.builtin_opts.single_character)` - jump
---   to single character typed after executing this command.
--- - See more examples in |MiniJump2d.start| and |MiniJump2d.builtin_opts|.
---
--- # Comparisons~
---
--- - 'phaazon/hop.nvim':
---     - Both are fast, customizable, and extensible (user can write their own
---       ways to define jump spots).
---     - Both have several builtin ways to specify type of jump (word start,
---       line start, one character or query based on user input). 'hop.nvim'
---       does that by exporting many targeted Neovim commands, while this
---       module has preconfigured basic options leaving others to
---       customization with Lua code (see |MiniJump2d.builtin_opts|).
---     - 'hop.nvim' computes labels (called "hints") differently. Contrary to
---       this module deliberately not having preference of one jump spot over
---       another, 'hop.nvim' uses specialized algorithm that produces sequence
---       of keys in a slightly biased manner: some sequences are intentionally
---       shorter than the others (leading to fewer average keystrokes). They
---       are put near cursor (by default) and highlighted differently. Final
---       order of sequences is based on distance to the cursor.
---     - 'hop.nvim' visualizes labels differently. It is designed to show
---       whole sequences at once, while this module intentionally shows only
---       current one at a time.
---     - 'mini.jump2d' has opinionated default algorithm of computing jump
---       spots. See |MiniJump2d.default_spotter|.
---
--- # Highlight groups~
---
--- * `MiniJump2dSpot` - highlighting of jump spots. By default it uses label
---   with highest contrast while not being too visually demanding: white on
---   black for dark 'background', black on white for light. If it doesn't
---   suit your liking, try couple of these alternatives (or choose your own,
---   of course):
---     - `hi MiniJump2dSpot gui=reverse` - reverse underlying highlighting (more
---       colorful while being visible in any colorscheme).
---     - `hi MiniJump2dSpot gui=bold,italic` - bold italic.
---     - `hi MiniJump2dSpot gui=undercurl guisp=red` - red undercurl.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling~
---
--- To disable, set `g:minijump2d_disable` (globally) or `b:minijump2d_disable`
--- (for a buffer) to `v:true`. Considering high number of different scenarios
--- and customization intentions, writing exact rules for disabling module's
--- functionality is left to user. See |mini.nvim-disabling-recipes| for common
--- recipes.
---@tag mini.jump2d
---@tag MiniJump2d
---@toc_entry Jump within visible lines

-- Module definition ==========================================================
local MiniJump2d = {}
local H = {}

--- Module setup
---
---@param config table Module config table. See |MiniJump2d.config|.
---
---@usage `require('mini.jump2d').setup({})` (replace `{}` with your `config` table)
function MiniJump2d.setup(config)
  -- Export module
  _G.MiniJump2d = MiniJump2d

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Corrections for default `<CR>` mapping to not interfer with popular usages
  if config.mappings.start_jumping == '<CR>' then
    vim.api.nvim_exec(
      [[augroup MiniJump2d
          au!
          autocmd BufWinEnter quickfix nnoremap <buffer> <CR> <CR>
          autocmd CmdwinEnter * nnoremap <buffer> <CR> <CR>
        augroup END]],
      false
    )
  end

  -- Create highlighting
  local hl_cmd = 'hi default MiniJump2dSpot guifg=white guibg=black gui=bold,nocombine'
  if vim.o.background == 'light' then
    hl_cmd = 'hi default MiniJump2dSpot guifg=black guibg=white gui=bold,nocombine'
  end
  vim.cmd(hl_cmd)
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # Options~
---
--- ## Spotter function~
---
--- Actual computation of possible jump spots is done through spotter function.
--- It should have the following arguments:
--- - `line_num` is a line number inside buffer.
--- - `args` - table with additional arguments:
---     - {win_id} - identifier of a window where input line number is from.
---     - {win_id_init} - identifier of a window which was current when
---       `MiniJump2d.start()` was called.
---
--- Its output is a list of byte-indexed positions that should be considered as
--- possible jump spots for this particular line in this particular window.
--- Note: for a more aligned visualization this list should be (but not
--- strictly necessary) sorted increasingly.
---
--- Note: spotter function is always called with `win_id` window being
--- "temporary current" (see |nvim_win_call|). This allows using builtin
--- Vimscript functions that operate only inside current window.
---
--- ## Allowed lines~
---
--- Option `allowed_lines` controls which lines will be used for computing
--- possible jump spots:
--- - If `blank` or `fold` is `true`, it is possible to jump to first column of blank
---   line (determined by |prevnonblank|) or first folded one (determined by
---   |foldclosed|) respectively. Otherwise they are skipped. These lines are
---   not processed by spotter function even if the option is `true`.
--- - If `cursor_before`, (`cursor_at`, `cursor_after`) is `true`, lines before
---   (at, after) cursor line of all processed windows are forwarded to spotter
---   function. Otherwise, they don't. This allows control of jump "direction".
---
--- ## Hooks~
---
--- Following hook functions can be used to further tweak jumping experience:
--- - `before_start` - called without arguments first thing when jump starts.
---   One of the possible use cases is to ask for user input and update spotter
---   function with it.
--- - `after_jump` - called after jump was actually done. Useful to make
---   post-adjustments (like move cursor to first non-whitespace character).
MiniJump2d.config = {
  -- Function producing jump spots (byte indexed) for a particular line.
  -- For more information see |MiniJump2d.start|.
  -- If `nil` (default) - use |MiniJump2d.default_spotter|
  spotter = nil,

  -- Characters used for labels of jump spots (in supplied order)
  labels = 'abcdefghijklmnopqrstuvwxyz',

  -- Which lines are used for computing spots
  allowed_lines = {
    blank = true, -- Blank line (not sent to spotter even if `true`)
    cursor_before = true, -- Lines before cursor line
    cursor_at = true, -- Cursor line
    cursor_after = true, -- Lines after cursor line
    fold = true, -- Start of fold (not sent to spotter even if `true`)
  },

  -- Which windows from current tabpage are used for visible lines
  allowed_windows = {
    current = true,
    not_current = true,
  },

  -- Functions to be executed at certain events
  hooks = {
    before_start = nil, -- Before jump start
    after_jump = nil, -- After jump was actually done
  },

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    start_jumping = '<CR>',
  },
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Start jumping
---
--- Compute possible jump spots, visualize them and wait for iterative filtering.
---
--- First computation of possible jump spots~
---
--- - Process allowed windows (current and/or not current; controlled by
---   `allowed_windows` option) by visible lines from top to bottom. For each
---   one see if it is allowed (controlled by `allowed_lines` option). If not
---   allowed, then do nothing. If allowed and should be processed by
---   `spotter`, process it.
--- - Apply spotter function from `spotter` option for each appropriate line
---   and concatenate outputs. This means that eventual order of jump spots
---   aligns with lexicographical order within "window id" - "line number" -
---   "position in `spotter` output" tuples.
--- - For each possible jump compute its label: a single character from
---   `labels` option used to filter jump spots. Each possible label character
---   might be used more than once to label several "consecutive" jump spots.
---   It is done in an optimal way under assumption of no preference of one
---   spot over another. Basically, it means "use all labels at each step of
---   iterative filtering as equally as possible".
---
--- Visualization~
---
--- Current label for each possible jump spot is shown at that position
--- overriding everything underneath it.
---
--- Iterative filtering~
---
--- Labels of possible jump spots are computed in order to use them as equally
--- as possible.
---
--- Example:
--- - With `abc` as `labels` option, initial labels for 10 possible jumps
---   are "aaaabbbccc". As there are 10 spots which should be "coded" with 3
---   symbols, at least 2 symbols need 3 steps to filter them out. With current
---   implementation those are always the "first ones".
--- - After typing `a`, it filters first four jump spots and recomputes its
---   labels to be "aabc".
--- - After typing `a` again, it filters first two spots and recomputes its
---   labels to be "ab".
--- - After typing either `a` or `b` it filters single spot and makes jump.
---
--- With default 26 labels for most real-world cases 2 steps is enough for
--- default spotter function. Rarely 3 steps are needed with several windows.
---
---@param opts table Configuration of jumping, overriding values from
---   |MiniJump2d.config|. Has the same structure as |MiniJump2d.config|
---   without <mappings> field. Extra allowed fields:
---     - <hl_group> - which highlight group to use (default: "MiniJump2dSpot").
---
---@usage - Start default jumping:
---   `MiniJump2d.start()`
--- - Jump to word start:
---   `MiniJump2d.start(MiniJump2d.builtin_opts.word_start)`
--- - Jump to single character from user input (follow by typing one character):
---   `MiniJump2d.start(MiniJump2d.builtin_opts.single_character)`
--- - Jump to first character of punctuation group only inside current window
---   which is placed at cursor line; visualize with 'hl-Search': >
---   MiniJump2d.start({
---     spotter = MiniJump2d.gen_pattern_spotter('%p+'),
---     allowed_lines = { cursor_before = false, cursor_after = false },
---     allowed_windows = { not_current = false },
---     hl_group = 'Search'
---   })
---<
---@seealso |MiniJump2d.config|
function MiniJump2d.start(opts)
  if H.is_disabled() then
    return
  end

  opts = opts or {}

  -- Apply `before_start` before `tbl_deep_extend` to allow it modify options
  -- inside it (notably `spotter`). Example: `builtins.single_character`.
  local before_start = (opts.hooks or {}).before_start or MiniJump2d.config.hooks.before_start
  if before_start ~= nil then
    before_start()
  end

  opts = vim.tbl_deep_extend('force', MiniJump2d.config, opts)
  opts.spotter = opts.spotter or MiniJump2d.default_spotter
  opts.hl_group = opts.hl_group or 'MiniJump2dSpot'

  local spots = H.spots_compute(opts)
  spots = H.spots_add_label(spots, opts)

  H.spots_show(spots, opts)

  H.cache.spots = spots

  -- Defer advancing jump to allow drawing before invoking `getcharstr()`.
  -- This is much faster than having to call `vim.cmd('redraw')`.
  -- Don't do that in Operator-pending mode because it doesn't work otherwise.
  if H.is_operator_pending() then
    H.advance_jump(opts)
  else
    --stylua: ignore
    vim.defer_fn(function() H.advance_jump(opts) end, 0)
  end
end

--- Stop jumping
function MiniJump2d.stop()
  H.spots_unshow()
  H.cache.spots = nil
  vim.cmd('redraw')

  if H.cache.is_in_getchar then
    vim.api.nvim_input('<C-c>')
  end
end

--- Generate spotter for Lua pattern
---
---@param pattern string|nil Lua pattern. Default: `'[^%s%p]+'` which matches group
---   of "non-whitespace non-punctuation characters" (basically a way of saying
---   "group of alphanumeric characters" that works with multibyte characters).
---@param side string|nil Which side of pattern match should be considered as
---   jumping spot. Should be one of 'start' (start of match, default), 'end'
---   (inclusive end of match), or 'none' (match for spot is done manually
---   inside pattern with plain `()` matching group).
---
---@usage - Match any punctuation:
---   `MiniJump2d.gen_pattern_spotter('%p')`
--- - Match first from line start non-whitespace character:
---   `MiniJump2d.gen_pattern_spotter('^%s*%S', 'end')`
--- - Match start of last word:
---   `MiniJump2d.gen_pattern_spotter('[^%s%p]+[%s%p]-$', 'start')`
--- - Match letter followed by another letter (example of manual matching
---   inside pattern):
---   `MiniJump2d.gen_pattern_spotter('%a()%a', 'none')`
function MiniJump2d.gen_pattern_spotter(pattern, side)
  -- Don't use `%w` to account for multibyte characters
  pattern = pattern or '[^%s%p]+'
  side = side or 'start'

  -- Process anchored patterns separately because:
  -- - `gmatch()` doesn't work if pattern start with `^`.
  -- - Manual adding of `()` will conflict with anchors.
  local is_anchored = pattern:sub(1, 1) == '^' or pattern:sub(-1, -1) == '$'
  if is_anchored then
    return function(line_num, args)
      local line = vim.fn.getline(line_num)
      local s, e, m = line:find(pattern)
      return { ({ ['start'] = s, ['end'] = e, ['none'] = m })[side] }
    end
  end

  -- Handle `side = 'end'` later by appending length of match to match start.
  -- This, unlike appending `()` to end of pattern, makes output spot to be
  -- inside matched pattern and on its exact right.
  -- Having `(%s)` for `side = 'none'` is for compatibility with later `gmatch`
  local pattern_template = side == 'none' and '(%s)' or '(()%s)'
  pattern = pattern_template:format(pattern)

  return function(line_num, args)
    local line = vim.fn.getline(line_num)
    local res = {}
    -- NOTE: maybe a more straightforward approach would be a series of
    -- `line:find(original_pattern, init)` with moving `init`, but it has some
    -- weird behavior with quantifiers.
    -- For example: `string.find('  --', '%s*', 4)` returns `4 3`.
    for whole, spot in string.gmatch(line, pattern) do
      -- Possibly correct spot to be index of last matched position
      if side == 'end' then
        spot = spot + math.max(whole:len() - 1, 0)
      end

      -- Ensure that index is strictly within line length (which can be not
      -- true in case of weird pattern, like when using frontier `%f[%W]`)
      spot = math.min(math.max(spot, 0), line:len())

      -- Unify how spot is chosen in case of multibyte characters
      spot = vim.str_byteindex(line, vim.str_utfindex(line, spot))

      -- Add spot only if it referces new actually visible column
      if spot ~= res[#res] then
        table.insert(res, spot)
      end
    end
    return res
  end
end

--- Default spotter function
---
--- Spot is possible for jump if it is one of the following:
--- - Start or end of non-whitespace character group.
--- - Alphanumeric character followed or preceeded by punctuation (useful for
---   snake case names).
--- - Start of uppercase character group (useful for camel case names). Usually
---   only Lating alphabet is recognized due to Lua patterns shortcomings.
---
--- These rules are derived in an attempt to balance between two intentions:
--- - Allow as much useful jumping spots as possible.
--- - Make labeled jump spots easily distinguishable.
---
--- Usually takes from 2 to 3 keystrokes to get to destination.
MiniJump2d.default_spotter = (function()
  local nonblank_start = MiniJump2d.gen_pattern_spotter('%S+', 'start')
  local nonblank_end = MiniJump2d.gen_pattern_spotter('%S+', 'end')
  -- Use `[^%s%p]` as "alphanumeric" to allow working with multibyte characters
  local alphanum_before_punct = MiniJump2d.gen_pattern_spotter('[^%s%p]%p', 'start')
  local alphanum_after_punct = MiniJump2d.gen_pattern_spotter('%p[^%s%p]', 'end')
  -- NOTE: works only with Latin alphabet
  local upper_start = MiniJump2d.gen_pattern_spotter('%u+', 'start')

  return function(line_num, args)
    local res_1 = H.merge_unique(nonblank_start(line_num, args), nonblank_end(line_num, args))
    local res_2 = H.merge_unique(alphanum_before_punct(line_num, args), alphanum_after_punct(line_num, args))
    local res = H.merge_unique(res_1, res_2)
    return H.merge_unique(res, upper_start(line_num, args))
  end
end)()

--- Table with builtin `opts` values for |MiniJump2d.start()|
---
--- Each element of table is itself a table defining one or several options for
--- `MiniJump2d.start()`. Read help description to see which options it defines
--- (like in |MiniJump2d.builtin_opts.line_start|).
---
---@usage Using |MiniJump2d.builtin_opts.line_start| as example:
--- - Command:
---   `:lua MiniJump2d.start(MiniJump2d.builtin_opts.line_start)`
--- - Custom mapping: >
---   vim.api.nvim_set_keymap(
---     'n', '<CR>',
---     '<Cmd>lua MiniJump2d.start(MiniJump2d.builtin_opts.line_start)<CR>', {}
---   )
--- - Inside |MiniJump2d.setup| (make sure to use all defined options): >
---   local jump2d = require('mini.jump2d')
---   local jump_line_start = jump2d.builtin_opts.line_start
---   jump2d.setup({
---     spotter = jump_line_start.spotter,
---     hooks = { after_jump = jump_line_start.hooks.after_jump }
---   })
--- <
MiniJump2d.builtin_opts = {}

--- Jump with |MiniJump2d.default_spotter()|
---
--- Defines `spotter`.
MiniJump2d.builtin_opts.default = { spotter = MiniJump2d.default_spotter }

--- Jump to line start
---
--- Defines `spotter` and `hooks.after_jump`.
MiniJump2d.builtin_opts.line_start = {
  spotter = function(line_num, args)
    return { 1 }
  end,
  hooks = {
    after_jump = function()
      -- Move to first non-blank character
      vim.cmd('normal! ^')
    end,
  },
}

--- Jump to word start
---
--- Defines `spotter`.
MiniJump2d.builtin_opts.word_start = { spotter = MiniJump2d.gen_pattern_spotter('[^%s%p]+') }

-- Produce `opts` which modifies spotter based on user input
local function user_input_opts(input_fun)
  --stylua: ignore
  local res = {
    spotter = function() return {} end,
    allowed_lines = { blank = false, fold = false },
  }

  res.hooks = {
    before_start = function()
      local input = input_fun()
      if input == nil then
        --stylua: ignore
        res.spotter = function() return {} end
      else
        local pattern = vim.pesc(input)
        res.spotter = MiniJump2d.gen_pattern_spotter(pattern)
      end
    end,
  }

  return res
end

--- Jump to single character taken from user input
---
--- Defines `spotter`, `allowed_lines.blank`, `allowed_lines.fold`, and
--- `hooks.before_start`.
MiniJump2d.builtin_opts.single_character = user_input_opts(function()
  return H.getcharstr('Enter single character to search')
end)

--- Jump to query taken from user input
---
--- Defines `spotter`, `allowed_lines.blank`, `allowed_lines.fold`, and
--- `hooks.before_start`.
MiniJump2d.builtin_opts.query = user_input_opts(function()
  return H.input('Enter query to search')
end)

-- Helper data ================================================================
-- Module default config
H.default_config = MiniJump2d.config

-- Namespaces to be used withing module
H.ns_id = {
  spots = vim.api.nvim_create_namespace('MiniJump2dSpots'),
  input = vim.api.nvim_create_namespace('MiniJump2dInput'),
}

-- Table with current relevant data:
H.cache = {
  -- Array of shown spots
  spots = nil,
  -- Indicator of whether Neovim is currently in "getchar" mode
  is_in_getchar = false,
}

-- Table with special keys
H.keys = {
  esc = vim.api.nvim_replace_termcodes('<Esc>', true, true, true),
  cr = vim.api.nvim_replace_termcodes('<CR>', true, true, true),
  block_operator_pending = vim.api.nvim_replace_termcodes('no<C-V>', true, true, true),
}

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({
    spotter = { config.spotter, 'function', true },
    labels = { config.labels, 'string' },
    allowed_lines = { config.allowed_lines, 'table' },
    allowed_windows = { config.allowed_windows, 'table' },
    hooks = { config.hooks, 'table' },
    mappings = { config.mappings, 'table' },
  })

  vim.validate({
    ['allowed_lines.blank'] = { config.allowed_lines.blank, 'boolean' },
    ['allowed_lines.cursor_before'] = { config.allowed_lines.cursor_before, 'boolean' },
    ['allowed_lines.cursor_at'] = { config.allowed_lines.cursor_at, 'boolean' },
    ['allowed_lines.cursor_after'] = { config.allowed_lines.cursor_after, 'boolean' },
    ['allowed_lines.fold'] = { config.allowed_lines.fold, 'boolean' },

    ['allowed_windows.current'] = { config.allowed_windows.current, 'boolean' },
    ['allowed_windows.not_current'] = { config.allowed_windows.not_current, 'boolean' },

    ['hooks.before_start'] = { config.hooks.before_start, 'function', true },
    ['hooks.after_jump'] = { config.hooks.after_jump, 'function', true },

    ['mappings.start_jumping'] = { config.mappings.start_jumping, 'string' },
  })
  return config
end

function H.apply_config(config)
  MiniJump2d.config = config

  -- Apply mappings
  local keymap = config.mappings.start_jumping
  H.map('n', keymap, '<Cmd>lua MiniJump2d.start()<CR>', { desc = 'Start 2d jumping' })
  H.map('x', keymap, '<Cmd>lua MiniJump2d.start()<CR>', { desc = 'Start 2d jumping' })
  H.map('o', keymap, '<Cmd>lua MiniJump2d.start()<CR>', { desc = 'Start 2d jumping' })
end

function H.is_disabled()
  return vim.g.minijump2d_disable == true or vim.b.minijump2d_disable == true
end

-- Jump spots -----------------------------------------------------------------
function H.spots_compute(opts)
  local win_id_init = vim.api.nvim_get_current_win()
  local win_id_arr = vim.tbl_filter(function(win_id)
    if win_id == win_id_init then
      return opts.allowed_windows.current
    end
    return opts.allowed_windows.not_current
  end, H.tabpage_list_wins(0))

  local res = {}
  for _, win_id in ipairs(win_id_arr) do
    vim.api.nvim_win_call(win_id, function()
      local cursor_pos = vim.api.nvim_win_get_cursor(win_id)
      local spotter_args = { win_id = win_id, win_id_init = win_id_init }
      local buf_id = vim.api.nvim_win_get_buf(win_id)

      -- Use all currently visible lines
      for i = vim.fn.line('w0'), vim.fn.line('w$') do
        local columns = H.spot_find_in_line(i, spotter_args, opts, cursor_pos)
        -- Use all returned columns for particular line
        for _, col in ipairs(columns) do
          table.insert(res, { line = i, column = col, buf_id = buf_id, win_id = win_id })
        end
      end
    end)
  end
  return res
end

function H.spots_add_label(spots, opts)
  local label_tbl = vim.split(opts.labels, '')

  -- Example: with 3 label characters labels should evolve with progressing
  -- number of spots like this: 'a', 'ab', 'abc', 'aabc', 'aabbc', 'aabbcc',
  -- 'aaabbcc', 'aaabbbcc', 'aaabbbccc', etc.
  local n_spots, n_label_chars = #spots, #label_tbl
  local base, extra = math.floor(n_spots / n_label_chars), n_spots % n_label_chars

  local label_id, cur_label_count = 1, 0
  local label_max_count = base + (label_id <= extra and 1 or 0)
  for _, s in ipairs(spots) do
    s.label = label_tbl[label_id]
    cur_label_count = cur_label_count + 1
    if cur_label_count >= label_max_count then
      label_id, cur_label_count = label_id + 1, 0
      label_max_count = base + (label_id <= extra and 1 or 0)
    end
  end

  return spots
end

function H.spots_show(spots, opts)
  spots = spots or H.cache.spots or {}
  if #spots == 0 then
    H.message('No spots to show.')
    return
  end

  for _, extmark in ipairs(H.spots_to_extmarks(spots)) do
    local extmark_opts = {
      hl_mode = 'combine',
      -- Use very high priority
      priority = 1000,
      virt_text = { { extmark.text, opts.hl_group } },
      virt_text_pos = 'overlay',
    }
    pcall(vim.api.nvim_buf_set_extmark, extmark.buf_id, H.ns_id.spots, extmark.line, extmark.col, extmark_opts)
  end

  -- Need to redraw in Operator-pending mode, because otherwise extmarks won't
  -- be shown and deferring disables this mode.
  if H.is_operator_pending() then
    vim.cmd('redraw')
  end
end

function H.spots_unshow(spots)
  spots = spots or H.cache.spots or {}

  -- Remove spot extmarks from all buffers they are present
  local buf_ids = {}
  for _, s in ipairs(spots) do
    buf_ids[s.buf_id] = true
  end

  for _, buf_id in ipairs(vim.tbl_keys(buf_ids)) do
    pcall(vim.api.nvim_buf_clear_namespace, buf_id, H.ns_id.spots, 0, -1)
  end
end

--- Convert consecutive spots into single extmark
---
--- This considerably increases performance in case of many spots.
---@private
function H.spots_to_extmarks(spots)
  if #spots == 0 then
    return {}
  end

  local res = {}

  local buf_id, line, col = spots[1].buf_id, spots[1].line - 1, spots[1].column - 1
  local extmark_chars = {}
  local cur_col = col
  for _, s in ipairs(spots) do
    local is_within_same_extmark = s.buf_id == buf_id and s.line == (line + 1) and s.column == (cur_col + 1)

    if not is_within_same_extmark then
      table.insert(res, { buf_id = buf_id, col = col, line = line, text = table.concat(extmark_chars) })
      buf_id, line, col = s.buf_id, s.line - 1, s.column - 1
      extmark_chars = {}
    end

    table.insert(extmark_chars, s.label)
    cur_col = s.column
  end
  table.insert(res, { buf_id = buf_id, col = col, line = line, text = table.concat(extmark_chars) })

  return res
end

function H.spot_find_in_line(line_num, spotter_args, opts, cursor_pos)
  local allowed = opts.allowed_lines

  -- Adjust for cursor line
  local cur_line = cursor_pos[1]
  if
    (not allowed.cursor_before and line_num < cur_line)
    or (not allowed.cursor_at and line_num == cur_line)
    or (not allowed.cursor_after and line_num > cur_line)
  then
    return {}
  end

  -- Process folds
  local fold_indicator = vim.fn.foldclosed(line_num)
  if fold_indicator ~= -1 then
    return (allowed.fold and fold_indicator == line_num) and { 1 } or {}
  end

  -- Process blank lines
  if vim.fn.prevnonblank(line_num) ~= line_num then
    return allowed.blank and { 1 } or {}
  end

  -- Finally apply spotter
  return opts.spotter(line_num, spotter_args)
end

-- Jump state -----------------------------------------------------------------
function H.advance_jump(opts)
  local label_tbl = vim.split(opts.labels, '')

  local spots = H.cache.spots

  if type(spots) ~= 'table' or #spots < 1 then
    H.spots_unshow(spots)
    H.cache.spots = nil
    return
  end

  local key = H.getcharstr('Enter encoding symbol to advance jump')

  if vim.tbl_contains(label_tbl, key) then
    H.spots_unshow(spots)
    --stylua: ignore
    spots = vim.tbl_filter(function(x) return x.label == key end, spots)

    if #spots > 1 then
      spots = H.spots_add_label(spots, opts)
      H.spots_show(spots, opts)
      H.cache.spots = spots

      -- Defer advancing jump to allow drawing before invoking `getcharstr()`.
      -- This is much faster than having to call `vim.cmd('redraw')`. Don't do that
      -- in Operator-pending mode because it doesn't work otherwise.
      if H.is_operator_pending() then
        H.advance_jump(opts)
      else
        --stylua: ignore
        vim.defer_fn(function() H.advance_jump(opts) end, 0)
        return
      end
    end
  end

  if #spots == 1 or key == H.keys.cr then
    -- Add to jumplist
    vim.cmd('normal! m`')

    local first_spot = spots[1]
    vim.api.nvim_set_current_win(first_spot.win_id)
    vim.api.nvim_win_set_cursor(first_spot.win_id, { first_spot.line, first_spot.column - 1 })

    -- Possibly unfold to see cursor
    vim.cmd('normal! zv')

    --stylua: ignore
    if opts.hooks.after_jump ~= nil then opts.hooks.after_jump() end
  end

  MiniJump2d.stop()
end

-- Utilities ------------------------------------------------------------------
function H.message(msg)
  vim.cmd('echomsg ' .. vim.inspect('(mini.jump2d) ' .. msg))
end

function H.is_operator_pending()
  return vim.tbl_contains({ 'no', 'noV', H.keys.block_operator_pending }, vim.fn.mode(1))
end

function H.getcharstr(msg)
  local needs_help_msg = true
  if msg ~= nil then
    vim.defer_fn(function()
      --stylua: ignore
      if needs_help_msg then H.message(msg) end
    end, 1000)
  end

  -- Use `getchar()` because `getcharstr()` is present only in Neovim>=0.6
  -- Might want to remove if support for Neovim<0.6 is dropped
  H.cache.is_in_getchar = true
  local ok, char = pcall(vim.fn.getchar)
  H.cache.is_in_getchar = false
  needs_help_msg = false

  --stylua: ignore
  if not ok then return end

  if type(char) == 'number' then
    char = vim.fn.nr2char(char)
  end
  return char
end

function H.input(prompt, text)
  -- Distinguish between `<C-c>`, `<Esc>`, and first `<CR>`
  local on_key = vim.on_key or vim.register_keystroke_callback
  local was_cancelled = false
  on_key(function(key)
    if key == H.keys.esc then
      was_cancelled = true
    end
  end, H.ns_id.input)

  -- Ask for input
  local opts = { prompt = '(mini.jump2d) ' .. prompt .. ': ', default = text or '' }
  -- Use `pcall` to allow `<C-c>` to cancel user input
  local ok, res = pcall(vim.fn.input, opts)

  -- Stop key listening
  on_key(nil, H.ns_id.input)

  if not ok or was_cancelled then
    return
  end
  return res
end

--- This ensures order of windows based on their layout
---
--- This is already done by default in `nvim_tabpage_list_wins()`, but is not
--- documented, so can break any time.
---
---@private
function H.tabpage_list_wins(tabpage_id)
  local wins = vim.api.nvim_tabpage_list_wins(tabpage_id)
  local wins_pos = {}
  for _, win_id in ipairs(wins) do
    local pos = vim.api.nvim_win_get_position(win_id)
    local config = vim.api.nvim_win_get_config(win_id)
    wins_pos[win_id] = { row = pos[1], col = pos[2], zindex = config.zindex or 0 }
  end

  -- Sort windows by their position: top to bottom, left to right, low to high
  --stylua: ignore
  table.sort(wins, function(a, b)
    -- Put higher window further to have them processed later. This means that
    -- in case of same buffer in floating and underlying regular windows,
    -- floating will have "the latest" extmarks (think like `MiniMisc.zoom()`).
    if wins_pos[a].zindex < wins_pos[b].zindex then return true end
    if wins_pos[a].zindex > wins_pos[b].zindex then return false end

    if wins_pos[a].col < wins_pos[b].col then return true end
    if wins_pos[a].col > wins_pos[b].col then return false end

    return wins_pos[a].row < wins_pos[b].row
  end)

  return wins
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

function H.merge_unique(tbl_1, tbl_2)
  if not (type(tbl_1) == 'table' and type(tbl_2) == 'table') then
    return
  end

  local n_1, n_2 = #tbl_1, #tbl_2
  local res, i, j = {}, 1, 1
  local to_add
  while i <= n_1 and j <= n_2 do
    if tbl_1[i] < tbl_2[j] then
      to_add = tbl_1[i]
      i = i + 1
    else
      to_add = tbl_2[j]
      j = j + 1
    end
    if res[#res] ~= to_add then
      table.insert(res, to_add)
    end
  end

  while i <= n_1 do
    to_add = tbl_1[i]
    if res[#res] ~= to_add then
      table.insert(res, to_add)
    end
    i = i + 1
  end
  while j <= n_2 do
    to_add = tbl_2[j]
    if res[#res] ~= to_add then
      table.insert(res, to_add)
    end
    j = j + 1
  end

  return res
end

return MiniJump2d
