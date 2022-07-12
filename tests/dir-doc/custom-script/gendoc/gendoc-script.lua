-- Global config should be later restored
MiniDoc.config.aaa = true

return require('mini.doc').generate(nil, 'output.txt', {})
