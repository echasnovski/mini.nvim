local T = MiniTest.new_set()

T['run_at_location()'] = function()
  -- Should be the only one collected with `run_at_location()`
end

T['extra case'] = function() end

return T
