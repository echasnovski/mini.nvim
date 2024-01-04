local minidoc = require('mini.doc')

if _G.MiniDoc == nil then minidoc.setup() end

local modules = {
  'ai',
  'align',
  'animate',
  'base16',
  'basics',
  'bracketed',
  'bufremove',
  'clue',
  'colors',
  'comment',
  'completion',
  'cursorword',
  'doc',
  'extra',
  'files',
  'fuzzy',
  'hipatterns',
  'hues',
  'indentscope',
  'jump',
  'jump2d',
  'map',
  'misc',
  'move',
  'notify',
  'operators',
  'pairs',
  'pick',
  'sessions',
  'splitjoin',
  'starter',
  'statusline',
  'surround',
  'tabline',
  'test',
  'trailspace',
  'visits',
}

local hooks = vim.deepcopy(MiniDoc.default_hooks)

hooks.write_pre = function(lines)
  -- Remove first two lines with `======` and `------` delimiters to comply
  -- with `:h local-additions` template
  table.remove(lines, 1)
  table.remove(lines, 1)
  return lines
end

MiniDoc.generate({ 'lua/mini/init.lua' }, 'doc/mini.txt', { hooks = hooks })

for _, m in ipairs(modules) do
  MiniDoc.generate({ 'lua/mini/' .. m .. '.lua' }, 'doc/mini-' .. m .. '.txt', { hooks = hooks })
end
