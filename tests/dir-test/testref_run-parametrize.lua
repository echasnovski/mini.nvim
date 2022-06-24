local new_set = MiniTest.new_set

local T = new_set()

local error_vararg = function(...)
  local args = vim.tbl_map(vim.inspect, { ... })
  error('Passed arguments: ' .. table.concat(args, ', '))
end

T['parametrize'] = new_set({ parametrize = { { 'a' }, { 'b' } } })

-- Should be parametrized with 'a' and 'b'
T['parametrize']['first level'] = error_vararg

T['parametrize']['nested'] = new_set({ parametrize = { { 1 }, { 2 } } })

-- Should be parametrized with cartesian product of {'a', 'b'} and {1, 2}
T['parametrize']['nested']['test'] = error_vararg

T['multiple args'] = new_set({ parametrize = { { 'a', 'a' }, { 'b', 'b' } } })

T['multiple args']['nested'] = new_set({ parametrize = { { 1, 1 }, { 2, 2 } } })

-- Should be parametrized with cartesian product and each have 4 arguments
T['multiple args']['nested']['test'] = error_vararg

return T
