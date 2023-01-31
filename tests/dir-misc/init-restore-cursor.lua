dofile('scripts/minimal_init.lua')

-- Enable reading correct shada file
vim.o.shadafile = 'tests/dir-misc/restore-cursor.shada'

-- Set testable size
vim.o.lines = 10
vim.o.columns = 20

-- Set up tested functionality based on test type
local test_type = vim.env.RESTORE_CURSOR_TEST_TYPE

if test_type == 'set-not-normal-buftype' then vim.cmd('au BufReadPost * set buftype=help') end
if test_type == 'set-position' then vim.cmd('au BufReadPost * call cursor(4, 0)') end
if test_type == 'make-folds' then vim.cmd('au BufReadPost * 2,3 fold | 9,10 fold') end

local opts = {}
if test_type == 'not-center' then opts = { center = false } end
if test_type == 'ignore-lua' then opts = { ignore_filetype = { 'lua' } } end

require('mini.misc').setup_restore_cursor(opts)
