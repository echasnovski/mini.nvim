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
  'colors',
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
  'splitjoin',
  'starter',
  'statusline',
  'surround',
  'tabline',
  'test',
  'trailspace',
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
