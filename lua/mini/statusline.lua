-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom minimal and fast statusline module with opinionated default look.
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
--- # Dependencies
---
--- Suggested dependencies (provide extra functionality, statusline will work
--- without them):
--- - Nerd font (to support extra icons).
--- - Plugin 'lewis6991/gitsigns.nvim' for Git information in
---   |MiniStatusline.section_git|. If missing, no section will be shown.
--- - Plugin 'kyazdani42/nvim-web-devicons' for filetype icons in
---   `MiniStatusline.section_fileinfo`. If missing, no icons will be shown.
---
--- # Setup
---
--- This module needs a setup with `require('mini.statusline').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`:
--- <pre>
--- {
---   -- Content of statusline as functions which return statusline string. See `:h
---   -- statusline` and code of default contents (used when `nil` is supplied).
---   content = {
---     -- Content for active window
---     active = nil,
---
---     -- Content for inactive window(s)
---     inactive = nil,
---   },
---
---   -- Whether to set Vim's settings for statusline (make it always shown)
---   set_vim_settings = true,
--- }
--- </pre>
---
--- # Example content
---
--- This function is used as default value for active content:
--- <pre>
--- `function()`
---   `local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })`
---   `local spell         = MiniStatusline.section_spell({ trunc_width = 120 })`
---   `local wrap          = MiniStatusline.section_wrap({ trunc_width = 120 })`
---   `local git           = MiniStatusline.section_git({ trunc_width = 75 })`
---   `local diagnostics   = MiniStatusline.section_diagnostics({ trunc_width = 75 })`
---   `local filename      = MiniStatusline.section_filename({ trunc_width = 140 })`
---   `local fileinfo      = MiniStatusline.section_fileinfo({ trunc_width = 120 })`
---   `local location      = MiniStatusline.section_location({ trunc_width = 75 })`
---
---   `return MiniStatusline.combine_groups({`
---     `{ hl = mode_hl,                  strings = { mode, spell, wrap } },`
---     `{ hl = 'MiniStatuslineDevinfo',  strings = { git, diagnostics } },`
---     `'%<', -- Mark general truncate point`
---     `{ hl = 'MiniStatuslineFilename', strings = { filename } },`
---     `'%=', -- End left alignment`
---     `{ hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },`
---     `{ hl = mode_hl,                  strings = { location } },`
---   `})`
--- `end`
--- </pre>
---
--- # Highlight groups
---
--- 1. Highlighting depending on mode (returned as second value from
---    |MiniStatusline.section_mode|):
---     - `MiniStatuslineModeNormal` - normal mode.
---     - `MiniStatuslineModeInsert` - insert mode.
---     - `MiniStatuslineModeVisual` - visual mode.
---     - `MiniStatuslineModeReplace` - replace mode.
---     - `MiniStatuslineModeCommand` - command mode.
---     - `MiniStatuslineModeOther` - other mode (like terminal, etc.).
--- 2. Highlight groups used in default statusline:
---     - `MiniStatuslineDevinfo` - highlighting of "dev info" group
---       (|MiniStatusline.section_git| and
---       |MiniStatusline.section_diagnostics|).
---     - `MiniStatuslineFilename` - highliting of
---       |MiniStatusline.section_filename| section.
---     - `MiniStatuslineFileinfo` - highliting of
---       |MiniStatusline.section_fileinfo| section.
--- 3. `MiniStatuslineInactive` - highliting in not focused window.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling
---
--- To disable (show empty statusline), set `g:ministatusline_disable`
--- (globally) or `b:ministatusline_disable` (for a buffer) to `v:true`.
---@brief ]]
---@tag MiniStatusline mini.statusline

-- Module and its helper
local MiniStatusline = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
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
    [[hi link MiniStatuslineModeNormal  Cursor
      hi link MiniStatuslineModeInsert  DiffChange
      hi link MiniStatuslineModeVisual  DiffAdd
      hi link MiniStatuslineModeReplace DiffDelete
      hi link MiniStatuslineModeCommand DiffText
      hi link MiniStatuslineModeOther   IncSearch

      hi link MiniStatuslineDevinfo  StatusLine
      hi link MiniStatuslineFilename StatusLineNC
      hi link MiniStatuslineFileinfo StatusLine
      hi link MiniStatuslineInactive StatusLineNC]],
    false
  )
