local new_set = MiniTest.new_set

local T = new_set()

-- Collection order -----------------------------------------------------------
T['order'] = new_set(nil, { ['From initial call'] = function() return 1 end })

T['order']['zzz First added'] = function() end
T['order']['aaa Second added'] = function() end

-- Implicit additions should be also collected
table.insert(T['order'], function() end)

return T
