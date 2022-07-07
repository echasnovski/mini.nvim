local new_set = MiniTest.new_set

local f = function() end
local T = new_set({ hooks = { pre_once = f, pre_case = f, post_case = f, post_once = f } })

T['case 1'] = function() error('Some error') end
T['case 2'] = function() end

return T
