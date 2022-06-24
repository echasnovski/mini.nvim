local T = MiniTest.new_set()
T['parametrize'] = MiniTest.new_set({ parametrize = { 'a' } }, { test = function() end })
return T
