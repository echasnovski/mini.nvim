-- 'Minicyan' color scheme
-- Derived from base16 (https://github.com/chriskempson/base16) and
-- mini_palette palette generator
local use_cterm, palette

-- Dark palette is an output of 'MiniBase16.mini_palette':
-- - Background '#0A2A2A' (LCh(uv) = 15-10-192)
-- - Foreground '#D0D0D0' (Lch(uv) = 83-0-0)
-- - Accent chroma 50
if vim.o.background == 'dark' then
  palette = {
    base00 = '#0a2a2a',
    base01 = '#324747',
    base02 = '#556868',
    base03 = '#788a8a',
    base04 = '#bbbbbb',
    base05 = '#d0d0d0',
    base06 = '#e6e6e6',
    base07 = '#fcfcfc',
    base08 = '#ebcd91',
    base09 = '#9f8340',
    base0A = '#209870',
    base0B = '#82e3ba',
    base0C = '#bb6d9b',
    base0D = '#a9d4ff',
    base0E = '#ffb9e5',
    base0F = '#598ab9',
  }
  use_cterm = {
    base00 = 235,
    base01 = 238,
    base02 = 241,
    base03 = 245,
    base04 = 250,
    base05 = 252,
    base06 = 7,
    base07 = 15,
    base08 = 186,
    base09 = 137,
    base0A = 29,
    base0B = 115,
    base0C = 132,
    base0D = 153,
    base0E = 218,
    base0F = 67,
  }
end

-- Light palette is an 'inverted dark', output of 'MiniBase16.mini_palette':
-- - Background '#C0D2D2' (LCh(uv) = 83-10-192)
-- - Foreground '#262626' (Lch(uv) = 15-0-0)
-- - Accent chroma 80
if vim.o.background == 'light' then
  palette = {
    base00 = '#c0d2d2',
    base01 = '#9badad',
    base02 = '#778989',
    base03 = '#546767',
    base04 = '#353535',
    base05 = '#262626',
    base06 = '#181818',
    base07 = '#040404',
    base08 = '#402100',
    base09 = '#855f00',
    base0A = '#007d3c',
    base0B = '#003d00',
    base0C = '#b12985',
    base0D = '#003fb6',
    base0E = '#7e0052',
    base0F = '#006cb4',
  }
  use_cterm = {
    base00 = 252,
    base01 = 248,
    base02 = 102,
    base03 = 241,
    base04 = 236,
    base05 = 235,
    base06 = 234,
    base07 = 0,
    base08 = 52,
    base09 = 94,
    base0A = 29,
    base0B = 22,
    base0C = 126,
    base0D = 25,
    base0E = 89,
    base0F = 25,
  }
end

if palette then
  require('mini.base16').setup({ palette = palette, use_cterm = use_cterm })
  vim.g.colors_name = 'minicyan'
end
