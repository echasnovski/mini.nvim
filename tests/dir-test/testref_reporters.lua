local new_set = MiniTest.new_set

local T = new_set()

--stylua: ignore start
T['first group'] = new_set()
T['first group']['pass'] = function() end
T['first group']['pass with notes'] = function() MiniTest.add_note('Passed note') end
T['first group']['fail'] = function() error('Custom error', 0) end
T['first group']['fail with notes'] = function()
  MiniTest.add_note('Failed note')
  error('Custom error after note', 0)
end

T['second group'] = new_set()
T['second group']['pass'] = function() end
T['second group']['pass with notes'] = function() MiniTest.add_note('Passed note #2') end
T['second group']['fail'] = function() error('Custom error #2', 0) end
T['second group']['fail with notes'] = function()
  MiniTest.add_note('Failed note #2')
  error('Custom error after note #2', 0)
end

T['third group with \n in name'] = new_set()
T['third group with \n in name']['case with \n in name'] = function() MiniTest.add_note('Passed note #3') end
--stylua: ignore end

return T
