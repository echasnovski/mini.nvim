local minitest = require('mini.test')

if _G.MiniDoc == nil then
  minitest.setup()
end
minitest.run()
