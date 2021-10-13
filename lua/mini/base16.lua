-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom minimal and fast Lua module which implements
--- [base16](http://chriskempson.com/projects/base16/) color scheme (with
--- Copyright (C) 2012 Chris Kempson) adapated for modern Neovim 0.5 Lua
--- plugins. Extra features:
--- - Configurable automatic support of cterm colors (see |highlight-cterm|).
--- - Opinionated palette generator based only on background and foreground
---   colors.
---
--- # Setup
---
--- This module needs a setup with `require('mini.base16').setup({})` (replace
---`{}` with your - `config` table).
---
--- Default `config`:
--- <pre>
--- {
---   -- Table with names from `base00` to `base0F` and values being strings of HEX
---   -- colors with format "#RRGGBB". NOTE: this should be explicitly supplied in
---   -- `setup()`.
---   palette = nil,
---
---   -- Name of applied theme (stored in `g:colors_name`)
---   name = 'base16-custom',
---
---  -- Whether to support cterm colors. Can be boolean, `nil` (same as `false`),
---  -- or table with cterm colors. See `setup()` documentation for more
---  -- information.
---   use_cterm = nil,
--- }
--- </pre>
---
--- Example:
---
--- <pre>
--- `require('mini.base16').setup({`
---   `palette = {`
---     `base00 = '#112641',`
---     `base01 = '#3a475e',`
---     `base02 = '#606b81',`
---     `base03 = '#8691a7',`
---     `base04 = '#d5dc81',`
---     `base05 = '#e2e98f',`
---     `base06 = '#eff69c',`
---     `base07 = '#fcffaa',`
---     `base08 = '#ffcfa0',`
---     `base09 = '#cc7e46',`
---     `base0A = '#46a436',`
---     `base0B = '#9ff895',`
---     `base0C = '#ca6ecf',`
---     `base0D = '#42f7ff',`
---     `base0E = '#ffc4ff',`
---     `base0F = '#00a5c5',`
---   `},`
---   `name = 'minischeme',`
---   `use_cterm = true,`
--- `})`
--- </pre>
---
--- # Notes
--- 1. This module is used for creating plugin's official colorscheme named
---    `minischeme` (see |mini.nvim|).
---@brief ]]
---@tag MiniBase16 mini.base16

-- Module and its helper
local MiniBase16 = {}
local H = {}