end

-- Module config
MiniStatusline.config = {
  -- Content of statusline as functions which return statusline string. See `:h
  -- statusline` and code of default contents (used when `nil` is supplied).
  content = {
    -- Content for active window
    active = nil,
    -- Content for inactive window(s)
    inactive = nil,
  },

  -- Whether to set Vim's settings for statusline
  set_vim_settings = true,
}

-- Module functionality
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
--- General idea of this function is as follows. String group is used as is
--- (useful for special strings like `%<` or `%=`). Each group defined by table
--- has own highlighting (if not supplied explicitly, the previous one is
--- used). Non-empty strings inside group are separated by one space. Non-empty
--- groups are separated by two spaces (one for each highlighting).
---
---@param groups table: List of groups
---@return string: String suitable for 'statusline'.
function MiniStatusline.combine_groups(groups)
  local t = vim.tbl_map(function(s)
    if not s then
      return ''
    end
    if type(s) == 'string' then
      return s
    end
    local t = vim.tbl_filter(function(x)
      return not (x == nil or x == '')
    end, s.strings)
    -- Return highlight group to allow inheritance from later sections
    if vim.tbl_count(t) == 0 then
      return string.format('%%#%s#', s.hl or '')
    end
    return string.format('%%#%s# %s ', s.hl or '', table.concat(t, ' '))
  end, groups)
  return table.concat(t, '')
end

-- Statusline sections. Should return output text without whitespace on sides
-- or empty string to omit section.

-- Mode
-- Custom `^V` and `^S` symbols to make this file appropriate for copy-paste
-- (otherwise those symbols are not displayed).
local CTRL_S = vim.api.nvim_replace_termcodes('<C-S>', true, true, true)
local CTRL_V = vim.api.nvim_replace_termcodes('<C-V>', true, true, true)

