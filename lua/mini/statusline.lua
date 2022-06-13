-- MIT License Copyright (c) 2021 Evgeni Chasnovski

-- Documentation ==============================================================
--- Minimal and fast statusline module with opinionated default look.
--- Special features: change color depending on current mode and compact
--- version of sections activated when window width is small enough.
---
--- Features:
--- - Built-in active mode indicator with colors.
--- - Sections can hide information when window is too narrow (specific window
---   width is configurable per section).
--- - Define own custom statusline structure for active and inactive windows.
---   This is done with a function which should return string appropriate for
---   |statusline|. Its code should be similar to default one with structure:
---     - Compute string data for every section you want to be displayed.
---     - Combine them in groups with |MiniStatusline.combine_groups()|.
---
--- # Dependencies~
---
--- Suggested dependencies (provide extra functionality, statusline will work
--- without them):
--- - Nerd font (to support extra icons).
--- - Plugin 'lewis6991/gitsigns.nvim' for Git information in
---   |MiniStatusline.section_git|. If missing, no section will be shown.
--- - Plugin 'kyazdani42/nvim-web-devicons' for filetype icons in
---   `MiniStatusline.section_fileinfo`. If missing, no icons will be shown.
---
--- # Setup~
---
--- This module needs a setup with `require('mini.statusline').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniStatusline` which you can use for scripting or manually (with
--- `:lua MiniStatusline.*`).
---
--- See |MiniStatusline.config| for `config` structure and default values. For
--- some content examples, see |MiniStatusline-example-content|.
---
--- # Highlight groups~
---
--- Highlight depending on mode (second output from |MiniStatusline.section_mode|):
--- * `MiniStatuslineModeNormal` - Normal mode.
--- * `MiniStatuslineModeInsert` - Insert mode.
--- * `MiniStatuslineModeVisual` - Visual mode.
--- * `MiniStatuslineModeReplace` - Replace mode.
--- * `MiniStatuslineModeCommand` - Command mode.
--- * `MiniStatuslineModeOther` - other modes (like Terminal, etc.).
---
--- Highlight used in default statusline:
--- * `MiniStatuslineDevinfo` - for "dev info" group
---   (|MiniStatusline.section_git| and |MiniStatusline.section_diagnostics|).
--- * `MiniStatuslineFilename` - for |MiniStatusline.section_filename| section.
--- * `MiniStatuslineFileinfo` - for |MiniStatusline.section_fileinfo| section.
---
--- Other groups:
--- * `MiniStatuslineInactive` - highliting in not focused window.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling~
---
--- To disable (show empty statusline), set `g:ministatusline_disable`
--- (globally) or `b:ministatusline_disable` (for a buffer) to `v:true`.
--- Considering high number of different scenarios and customization
--- intentions, writing exact rules for disabling module's functionality is
--- left to user. See |mini.nvim-disabling-recipes| for common recipes.
---@tag mini.statusline
---@tag MiniStatusline
---@toc_entry Statusline

