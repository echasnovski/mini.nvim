-- "Hot summer"
--
-- Params for `make_palette` used to make palette (colors in OKLch):
--   Dark:  bg=15-1-45; fg=85-1-270; saturation=fg:'medium'
--   Light: bg=90-1-45; fg=20-1-270; saturation=fg:'high'
--   Accent: 'yellow'
--
-- Notes:
-- - Fg hues have different temperature than bg for more contrast.
--   They are tweaked to maximize palette's bg colors visibility.
local palette

--stylua: ignore
if vim.o.background == 'dark' then
  palette = {
    bg_edge2 = '#0c0705', bg_edge = '#1b1512', bg = '#27211e', bg_mid = '#433c39', bg_mid2 = '#605855',
    fg_edge2 = '#eef1f8', fg_edge = '#e0e2e9', fg = '#d2d4db', fg_mid = '#b2b4bb', fg_mid2 = '#93949b',

    accent = '#f6cc9b', accent_bg = '#492c00',

    red    = '#fac0e4', red_bg    = '#3a0f2e',
    orange = '#ffc1b9', orange_bg = '#410d0c',
    yellow = '#f6cc9b', yellow_bg = '#492c00',
    green  = '#d1db9f', green_bg  = '#313600',
    cyan   = '#a6e5c3', cyan_bg   = '#003d26',
    azure  = '#93e4ee', azure_bg  = '#004a51',
    blue   = '#acd6ff', blue_bg   = '#002649',
    purple = '#d8caff', purple_bg = '#271844',
  }
else
  palette = {
    bg_edge2 = '#fcf4f0', bg_edge = '#f2eae6', bg = '#e9e1dd', bg_mid = '#c9c1bd', bg_mid2 = '#a8a19d',
    fg_edge2 = '#0b0d11', fg_edge = '#1d1e23', fg = '#2c2e33', fg_mid = '#47494f', fg_mid2 = '#64666c',

    accent = '#804e00', accent_bg = '#ffc888',

    red    = '#61004f', red_bg    = '#ffb2ee',
    orange = '#700011', orange_bg = '#ffaba5',
    yellow = '#804e00', yellow_bg = '#ffc888',
    green  = '#636900', green_bg  = '#e3ee65',
    cyan   = '#006f44', cyan_bg   = '#7fffbd',
    azure  = '#007e87', azure_bg  = '#79f4ff',
    blue   = '#004d84', blue_bg   = '#91caff',
    purple = '#370674', purple_bg = '#c5b3ff',
  }
end

require('mini.hues').apply_palette(palette)
vim.g.colors_name = 'minisummer'
