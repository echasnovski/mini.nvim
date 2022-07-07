local T = MiniTest.new_set()

local finally_with_error, finally_no_error = false, false

T['finally() with error'] = function()
  MiniTest.finally(function() finally_with_error = true end)
  error()
end

T['finally() with error; check'] = function() MiniTest.expect.equality(finally_with_error, true) end

T['finally() no error'] = function()
  MiniTest.finally(function() finally_no_error = true end)
  local res = true
  return res
end

T['finally() no error; check'] = function() MiniTest.expect.equality(finally_no_error, true) end

T['skip(); no message'] = function()
  MiniTest.skip()
  error('This error should not take effect')
end

T['skip(); with message'] = function()
  MiniTest.skip('This is a custom skip message')
  error('This error should not take effect')
end

T['add_note()'] = function() MiniTest.add_note('This note should be appended') end

return T
