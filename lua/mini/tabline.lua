--- *mini.tabline* Tabline
--- *MiniTabline*
---
--- MIT License Copyright (c) 2021 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Key idea: show all listed buffers in readable way with minimal total width.
--- Also allow showing extra information section in case of multiple vim tabpages.
---
--- Features:
--- - Buffers are listed in the order of their identifier (see |bufnr()|).
---
--- - Different highlight groups for "states" of buffer affecting 'buffer tabs'.
---
--- - Buffer names are made unique by extending paths to files or appending
---   unique identifier to buffers without name.
---
--- - Current buffer is displayed "optimally centered" (in center of screen
---   while maximizing the total number of buffers shown) when there are many
---   buffers open.
---
--- - 'Buffer tabs' are clickable if Neovim allows it.
---
--- What it doesn't do:
--- - Custom buffer order is not supported.
---
--- # Dependencies ~
---
--- Suggested dependencies (provide extra functionality, tabline will work
--- without them):
--- - Plugin 'nvim-tree/nvim-web-devicons' for filetype icons near the buffer
---   name. If missing, no icons will be shown.
---
--- # Setup ~
---
--- This module needs a setup with `require('mini.tabline').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniTabline` which you can use for scripting or manually (with
--- `:lua MiniTabline.*`).
---
--- See |MiniTabline.config| for `config` structure and default values.
---
--- You can override runtime config settings locally to buffer inside
--- `vim.b.minitabline_config` which should have same structure as
--- `MiniTabline.config`. See |mini.nvim-buffer-local-config| for more details.
---
--- # Highlight groups ~
---
--- * `MiniTablineCurrent` - buffer is current (has cursor in it).
--- * `MiniTablineVisible` - buffer is visible (displayed in some window).
--- * `MiniTablineHidden` - buffer is hidden (not displayed).
--- * `MiniTablineModifiedCurrent` - buffer is modified and current.
--- * `MiniTablineModifiedVisible` - buffer is modified and visible.
--- * `MiniTablineModifiedHidden` - buffer is modified and hidden.
--- * `MiniTablineFill` - unused right space of tabline.
--- * `MiniTablineTabpagesection` - section with tabpage information.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling ~
---
--- To disable (show empty tabline), set `vim.g.minitabline_disable` (globally) or
--- `vim.b.minitabline_disable` (for a buffer) to `true`. Considering high number
--- of different scenarios and customization intentions, writing exact rules
--- for disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes.

-- Module definition ==========================================================
local MiniTabline = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniTabline.config|.
---
---@usage `require('mini.tabline').setup({})` (replace `{}` with your `config` table)
MiniTabline.setup = function(config)
  -- Export module
  _G.MiniTabline = MiniTabline

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Function to make tabs clickable
  vim.api.nvim_exec(
    [[function! MiniTablineSwitchBuffer(buf_id, clicks, button, mod)
        execute 'buffer' a:buf_id
      endfunction]],
    false
  )

  -- Create default highlighting
  H.create_default_hl()
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniTabline.config = {
  -- Whether to show file icons (requires 'nvim-tree/nvim-web-devicons')
  show_icons = true,

  -- Whether to set Vim's settings for tabline (make it always shown and
  -- allow hidden buffers)
  set_vim_settings = true,

  -- Where to show tabpage section in case of multiple vim tabpages.
  -- One of 'left', 'right', 'none'.
  tabpage_section = 'left',
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Make string for |tabline|
MiniTabline.make_tabline_string = function()
  if H.is_disabled() then return '' end

  H.make_tabpage_section()
  H.list_tabs()
  H.finalize_labels()
  H.fit_width()

  return H.concat_tabs()
end

-- Helper data ================================================================
-- Module default config
H.default_config = vim.deepcopy(MiniTabline.config)

-- Table to keep track of tabs
H.tabs = {}

-- Indicator of whether there is clickable support
H.tablineat = vim.fn.has('tablineat')

-- Keep track of initially unnamed buffers
H.unnamed_buffers_seq_ids = {}

-- Separator of file path
H.path_sep = package.config:sub(1, 1)

-- String with tabpage prefix
H.tabpage_section = ''

-- Buffer number of center buffer
H.center_buf_id = nil

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({
    show_icons = { config.show_icons, 'boolean' },
    set_vim_settings = { config.set_vim_settings, 'boolean' },
    tabpage_section = { config.tabpage_section, 'string' },
  })

  return config
end

H.apply_config = function(config)
  MiniTabline.config = config

  -- Set settings to ensure tabline is displayed properly
  if config.set_vim_settings then
    vim.o.showtabline = 2 -- Always show tabline
    vim.o.hidden = true -- Allow switching buffers without saving them
  end

  -- Set tabline string
  vim.o.tabline = '%!v:lua.MiniTabline.make_tabline_string()'
end

