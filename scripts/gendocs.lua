local docgen = require('docgen')

local docs = {}

docs.run = function()
  local input_files = {
    './lua/mini/init.lua',
    './lua/mini/base16.lua',
    './lua/mini/bufremove.lua',
    './lua/mini/comment.lua',
    './lua/mini/completion.lua',
    './lua/mini/cursorword.lua',
    './lua/mini/fuzzy.lua',
    './lua/mini/misc.lua',
    './lua/mini/pairs.lua',
    './lua/mini/statusline.lua',
    './lua/mini/surround.lua',
    './lua/mini/tabline.lua',
    './lua/mini/trailspace.lua',
  }

  local output_file = './doc/mini.txt'
  local output_file_handle = io.open(output_file, 'w')

  for _, input_file in ipairs(input_files) do
    docgen.write(input_file, output_file_handle)
  end

  output_file_handle:write(' vim:tw=78:ts=8:ft=help:norl:\n')
  output_file_handle:close()
  vim.cmd([[checktime]])
end

docs.run()

return docs
