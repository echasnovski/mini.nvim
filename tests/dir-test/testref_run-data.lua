local new_set = MiniTest.new_set

local T = new_set()

T['data'] = new_set({ data = { a = 1, b = 2 } })

T['data']['first level'] = function() end

T['data']['nested'] = new_set({ data = { a = 10, c = 30 } })

T['data']['nested']['should override'] = function() end

return T
