--- *mini.diff* Work with diff hunks
--- *MiniDiff*
---
--- MIT License Copyright (c) 2024 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Features:
---
--- - Visualize difference between buffer text and its configurable reference
---   interactively (updates as you type). This is done per line showing whether
---   it is inside added, changed, or deleted part of difference (called hunk).
---   Visualization can be with customizable colored signs or line numbers.
---
--- - Special toggleable overlay view with more hunk details inside text area.
---   See |MiniDiff.toggle_overlay()|.
---
--- - Completely configurable per buffer source of reference text used to keep
---   it up to date and define interactions with it.
---   See |MiniDiff-source-specification|. By default uses buffer's file content
---   in Git index. See |MiniDiff.gen_source.git()|.
---
--- - Configurable mappings to manage diff hunks:
---     - Apply and reset hunks inside region (selected visually or with
---       a dot-repeatable operator).
---     - "Hunk range under cursor" textobject to be used as operator target.
---     - Navigate to first/previous/next/last hunk. See |MiniDiff.goto_hunk()|.
---
--- What it doesn't do:
---
--- - Provide functionality to work directly with Git outside of visualizing
---   and staging (applying) hunks with (default) Git source. In particular,
---   unstaging hunks is not supported. See |MiniDiff.gen_source.git()|.
---
--- Sources with more details:
--- - |MiniDiff-overview|
--- - |MiniDiff-source-specification|
--- - |MiniDiff-hunk-specification|
--- - |MiniDiff-diff-summary|
---
--- # Setup ~
---
--- This module needs a setup with `require('mini.diff').setup({})` (replace
--- `{}` with your `config` table). It will create global Lua table `MiniDiff`
--- which you can use for scripting or manually (with `:lua MiniDiff.*`).
---
--- See |MiniDiff.config| for `config` structure and default values.
---
--- You can override runtime config settings locally to buffer inside
--- `vim.b.minidiff_config` which should have same structure as
--- `MiniDiff.config`. See |mini.nvim-buffer-local-config| for more details.
---
--- # Comparisons ~
---
--- - 'lewis6991/gitsigns.nvim':
---     - Main inspiration for this module, so there are many similarities.
---     - Can display only Git hunks, while this module has extensible design.
---     - Provides more functionality to work with Git outside of hunks.
---       This module does not (by design).
---
--- # Highlight groups ~
---
--- * `MiniDiffSignAdd`     - "add" hunk lines visualization.
--- * `MiniDiffSignChange`  - "change" hunk lines visualization.
--- * `MiniDiffSignDelete`  - "delete" hunk lines visualization.
--- * `MiniDiffOverAdd`     - added text shown in overlay.
--- * `MiniDiffOverChange`  - changed text shown in overlay.
--- * `MiniDiffOverContext` - context of changed text shown in overlay.
--- * `MiniDiffOverDelete`  - deleted text shown in overlay.
---
--- To change any highlight group, modify it directly with |:highlight|.

--- # Diffs and hunks ~
---
--- The "diff" (short for "difference") is a result of computing how two text
--- strings differ from one another. This is done on per line basis, i.e. the
--- goal is to compute sequences of lines common to both files, interspersed
--- with groups of differing lines (called "hunks").
---
--- Although computing diff is a general concept (used on its own, in Git, etc.),
--- this module computes difference between current text in a buffer and some
--- reference text which is kept up to date specifically for that buffer.
--- For example, default reference text is computed as file content in Git index.
--- This can be customized in `config.source` (see |MiniDiff-source-specification|).
---
---                                                    *MiniDiff-hunk-specification*
--- Hunk describes two sets (one from buffer text, one - from reference) of
--- consecutive lines which are different. In this module hunk is stored as
--- a table with the following fields:
---
--- - <buf_start> `(number)` - start of hunk buffer lines. First line is 1.
---   Can be 0 if first reference lines are deleted.
---
--- - <buf_count> `(number)` - number of consecutive buffer lines. Can be 0 in
---   case reference lines are deleted.
---
--- - <ref_start> `(number)` - start of hunk reference lines. First line is 1.
---   Can be 0 if lines are added before first reference line.
---
--- - <ref_count> `(number)` - number of consecutive reference lines. Can be 0 in
---   case buffer lines are added.
---
--- - <type> `(string)` - hunk type. Can be one of:
---     - "add" - lines are present in buffer but absent in reference.
---     - "change" - lines are present in both buffer and reference.
---     - "delete" - lines are absent in buffer but present in reference.
---
--- # Life cycle ~
---
--- - When entering proper (not already enabled, valid, showing text) buffer,
---   it is attempted to be enabled for diff processing.
--- - During enabling, attempt attaching the source. This should set up how
---   reference text is kept up to date.
--- - On every text change, diff computation is scheduled in debounced fashion
---   after customizable delay (200 ms by default).
--- - After the diff is computed, do the following:
---     - Update visualization based on configurable style: either by placing
---       colored text in sign column or coloring line numbers. Colors for both
---       styles are defined per hunk type in corresponding `MiniDiffSign*`
---       highlight group (see |MiniDiff|) and sign text for "sign" style can
---       be configured in `view.signs` of |MiniDiff.config|.
---     - Update overlay view (if it is enabled).
---     - Update `vim.b.minidiff_summary` and `vim.b.minidiff_summary_string`
---       buffer-local variables. These can be used, for example, in statusline.
---     - Trigger `MiniDiffUpdated` `User` event. See |MiniDiff-diff-summary| for
---       example of how to use it.
---
--- Notes:
--- - Use |:edit| to reset (disable and re-enable) current buffer.
---
--- # Overlay ~
---
--- Along with basic visualization, there is a special view called "overlay".
--- Although it is meant for temporary overview of diff details and can be
--- manually toggled via |MiniDiff.toggle_overlay()|, text can be changed with
--- overlay reacting accordingly.
---
--- It shows more diff details inside text area:
---
--- - Added buffer lines are highlighted with `MiniDiffOverAdd` highlight group.
---
--- - Deleted reference lines are shown as virtual text and highlighted with
---   `MiniDiffOverDelete` highlight group.
---
--- - Changed reference lines are shown as virtual text and highlighted with
---   `MiniDiffOverChange` highlight group.
---
---   "Change" hunks with equal number of buffer and reference lines have special
---   treatment and show "word diff". Reference line is shown next to its buffer
---   counterpart and only changed parts of both lines are highlighted with
---   `MiniDiffOverChange`. The rest of reference line has `MiniDiffOverContext`
---   highlighting.
---   This usually is the case when `config.options.linematch` is enabled.
---
--- Notes:
--- - Word diff has non-zero context width. This means if changed characters
---   are close enough, whole range between them is also colored. This usually
---   reduces visual noise.
--- - Virtual lines above line 1 (like deleted or changed lines) need manual
---   scroll to become visible (with |CTRL-Y|).
---
--- # Mappings ~
---
--- This module provides mappings for common actions with diffs, like:
--- - Apply and reset hunks.
--- - "Hunk range under cursor" textobject.
--- - Go to first/previous/next/last hunk range.
---
--- Examples:
--- - `vip` followed by `gh` / `gH` applies/resets hunks inside current paragraph.
---   Same can be achieved in operator form `ghip` / `gHip`, which has the
---   advantage of being dot-repeatable (see |single-repeat|).
--- - `gh_` / `gH_` applies/resets current line (even if it is not a full hunk).
--- - `ghgh` / `gHgh` applies/resets hunk range under cursor.
--- - `dgh` deletes hunk range under cursor.
--- - `[H` / `[h` / `]h` / `]H` navigate cursor to the first / previous / next / last
---   hunk range of the current buffer.
---
--- # Buffer-local variables ~
---                                                          *MiniDiff-diff-summary*
--- Each enabled buffer has the following buffer-local variables which can be
--- used in custom statusline to show an overview of hunks in current buffer:
---
--- - `vim.b.minidiff_summary` is a table with the following fields:
---     - `source_name` - name of the source.
---     - `n_ranges` - number of hunk ranges (sequences of contiguous hunks).
---     - `add` - number of added lines.
---     - `change` - number of changed lines.
---     - `delete` - number of deleted lines.
---
--- - `vim.b.minidiff_summary_string` is a string representation of summary
---   with a fixed format. It is expected to be used as is. To achieve
---   different formatting, use `vim.b.minidiff_summary` to construct one.
---   The best way to do this is by overriding `vim.b.minidiff_summary_string`
---   in the callback for `MiniDiffUpdated` event: >
---
---   local format_summary = function(data)
---     local summary = vim.b[data.buf].minidiff_summary
---     local t = {}
---     if summary.add > 0 then table.insert(t, '+' .. summary.add) end
---     if summary.change > 0 then table.insert(t, '~' .. summary.change) end
---     if summary.delete > 0 then table.insert(t, '-' .. summary.delete) end
---     vim.b[data.buf].minidiff_summary_string = table.concat(t, ' ')
---   end
---   local au_opts = { pattern = 'MiniDiffUpdated', callback = format_summary }
---   vim.api.nvim_create_autocmd('User', au_opts)
---@tag MiniDiff-overview

