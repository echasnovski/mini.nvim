local minidoc = require('mini.doc')

if _G.MiniDoc == nil then minidoc.setup() end

local modules = {
  'ai',
  'align',
  'animate',
  'base16',
  'basics',
  'bufremove',
  'comment',
  'completion',
  'cursorword',
  'doc',
  'fuzzy',
  'indentscope',
  'jump',
  'jump2d',
  'map',
  'misc',
  'move',
  'pairs',
  'sessions',
  'starter',
  'statusline',
  'surround',
  'tabline',
  'test',
  'trailspace',
}

for _, m in ipairs(modules) do
  minidoc.generate({ 'lua/mini/' .. m .. '.lua' }, 'doc/mini-' .. m .. '.txt', { hooks = minidoc.default_hooks })
end

minidoc.generate({ 'lua/mini/init.lua' }, 'doc/mini.txt', { hooks = minidoc.default_hooks })