-- stylua: ignore start
MiniStatusline.modes = setmetatable({
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

--- Section for Vim |mode()|
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args table: Section arguments.
---@return section_string, mode_hl tuple: Section string and mode's highlight group.
function MiniStatusline.section_mode(args)
  local mode_info = MiniStatusline.modes[vim.fn.mode()]

  local mode = H.is_truncated(args.trunc_width) and mode_info.short or mode_info.long

  return mode, mode_info.hl
end

--- Section for 'spell'
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args table: Section arguments.
---@return string: Section string.
function MiniStatusline.section_spell(args)
  if not vim.wo.spell then
    return ''
  end

  if H.is_truncated(args.trunc_width) then
    return 'SP'
  end

  return string.format('SPELL(%s)', vim.bo.spelllang)
end

--- Section for 'wrap'
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args table: Section arguments.
---@return string: Section string.
function MiniStatusline.section_wrap(args)
  if not vim.wo.wrap then
    return ''
  end

  if H.is_truncated(args.trunc_width) then
    return 'WR'
  end

  return 'WRAP'
end

--- Section for Git information
---
--- Normal output contains name of `HEAD` (via |b:gitsigns_head|) and chunk
--- information (via |b:gitsigns_status|). Short output - only name of `HEAD`.
--- Note: requires 'lewis6991/gitsigns' plugin.
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args table: Section arguments.
---@return string: Section string.
function MiniStatusline.section_git(args)
  if H.isnt_normal_buffer() then
    return ''
  end

  local head = vim.b.gitsigns_head or '-'
  local signs = H.is_truncated(args.trunc_width) and '' or (vim.b.gitsigns_status or '')

  if signs == '' then
    if head == '-' or head == '' then
      return ''
    end
    return string.format(' %s', head)
  end
  return string.format(' %s %s', head, signs)
end

--- Section for Neovim's builtin diagnostics
---
--- Shows nothing if there is no attached LSP clients or for short output.
--- Otherwise uses |vim.lsp.diagnostic.get_count()| to show number of errors
--- ('E'), warnings ('W'), information ('I'), and hints ('H').
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args table: Section arguments.
---@return string: Section string.
function MiniStatusline.section_diagnostics(args)
  -- Assumption: there are no attached clients if table
  -- `vim.lsp.buf_get_clients()` is empty
  local hasnt_attached_client = next(vim.lsp.buf_get_clients()) == nil
  local dont_show_lsp = H.is_truncated(args.trunc_width) or H.isnt_normal_buffer() or hasnt_attached_client
  if dont_show_lsp then
    return ''
  end

  -- Construct diagnostic info using predefined order
  local t = {}
  for _, level in ipairs(H.diagnostic_levels) do
    local n = vim.lsp.diagnostic.get_count(0, level.name)
    -- Add level info only if diagnostic is present
    if n > 0 then
      table.insert(t, string.format(' %s%s', level.sign, n))
    end
  end

  if vim.tbl_count(t) == 0 then
    return 'ﯭ  -'
  end
  return string.format('ﯭ %s', table.concat(t, ''))
end

--- Section for file name
---
--- Show full file name or relative in short output.
---
--- Short output is returned if window width is lower than `args.trunc_width`.
---
---@param args table: Section arguments.
---@return string: Section string.
function MiniStatusline.section_filename(args)
  -- In terminal always use plain name
  if vim.bo.buftype == 'terminal' then
    return '%t'
  elseif H.is_truncated(args.trunc_width) then
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
---@param args table: Section arguments.
---@return string: Section string.
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
  if H.is_truncated(args.trunc_width) then
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
---@param args table: Section arguments.
---@return string: Section string.
function MiniStatusline.section_location(args)
  -- Use virtual column number to allow update when paste last column
  if H.is_truncated(args.trunc_width) then
    return '%l│%2v'
  end

  return '%l|%L│%2v|%-2{col("$") - 1}'
end

-- Helper data
---- Module default config
H.default_config = MiniStatusline.config

H.diagnostic_levels = {
  { name = 'Error', sign = 'E' },
  { name = 'Warning', sign = 'W' },
  { name = 'Information', sign = 'I' },
  { name = 'Hint', sign = 'H' },
}

-- Helper functions
---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({
    content = { config.content, 'table' },
    ['content.active'] = { config.content.active, 'function', true },
    ['content.inactive'] = { config.content.inactive, 'function', true },

    set_vim_settings = { config.set_vim_settings, 'boolean' },
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

---- Default content
function H.default_content_active()
  -- stylua: ignore start
  local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
  local spell         = MiniStatusline.section_spell({ trunc_width = 120 })
  local wrap          = MiniStatusline.section_wrap({ trunc_width = 120 })
  local git           = MiniStatusline.section_git({ trunc_width = 75 })
  local diagnostics   = MiniStatusline.section_diagnostics({ trunc_width = 75 })
  local filename      = MiniStatusline.section_filename({ trunc_width = 140 })
  local fileinfo      = MiniStatusline.section_fileinfo({ trunc_width = 120 })
  local location      = MiniStatusline.section_location({ trunc_width = 75 })

  -- Usage of `MiniStatusline.combine_groups()` ensures highlighting and
  -- correct padding with spaces between groups (accounts for 'missing'
  -- sections, etc.)
  return MiniStatusline.combine_groups({
    { hl = mode_hl,                  strings = { mode, spell, wrap } },
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

---- Various helpers
function H.is_truncated(width)
  -- Use -1 to default to 'not truncated'
  return vim.api.nvim_win_get_width(0) < (width or -1)
end

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
  -- Have this `require()` here to not depend on plugin initialization order
  local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
  if not has_devicons then
    return ''
  end

  local file_name, file_ext = vim.fn.expand('%:t'), vim.fn.expand('%:e')
  return devicons.get_icon(file_name, file_ext, { default = true })
end

return MiniStatusline
