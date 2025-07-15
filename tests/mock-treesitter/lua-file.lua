local M = {}

function M.a(u, vv, www)
  return function() print(u .. vv) end
end

M.b = function()
  local x = 1 + 1
  print('1 + 1 = ' .. x)
  return true
end

return M
