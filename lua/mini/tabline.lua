-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom minimal and fast tabline module. General idea: show all listed
--- buffers in readable way with minimal total width in case of one vim tab,
--- fall back for deafult otherwise. Inspired by
--- [ap/vim-buftabline](https://github.com/ap/vim-buftabline).
---
--- Features:
--- - Buffers are listed by their identifier (see |bufnr()|).
--- - Different highlight groups for "states" of buffer affecting 'buffer tabs':
--- - Buffer names are made unique by extending paths to files or appending
---   unique identifier to buffers without name.
--- - Current buffer is displayed "optimally centered" (in center of screen
---   while maximizing the total number of buffers shown) when there are many
---   buffers open.
--- - 'Buffer tabs' are clickable if Neovim allows it.
---
--- What it doesn't do:
--- - Custom buffer order is not supported.
---
--- # Dependencies
---
--- Suggested dependencies (provide extra functionality, tabline will work
--- without them):
--- - Plugin 'kyazdani42/nvim-web-devicons' for filetype icons near the buffer
---   name. If missing, no icons will be shown.
---
--- # Setup
---
--- This module needs a setup with `require('mini.tabline').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`:
--- <pre>
--- {
---   -- Whether to show file icons (requires 'kyazdani42/nvim-web-devicons')
---   show_icons = true,
---
---   -- Whether to set Vim's settings for tabline (make it always shown and
---   -- allow hidden buffers)
---   set_vim_settings = true
--- }
--- </pre>
---
--- # Highlight groups
---
--- 1. `MiniTablineCurrent` - buffer is current (has cursor in it).
--- 2. `MiniTablineVisible` - buffer is visible (displayed in some window).
--- 3. `MiniTablineHidden` - buffer is hidden (not displayed).
--- 4. `MiniTablineModifiedCurrent` - buffer is modified and current.
--- 5. `MiniTablineModifiedVisible` - buffer is modified and visible.
--- 6. `MiniTablineModifiedHidden` - buffer is modified and hidden.
--- 7. `MiniTablineFill` - unused right space of tabline.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling
---
--- To disable (show empty tabline), set `g:minitabline_disable` (globally) or
--- `b:minitabline_disable` (for a buffer) to `v:true`. Note: after
--- disabling tabline is not updated right away, but rather after dedicated
--- event (see |events| and `MiniTabline` |augroup|).
---@brief ]]
---@tag MiniTabline mini.tabline

-- Module and its helper
local MiniTabline = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.tabline').setup({})` (replace `{}` with your `config` table)
function MiniTabline.setup(config)
  -- Export module
  _G.MiniTabline = MiniTabline

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  vim.api.nvim_exec(
    [[augroup MiniTabline
        autocmd!
        autocmd VimEnter   * lua MiniTabline.update_tabline()
        autocmd TabEnter   * lua MiniTabline.update_tabline()
        autocmd BufAdd     * lua MiniTabline.update_tabline()
        autocmd FileType  qf lua MiniTabline.update_tabline()
        autocmd BufDelete  * lua MiniTabline.update_tabline()
      augroup END]],
    false
  )

  -- Function to make tabs clickable
  vim.api.nvim_exec(
    [[function! MiniTablineSwitchBuffer(buf_id, clicks, button, mod)
        execute 'buffer' a:buf_id
      endfunction]],
    false
  )

  -- Create highlighting
  vim.api.nvim_exec(
    [[hi link MiniTablineCurrent TabLineSel
      hi link MiniTablineVisible TabLineSel
      hi link MiniTablineHidden  TabLine

      hi link MiniTablineModifiedCurrent StatusLine
      hi link MiniTablineModifiedVisible StatusLine
      hi link MiniTablineModifiedHidden  StatusLineNC

      hi MiniTablineFill NONE]],
    false
  )
end

-- Module config
MiniTabline.config = {
  -- Whether to show file icons (requires 'kyazdani42/nvim-web-devicons')
  show_icons = true,

  -- Whether to set Vim's settings for tabline (make it always shown and
  -- allow hidden buffers)
  set_vim_settings = true,
}

-- Module functionality
--- Update |tabline|
---
--- Designed to be used with |autocmd|. No need to use it directly,
function MiniTabline.update_tabline()
  if vim.fn.tabpagenr('$') > 1 then
    vim.o.tabline = [[]]
  else
    vim.o.tabline = [[%!v:lua.MiniTabline.make_tabline_string()]]
  end
end

--- Make string for |tabline| in case of single tab
function MiniTabline.make_tabline_string()
  if H.is_disabled() then
    return ''
  end

  H.list_tabs()
  H.finalize_labels()
  H.fit_width()

  return H.concat_tabs()
end

-- Helper data
---- Module default config
H.default_config = MiniTabline.config

