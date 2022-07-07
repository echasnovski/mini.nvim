local minidoc = require('mini.doc')

if _G.MiniDoc == nil then minidoc.setup() end
minidoc.generate(nil, nil, { hooks = minidoc.default_hooks })
