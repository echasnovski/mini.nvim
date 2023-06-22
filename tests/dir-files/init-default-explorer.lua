dofile('scripts/minimal_init.lua')

-- Make test more portable
vim.cmd('source tests/dir-files/mock-win-functions.lua')
vim.o.laststatus = 0

-- Ensure instance size
vim.o.lines = 15
vim.o.columns = 80

-- Set up module
local use_as_default_explorer = os.getenv('USE_AS_DEFAULT_EXPLORER') == 'true'
require('mini.files').setup({ options = { use_as_default_explorer = use_as_default_explorer } })
