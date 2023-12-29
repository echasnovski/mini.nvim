--- *mini.misc* Miscellaneous functions
--- *MiniMisc*
---
--- MIT License Copyright (c) 2021 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Features the following functions:
--- - |MiniMisc.bench_time()| to benchmark function execution time.
---   Useful in combination with `stat_summary()`.
---
--- - |MiniMisc.put()| and |MiniMisc.put_text()| to pretty print its arguments
---   into command line and current buffer respectively.
---
--- - |MiniMisc.setup_auto_root()| to set up automated change of current directory.
---
--- - |MiniMisc.setup_restore_cursor()| to set up automated restoration of
---   cursor position on file reopen.
---
--- - |MiniMisc.stat_summary()| to compute summary statistics of numerical array.
---   Useful in combination with `bench_time()`.
---
--- - |MiniMisc.tbl_head()| and |MiniMisc.tbl_tail()| to return "first" and "last"
---   elements of table.
---
--- - |MiniMisc.zoom()| to zoom in and out of a buffer, making it full screen
---   in a floating window.
---
--- - And more.
---
--- # Setup ~
---
--- This module doesn't need setup, but it can be done to improve usability.
--- Setup with `require('mini.misc').setup({})` (replace `{}` with your
--- `config` table). It will create global Lua table `MiniMisc` which you can
--- use for scripting or manually (with `:lua MiniMisc.*`).
---
--- See |MiniMisc.config| for `config` structure and default values.
---
--- This module doesn't have runtime options, so using `vim.b.minimisc_config`
--- will have no effect here.