--- Example content
---
--- # Default content~
---
--- This function is used as default value for active content:
--- >
---   function()
---     local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
---     local git           = MiniStatusline.section_git({ trunc_width = 75 })
---     local diagnostics   = MiniStatusline.section_diagnostics({ trunc_width = 75 })
---     local filename      = MiniStatusline.section_filename({ trunc_width = 140 })
---     local fileinfo      = MiniStatusline.section_fileinfo({ trunc_width = 120 })
---     local location      = MiniStatusline.section_location({ trunc_width = 75 })
---
---     return MiniStatusline.combine_groups({
---       { hl = mode_hl,                  strings = { mode } },
---       { hl = 'MiniStatuslineDevinfo',  strings = { git, diagnostics } },
---       '%<', -- Mark general truncate point
---       { hl = 'MiniStatuslineFilename', strings = { filename } },
---       '%=', -- End left alignment
---       { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
---       { hl = mode_hl,                  strings = { location } },
---     })
---   end
--- <
--- # Show boolean options~
---
--- To compute section string for boolean option use variation of this code
--- snippet inside content function (you can modify option itself, truncation
--- width, short and long displayed names):
--- >
---   local spell = vim.wo.spell and (MiniStatusline.is_truncated(120) and 'S' or 'SPELL') or ''
--- <
--- Here `x and y or z` is a common Lua way of doing ternary operator: if `x`
--- is `true`-ish then return `y`, if not - return `z`.
---@tag MiniStatusline-example-content

---@alias __args table Section arguments.
---@alias __section string Section string.

-- Module definition ==========================================================
local MiniStatusline = {}
local H = {}

--- Module setup
---
---@param config table Module config table. See |MiniStatusline.config|.
---
---@usage `require('mini.statusline').setup({})` (replace `{}` with your `config` table)
function MiniStatusline.setup(config)
  -- Export module
  _G.MiniStatusline = MiniStatusline

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  vim.api.nvim_exec(
    [[augroup MiniStatusline
        au!
        au WinEnter,BufEnter * setlocal statusline=%!v:lua.MiniStatusline.active()
        au WinLeave,BufLeave * setlocal statusline=%!v:lua.MiniStatusline.inactive()
      augroup END]],
    false
  )

  -- Create highlighting
  vim.api.nvim_exec(
    [[hi default link MiniStatuslineModeNormal  Cursor
      hi default link MiniStatuslineModeInsert  DiffChange
      hi default link MiniStatuslineModeVisual  DiffAdd
      hi default link MiniStatuslineModeReplace DiffDelete
      hi default link MiniStatuslineModeCommand DiffText
      hi default link MiniStatuslineModeOther   IncSearch

      hi default link MiniStatuslineDevinfo  StatusLine
      hi default link MiniStatuslineFilename StatusLineNC
      hi default link MiniStatuslineFileinfo StatusLine
      hi default link MiniStatuslineInactive StatusLineNC]],
    false
  )
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniStatusline.config = {
  -- Content of statusline as functions which return statusline string. See
  -- `:h statusline` and code of default contents (used instead of `nil`).
  content = {
    -- Content for active window
    active = nil,
    -- Content for inactive window(s)
    inactive = nil,
  },
  -- Whether to use Nert Fonts.
  nerdfonts = true,
  -- Whether to set Vim's settings for statusline (make it always shown with
  -- 'laststatus' set to 2). To use global statusline in Neovim>=0.7.0, set
  -- this to `false` and 'laststatus' to 3.
  set_vim_settings = true,
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Compute content for active window
function MiniStatusline.active()
  if H.is_disabled() then
    return ''
  end

  return (MiniStatusline.config.content.active or H.default_content_active)()
end

--- Compute content for inactive window
function MiniStatusline.inactive()
  if H.is_disabled() then
    return ''
  end

  return (MiniStatusline.config.content.inactive or H.default_content_inactive)()
end

--- Combine groups of sections
---
--- Each group can be either a string or a table with fields `hl` (group's
--- highlight group) and `strings` (strings representing sections).
---
--- General idea of this function is as follows;
--- - String group is used as is (useful for special strings like `%<` or `%=`).
--- - Each table group has own highlighting in `hl` field (if missing, the
---   previous one is used) and string parts in `strings` field. Non-empty
---   strings from `strings` are separated by one space. Non-empty groups are
---   separated by two spaces (one for each highlighting).
---
---@param groups string|table Array of groups.
---
---@return string String suitable for 'statusline'.
function MiniStatusline.combine_groups(groups)
  local parts = vim.tbl_map(function(s)
    --stylua: ignore start
    if type(s) == 'string' then return s end
    if type(s) ~= 'table' then return '' end

    local string_arr = vim.tbl_filter(function(x) return type(x) == 'string' and x ~= '' end, s.strings or {})
    local str = table.concat(string_arr, ' ')

    -- Use previous highlight group
    if s.hl == nil then
      return (' %s '):format(str)
    end

    -- Allow using this highlight group later
    if str:len() == 0 then
      return string.format('%%#%s#', s.hl)
    end

    return string.format('%%#%s# %s ', s.hl, str)
    --stylua: ignore end
  end, groups)

  return table.concat(parts, '')
end

--- Decide whether to truncate
---
--- This basically computes window width and compares it to `trunc_width`: if
--- window is smaller then truncate; otherwise don't. Don't truncate by
--- default.
---
--- Use this to manually decide if section needs truncation or not.
---
---@param trunc_width number Truncation width. If `nil`, output is `false`.
---
---@return boolean Whether to truncate.
function MiniStatusline.is_truncated(trunc_width)
  -- Use -1 to default to 'not truncated'
  return vim.api.nvim_win_get_width(0) < (trunc_width or -1)
end

-- Sections ===================================================================
-- Functions should return output text without whitespace on sides.
-- Return empty string to omit section.

--- Section for Vim |mode()|
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args __args
---
---@return ... Section string and mode's highlight group.
function MiniStatusline.section_mode(args)
  local mode_info = H.modes[vim.fn.mode()]

  local mode = MiniStatusline.is_truncated(args.trunc_width) and mode_info.short or mode_info.long

  return mode, mode_info.hl
end

--- Section for Git information
---
--- Normal output contains name of `HEAD` (via |b:gitsigns_head|) and chunk
--- information (via |b:gitsigns_status|). Short output - only name of `HEAD`.
--- Note: requires 'lewis6991/gitsigns' plugin.
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args __args Use `args.icon` to supply your own icon.
---
---@return __section
function MiniStatusline.section_git(args)
  if H.isnt_normal_buffer() then
    return ''
  end

  local head = vim.b.gitsigns_head or '-'
  local signs = MiniStatusline.is_truncated(args.trunc_width) and '' or (vim.b.gitsigns_status or '')
  local icon = args.icon or (MiniStatusline.config.nerdfonts and '' or 'Git')

  if signs == '' then
    if head == '-' or head == '' then
      return ''
    end
    return string.format('%s %s', icon, head)
  end
  return string.format('%s %s %s', icon, head, signs)
end

--- Section for Neovim's builtin diagnostics
---
--- Shows nothing if there is no attached LSP clients or for short output.
--- Otherwise uses builtin Neovim capabilities to compute and show number of
--- errors ('E'), warnings ('W'), information ('I'), and hints ('H').
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args __args Use `args.icon` to supply your own icon.
---
---@return __section
function MiniStatusline.section_diagnostics(args)
  -- Assumption: there are no attached clients if table
  -- `vim.lsp.buf_get_clients()` is empty
  local hasnt_attached_client = next(vim.lsp.buf_get_clients()) == nil
  local dont_show_lsp = MiniStatusline.is_truncated(args.trunc_width) or H.isnt_normal_buffer() or hasnt_attached_client
  if dont_show_lsp then
    return ''
  end

  -- Construct diagnostic info using predefined order
  local t = {}
  for _, level in ipairs(H.diagnostic_levels) do
    local n = H.get_diagnostic_count(level.id)
    -- Add level info only if diagnostic is present
    if n > 0 then
      table.insert(t, string.format(' %s%s', level.sign, n))
    end
  end

  local icon = args.icon or (MiniStatusline.config.nerdfonts and '' or 'LSP')
  if vim.tbl_count(t) == 0 then
    return ('%s -'):format(icon)
  end
  return string.format('%s%s', icon, table.concat(t, ''))
end

--- Section for file name
---
--- Show full file name or relative in short output.
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args __args
---
---@return __section
function MiniStatusline.section_filename(args)
  -- In terminal always use plain name
  if vim.bo.buftype == 'terminal' then
    return '%t'
  elseif MiniStatusline.is_truncated(args.trunc_width) then
    -- File name with 'truncate', 'modified', 'readonly' flags
    -- Use relative path if truncated
    return '%f%m%r'
  else
    -- Use fullpath if not truncated
    return '%F%m%r'
  end
end

--- Section for file information
---
--- Short output contains only extension and is returned if window width is
--- lower than `args.trunc_width`.
---
---@param args __args
---
---@return __section
function MiniStatusline.section_fileinfo(args)
  local filetype = vim.bo.filetype

  -- Don't show anything if can't detect file type or not inside a "normal
  -- buffer"
  if (filetype == '') or H.isnt_normal_buffer() then
    return ''
  end

  -- Add filetype icon
  local icon = H.get_filetype_icon()
  if icon ~= '' then
    filetype = string.format('%s %s', icon, filetype)
  end

  -- Construct output string if truncated
  if MiniStatusline.is_truncated(args.trunc_width) then
    return filetype
  end

  -- Construct output string with extra file info
  local encoding = vim.bo.fileencoding or vim.bo.encoding
  local format = vim.bo.fileformat
  local size = H.get_filesize()

  return string.format('%s %s[%s] %s', filetype, encoding, format, size)
end

--- Section for location inside buffer
---
--- Show location inside buffer in the form:
--- - Normal: '<cursor line>|<total lines>│<cursor column>|<total columns>'.
--- - Short: '<cursor line>│<cursor column>'.
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args __args
---
---@return __section
function MiniStatusline.section_location(args)
  -- Use virtual column number to allow update when past last column
  if MiniStatusline.is_truncated(args.trunc_width) then
    return '%l│%2v'
  end

  -- Use `virtcol()` to correctly handle multi-byte characters
  return '%l|%L│%2v|%-2{virtcol("$") - 1}'
end

--- Section for current search count
---
--- Show the current status of |searchcount()|. Empty output is returned if
--- window width is lower than `args.trunc_width`, search highlighting is not
--- on (see |v:hlsearch|), or if number of search result is 0.
---
--- `args.options` is forwarded to |searchcount()|.  By default it recomputes
--- data on every call which can be computationally expensive (although still
--- usually same order of magnitude as 0.1 ms). To prevent this, supply
--- `args.options = {recompute = false}`.
---
---@param args __args
---
---@return __section
function MiniStatusline.section_searchcount(args)
  if vim.v.hlsearch == 0 or MiniStatusline.is_truncated(args.trunc_width) then
    return ''
  end
  -- `searchcount()` can return errors because it is evaluated very often in
  -- statusline. For example, when typing `/` followed by `\(`, it gives E54.
  local ok, s_count = pcall(vim.fn.searchcount, (args or {}).options or { recompute = true })
  if not ok or s_count.current == nil or s_count.total == 0 then
    return ''
  end

  if s_count.incomplete == 1 then
    return '?/?'
  end

  local too_many = ('>%d'):format(s_count.maxcount)
  local current = s_count.current > s_count.maxcount and too_many or s_count.current
  local total = s_count.total > s_count.maxcount and too_many or s_count.total
  return ('%s/%s'):format(current, total)
end

-- Helper data ================================================================
-- Module default config
H.default_config = MiniStatusline.config

-- Showed diagnostic levels
if vim.fn.has('nvim-0.6') == 1 then
  H.diagnostic_levels = {
    { id = vim.diagnostic.severity.ERROR, sign = 'E' },
    { id = vim.diagnostic.severity.WARN, sign = 'W' },
    { id = vim.diagnostic.severity.INFO, sign = 'I' },
    { id = vim.diagnostic.severity.HINT, sign = 'H' },
  }
else
  H.diagnostic_levels = {
    { id = 'Error', sign = 'E' },
    { id = 'Warning', sign = 'W' },
    { id = 'Information', sign = 'I' },
    { id = 'Hint', sign = 'H' },
  }
end

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  -- Validate per nesting level to produce correct error message
  vim.validate({
    content = { config.content, 'table' },
    set_vim_settings = { config.set_vim_settings, 'boolean' },
  })

  vim.validate({
    ['content.active'] = { config.content.active, 'function', true },
    ['content.inactive'] = { config.content.inactive, 'function', true },
  })

  return config
end

function H.apply_config(config)
  MiniStatusline.config = config

  -- Set settings to ensure statusline is displayed properly
  if config.set_vim_settings then
    vim.o.laststatus = 2 -- Always show statusline
  end
end

function H.is_disabled()
  return vim.g.ministatusline_disable == true or vim.b.ministatusline_disable == true
end

-- Mode -----------------------------------------------------------------------
-- Custom `^V` and `^S` symbols to make this file appropriate for copy-paste
-- (otherwise those symbols are not displayed).
local CTRL_S = vim.api.nvim_replace_termcodes('<C-S>', true, true, true)
local CTRL_V = vim.api.nvim_replace_termcodes('<C-V>', true, true, true)

-- stylua: ignore start
H.modes = setmetatable({
  ['n']    = { long = 'Normal',   short = 'N',   hl = 'MiniStatuslineModeNormal' },
  ['v']    = { long = 'Visual',   short = 'V',   hl = 'MiniStatuslineModeVisual' },
  ['V']    = { long = 'V-Line',   short = 'V-L', hl = 'MiniStatuslineModeVisual' },
  [CTRL_V] = { long = 'V-Block',  short = 'V-B', hl = 'MiniStatuslineModeVisual' },
  ['s']    = { long = 'Select',   short = 'S',   hl = 'MiniStatuslineModeVisual' },
  ['S']    = { long = 'S-Line',   short = 'S-L', hl = 'MiniStatuslineModeVisual' },
  [CTRL_S] = { long = 'S-Block',  short = 'S-B', hl = 'MiniStatuslineModeVisual' },
  ['i']    = { long = 'Insert',   short = 'I',   hl = 'MiniStatuslineModeInsert' },
  ['R']    = { long = 'Replace',  short = 'R',   hl = 'MiniStatuslineModeReplace' },
  ['c']    = { long = 'Command',  short = 'C',   hl = 'MiniStatuslineModeCommand' },
  ['r']    = { long = 'Prompt',   short = 'P',   hl = 'MiniStatuslineModeOther' },
  ['!']    = { long = 'Shell',    short = 'Sh',  hl = 'MiniStatuslineModeOther' },
  ['t']    = { long = 'Terminal', short = 'T',   hl = 'MiniStatuslineModeOther' },
}, {
  -- By default return 'Unknown' but this shouldn't be needed
  __index = function()
    return   { long = 'Unknown',  short = 'U',   hl = '%#MiniStatuslineModeOther#' }
  end,
})
-- stylua: ignore end

-- Default content ------------------------------------------------------------
function H.default_content_active()
  -- stylua: ignore start
  local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
  local git           = MiniStatusline.section_git({ trunc_width = 75 })
  local diagnostics   = MiniStatusline.section_diagnostics({ trunc_width = 75 })
  local filename      = MiniStatusline.section_filename({ trunc_width = 140 })
  local fileinfo      = MiniStatusline.section_fileinfo({ trunc_width = 120 })
  local location      = MiniStatusline.section_location({ trunc_width = 75 })

  -- Usage of `MiniStatusline.combine_groups()` ensures highlighting and
  -- correct padding with spaces between groups (accounts for 'missing'
  -- sections, etc.)
  return MiniStatusline.combine_groups({
    { hl = mode_hl,                  strings = { mode } },
    { hl = 'MiniStatuslineDevinfo',  strings = { git, diagnostics } },
    '%<', -- Mark general truncate point
    { hl = 'MiniStatuslineFilename', strings = { filename } },
    '%=', -- End left alignment
    { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
    { hl = mode_hl,                  strings = { location } },
  })
  -- stylua: ignore end
end

function H.default_content_inactive()
  return '%#MiniStatuslineInactive#%F%='
end

-- Utilities ------------------------------------------------------------------
function H.isnt_normal_buffer()
  -- For more information see ":h buftype"
  return vim.bo.buftype ~= ''
end

function H.get_filesize()
  local size = vim.fn.getfsize(vim.fn.getreg('%'))
  if size < 1024 then
    return string.format('%dB', size)
  elseif size < 1048576 then
    return string.format('%.2fKiB', size / 1024)
  else
    return string.format('%.2fMiB', size / 1048576)
  end
end

function H.get_filetype_icon()
  -- Skip if NerdFonts is disabled
  if not MiniStatusline.config.nerdfonts then
    return ''
  end
  -- Have this `require()` here to not depend on plugin initialization order
  local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
  if not has_devicons then
    return ''
  end

  local file_name, file_ext = vim.fn.expand('%:t'), vim.fn.expand('%:e')
  return devicons.get_icon(file_name, file_ext, { default = true })
end

if vim.fn.has('nvim-0.6') == 1 then
  H.get_diagnostic_count = function(id)
    return #vim.diagnostic.get(0, { severity = id })
  end
else
  H.get_diagnostic_count = function(id)
    return vim.lsp.diagnostic.get_count(0, id)
  end
end

return MiniStatusline
