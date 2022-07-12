_G.custom_script_result = 'This actually ran'

-- Dummy call to `run()` to ensure there is no infinite loop
MiniTest.run({
  collect = {
    find_files = function() return {} end,
  },
})

-- Buffer local and global configs should be later restored
MiniTest.config.aaa = true
vim.b.minitest_config = { aaa = true }
