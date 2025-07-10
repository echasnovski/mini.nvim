-- "Icy winter"
--
-- Params for `make_palette` used to make palette (colors in OKLch):
--   Dark:  bg=15-3-225; fg=85-1-80; saturation=fg:'lowmedium', bg:'medium'
--   Light: bg=90-1-225; fg=20-1-80; saturation=fg:'mediumhigh',bg:'high'
--   Accent: 'azure'
--
-- Notes:
-- - Fg hues have different temperature than bg for more contrast.
--   They are tweaked to maximize palette's bg colors visibility.
-- - Fg is less saturated than spring and summer for "cool" period.
-- - Bg is more saturated than fg for more legible diffs.
local palette

--stylua: ignore
if vim.o.background == 'dark' then
  palette = {
    bg_edge2 = '#000f15', bg_edge = '#051a20', bg = '#11262d', bg_mid = '#2c4249', bg_mid2 = '#485f67',
    fg_edge2 = '#f4f0e9', fg_edge = '#e6e2db', fg = '#d8d4cd', fg_mid = '#b8b4ad', fg_mid2 = '#98948e',

    accent = '#b3daf9', accent_bg = '#00324f',

    red    = '#fac5c7',    red_bg = '#410d14',
    orange = '#f2ccad', orange_bg = '#492600',
    yellow = '#d9d8aa', yellow_bg = '#3a3800',
    green  = '#b8e1c1',  green_bg = '#003415',
    cyan   = '#a6e1e2',   cyan_bg = '#004c4e',
    azure  = '#b3daf9',  azure_bg = '#00324f',
    blue   = '#d1cffb',   blue_bg = '#211a46',
    purple = '#edc7e7', purple_bg = '#371134',
  }
else
  palette = {
    bg_edge2 = '#eff7fb', bg_edge = '#e5edf1', bg = '#dce4e8', bg_mid = '#bcc4c8', bg_mid2 = '#9ca4a7',
    fg_edge2 = '#0f0d09', fg_edge = '#211e1a', fg = '#312e29', fg_mid = '#4c4944', fg_mid2 = '#6a6661',

    accent = '#014772', accent_bg = '#90ceff',

    red    = '#5c0113', red_bg    = '#ffaaaa',
    orange = '#6c3e00', orange_bg = '#ffc488',
    yellow = '#565600', yellow_bg = '#eaeb5f',
    green  = '#00562e', green_bg  = '#83ffb3',
    cyan   = '#016d71', cyan_bg   = '#6af9ff',
    azure  = '#014772', azure_bg  = '#90ceff',
    blue   = '#301d65', blue_bg   = '#beb3ff',
    purple = '#4f0b46', purple_bg = '#ffb3f6',
  }
end

require('mini.hues').apply_palette(palette)
vim.g.colors_name = 'miniwinter'