---@alias __diff_buf_id number Target buffer identifier. Default: 0 for current buffer.

---@diagnostic disable:undefined-field
---@diagnostic disable:discard-returns
---@diagnostic disable:unused-local
---@diagnostic disable:cast-local-type
---@diagnostic disable:undefined-doc-name
---@diagnostic disable:luadoc-miss-type-name

-- Module definition ==========================================================
local MiniDiff = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniDiff.config|.
---
---@usage `require('mini.diff').setup({})` (replace `{}` with your `config` table).
MiniDiff.setup = function(config)
  -- Export module
  _G.MiniDiff = MiniDiff

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Define behavior
  H.create_autocommands()
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    H.auto_enable({ buf = buf_id })
  end

  -- Create default highlighting
  H.create_default_hl()
end

--stylua: ignore
--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # View ~
---
--- `config.view` contains settings for how diff hunks are visualized.
--- Example of using custom signs: >
---
---   require('mini.diff').setup({
---     view = {
---       style = 'sign',
---       signs = { add = '+', change = '~', delete = '-' },
---     },
---   })
--- <
--- `view.style` is a string defining visualization style. Can be one of "sign"
--- (as a colored sign in a |sign-column|) or "number" (colored line number).
--- Default: "number" if |number| option is enabled, "sign" otherwise.
--- Note: with "sign" style it is usually better to have |signcolumn| always shown.
---
--- `view.signs` is a table with one or two character strings used as signs for
--- corresponding ("add", "change", "delete") hunks.
--- Default: all hunks use "▒" character resulting in a contiguous colored lines.
---
--- `view.priority` is a number with priority used for visualization and
--- overlay |extmarks|.
--- Default: one less than `user` in |vim.highlight.priorities| (to have higher
--- priority than automated extmarks but not as in user enabled ones).
---
---                                                  *MiniDiff-source-specification*
--- # Source ~
---
--- `config.source` is a table defining how reference text is managed in
--- a particular buffer. It can have the following fields:
--- - <attach> `(function)` - callable which defines how and when reference text
---   should be updated inside a particular buffer. It is called
---   inside |MiniDiff.enable()| with a buffer identifier as a single argument.
---
---   Should execute logic which results into calling |MiniDiff.set_ref_text()|
---   when reference text for buffer needs to be updated. Like inside callback
---   for an |autocommand| or file watcher (see |watch-file|).
---
---   For example, default Git source watches when ".git/index" file is changed
---   and computes reference text as the one from Git index for current file.
---
---   Can return `false` to force buffer to not be enabled. If this can not be
---   inferred immediately (for example, due to asynchronous execution), should
---   call |MiniDiff.disable()| later to disable buffer.
---
---   No default value, should be always supplied.
---
--- - <name> `(string|nil)` - source name. String `"unknown"` is used if not supplied.
---
--- - <detach> `(function|nil)` - callable with cleanup action to be done when
---   buffer is disabled. It is called inside |MiniDiff.disable()| with a buffer
---   identifier as a single argument.
---
---   If not supplied, nothing is done during detaching.
---
--- - <apply_hunks> `(function|nil)` - callable which defines how hunks are applied.
---   It is called with buffer identifier as first argument and array of hunks
---   (see |MiniDiff-hunk-specification|) as second. It should eventually update
---   reference text: either by explicitly calling |MiniDiff.set_ref_text()| or
---   performing action triggering its call.
---
---   For example, default Git source computes patch based on the hunks and
---   applies it inside file's git repo.
---
---   If not supplied, applying hunks throws an error.
---
--- Default: |MiniDiff.gen_source.git()|.
---
--- # Delay ~
---
--- `config.delay` contains settings for delays in asynchronous processes.
---
--- `delay.text_change` is a number (in ms) defining how long to wait after latest
--- text change (in debounced fashion) before updating diff and visualization.
--- Default: 200.
---
--- # Mappings ~
---
--- `config.mappings` contains keys which are mapped during |MiniDiff.setup()|.
---
--- `mappings.apply` keys can be used to apply hunks inside visual/operator region.
--- What exactly "apply hunks" means depends on the source and its `apply_hunks()`.
--- For example, in default Git source it means stage hunks.
---
--- `mappings.reset` keys can be used to reset hunks inside visual/operator region.
--- Reset means replacing buffer text in region with corresponding reference text.
---
--- `mappings.textobject` keys define "hunk range under cursor" textobject
--- which can be used in Operator-pending mode as target for operator (like
--- |d|, |y|, apply/reset hunks, etc.). It is "hunk range" in a sense that
--- contiguous (back-to-back) hunks are considered as parts of a same hunk range.
---
--- `mappings.goto_first` / `mappings.goto_prev` / `mappings.goto_next` /
--- `mappings.goto_last` keys can be used to navigate to first / previous / next /
--- last hunk range in the current buffer.
---
--- # Options ~
---
--- `config.options` contains various customization options.
---
--- `options.algorithm` is a string defining which diff algorithm to use.
--- Default: "histogram". See |vim.diff()| for possible values.
---
--- `options.indent_heuristic` is a boolean defining whether to use indent
--- heuristic for a (possibly) more naturally aligned hunks.
--- Default: `true`.
---
--- `options.linematch` is a number defining hunk size for which a second
--- stage diff is executed for a better aligned and more granular hunks.
--- Note: present only in Neovim>=0.9.
--- Default: 60. See |vim.diff()| and 'diffopt' for more details.
---
--- `options.wrap_goto` is a boolean indicating whether to wrap around edges during
--- hunk navigation (with |MiniDiff.goto_hunk()| or `goto_*` mappings). Like if
--- cursor is after the last hunk, going "next" will put cursor on the first hunk.
--- Default: `false`.
MiniDiff.config = {
  -- Options for how hunks are visualized
  view = {
    -- Visualization style. Possible values are 'sign' and 'number'.
    -- Default: 'number' if line numbers are enabled, 'sign' otherwise.
    style = vim.go.number and 'number' or 'sign',

    -- Signs used for hunks with 'sign' view
    signs = { add = '▒', change = '▒', delete = '▒' },

    -- Priority of used visualization extmarks
    priority = vim.highlight.priorities.user - 1,
  },

  -- Source for how reference text is computed/updated/etc
  -- Uses content from Git index by default
  source = nil,

  -- Delays (in ms) defining asynchronous processes
  delay = {
    -- How much to wait before update following every text change
    text_change = 200,
  },

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    -- Apply hunks inside a visual/operator region
    apply = 'gh',

    -- Reset hunks inside a visual/operator region
    reset = 'gH',

    -- Hunk range textobject to be used inside operator
    textobject = 'gh',

    -- Go to hunk range in corresponding direction
    goto_first = '[H',
    goto_prev = '[h',
    goto_next = ']h',
    goto_last = ']H',
  },

  -- Various options
  options = {
    -- Diff algorithm. See `:h vim.diff()`.
    algorithm = 'histogram',

    -- Whether to use "indent heuristic". See `:h vim.diff()`.
    indent_heuristic = true,

    -- The amount of second-stage diff to align lines (in Neovim>=0.9)
    linematch = 60,

    -- Whether to wrap around edges during hunk navigation
    wrap_goto = false,
  },
}
--minidoc_afterlines_end

--- Enable diff processing in buffer
---
---@param buf_id __diff_buf_id
MiniDiff.enable = function(buf_id)
  buf_id = H.validate_buf_id(buf_id)

  -- Don't enable more than once
  if H.is_buf_enabled(buf_id) or H.is_disabled(buf_id) then return end

  -- Ensure buffer is loaded (to have up to date lines returned)
  if not vim.api.nvim_buf_is_loaded(buf_id) then vim.fn.bufload(buf_id) end

  -- Register enabled buffer with cached data for performance
  H.update_buf_cache(buf_id)

  -- Try attaching source
  local attach_output = H.cache[buf_id].source.attach(buf_id)
  if attach_output == false then return MiniDiff.disable(buf_id) end

  -- Add buffer watchers
  vim.api.nvim_buf_attach(buf_id, false, {
    -- Called on every text change (`:h nvim_buf_lines_event`)
    on_lines = function(_, _, _, from_line, _, to_line)
      local buf_cache = H.cache[buf_id]
      -- Properly detach if diffing is disabled
      if buf_cache == nil then return true end
      H.schedule_diff_update(buf_id, buf_cache.config.delay.text_change)
    end,

    -- Called when buffer content is changed outside of current session
    on_reload = function() H.schedule_diff_update(buf_id, 0) end,

    -- Called when buffer is unloaded from memory (`:h nvim_buf_detach_event`),
    -- **including** `:edit` command
    on_detach = function() MiniDiff.disable(buf_id) end,
  })

  -- Add buffer autocommands
  H.setup_buf_autocommands(buf_id)
end

--- Disable diff processing in buffer
---
---@param buf_id __diff_buf_id
MiniDiff.disable = function(buf_id)
  buf_id = H.validate_buf_id(buf_id)

  local buf_cache = H.cache[buf_id]
  if buf_cache == nil then return end
  H.cache[buf_id] = nil

  pcall(vim.api.nvim_del_augroup_by_id, buf_cache.augroup)
  H.clear_all_diff(buf_id)
  pcall(buf_cache.source.detach, buf_id)
