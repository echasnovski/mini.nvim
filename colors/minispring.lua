-- "Blooming spring"
--
-- Params for `make_palette` used to make palette (colors in OKLch):
--   Dark : bg=15-3-135; fg=85-1-265; saturation='medium'
--   Light: bg=90-1-135; fg=20-1-265; saturation='high'
--   Accent: 'bg'
--
-- Notes:
-- - Fg hues have different temperature than bg for more contrast.
--   They are tweaked to maximize palette's bg colors visibility.
-- - Accent is 'bg' for `make_palette`, but `accent_bg` is set to `green_bg`
--   for colorful statusline.
--   No `accent='green'` to avoid accent be exactly green: improves legibility
--   of diff "add" color (like in number column with 'mini.diff').
local palette

--stylua: ignore
if vim.o.background == 'dark' then
  palette = {
    bg_edge2 = '#040b02', bg_edge = '#101a0b', bg = '#1c2617', bg_mid = '#374231', bg_mid2 = '#535f4d',
    fg_edge2 = '#eef1f7', fg_edge = '#e0e3e9', fg = '#d2d5db', fg_mid = '#b2b5bb', fg_mid2 = '#92959b',

    accent = '#bee2ad', accent_bg = '#00381d',

    red    = '#ffc1bf', red_bg    = '#410d12',
    orange = '#facb9e', orange_bg = '#492900',
    yellow = '#d8da9d', yellow_bg = '#373700',
    green  = '#abe5be', green_bg  = '#00381d',
    cyan   = '#94e5ea', cyan_bg   = '#004c4f',
    azure  = '#a9d8ff', azure_bg  = '#002d4d',
    blue   = '#d3ccff', blue_bg   = '#231946',
    purple = '#f7c2ea', purple_bg = '#381031',
  }
else
  palette = {
    bg_edge2 = '#f3f7f1', bg_edge = '#e9ede7', bg = '#e0e4de', bg_mid = '#c0c4be', bg_mid2 = '#a0a39e',
    fg_edge2 = '#0b0d11', fg_edge = '#1d1e23', fg = '#2c2e33', fg_mid = '#47494f', fg_mid2 = '#64666c',

    accent = '#2e5e00', accent_bg = '#80ffb8',

    red    = '#700015', red_bg    = '#ffaaa7',
    orange = '#804c00', orange_bg = '#ffc688',
    yellow = '#676900', yellow_bg = '#e6ed62',
    green  = '#006d3f', green_bg  = '#80ffb8',
    cyan   = '#007f86', cyan_bg   = '#72f6ff',
    azure  = '#005085', azure_bg  = '#90ccff',
    blue   = '#350775', blue_bg   = '#c2b3ff',
    purple = '#600051', purple_bg = '#ffb2f2',
  }
end

require('mini.hues').apply_palette(palette)
vim.g.colors_name = 'minispring'
