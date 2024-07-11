--- *mini.icons* Icon provider
--- *MiniIcons*
---
--- MIT License Copyright (c) 2024 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Features:
---
--- - Provide icons with their highlighting via a single |MiniIcons.get()| for
---   various categories: filetype, file/directory path, extension, operating
---   system, LSP kind values. Icons and category defaults can be overridden.
---
--- - Configurable styles: "glyph" (icon glyphs) or "ascii" (non-glyph fallback).
---
--- - Fixed set of highlight groups (linked to built-in groups by default) for
---   better blend with color scheme.
---
--- - Caching for maximum performance.
---
--- - Integration with |vim.filetype.add()| and |vim.filetype.match()|.
---
--- - Mocking methods of 'nvim-tree/nvim-web-devicons' for better integrations
---   with plugins outside 'mini.nvim'. See |MiniIcons.mock_nvim_web_devicons()|.
---
--- Notes:
---
--- - It is not a goal to become a collection of icons for as much use cases as
---   possible. There are specific criteria for icon data to be included as
---   built-in in each category (see |MiniIcons.get()|).
---   The main supported category is "filetype".
---
--- # Dependencies ~
---
--- Suggested dependencies:
---
--- - Terminal emulator that supports showing special utf8 glyphs, possibly with
---   "overflow" view (displaying is done not in one but two visual cells).
---   Most modern feature-rich terminal emulators support this out of the box:
---   WezTerm, Kitty, Alacritty, iTerm2, Ghostty.
---   Not having "overflow" feature only results into smaller icons.
---   Not having support for special utf8 glyphs will result into seemingly
---   random symbols (or question mark squares) instead of icon glyphs.
---
--- - Font that supports Nerd Fonts (https://www.nerdfonts.com) icons from
---   version 3.0.0+ (in particular `nf-md-*` class).
---   This should be configured on terminal emulator level either by using font
---   patched with Nerd Fonts icons or using `NerdFontsSymbolsOnly` font as
---   a fallback for glyphs that are not supported in main font.
---
--- If using terminal emulator and/or font with icon support is impossible, use
--- `config.style = 'ascii'`. It will use a (less visually appealing) set of
--- non-glyph icons.
---
--- # Setup ~
---
--- This module needs a setup with `require('mini.icons').setup({})` (replace `{}`
--- with your `config` table). It will create global Lua table `MiniIcons` which you
--- can use for scripting or manually (with `:lua MiniIcons.*`).
---
--- See |MiniIcons.config| for `config` structure and default values.
---
--- # Comparisons ~
---
--- - 'nvim-tree/nvim-web-devicons' (for users):
---     - Sets individual colors to each icon with separate specific highlight
---       groups, while this modules uses fixed set of highlight groups.
---       This makes it easier to customize in bulk and actually blend with any
---       color scheme.
---
---     - This module prefers richer set of `nf-md-*` (from "Material design" set)
---       Nerd Fonts icons while 'nvim-web-devicons' mostly prefers `nf-dev-*`
---       (from "devicons" set).
---
---     - Supported categories are slightly different (with much overlap).
---
---     - Both support customization of any icon. Only this module supports
---       customization of default ones per supported category.
---
---     - Using this module can occasionally result in small delays when used
---       synchronously for many times to get icons for not typical files (like
---       in |mini.files|). This is due to using |vim.filetype.match()| fallback and
---       is present only during first call, as value is cached for later uses.
---
---     - This module supports different icon styles (like "ascii" for when using
---       glyphs is not possible), while 'nvim-web-devicons' does not.
---
---     - This module provides |MiniIcons.mock_nvim_web_devicons()| function which
---       when called imitates installed 'nvim-web-devicons' plugin to support
---       other plugins which do not provide 'mini.icons' yet.
---
--- - 'nvim-tree/nvim-web-devicons' (for plugin developers):
---     - Both have main "get icon" type of function:
---         - Both return tuple of icon and highlight group strings.
---
---         - This module always returns icon data possibly falling back to
---           user's configured default, while 'nvim-web-devicons' is able to
---           return `nil`. This module's approach is more aligned with the most
---           common use case of always showing an icon instead or near some data.
---           There is a third returned value indicating if output is a result of
---           a fallback (see |MiniIcons.get()|).
---
---         - This module uses |vim.filetype.match()| as a fallback for "file"
---           and "extension" categories, while 'nvim-web-devicons' completely
---           relies on the manually maintained tables of supported filenames
---           and extensions.
---           Using fallback results in a wider support and deeper integration
---           with Neovim's filetype detection at the cost of occasional slower
---           first call. The difference is reduced as much as is reasonable by
---           also having some manually tracked data tables for common cases.
---
---         - This module caches all its return values resulting in really fast
---           next same argument calls, while 'nvim-web-devicons' doesn't do that.
---
---         - This module works with full file/directory paths as input.
---
---     - Different sets of supported categories (see |MiniIcons.config|):
---         - Both support "file", "extension", "filetype", "operating system".
---           Albeit in different volumes: 'nvim-web-devicons' covers more
---           cases for "operating system", while this module has better eventual
---           coverage for other cases.
---
---
---         - This module supports "directory" and "lsp" categories.
---
---         - 'nvim-web-devicons' covers "desktop environment" and "window
---           management" categories. This modules does not include them due to
---           relatively low demand.
---
--- # Highlight groups ~
---
--- Only the following set of highlight groups is used as icon highlight.
--- It is recommended that they all only define colored foreground:
---
--- * `MiniIconsAzure`  - azure.
--- * `MiniIconsBlue`   - blue.
--- * `MiniIconsCyan`   - cyan.
--- * `MiniIconsGreen`  - green.
--- * `MiniIconsGrey`   - grey.
--- * `MiniIconsOrange` - orange.
--- * `MiniIconsPurple` - purple.
--- * `MiniIconsRed`    - red.
--- * `MiniIconsYellow` - yellow.
---
--- To change any highlight group, modify it directly with |:highlight|.

---@diagnostic disable:undefined-field
---@diagnostic disable:discard-returns
---@diagnostic disable:unused-local
---@diagnostic disable:cast-local-type
---@diagnostic disable:undefined-doc-name
---@diagnostic disable:luadoc-miss-type-name

-- Module definition ==========================================================
local MiniIcons = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniIcons.config|.
---
---@usage >lua
---   require('mini.icons').setup() -- use default config
---   -- OR
---   require('mini.icons').setup({}) -- replace {} with your config table
--- <
MiniIcons.setup = function(config)
  -- Export module
  _G.MiniIcons = MiniIcons

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Create default highlighting
  H.create_default_hl()
end

--stylua: ignore
--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # Style ~
---
--- `config.style` is a string defining which icon style to use. It can be:
--- - `'glyph'` (default) - use glyph icons (like 󰈔 and 󰉋 ).
--- - `'ascii'` - use fallback ASCII-compatible icons. Those are computed as
---   an upper first character of the icon's resolved name inside its category.
---   Examples: >lua
---
---     MiniIcons.get('file', 'Makefile') -- Has `'M'` as icon
---     MiniIcons.get('extension', 'lua') -- Has `'L'` as icon
---     MiniIcons.get('file', 'file.lua') -- Has `'L'` as icon; it is resolved to
---                                       -- come from 'lua' 'extension' category
---     MiniIcons.get('file', 'myfile')   -- Has `'F'` as icon; it is resolved to
---                                       -- come from 'file' 'default' category
--- <
--- # Customization per category ~
---
--- The following entries can be used to customize icons for supported categories:
--- - `config.default`
--- - `config.directory`
--- - `config.extension`
--- - `config.file`
--- - `config.filetype`
--- - `config.lsp`
--- - `config.os`
---
--- Customization should be done by supplying a table with <glyph> (icon glyph)
--- and/or <hl> (name of highlight group) string fields as a value for an icon
--- name entry. Example: >lua
---
---   require('mini.icons').setup({
---     default = {
---       -- Override default glyph for "file" category (reuse highlight group)
---       file = { glyph = '󰈤' },
---     },
---     extension = {
---       -- Override highlight group (not necessary from 'mini.icons')
---       lua = { hl = 'Special' },
---
---       -- Add icons for custom extension. This will also be used in
---       -- 'file' category for input like 'file.my.ext'.
---       ['my.ext'] = { glyph = '󰻲', hl = 'MiniIconsRed' },
---     },
---   })
--- <
--- Notes:
--- - These customizations only take effect inside |MiniIcons.setup()| call.
---   Changing interactively via `:lua MiniIcons.config.xxx = { ... }` does not work
---   for performance reasons.
--- - Use lower case names for categories which are matched ignoring case.
---   See |MiniIcons.get()| for more details.
MiniIcons.config = {
  -- Icon style: 'glyph' or 'ascii'
  style = 'glyph',

  -- Customize per category. See `:h MiniIcons.config` for details.
  default   = {},
  directory = {},
  extension = {},
  file      = {},
  filetype  = {},
  lsp       = {},
  os        = {},
}
--minidoc_afterlines_end

--- Get icon data
---
--- Usage example: >lua
---
---   -- Results into `icon='󰢱'`, `hl='MiniIconsAzure'`, `is_default=false`
---   local icon, hl, is_default = MiniIcons.get('file', 'file.lua')
--- <
--- Notes:
--- - Always returns some data, even if icon name is not explicitly supported
---   within target category. Category "default" is used as a fallback. Use third
---   output value to check if this particular case is a result of a fallback.
---
--- - Glyphs are explicitly preferred (when reasonable) from a richer set of
---   `nf-md-*` class  ("Material design" set) of Nerd Fonts icons.
---
--- - Output is cached after the first call to increase performance of next calls
---   with same arguments. To reset cache, call |MiniIcons.setup()|.
---
--- - To increase first call performance for "extension" and "file" categories,
---   add frequently used values in |MiniIcons.config|. They will be preferred
---   over executing |vim.filetype.match()|.
---
--- - Matching icon name for "file" and "directory" categories is done exactly
---   and respecting case. Others are done ignoring case.
---
--- - The recommended way to use this function in plugin is first checking if
---   `_G.MiniIcons` table is present (which means that user explicitly enabled
---   'mini.icons') and provide icons only if it is.
---
---@param category string Category name. Supported categories:
---   - `'default'` - icon data used as fallback for any category.
---     Icon names:
---       - <Input>: any supported category name.
---       - <Built-in>: only supported category names.
---
---     Examples: >lua
---
---       MiniIcons.get('default', 'file')
--- <
---   - `'directory'` - icon data for directory path.
---     Icon names:
---       - <Input>: any string, but only basename is used. Works with not present
---         paths (no check is done).
---       - <Built-in>: popular directory names not tied to language/software
---         (with few notable exceptions like Neovim, Git, etc.).
---
---     Examples: >lua
---
---       -- All of these will result in the same output
---       MiniIcons.get('directory', '.config')
---       MiniIcons.get('directory', '~/.config')
---       MiniIcons.get('directory', '/home/user/.config')
---
---       -- Results in different output
---       MiniIcons.get('directory', '.Config')
--- <
---   - `'extension'` - icon data for extension.
---     Icon names:
---       - <Input>: any string (without extra dot prefix).
---       - <Built-in>: popular extensions not tied to language/software (with
---         few notable exceptions) and without associated filetype; plus a set
---         of filetype associated extensions (for performance or better support).
---
---     Icon data is attempted to be resolved in the following order:
---       - List of built-in and user configured extensions (for better
---         performance). Run `:=MiniIcons.list('extension')` to see them.
---       - Filetype as a result of |vim.filetype.match()| with placeholder
---         file name. Uses output of corresponding "filetype" category.
---
---     Examples: >lua
---
---       -- All of these will result in the same output
---       MiniIcons.get('extension', 'lua')
---       MiniIcons.get('extension', 'LUA')
--- <
---   - `'file'` - icon data for file path.
---     Icon names:
---       - <Input>: any string, but only basename is used. Works with not present
---         paths (no check is done).
---       - <Built-in>: popular file names not tied to language/software
---         (with few notable exceptions like Neovim, Git, etc.).
---
---     Icon data is attempted to be resolved in the following order:
---       - List of built-in and user configured file names (to match exactly).
---         Run `:=MiniIcons.list('flle')` to see them.
---       - List of built-in and user configured extensions.
---         Run `:=MiniIcons.list('extension')` to see them.
---         This step also includes already cached extensions.
---         Uses output of corresponding "extension" category.
---       - Filetype as a result of |vim.filetype.match()|.
---         Uses output of corresponding "filetype" category.
---
---     Examples: >lua
---
---       -- All of these will result in the same output
---       MiniIcons.get('file', 'init.lua')
---       MiniIcons.get('file', '~/.config/nvim/init.lua')
---       MiniIcons.get('file', '/home/user/.config/nvim/init.lua')
---
---       -- Results in different output
---       MiniIcons.get('file', 'Init.lua')
---       MiniIcons.get('file', 'init.LUA')
--- <
---   - `'filetype'` - icon data for 'filetype' values.
---     Icon names:
---       - <Input>: any string.
---       - <Built-in>: any filetype that is reasonably used in Neovim ecosystem.
---         This category is intended as a widest net for supporting use cases.
---         Users are encouraged to have a specific filetype detection set up.
---
---     Examples: >lua
---
---       MiniIcons.get('filetype', 'lua')
---       MiniIcons.get('filetype', 'help')
---       MiniIcons.get('filetype', 'minifiles')
--- <
---   - `'lsp'` - icon data for various "LSP kind" values.
---     Icon names:
---       - <Input>: any string.
---       - <Built-in>: only namesspace entries from LSP specification that are
---         can be displayed to user. Like `CompletionItemKind`, `SymbolKind`, etc.
---
---     Examples: >lua
---
---       MiniIcons.get('lsp', 'array')
---       MiniIcons.get('lsp', 'keyword')
--- <
---   - `'os'` - icon data for popular operating systems.
---     Icon names:
---       - <Input>: any string.
---       - <Built-in>: only operating systems which have `nf-md-*` class icon.
---
---     Examples: >lua
---
---       MiniIcons.get('os', 'linux')
---       MiniIcons.get('os', 'arch')
---       MiniIcons.get('os', 'macos')
--- <
---@param name string Icon name within category. Use |MiniIcons.list()| to get icon
---   names which are explicitly supported for specific category.
---
---@return [string,string,boolean] Tuple of icon string, highlight group name it is
---   suggested to be highlighted with, and boolean indicating whether this icon
---   was returned as a result of fallback to default. Example: >lua
---
---   -- Results into `icon='󰢱'`, `hl='MiniIconsAzure'`, `is_default=false`
---   local icon, hl, is_default = MiniIcons.get('file', 'file.lua')
---
---   -- Results into `icon='󰈔'`, `hl='MiniIconsGrey'`, `is_default=true`
---   local icon, hl, is_default = MiniIcons.get('file', 'not-supported')
--- <
MiniIcons.get = function(category, name)
  if not (type(category) == 'string' and type(name) == 'string') then
    H.error('Both `category` and `name` should be string.')
  end

  -- Get "get" implementation now to show informative message for bad category
  local getter = H.get_impl[category]
  if getter == nil then H.error(vim.inspect(category) .. ' is not a supported category.') end

  -- Try cache first
  name = (category == 'file' or category == 'directory') and H.fs_basename(name) or name:lower()
  local cached = H.cache[category][name]
  if cached ~= nil then return cached[1], cached[2], cached[3] end

  -- Get icon
  local icon, hl = getter(name)
  local is_default = false
  if icon == nil then
    -- Fall back to category default
    icon, hl = unpack(H.cache.default[category])
    is_default = true
  end
  if hl == nil then
    -- Normalize if icon is returned first time
    icon, hl = H.style_icon(icon.glyph, name), icon.hl
  end

  -- Save to cache and return
  H.cache[category][name] = { icon, hl, is_default }
  return icon, hl, is_default
end

--- List explicitly supported icon names
---
---@param category string Category name supported by |MiniIcons.get()|.
---
---@return table Array of icon names which are explicitly supported for category.
---   Note, that `'file'` and `'extension'` categories support much more icon names
---   via their fallback to using |vim.filetype.match()| with `'filetype'` category.
MiniIcons.list = function(category)
  local category_icons = H[category .. '_icons']
  if category_icons == nil then H.error(vim.inspect(category) .. ' is not a supported category.') end

  -- Output is a union of explicit built-in and custom icons
  local res_map = {}
  for k, _ in pairs(category_icons) do
    res_map[k] = true
  end
  for k, _ in pairs(MiniIcons.config[category]) do
    res_map[k] = true
  end

  local res = vim.tbl_keys(res_map)
  table.sort(res)
  return res
end

--- Mock 'nvim-web-devicons' module
---
--- Call this function to mock exported functions of 'nvim-tree/nvim-web-devicons'
--- plugin. It will mock all its functions which return icon data by
--- using |MiniIcons.get()| equivalent.
---
--- This function is useful if any plugins relevant to you depend solely on
--- 'nvim-web-devicons' and have not yet added an integration with 'mini.icons'.
---
--- Full example of usage: >lua
---
---   require('mini.icons').setup()
---   MiniIcons.mock_nvim_web_devicons()
--- <
--- Works without installed 'nvim-web-devicons' and even with it installed (needs
--- to be called after 'nvim-web-devicons' is set up).
MiniIcons.mock_nvim_web_devicons = function()
  local M = {}

  -- Main functions which get icon and highlight group
  M.get_icon = function(name, ext, opts)
    -- Preferring 'name' first leads to a slightly different behavior compared to
    -- the original in case both `name` and `ext` is supplied:
    -- - Original: try exact `name`, then `ext`, then extensions in `name`.
    -- - This: use 'file' category and ignore `ext` completely.
    -- In practice this seems like a better choice because it accounts for
    -- special file names at the cost of ignoring `ext` if it conflicts with
    -- `name` (which rarely happens) and very small overhead of recomputing
    -- extension (which assumed to already be computed by the caller).
    local is_file = type(name) == 'string'
    local category = is_file and 'file' or 'extension'
    local icon, hl, is_default = MiniIcons.get(category, is_file and name or ext)
    if is_default and not (opts or {}).default then return nil, nil end
    return icon, hl
  end

  M.get_icon_by_filetype = function(ft, opts)
    local icon, hl, is_default = MiniIcons.get('filetype', ft)
    if is_default and not (opts or {}).default then return nil, nil end
    return icon, hl
  end

  -- Use default colors of default icon (#6d8086 and 66) by default
  local get_hl_data = function(...) return vim.api.nvim_get_hl_by_name(...) end
  local get_hex = function(hl)
    if hl == nil then return nil end
    return string.format('#%06x', get_hl_data(hl, true).foreground or 7176326)
  end
  local get_cterm = function(hl)
    if hl == nil then return nil end
    return get_hl_data(hl, false).foreground or 66
  end
  local with_hex = function(icon, hl) return icon, get_hex(hl) end
  local with_cterm = function(icon, hl) return icon, get_cterm(hl) end
  local with_hex_cterm = function(icon, hl) return icon, get_hex(hl), get_cterm(hl) end

  M.get_icon_color = function(...) return with_hex(M.get_icon(...)) end
  M.get_icon_cterm_color = function(...) return with_cterm(M.get_icon(...)) end
  M.get_icon_colors = function(...) return with_hex_cterm(M.get_icon(...)) end

  M.get_icon_color_by_filetype = function(...) return with_hex(M.get_icon_by_filetype(...)) end
  M.get_icon_cterm_color_by_filetype = function(...) return with_cterm(M.get_icon_by_filetype(...)) end
  M.get_icon_colors_by_filetype = function(...) return with_hex_cterm(M.get_icon_by_filetype(...)) end

  M.get_icon_name_by_filetype = function(ft) return ft end

  -- Mock `get_icons_*()` to the extent they are compatible with this module
  local make_icon_tbl = function(category, name, output_name)
    local icon, hl = MiniIcons.get(category, name)
    return { icon = icon, color = get_hex(hl), cterm_color = tostring(get_cterm(hl)), name = output_name }
  end
  local make_category_tbl = function(category)
    local res = {}
    -- This won't list all supported names (due to fallback), but at least some
    for _, name in ipairs(MiniIcons.list(category)) do
      res[name] = make_icon_tbl(category, name, name)
    end
    return res
  end

  M.get_default_icon = function() return make_icon_tbl('default', 'file', 'Default') end

  M.get_icons = function()
    return vim.tbl_deep_extend(
      'force',
      { [1] = M.get_default_icon() },
      make_category_tbl('os'),
      make_category_tbl('file'),
      make_category_tbl('extension')
    )
  end
  M.get_icons_by_desktop_environment = function() return {} end
  M.get_icons_by_extension = function() return make_category_tbl('extension') end
  M.get_icons_by_filename = function() return make_category_tbl('file') end
  M.get_icons_by_operating_system = function() return make_category_tbl('os') end
  M.get_icons_by_window_manager = function() return {} end

  -- Should be no need in the these. Suggest using `MiniIcons.setup()`.
  M.has_loaded = function() return true end
  M.refresh = function() end
  M.set_default_icon = function() end
  M.set_icon = function() end
  M.set_icon_by_filetype = function() end
  M.set_up_highlights = function() end
  M.setup = function() end

  -- Mock. Prefer `package.preload` as it seems to be a better practice.
  local modname = 'nvim-web-devicons'
  if package.loaded[modname] == nil then
    package.preload[modname] = function() return M end
  else
    package.loaded[modname] = M
  end
end

-- Helper data ================================================================
-- Module default config
H.default_config = MiniIcons.config

-- Default icons per supported category
--stylua: ignore
H.default_icons = {
  default   = { glyph = '󰟢', hl = 'MiniIconsGrey'   },
  directory = { glyph = '󰉋', hl = 'MiniIconsAzure'  },
  extension = { glyph = '󰈔', hl = 'MiniIconsGrey'   },
  file      = { glyph = '󰈔', hl = 'MiniIconsGrey'   },
  filetype  = { glyph = '󰈔', hl = 'MiniIconsGrey'   },
  lsp       = { glyph = '󰞋', hl = 'MiniIconsRed'    },
  os        = { glyph = '󰟀', hl = 'MiniIconsPurple' },
}

-- Directory icons. Keys are some popular *language-agnostic* directory
-- basenames. Use only "folder-shaped" glyphs while prefering `nf-md-folder-*`
-- classes (unless glyph is designed specifically for the directory name)
--stylua: ignore
H.directory_icons = {
  ['.cache']    = { glyph = '󰪺', hl = 'MiniIconsCyan'   },
  ['.config']   = { glyph = '󱁿', hl = 'MiniIconsCyan'   },
  ['.git']      = { glyph = '', hl = 'MiniIconsOrange' },
  ['.github']   = { glyph = '', hl = 'MiniIconsAzure'  },
  ['.local']    = { glyph = '󰉌', hl = 'MiniIconsCyan'   },
  ['.vim']      = { glyph = '󰉋', hl = 'MiniIconsGreen'  },
  AppData       = { glyph = '󰉌', hl = 'MiniIconsOrange' },
  Applications  = { glyph = '󱧺', hl = 'MiniIconsOrange' },
  Desktop       = { glyph = '󰚝', hl = 'MiniIconsOrange' },
  Documents     = { glyph = '󱧶', hl = 'MiniIconsOrange' },
  Downloads     = { glyph = '󰉍', hl = 'MiniIconsOrange' },
  Favorites     = { glyph = '󱃪', hl = 'MiniIconsOrange' },
  Library       = { glyph = '󰲂', hl = 'MiniIconsOrange' },
  Music         = { glyph = '󱍙', hl = 'MiniIconsOrange' },
  Network       = { glyph = '󰡰', hl = 'MiniIconsOrange' },
  Pictures      = { glyph = '󰉏', hl = 'MiniIconsOrange' },
  ProgramData   = { glyph = '󰉌', hl = 'MiniIconsOrange' },
  Public        = { glyph = '󱧰', hl = 'MiniIconsOrange' },
  System        = { glyph = '󱧼', hl = 'MiniIconsOrange' },
  Templates     = { glyph = '󱋣', hl = 'MiniIconsOrange' },
  Trash         = { glyph = '󱧴', hl = 'MiniIconsOrange' },
  Users         = { glyph = '󰉌', hl = 'MiniIconsOrange' },
  Videos        = { glyph = '󱞊', hl = 'MiniIconsOrange' },
  Volumes       = { glyph = '󰉓', hl = 'MiniIconsOrange' },
  bin           = { glyph = '󱧺', hl = 'MiniIconsYellow' },
  build         = { glyph = '󱧼', hl = 'MiniIconsGrey'   },
  boot          = { glyph = '󰴋', hl = 'MiniIconsYellow' },
  dev           = { glyph = '󱧼', hl = 'MiniIconsYellow' },
  doc           = { glyph = '󱂷', hl = 'MiniIconsPurple' },
  docs          = { glyph = '󱂷', hl = 'MiniIconsPurple' },
  etc           = { glyph = '󱁿', hl = 'MiniIconsYellow' },
  home          = { glyph = '󱂵', hl = 'MiniIconsYellow' },
  lib           = { glyph = '󰲂', hl = 'MiniIconsYellow' },
  media         = { glyph = '󱧺', hl = 'MiniIconsYellow' },
  mnt           = { glyph = '󰉓', hl = 'MiniIconsYellow' },
  ['mini.nvim'] = { glyph = '󰚝', hl = 'MiniIconsRed'    },
  node_modules  = { glyph = '', hl = 'MiniIconsGreen'  },
  nvim          = { glyph = '󰉋', hl = 'MiniIconsGreen'  },
  opt           = { glyph = '󰉗', hl = 'MiniIconsYellow' },
  proc          = { glyph = '󰢬', hl = 'MiniIconsYellow' },
  root          = { glyph = '󰷌', hl = 'MiniIconsYellow' },
  sbin          = { glyph = '󱧺', hl = 'MiniIconsYellow' },
  src           = { glyph = '󰴉', hl = 'MiniIconsPurple' },
  srv           = { glyph = '󱋣', hl = 'MiniIconsYellow' },
  tmp           = { glyph = '󰪺', hl = 'MiniIconsYellow' },
  test          = { glyph = '󱞊', hl = 'MiniIconsBlue'   },
  tests         = { glyph = '󱞊', hl = 'MiniIconsBlue'   },
  usr           = { glyph = '󰉌', hl = 'MiniIconsYellow' },
  var           = { glyph = '󱋣', hl = 'MiniIconsYellow' },
}

-- Extension icons
-- Value is string with filetype's name to inherit from its icon data
--stylua: ignore
H.extension_icons = {
  -- Popular extensions associated with supported filetype. Present to not have
  -- to rely on `vim.filetype.match()` thus having better performance. Add only
  -- unambiguously detectable from the extension (allow obvious exceptions on
  -- case by case basis) to allow users to customize with `vim.filetype.add()`.
  bib   = 'bib',
  bzl   = 'bzl',
  c     = 'c',
  cbl   = 'cobol',
  clj   = 'clojure',
  cpp   = 'cpp',
  cs    = 'cs',
  css   = 'css',
  csv   = 'csv',
  cu    = 'cuda',
  dart  = 'dart',
  diff  = 'diff',
  el    = 'lisp',
  elm   = 'elm',
  erl   = 'erlang',
  f90   = 'fortran',
  fish  = 'fish',
  fnl   = 'fennel',
  fs    = 'fsharp',
  go    = 'go',
  hs    = 'haskell',
  htm   = 'html',
  html  = 'html',
  jav   = 'java',
  java  = 'java',
  jl    = 'julia',
  js    = 'javascript',
  json5 = 'json5',
  kt    = 'kotlin',
  latex = 'tex',
  lua   = 'lua',
  md    = 'markdown',
  ml    = 'ocaml',
  mojo  = 'mojo',
  nim   = 'nim',
  nix   = 'nix',
  pdb   = 'prolog',
  pdf   = 'pdf',
  php   = 'php',
  py    = 'python',
  qmd   = 'quarto',
  r     = 'r',
  raku  = 'raku',
  rb    = 'ruby',
  rmd   = 'rmd',
  roc   = 'roc',
  rs    = 'rust',
  rst   = 'rst',
  scala = 'scala',
  sol   = 'solidity',
  srt   = 'srt',
  ss    = 'scheme',
  ssa   = 'ssa',
  svg   = 'svg',
  swift = 'swift',
  ts    = 'typescript',
  tsv   = 'tsv',
  vim   = 'vim',
  vue   = 'vue',
  zig   = 'zig',

  -- Extensions for which `vim.filetype.match()` mismatches or doesn't work.
  -- Usually because matching depends on an actual buffer content.
  h     = { glyph = '󰫵', hl = 'MiniIconsPurple' },
  ipynb = { glyph = '󰠮', hl = 'MiniIconsOrange' },
  exs   = { glyph = '', hl = 'MiniIconsPurple' },
  purs  = 'purescript',
  tf    = 'terraform',

  -- Video
  ['3gp'] = { glyph = '󰈫', hl = 'MiniIconsYellow' },
  avi     = { glyph = '󰈫', hl = 'MiniIconsGrey'   },
  cast    = { glyph = '󰈫', hl = 'MiniIconsRed'    },
  m4v     = { glyph = '󰈫', hl = 'MiniIconsOrange' },
  mkv     = { glyph = '󰈫', hl = 'MiniIconsGreen'  },
  mov     = { glyph = '󰈫', hl = 'MiniIconsCyan'   },
  mp4     = { glyph = '󰈫', hl = 'MiniIconsAzure'  },
  mpeg    = { glyph = '󰈫', hl = 'MiniIconsPurple' },
  mpg     = { glyph = '󰈫', hl = 'MiniIconsPurple' },
  webm    = { glyph = '󰈫', hl = 'MiniIconsGrey'   },
  wmv     = { glyph = '󰈫', hl = 'MiniIconsBlue'   },

  -- Audio
  aac  = { glyph = '󰈣', hl = 'MiniIconsYellow' },
  aif  = { glyph = '󰈣', hl = 'MiniIconsCyan'   },
  flac = { glyph = '󰈣', hl = 'MiniIconsOrange' },
  m4a  = { glyph = '󰈣', hl = 'MiniIconsPurple' },
  mp3  = { glyph = '󰈣', hl = 'MiniIconsAzure'  },
  ogg  = { glyph = '󰈣', hl = 'MiniIconsGrey'   },
  snd  = { glyph = '󰈣', hl = 'MiniIconsRed'    },
  wav  = { glyph = '󰈣', hl = 'MiniIconsGreen'  },
  wma  = { glyph = '󰈣', hl = 'MiniIconsBlue'   },

  -- Image
  bmp  = { glyph = '󰈟', hl = 'MiniIconsGreen'  },
  eps  = { glyph = '', hl = 'MiniIconsRed'    },
  gif  = { glyph = '󰵸', hl = 'MiniIconsAzure'  },
  jpeg = { glyph = '󰈥', hl = 'MiniIconsOrange' },
  jpg  = { glyph = '󰈥', hl = 'MiniIconsOrange' },
  png  = { glyph = '󰸭', hl = 'MiniIconsPurple' },
  tif  = { glyph = '󰈟', hl = 'MiniIconsYellow' },
  tiff = { glyph = '󰈟', hl = 'MiniIconsYellow' },
  webp = { glyph = '󰈟', hl = 'MiniIconsBlue'   },

  -- Archives
  ['7z'] = { glyph = '󰗄', hl = 'MiniIconsBlue'   },
  bz     = { glyph = '󰗄', hl = 'MiniIconsOrange' },
  bz2    = { glyph = '󰗄', hl = 'MiniIconsOrange' },
  bz3    = { glyph = '󰗄', hl = 'MiniIconsOrange' },
  gz     = { glyph = '󰗄', hl = 'MiniIconsGrey'   },
  rar    = { glyph = '󰗄', hl = 'MiniIconsGreen'  },
  rpm    = { glyph = '󰗄', hl = 'MiniIconsRed'    },
  sit    = { glyph = '󰗄', hl = 'MiniIconsRed'    },
  tar    = { glyph = '󰗄', hl = 'MiniIconsCyan'   },
  tgz    = { glyph = '󰗄', hl = 'MiniIconsGrey'   },
  txz    = { glyph = '󰗄', hl = 'MiniIconsPurple' },
  xz     = { glyph = '󰗄', hl = 'MiniIconsGreen'  },
  z      = { glyph = '󰗄', hl = 'MiniIconsGrey'   },
  zip    = { glyph = '󰗄', hl = 'MiniIconsAzure'  },
  zst    = { glyph = '󰗄', hl = 'MiniIconsYellow' },

  -- Software
  doc  = { glyph = '󱎒', hl = 'MiniIconsAzure'  },
  docm = { glyph = '󱎒', hl = 'MiniIconsAzure'  },
  docx = { glyph = '󱎒', hl = 'MiniIconsAzure'  },
  dot  = { glyph = '󱎒', hl = 'MiniIconsAzure'  },
  dotx = { glyph = '󱎒', hl = 'MiniIconsAzure'  },
  exe  = { glyph = '󰖳', hl = 'MiniIconsRed'    },
  pps  = { glyph = '󱎐', hl = 'MiniIconsRed'    },
  ppsm = { glyph = '󱎐', hl = 'MiniIconsRed'    },
  ppsx = { glyph = '󱎐', hl = 'MiniIconsRed'    },
  ppt  = { glyph = '󱎐', hl = 'MiniIconsRed'    },
  pptm = { glyph = '󱎐', hl = 'MiniIconsRed'    },
  pptx = { glyph = '󱎐', hl = 'MiniIconsRed'    },
  xls  = { glyph = '󱎏', hl = 'MiniIconsGreen'  },
  xlsm = { glyph = '󱎏', hl = 'MiniIconsGreen'  },
  xlsx = { glyph = '󱎏', hl = 'MiniIconsGreen'  },
  xlt  = { glyph = '󱎏', hl = 'MiniIconsGreen'  },
  xltm = { glyph = '󱎏', hl = 'MiniIconsGreen'  },
  xltx = { glyph = '󱎏', hl = 'MiniIconsGreen'  },
}

-- File icons. Keys are mostly some popular *language-agnostic* file basenames
-- and the ones which can conflict with icon detection based on extension.
--stylua: ignore
H.file_icons = {
  ['.DS_Store']          = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  ['.bash_profile']      = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  ['.bashrc']            = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  ['.git']               = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  ['.gitlab-ci.yml']     = { glyph = '󰮠', hl = 'MiniIconsOrange' },
  ['.gitkeep']           = { glyph = '󰊢', hl = 'MiniIconsRed'    },
  ['.mailmap']           = { glyph = '󰊢', hl = 'MiniIconsCyan'   },
  ['.npmignore']         = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  ['.nvmrc']             = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  ['.xinitrc']           = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  ['.zshrc']             = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  CHANGELOG              = { glyph = '󰉻', hl = 'MiniIconsBlue'   },
  ['CHANGELOG.md']       = { glyph = '󰉻', hl = 'MiniIconsBlue'   },
  CODE_OF_CONDUCT        = { glyph = '󱃱', hl = 'MiniIconsRed'    },
  ['CODE_OF_CONDUCT.md'] = { glyph = '󱃱', hl = 'MiniIconsRed'    },
  CODEOWNERS             = { glyph = '󰜻', hl = 'MiniIconsPurple' },
  CONTRIBUTING           = { glyph = '󰺾', hl = 'MiniIconsAzure'  },
  ['CONTRIBUTING.md']    = { glyph = '󰺾', hl = 'MiniIconsAzure'  },
  ['FUNDING.yml']        = { glyph = '󰇁', hl = 'MiniIconsGreen'  },
  LICENSE                = { glyph = '', hl = 'MiniIconsCyan'   },
  ['LICENSE.md']         = { glyph = '', hl = 'MiniIconsCyan'   },
  ['LICENSE.txt']        = { glyph = '', hl = 'MiniIconsCyan'   },
  NEWS                   = { glyph = '󰎕', hl = 'MiniIconsBlue'   },
  ['NEWS.md']            = { glyph = '󰎕', hl = 'MiniIconsBlue'   },
  PKGBUILD               = { glyph = '󱁤', hl = 'MiniIconsPurple' },
  README                 = { glyph = '', hl = 'MiniIconsYellow' },
  ['README.md']          = { glyph = '', hl = 'MiniIconsYellow' },
  ['README.txt']         = { glyph = '', hl = 'MiniIconsYellow' },
  TODO                   = { glyph = '󰝖', hl = 'MiniIconsPurple' },
  ['TODO.md']            = { glyph = '󰝖', hl = 'MiniIconsPurple' },
  ['init.lua']           = { glyph = '', hl = 'MiniIconsGreen'  },
}

-- Filetype icons. Keys are filetypes explicitly supported by Neovim core
-- (i.e. present in `getcompletion('', 'filetype')` except technical ones)
-- and filetypes from some popular plugins.
-- Rough process of how glyphs and icons are chosen:
-- - Try to balance usage of highlight groups.
-- - Prefer using the following Nerd Fonts classes (from best to worst):
--     - `nf-md-*` (UTF codes seem to be more thought through). It is also
--       correctly has double width in Kitty.
--     - `nf-dev-*` (more supported devicons).
--     - `nf-seti-*` (more up to date extensions).
-- - If filetype is present in 'nvim-web-devicons', use highlight group with
--   most similar hue (based on OKLCH color space with equally spaced grid as
--   in 'mini.hues' and chroma=3 for grey cutoff; adjust manually if needed).
-- - Sets that have same/close glyphs but maybe different highlights:
--     - Generic configuration filetypes (".*conf.*", ".*rc", if stated in
--       filetype file description, etc.) have same glyph.
--     - Similar language: assembly ("asm"), SQL, Perl, HTML, CSV, shell.
--     - Log files.
--     - Make / build system.
--     - Related to Internet/Web.
-- - For newly assigned icons use semantically close (first by filetype origin,
--   then by name) abstract icons with `nf-md-*` Nerd Fonts class.
-- - If no semantically close abstract icon present, use plain letter/digit
--   icon (based on the first filetype character) with highlight groups picked
--   randomly to achieve overall balance (trying to minimize maximum number of
--   glyph-hl duplicates).
--stylua: ignore
H.filetype_icons = {
  -- Neovim filetype plugins (i.e. recognized with vanilla Neovim)
  ['8th']            = { glyph = '󰭁', hl = 'MiniIconsYellow' },
  a2ps               = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  a65                = { glyph = '', hl = 'MiniIconsRed'    },
  aap                = { glyph = '󰫮', hl = 'MiniIconsOrange' },
  abap               = { glyph = '󰫮', hl = 'MiniIconsGreen'  },
  abaqus             = { glyph = '󰫮', hl = 'MiniIconsGreen'  },
  abc                = { glyph = '󰝚', hl = 'MiniIconsAzure'  },
  abel               = { glyph = '󰫮', hl = 'MiniIconsAzure'  },
  acedb              = { glyph = '󰆼', hl = 'MiniIconsGrey'   },
  ada                = { glyph = '󱁷', hl = 'MiniIconsAzure'  },
  aflex              = { glyph = '󰫮', hl = 'MiniIconsCyan'   },
  ahdl               = { glyph = '󰫮', hl = 'MiniIconsRed'    },
  aidl               = { glyph = '󰫮', hl = 'MiniIconsYellow' },
  alsaconf           = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  amiga              = { glyph = '󰫮', hl = 'MiniIconsCyan'   },
  aml                = { glyph = '󰫮', hl = 'MiniIconsPurple' },
  ampl               = { glyph = '󰫮', hl = 'MiniIconsOrange' },
  ant                = { glyph = '󰫮', hl = 'MiniIconsRed'    },
  antlr              = { glyph = '󰫮', hl = 'MiniIconsCyan'   },
  apache             = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  apachestyle        = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  aptconf            = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  arch               = { glyph = '󰣇', hl = 'MiniIconsBlue'   },
  arduino            = { glyph = '', hl = 'MiniIconsAzure'  },
  art                = { glyph = '󰫮', hl = 'MiniIconsPurple' },
  asciidoc           = { glyph = '󰪶', hl = 'MiniIconsYellow' },
  asm                = { glyph = '', hl = 'MiniIconsPurple' },
  asm68k             = { glyph = '', hl = 'MiniIconsRed'    },
  asmh8300           = { glyph = '', hl = 'MiniIconsOrange' },
  asn                = { glyph = '󰫮', hl = 'MiniIconsBlue'   },
  aspperl            = { glyph = '', hl = 'MiniIconsBlue'   },
  aspvbs             = { glyph = '󰫮', hl = 'MiniIconsGreen'  },
  asterisk           = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  asteriskvm         = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  astro              = { glyph = '', hl = 'MiniIconsOrange' },
  atlas              = { glyph = '󰫮', hl = 'MiniIconsAzure'  },
  autodoc            = { glyph = '󰪶', hl = 'MiniIconsGreen'  },
  autohotkey         = { glyph = '󰫮', hl = 'MiniIconsYellow' },
  autoit             = { glyph = '󰫮', hl = 'MiniIconsCyan'   },
  automake           = { glyph = '󱁤', hl = 'MiniIconsPurple' },
  ave                = { glyph = '󰫮', hl = 'MiniIconsGrey'   },
  avra               = { glyph = '', hl = 'MiniIconsPurple' },
  awk                = { glyph = '', hl = 'MiniIconsGrey'   },
  ayacc              = { glyph = '󰫮', hl = 'MiniIconsCyan'   },
  b                  = { glyph = '󰫯', hl = 'MiniIconsYellow' },
  baan               = { glyph = '󰫯', hl = 'MiniIconsOrange' },
  bash               = { glyph = '', hl = 'MiniIconsGreen'  },
  basic              = { glyph = '󰫯', hl = 'MiniIconsPurple' },
  bc                 = { glyph = '󰫯', hl = 'MiniIconsCyan'   },
  bdf                = { glyph = '󰛖', hl = 'MiniIconsRed'    },
  bib                = { glyph = '󱉟', hl = 'MiniIconsYellow' },
  bicep              = { glyph = '', hl = 'MiniIconsCyan'   },
  bicepparam         = { glyph = '', hl = 'MiniIconsPurple' },
  bindzone           = { glyph = '󰫯', hl = 'MiniIconsCyan'   },
  bitbake            = { glyph = '󰃫', hl = 'MiniIconsOrange' },
  blank              = { glyph = '󰫯', hl = 'MiniIconsPurple' },
  bp                 = { glyph = '󰫯', hl = 'MiniIconsYellow' },
  bsdl               = { glyph = '󰫯', hl = 'MiniIconsPurple' },
  bst                = { glyph = '󰫯', hl = 'MiniIconsCyan'   },
  btm                = { glyph = '󰫯', hl = 'MiniIconsGreen'  },
  bzl                = { glyph = '', hl = 'MiniIconsGreen'  },
  bzr                = { glyph = '󰜘', hl = 'MiniIconsRed'    },
  c                  = { glyph = '󰙱', hl = 'MiniIconsBlue'   },
  cabal              = { glyph = '󰲒', hl = 'MiniIconsBlue'   },
  cabalconfig        = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  cabalproject       = { glyph = '󰫰', hl = 'MiniIconsBlue'   },
  calendar           = { glyph = '󰃵', hl = 'MiniIconsRed'    },
  catalog            = { glyph = '󰕲', hl = 'MiniIconsGrey'   },
  cdl                = { glyph = '󰫰', hl = 'MiniIconsOrange' },
  cdrdaoconf         = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  cdrtoc             = { glyph = '󰠶', hl = 'MiniIconsRed'    },
  cf                 = { glyph = '󰫰', hl = 'MiniIconsRed'    },
  cfg                = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  cgdbrc             = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  ch                 = { glyph = '󰫰', hl = 'MiniIconsCyan'   },
  chaiscript         = { glyph = '󰶞', hl = 'MiniIconsOrange' },
  change             = { glyph = '󰹳', hl = 'MiniIconsYellow' },
  changelog          = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  chaskell           = { glyph = '󰲒', hl = 'MiniIconsGreen'  },
  chatito            = { glyph = '󰫰', hl = 'MiniIconsCyan'   },
  checkhealth        = { glyph = '󰓙', hl = 'MiniIconsBlue'   },
  cheetah            = { glyph = '󰫰', hl = 'MiniIconsGrey'   },
  chicken            = { glyph = '󰫰', hl = 'MiniIconsRed'    },
  chill              = { glyph = '󰫰', hl = 'MiniIconsBlue'   },
  chordpro           = { glyph = '󰫰', hl = 'MiniIconsGreen'  },
  chuck              = { glyph = '󰫰', hl = 'MiniIconsBlue'   },
  cl                 = { glyph = '󰫰', hl = 'MiniIconsCyan'   },
  clean              = { glyph = '󰫰', hl = 'MiniIconsBlue'   },
  clipper            = { glyph = '󰫰', hl = 'MiniIconsPurple' },
  clojure            = { glyph = '', hl = 'MiniIconsGreen'  },
  cmake              = { glyph = '󱁤', hl = 'MiniIconsOrange' },
  cmakecache         = { glyph = '󱁤', hl = 'MiniIconsRed'    },
  cmod               = { glyph = '󰫰', hl = 'MiniIconsCyan'   },
  cmusrc             = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  cobol              = { glyph = '󱌼', hl = 'MiniIconsBlue'   },
  coco               = { glyph = '󰫰', hl = 'MiniIconsRed'    },
  conaryrecipe       = { glyph = '󰫰', hl = 'MiniIconsGrey'   },
  conf               = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  config             = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  confini            = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  context            = { glyph = '', hl = 'MiniIconsGreen'  },
  corn               = { glyph = '󰞸', hl = 'MiniIconsYellow' },
  cpp                = { glyph = '󰙲', hl = 'MiniIconsAzure'  },
  crm                = { glyph = '󰫰', hl = 'MiniIconsGreen'  },
  crontab            = { glyph = '󰔠', hl = 'MiniIconsAzure'  },
  cs                 = { glyph = '󰌛', hl = 'MiniIconsGreen'  },
  csc                = { glyph = '󰫰', hl = 'MiniIconsBlue'   },
  csdl               = { glyph = '󰫰', hl = 'MiniIconsCyan'   },
  csh                = { glyph = '', hl = 'MiniIconsGrey'   },
  csp                = { glyph = '󰫰', hl = 'MiniIconsAzure'  },
  css                = { glyph = '󰌜', hl = 'MiniIconsAzure'  },
  csv                = { glyph = '', hl = 'MiniIconsGreen'  },
  csv_pipe           = { glyph = '', hl = 'MiniIconsAzure'  },
  csv_semicolon      = { glyph = '', hl = 'MiniIconsRed'    },
  csv_whitespace     = { glyph = '', hl = 'MiniIconsPurple' },
  cterm              = { glyph = '󰫰', hl = 'MiniIconsCyan'   },
  ctrlh              = { glyph = '󰫰', hl = 'MiniIconsOrange' },
  cucumber           = { glyph = '󰫰', hl = 'MiniIconsPurple' },
  cuda               = { glyph = '', hl = 'MiniIconsGreen'  },
  cupl               = { glyph = '󰫰', hl = 'MiniIconsOrange' },
  cuplsim            = { glyph = '󰫰', hl = 'MiniIconsPurple' },
  cvs                = { glyph = '󰜘', hl = 'MiniIconsGreen'  },
  cvsrc              = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  cweb               = { glyph = '󰫰', hl = 'MiniIconsCyan'   },
  cynlib             = { glyph = '󰙲', hl = 'MiniIconsPurple' },
  cynpp              = { glyph = '󰙲', hl = 'MiniIconsYellow' },
  d                  = { glyph = '', hl = 'MiniIconsGreen'  },
  dart               = { glyph = '', hl = 'MiniIconsBlue'   },
  datascript         = { glyph = '󰫱', hl = 'MiniIconsGreen'  },
  dcd                = { glyph = '󰫱', hl = 'MiniIconsCyan'   },
  dcl                = { glyph = '󰫱', hl = 'MiniIconsAzure'  },
  deb822sources      = { glyph = '󰫱', hl = 'MiniIconsCyan'   },
  debchangelog       = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  debcontrol         = { glyph = '󰫱', hl = 'MiniIconsOrange' },
  debcopyright       = { glyph = '', hl = 'MiniIconsRed'    },
  debsources         = { glyph = '󰫱', hl = 'MiniIconsYellow' },
  def                = { glyph = '󰫱', hl = 'MiniIconsGrey'   },
  denyhosts          = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  dep3patch          = { glyph = '󰫱', hl = 'MiniIconsCyan'   },
  desc               = { glyph = '󰫱', hl = 'MiniIconsCyan'   },
  desktop            = { glyph = '󰍹', hl = 'MiniIconsPurple' },
  dictconf           = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  dictdconf          = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  diff               = { glyph = '󰦓', hl = 'MiniIconsRed'    },
  dircolors          = { glyph = '󰫱', hl = 'MiniIconsRed'    },
  dirpager           = { glyph = '󰙅', hl = 'MiniIconsYellow' },
  diva               = { glyph = '󰫱', hl = 'MiniIconsRed'    },
  django             = { glyph = '', hl = 'MiniIconsGreen'  },
  dns                = { glyph = '󰫱', hl = 'MiniIconsOrange' },
  dnsmasq            = { glyph = '󰫱', hl = 'MiniIconsGrey'   },
  docbk              = { glyph = '󰫱', hl = 'MiniIconsYellow' },
  docbksgml          = { glyph = '󰫱', hl = 'MiniIconsGrey'   },
  docbkxml           = { glyph = '󰫱', hl = 'MiniIconsGrey'   },
  dockerfile         = { glyph = '󰡨', hl = 'MiniIconsBlue'   },
  dosbatch           = { glyph = '󰯂', hl = 'MiniIconsGreen'  },
  dosini             = { glyph = '󰯂', hl = 'MiniIconsAzure'  },
  dot                = { glyph = '󱁉', hl = 'MiniIconsAzure'  },
  doxygen            = { glyph = '󰋘', hl = 'MiniIconsBlue'   },
  dracula            = { glyph = '󰭟', hl = 'MiniIconsGrey'   },
  dsl                = { glyph = '󰫱', hl = 'MiniIconsAzure'  },
  dtd                = { glyph = '󰫱', hl = 'MiniIconsCyan'   },
  dtml               = { glyph = '󰫱', hl = 'MiniIconsRed'    },
  dtrace             = { glyph = '󰫱', hl = 'MiniIconsRed'    },
  dts                = { glyph = '󰫱', hl = 'MiniIconsRed'    },
  dune               = { glyph = '', hl = 'MiniIconsGreen'  },
  dylan              = { glyph = '󰫱', hl = 'MiniIconsRed'    },
  dylanintr          = { glyph = '󰫱', hl = 'MiniIconsGrey'   },
  dylanlid           = { glyph = '󰫱', hl = 'MiniIconsOrange' },
  ecd                = { glyph = '󰫲', hl = 'MiniIconsPurple' },
  edif               = { glyph = '󰫲', hl = 'MiniIconsCyan'   },
  editorconfig       = { glyph = '', hl = 'MiniIconsGrey'   },
  eiffel             = { glyph = '󱕫', hl = 'MiniIconsYellow' },
  elf                = { glyph = '󰫲', hl = 'MiniIconsGreen'  },
  elinks             = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  elixir             = { glyph = '', hl = 'MiniIconsPurple' },
  elm                = { glyph = '', hl = 'MiniIconsAzure'  },
  elmfilt            = { glyph = '󰫲', hl = 'MiniIconsBlue'   },
  erlang             = { glyph = '', hl = 'MiniIconsRed'    },
  eruby              = { glyph = '󰴭', hl = 'MiniIconsOrange' },
  esmtprc            = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  esqlc              = { glyph = '󰆼', hl = 'MiniIconsGrey'   },
  esterel            = { glyph = '󰫲', hl = 'MiniIconsAzure'  },
  eterm              = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  euphoria3          = { glyph = '󰫲', hl = 'MiniIconsRed'    },
  euphoria4          = { glyph = '󰫲', hl = 'MiniIconsYellow' },
  eviews             = { glyph = '󰫲', hl = 'MiniIconsCyan'   },
  exim               = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  expect             = { glyph = '󰫲', hl = 'MiniIconsGrey'   },
  exports            = { glyph = '󰈇', hl = 'MiniIconsPurple' },
  falcon             = { glyph = '󱗆', hl = 'MiniIconsOrange' },
  fan                = { glyph = '󰫳', hl = 'MiniIconsAzure'  },
  fasm               = { glyph = '', hl = 'MiniIconsPurple' },
  fdcc               = { glyph = '󰫳', hl = 'MiniIconsBlue'   },
  fennel             = { glyph = '', hl = 'MiniIconsYellow' },
  fetchmail          = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  fgl                = { glyph = '󰫳', hl = 'MiniIconsCyan'   },
  fish               = { glyph = '', hl = 'MiniIconsGrey'   },
  flexwiki           = { glyph = '󰖬', hl = 'MiniIconsPurple' },
  focexec            = { glyph = '󰫳', hl = 'MiniIconsPurple' },
  form               = { glyph = '󰫳', hl = 'MiniIconsCyan'   },
  forth              = { glyph = '󰬽', hl = 'MiniIconsRed'    },
  fortran            = { glyph = '󱈚', hl = 'MiniIconsPurple' },
  foxpro             = { glyph = '󰫳', hl = 'MiniIconsGreen'  },
  fpcmake            = { glyph = '󱁤', hl = 'MiniIconsRed'    },
  framescript        = { glyph = '󰫳', hl = 'MiniIconsCyan'   },
  freebasic          = { glyph = '󰫳', hl = 'MiniIconsOrange' },
  fsharp             = { glyph = '', hl = 'MiniIconsBlue'   },
  fstab              = { glyph = '󰋊', hl = 'MiniIconsGrey'   },
  fvwm               = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  fvwm2m4            = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  gdb                = { glyph = '󰈺', hl = 'MiniIconsGrey'   },
  gdmo               = { glyph = '󰫴', hl = 'MiniIconsBlue'   },
  gdresource         = { glyph = '', hl = 'MiniIconsGreen'  },
  gdscript           = { glyph = '', hl = 'MiniIconsYellow' },
  gdshader           = { glyph = '', hl = 'MiniIconsPurple' },
  gedcom             = { glyph = '󰫴', hl = 'MiniIconsRed'    },
  gemtext            = { glyph = '󰪁', hl = 'MiniIconsAzure'  },
  gift               = { glyph = '󰹄', hl = 'MiniIconsRed'    },
  git                = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  gitattributes      = { glyph = '󰊢', hl = 'MiniIconsYellow' },
  gitcommit          = { glyph = '󰊢', hl = 'MiniIconsGreen'  },
  gitconfig          = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  gitignore          = { glyph = '󰊢', hl = 'MiniIconsPurple' },
  gitolite           = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  gitrebase          = { glyph = '󰊢', hl = 'MiniIconsAzure'  },
  gitsendemail       = { glyph = '󰊢', hl = 'MiniIconsBlue'   },
  gkrellmrc          = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  gnash              = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  gnuplot            = { glyph = '󰺒', hl = 'MiniIconsPurple' },
  go                 = { glyph = '󰟓', hl = 'MiniIconsAzure'  },
  godoc              = { glyph = '󰟓', hl = 'MiniIconsOrange' },
  gomod              = { glyph = '󰟓', hl = 'MiniIconsAzure'  },
  gosum              = { glyph = '󰟓', hl = 'MiniIconsCyan'   },
  gp                 = { glyph = '󰫴', hl = 'MiniIconsCyan'   },
  gpg                = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  gprof              = { glyph = '󰫴', hl = 'MiniIconsAzure'  },
  grads              = { glyph = '󰫴', hl = 'MiniIconsPurple' },
  graphql            = { glyph = '󰡷', hl = 'MiniIconsRed'    },
  gretl              = { glyph = '󰫴', hl = 'MiniIconsCyan'   },
  groff              = { glyph = '󰫴', hl = 'MiniIconsYellow' },
  groovy             = { glyph = '', hl = 'MiniIconsAzure'  },
  group              = { glyph = '󰫴', hl = 'MiniIconsCyan'   },
  grub               = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  gsp                = { glyph = '󰫴', hl = 'MiniIconsYellow' },
  gtkrc              = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  gvpr               = { glyph = '󰫴', hl = 'MiniIconsBlue'   },
  gyp                = { glyph = '󰫴', hl = 'MiniIconsPurple' },
  haml               = { glyph = '󰅴', hl = 'MiniIconsGrey'   },
  hamster            = { glyph = '󰫵', hl = 'MiniIconsCyan'   },
  hare               = { glyph = '󰫵', hl = 'MiniIconsRed'    },
  haredoc            = { glyph = '󰪶', hl = 'MiniIconsGrey'   },
  haskell            = { glyph = '󰲒', hl = 'MiniIconsPurple' },
  haste              = { glyph = '󰫵', hl = 'MiniIconsYellow' },
  hastepreproc       = { glyph = '󰫵', hl = 'MiniIconsCyan'   },
  hb                 = { glyph = '󰫵', hl = 'MiniIconsGreen'  },
  hcl                = { glyph = '󰫵', hl = 'MiniIconsAzure'  },
  heex               = { glyph = '', hl = 'MiniIconsPurple' },
  help               = { glyph = '󰋖', hl = 'MiniIconsPurple' },
  hercules           = { glyph = '󰫵', hl = 'MiniIconsRed'    },
  hex                = { glyph = '󰋘', hl = 'MiniIconsYellow' },
  hgcommit           = { glyph = '󰜘', hl = 'MiniIconsGrey'   },
  hlsplaylist        = { glyph = '󰲸', hl = 'MiniIconsOrange' },
  hog                = { glyph = '󰫵', hl = 'MiniIconsOrange' },
  hollywood          = { glyph = '󰓎', hl = 'MiniIconsYellow' },
  hostconf           = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  hostsaccess        = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  html               = { glyph = '󰌝', hl = 'MiniIconsOrange' },
  htmlcheetah        = { glyph = '󰌝', hl = 'MiniIconsYellow' },
  htmldjango         = { glyph = '󰌝', hl = 'MiniIconsGreen'  },
  htmlm4             = { glyph = '󰌝', hl = 'MiniIconsRed'    },
  htmlos             = { glyph = '󰌝', hl = 'MiniIconsAzure'  },
  hurl               = { glyph = '󰫵', hl = 'MiniIconsGreen'  },
  hyprlang           = { glyph = '', hl = 'MiniIconsCyan'   },
  i3config           = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  ia64               = { glyph = '', hl = 'MiniIconsPurple' },
  ibasic             = { glyph = '󰫶', hl = 'MiniIconsOrange' },
  icemenu            = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  icon               = { glyph = '󰫶', hl = 'MiniIconsGreen'  },
  idl                = { glyph = '󰫶', hl = 'MiniIconsRed'    },
  idlang             = { glyph = '󱗿', hl = 'MiniIconsAzure'  },
  inform             = { glyph = '󰫶', hl = 'MiniIconsOrange' },
  initex             = { glyph = '', hl = 'MiniIconsGreen'  },
  initng             = { glyph = '󰫶', hl = 'MiniIconsAzure'  },
  inittab            = { glyph = '󰫶', hl = 'MiniIconsBlue'   },
  ipfilter           = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  ishd               = { glyph = '󰫶', hl = 'MiniIconsYellow' },
  iss                = { glyph = '󰏗', hl = 'MiniIconsBlue'   },
  ist                = { glyph = '󰫶', hl = 'MiniIconsCyan'   },
  j                  = { glyph = '󰫷', hl = 'MiniIconsAzure'  },
  jal                = { glyph = '󰫷', hl = 'MiniIconsCyan'   },
  jam                = { glyph = '󰫷', hl = 'MiniIconsCyan'   },
  jargon             = { glyph = '󰫷', hl = 'MiniIconsCyan'   },
  java               = { glyph = '󰬷', hl = 'MiniIconsOrange' },
  javacc             = { glyph = '󰬷', hl = 'MiniIconsRed'    },
  javascript         = { glyph = '󰌞', hl = 'MiniIconsYellow' },
  javascriptreact    = { glyph = '', hl = 'MiniIconsAzure'  },
  jess               = { glyph = '󰫷', hl = 'MiniIconsPurple' },
  jgraph             = { glyph = '󰫷', hl = 'MiniIconsGrey'   },
  jj                 = { glyph = '󱨎', hl = 'MiniIconsYellow' },
  jovial             = { glyph = '󰫷', hl = 'MiniIconsGrey'   },
  jproperties        = { glyph = '󰬷', hl = 'MiniIconsGreen'  },
  jq                 = { glyph = '󰘦', hl = 'MiniIconsBlue'   },
  json               = { glyph = '󰘦', hl = 'MiniIconsYellow' },
  json5              = { glyph = '󰘦', hl = 'MiniIconsOrange' },
  jsonc              = { glyph = '󰘦', hl = 'MiniIconsYellow' },
  jsonnet            = { glyph = '󰫷', hl = 'MiniIconsYellow' },
  jsp                = { glyph = '󰫷', hl = 'MiniIconsAzure'  },
  julia              = { glyph = '', hl = 'MiniIconsPurple' },
  just               = { glyph = '󰖷', hl = 'MiniIconsOrange' },
  kconfig            = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  kivy               = { glyph = '󰫸', hl = 'MiniIconsBlue'   },
  kix                = { glyph = '󰫸', hl = 'MiniIconsRed'    },
  kotlin             = { glyph = '󱈙', hl = 'MiniIconsBlue'   },
  krl                = { glyph = '󰚩', hl = 'MiniIconsGrey'   },
  kscript            = { glyph = '󰫸', hl = 'MiniIconsGrey'   },
  kwt                = { glyph = '󰫸', hl = 'MiniIconsOrange' },
  lace               = { glyph = '󰫹', hl = 'MiniIconsCyan'   },
  latte              = { glyph = '󰅶', hl = 'MiniIconsOrange' },
  lc                 = { glyph = '󰫹', hl = 'MiniIconsRed'    },
  ld                 = { glyph = '󰫹', hl = 'MiniIconsPurple' },
  ldapconf           = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  ldif               = { glyph = '󰫹', hl = 'MiniIconsPurple' },
  less               = { glyph = '󰌜', hl = 'MiniIconsPurple' },
  lex                = { glyph = '󰫹', hl = 'MiniIconsOrange' },
  lftp               = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  lhaskell           = { glyph = '', hl = 'MiniIconsPurple' },
  libao              = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  lifelines          = { glyph = '󰫹', hl = 'MiniIconsCyan'   },
  lilo               = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  limits             = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  liquid             = { glyph = '', hl = 'MiniIconsGreen'  },
  lisp               = { glyph = '', hl = 'MiniIconsGrey'   },
  lite               = { glyph = '󰫹', hl = 'MiniIconsCyan'   },
  litestep           = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  livebook           = { glyph = '󰂾', hl = 'MiniIconsGreen'  },
  logcheck           = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  loginaccess        = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  logindefs          = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  logtalk            = { glyph = '󰫹', hl = 'MiniIconsOrange' },
  lotos              = { glyph = '󰫹', hl = 'MiniIconsYellow' },
  lout               = { glyph = '󰫹', hl = 'MiniIconsCyan'   },
  lpc                = { glyph = '󰫹', hl = 'MiniIconsGrey'   },
  lprolog            = { glyph = '󰘧', hl = 'MiniIconsOrange' },
  lscript            = { glyph = '󰫹', hl = 'MiniIconsCyan'   },
  lsl                = { glyph = '󰫹', hl = 'MiniIconsYellow' },
  lsp_markdown       = { glyph = '󰍔', hl = 'MiniIconsGrey'   },
  lss                = { glyph = '󰫹', hl = 'MiniIconsAzure'  },
  lua                = { glyph = '󰢱', hl = 'MiniIconsAzure'  },
  luau               = { glyph = '󰢱', hl = 'MiniIconsGreen'  },
  lynx               = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  lyrics             = { glyph = '󰫹', hl = 'MiniIconsOrange' },
  m3build            = { glyph = '󰫺', hl = 'MiniIconsGrey'   },
  m3quake            = { glyph = '󰫺', hl = 'MiniIconsGreen'  },
  m4                 = { glyph = '󰫺', hl = 'MiniIconsYellow' },
  mail               = { glyph = '󰇮', hl = 'MiniIconsRed'    },
  mailaliases        = { glyph = '󰇮', hl = 'MiniIconsOrange' },
  mailcap            = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  make               = { glyph = '󱁤', hl = 'MiniIconsGrey'   },
  mallard            = { glyph = '󰫺', hl = 'MiniIconsGrey'   },
  man                = { glyph = '󰗚', hl = 'MiniIconsYellow' },
  manconf            = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  manual             = { glyph = '󰗚', hl = 'MiniIconsYellow' },
  maple              = { glyph = '󰲓', hl = 'MiniIconsRed'    },
  markdown           = { glyph = '󰍔', hl = 'MiniIconsGrey'   },
  masm               = { glyph = '', hl = 'MiniIconsPurple' },
  master             = { glyph = '󰫺', hl = 'MiniIconsOrange' },
  matlab             = { glyph = '󰿈', hl = 'MiniIconsOrange' },
  maxima             = { glyph = '󰫺', hl = 'MiniIconsGrey'   },
  mel                = { glyph = '󰫺', hl = 'MiniIconsAzure'  },
  mermaid            = { glyph = '󰫺', hl = 'MiniIconsCyan'   },
  meson              = { glyph = '󰫺', hl = 'MiniIconsBlue'   },
  messages           = { glyph = '󰍡', hl = 'MiniIconsBlue'   },
  mf                 = { glyph = '󰫺', hl = 'MiniIconsCyan'   },
  mgl                = { glyph = '󰫺', hl = 'MiniIconsCyan'   },
  mgp                = { glyph = '󰫺', hl = 'MiniIconsAzure'  },
  mib                = { glyph = '󰫺', hl = 'MiniIconsCyan'   },
  mix                = { glyph = '󰫺', hl = 'MiniIconsRed'    },
  mma                = { glyph = '󰘨', hl = 'MiniIconsAzure'  },
  mmix               = { glyph = '󰫺', hl = 'MiniIconsRed'    },
  mmp                = { glyph = '󰫺', hl = 'MiniIconsGrey'   },
  modconf            = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  model              = { glyph = '󰫺', hl = 'MiniIconsGreen'  },
  modsim3            = { glyph = '󰫺', hl = 'MiniIconsCyan'   },
  modula2            = { glyph = '󰫺', hl = 'MiniIconsOrange' },
  modula3            = { glyph = '󰫺', hl = 'MiniIconsRed'    },
  mojo               = { glyph = '󰈸', hl = 'MiniIconsRed'    },
  monk               = { glyph = '󰫺', hl = 'MiniIconsCyan'   },
  moo                = { glyph = '󰫺', hl = 'MiniIconsYellow' },
  mp                 = { glyph = '󰫺', hl = 'MiniIconsAzure'  },
  mplayerconf        = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  mrxvtrc            = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  msidl              = { glyph = '󰫺', hl = 'MiniIconsPurple' },
  msmessages         = { glyph = '󰍡', hl = 'MiniIconsAzure'  },
  msql               = { glyph = '󰆼', hl = 'MiniIconsGrey'   },
  mupad              = { glyph = '󰫺', hl = 'MiniIconsCyan'   },
  murphi             = { glyph = '󰫺', hl = 'MiniIconsAzure'  },
  mush               = { glyph = '󰫺', hl = 'MiniIconsPurple' },
  muttrc             = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  mysql              = { glyph = '󰆼', hl = 'MiniIconsOrange' },
  n1ql               = { glyph = '󰫻', hl = 'MiniIconsYellow' },
  named              = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  nanorc             = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  nasm               = { glyph = '', hl = 'MiniIconsPurple' },
  nastran            = { glyph = '󰫻', hl = 'MiniIconsRed'    },
  natural            = { glyph = '󰫻', hl = 'MiniIconsBlue'   },
  ncf                = { glyph = '󰫻', hl = 'MiniIconsYellow' },
  neomuttrc          = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  netrc              = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  netrw              = { glyph = '󰙅', hl = 'MiniIconsBlue'   },
  nginx              = { glyph = '󰰓', hl = 'MiniIconsGreen'  },
  nim                = { glyph = '', hl = 'MiniIconsYellow' },
  ninja              = { glyph = '󰝴', hl = 'MiniIconsGrey'   },
  nix                = { glyph = '󱄅', hl = 'MiniIconsAzure'  },
  nqc                = { glyph = '󱊈', hl = 'MiniIconsYellow' },
  nroff              = { glyph = '󰫻', hl = 'MiniIconsCyan'   },
  nsis               = { glyph = '󰫻', hl = 'MiniIconsAzure'  },
  obj                = { glyph = '󰆧', hl = 'MiniIconsGrey'   },
  objc               = { glyph = '󰀵', hl = 'MiniIconsOrange' },
  objcpp             = { glyph = '󰀵', hl = 'MiniIconsOrange' },
  objdump            = { glyph = '󰫼', hl = 'MiniIconsCyan'   },
  obse               = { glyph = '󰫼', hl = 'MiniIconsBlue'   },
  ocaml              = { glyph = '', hl = 'MiniIconsOrange' },
  occam              = { glyph = '󱦗', hl = 'MiniIconsGrey'   },
  octave             = { glyph = '󱥸', hl = 'MiniIconsBlue'   },
  odin               = { glyph = '󰮔', hl = 'MiniIconsBlue'   },
  omnimark           = { glyph = '󰫼', hl = 'MiniIconsPurple' },
  ondir              = { glyph = '󰫼', hl = 'MiniIconsCyan'   },
  opam               = { glyph = '󰫼', hl = 'MiniIconsBlue'   },
  openroad           = { glyph = '󰫼', hl = 'MiniIconsOrange' },
  openscad           = { glyph = '', hl = 'MiniIconsYellow' },
  openvpn            = { glyph = '󰖂', hl = 'MiniIconsPurple' },
  opl                = { glyph = '󰫼', hl = 'MiniIconsPurple' },
  ora                = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  org                = { glyph = '', hl = 'MiniIconsCyan'   },
  pacmanlog          = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  pamconf            = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  pamenv             = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  pandoc             = { glyph = '󰍔', hl = 'MiniIconsYellow' },
  papp               = { glyph = '', hl = 'MiniIconsAzure'  },
  pascal             = { glyph = '󱤊', hl = 'MiniIconsRed'    },
  passwd             = { glyph = '󰟵', hl = 'MiniIconsGrey'   },
  pbtxt              = { glyph = '󰈚', hl = 'MiniIconsRed'    },
  pcap               = { glyph = '󰐪', hl = 'MiniIconsRed'    },
  pccts              = { glyph = '󰫽', hl = 'MiniIconsRed'    },
  pdf                = { glyph = '󰈦', hl = 'MiniIconsRed'    },
  perl               = { glyph = '', hl = 'MiniIconsAzure'  },
  pf                 = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  pfmain             = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  php                = { glyph = '󰌟', hl = 'MiniIconsPurple' },
  phtml              = { glyph = '󰌟', hl = 'MiniIconsOrange' },
  pic                = { glyph = '', hl = 'MiniIconsPurple' },
  pike               = { glyph = '󰈺', hl = 'MiniIconsGrey'   },
  pilrc              = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  pine               = { glyph = '󰇮', hl = 'MiniIconsRed'    },
  pinfo              = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  plaintex           = { glyph = '', hl = 'MiniIconsGreen'  },
  pli                = { glyph = '󰫽', hl = 'MiniIconsRed'    },
  plm                = { glyph = '󰫽', hl = 'MiniIconsBlue'   },
  plp                = { glyph = '', hl = 'MiniIconsBlue'   },
  plsql              = { glyph = '󰆼', hl = 'MiniIconsOrange' },
  po                 = { glyph = '󰗊', hl = 'MiniIconsAzure'  },
  pod                = { glyph = '', hl = 'MiniIconsPurple' },
  poefilter          = { glyph = '󰫽', hl = 'MiniIconsAzure'  },
  poke               = { glyph = '󰫽', hl = 'MiniIconsPurple' },
  postscr            = { glyph = '', hl = 'MiniIconsYellow' },
  pov                = { glyph = '󰫽', hl = 'MiniIconsPurple' },
  povini             = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  ppd                = { glyph = '', hl = 'MiniIconsPurple' },
  ppwiz              = { glyph = '󰫽', hl = 'MiniIconsGrey'   },
  prescribe          = { glyph = '󰜆', hl = 'MiniIconsYellow' },
  prisma             = { glyph = '', hl = 'MiniIconsBlue'   },
  privoxy            = { glyph = '󰫽', hl = 'MiniIconsOrange' },
  procmail           = { glyph = '󰇮', hl = 'MiniIconsBlue'   },
  progress           = { glyph = '󰫽', hl = 'MiniIconsGreen'  },
  prolog             = { glyph = '', hl = 'MiniIconsYellow' },
  promela            = { glyph = '󰫽', hl = 'MiniIconsRed'    },
  proto              = { glyph = '', hl = 'MiniIconsRed'    },
  protocols          = { glyph = '󰖟', hl = 'MiniIconsOrange' },
  ps1                = { glyph = '󰨊', hl = 'MiniIconsBlue'   },
  ps1xml             = { glyph = '󰨊', hl = 'MiniIconsAzure'  },
  psf                = { glyph = '󰫽', hl = 'MiniIconsPurple' },
  psl                = { glyph = '󰫽', hl = 'MiniIconsAzure'  },
  ptcap              = { glyph = '󰐪', hl = 'MiniIconsRed'    },
  purescript         = { glyph = '', hl = 'MiniIconsGrey'   },
  purifylog          = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  pymanifest         = { glyph = '󰌠', hl = 'MiniIconsAzure'  },
  pyrex              = { glyph = '󰫽', hl = 'MiniIconsYellow' },
  python             = { glyph = '󰌠', hl = 'MiniIconsYellow' },
  python2            = { glyph = '󰌠', hl = 'MiniIconsGrey'   },
  qb64               = { glyph = '󰫾', hl = 'MiniIconsCyan'   },
  qf                 = { glyph = '󰝖', hl = 'MiniIconsAzure'  },
  qml                = { glyph = '󰫾', hl = 'MiniIconsAzure'  },
  quake              = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  quarto             = { glyph = '󰐗', hl = 'MiniIconsAzure'  },
  query              = { glyph = '󰐅', hl = 'MiniIconsGreen'  },
  r                  = { glyph = '󰟔', hl = 'MiniIconsBlue'   },
  racc               = { glyph = '󰫿', hl = 'MiniIconsYellow' },
  racket             = { glyph = '󰘧', hl = 'MiniIconsRed'    },
  radiance           = { glyph = '󰫿', hl = 'MiniIconsGrey'   },
  raku               = { glyph = '󱖉', hl = 'MiniIconsYellow' },
  raml               = { glyph = '󰫿', hl = 'MiniIconsCyan'   },
  rapid              = { glyph = '󰫿', hl = 'MiniIconsCyan'   },
  rasi               = { glyph = '󰫿', hl = 'MiniIconsOrange' },
  ratpoison          = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  rc                 = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  rcs                = { glyph = '󰫿', hl = 'MiniIconsYellow' },
  rcslog             = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  readline           = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  rebol              = { glyph = '󰫿', hl = 'MiniIconsBlue'   },
  redif              = { glyph = '󰫿', hl = 'MiniIconsOrange' },
  registry           = { glyph = '󰪶', hl = 'MiniIconsRed'    },
  rego               = { glyph = '󰫿', hl = 'MiniIconsPurple' },
  remind             = { glyph = '󰢌', hl = 'MiniIconsPurple' },
  requirements       = { glyph = '󱘎', hl = 'MiniIconsPurple' },
  rescript           = { glyph = '󰫿', hl = 'MiniIconsAzure'  },
  resolv             = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  reva               = { glyph = '󰫿', hl = 'MiniIconsGrey'   },
  rexx               = { glyph = '󰫿', hl = 'MiniIconsGreen'  },
  rfc_csv            = { glyph = '', hl = 'MiniIconsOrange' },
  rfc_semicolon      = { glyph = '', hl = 'MiniIconsRed'    },
  rhelp              = { glyph = '󰟔', hl = 'MiniIconsAzure'  },
  rib                = { glyph = '󰫿', hl = 'MiniIconsGreen'  },
  rmarkdown          = { glyph = '󰍔', hl = 'MiniIconsAzure'  },
  rmd                = { glyph = '󰍔', hl = 'MiniIconsAzure'  },
  rnc                = { glyph = '󰫿', hl = 'MiniIconsGreen'  },
  rng                = { glyph = '󰫿', hl = 'MiniIconsCyan'   },
  rnoweb             = { glyph = '󰟔', hl = 'MiniIconsGreen'  },
  robots             = { glyph = '󰚩', hl = 'MiniIconsGrey'   },
  roc                = { glyph = '󱗆', hl = 'MiniIconsPurple' },
  routeros           = { glyph = '󱂇', hl = 'MiniIconsGrey'   },
  rpcgen             = { glyph = '󰫿', hl = 'MiniIconsCyan'   },
  rpl                = { glyph = '󰫿', hl = 'MiniIconsCyan'   },
  rrst               = { glyph = '󰫿', hl = 'MiniIconsGreen'  },
  rst                = { glyph = '󰊄', hl = 'MiniIconsYellow' },
  rtf                = { glyph = '󰚞', hl = 'MiniIconsAzure'  },
  ruby               = { glyph = '󰴭', hl = 'MiniIconsRed'    },
  rust               = { glyph = '󱘗', hl = 'MiniIconsOrange' },
  samba              = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  sas                = { glyph = '󰱐', hl = 'MiniIconsAzure'  },
  sass               = { glyph = '󰟬', hl = 'MiniIconsRed'    },
  sather             = { glyph = '󰬀', hl = 'MiniIconsAzure'  },
  sbt                = { glyph = '', hl = 'MiniIconsOrange' },
  scala              = { glyph = '', hl = 'MiniIconsRed'    },
  scdoc              = { glyph = '󰪶', hl = 'MiniIconsAzure'  },
  scheme             = { glyph = '󰘧', hl = 'MiniIconsGrey'   },
  scilab             = { glyph = '󰂓', hl = 'MiniIconsYellow' },
  screen             = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  scss               = { glyph = '󰟬', hl = 'MiniIconsRed'    },
  sd                 = { glyph = '󰬀', hl = 'MiniIconsGrey'   },
  sdc                = { glyph = '󰬀', hl = 'MiniIconsGreen'  },
  sdl                = { glyph = '󰬀', hl = 'MiniIconsRed'    },
  sed                = { glyph = '󰟥', hl = 'MiniIconsRed'    },
  sendpr             = { glyph = '󰆨', hl = 'MiniIconsBlue'   },
  sensors            = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  services           = { glyph = '󰖟', hl = 'MiniIconsGreen'  },
  setserial          = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  sexplib            = { glyph = '', hl = 'MiniIconsYellow' },
  sgml               = { glyph = '󰬀', hl = 'MiniIconsRed'    },
  sgmldecl           = { glyph = '󰬀', hl = 'MiniIconsYellow' },
  sgmllnx            = { glyph = '󰬀', hl = 'MiniIconsGrey'   },
  sh                 = { glyph = '', hl = 'MiniIconsGrey'   },
  shada              = { glyph = '󰆼', hl = 'MiniIconsGrey'   },
  sicad              = { glyph = '󰬀', hl = 'MiniIconsPurple' },
  sieve              = { glyph = '󰈲', hl = 'MiniIconsOrange' },
  sil                = { glyph = '󰛥', hl = 'MiniIconsOrange' },
  simula             = { glyph = '󰬀', hl = 'MiniIconsPurple' },
  sinda              = { glyph = '󰬀', hl = 'MiniIconsYellow' },
  sindacmp           = { glyph = '󱒒', hl = 'MiniIconsRed'    },
  sindaout           = { glyph = '󰬀', hl = 'MiniIconsBlue'   },
  sisu               = { glyph = '󰬀', hl = 'MiniIconsCyan'   },
  skill              = { glyph = '󰬀', hl = 'MiniIconsGrey'   },
  sl                 = { glyph = '󰟽', hl = 'MiniIconsRed'    },
  slang              = { glyph = '󰬀', hl = 'MiniIconsYellow' },
  slice              = { glyph = '󰧻', hl = 'MiniIconsGrey'   },
  slint              = { glyph = '󰬀', hl = 'MiniIconsAzure'  },
  slpconf            = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  slpreg             = { glyph = '󰬀', hl = 'MiniIconsCyan'   },
  slpspi             = { glyph = '󰬀', hl = 'MiniIconsPurple' },
  slrnrc             = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  slrnsc             = { glyph = '󰬀', hl = 'MiniIconsCyan'   },
  sm                 = { glyph = '󱃜', hl = 'MiniIconsBlue'   },
  smarty             = { glyph = '', hl = 'MiniIconsYellow' },
  smcl               = { glyph = '󰄨', hl = 'MiniIconsRed'    },
  smil               = { glyph = '󰬀', hl = 'MiniIconsOrange' },
  smith              = { glyph = '󰬀', hl = 'MiniIconsRed'    },
  sml                = { glyph = '󰘧', hl = 'MiniIconsOrange' },
  snnsnet            = { glyph = '󰖟', hl = 'MiniIconsGreen'  },
  snnspat            = { glyph = '󰬀', hl = 'MiniIconsGreen'  },
  snnsres            = { glyph = '󰬀', hl = 'MiniIconsBlue'   },
  snobol4            = { glyph = '󰬀', hl = 'MiniIconsCyan'   },
  solidity           = { glyph = '', hl = 'MiniIconsAzure'  },
  solution           = { glyph = '󰘐', hl = 'MiniIconsBlue'   },
  spec               = { glyph = '', hl = 'MiniIconsBlue'   },
  specman            = { glyph = '󰬀', hl = 'MiniIconsCyan'   },
  spice              = { glyph = '󰬀', hl = 'MiniIconsOrange' },
  splint             = { glyph = '󰙱', hl = 'MiniIconsGreen'  },
  spup               = { glyph = '󰬀', hl = 'MiniIconsOrange' },
  spyce              = { glyph = '󰬀', hl = 'MiniIconsRed'    },
  sql                = { glyph = '󰆼', hl = 'MiniIconsGrey'   },
  sqlanywhere        = { glyph = '󰆼', hl = 'MiniIconsAzure'  },
  sqlforms           = { glyph = '󰆼', hl = 'MiniIconsOrange' },
  sqlhana            = { glyph = '󰆼', hl = 'MiniIconsPurple' },
  sqlinformix        = { glyph = '󰆼', hl = 'MiniIconsBlue'   },
  sqlj               = { glyph = '󰆼', hl = 'MiniIconsGrey'   },
  sqloracle          = { glyph = '󰆼', hl = 'MiniIconsOrange' },
  sqr                = { glyph = '󰬀', hl = 'MiniIconsGrey'   },
  squid              = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  squirrel           = { glyph = '', hl = 'MiniIconsGrey'   },
  srec               = { glyph = '󰍛', hl = 'MiniIconsAzure'  },
  srt                = { glyph = '󰨖', hl = 'MiniIconsYellow' },
  ssa                = { glyph = '󰨖', hl = 'MiniIconsOrange' },
  sshconfig          = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  sshdconfig         = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  st                 = { glyph = '󰄚', hl = 'MiniIconsOrange' },
  stata              = { glyph = '󰝫', hl = 'MiniIconsRed'    },
  stp                = { glyph = '󰬀', hl = 'MiniIconsYellow' },
  strace             = { glyph = '󰬀', hl = 'MiniIconsPurple' },
  structurizr        = { glyph = '󰬀', hl = 'MiniIconsBlue'   },
  stylus             = { glyph = '󰴒', hl = 'MiniIconsGrey'   },
  sudoers            = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  svelte             = { glyph = '', hl = 'MiniIconsOrange' },
  svg                = { glyph = '󰜡', hl = 'MiniIconsYellow' },
  svn                = { glyph = '󰜘', hl = 'MiniIconsOrange' },
  swayconfig         = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  swift              = { glyph = '󰛥', hl = 'MiniIconsOrange' },
  swiftgyb           = { glyph = '󰛥', hl = 'MiniIconsYellow' },
  swig               = { glyph = '󰬀', hl = 'MiniIconsGreen'  },
  sysctl             = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  systemd            = { glyph = '', hl = 'MiniIconsGrey'   },
  systemverilog      = { glyph = '󰍛', hl = 'MiniIconsGreen'  },
  tads               = { glyph = '󱩼', hl = 'MiniIconsAzure'  },
  tags               = { glyph = '󰓻', hl = 'MiniIconsGreen'  },
  tak                = { glyph = '󰔏', hl = 'MiniIconsRed'    },
  takcmp             = { glyph = '󰔏', hl = 'MiniIconsGreen'  },
  takout             = { glyph = '󰔏', hl = 'MiniIconsBlue'   },
  tap                = { glyph = '󰬁', hl = 'MiniIconsAzure'  },
  tar                = { glyph = '󰬁', hl = 'MiniIconsCyan'   },
  taskdata           = { glyph = '󱒋', hl = 'MiniIconsPurple' },
  taskedit           = { glyph = '󰬁', hl = 'MiniIconsAzure'  },
  tasm               = { glyph = '', hl = 'MiniIconsPurple' },
  tcl                = { glyph = '󰛓', hl = 'MiniIconsRed'    },
  tcsh               = { glyph = '', hl = 'MiniIconsAzure'  },
  template           = { glyph = '󰬁', hl = 'MiniIconsGreen'  },
  teraterm           = { glyph = '󰅭', hl = 'MiniIconsGreen'  },
  terminfo           = { glyph = '', hl = 'MiniIconsGrey'   },
  terraform          = { glyph = '󱁢', hl = 'MiniIconsBlue'   },
  tex                = { glyph = '', hl = 'MiniIconsGreen'  },
  texinfo            = { glyph = '', hl = 'MiniIconsAzure'  },
  texmf              = { glyph = '󰒓', hl = 'MiniIconsPurple' },
  text               = { glyph = '󰦪', hl = 'MiniIconsYellow' },
  tf                 = { glyph = '󰬁', hl = 'MiniIconsRed'    },
  tidy               = { glyph = '󰌝', hl = 'MiniIconsBlue'   },
  tilde              = { glyph = '󰜥', hl = 'MiniIconsRed'    },
  tli                = { glyph = '󰬁', hl = 'MiniIconsCyan'   },
  tmux               = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  toml               = { glyph = '', hl = 'MiniIconsOrange' },
  tpp                = { glyph = '󰐨', hl = 'MiniIconsPurple' },
  trasys             = { glyph = '󰬁', hl = 'MiniIconsBlue'   },
  treetop            = { glyph = '󰔱', hl = 'MiniIconsGreen'  },
  trustees           = { glyph = '󰬁', hl = 'MiniIconsPurple' },
  tsalt              = { glyph = '󰬁', hl = 'MiniIconsPurple' },
  tsscl              = { glyph = '󱣖', hl = 'MiniIconsGreen'  },
  tssgm              = { glyph = '󱣖', hl = 'MiniIconsYellow' },
  tssop              = { glyph = '󱣖', hl = 'MiniIconsGrey'   },
  tsv                = { glyph = '', hl = 'MiniIconsBlue'   },
  tt2                = { glyph = '', hl = 'MiniIconsAzure'  },
  tt2html            = { glyph = '', hl = 'MiniIconsOrange' },
  tt2js              = { glyph = '', hl = 'MiniIconsYellow' },
  tutor              = { glyph = '󱆀', hl = 'MiniIconsPurple' },
  typescript         = { glyph = '󰛦', hl = 'MiniIconsAzure'  },
  typescriptreact    = { glyph = '', hl = 'MiniIconsBlue'   },
  typst              = { glyph = '󰬛', hl = 'MiniIconsAzure'  },
  uc                 = { glyph = '󰬂', hl = 'MiniIconsGrey'   },
  uci                = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  udevconf           = { glyph = '󰒓', hl = 'MiniIconsOrange' },
  udevperm           = { glyph = '󰬂', hl = 'MiniIconsOrange' },
  udevrules          = { glyph = '󰬂', hl = 'MiniIconsBlue'   },
  uil                = { glyph = '󰬂', hl = 'MiniIconsGrey'   },
  unison             = { glyph = '󰡉', hl = 'MiniIconsYellow' },
  updatedb           = { glyph = '󰒓', hl = 'MiniIconsGrey'   },
  upstart            = { glyph = '󰬂', hl = 'MiniIconsCyan'   },
  upstreamdat        = { glyph = '󰬂', hl = 'MiniIconsGreen'  },
  upstreaminstalllog = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  upstreamlog        = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  upstreamrpt        = { glyph = '󰬂', hl = 'MiniIconsYellow' },
  urlshortcut        = { glyph = '󰌷', hl = 'MiniIconsPurple' },
  usd                = { glyph = '󰻇', hl = 'MiniIconsAzure'  },
  usserverlog        = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  usw2kagtlog        = { glyph = '󰷐', hl = 'MiniIconsBlue'   },
  v                  = { glyph = '󰬃', hl = 'MiniIconsBlue'   },
  valgrind           = { glyph = '󰍛', hl = 'MiniIconsGrey'   },
  vb                 = { glyph = '󰛤', hl = 'MiniIconsPurple' },
  vdf                = { glyph = '󰬃', hl = 'MiniIconsCyan'   },
  vera               = { glyph = '󰬃', hl = 'MiniIconsCyan'   },
  verilog            = { glyph = '󰍛', hl = 'MiniIconsGreen'  },
  verilogams         = { glyph = '󰍛', hl = 'MiniIconsGreen'  },
  vgrindefs          = { glyph = '󰬃', hl = 'MiniIconsPurple' },
  vhdl               = { glyph = '󰍛', hl = 'MiniIconsGreen'  },
  vim                = { glyph = '', hl = 'MiniIconsGreen'  },
  viminfo            = { glyph = '', hl = 'MiniIconsBlue'   },
  virata             = { glyph = '󰒓', hl = 'MiniIconsCyan'   },
  vmasm              = { glyph = '', hl = 'MiniIconsPurple' },
  voscm              = { glyph = '󰬃', hl = 'MiniIconsCyan'   },
  vrml               = { glyph = '󰬃', hl = 'MiniIconsBlue'   },
  vroom              = { glyph = '', hl = 'MiniIconsOrange' },
  vsejcl             = { glyph = '󰬃', hl = 'MiniIconsCyan'   },
  vue                = { glyph = '󰡄', hl = 'MiniIconsGreen'  },
  wat                = { glyph = '', hl = 'MiniIconsPurple' },
  wdiff              = { glyph = '󰦓', hl = 'MiniIconsBlue'   },
  wdl                = { glyph = '󰬄', hl = 'MiniIconsGrey'   },
  web                = { glyph = '󰯊', hl = 'MiniIconsGrey'   },
  webmacro           = { glyph = '󰬄', hl = 'MiniIconsCyan'   },
  wget               = { glyph = '󰒓', hl = 'MiniIconsYellow' },
  wget2              = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  winbatch           = { glyph = '󰯂', hl = 'MiniIconsBlue'   },
  wml                = { glyph = '󰖟', hl = 'MiniIconsGreen'  },
  wsh                = { glyph = '󰯂', hl = 'MiniIconsPurple' },
  wsml               = { glyph = '󰬄', hl = 'MiniIconsAzure'  },
  wvdial             = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  xbl                = { glyph = '󰬅', hl = 'MiniIconsAzure'  },
  xcompose           = { glyph = '󰌌', hl = 'MiniIconsOrange' },
  xdefaults          = { glyph = '󰒓', hl = 'MiniIconsBlue'   },
  xf86conf           = { glyph = '󰒓', hl = 'MiniIconsAzure'  },
  xhtml              = { glyph = '󰌝', hl = 'MiniIconsOrange' },
  xinetd             = { glyph = '󰒓', hl = 'MiniIconsGreen'  },
  xkb                = { glyph = '󰌌', hl = 'MiniIconsPurple' },
  xmath              = { glyph = '󰬅', hl = 'MiniIconsYellow' },
  xml                = { glyph = '󰗀', hl = 'MiniIconsOrange' },
  xmodmap            = { glyph = '󰬅', hl = 'MiniIconsCyan'   },
  xpm                = { glyph = '󰍹', hl = 'MiniIconsYellow' },
  xpm2               = { glyph = '󰍹', hl = 'MiniIconsGreen'  },
  xquery             = { glyph = '󰗀', hl = 'MiniIconsAzure'  },
  xs                 = { glyph = '', hl = 'MiniIconsRed'    },
  xsd                = { glyph = '󰗀', hl = 'MiniIconsYellow' },
  xslt               = { glyph = '󰗀', hl = 'MiniIconsGreen'  },
  xxd                = { glyph = '󰬅', hl = 'MiniIconsBlue'   },
  yacc               = { glyph = '󰬆', hl = 'MiniIconsOrange' },
  yaml               = { glyph = '', hl = 'MiniIconsPurple' },
  z8a                = { glyph = '', hl = 'MiniIconsGrey'   },
  zathurarc          = { glyph = '󰒓', hl = 'MiniIconsRed'    },
  zig                = { glyph = '', hl = 'MiniIconsOrange' },
  zimbu              = { glyph = '󰬇', hl = 'MiniIconsGreen'  },
  zip                = { glyph = '󰗄', hl = 'MiniIconsGreen'  },
  zir                = { glyph = '', hl = 'MiniIconsOrange' },
  zserio             = { glyph = '󰬇', hl = 'MiniIconsGrey'   },
  zsh                = { glyph = '', hl = 'MiniIconsGreen'  },

  -- Popular filetype which require user configuration
  helm                    = { glyph = '󰠳', hl = 'MiniIconsBlue'   },
  http                    = { glyph = '󰌷', hl = 'MiniIconsOrange' },
  ['yaml.ansible']        = { glyph = '󱂚', hl = 'MiniIconsGrey'   },
  ['yaml.docker-compose'] = { glyph = '󰡨', hl = 'MiniIconsYellow' },

  -- 'mini.nvim'
  ['minideps-confirm']   = { glyph = '', hl = 'MiniIconsOrange' },
  minifiles              = { glyph = '', hl = 'MiniIconsGreen'  },
  ['minifiles-help']     = { glyph = '', hl = 'MiniIconsGreen'  },
  mininotify             = { glyph = '', hl = 'MiniIconsYellow' },
  ['mininotify-history'] = { glyph = '', hl = 'MiniIconsYellow' },
  minipick               = { glyph = '', hl = 'MiniIconsCyan'   },
  ministarter            = { glyph = '', hl = 'MiniIconsAzure'  },

  -- Popular Lua plugins which have a dedicated "current window" workflow (i.e.
  -- when displaying filetype might make sense, especially with 'laststatus=3')
  aerial                   = { glyph = '󱘎', hl = 'MiniIconsPurple' },
  alpha                    = { glyph = '󰀫', hl = 'MiniIconsOrange' },
  dapui_breakpoints        = { glyph = '󰃤', hl = 'MiniIconsRed'    },
  dapui_console            = { glyph = '󰃤', hl = 'MiniIconsRed'    },
  dapui_hover              = { glyph = '󰃤', hl = 'MiniIconsRed'    },
  dapui_scopes             = { glyph = '󰃤', hl = 'MiniIconsRed'    },
  dapui_stacks             = { glyph = '󰃤', hl = 'MiniIconsRed'    },
  dapui_watches            = { glyph = '󰃤', hl = 'MiniIconsRed'    },
  dashboard                = { glyph = '󰕮', hl = 'MiniIconsOrange' },
  edgy                     = { glyph = '󰛺', hl = 'MiniIconsGrey'   },
  fzf                      = { glyph = '󱡠', hl = 'MiniIconsAzure'  },
  harpoon                  = { glyph = '󱡀', hl = 'MiniIconsCyan'   },
  lazy                     = { glyph = '󰒲', hl = 'MiniIconsBlue'   },
  mason                    = { glyph = '󱌢', hl = 'MiniIconsGrey'   },
  ['neo-tree']             = { glyph = '󰙅', hl = 'MiniIconsYellow' },
  ['neo-tree-popup']       = { glyph = '󰙅', hl = 'MiniIconsYellow' },
  neogitcommitselectview   = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitcommitview         = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitconsole            = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitdiffview           = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitgitcommandhistory  = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitlogview            = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitpopup              = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitrebasetodo         = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitreflogview         = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitrefsview           = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  neogitstatus             = { glyph = '󰊢', hl = 'MiniIconsOrange' },
  ['neotest-output-panel'] = { glyph = '󰱑', hl = 'MiniIconsRed'    },
  ['neotest-summary']      = { glyph = '󰱑', hl = 'MiniIconsRed'    },
  nvimtree                 = { glyph = '󰙅', hl = 'MiniIconsGreen'  },
  oil                      = { glyph = '󰙅', hl = 'MiniIconsPurple' },
  overseerform             = { glyph = '󰜎', hl = 'MiniIconsBlue'   },
  overseerlist             = { glyph = '󰜎', hl = 'MiniIconsBlue'   },
  telescopeprompt          = { glyph = '󰭎', hl = 'MiniIconsAzure'  },
  trouble                  = { glyph = '󰙅', hl = 'MiniIconsRed'    },
}

-- LSP kind values (completion item, symbol, etc.) icons.
-- Use only `nf-cod-*` classes with "outline" look. Balance colors.
--stylua: ignore
H.lsp_icons = {
  array         = { glyph = '', hl = 'MiniIconsOrange' },
  boolean       = { glyph = '', hl = 'MiniIconsOrange' },
  class         = { glyph = '', hl = 'MiniIconsPurple' },
  color         = { glyph = '', hl = 'MiniIconsRed'    },
  constant      = { glyph = '', hl = 'MiniIconsOrange' },
  constructor   = { glyph = '', hl = 'MiniIconsAzure'  },
  enum          = { glyph = '', hl = 'MiniIconsPurple' },
  enummember    = { glyph = '', hl = 'MiniIconsYellow' },
  event         = { glyph = '', hl = 'MiniIconsRed'    },
  field         = { glyph = '', hl = 'MiniIconsYellow' },
  file          = { glyph = '', hl = 'MiniIconsBlue'   },
  folder        = { glyph = '', hl = 'MiniIconsBlue'   },
  ['function']  = { glyph = '', hl = 'MiniIconsAzure'  },
  interface     = { glyph = '', hl = 'MiniIconsPurple' },
  key           = { glyph = '', hl = 'MiniIconsYellow' },
  keyword       = { glyph = '', hl = 'MiniIconsCyan'   },
  method        = { glyph = '', hl = 'MiniIconsAzure'  },
  module        = { glyph = '', hl = 'MiniIconsPurple' },
  namespace     = { glyph = '', hl = 'MiniIconsRed'    },
  null          = { glyph = '', hl = 'MiniIconsGrey'   },
  number        = { glyph = '', hl = 'MiniIconsOrange' },
  object        = { glyph = '', hl = 'MiniIconsGrey'   },
  operator      = { glyph = '', hl = 'MiniIconsCyan'   },
  package       = { glyph = '', hl = 'MiniIconsPurple' },
  property      = { glyph = '', hl = 'MiniIconsYellow' },
  reference     = { glyph = '', hl = 'MiniIconsCyan'   },
  snippet       = { glyph = '', hl = 'MiniIconsGreen'  },
  string        = { glyph = '', hl = 'MiniIconsGreen'  },
  struct        = { glyph = '', hl = 'MiniIconsPurple' },
  text          = { glyph = '', hl = 'MiniIconsGreen'  },
  typeparameter = { glyph = '', hl = 'MiniIconsCyan'   },
  unit          = { glyph = '', hl = 'MiniIconsCyan'   },
  value         = { glyph = '', hl = 'MiniIconsBlue'   },
  variable      = { glyph = '', hl = 'MiniIconsCyan'   },
}

-- OS icons. Keys are for operating systems present as `md-*` class icons, as
-- this feels representative of "popular" operating systems.
--stylua: ignore
H.os_icons = {
  android      = { glyph = '󰀲', hl = 'MiniIconsGreen'  },
  arch         = { glyph = '󰣇', hl = 'MiniIconsAzure'  },
  centos       = { glyph = '󱄚', hl = 'MiniIconsRed'    },
  debian       = { glyph = '󰣚', hl = 'MiniIconsRed'    },
  fedora       = { glyph = '󰣛', hl = 'MiniIconsBlue'   },
  freebsd      = { glyph = '󰣠', hl = 'MiniIconsRed'    },
  gentoo       = { glyph = '󰣨', hl = 'MiniIconsPurple' },
  ios          = { glyph = '󰀷', hl = 'MiniIconsYellow' },
  linux        = { glyph = '󰌽', hl = 'MiniIconsCyan'   },
  macos        = { glyph = '󰀵', hl = 'MiniIconsGrey'   },
  manjaro      = { glyph = '󱘊', hl = 'MiniIconsGreen'  },
  mint         = { glyph = '󰣭', hl = 'MiniIconsGreen'  },
  nixos        = { glyph = '󱄅', hl = 'MiniIconsAzure'  },
  raspberry_pi = { glyph = '󰐿', hl = 'MiniIconsRed'    },
  redhat       = { glyph = '󱄛', hl = 'MiniIconsRed'    },
  ubuntu       = { glyph = '󰕈', hl = 'MiniIconsOrange' },
  windows      = { glyph = '󰖳', hl = 'MiniIconsBlue'   },
}

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({
    style = { config.style, 'string' },
    default = { config.default, 'table' },
    directory = { config.directory, 'table' },
    extension = { config.extension, 'table' },
    file = { config.file, 'table' },
    filetype = { config.filetype, 'table' },
    lsp = { config.lsp, 'table' },
    os = { config.os, 'table' },
  })

  return config
end

H.apply_config = function(config)
  MiniIcons.config = config

  -- Initialize cache for quicker `get()`
  H.init_cache(config)
end

--stylua: ignore
H.create_default_hl = function()
  local hi = function(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end

  hi('MiniIconsAzure', { link = 'Function' })
  hi('MiniIconsBlue', { link = 'DiagnosticInfo' })
  hi('MiniIconsCyan', { link = 'DiagnosticHint' })
  hi('MiniIconsGreen', { link = 'DiagnosticOk' })
  hi('MiniIconsGrey', {})
  hi('MiniIconsOrange', { link = 'DiagnosticWarn' })
  hi('MiniIconsPurple', { link = 'Constant' })
  hi('MiniIconsRed', { link = 'DiagnosticError' })
  hi('MiniIconsYellow', { link = 'DiagnosticWarn' })
end

H.init_cache = function(config)
  -- NOTE: process 'filetype' - 'extension' - 'file' order because previous
  -- might be used to infer missing data in the next
  local categories = { 'directory', 'filetype', 'extension', 'file', 'lsp', 'os' }

  -- Cache is structured the same way as customization tables in `config`, but
  -- for smaller size (by about 10%) uses number indexes instead of named ones.
  H.cache = { default = {} }
  for _, cat in ipairs(categories) do
    -- Set default
    H.cache.default[cat] = H.compute_cache_entry('default', cat, config.default[cat])

    -- Set custom
    H.cache[cat] = {}
    for name, icon_data in pairs(config[cat]) do
      H.cache[cat][name] = H.compute_cache_entry(cat, name, icon_data)
    end
  end
  H.cache.default.default = H.compute_cache_entry('default', 'default', config.default.default)
end

H.compute_cache_entry = function(category, name, icon_data)
  if type(name) ~= 'string' then return nil end

  icon_data = type(icon_data) == 'table' and icon_data or {}
  local glyph, hl = icon_data.glyph, icon_data.hl

  -- Allow customizing only one characteristic with proper fallback
  local has_glyph, has_hl = type(glyph) == 'string', type(hl) == 'string'
  local builtin_glyph, builtin_hl = '', ''
  if not (has_glyph and has_hl) then
    if category == 'default' then
      builtin_glyph, builtin_hl = H.default_icons[name].glyph, H.default_icons[name].hl
    else
      builtin_glyph, builtin_hl = MiniIcons.get(category, name)
    end
  end
  return {
    H.style_icon(has_glyph and glyph or builtin_glyph, name),
    has_hl and hl or builtin_hl,
    false,
  }
end

-- Getters --------------------------------------------------------------------
H.get_impl = {
  default = function(name) H.error(vim.inspect(name) .. ' is not a supported category.') end,
  directory = function(name) return H.directory_icons[name] end,
  extension = function(name)
    local icon, hl = H.get_from_extension(name)
    if icon ~= nil then return icon, hl end

    -- Fall back to built-in filetype matching using generic filename
    local ft = H.filetype_match('aaa.' .. name)
    if ft ~= nil then return MiniIcons.get('filetype', ft) end
  end,
  file = function(name)
    local icon_data = H.file_icons[name]
    if icon_data ~= nil then return icon_data end

    -- Try using custom extensions first before for better speed (as
    -- `vim.filetype.match()` is slow-ish to be called many times; like 0.1 ms)
    local dot = string.find(name, '%..', 2)
    while dot ~= nil do
      local ext = name:sub(dot + 1):lower()

      local cached = H.cache.extension[ext]
      if cached ~= nil then return cached[1], cached[2] end

      local icon, hl = H.get_from_extension(ext)
      if icon ~= nil then
        H.cache.extension[ext] = { icon, hl, false }
        return icon, hl
      end

      dot = string.find(name, '%..', dot + 1)
    end

    -- Fall back to built-in filetype matching using generic filename
    local ft = H.filetype_match(name)
    if ft ~= nil then return MiniIcons.get('filetype', ft) end
  end,
  filetype = function(name) return H.filetype_icons[name] end,
  lsp = function(name) return H.lsp_icons[name] end,
  os = function(name) return H.os_icons[name] end,
}

H.get_from_extension = function(ext)
  local icon_data = H.extension_icons[ext]
  if type(icon_data) == 'string' then return MiniIcons.get('filetype', icon_data) end
  if icon_data ~= nil then return H.style_icon(icon_data.glyph, ext), icon_data.hl end
end

H.style_icon = function(glyph, name)
  if MiniIcons.config.style ~= 'ascii' then return glyph end
  -- Use `vim.str_byteindex()` and `vim.fn.toupper()` for multibyte characters
  return vim.fn.toupper(name:sub(1, vim.str_byteindex(name, 1)))
end

H.filetype_match = function(filename)
  -- Ensure always present scratch buffer to be used in `vim.filetype.match()`
  -- (needed because the function in many ambiguous cases prefers to return
  -- nothing if there is no buffer supplied)
  local buf_id = H.scratch_buf_id
  H.scratch_buf_id = (buf_id == nil or not vim.api.nvim_buf_is_valid(buf_id)) and vim.api.nvim_create_buf(false, true)
    or buf_id
  return vim.filetype.match({ filename = filename, buf = H.scratch_buf_id })
end

-- Utilities ------------------------------------------------------------------
H.error = function(msg) error(string.format('(mini.icons) %s', msg), 0) end

H.notify = function(msg, level_name) vim.notify('(mini.icons) ' .. msg, vim.log.levels[level_name]) end

H.fs_basename = function(x) return vim.fn.fnamemodify(x:sub(-1, -1) == '/' and x:sub(1, -2) or x, ':t') end
if vim.loop.os_uname().sysname == 'Windows_NT' then
  H.fs_basename = function(x)
    local last = x:sub(-1, -1)
    return vim.fn.fnamemodify((last == '/' or last == '\\') and x:sub(1, -2) or x, ':t')
  end
end

-- Initialize cache right away to allow using `get()` without `setup()`
H.init_cache(MiniIcons.config)

return MiniIcons