---- Table to keep track of tabs
H.tabs = {}

---- Indicator of whether there is clickable support
H.tablineat = vim.fn.has('tablineat')

---- Keep track of initially unnamed buffers
H.unnamed_buffers_seq_ids = {}

---- Separator of file path
H.path_sep = package.config:sub(1, 1)

---- Buffer number of center buffer
H.center_buf_id = vim.fn.winbufnr(0)

-- Helper functions
---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({
    show_icons = { config.show_icons, 'boolean' },
    set_vim_settings = { config.set_vim_settings, 'boolean' },
  })

  return config
end

function H.apply_config(config)
  MiniTabline.config = config

  -- Set settings to ensure tabline is displayed properly
  if config.set_vim_settings then
    vim.o.showtabline = 2 -- Always show tabline
    vim.o.hidden = true -- Allow switching buffers without saving them
  end
end

function H.is_disabled()
  return vim.g.minitabline_disable == true or vim.b.minitabline_disable == true
end

---- List tabs
function H.list_tabs()
  local tabs = {}
  for i = 1, vim.fn.bufnr('$') do
    if H.is_buffer_in_minitabline(i) then
      local tab = { buf_id = i }
      tab['hl'] = H.construct_highlight(i)
      tab['tabfunc'] = H.construct_tabfunc(i)
      tab['label'], tab['label_extender'] = H.construct_label_data(i)

      table.insert(tabs, tab)
    end
  end

  H.tabs = tabs
end

function H.is_buffer_in_minitabline(buf_id)
  return (vim.fn.buflisted(buf_id) > 0) and (vim.fn.getbufvar(buf_id, '&buftype') ~= 'quickfix')
end

---- Tab's highlight group
function H.construct_highlight(buf_id)
  local hl_type
  if buf_id == vim.fn.winbufnr(0) then
    hl_type = 'Current'
  elseif vim.fn.bufwinnr(buf_id) > 0 then
    hl_type = 'Visible'
  else
    hl_type = 'Hidden'
  end
  if vim.fn.getbufvar(buf_id, '&modified') > 0 then
    hl_type = 'Modified' .. hl_type
  end

  return string.format('%%#MiniTabline%s#', hl_type)
end

---- Tab's clickable action (if supported)
function H.construct_tabfunc(buf_id)
  if H.tablineat > 0 then
    return string.format([[%%%d@MiniTablineSwitchBuffer@]], buf_id)
  else
    return ''
  end
end

---- Tab's label and label extender
function H.construct_label_data(buf_id)
  local label, label_extender

  local bufpath = vim.fn.bufname(buf_id)
  if bufpath ~= '' then
    -- Process path buffer
    label = vim.fn.fnamemodify(bufpath, ':t')
    label_extender = H.make_path_extender(buf_id)
  else
    -- Process unnamed buffer
    label = H.make_unnamed_label(buf_id)
    label_extender = function(x)
      return x
    end
  end

  return label, label_extender
end

function H.make_path_extender(buf_id)
  return function(label)
    -- Add parent to current label
    local full_path = vim.fn.fnamemodify(vim.fn.bufname(buf_id), ':p')
    -- Using `vim.pesc` prevents effect of problematic characters (like '.')
    local pattern = string.format('[^%s]+%s%s$', H.path_sep, H.path_sep, vim.pesc(label))
    return string.match(full_path, pattern) or label
  end
end

---- Work with unnamed buffers. They are tracked in `H.unnamed_buffers_seq_ids`
---- for disambiguation. This table is designed to store 'sequential' buffer
---- identifier. This approach allows to have the following behavior:
---- - Create three unnamed buffers.
---- - Delete second one.
---- - Tab label for third one remains the same.
function H.make_unnamed_label(buf_id)
  local label = H.is_buffer_scratch(buf_id) and '!' or '*'

  -- Possibly add tracking id
  local unnamed_id = H.get_unnamed_id(buf_id)
  if unnamed_id > 1 then
    label = string.format('%s(%d)', label, unnamed_id)
  end

  return label
end

function H.is_buffer_scratch(buf_id)
  local buftype = vim.fn.getbufvar(buf_id, '&buftype')
  return (buftype == 'acwrite') or (buftype == 'nofile')
end

function H.get_unnamed_id(buf_id)
  -- Use existing sequential id if possible
  local seq_id = H.unnamed_buffers_seq_ids[buf_id]
  if seq_id ~= nil then
    return seq_id
  end

  -- Cache sequential id for currently unnamed buffer `buf_id`
  H.unnamed_buffers_seq_ids[buf_id] = vim.tbl_count(H.unnamed_buffers_seq_ids) + 1
  return H.unnamed_buffers_seq_ids[buf_id]
end