--stylua: ignore
H.create_default_hl = function()
  local set_default_hl = function(name, data)
    data.default = true
    vim.api.nvim_set_hl(0, name, data)
  end

  set_default_hl('MiniTablineCurrent', { link = 'TabLineSel' })
  set_default_hl('MiniTablineVisible', { link = 'TabLineSel' })
  set_default_hl('MiniTablineHidden',  { link = 'TabLine' })

  set_default_hl('MiniTablineModifiedCurrent', { link = 'StatusLine' })
  set_default_hl('MiniTablineModifiedVisible', { link = 'StatusLine' })
  set_default_hl('MiniTablineModifiedHidden',  { link = 'StatusLineNC' })

  set_default_hl('MiniTablineTabpagesection', { link = 'Search' })

  set_default_hl('MiniTablineFill', { link = 'Normal' })
end

H.is_disabled = function() return vim.g.minitabline_disable == true or vim.b.minitabline_disable == true end

H.get_config = function(config)
  return vim.tbl_deep_extend('force', MiniTabline.config, vim.b.minitabline_config or {}, config or {})
end

-- Work with tabpages ---------------------------------------------------------
H.make_tabpage_section = function()
  local n_tabpages = vim.fn.tabpagenr('$')
  if n_tabpages == 1 or H.get_config().tabpage_section == 'none' then
    H.tabpage_section = ''
    return
  end

  local cur_tabpagenr = vim.fn.tabpagenr()
  H.tabpage_section = (' Tab %s/%s '):format(cur_tabpagenr, n_tabpages)
end

-- Work with tabs -------------------------------------------------------------
-- List tabs
H.list_tabs = function()
  local tabs = {}
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if H.is_buffer_in_minitabline(buf_id) then
      local tab = { buf_id = buf_id }
      tab['hl'] = H.construct_highlight(buf_id)
      tab['tabfunc'] = H.construct_tabfunc(buf_id)
      tab['label'], tab['label_extender'] = H.construct_label_data(buf_id)

      table.insert(tabs, tab)
    end
  end

  H.tabs = tabs
end

H.is_buffer_in_minitabline = function(buf_id) return vim.bo[buf_id].buflisted end

-- Tab's highlight group
H.construct_highlight = function(buf_id)
  local hl_type
  if buf_id == vim.api.nvim_get_current_buf() then
    hl_type = 'Current'
  elseif vim.fn.bufwinnr(buf_id) > 0 then
    hl_type = 'Visible'
  else
    hl_type = 'Hidden'
  end
  if vim.bo[buf_id].modified then hl_type = 'Modified' .. hl_type end

  return string.format('%%#MiniTabline%s#', hl_type)
end

-- Tab's clickable action (if supported)
H.construct_tabfunc = function(buf_id)
  if H.tablineat > 0 then
    return string.format('%%%d@MiniTablineSwitchBuffer@', buf_id)
  else
    return ''
  end
end

-- Tab's label and label extender
H.construct_label_data = function(buf_id)
  local label, label_extender

  local bufpath = vim.api.nvim_buf_get_name(buf_id)
  if bufpath ~= '' then
    -- Process path buffer
    label = vim.fn.fnamemodify(bufpath, ':t')
    label_extender = H.make_path_extender(buf_id)
  else
    -- Process unnamed buffer
    label = H.make_unnamed_label(buf_id)
    label_extender = function(x) return x end
  end

  return label, label_extender
end

H.make_path_extender = function(buf_id)
  -- Add parent to current label (if possible)
  return function(label)
    local full_path = vim.api.nvim_buf_get_name(buf_id)
    -- Using `vim.pesc` prevents effect of problematic characters (like '.')
    local pattern = string.format('[^%s]+%s%s$', vim.pesc(H.path_sep), vim.pesc(H.path_sep), vim.pesc(label))
    return string.match(full_path, pattern) or label
  end
end

-- Work with unnamed buffers --------------------------------------------------
-- Unnamed buffers are tracked in `H.unnamed_buffers_seq_ids` for
-- disambiguation. This table is designed to store 'sequential' buffer
-- identifier. This approach allows to have the following behavior:
-- - Create three unnamed buffers.
-- - Delete second one.
-- - Tab label for third one remains the same.
H.make_unnamed_label = function(buf_id)
  local label
  if vim.bo[buf_id].buftype == 'quickfix' then
    -- It would be great to differentiate for buffer `buf_id` between quickfix
    -- and location lists but it seems there is no reliable way to do so.
    -- The only one is to use `getwininfo(bufwinid(buf_id))` and look for
    -- `quickfix` and `loclist` fields, but that fails if buffer `buf_id` is
    -- not visible.
    label = '*quickfix*'
  else
    label = H.is_buffer_scratch(buf_id) and '!' or '*'
  end

  -- Possibly add tracking id
  local unnamed_id = H.get_unnamed_id(buf_id)
  if unnamed_id > 1 then label = string.format('%s(%d)', label, unnamed_id) end

  return label
end

H.is_buffer_scratch = function(buf_id)
  local buftype = vim.bo[buf_id].buftype
  return (buftype == 'acwrite') or (buftype == 'nofile')
end

H.get_unnamed_id = function(buf_id)
  -- Use existing sequential id if possible
  local seq_id = H.unnamed_buffers_seq_ids[buf_id]
  if seq_id ~= nil then return seq_id end

  -- Cache sequential id for currently unnamed buffer `buf_id`
  H.unnamed_buffers_seq_ids[buf_id] = vim.tbl_count(H.unnamed_buffers_seq_ids) + 1
  return H.unnamed_buffers_seq_ids[buf_id]
