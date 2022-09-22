local minidoc = require('mini.doc')

if _G.MiniDoc == nil then minidoc.setup() end

minidoc.generate({ 'lua/mini/init.lua' }, 'doc/mini.txt', { hooks = minidoc.default_hooks })

local modules = {
  'ai',
  'align',
  'base16',
  'bufremove',
  'comment',
  'completion',
  'cursorword',
  'doc',
  'fuzzy',
  'indentscope',
  'jump',
  'jump2d',
  'misc',
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
