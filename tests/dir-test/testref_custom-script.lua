_G.custom_script_result = 'This actually ran'

-- Dummy call to `run()` to ensure there is no infinite loop
MiniTest.run({
  collect = {
    find_files = function()
      return {}
    end,
  },
})
