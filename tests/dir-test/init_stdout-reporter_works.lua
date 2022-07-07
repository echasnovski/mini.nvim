vim.cmd('set rtp+=.')

require('mini.test').setup()

local group_depth = tonumber(vim.env.TEST_GROUP_DEPTH)

local quit_on_finish
if vim.env.TEST_QUIT_ON_FINISH ~= nil then quit_on_finish = vim.env.TEST_QUIT_ON_FINISH == 'true' end

local reporter = MiniTest.gen_reporter.stdout({
  group_depth = group_depth,
  quit_on_finish = quit_on_finish,
})

MiniTest.run_file('tests/dir-test/testref_reporters.lua', { execute = { reporter = reporter } })