end

-- Work with labels -----------------------------------------------------------
H.finalize_labels = function()
  -- Deduplicate
  local nonunique_tab_ids = H.get_nonunique_tab_ids()
  while #nonunique_tab_ids > 0 do
    local nothing_changed = true

    -- Extend labels
    for _, buf_id in ipairs(nonunique_tab_ids) do
      local tab = H.tabs[buf_id]
      local old_label = tab.label
      tab.label = tab.label_extender(tab.label)
      if old_label ~= tab.label then nothing_changed = false end
    end

    if nothing_changed then break end

    nonunique_tab_ids = H.get_nonunique_tab_ids()
  end

  -- Postprocess: add file icons and padding
  local has_devicons, devicons
  local show_icons = H.get_config().show_icons

  -- Have this `require()` here to not depend on plugin initialization order
  if show_icons then
    has_devicons, devicons = pcall(require, 'nvim-web-devicons')
  end

  for _, tab in pairs(H.tabs) do
    if show_icons and has_devicons then
      local extension = vim.fn.fnamemodify(tab.label, ':e')
      local icon = devicons.get_icon(tab.label, extension, { default = true })
      tab.label = string.format(' %s %s ', icon, tab.label)
    else
      tab.label = string.format(' %s ', tab.label)
    end
  end
end

---@return table Array of `H.tabs` ids which have non-unique labels.
---@private
H.get_nonunique_tab_ids = function()
  -- Collect tab-array-id per label
  local label_tab_ids = {}
  for i, tab in ipairs(H.tabs) do
    local label = tab.label
    if label_tab_ids[label] == nil then
      label_tab_ids[label] = { i }
    else
      table.insert(label_tab_ids[label], i)
    end
  end

  -- Collect tab-array-ids with non-unique labels
  return vim.tbl_flatten(vim.tbl_filter(function(x) return #x > 1 end, label_tab_ids))
end

-- Fit tabline to maximum displayed width -------------------------------------
H.fit_width = function()
  H.update_center_buf_id()

  -- Compute label width data
  local center_offset = 1
  local tot_width = 0
  for _, tab in pairs(H.tabs) do
    -- Use `nvim_strwidth()` and not `:len()` to respect multibyte characters
    tab.label_width = vim.api.nvim_strwidth(tab.label)
    tab.chars_on_left = tot_width

    tot_width = tot_width + tab.label_width

    if tab.buf_id == H.center_buf_id then
      -- Make right end of 'center tab' to be always displayed in center in
      -- case of truncation
      center_offset = tot_width
    end
  end

  local display_interval = H.compute_display_interval(center_offset, tot_width)

  H.truncate_tabs_display(display_interval)
end

H.update_center_buf_id = function()
  local cur_buf = vim.api.nvim_get_current_buf()
  if H.is_buffer_in_minitabline(cur_buf) then H.center_buf_id = cur_buf end
end

H.compute_display_interval = function(center_offset, tabline_width)
  -- left - first character to be displayed (starts with 1)
  -- right - last character to be displayed
  -- Conditions to be satisfied:
  -- 1) right - left + 1 = math.min(tot_width, tabline_width)
  -- 2) 1 <= left <= tabline_width; 1 <= right <= tabline_width

  local tot_width = vim.o.columns - vim.api.nvim_strwidth(H.tabpage_section)

  -- Usage of `math.floor` is crucial to avoid non-integer values which might
  -- affect total width of output tabline string.
  -- Using `floor` instead of `ceil` has effect when `tot_width` is odd:
  -- - `floor` makes "true center" to be between second to last and last label
  --   character (usually non-space and space).
  -- - `ceil` - between last character of center label and first character of
  --   next label (both whitespaces).
  local right = math.min(tabline_width, math.floor(center_offset + 0.5 * tot_width))
  local left = math.max(1, right - tot_width + 1)
  right = left + math.min(tot_width, tabline_width) - 1

  return { left, right }
end

H.truncate_tabs_display = function(display_interval)
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

-- Concatenate tabs into single tablien string --------------------------------
H.concat_tabs = function()
  -- NOTE: it is assumed that all padding is incorporated into labels
  local t = {}
  for _, tab in ipairs(H.tabs) do
    -- Escape '%' in labels
    table.insert(t, ('%s%s%s'):format(tab.hl, tab.tabfunc, tab.label:gsub('%%', '%%%%')))
  end

  -- Usage of `%X` makes filled space to the right 'non-clickable'
  local res = ('%s%%X%%#MiniTablineFill#'):format(table.concat(t, ''))

  -- Add tabpage section
  local position = H.get_config().tabpage_section
  if H.tabpage_section ~= '' then
    if position == 'left' then res = ('%%#MiniTablineTabpagesection#%s%s'):format(H.tabpage_section, res) end
    if position == 'right' then
      -- Use `%=` to make it stick to right hand side
      res = ('%s%%=%%#MiniTablineTabpagesection#%s'):format(res, H.tabpage_section)
    end
  end

  return res
end

return MiniTabline