end

--- Toggle diff processing in buffer
---
--- Enable if disabled, disable if enabled.
---
---@param buf_id __diff_buf_id
MiniDiff.toggle = function(buf_id)
  buf_id = H.validate_buf_id(buf_id)
  if H.is_buf_enabled(buf_id) then return MiniDiff.disable(buf_id) end
  return MiniDiff.enable(buf_id)
end

--- Toggle overlay view in buffer
---
---@param buf_id __diff_buf_id
MiniDiff.toggle_overlay = function(buf_id)
  buf_id = H.validate_buf_id(buf_id)
  local buf_cache = H.cache[buf_id]
  if buf_cache == nil then H.error(string.format('Buffer %d is not enabled.', buf_id)) end

  buf_cache.overlay = not buf_cache.overlay
  H.clear_all_diff(buf_id)
  H.schedule_diff_update(buf_id, 0)
end

--- Export hunks
---
--- Get and convert hunks from current/all buffers. Example of using it: >
---
---   -- Set quickfix list from all available hunks
---   vim.fn.setqflist(MiniDiff.export('qf'))
--- <
---@param format string Output format. Currently only `'qf'` value is supported.
---@param opts table|nil Options. Possible fields:
---   - <scope> `(string)` - scope defining from which buffers to use hunks.
---     One of "all" (all enabled buffers) or "current".
---
---@return table Result of export. Depends on the `format`:
---   - If "qf", an array compatible with |setqflist()| and |setloclist()|.
MiniDiff.export = function(format, opts)
  opts = vim.tbl_deep_extend('force', { scope = 'all' }, opts or {})
  if format == 'qf' then return H.export_qf(opts) end
  H.error('`format` should be one of "qf".')
end

--- Get buffer data
---
---@param buf_id __diff_buf_id
---
---@return table|nil Table with buffer diff data or `nil` if buffer is not enabled.
---   Table has the following fields:
---   - <config> `(table)` - config used for this particular buffer.
---   - <hunks> `(table)` - array of hunks. See |MiniDiff-hunk-specification|.
---   - <overlay> `(boolean)` - whether an overlay view is shown.
---   - <ref_text> `(string|nil)` - current value of reference text. Lines are
---     separated with newline character (`'\n'`). Can be `nil` indicating that
---     reference text was not yet set (for example, if source did not yet react).
---   - <summary> `(table)` - overall diff summary. See |MiniDiff-diff-summary|.
MiniDiff.get_buf_data = function(buf_id)
  buf_id = H.validate_buf_id(buf_id)
  local buf_cache = H.cache[buf_id]
  if buf_cache == nil then return nil end
  return vim.deepcopy({
    config = buf_cache.config,
    hunks = buf_cache.hunks,
    overlay = buf_cache.overlay,
    ref_text = buf_cache.ref_text,
    summary = buf_cache.summary,
  })
end

--- Set reference text for the buffer
---
--- Note: this will call |MiniDiff.enable()| for target buffer if it is not
--- already enabled.
---
---@param buf_id __diff_buf_id
---@param text string|table New reference text. Either a string with `\n` used to
---   separate lines or array of lines. Use empty table to unset current
---   reference text (results into no hunks shown). Default: `{}`.
---   Note: newline character is appended at the end (if it is not there already)
---   for better diffs.
MiniDiff.set_ref_text = function(buf_id, text)
  buf_id = H.validate_buf_id(buf_id)
  if not (type(text) == 'table' or type(text) == 'string') then H.error('`text` should be either string or array.') end
  if type(text) == 'table' then text = #text > 0 and table.concat(text, '\n') or nil end

  -- Enable if not already enabled
  if not H.is_buf_enabled(buf_id) then MiniDiff.enable(buf_id) end
  if not H.is_buf_enabled(buf_id) then H.error('Can not set reference text for not enabled buffer.') end

  -- Appending '\n' makes more intuitive diffs at end-of-file
  if text ~= nil and string.sub(text, -1) ~= '\n' then text = text .. '\n' end
  if text == nil then
    H.clear_all_diff(buf_id)
    vim.cmd('redraw')
  end

  -- Immediately update diff
  H.cache[buf_id].ref_text = text
  H.schedule_diff_update(buf_id, 0)
end

--- Generate builtin sources
---
--- This is a table with function elements. Call to actually get source.
--- Example of using |MiniDiff.gen_source.save()|: >
---
---   local diff = require('mini.diff')
---   diff.setup({ source = diff.gen_source.save() })
MiniDiff.gen_source = {}

--- Git source
---
--- Default source. Uses file text from Git index as reference. This results in:
--- - "Add" hunks represent text present in current buffer, but not in index.
--- - "Change" hunks represent modified text already present in index.
--- - "Delete" hunks represent text deleted from index.
---
--- Applying hunks means staging, a.k.a adding to index.
--- Notes:
--- - Requires Git version at least 2.38.0.
--- - There is no capability for unstaging hunks. Use full Git client for that.
---
---@return table Source. See |MiniDiff-source-specification|.
MiniDiff.gen_source.git = function()
  local attach = function(buf_id)
    -- Try attaching to a buffer only once
    if H.git_cache[buf_id] ~= nil then return false end
    local path = vim.api.nvim_buf_get_name(buf_id)
    if path == '' or vim.fn.filereadable(path) ~= 1 then return false end

    H.git_cache[buf_id] = {}
    H.git_start_watching_index(buf_id, path)
  end

  local detach = function(buf_id)
    local cache = H.git_cache[buf_id]
    H.git_cache[buf_id] = nil
    H.git_invalidate_cache(cache)
  end

  local apply_hunks = function(buf_id, hunks)
    local path_data = H.git_get_path_data(vim.api.nvim_buf_get_name(buf_id))
    if path_data == nil or path_data.rel_path == nil then return end
    local patch = H.git_format_patch(buf_id, hunks, path_data)
    H.git_apply_patch(path_data, patch)
  end

  return { name = 'git', attach = attach, detach = detach, apply_hunks = apply_hunks }
end

--- "Do nothing" source
---
--- Allows buffers to be enabled while not setting any reference text.
--- Use this if the goal is to rely on manual |MiniDiff.set_ref_text()| calls.
---
---@return table Source. See |MiniDiff-source-specification|.
MiniDiff.gen_source.none = function()
  return { name = 'none', attach = function() end }
end

--- Latest save source
---
--- Uses text at latest save as the reference. This results into diff showing
--- difference after the latest save.
---
---@return table Source. See |MiniDiff-source-specification|.
MiniDiff.gen_source.save = function()
  local augroups = {}
  local attach = function(buf_id)
    local augroup = vim.api.nvim_create_augroup('MiniDiffSourceSaveBuffer' .. buf_id, { clear = true })
    augroups[buf_id] = augroup

    local set_ref = function()
      if vim.bo[buf_id].modified then return end
      MiniDiff.set_ref_text(buf_id, vim.api.nvim_buf_get_lines(buf_id, 0, -1, false))
    end

    -- Autocommand are more efficient than file watcher as it doesn't read disk
    local au_opts = { group = augroup, buffer = buf_id, callback = set_ref, desc = 'Set reference text after save' }
    vim.api.nvim_create_autocmd({ 'BufWritePost', 'FileChangedShellPost' }, au_opts)
    set_ref()
  end

  local detach = function(buf_id) pcall(vim.api.nvim_del_augroup_by_id, augroups[buf_id]) end

  return { name = 'save', attach = attach, detach = detach }
end

--- Perform action on hunks in region
---
--- Compute hunks inside a target region (even for hunks only partially inside it)
--- and perform apply/reset operation on them.
---
--- Notes:
--- - Whether hunk is inside a region is computed based on position of its
---   buffer lines.
--- - If "change" or "delete" is only partially inside a target region, all
---   reference lines are used in computed "intersection" hunk.
---
--- Used directly in `config.mappings.apply` and `config.mappings.reset`.
--- Usually there is no need to use this function manually.
---
---@param buf_id __diff_buf_id
---@param action string One of "apply" or "reset".
---@param opts table|nil Options. Possible fields:
---   - <line_start> `(number)` - start line of the region. Default: 1.
---   - <line_end> `(number)` - start line of the region. Default: last buffer line.
MiniDiff.do_hunks = function(buf_id, action, opts)
  buf_id = H.validate_buf_id(buf_id)
  local buf_cache = H.cache[buf_id]
  if buf_cache == nil then H.error(string.format('Buffer %d is not enabled.', buf_id)) end
  if type(buf_cache.ref_text) ~= 'string' then H.error(string.format('Buffer %d has no reference text.', buf_id)) end

  if not (action == 'apply' or action == 'reset') then H.error('`action` should be one of "apply", "reset".') end

  opts = vim.tbl_deep_extend('force', { line_start = 1, line_end = vim.api.nvim_buf_line_count(buf_id) }, opts or {})
  local line_start, line_end = H.validate_target_lines(buf_id, opts.line_start, opts.line_end)

  local hunks = H.get_hunks_in_range(buf_cache.hunks, line_start, line_end)
  if #hunks == 0 then return H.notify('No hunks to ' .. action, 'INFO') end
  local f = action == 'apply' and buf_cache.source.apply_hunks or H.reset_hunks
  f(buf_id, hunks)