-- Module definition ==========================================================
local MiniMisc = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniMisc.config|.
---
---@usage `require('mini.misc').setup({})` (replace `{}` with your `config` table)
MiniMisc.setup = function(config)
  -- Export module
  _G.MiniMisc = MiniMisc

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniMisc.config = {
  -- Array of fields to make global (to be used as independent variables)
  make_global = { 'put', 'put_text' },
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Execute `f` several times and time how long it took
---
---@param f function Function which execution to benchmark.
---@param n number|nil Number of times to execute `f(...)`. Default: 1.
---@param ... any Arguments when calling `f`.
---
---@return ... Table with durations (in seconds; up to nanoseconds) and
---   output of (last) function execution.
MiniMisc.bench_time = function(f, n, ...)
  n = n or 1
  local durations, output = {}, nil
  for _ = 1, n do
    local start_time = vim.loop.hrtime()
    output = f(...)
    local end_time = vim.loop.hrtime()
    table.insert(durations, 0.000000001 * (end_time - start_time))
  end

  return durations, output
end

--- Compute width of gutter (info column on the left of the window)
---
---@param win_id number|nil Window identifier (see |win_getid()|) for which gutter
---   width is computed. Default: 0 for current.
MiniMisc.get_gutter_width = function(win_id)
  win_id = (win_id == nil or win_id == 0) and vim.api.nvim_get_current_win() or win_id
  return vim.fn.getwininfo(win_id)[1].textoff
end

--- Print Lua objects in command line
---
---@param ... any Any number of objects to be printed each on separate line.
MiniMisc.put = function(...)
  local objects = {}
  -- Not using `{...}` because it removes `nil` input
  for i = 1, select('#', ...) do
    local v = select(i, ...)
    table.insert(objects, vim.inspect(v))
  end

  print(table.concat(objects, '\n'))

  return ...
end

--- Print Lua objects in current buffer
---
---@param ... any Any number of objects to be printed each on separate line.
MiniMisc.put_text = function(...)
  local objects = {}
  -- Not using `{...}` because it removes `nil` input
  for i = 1, select('#', ...) do
    local v = select(i, ...)
    table.insert(objects, vim.inspect(v))
  end

  local lines = vim.split(table.concat(objects, '\n'), '\n')
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  vim.fn.append(lnum, lines)

  return ...
end

--- Resize window to have exact number of editable columns
---
---@param win_id number|nil Window identifier (see |win_getid()|) to be resized.
---   Default: 0 for current.
---@param text_width number|nil Number of editable columns resized window will
---   display. Default: first element of 'colorcolumn' or otherwise 'textwidth'
---   (using screen width as its default but not more than 79).
MiniMisc.resize_window = function(win_id, text_width)
  win_id = win_id or 0
  text_width = text_width or H.default_text_width(win_id)

  vim.api.nvim_win_set_width(win_id, text_width + MiniMisc.get_gutter_width(win_id))
end

H.default_text_width = function(win_id)
  local buf = vim.api.nvim_win_get_buf(win_id)
  local textwidth = vim.bo[buf].textwidth
  textwidth = (textwidth == 0) and math.min(vim.o.columns, 79) or textwidth

  local colorcolumn = vim.wo[win_id].colorcolumn
  if colorcolumn ~= '' then
    local cc = vim.split(colorcolumn, ',')[1]
    local is_cc_relative = vim.tbl_contains({ '-', '+' }, cc:sub(1, 1))

    if is_cc_relative then
      return textwidth + tonumber(cc)
    else
      return tonumber(cc)
    end
  else
    return textwidth
  end
end

--- Set up automated change of current directory
---
--- What it does:
--- - Creates autocommand which on every |BufEnter| event with |MiniMisc.find_root()|
---   finds root directory for current buffer file and sets |current-directory|
---   to it (using |chdir()|).
--- - Resets |autochdir| to `false`.
---
--- Note: requires |vim.fs| module (present in Neovim>=0.8).
---
---@param names table|function|nil Forwarded to |MiniMisc.find_root()|.
---@param fallback function|nil Forwarded to |MiniMisc.find_root()|.
---
---@usage >
---   require('mini.misc').setup()
---   MiniMisc.setup_auto_root()
MiniMisc.setup_auto_root = function(names, fallback)
  if vim.fs == nil then
    vim.notify('(mini.misc) `setup_auto_root()` requires `vim.fs` module (present in Neovim>=0.8).')
    return
  end

  names = names or { '.git', 'Makefile' }
  if not (H.is_array_of(names, H.is_string) or vim.is_callable(names)) then
    H.error('Argument `names` of `setup_auto_root()` should be array of string file names or a callable.')
  end

  fallback = fallback or function() return nil end
  if not vim.is_callable(fallback) then H.error('Argument `fallback` of `setup_auto_root()` should be callable.') end

  -- Disable conflicting option
  vim.o.autochdir = false

  -- Create autocommand
  local set_root = function(data)
    local root = MiniMisc.find_root(data.buf, names, fallback)
    if root == nil then return end
    vim.fn.chdir(root)
  end
  local augroup = vim.api.nvim_create_augroup('MiniMiscAutoRoot', {})
  vim.api.nvim_create_autocmd(
    'BufEnter',
    { group = augroup, callback = set_root, desc = 'Find root and change current directory' }
  )
end

--- Find root directory
---
--- Based on a buffer name (full path to file opened in a buffer) find a root
--- directory. If buffer is not associated with file, returns `nil`.
---
--- Root directory is a directory containing at least one of pre-defined files.
--- It is searched using |vim.fn.find()| with `upward = true` starting from
--- directory of current buffer file until first occurrence of root file(s).
---
--- Notes:
--- - Requires |vim.fs| module (present in Neovim>=0.8).
--- - Uses directory path caching to speed up computations. This means that no
---   changes in root directory will be detected after directory path was already
---   used in this function. Reload Neovim to account for that.
---
---@param buf_id number|nil Buffer identifier (see |bufnr()|) to use.
---   Default: 0 for current.
---@param names table|function|nil Array of file names or a callable used to
---   identify a root directory. Forwarded to |vim.fs.find()|.
---   Default: `{ '.git', 'Makefile' }`.
---@param fallback function|nil Callable fallback to use if no root is found
---   with |vim.fs.find()|. Will be called with a buffer path and should return
---   a valid directory path.
MiniMisc.find_root = function(buf_id, names, fallback)
  buf_id = buf_id or 0
  names = names or { '.git', 'Makefile' }
  fallback = fallback or function() return nil end

  if type(buf_id) ~= 'number' then H.error('Argument `buf_id` of `find_root()` should be number.') end
  if not (H.is_array_of(names, H.is_string) or vim.is_callable(names)) then
    H.error('Argument `names` of `find_root()` should be array of string file names or a callable.')
  end
  if not vim.is_callable(fallback) then H.error('Argument `fallback` of `find_root()` should be callable.') end

  -- Compute directory to start search from. NOTEs on why not using file path:
  -- - This has better performance because `vim.fs.find()` is called less.
  -- - *Needs* to be a directory for callable `names` to work.
  -- - Later search is done including initial `path` if directory, so this
  --   should work for detecting buffer directory as root.
  local path = vim.api.nvim_buf_get_name(buf_id)
  if path == '' then return end
  local dir_path = vim.fs.dirname(path)

  -- Try using cache
  local res = H.root_cache[dir_path]
  if res ~= nil then return res end

  -- Find root
  local root_file = vim.fs.find(names, { path = dir_path, upward = true })[1]
  if root_file ~= nil then
    res = vim.fs.dirname(root_file)
  else
    res = fallback(path)
  end

  -- Use absolute path to an existing directory
  if type(res) ~= 'string' then return end
  res = vim.fn.fnamemodify(res, ':p')
  if vim.fn.isdirectory(res) == 0 then return end

  -- Cache result per directory path
  H.root_cache[dir_path] = res

  return res
end

H.root_cache = {}

--- Restore cursor position on file open
---
--- When reopening a file this will make sure the cursor is placed back to the
--- position where you left before. This implements |restore-cursor| in a nicer way.
--- File should have a recognized file type (see 'filetype') and be opened in
--- a normal buffer (see 'buftype').
---
--- Note: it relies on file mark data stored in 'shadafile' (see |shada-f|).
--- Be sure to enable it.
---
---@param opts table|nil Options for |MiniMisc.restore_cursor|. Possible fields:
---   - <center> - (boolean) Center the window after we restored the cursor.
---     Default: `true`.
---   - <ignore_filetype> - Array with file types to be ignored (see 'filetype').
---     Default: `{ "gitcommit", "gitrebase" }`.
---
---@usage >
---   require('mini.misc').setup_restore_cursor()
MiniMisc.setup_restore_cursor = function(opts)
  opts = opts or {}

  opts.ignore_filetype = opts.ignore_filetype or { 'gitcommit', 'gitrebase' }
  if not H.is_array_of(opts.ignore_filetype, H.is_string) then
    H.error('In `setup_restore_cursor()` `opts.ignore_filetype` should be an array of strings.')
  end

  if opts.center == nil then opts.center = true end
  if type(opts.center) ~= 'boolean' then H.error('In `setup_restore_cursor()` `opts.center` should be a boolean.') end

  -- Create autocommand which runs once on `FileType` for every new buffer
  local augroup = vim.api.nvim_create_augroup('MiniMiscRestoreCursor', {})
  vim.api.nvim_create_autocmd('BufReadPre', {
    group = augroup,
    callback = function(data)
      vim.api.nvim_create_autocmd('FileType', {
        buffer = data.buf,
        once = true,
        callback = function() H.restore_cursor(opts) end,
      })
    end,
  })
end

H.restore_cursor = function(opts)
  -- Stop if not a normal buffer
  if vim.bo.buftype ~= '' then return end

  -- Stop if filetype is ignored
  if vim.tbl_contains(opts.ignore_filetype, vim.bo.filetype) then return end

  -- Stop if line is already specified (like during start with `nvim file +num`)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  if cursor_line > 1 then return end

  -- Stop if can't restore proper line for some reason
  local mark_line = vim.api.nvim_buf_get_mark(0, [["]])[1]
  local n_lines = vim.api.nvim_buf_line_count(0)
  if not (1 <= mark_line and mark_line <= n_lines) then return end

  -- Restore cursor and open just enough folds
  vim.cmd([[normal! g`"zv]])

  -- Center window
  if opts.center then vim.cmd('normal! zz') end
end

--- Compute summary statistics of numerical array
---
--- This might be useful to compute summary of time benchmarking with
--- |MiniMisc.bench_time|.
---
---@param t table Array (table suitable for `ipairs`) of numbers.
---
---@return table Table with summary values under following keys (may be
---   extended in the future): <maximum>, <mean>, <median>, <minimum>, <n>
---   (number of elements), <sd> (sample standard deviation).
MiniMisc.stat_summary = function(t)
  if not H.is_array_of(t, H.is_number) then
    H.error('Input of `MiniMisc.stat_summary()` should be an array of numbers.')
  end

  -- Welford algorithm of computing variance
  -- Source: https://www.johndcook.com/blog/skewness_kurtosis/
  local n = #t
  local delta, m1, m2 = 0, 0, 0
  local minimum, maximum = math.huge, -math.huge
  for i, x in ipairs(t) do
    delta = x - m1
    m1 = m1 + delta / i
    m2 = m2 + delta * (x - m1)

    -- Extremums
    minimum = x < minimum and x or minimum
    maximum = x > maximum and x or maximum
  end

  return {
    maximum = maximum,
    mean = m1,
    median = H.compute_median(t),
    minimum = minimum,
    n = n,
    sd = math.sqrt(n > 1 and m2 / (n - 1) or 0),
  }
end

H.compute_median = function(t)
  local n = #t
  if n == 0 then return 0 end

  local t_sorted = vim.deepcopy(t)
  table.sort(t_sorted)
  return 0.5 * (t_sorted[math.ceil(0.5 * n)] + t_sorted[math.ceil(0.5 * (n + 1))])
end

--- Return "first" elements of table as decided by `pairs`
---
--- Note: order of elements might vary.
---
---@param t table Input table.
---@param n number|nil Maximum number of first elements. Default: 5.
---
---@return table Table with at most `n` first elements of `t` (with same keys).
MiniMisc.tbl_head = function(t, n)
  n = n or 5
  local res, n_res = {}, 0
  for k, val in pairs(t) do
    if n_res >= n then return res end
    res[k] = val
    n_res = n_res + 1
  end
  return res
end

--- Return "last" elements of table as decided by `pairs`
---
--- This function makes two passes through elements of `t`:
--- - First to count number of elements.
--- - Second to construct result.
---
--- Note: order of elements might vary.
---
---@param t table Input table.
---@param n number|nil Maximum number of last elements. Default: 5.
---
---@return table Table with at most `n` last elements of `t` (with same keys).
MiniMisc.tbl_tail = function(t, n)
  n = n or 5

  -- Count number of elements on first pass
  local n_all = 0
  for _, _ in pairs(t) do
    n_all = n_all + 1
  end

  -- Construct result on second pass
  local res = {}
  local i, start_i = 0, n_all - n + 1
  for k, val in pairs(t) do
    i = i + 1
    if i >= start_i then res[k] = val end
  end
  return res
end

--- Add possibility of nested comment leader
---
--- This works by parsing 'commentstring' buffer option, extracting
--- non-whitespace comment leader (symbols on the left of commented line), and
--- locally modifying 'comments' option (by prepending `n:<leader>`). Does
--- nothing if 'commentstring' is empty or has comment symbols both in front
--- and back (like "/*%s*/").
---
--- Nested comment leader added with this function is useful for formatting
--- nested comments. For example, have in Lua "first-level" comments with '--'
--- and "second-level" comments with '----'. With nested comment leader second
--- type can be formatted with `gq` in the same way as first one.
---
--- Recommended usage is with |autocmd|:
--- `autocmd BufEnter * lua pcall(require('mini.misc').use_nested_comments)`
---
--- Note: for most filetypes 'commentstring' option is added only when buffer
--- with this filetype is entered, so using non-current `buf_id` can not lead
--- to desired effect.
---
---@param buf_id number|nil Buffer identifier (see |bufnr()|) in which function
---   will operate. Default: 0 for current.
MiniMisc.use_nested_comments = function(buf_id)
  buf_id = buf_id or 0

  local commentstring = vim.bo[buf_id].commentstring
  if commentstring == '' then return end

  -- Extract raw comment leader from 'commentstring' option
  local comment_parts = vim.tbl_filter(function(x) return x ~= '' end, vim.split(commentstring, '%s', true))

  -- Don't do anything if 'commentstring' is like '/*%s*/' (as in 'json')
  if #comment_parts > 1 then return end

  -- Get comment leader by removing whitespace
  local leader = vim.trim(comment_parts[1])

  local comments = vim.bo[buf_id].comments
  local new_comments = string.format('n:%s,%s', leader, comments)
  vim.api.nvim_buf_set_option(buf_id, 'comments', new_comments)
end

--- Zoom in and out of a buffer, making it full screen in a floating window
---
--- This function is useful when working with multiple windows but temporarily
--- needing to zoom into one to see more of the code from that buffer. Call it
--- again (without arguments) to zoom out.
---
---@param buf_id number|nil Buffer identifier (see |bufnr()|) to be zoomed.
---   Default: 0 for current.
---@param config table|nil Optional config for window (as for |nvim_open_win()|).
MiniMisc.zoom = function(buf_id, config)
  if H.zoom_winid and vim.api.nvim_win_is_valid(H.zoom_winid) then
    vim.api.nvim_win_close(H.zoom_winid, true)
    H.zoom_winid = nil
  else
    buf_id = buf_id or 0
    -- Currently very big `width` and `height` get truncated to maximum allowed
    local default_config = { relative = 'editor', row = 0, col = 0, width = 1000, height = 1000 }
    config = vim.tbl_deep_extend('force', default_config, config or {})
    H.zoom_winid = vim.api.nvim_open_win(buf_id, true, config)
    vim.wo.winblend = 0
    vim.cmd('normal! zz')
  end
end

-- Helper data ================================================================
-- Module default config
H.default_config = vim.deepcopy(MiniMisc.config)

-- Window identifier of current zoom (for `zoom()`)
H.zoom_winid = nil

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({
    make_global = {
      config.make_global,
      function(x)
        if type(x) ~= 'table' then return false end
        local present_fields = vim.tbl_keys(MiniMisc)
        for _, v in pairs(x) do
          if not vim.tbl_contains(present_fields, v) then return false end
        end
        return true
      end,
      '`make_global` should be a table with `MiniMisc` actual fields',
    },
  })

  return config
end

H.apply_config = function(config)
  MiniMisc.config = config

  for _, v in pairs(config.make_global) do
    _G[v] = MiniMisc[v]
  end
end

-- Utilities ------------------------------------------------------------------
H.error = function(msg) error(string.format('(mini.misc) %s', msg)) end

H.is_array_of = function(x, predicate)
  if not vim.tbl_islist(x) then return false end
  for _, v in ipairs(x) do
    if not predicate(v) then return false end
  end
  return true
end

H.is_number = function(x) return type(x) == 'number' end

H.is_string = function(x) return type(x) == 'string' end

return MiniMisc
