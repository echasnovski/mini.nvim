-- "Cooling autumn"
--
-- Params for `make_palette` used to make palette (colors in OKLch):
--   Dark : bg=15-2-315; fg=85-1-100; saturation=fg:'lowmedium', bg:'medium'
--   Light: bg=90-1-315; fg=20-1-100; saturation=fg:'mediumhigh',bg:'high'
--   Accent: 'bg'
--
-- Notes:
-- - Fg hues have different temperature than bg for more contrast.
--   They are tweaked to maximize palette's bg colors visibility.
-- - Fg is less saturated than spring and summer for "cool" period.
-- - Bg is more saturated than fg for more legible diffs.
-- - Accent is 'bg' for `make_palette`, but `accent_bg` is set to `red_bg`
--   for colorful statusline.
--   No `accent='red'` to avoid accent be exactly red: improves legibility
--   of diff "delete" color (like in number column with 'mini.diff').
local palette

--stylua: ignore
if vim.o.background == 'dark' then
  palette = {
    bg_edge2 = '#0b060e', bg_edge = '#1a141d', bg = '#262029', bg_mid = '#423b45', bg_mid2 = '#5e5762',
    fg_edge2 = '#f3f1e9', fg_edge = '#e5e3db', fg = '#d7d5cd', fg_mid = '#b7b5ad', fg_mid2 = '#97958e',

    accent = '#e4caf1', accent_bg = '#3a0f2f',

    red    = '#f1c6e2', red_bg    = '#3a0f2f',
    orange = '#fac6c1', orange_bg = '#410d0d',
    yellow = '#efcfab', yellow_bg = '#492c00',
    green  = '#d3daad', green_bg  = '#323700',
    cyan   = '#b4e2c7', cyan_bg   = '#003c24',
    azure  = '#a7e1e8', azure_bg  = '#004b51',
    blue   = '#b8d9fc', blue_bg   = '#00284a',
    purple = '#d7cef9', purple_bg = '#261844',
  }
else
  palette = {
    bg_edge2 = '#f8f4fa', bg_edge = '#eeeaf0', bg = '#e5e1e7', bg_mid = '#c5c1c7', bg_mid2 = '#a4a0a6',
    fg_edge2 = '#0e0d09', fg_edge = '#1f1f1a', fg = '#2f2e29', fg_mid = '#4a4944', fg_mid2 = '#686661',

    accent = '#431256', accent_bg = '#ffb0e9',

    red    = '#52073f', red_bg    = '#ffb0e9',
    orange = '#5c0207', orange_bg = '#ffaba1',
    yellow = '#6c4300', yellow_bg = '#ffca87',
    green  = '#4b5400', green_bg  = '#ddf069',
    cyan   = '#005e3d', cyan_bg   = '#7bffc2',
    azure  = '#006a74', azure_bg  = '#7df1ff',
    blue   = '#003b6d', blue_bg   = '#92c8ff',
    purple = '#351962', purple_bg = '#cab3ff',
  }
end

require('mini.hues').apply_palette(palette)
vim.g.colors_name = 'miniautumn'