end

--- Go to hunk range in current buffer
---
---@param direction string One of "first", "prev", "next", "last".
---@param opts table|nil Options. A table with fields:
---   - <n_times> `(number)` - Number of times to advance. Default: |v:count1|.
---   - <line_start> `(number)` - Line number to start from for directions
---     "prev" and "next". Default: cursor line.
---   - <wrap> `(boolean)` - Whether to wrap around edges.
---     Default: `options.wrap` value of the config.
MiniDiff.goto_hunk = function(direction, opts)
  local buf_id = vim.api.nvim_get_current_buf()
  local buf_cache = H.cache[buf_id]
  if buf_cache == nil then H.error(string.format('Buffer %d is not enabled.', buf_id)) end

  if not vim.tbl_contains({ 'first', 'prev', 'next', 'last' }, direction) then
    H.error('`direction` should be one of "first", "prev", "next", "last".')
  end

  local default_wrap = buf_cache.config.options.wrap_goto
  local default_opts = { n_times = vim.v.count1, line_start = vim.fn.line('.'), wrap = default_wrap }
  opts = vim.tbl_deep_extend('force', default_opts, opts or {})
  if not (type(opts.n_times) == 'number' and opts.n_times >= 1) then
    H.error('`opts.n_times` should be positive number.')
  end
  if type(opts.line_start) ~= 'number' then H.error('`opts.line_start` should be number.') end
  if type(opts.wrap) ~= 'boolean' then H.error('`opts.wrap` should be boolean.') end

  -- Prepare ranges to iterate.
  local ranges = H.get_contiguous_hunk_ranges(buf_cache.hunks)
  if #ranges == 0 then return H.notify('No hunks to go to', 'INFO') end

  -- Iterate
  local res_ind, did_wrap = H.iterate_hunk_ranges(ranges, direction, opts)
  if res_ind == nil then return H.notify('No hunk ranges in direction ' .. vim.inspect(direction), 'INFO') end
  local res_line = ranges[res_ind].from
  if did_wrap then H.notify('Wrapped around edge in direction ' .. vim.inspect(direction), 'INFO') end

  -- Add to jumplist
  vim.cmd([[normal! m']])

  -- Jump
  local _, col = vim.fn.getline(res_line):find('^%s*')
  vim.api.nvim_win_set_cursor(0, { res_line, col })

  -- Open just enough folds
  vim.cmd('normal! zv')
end

--- Perform action over region
---
--- Perform action over region defined by marks. Used in mappings.
---
---@param mode string One of "apply", "reset", or the ones used in |g@|.
MiniDiff.operator = function(mode)
  local buf_id = vim.api.nvim_get_current_buf()
  if H.is_disabled(buf_id) then return '' end

  if mode == 'apply' or mode == 'reset' then
    H.operator_cache = { action = mode, win_view = vim.fn.winsaveview() }
    vim.o.operatorfunc = 'v:lua.MiniDiff.operator'
    return 'g@'
  end

  -- NOTE: Using `[` / `]` marks also works in Visual mode as because it is
  -- executed as part of `g@`, which treats visual selection as a result of
  -- Operator-pending mode mechanics (for which visual selection is allowed to
  -- define motion/textobject). The downside is that it sets 'operatorfunc',
  -- but the upside is that it is "dot-repeatable" (for relative selection).
  local opts = { line_start = vim.fn.line("'["), line_end = vim.fn.line("']") }
  if opts.line_end < opts.line_start then return H.notify('Not a proper textobject', 'INFO') end
  MiniDiff.do_hunks(buf_id, H.operator_cache.action, opts)

  -- Restore window view for "apply" (as buffer text should not have changed)
  if H.operator_cache.action == 'apply' and H.operator_cache.win_view ~= nil then
    vim.fn.winrestview(H.operator_cache.win_view)
    -- NOTE: Restore only once because during dot-repeat it is not up to date
    H.operator_cache.win_view = nil
  end
  return ''
end

--- Select hunk range textobject
---
--- Selects all contiguous lines adjacent to cursor line which are in any (not
--- necessarily same) hunk (if cursor line itself is in hunk).
--- Used in default mappings.
MiniDiff.textobject = function()
  local buf_id = vim.api.nvim_get_current_buf()
  local buf_cache = H.cache[buf_id]
  if buf_cache == nil or H.is_disabled(buf_id) then H.error('Current buffer is not enabled.') end

  -- Get hunk range under cursor
  local cur_line = vim.fn.line('.')
  local regions, cur_region = H.get_contiguous_hunk_ranges(buf_cache.hunks), nil
  for _, r in ipairs(regions) do
    if r.from <= cur_line and cur_line <= r.to then cur_region = r end
  end
  if cur_region == nil then return H.notify('No hunk range under cursor', 'INFO') end

  -- Select target region
  local is_visual = vim.tbl_contains({ 'v', 'V', '\22' }, vim.fn.mode())
  if is_visual then vim.cmd('normal! \27') end
  vim.cmd(string.format('normal! %dGV%dG', cur_region.from, cur_region.to))
end

-- Helper data ================================================================
-- Module default config
H.default_config = MiniDiff.config

H.default_source = MiniDiff.gen_source.git()

-- Timers
H.timer_diff_update = vim.loop.new_timer()

-- Namespaces per highlighter name
H.ns_id = {
  viz = vim.api.nvim_create_namespace('MiniDiffViz'),
  overlay = vim.api.nvim_create_namespace('MiniDiffOverlay'),
}

-- Cache of buffers waiting for debounced diff update
H.bufs_to_update = {}

-- Cache per enabled buffer
H.cache = {}

-- Cache per buffer for attached `git` source
H.git_cache = {}

-- Cache for operator
H.operator_cache = {}

-- Common extmark data for supported styles
--stylua: ignore
H.style_extmark_data = {
  sign    = { hl_group_prefix = 'MiniDiffSign', field = 'sign_hl_group' },
  number  = { hl_group_prefix = 'MiniDiffSign', field = 'number_hl_group' },
}

-- Suffix for overlay virtual lines to be highlighted as full line
H.overlay_suffix = string.rep(' ', vim.o.columns)

-- Flag of whether Neovim version supports invalidating extmarks
H.extmark_supports_invalidate = vim.fn.has('nvim-0.10') == 1

-- Permanent `vim.diff()` options
H.vimdiff_opts = { result_type = 'indices', ctxlen = 0, interhunkctxlen = 0 }
H.vimdiff_supports_linematch = vim.fn.has('nvim-0.9') == 1

-- Options for `vim.diff()` during word diff. Use `interhunkctxlen = 4` to
-- reduce noisiness (chosen as slightly less than average English word length)
--stylua: ignore
H.worddiff_opts = { algorithm = 'minimal', result_type = 'indices', ctxlen = 0, interhunkctxlen = 4, indent_heuristic = false }
if H.vimdiff_supports_linematch then H.worddiff_opts.linematch = 0 end

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({
    view = { config.view, 'table' },
    source = { config.source, 'table', true },
    delay = { config.delay, 'table' },
    mappings = { config.mappings, 'table' },
    options = { config.options, 'table' },
  })

  vim.validate({
    ['view.style'] = { config.view.style, 'string' },
    ['view.signs'] = { config.view.signs, 'table' },
    ['view.priority'] = { config.view.priority, 'number' },

    ['delay.text_change'] = { config.delay.text_change, 'number' },

    ['mappings.apply'] = { config.mappings.apply, 'string' },
    ['mappings.reset'] = { config.mappings.reset, 'string' },
    ['mappings.textobject'] = { config.mappings.textobject, 'string' },
    ['mappings.goto_first'] = { config.mappings.goto_first, 'string' },
    ['mappings.goto_prev'] = { config.mappings.goto_prev, 'string' },
    ['mappings.goto_next'] = { config.mappings.goto_next, 'string' },
    ['mappings.goto_last'] = { config.mappings.goto_last, 'string' },

    ['options.algorithm'] = { config.options.algorithm, 'string' },
    ['options.indent_heuristic'] = { config.options.indent_heuristic, 'boolean' },
    ['options.linematch'] = { config.options.linematch, 'number' },
    ['options.wrap_goto'] = { config.options.wrap_goto, 'boolean' },
  })

  vim.validate({
    ['view.signs.add'] = { config.view.signs.add, 'string' },
    ['view.signs.change'] = { config.view.signs.change, 'string' },
    ['view.signs.delete'] = { config.view.signs.delete, 'string' },
  })

  return config
end

H.apply_config = function(config)
  MiniDiff.config = config

  -- Make mappings
  local mappings = config.mappings

  local rhs_apply = function() return MiniDiff.operator('apply') end
  H.map({ 'n', 'x' }, mappings.apply, rhs_apply, { expr = true, desc = 'Apply hunks' })
  local rhs_reset = function() return MiniDiff.operator('reset') end
  H.map({ 'n', 'x' }, mappings.reset, rhs_reset, { expr = true, desc = 'Reset hunks' })

  H.map('o', mappings.textobject, '<Cmd>lua MiniDiff.textobject()<CR>', { desc = 'Hunk range textobject' })

  --stylua: ignore start
  H.map({ 'n', 'x' }, mappings.goto_first,  "<Cmd>lua MiniDiff.goto_hunk('first')<CR>", { desc = 'First hunk' })
  H.map('o',          mappings.goto_first, "V<Cmd>lua MiniDiff.goto_hunk('first')<CR>", { desc = 'First hunk' })
  H.map({ 'n', 'x' }, mappings.goto_prev,   "<Cmd>lua MiniDiff.goto_hunk('prev')<CR>",  { desc = 'Previous hunk' })
  H.map('o',          mappings.goto_prev,  "V<Cmd>lua MiniDiff.goto_hunk('prev')<CR>",  { desc = 'Previous hunk' })
  H.map({ 'n', 'x' }, mappings.goto_next,   "<Cmd>lua MiniDiff.goto_hunk('next')<CR>",  { desc = 'Next hunk' })
  H.map('o',          mappings.goto_next,  "V<Cmd>lua MiniDiff.goto_hunk('next')<CR>",  { desc = 'Next hunk' })
  H.map({ 'n', 'x' }, mappings.goto_last,   "<Cmd>lua MiniDiff.goto_hunk('last')<CR>",  { desc = 'Last hunk' })
  H.map('o',          mappings.goto_last,  "V<Cmd>lua MiniDiff.goto_hunk('last')<CR>",  { desc = 'Last hunk' })
  --stylua: ignore end

  -- Register decoration provider which actually makes visualization
  local ns_id_viz, ns_id_overlay = H.ns_id.viz, H.ns_id.overlay
  H.set_decoration_provider(ns_id_viz, ns_id_overlay)
end

H.create_autocommands = function()
  local augroup = vim.api.nvim_create_augroup('MiniDiff', {})

  local au = function(event, pattern, callback, desc)
    vim.api.nvim_create_autocmd(event, { group = augroup, pattern = pattern, callback = callback, desc = desc })
  end

  -- NOTE: Try auto enabling buffer on every `BufEnter` to not have `:edit`
  -- disabling buffer, as it calls `on_detach()` from buffer watcher
  au('BufEnter', '*', H.auto_enable, 'Enable diff')
  au('VimResized', '*', H.on_resize, 'Track Neovim resizing')
end

--stylua: ignore
H.create_default_hl = function()
  local hi = function(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end

  local has_core_diff_hl = vim.fn.has('nvim-0.10') == 1
  hi('MiniDiffSignAdd',     { link = has_core_diff_hl and 'Added' or 'diffAdded' })
  hi('MiniDiffSignChange',  { link = has_core_diff_hl and 'Changed' or 'diffChanged' })
  hi('MiniDiffSignDelete',  { link = has_core_diff_hl and 'Removed' or 'diffRemoved'  })
  hi('MiniDiffOverAdd',     { link = 'DiffAdd' })
  hi('MiniDiffOverChange',  { link = 'DiffText' })
  hi('MiniDiffOverContext', { link = 'DiffChange' })
  hi('MiniDiffOverDelete',  { link = 'DiffDelete'  })
end

H.is_disabled = function(buf_id)
  local buf_disable = H.get_buf_var(buf_id, 'minidiff_disable')
  return vim.g.minidiff_disable == true or buf_disable == true
end

H.get_config = function(config, buf_id)
  local buf_config = H.get_buf_var(buf_id, 'minidiff_config') or {}
  return vim.tbl_deep_extend('force', MiniDiff.config, buf_config, config or {})
end

H.get_buf_var = function(buf_id, name)
  if not vim.api.nvim_buf_is_valid(buf_id) then return nil end
  return vim.b[buf_id or 0][name]
end

-- Autocommands ---------------------------------------------------------------
H.auto_enable = vim.schedule_wrap(function(data)
  if H.is_buf_enabled(data.buf) or H.is_disabled(data.buf) then return end
  if not vim.api.nvim_buf_is_valid(data.buf) or vim.bo[data.buf].buftype ~= '' then return end
  if not H.is_buf_text(data.buf) then return end
  MiniDiff.enable(data.buf)
end)

H.on_resize = function()
  H.overlay_suffix = string.rep(' ', vim.o.columns)
  for buf_id, _ in pairs(H.cache) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      H.clear_all_diff(buf_id)
      H.schedule_diff_update(buf_id, 0)
    end
  end
end

-- Validators -----------------------------------------------------------------
H.validate_buf_id = function(x)
  if x == nil or x == 0 then return vim.api.nvim_get_current_buf() end
  if not (type(x) == 'number' and vim.api.nvim_buf_is_valid(x)) then
    H.error('`buf_id` should be `nil` or valid buffer id.')
  end
  return x
end

H.validate_target_lines = function(buf_id, line_start, line_end)
  local n_lines = vim.api.nvim_buf_line_count(buf_id)

  if type(line_start) ~= 'number' then H.error('`line_start` should be number.') end
  if type(line_end) ~= 'number' then H.error('`line_end` should be number.') end

  -- Allow negative lines to count from last line
  line_start = line_start < 0 and (n_lines + line_start + 1) or line_start
  line_end = line_end < 0 and (n_lines + line_end + 1) or line_end

  -- Clamp to fit the allowed range
  line_start = math.min(math.max(line_start, 1), n_lines)
  line_end = math.min(math.max(line_end, 1), n_lines)
  if not (line_start <= line_end) then H.error('`line_start` should be less than or equal to `line_end`.') end

  return line_start, line_end
end

H.validate_callable = function(x, name)
  if vim.is_callable(x) then return x end
  H.error('`' .. name .. '` should be callable.')
end

-- Enabling -------------------------------------------------------------------
H.is_buf_enabled = function(buf_id) return H.cache[buf_id] ~= nil end

H.update_buf_cache = function(buf_id)
  local new_cache = H.cache[buf_id] or {}

  local buf_config = H.get_config({}, buf_id)
  new_cache.config = buf_config
  new_cache.extmark_opts = H.convert_view_to_extmark_opts(buf_config.view)
  new_cache.source = H.normalize_source(buf_config.source or H.default_source)

  new_cache.hunks = new_cache.hunks or {}
  new_cache.summary = new_cache.summary or {}
  new_cache.viz_lines = new_cache.viz_lines or {}

  new_cache.overlay = false
  new_cache.overlay_lines = new_cache.overlay_lines or {}

  H.cache[buf_id] = new_cache
end

H.setup_buf_autocommands = function(buf_id)
  local augroup = vim.api.nvim_create_augroup('MiniDiffBuffer' .. buf_id, { clear = true })
  H.cache[buf_id].augroup = augroup

  local buf_update = vim.schedule_wrap(function() H.update_buf_cache(buf_id) end)
  local bufwinenter_opts = { group = augroup, buffer = buf_id, callback = buf_update, desc = 'Update buffer cache' }
  vim.api.nvim_create_autocmd('BufWinEnter', bufwinenter_opts)

  local reset_if_enabled = vim.schedule_wrap(function(data)
    if not H.is_buf_enabled(data.buf) then return end
    MiniDiff.disable(data.buf)
    MiniDiff.enable(data.buf)
  end)
  local bufrename_opts = { group = augroup, buffer = buf_id, callback = reset_if_enabled, desc = 'Reset on rename' }
  -- NOTE: `BufFilePost` does not look like a proper event, but it (yet) works
  vim.api.nvim_create_autocmd('BufFilePost', bufrename_opts)

  local buf_disable = function() MiniDiff.disable(buf_id) end
  local bufdelete_opts = { group = augroup, buffer = buf_id, callback = buf_disable, desc = 'Disable on delete' }
  vim.api.nvim_create_autocmd('BufDelete', bufdelete_opts)
end

H.normalize_source = function(source)
  if type(source) ~= 'table' then H.error('`source` should be table.') end

  local res = { attach = source.attach }
  res.name = source.name or 'unknown'
  res.detach = source.detach or function(_) end
  res.apply_hunks = source.apply_hunks or function(_) H.error('Current source does not support applying hunks.') end

  if type(res.name) ~= 'string' then H.error('`source.name` should be string.') end
  H.validate_callable(res.attach, 'source.attach')
  H.validate_callable(res.detach, 'source.detach')
  H.validate_callable(res.apply_hunks, 'source.apply_hunks')

  return res
end

H.convert_view_to_extmark_opts = function(view)
  local extmark_data = H.style_extmark_data[view.style]
  if extmark_data == nil then H.error('Style ' .. vim.inspect(view.style) .. ' is not supported.') end

  local signs = view.style == 'sign' and view.signs or {}
  local field, hl_group_prefix = extmark_data.field, extmark_data.hl_group_prefix
  local invalidate
  if H.extmark_supports_invalidate then invalidate = true end
  --stylua: ignore
  return {
    add =    { [field] = hl_group_prefix .. 'Add',    sign_text = signs.add,    priority = view.priority, invalidate = invalidate },
    change = { [field] = hl_group_prefix .. 'Change', sign_text = signs.change, priority = view.priority, invalidate = invalidate },
    delete = { [field] = hl_group_prefix .. 'Delete', sign_text = signs.delete, priority = view.priority, invalidate = invalidate },
  }
end

-- Processing -----------------------------------------------------------------
H.set_decoration_provider = function(ns_id_viz, ns_id_overlay)
  local on_win = function(_, _, buf_id, top, bottom)
    local buf_cache = H.cache[buf_id]
    if buf_cache == nil then return false end

    if buf_cache.needs_clear then
      H.clear_all_diff(buf_id)
      buf_cache.needs_clear = false
    end

    local viz_lines, overlay_lines = buf_cache.viz_lines, buf_cache.overlay_lines
    for i = top + 1, bottom + 1 do
      if viz_lines[i] ~= nil then
        H.set_extmark(buf_id, ns_id_viz, i - 1, 0, viz_lines[i])
        viz_lines[i] = nil
      end
      if overlay_lines[i] ~= nil then
        -- Allow several overlays at one line (like for "delete" and "change")
        for j = 1, #overlay_lines[i] do
          H.draw_overlay_line(buf_id, ns_id_overlay, i - 1, overlay_lines[i][j])
        end
        overlay_lines[i] = nil
      end
    end
  end
  vim.api.nvim_set_decoration_provider(ns_id_viz, { on_win = on_win })
end

H.schedule_diff_update = vim.schedule_wrap(function(buf_id, delay_ms)
  H.bufs_to_update[buf_id] = true
  H.timer_diff_update:stop()
  H.timer_diff_update:start(delay_ms, 0, H.process_scheduled_buffers)
end)

H.process_scheduled_buffers = vim.schedule_wrap(function()
  for buf_id, _ in pairs(H.bufs_to_update) do
    H.update_buf_diff(buf_id)
  end
  H.bufs_to_update = {}
end)

H.update_buf_diff = vim.schedule_wrap(function(buf_id)
  -- Make early returns
  local buf_cache = H.cache[buf_id]
  if buf_cache == nil then return end
  if not vim.api.nvim_buf_is_valid(buf_id) then
    H.cache[buf_id] = nil
    return
  end
  if type(buf_cache.ref_text) ~= 'string' or H.is_disabled(buf_id) then
    local summary = { source_name = buf_cache.source.name }
    buf_cache.hunks, buf_cache.viz_lines, buf_cache.overlay_lines, buf_cache.summary = {}, {}, {}, summary
    vim.b[buf_id].minidiff_summary, vim.b[buf_id].minidiff_summary_string = summary, ''
    return
  end

  -- Compute diff
  local options = buf_cache.config.options
  H.vimdiff_opts.algorithm = options.algorithm
  H.vimdiff_opts.indent_heuristic = options.indent_heuristic
  if H.vimdiff_supports_linematch then H.vimdiff_opts.linematch = options.linematch end

  -- - NOTE: Appending '\n' makes more intuitive diffs at end-of-file
  local buf_lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local buf_text = table.concat(buf_lines, '\n') .. '\n'
  local diff = vim.diff(buf_cache.ref_text, buf_text, H.vimdiff_opts)

  -- Recompute hunks with summary and draw information
  H.update_hunk_data(diff, buf_cache, buf_lines)

  -- Set buffer-local variables with summary for easier external usage
  local summary = buf_cache.summary
  vim.b[buf_id].minidiff_summary = summary

  local summary_string = {}
  if summary.n_ranges > 0 then table.insert(summary_string, '#' .. summary.n_ranges) end
  if summary.add > 0 then table.insert(summary_string, '+' .. summary.add) end
  if summary.change > 0 then table.insert(summary_string, '~' .. summary.change) end
  if summary.delete > 0 then table.insert(summary_string, '-' .. summary.delete) end
  vim.b[buf_id].minidiff_summary_string = table.concat(summary_string, ' ')

  -- Request highlighting clear to be done in decoration provider
  buf_cache.needs_clear = true

  -- Trigger event for users to possibly hook into
  vim.api.nvim_exec_autocmds('User', { pattern = 'MiniDiffUpdated' })

  -- Force redraw. NOTE: Using 'redraw' not always works (`<Cmd>update<CR>`
  -- from keymap with "save" source will not redraw) while 'redraw!' flickers.
  vim.api.nvim__buf_redraw_range(buf_id, 0, -1)

  -- Redraw statusline to have possible statusline component up to date
  vim.cmd('redrawstatus')
end)

H.update_hunk_data = function(diff, buf_cache, buf_lines)
  local do_overlay = buf_cache.overlay
  local ref_lines = do_overlay and vim.split(buf_cache.ref_text, '\n') or nil

  local extmark_opts, priority = buf_cache.extmark_opts, buf_cache.config.view.priority
  local hunks, viz_lines, overlay_lines = {}, {}, {}
  local n_add, n_change, n_delete = 0, 0, 0
  local n_ranges, last_range_to = 0, -math.huge
  for i, d in ipairs(diff) do
    -- Hunk
    local n_ref, n_buf = d[2], d[4]
    local hunk_type = n_ref == 0 and 'add' or (n_buf == 0 and 'delete' or 'change')
    local hunk = { type = hunk_type, ref_start = d[1], ref_count = n_ref, buf_start = d[3], buf_count = n_buf }
    hunks[i] = hunk

    -- Hunk summary
    local hunk_n_change = math.min(n_ref, n_buf)
    n_add = n_add + n_buf - hunk_n_change
    n_change = n_change + hunk_n_change
    n_delete = n_delete + n_ref - hunk_n_change

    -- Number of contiguous ranges.
    -- NOTE: this relies on `vim.diff()` output being sorted by `buf_start`.
    local range_from = math.max(d[3], 1)
    local range_to = range_from + math.max(n_buf, 1) - 1
    n_ranges = n_ranges + ((range_from <= last_range_to + 1) and 0 or 1)
    last_range_to = math.max(last_range_to, range_to)

    -- Register lines for draw. At least one line should visualize hunk.
    local viz_ext_opts = extmark_opts[hunk_type]
    for l_num = range_from, range_to do
      -- Prefer showing "change" hunk over other types
      if viz_lines[l_num] == nil or hunk_type == 'change' then viz_lines[l_num] = viz_ext_opts end
    end

    if do_overlay then
      if hunk_type == 'add' then H.append_overlay_add(overlay_lines, hunk, priority) end
      if hunk_type == 'change' then H.append_overlay_change(overlay_lines, hunk, ref_lines, buf_lines, priority) end
      if hunk_type == 'delete' then H.append_overlay_delete(overlay_lines, hunk, ref_lines, priority) end
    end
  end

  buf_cache.hunks, buf_cache.viz_lines, buf_cache.overlay_lines = hunks, viz_lines, overlay_lines
  buf_cache.summary = { add = n_add, change = n_change, delete = n_delete, n_ranges = n_ranges }
  buf_cache.summary.source_name = buf_cache.source.name
end

H.clear_all_diff = function(buf_id)
  H.clear_namespace(buf_id, H.ns_id.viz, 0, -1)
  H.clear_namespace(buf_id, H.ns_id.overlay, 0, -1)
end

-- Overlay --------------------------------------------------------------------
H.append_overlay = function(overlay_lines, l_num, data)
  local t = overlay_lines[l_num] or {}
  table.insert(t, data)
  overlay_lines[l_num] = t
end

H.append_overlay_add = function(overlay_lines, hunk, priority)
  local data = { type = 'add', to = hunk.buf_start + hunk.buf_count - 1, priority = priority }
  H.append_overlay(overlay_lines, hunk.buf_start, data)
end

H.append_overlay_change = function(overlay_lines, hunk, ref_lines, buf_lines, priority)
  -- For one-to-one change, show lines separately with word diff highlighted
  -- This is usually the case when `linematch` is on
  if hunk.buf_count == hunk.ref_count then
    for i = 0, hunk.ref_count - 1 do
      local ref_n, buf_n = hunk.ref_start + i, hunk.buf_start + i
      -- Defer actually computing word diff until in decoration provider as it
      -- will compute only for displayed lines
      local data =
        { type = 'change_worddiff', ref_line = ref_lines[ref_n], buf_line = buf_lines[buf_n], priority = priority }
      H.append_overlay(overlay_lines, buf_n, data)
    end
    return
  end

  -- If not one-to-one change, show reference lines above first real one
  local changed_lines = {}
  for i = hunk.ref_start, hunk.ref_start + hunk.ref_count - 1 do
    local l = { { ref_lines[i], 'MiniDiffOverChange' }, { H.overlay_suffix, 'MiniDiffOverChange' } }
    table.insert(changed_lines, l)
  end
  H.append_overlay(overlay_lines, hunk.buf_start, { type = 'change', lines = changed_lines, priority = priority })
end

H.append_overlay_delete = function(overlay_lines, hunk, ref_lines, priority)
  local deleted_lines = {}
  for i = hunk.ref_start, hunk.ref_start + hunk.ref_count - 1 do
    table.insert(deleted_lines, { { ref_lines[i], 'MiniDiffOverDelete' }, { H.overlay_suffix, 'MiniDiffOverDelete' } })
  end
  local l_num, show_above = math.max(hunk.buf_start, 1), hunk.buf_start == 0
  local data = { type = 'delete', lines = deleted_lines, show_above = show_above, priority = priority }
  H.append_overlay(overlay_lines, l_num, data)
end

H.draw_overlay_line = function(buf_id, ns_id, row, data)
  -- "Add" hunk: highlight whole buffer range
  if data.type == 'add' then
    local opts =
      { end_row = data.to, end_col = 0, hl_group = 'MiniDiffOverAdd', hl_eol = true, priority = data.priority }
    return H.set_extmark(buf_id, ns_id, row, 0, opts)
  end

  -- "Change" hunk: show changed lines above first hunk line
  if data.type == 'change' then
    -- NOTE: virtual lines above line 1 need manual scroll (with `<C-y>`)
    -- See https://github.com/neovim/neovim/issues/16166
    local opts = { virt_lines = data.lines, virt_lines_above = true, priority = data.priority }
    return H.set_extmark(buf_id, ns_id, row, 0, opts)
  end

  -- "Change worddif" hunk: compute word diff and show it above and over text
  if data.type == 'change_worddiff' then return H.draw_overlay_line_worddiff(buf_id, ns_id, row, data) end

  -- "Delete" hunk: show deleted lines below buffer line (if possible)
  if data.type == 'delete' then
    local opts = { virt_lines = data.lines, virt_lines_above = data.show_above, priority = data.priority }
    return H.set_extmark(buf_id, ns_id, row, 0, opts)
  end
end

H.draw_overlay_line_worddiff = function(buf_id, ns_id, row, data)
  local ref_line, buf_line = data.ref_line, data.buf_line
  local ref_parts, buf_parts = H.compute_worddiff_changed_parts(ref_line, buf_line)

  -- Show changed parts in reference line as virtual line above
  local virt_line, index = {}, 1
  for i = 1, #ref_parts do
    local part = ref_parts[i]
    if index < part[1] then table.insert(virt_line, { ref_line:sub(index, part[1] - 1), 'MiniDiffOverContext' }) end
    table.insert(virt_line, { ref_line:sub(part[1], part[2]), 'MiniDiffOverChange' })
    index = part[2] + 1
  end
  if index <= ref_line:len() then table.insert(virt_line, { ref_line:sub(index), 'MiniDiffOverContext' }) end
  table.insert(virt_line, { H.overlay_suffix, 'MiniDiffOverContext' })

  local ref_opts = { virt_lines = { virt_line }, virt_lines_above = true, priority = data.priority }
  H.set_extmark(buf_id, ns_id, row, 0, ref_opts)

  -- Show changed parts in current line with separate extmarks
  for i = 1, #buf_parts do
    local part = buf_parts[i]
    local buf_opts = { end_row = row, end_col = part[2], hl_group = 'MiniDiffOverChange', priority = data.priority }
    H.set_extmark(buf_id, ns_id, row, part[1] - 1, buf_opts)
  end
end

H.compute_worddiff_changed_parts = function(ref_line, buf_line)
  local ref_sliced, ref_byte_starts, ref_byte_ends = H.slice_line(ref_line)
  local buf_sliced, buf_byte_starts, buf_byte_ends = H.slice_line(buf_line)
  local diff = vim.diff(ref_sliced, buf_sliced, H.worddiff_opts)
  local ref_ranges, buf_ranges = {}, {}
  for i = 1, #diff do
    local d = diff[i]
    if d[2] > 0 then table.insert(ref_ranges, { ref_byte_starts[d[1]], ref_byte_ends[d[1] + d[2] - 1] }) end
    if d[4] > 0 then table.insert(buf_ranges, { buf_byte_starts[d[3]], buf_byte_ends[d[3] + d[4] - 1] }) end
  end

  return ref_ranges, buf_ranges
end

H.slice_line = function(line)
  -- Intertwine every proper character with '\n'
  local line_len = line:len()
  local sliced, starts, ends
  -- Make short route for a very common case of no multibyte characters
  if vim.str_utfindex(line) == line_len then
    sliced, starts, ends = line:gsub('(.)', '%1\n'), {}, {}
    for i = 1, string.len(line) do
      starts[i], ends[i] = i, i
    end
  else
    sliced, starts, ends = {}, vim.str_utf_pos(line), {}
    for i = 1, #starts - 1 do
      table.insert(sliced, line:sub(starts[i], starts[i + 1] - 1))
      table.insert(ends, starts[i + 1] - 1)
    end
    table.insert(sliced, line:sub(starts[#starts], line_len))
    table.insert(ends, line_len)
    sliced = table.concat(sliced, '\n') .. '\n'
  end

  return sliced, starts, ends
end

-- Hunks ----------------------------------------------------------------------
H.get_hunk_buf_range = function(hunk)
  -- "Change" and "Add" hunks have the range `[from, from + buf_count - 1]`
  if hunk.buf_count > 0 then return hunk.buf_start, hunk.buf_start + hunk.buf_count - 1 end
  -- "Delete" hunks have `buf_count = 0` yet its range is `[from, from]`
  -- `buf_start` can be 0 for 'delete' hunk, yet range should be real lines
  local from = math.max(hunk.buf_start, 1)
  return from, from
end

H.get_hunks_in_range = function(hunks, from, to)
  local res = {}
  for _, h in ipairs(hunks) do
    local h_from, h_to = H.get_hunk_buf_range(h)

    local left, right = math.max(from, h_from), math.min(to, h_to)
    if left <= right then
      -- If any `cur` hunk part is selected, its `ref` part is used fully
      local new_h = { ref_start = h.ref_start, ref_count = h.ref_count }
      new_h.type = h.ref_count == 0 and 'add' or (h.buf_count == 0 and 'delete' or 'change')

      -- It should be possible to work with only hunk part inside target range
      -- Also Treat "delete" hunks differently as they represent range differently
      -- and can have `buf_start=0`
      new_h.buf_start = new_h.type == 'delete' and h.buf_start or left
      new_h.buf_count = new_h.type == 'delete' and 0 or (right - left + 1)

      table.insert(res, new_h)
    end
  end

  table.sort(res, H.hunk_order)
  return res
end

H.reset_hunks = function(buf_id, hunks)
  local ref_lines = vim.split(H.cache[buf_id].ref_text, '\n')
  local offset = 0
  for _, h in ipairs(hunks) do
    -- Replace current hunk lines with corresponding reference
    local new_lines = vim.list_slice(ref_lines, h.ref_start, h.ref_start + h.ref_count - 1)

    -- Compute buffer offset from parts: result of previous replaces, "delete"
    -- hunk offset which starts below the `buf_start` line, zero-indexing.
    local buf_offset = offset + (h.buf_count == 0 and 1 or 0) - 1
    local from, to = h.buf_start + buf_offset, h.buf_start + h.buf_count + buf_offset
    vim.api.nvim_buf_set_lines(buf_id, from, to, false, new_lines)

    -- Keep track of current hunk lines shift as a result of previous replaces
    offset = offset + (h.ref_count - h.buf_count)
  end
end

H.get_contiguous_hunk_ranges = function(hunks)
  if #hunks == 0 then return {} end
  hunks = vim.deepcopy(hunks)
  table.sort(hunks, H.hunk_order)

  local h1_from, h1_to = H.get_hunk_buf_range(hunks[1])
  local res = { { from = h1_from, to = h1_to } }
  for i = 2, #hunks do
    local h, cur_region = hunks[i], res[#res]
    local h_from, h_to = H.get_hunk_buf_range(h)
    if h_from <= cur_region.to + 1 then
      cur_region.to = math.max(cur_region.to, h_to)
    else
      table.insert(res, { from = h_from, to = h_to })
    end
  end
  return res
end

H.iterate_hunk_ranges = function(ranges, direction, opts)
  local n = #ranges

  -- Compute initial index
  local init_ind
  if direction == 'first' then init_ind = 0 end
  if direction == 'prev' then init_ind = H.get_range_id_prev(ranges, opts.line_start) end
  if direction == 'next' then init_ind = H.get_range_id_next(ranges, opts.line_start) end
  if direction == 'last' then init_ind = n + 1 end

  local is_on_edge = (direction == 'prev' and init_ind == 1) or (direction == 'next' and init_ind == n)
  if not opts.wrap and is_on_edge then return nil end

  -- Compute destination index
  local is_move_forward = direction == 'first' or direction == 'next'
  local res_ind = init_ind + opts.n_times * (is_move_forward and 1 or -1)
  local did_wrap = opts.wrap and (res_ind < 1 or n < res_ind)
  res_ind = opts.wrap and ((res_ind - 1) % n + 1) or math.min(math.max(res_ind, 1), n)

  return res_ind, did_wrap
end

H.get_range_id_next = function(ranges, line_start)
  for i = #ranges, 1, -1 do
    if ranges[i].from <= line_start then return i end
  end
  return 0
end

H.get_range_id_prev = function(ranges, line_start)
  for i = 1, #ranges do
    if line_start <= ranges[i].to then return i end
  end
  return #ranges + 1
end

H.hunk_order = function(a, b)
  -- Ensure buffer order and that "change" hunks are listed earlier "delete"
  -- ones from the same line (important for `reset_hunks()`)
  return a.buf_start < b.buf_start or (a.buf_start == b.buf_start and a.type == 'change')
end

-- Export ---------------------------------------------------------------------
H.export_qf = function(opts)
  local buffers = opts.scope == 'current' and { vim.api.nvim_get_current_buf() } or vim.tbl_keys(H.cache)
  buffers = vim.tbl_filter(vim.api.nvim_buf_is_valid, buffers)
  table.sort(buffers)

  local res = {}
  for _, buf_id in ipairs(buffers) do
    local filename = vim.api.nvim_buf_get_name(buf_id)
    for _, h in ipairs(H.cache[buf_id].hunks) do
      local entry = { bufnr = buf_id, filename = filename, type = h.type:sub(1, 1):upper() }
      entry.lnum, entry.end_lnum = H.get_hunk_buf_range(h)
      table.insert(res, entry)
    end
  end
  return res
end

-- Git ------------------------------------------------------------------------
H.git_start_watching_index = function(buf_id, path)
  -- NOTE: Watching single 'index' file is not enough as staging by Git is done
  -- via "create fresh 'index.lock' file, apply modifications, change file name
  -- to 'index'". Hence watch the whole '.git' (first level) and react only if
  -- change was in 'index' file.
  local stdout = vim.loop.new_pipe()
  local args = { 'rev-parse', '--path-format=absolute', '--git-dir' }
  local spawn_opts = { args = args, cwd = vim.fn.fnamemodify(path, ':h'), stdio = { nil, stdout, nil } }

  -- If path is not in Git, disable buffer but make sure that it will not try
  -- to re-attach until buffer is properly disabled
  local on_not_in_git = vim.schedule_wrap(function()
    MiniDiff.disable(buf_id)
    H.git_cache[buf_id] = {}
  end)

  local process, stdout_feed = nil, {}
  local on_exit = function(exit_code)
    process:close()

    -- Watch index only if there was no error retrieving path to it
    if exit_code ~= 0 or stdout_feed[1] == nil then return on_not_in_git() end

    -- Set up index watching
    local git_dir_path = table.concat(stdout_feed, ''):gsub('\n+$', '')
    H.git_setup_index_watch(buf_id, git_dir_path)

    -- Set reference text immediately
    H.git_set_ref_text(buf_id)
  end

  process = vim.loop.spawn('git', spawn_opts, on_exit)
  H.git_read_stream(stdout, stdout_feed)
end

H.git_setup_index_watch = function(buf_id, git_dir_path)
  local buf_fs_event, timer = vim.loop.new_fs_event(), vim.loop.new_timer()
  local buf_git_set_ref_text = function() H.git_set_ref_text(buf_id) end

  local watch_index = function(_, filename, _)
    if filename ~= 'index' then return end
    -- Debounce to not overload during incremental staging (like in script)
    timer:stop()
    timer:start(50, 0, buf_git_set_ref_text)
  end
  buf_fs_event:start(git_dir_path, { recursive = false }, watch_index)

  H.git_invalidate_cache(H.git_cache[buf_id])
  H.git_cache[buf_id] = { fs_event = buf_fs_event, timer = timer }
end

H.git_set_ref_text = vim.schedule_wrap(function(buf_id)
  local buf_set_ref_text = vim.schedule_wrap(function(text) pcall(MiniDiff.set_ref_text, buf_id, text) end)

  -- NOTE: Do not cache buffer's name to react to its possible rename
  local path = vim.api.nvim_buf_get_name(buf_id)
  if path == '' then return buf_set_ref_text({}) end
  local cwd, basename = vim.fn.fnamemodify(path, ':h'), vim.fn.fnamemodify(path, ':t')

  -- Set
  local stdout = vim.loop.new_pipe()
  local spawn_opts = { args = { 'show', ':0:./' .. basename }, cwd = cwd, stdio = { nil, stdout, nil } }

  local process, stdout_feed = nil, {}
  local on_exit = function(exit_code)
    process:close()

    -- Unset reference text in case of any error. This results into not showing
    -- hunks at all. Possible reasons to do so:
    -- - 'Not in index' files (new, ignored, etc.).
    -- - 'Neither in index nor on disk' files (after checking out commit which
    --   does not yet have file created).
    -- - 'Relative can not be used outside working tree' (when opening file
    --   inside '.git' directory).
    if exit_code ~= 0 or stdout_feed[1] == nil then return buf_set_ref_text({}) end

    -- Set reference text
    local text = table.concat(stdout_feed, '')
    buf_set_ref_text(text)
  end

  process = vim.loop.spawn('git', spawn_opts, on_exit)
  H.git_read_stream(stdout, stdout_feed)
end)

H.git_get_path_data = function(path)
  -- Get path data needed for proper patch header
  local cwd, basename = vim.fn.fnamemodify(path, ':h'), vim.fn.fnamemodify(path, ':t')
  local stdout = vim.loop.new_pipe()
  local args = { 'ls-files', '--full-name', '--format=%(objectmode) %(path)', '--', basename }
  local spawn_opts = { args = args, cwd = cwd, stdio = { nil, stdout, nil } }

  local process, stdout_feed, res, did_exit = nil, {}, { cwd = cwd }, false
  local on_exit = function(exit_code)
    process:close()

    did_exit = true
    if exit_code ~= 0 then return end
    -- Parse data about path
    local out = table.concat(stdout_feed, ''):gsub('\n+$', '')
    res.mode_bits, res.rel_path = string.match(out, '^(%d+) (.*)$')
  end

  process = vim.loop.spawn('git', spawn_opts, on_exit)
  H.git_read_stream(stdout, stdout_feed)
  vim.wait(1000, function() return did_exit end, 1)
  return res
end

H.git_format_patch = function(buf_id, hunks, path_data)
  local buf_lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local ref_lines = vim.split(H.cache[buf_id].ref_text, '\n')

  local res = {
    string.format('diff --git a/%s b/%s', path_data.rel_path, path_data.rel_path),
    'index 000000..000000 ' .. path_data.mode_bits,
    '--- a/' .. path_data.rel_path,
    '+++ b/' .. path_data.rel_path,
  }

  -- Take into account changing target ref region as a result of previous hunks
  local offset = 0
  for _, h in ipairs(hunks) do
    -- "Add" hunks have reference line above target
    local start = h.ref_start + (h.ref_count == 0 and 1 or 0)

    table.insert(res, string.format('@@ -%d,%d +%d,%d @@', start, h.ref_count, start + offset, h.buf_count))
    for i = h.ref_start, h.ref_start + h.ref_count - 1 do
      table.insert(res, '-' .. ref_lines[i])
    end
    for i = h.buf_start, h.buf_start + h.buf_count - 1 do
      table.insert(res, '+' .. buf_lines[i])
    end
    offset = offset + (h.buf_count - h.ref_count)
  end

  return res
end

H.git_apply_patch = function(path_data, patch)
  local stdin = vim.loop.new_pipe()
  local args = { 'apply', '--whitespace=nowarn', '--cached', '--unidiff-zero', '-' }
  local spawn_opts = { args = args, cwd = path_data.cwd, stdio = { stdin, nil, nil } }
  local process
  process = vim.loop.spawn('git', spawn_opts, function() process:close() end)

  -- Write patch, notify that writing is finished (shutdown), and close
  for _, l in ipairs(patch) do
    stdin:write(l)
    stdin:write('\n')
  end
  stdin:shutdown(function() stdin:close() end)
end

H.git_read_stream = function(stream, feed)
  local callback = function(err, data)
    if data ~= nil then return table.insert(feed, data) end
    if err then feed[1] = nil end
    stream:close()
  end
  stream:read_start(callback)
end

H.git_invalidate_cache = function(cache)
  if cache == nil then return end
  pcall(vim.loop.fs_event_stop, cache.fs_event)
  pcall(vim.loop.timer_stop, cache.timer)
end

-- Utilities ------------------------------------------------------------------
H.error = function(msg) error(string.format('(mini.diff) %s', msg), 0) end

H.notify = function(msg, level_name) vim.notify('(mini.diff) ' .. msg, vim.log.levels[level_name]) end

H.map = function(mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

H.set_extmark = function(...) pcall(vim.api.nvim_buf_set_extmark, ...) end

H.get_extmarks = function(...)
  local ok, res = pcall(vim.api.nvim_buf_get_extmarks, ...)
  if not ok then return {} end
  return res
end

H.clear_namespace = function(...) pcall(vim.api.nvim_buf_clear_namespace, ...) end

H.is_buf_text = function(buf_id)
  local n = vim.api.nvim_buf_call(buf_id, function() return vim.fn.byte2line(1024) end)
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, n, false)
  return table.concat(lines, ''):find('\0') == nil
end

return MiniDiff