--- Module setup
---
--- Setup is done by applying base16 palette to enable colorscheme. Highlight
--- groups make an extended set from original
--- [base16-vim](https://github.com/chriskempson/base16-vim/) plugin. It is a
--- good idea to have `config.palette` respect the original [styling
--- principles](https://github.com/chriskempson/base16/blob/master/styling.md).
---
--- By default only 'gui highlighting' (see |highlight-gui| and
--- |termguicolors|) is supported. To support 'cterm highlighting' (see
--- |highlight-cterm|) supply `config.use_cterm` argument in one of the formats:
--- - `true` to auto-generate from `palette` (as closest colors).
--- - Table with similar structure to `palette` but having terminal colors
---   (integers from 0 to 255) instead of hex strings.
---
---@param config table: Module config table.
---@usage `require('mini.base16').setup({})` (replace `{}` with your `config` table; `config.palette` should be a table with colors)
function MiniBase16.setup(config)
  -- Export module
  _G.MiniBase16 = MiniBase16

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)
end

MiniBase16.config = {
  -- Table with names from `base00` to `base0F` and values being strings of HEX
  -- colors with format "#RRGGBB". NOTE: this should be explicitly supplied in
  -- `setup()`.
  palette = nil,

  -- Name of applied theme (stored in `g:colors_name`)
  name = 'base16-custom',

  -- Whether to support cterm colors. Can be boolean, `nil` (same as `false`),
  -- or table with cterm colors. See `setup()` documentation for more
  -- information.
  use_cterm = nil,
}

--- Create 'mini' palette
---
--- Create base16 palette based on the HEX (string '#RRGGBB') colors of main background and
--- foreground with optional setting of accent chroma (see details).
---
--- # Algorithm design
--- - Main operating color space is
---   [CIELCh(uv)](https://en.wikipedia.org/wiki/CIELUV#Cylindrical_representation_(CIELCh))
---   which is a cylindrical representation of a perceptually uniform CIELUV
---   color space. It defines color by three values: lightness L (values from 0
---   to 100), chroma (positive values), and hue (circular values from 0 to 360
---   degress). Useful converting tool: https://www.easyrgb.com/en/convert.php
--- - There are four important lightness values: background, foreground, focus
---   (around the middle of background and foreground, leaning towards
---   foreground), and edge (extreme lightness closest to foreground).
--- - First four colors have the same chroma and hue as `background` but
---   lightness progresses from background towards focus.
--- - Second four colors have the same chroma and hue as `foreground` but
---   lightness progresses from foreground towards edge in such a way that
---   'base05' color is main foreground color.
--- - The rest eight colors are accent colors which are created in pairs
---     - Each pair has same hue from set of hues 'most different' to
---       background and foreground hues (if respective chorma is positive).
---     - All colors have the same chroma equal to `accent_chroma` (if not
---       provided, chroma of foreground is used, as they will appear next
---       to each other). Note: this means that in case of low foreground
---       chroma, it is a good idea to set `accent_chroma` manually.
---       Values from 30 (low chorma) to 80 (high chroma) are common.
---     - Within pair there is base lightness (equal to foreground
---       lightness) and alternative (equal to focus lightness). Base
---       lightness goes to colors which will be used more frequently in
---       code: base08 (variables), base0B (strings), base0D (functions),
---       base0E (keywords).
---   How exactly accent colors are mapped to base16 palette is a result of
---   trial and error. One rule of thumb was: colors within one hue pair should
---   be more often seen next to each other. This is because it is easier to
---   distinguish them and seems to be more visually appealing. That is why
---   `base0D` and `base0F` have same hues because they usually represent
---   functions and delimiter (brackets included).
---
---@param background string: Background HEX color (formatted as `#RRGGBB`).
---@param foreground string: Foreground HEX color (formatted as `#RRGGBB`).
---@param accent_chroma number: Optional positive number (usually between 0 and 100). Default: chroma of foreground color.
---@return table: Table with base16 palette.
---@usage `local palette = require('mini.base16').mini_palette('#112641', '#e2e98f', 75)`
---@usage `require('mini.base16').setup({palette = palette, name = 'my-base16'})`
function MiniBase16.mini_palette(background, foreground, accent_chroma)
  H.validate_hex(background, 'background')
  H.validate_hex(foreground, 'foreground')
  if accent_chroma and not (type(accent_chroma) == 'number' and accent_chroma >= 0) then
    error('(mini.base16) `accent_chroma` should be a positive number or `nil`.')
  end
  local bg, fg = H.hex2lch(background), H.hex2lch(foreground)
  accent_chroma = accent_chroma or fg.c

  local palette = {}

  -- Target lightness values
  -- Justification for skewness towards foreground in focus is mainly because
  -- it will be paired with foreground lightness and used for text.
  local focus_l = 0.4 * bg.l + 0.6 * fg.l
  local edge_l = fg.l > 50 and 99 or 1

  -- Background colors
  local bg_step = (focus_l - bg.l) / 3
  palette[1] = { l = bg.l + 0 * bg_step, c = bg.c, h = bg.h }
  palette[2] = { l = bg.l + 1 * bg_step, c = bg.c, h = bg.h }
  palette[3] = { l = bg.l + 2 * bg_step, c = bg.c, h = bg.h }
  palette[4] = { l = bg.l + 3 * bg_step, c = bg.c, h = bg.h }

  -- Foreground colors Possible negative value of `palette[5].l` will be
  -- handled in future conversion to hex.
  local fg_step = (edge_l - fg.l) / 2
  palette[5] = { l = fg.l - 1 * fg_step, c = fg.c, h = fg.h }
  palette[6] = { l = fg.l + 0 * fg_step, c = fg.c, h = fg.h }
  palette[7] = { l = fg.l + 1 * fg_step, c = fg.c, h = fg.h }
  palette[8] = { l = fg.l + 2 * fg_step, c = fg.c, h = fg.h }

  -- Accent colors
  ---- Only try to avoid color if it has positive chroma, because with zero
  ---- chroma hue is meaningless (as in polar coordinates)
  local present_hues = {}
  if bg.c > 0 then
    table.insert(present_hues, bg.h)
  end
  if fg.c > 0 then
    table.insert(present_hues, fg.h)
  end
  local hues = H.make_different_hues(present_hues, 4)

  -- stylua: ignore start
  palette[9]  = { l = fg.l,    c = accent_chroma, h = hues[1] }
  palette[10] = { l = focus_l, c = accent_chroma, h = hues[1] }
  palette[11] = { l = focus_l, c = accent_chroma, h = hues[2] }
  palette[12] = { l = fg.l,    c = accent_chroma, h = hues[2] }
  palette[13] = { l = focus_l, c = accent_chroma, h = hues[4] }
  palette[14] = { l = fg.l,    c = accent_chroma, h = hues[3] }
  palette[15] = { l = fg.l,    c = accent_chroma, h = hues[4] }
  palette[16] = { l = focus_l, c = accent_chroma, h = hues[3] }
  -- stylua: ignore end

  -- Convert to base16 palette
  local base16_palette = {}
  for i, lch in ipairs(palette) do
    local name = H.base16_names[i]
    -- It is ensured in `lch2hex` that only valid HEX values are produced
    base16_palette[name] = H.lch2hex(lch)
  end

  return base16_palette
end

--- Converts palette with RGB colors to terminal colors
---
--- Useful for caching `use_cterm` variable to increase speed.
---
---@param palette table: Table with base16 palette (same as in `MiniBase16.config.palette`).
---@return table: Table with base16 palette using |highlight-cterm|.
function MiniBase16.rgb_palette_to_cterm_palette(palette)
  H.validate_base16_palette(palette, 'palette')

  -- Create cterm palette only when it is needed to decrease load time
  H.ensure_cterm_palette()

  return vim.tbl_map(function(hex)
    return H.nearest_rgb_id(H.hex2rgb(hex), H.cterm_palette)
  end, palette)
end

-- Helpers
---- Module default config
H.default_config = MiniBase16.config

---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  -- Validate settings
  H.validate_base16_palette(config.palette, 'config.palette')
  if type(config.name) ~= 'string' then
    error('(mini.base16) `config.name` is not a string.')
  end
  H.validate_use_cterm(config.use_cterm, 'config.use_cterm')

  return config
end

function H.apply_config(config)
  MiniBase16.config = config

  H.apply_palette(config.palette, config.name, config.use_cterm)
end

---- Validators
H.base16_names = {
  'base00',
  'base01',
  'base02',
  'base03',
  'base04',
  'base05',
  'base06',
  'base07',
  'base08',
  'base09',
  'base0A',
  'base0B',
  'base0C',
  'base0D',
  'base0E',
  'base0F',
}

function H.validate_base16_palette(x, x_name)
  if type(x) ~= 'table' then
    error(string.format('(mini.base16) `%s` is not a table.', x_name))
  end

  for _, color_name in pairs(H.base16_names) do
    local c = x[color_name]
    if c == nil then
      local msg = string.format('(mini.base16) `%s` does not have value %s.', x_name, color_name)
      error(msg)
    end
    H.validate_hex(c, string.format('config.palette[%s]', color_name))
  end

  return true
end

function H.validate_use_cterm(x, x_name)
  if not x or type(x) == 'boolean' then
    return true
  end

  if type(x) ~= 'table' then
    local msg = string.format('(mini.base16) `%s` should be boolean or table with cterm colors.', x_name)
    error(msg)
  end

  for _, color_name in pairs(H.base16_names) do
    local c = x[color_name]
    if c == nil then
      local msg = string.format('(mini.base16) `%s` does not have value %s.', x_name, color_name)
      error(msg)
    end
    if not (type(c) == 'number' and 0 <= c and c <= 255) then
      local msg = string.format('(mini.base16) `%s.%s` is not a cterm color.', x_name, color_name)
      error(msg)
    end
  end

  return true
end

function H.validate_hex(x, x_name)
  local is_hex = type(x) == 'string' and x:len() == 7 and x:sub(1, 1) == '#' and (tonumber(x:sub(2), 16) ~= nil)

  if not is_hex then
    local msg = string.format('(mini.base16) `%s` is not a HEX color (string "#RRGGBB").', x_name)
    error(msg)
  end

  return true
end

---- Highlighting
function H.apply_palette(palette, name, use_cterm)
  -- Prepare highlighting application. Notes:
  -- - Clear current highlight only if other theme was loaded previously.
  -- - No need to `syntax reset` because *all* syntax groups are defined later.
  if vim.g.colors_name then
    vim.cmd([[highlight clear]])
  end
  vim.g.colors_name = name or 'base16-custom'

  local p, hi
  if use_cterm then
    p, hi = H.make_compound_palette(palette, use_cterm), H.highlight_both
  else
    p, hi = palette, H.highlight_gui
  end

  -- stylua: ignore start
  -- Builtin highlighting groups. Some groups which are missing in 'base16-vim'
  -- are added based on groups to which they are linked.
  hi('ColorColumn',  {fg=nil,      bg=p.base01, attr=nil,         sp=nil})
  hi('Conceal',      {fg=p.base0D, bg=p.base00, attr=nil,         sp=nil})
  hi('Cursor',       {fg=p.base00, bg=p.base05, attr=nil,         sp=nil})
  hi('CursorColumn', {fg=nil,      bg=p.base01, attr=nil,         sp=nil})
  hi('CursorIM',     {fg=p.base00, bg=p.base05, attr=nil,         sp=nil})
  hi('CursorLine',   {fg=nil,      bg=p.base01, attr=nil,         sp=nil})
  hi('CursorLineNr', {fg=p.base04, bg=p.base01, attr=nil,         sp=nil})
  hi('DiffAdd',      {fg=p.base0B, bg=p.base01, attr=nil,         sp=nil})
  hi('DiffChange',   {fg=p.base03, bg=p.base01, attr=nil,         sp=nil})
  hi('DiffDelete',   {fg=p.base08, bg=p.base01, attr=nil,         sp=nil})
  hi('DiffText',     {fg=p.base0D, bg=p.base01, attr=nil,         sp=nil})
  hi('Directory',    {fg=p.base0D, bg=nil,      attr=nil,         sp=nil})
  hi('EndOfBuffer',  {fg=p.base03, bg=nil,      attr=nil,         sp=nil})
  hi('ErrorMsg',     {fg=p.base08, bg=p.base00, attr=nil,         sp=nil})
  hi('FoldColumn',   {fg=p.base0C, bg=p.base01, attr=nil,         sp=nil})
  hi('Folded',       {fg=p.base03, bg=p.base01, attr=nil,         sp=nil})
  hi('IncSearch',    {fg=p.base01, bg=p.base09, attr=nil,         sp=nil})
  hi('LineNr',       {fg=p.base03, bg=p.base01, attr=nil,         sp=nil})
  ---- Slight difference from base16, where `bg=base03` is used. This makes
  ---- it possible to comfortably see this highlighting in comments.
  hi('MatchParen',   {fg=nil,      bg=p.base02, attr=nil,         sp=nil})
  hi('ModeMsg',      {fg=p.base0B, bg=nil,      attr=nil,         sp=nil})
  hi('MoreMsg',      {fg=p.base0B, bg=nil,      attr=nil,         sp=nil})
  hi('MsgArea',      {fg=p.base05, bg=p.base00, attr=nil,         sp=nil})
  hi('MsgSeparator', {fg=p.base04, bg=p.base02, attr=nil,         sp=nil})
  hi('NonText',      {fg=p.base03, bg=nil,      attr=nil,         sp=nil})
  hi('Normal',       {fg=p.base05, bg=p.base00, attr=nil,         sp=nil})
  hi('NormalFloat',  {fg=p.base05, bg=p.base01, attr=nil,         sp=nil})
  hi('NormalNC',     {fg=p.base05, bg=p.base00, attr=nil,         sp=nil})
  hi('PMenu',        {fg=p.base05, bg=p.base01, attr=nil,         sp=nil})
  hi('PMenuSbar',    {fg=nil,      bg=p.base02, attr=nil,         sp=nil})
  hi('PMenuSel',     {fg=p.base01, bg=p.base05, attr=nil,         sp=nil})
  hi('PMenuThumb',   {fg=nil,      bg=p.base07, attr=nil,         sp=nil})
  hi('Question',     {fg=p.base0D, bg=nil,      attr=nil,         sp=nil})
  hi('QuickFixLine', {fg=nil,      bg=p.base01, attr=nil,         sp=nil})
  hi('Search',       {fg=p.base01, bg=p.base0A, attr=nil,         sp=nil})
  hi('SignColumn',   {fg=p.base03, bg=p.base01, attr=nil,         sp=nil})
  hi('SpecialKey',   {fg=p.base03, bg=nil,      attr=nil,         sp=nil})
  hi('SpellBad',     {fg=nil,      bg=nil,      attr='undercurl', sp=p.base08})
  hi('SpellCap',     {fg=nil,      bg=nil,      attr='undercurl', sp=p.base0D})
  hi('SpellLocal',   {fg=nil,      bg=nil,      attr='undercurl', sp=p.base0C})
  hi('SpellRare',    {fg=nil,      bg=nil,      attr='undercurl', sp=p.base0E})
  hi('StatusLine',   {fg=p.base04, bg=p.base02, attr=nil,         sp=nil})
  hi('StatusLineNC', {fg=p.base03, bg=p.base01, attr=nil,         sp=nil})
  hi('Substitute',   {fg=p.base01, bg=p.base0A, attr=nil,         sp=nil})
  hi('TabLine',      {fg=p.base03, bg=p.base01, attr=nil,         sp=nil})
  hi('TabLineFill',  {fg=p.base03, bg=p.base01, attr=nil,         sp=nil})
  hi('TabLineSel',   {fg=p.base0B, bg=p.base01, attr=nil,         sp=nil})
  hi('TermCursor',   {fg=nil,      bg=nil,      attr='reverse',   sp=nil})
  hi('TermCursorNC', {fg=nil,      bg=nil,      attr='reverse',   sp=nil})
  hi('Title',        {fg=p.base0D, bg=nil,      attr=nil,         sp=nil})
  hi('VertSplit',    {fg=p.base02, bg=p.base02, attr=nil,         sp=nil})
  hi('Visual',       {fg=nil,      bg=p.base02, attr=nil,         sp=nil})
  hi('VisualNOS',    {fg=p.base08, bg=nil,      attr=nil,         sp=nil})
  hi('WarningMsg',   {fg=p.base08, bg=nil,      attr=nil,         sp=nil})
  hi('Whitespace',   {fg=p.base03, bg=nil,      attr=nil,         sp=nil})
  hi('WildMenu',     {fg=p.base08, bg=p.base0A, attr=nil,         sp=nil})
  hi('lCursor',      {fg=p.base00, bg=p.base05, attr=nil,         sp=nil})

  -- Standard syntax (affects treesitter)
  hi('Boolean',        {fg=p.base09, bg=nil,      attr=nil, sp=nil})
  hi('Character',      {fg=p.base08, bg=nil,      attr=nil, sp=nil})
  hi('Comment',        {fg=p.base03, bg=nil,      attr=nil, sp=nil})
  hi('Conditional',    {fg=p.base0E, bg=nil,      attr=nil, sp=nil})
  hi('Constant',       {fg=p.base09, bg=nil,      attr=nil, sp=nil})
  hi('Debug',          {fg=p.base08, bg=nil,      attr=nil, sp=nil})
  hi('Define',         {fg=p.base0E, bg=nil,      attr=nil, sp=nil})
  hi('Delimiter',      {fg=p.base0F, bg=nil,      attr=nil, sp=nil})
  hi('Error',          {fg=p.base00, bg=p.base08, attr=nil, sp=nil})
  hi('Exception',      {fg=p.base08, bg=nil,      attr=nil, sp=nil})
  hi('Float',          {fg=p.base09, bg=nil,      attr=nil, sp=nil})
  hi('Function',       {fg=p.base0D, bg=nil,      attr=nil, sp=nil})
  hi('Identifier',     {fg=p.base08, bg=nil,      attr=nil, sp=nil})
  hi('Ignore',         {fg=p.base0C, bg=nil,      attr=nil, sp=nil})
  hi('Include',        {fg=p.base0D, bg=nil,      attr=nil, sp=nil})
  hi('Keyword',        {fg=p.base0E, bg=nil,      attr=nil, sp=nil})
  hi('Label',          {fg=p.base0A, bg=nil,      attr=nil, sp=nil})
  hi('Macro',          {fg=p.base08, bg=nil,      attr=nil, sp=nil})
  hi('Number',         {fg=p.base09, bg=nil,      attr=nil, sp=nil})
  hi('Operator',       {fg=p.base05, bg=nil,      attr=nil, sp=nil})
  hi('PreCondit',      {fg=p.base0A, bg=nil,      attr=nil, sp=nil})
  hi('PreProc',        {fg=p.base0A, bg=nil,      attr=nil, sp=nil})
  hi('Repeat',         {fg=p.base0A, bg=nil,      attr=nil, sp=nil})
  hi('Special',        {fg=p.base0C, bg=nil,      attr=nil, sp=nil})
  hi('SpecialChar',    {fg=p.base0F, bg=nil,      attr=nil, sp=nil})
  hi('SpecialComment', {fg=p.base0C, bg=nil,      attr=nil, sp=nil})
  hi('Statement',      {fg=p.base08, bg=nil,      attr=nil, sp=nil})
  hi('StorageClass',   {fg=p.base0A, bg=nil,      attr=nil, sp=nil})
  hi('String',         {fg=p.base0B, bg=nil,      attr=nil, sp=nil})
  hi('Structure',      {fg=p.base0E, bg=nil,      attr=nil, sp=nil})
  hi('Tag',            {fg=p.base0A, bg=nil,      attr=nil, sp=nil})
  hi('Todo',           {fg=p.base0A, bg=p.base01, attr=nil, sp=nil})
  hi('Type',           {fg=p.base0A, bg=nil,      attr=nil, sp=nil})
  hi('Typedef',        {fg=p.base0A, bg=nil,      attr=nil, sp=nil})
  hi('Underlined',     {fg=p.base08, bg=nil,      attr=nil, sp=nil})

  -- Other from 'base16-vim'
  hi('Bold',       {fg=nil,      bg=nil, attr='bold', sp=nil})
  hi('Italic',     {fg=nil,      bg=nil, attr=nil,    sp=nil})
  hi('TooLong',    {fg=p.base08, bg=nil, attr=nil,    sp=nil})
  hi('Underlined', {fg=p.base08, bg=nil, attr=nil,    sp=nil})

  -- Git diff
  hi('DiffAdded',   {fg=p.base0B, bg=p.base00, attr=nil, sp=nil})
  hi('DiffFile',    {fg=p.base08, bg=p.base00, attr=nil, sp=nil})
  hi('DiffLine',    {fg=p.base0D, bg=p.base00, attr=nil, sp=nil})
  hi('DiffNewFile', {fg=p.base0B, bg=p.base00, attr=nil, sp=nil})
  hi('DiffRemoved', {fg=p.base08, bg=p.base00, attr=nil, sp=nil})

  -- Git commit
  hi('gitcommitBranch',        {fg=p.base09, bg=nil, attr='bold', sp=nil})
  hi('gitcommitComment',       {fg=p.base03, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitDiscarded',     {fg=p.base03, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitDiscardedFile', {fg=p.base08, bg=nil, attr='bold', sp=nil})
  hi('gitcommitDiscardedType', {fg=p.base0D, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitHeader',        {fg=p.base0E, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitOverflow',      {fg=p.base08, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitSelected',      {fg=p.base03, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitSelectedFile',  {fg=p.base0B, bg=nil, attr='bold', sp=nil})
  hi('gitcommitSelectedType',  {fg=p.base0D, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitSummary',       {fg=p.base0B, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitUnmergedFile',  {fg=p.base08, bg=nil, attr='bold', sp=nil})
  hi('gitcommitUnmergedType',  {fg=p.base0D, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitUntracked',     {fg=p.base03, bg=nil, attr=nil,    sp=nil})
  hi('gitcommitUntrackedFile', {fg=p.base0A, bg=nil, attr=nil,    sp=nil})

  -- Built-in LSP (similar to spelling)
  hi('LspDiagnosticsDefaultError',       {fg=p.base08, bg=p.base00, attr=nil, sp=nil})
  hi('LspDiagnosticsDefaultHint',        {fg=p.base0D, bg=p.base00, attr=nil, sp=nil})
  hi('LspDiagnosticsDefaultInformation', {fg=p.base0C, bg=p.base00, attr=nil, sp=nil})
  hi('LspDiagnosticsDefaultWarning',     {fg=p.base0E, bg=p.base00, attr=nil, sp=nil})

  hi('LspDiagnosticsUnderlineError',       {fg=nil, bg=nil, attr='underline', sp=p.base08})
  hi('LspDiagnosticsUnderlineHint',        {fg=nil, bg=nil, attr='underline', sp=p.base0D})
  hi('LspDiagnosticsUnderlineInformation', {fg=nil, bg=nil, attr='underline', sp=p.base0C})
  hi('LspDiagnosticsUnderlineWarning',     {fg=nil, bg=nil, attr='underline', sp=p.base0E})

  -- Plugins
  ---- 'mini'
  hi('MiniCompletionActiveParameter', {fg=nil, bg=nil, attr='underline', sp=nil})

  hi('MiniCursorword', {fg=nil, bg=nil, attr='underline', sp=nil})

  hi('MiniStatuslineDevinfo',     {fg=p.base04, bg=p.base02, attr=nil,    sp=nil})
  hi('MiniStatuslineFileinfo',    {fg=p.base04, bg=p.base02, attr=nil,    sp=nil})
  hi('MiniStatuslineFilename',    {fg=p.base03, bg=p.base01, attr=nil,    sp=nil})
  hi('MiniStatuslineInactive',    {fg=p.base03, bg=p.base01, attr=nil,    sp=nil})
  hi('MiniStatuslineModeCommand', {fg=p.base00, bg=p.base08, attr='bold', sp=nil})
  hi('MiniStatuslineModeInsert',  {fg=p.base00, bg=p.base0D, attr='bold', sp=nil})
  hi('MiniStatuslineModeNormal',  {fg=p.base00, bg=p.base05, attr='bold', sp=nil})
  hi('MiniStatuslineModeOther',   {fg=p.base00, bg=p.base03, attr='bold', sp=nil})
  hi('MiniStatuslineModeReplace', {fg=p.base00, bg=p.base0E, attr='bold', sp=nil})
  hi('MiniStatuslineModeVisual',  {fg=p.base00, bg=p.base0B, attr='bold', sp=nil})

  hi('MiniSurround', {fg=p.base01, bg=p.base09, attr=nil, sp=nil})

  hi('MiniTablineCurrent',         {fg=p.base05, bg=p.base02, attr='bold', sp=nil})
  hi('MiniTablineFill',            {fg=nil,      bg=nil,      attr=nil,    sp=nil})
  hi('MiniTablineHidden',          {fg=p.base04, bg=p.base01, attr=nil,    sp=nil})
  hi('MiniTablineModifiedCurrent', {fg=p.base02, bg=p.base05, attr='bold', sp=nil})
  hi('MiniTablineModifiedHidden',  {fg=p.base01, bg=p.base04, attr=nil,    sp=nil})
  hi('MiniTablineModifiedVisible', {fg=p.base02, bg=p.base04, attr='bold', sp=nil})
  hi('MiniTablineVisible',         {fg=p.base05, bg=p.base01, attr='bold', sp=nil})

  hi('MiniTrailspace', {fg=p.base00, bg=p.base08, attr=nil, sp=nil})

  ---- kyazdani42/nvim-tree.lua (only unlinked highlight groups)
  hi('NvimTreeExecFile',     { fg=p.base0B, bg=nil,      attr='bold',           sp=nil })
  hi('NvimTreeFolderIcon',   { fg=p.base03, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeGitDeleted',   { fg=p.base08, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeGitDirty',     { fg=p.base08, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeGitMerge',     { fg=p.base0C, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeGitNew',       { fg=p.base0D, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeGitRenamed',   { fg=p.base0E, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeGitStaged',    { fg=p.base0B, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeImageFile',    { fg=p.base0E, bg=nil,      attr='bold',           sp=nil })
  hi('NvimTreeIndentMarker', { fg=p.base03, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeOpenedFile',   { fg=p.base0B, bg=nil,      attr='bold',           sp=nil })
  hi('NvimTreeRootFolder',   { fg=p.base0E, bg=nil,      attr=nil,              sp=nil })
  hi('NvimTreeSpecialFile',  { fg=p.base0D, bg=nil,      attr='bold,underline', sp=nil })
  hi('NvimTreeSymlink',      { fg=p.base0F, bg=nil,      attr='bold',           sp=nil })
  hi('NvimTreeWindowPicker', { fg=p.base05, bg=p.base01, attr="bold",           sp=nil })

  ---- lewis6991/gitsigns.nvim
  hi('GitSignsAdd',    {fg=p.base0B, bg=p.base01, attr=nil, sp=nil})
  hi('GitSignsChange', {fg=p.base03, bg=p.base01, attr=nil, sp=nil})
  hi('GitSignsDelete', {fg=p.base08, bg=p.base01, attr=nil, sp=nil})

  ---- nvim-telescope/telescope.nvim
  hi('TelescopeBorder',         {fg=p.base0F, bg=nil,      attr=nil,    sp=nil}) -- as in 'Delimiter'
  hi('TelescopeMatching',       {fg=p.base0A, bg=nil,      attr=nil,    sp=nil}) -- as in 'Search'
  hi('TelescopeMultiSelection', {fg=nil,      bg=p.base01, attr='bold', sp=nil})
  hi('TelescopeSelection',      {fg=nil,      bg=p.base01, attr='bold', sp=nil})

  ---- folke/which-key.nvim
  hi('WhichKey',          {fg=p.base0D, bg=nil,      attr=nil, sp=nil})
  hi('WhichKeyDesc',      {fg=p.base05, bg=nil,      attr=nil, sp=nil})
  hi('WhichKeyFloat',     {fg=p.base05, bg=p.base01, attr=nil, sp=nil})
  hi('WhichKeyGroup',     {fg=p.base0E, bg=nil,      attr=nil, sp=nil})
  hi('WhichKeySeparator', {fg=p.base0B, bg=p.base01, attr=nil, sp=nil})
  hi('WhichKeyValue',     {fg=p.base03, bg=nil,      attr=nil, sp=nil})
  -- stylua: ignore end

  -- Terminal colors
  vim.g.terminal_color_0 = palette.base00
  vim.g.terminal_color_1 = palette.base08
  vim.g.terminal_color_2 = palette.base0B
  vim.g.terminal_color_3 = palette.base0A
  vim.g.terminal_color_4 = palette.base0D
  vim.g.terminal_color_5 = palette.base0E
  vim.g.terminal_color_6 = palette.base0C
  vim.g.terminal_color_7 = palette.base05
  vim.g.terminal_color_8 = palette.base03
  vim.g.terminal_color_9 = palette.base08
  vim.g.terminal_color_10 = palette.base0B
  vim.g.terminal_color_11 = palette.base0A
  vim.g.terminal_color_12 = palette.base0D
  vim.g.terminal_color_13 = palette.base0E
  vim.g.terminal_color_14 = palette.base0C
  vim.g.terminal_color_15 = palette.base07
  vim.g.terminal_color_background = vim.g.terminal_color_0
  vim.g.terminal_color_foreground = vim.g.terminal_color_5
  if vim.o.background == 'light' then
    vim.g.terminal_color_background = vim.g.terminal_color_7
    vim.g.terminal_color_foreground = vim.g.terminal_color_2
  end
end

function H.highlight_gui(group, args)
  -- NOTE: using `string.format` instead of gradually growing string with `..`
  -- is faster. Crude estimate for this particular case: whole colorscheme
  -- loading decreased from ~3.6ms to ~3.0ms, i.e. by about 20%.
  local command = string.format(
    [[highlight %s guifg=%s guibg=%s gui=%s guisp=%s]],
    group,
    args.fg or 'NONE',
    args.bg or 'NONE',
    args.attr or 'NONE',
    args.sp or 'NONE'
  )
  vim.cmd(command)
end

function H.highlight_both(group, args)
  local command = string.format(
    [[highlight %s guifg=%s ctermfg=%s guibg=%s ctermbg=%s gui=%s cterm=%s guisp=%s]],
    group,
    args.fg and args.fg.gui or 'NONE',
    args.fg and args.fg.cterm or 'NONE',
    args.bg and args.bg.gui or 'NONE',
    args.bg and args.bg.cterm or 'NONE',
    args.attr or 'NONE',
    args.attr or 'NONE',
    args.sp and args.sp.gui or 'NONE'
  )
  vim.cmd(command)
end

---- Compound (gui and cterm) palette
function H.make_compound_palette(palette, use_cterm)
  local cterm_table = use_cterm
  if type(use_cterm) == 'boolean' then
    cterm_table = MiniBase16.rgb_palette_to_cterm_palette(palette)
  end

  local res = {}
  for name, _ in pairs(palette) do
    res[name] = { gui = palette[name], cterm = cterm_table[name] }
  end
  return res
end

---- Optimal scales
---- Make a set of equally spaced hues which are as different to present hues
---- as possible
function H.make_different_hues(present_hues, n)
  local max_offset = math.floor(360 / n + 0.5)

  local dist, best_dist = nil, -math.huge
  local best_hues, new_hues

  for offset = 0, max_offset - 1, 1 do
    new_hues = H.make_hue_scale(n, offset)

    -- Compute distance as usual 'minimum distance' between two sets
    dist = H.dist_circle_set(new_hues, present_hues)

    -- Decide if it is the best
    if dist > best_dist then
      best_hues, best_dist = new_hues, dist
    end
  end

  return best_hues
end

function H.make_hue_scale(n, offset)
  local step = math.floor(360 / n + 0.5)
  local res = {}
  for i = 0, n - 1, 1 do
    table.insert(res, (offset + i * step) % 360)
  end
  return res
end

---- Terminal colors
---- Sources:
---- - https://github.com/shawncplus/Vim-toCterm/blob/master/lib/Xterm.php
---- - https://gist.github.com/MicahElliott/719710
-- stylua: ignore start
H.cterm_first16 = {
  { r = 0,   g = 0,   b = 0 },
  { r = 205, g = 0,   b = 0 },
  { r = 0,   g = 205, b = 0 },
  { r = 205, g = 205, b = 0 },
  { r = 0,   g = 0,   b = 238 },
  { r = 205, g = 0,   b = 205 },
  { r = 0,   g = 205, b = 205 },
  { r = 229, g = 229, b = 229 },
  { r = 127, g = 127, b = 127 },
  { r = 255, g = 0,   b = 0 },
  { r = 0,   g = 255, b = 0 },
  { r = 255, g = 255, b = 0 },
  { r = 92,  g = 92,  b = 255 },
  { r = 255, g = 0,   b = 255 },
  { r = 0,   g = 255, b = 255 },
  { r = 255, g = 255, b = 255 },
}
-- stylua: ignore end

H.cterm_basis = { 0, 95, 135, 175, 215, 255 }

function H.cterm2rgb(i)
  if i < 16 then
    return H.cterm_first16[i + 1]
  end
  if 16 <= i and i <= 231 then
    i = i - 16
    local r = H.cterm_basis[math.floor(i / 36) % 6 + 1]
    local g = H.cterm_basis[math.floor(i / 6) % 6 + 1]
    local b = H.cterm_basis[i % 6 + 1]
    return { r = r, g = g, b = b }
  end
  if 232 <= i and i <= 255 then
    local c = 8 + (i - 232) * 10
    return { r = c, g = c, b = c }
  end
end

function H.ensure_cterm_palette()
  if H.cterm_palette then
    return
  end
  H.cterm_palette = {}
  for i = 0, 255 do
    H.cterm_palette[i] = H.cterm2rgb(i)
  end
end

---- Color conversion
---- Source: https://www.easyrgb.com/en/math.php
---- Accuracy is usually around 2-3 decimal digits, which should be fine
------ HEX <-> CIELCh(uv)
function H.hex2lch(hex)
  local res = hex
  for _, f in pairs({ H.hex2rgb, H.rgb2xyz, H.xyz2luv, H.luv2lch }) do
    res = f(res)
  end
  return res
end

function H.lch2hex(lch)
  local res = lch
  for _, f in pairs({ H.lch2luv, H.luv2xyz, H.xyz2rgb, H.rgb2hex }) do
    res = f(res)
  end
  return res
end

------ HEX <-> RGB
function H.hex2rgb(hex)
  local dec = tonumber(hex:sub(2), 16)

  local b = math.fmod(dec, 256)
  local g = math.fmod((dec - b) / 256, 256)
  local r = math.floor(dec / 65536)

  return { r = r, g = g, b = b }
end

function H.rgb2hex(rgb)
  -- Round and trim values
  local t = vim.tbl_map(function(x)
    x = math.min(math.max(x, 0), 255)
    return math.floor(x + 0.5)
  end, rgb)

  return '#' .. string.format('%02x', t.r) .. string.format('%02x', t.g) .. string.format('%02x', t.b)
end

------ RGB <-> XYZ
function H.rgb2xyz(rgb)
  local t = vim.tbl_map(function(c)
    c = c / 255
    if c > 0.04045 then
      c = ((c + 0.055) / 1.055) ^ 2.4
    else
      c = c / 12.92
    end
    return 100 * c
  end, rgb)

  -- Source of better matrix: http://brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
  local x = 0.41246 * t.r + 0.35757 * t.g + 0.18043 * t.b
  local y = 0.21267 * t.r + 0.71515 * t.g + 0.07217 * t.b
  local z = 0.01933 * t.r + 0.11919 * t.g + 0.95030 * t.b
  return { x = x, y = y, z = z }
end

function H.xyz2rgb(xyz)
  -- Source of better matrix: http://brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
  -- stylua: ignore start
  local r =  3.24045 * xyz.x - 1.53713 * xyz.y - 0.49853 * xyz.z
  local g = -0.96927 * xyz.x + 1.87601 * xyz.y + 0.04155 * xyz.z
  local b =  0.05564 * xyz.x - 0.20403 * xyz.y + 1.05722 * xyz.z
  -- stylua: ignore end

  return vim.tbl_map(function(c)
    c = c / 100
    if c > 0.0031308 then
      c = 1.055 * (c ^ (1 / 2.4)) - 0.055
    else
      c = 12.92 * c
    end
    return 255 * c
  end, {
    r = r,
    g = g,
    b = b,
  })
end

------ XYZ <-> CIELuv
-------- Using white reference for D65 and 2 degress
H.ref_u = (4 * 95.047) / (95.047 + (15 * 100) + (3 * 108.883))
H.ref_v = (9 * 100) / (95.047 + (15 * 100) + (3 * 108.883))

function H.xyz2luv(xyz)
  local x, y, z = xyz.x, xyz.y, xyz.z
  if x + y + z == 0 then
    return { l = 0, u = 0, v = 0 }
  end

  local var_u = 4 * x / (x + 15 * y + 3 * z)
  local var_v = 9 * y / (x + 15 * y + 3 * z)
  local var_y = y / 100
  if var_y > 0.008856 then
    var_y = var_y ^ (1 / 3)
  else
    var_y = (7.787 * var_y) + (16 / 116)
  end

  local l = (116 * var_y) - 16
  local u = 13 * l * (var_u - H.ref_u)
  local v = 13 * l * (var_v - H.ref_v)
  return { l = l, u = u, v = v }
end

function H.luv2xyz(luv)
  if luv.l == 0 then
    return { x = 0, y = 0, z = 0 }
  end

  local var_y = (luv.l + 16) / 116
  if var_y ^ 3 > 0.008856 then
    var_y = var_y ^ 3
  else
    var_y = (var_y - 16 / 116) / 7.787
  end

  local var_u = luv.u / (13 * luv.l) + H.ref_u
  local var_v = luv.v / (13 * luv.l) + H.ref_v

  local y = var_y * 100
  local x = -(9 * y * var_u) / ((var_u - 4) * var_v - var_u * var_v)
  local z = (9 * y - 15 * var_v * y - var_v * x) / (3 * var_v)
  return { x = x, y = y, z = z }
end

------ CIELuv <-> CIELCh(uv)
H.tau = 2 * math.pi

function H.luv2lch(luv)
  local c = math.sqrt(luv.u ^ 2 + luv.v ^ 2)
  local h
  if c == 0 then
    h = 0
  else
    -- Convert [-pi, pi] radians to [0, 360] degrees
    h = (math.atan2(luv.v, luv.u) % H.tau) * 360 / H.tau
  end
  return { l = luv.l, c = c, h = h }
end

function H.lch2luv(lch)
  local angle = lch.h * H.tau / 360
  local u = lch.c * math.cos(angle)
  local v = lch.c * math.sin(angle)
  return { l = lch.l, u = u, v = v }
end

---- Distances
function H.dist_circle(x, y)
  local d = math.abs(x - y) % 360
  return d > 180 and (360 - d) or d
end

function H.dist_circle_set(set1, set2)
  -- Minimum distance between all pairs
  local dist = math.huge
  local d
  for _, x in pairs(set1) do
    for _, y in pairs(set2) do
      d = H.dist_circle(x, y)
      if dist > d then
        dist = d
      end
    end
  end
  return dist
end

function H.nearest_rgb_id(rgb_target, rgb_palette)
  local best_dist = math.huge
  local best_id, dist
  for id, rgb in pairs(rgb_palette) do
    dist = math.abs(rgb_target.r - rgb.r) + math.abs(rgb_target.g - rgb.g) + math.abs(rgb_target.b - rgb.b)
    if dist < best_dist then
      best_id, best_dist = id, dist
    end
  end

  return best_id
end

return MiniBase16