-- Finalize labels
function H.finalize_labels()
  -- Deduplicate
  local nonunique_tab_ids = H.get_nonunique_tab_ids()
  while #nonunique_tab_ids > 0 do
    local nothing_changed = true

    -- Extend labels
    for _, buf_id in ipairs(nonunique_tab_ids) do
      local tab = H.tabs[buf_id]
      local old_label = tab.label
      tab.label = tab.label_extender(tab.label)
      if old_label ~= tab.label then
        nothing_changed = false
      end
    end

    if nothing_changed then
      break
    end

    nonunique_tab_ids = H.get_nonunique_tab_ids()
  end

  -- Postprocess: add file icons and padding
  local has_devicons, devicons

  ---- Have this `require()` here to not depend on plugin initialization order
  if MiniTabline.config.show_icons then
    has_devicons, devicons = pcall(require, 'nvim-web-devicons')
  end

  for _, tab in pairs(H.tabs) do
    if MiniTabline.config.show_icons and has_devicons then
      local extension = vim.fn.fnamemodify(tab.label, ':e')
      local icon = devicons.get_icon(tab.label, extension, { default = true })
      tab.label = string.format(' %s %s ', icon, tab.label)
    else
      tab.label = string.format(' %s ', tab.label)
    end
  end
end

--@return List of `H.tabs` ids which have non-unique labels
function H.get_nonunique_tab_ids()
  -- Collect tab-list-id per label
  local label_tab_ids = {}
  for i, tab in ipairs(H.tabs) do
    local label = tab.label
    if label_tab_ids[label] == nil then
      label_tab_ids[label] = { i }
    else
      table.insert(label_tab_ids[label], i)
    end
  end

  -- Collect tab-list-ids with non-unique labels
  return vim.tbl_flatten(vim.tbl_filter(function(x)
    return #x > 1
  end, label_tab_ids))
end

---- Fit tabline to maximum displayed width
function H.fit_width()
  H.update_center_buf_id()

  -- Compute label width data
  local center = 1
  local tot_width = 0
  for _, tab in pairs(H.tabs) do
    -- Use `nvim_strwidth()` and not `:len()` to respect multibyte characters
    tab.label_width = vim.api.nvim_strwidth(tab.label)
    tab.chars_on_left = tot_width

    tot_width = tot_width + tab.label_width

    if tab.buf_id == H.center_buf_id then
      -- Make end of 'center tab' to be always displayed in center in case of
      -- truncation
      center = tot_width
    end
  end

  local display_interval = H.compute_display_interval(center, tot_width)

  H.truncate_tabs_display(display_interval)
end

function H.update_center_buf_id()
  local buf_displayed = vim.fn.winbufnr(0)
  if H.is_buffer_in_minitabline(buf_displayed) then
    H.center_buf_id = buf_displayed
  end
end

function H.compute_display_interval(center, tabline_width)
  -- left - first character to be displayed (starts with 1)
  -- right - last character to be displayed
  -- Conditions to be satisfied:
  -- 1) right - left + 1 = math.min(tot_width, tabline_width)
  -- 2) 1 <= left <= tabline_width; 1 <= right <= tabline_width

  local tot_width = vim.o.columns

  -- Usage of `math.ceil` is crucial to avoid non-integer values which might
  -- affect total width of output tabline string
  local right = math.min(tabline_width, math.ceil(center + 0.5 * tot_width))
  local left = math.max(1, right - tot_width + 1)
  right = left + math.min(tot_width, tabline_width) - 1

  return { left, right }
end

function H.truncate_tabs_display(display_interval)
  local display_left, display_right = display_interval[1], display_interval[2]

  local tabs = {}
  for _, tab in ipairs(H.tabs) do
    local tab_left = tab.chars_on_left + 1
    local tab_right = tab.chars_on_left + tab.label_width
    if (display_left <= tab_right) and (tab_left <= display_right) then
      -- Process tab that should be displayed (even partially)
      local n_trunc_left = math.max(0, display_left - tab_left)
      local n_trunc_right = math.max(0, tab_right - display_right)

      -- Take desired amount of characters starting from `n_trunc_left`
      tab.label = vim.fn.strcharpart(tab.label, n_trunc_left, tab.label_width - n_trunc_right)

      table.insert(tabs, tab)
    end
  end

  H.tabs = tabs
end

---- Concatenate tabs into single tabline string
function H.concat_tabs()
  -- NOTE: it is assumed that all padding is incorporated into labels
  local t = {}
  for _, tab in ipairs(H.tabs) do
    -- Escape '%' in labels
    table.insert(t, tab.hl .. tab.tabfunc .. tab.label:gsub('%%', '%%%%'))
  end

  return table.concat(t, '') .. '%#MiniTablineFill#'
end

return MiniTabline
