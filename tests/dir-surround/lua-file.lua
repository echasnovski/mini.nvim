local M = {}

function M.a(x, y)
  return function() print(x .. y) end
end

M.b = function()
  local x = 1 + 1
  print('1 + 1 = ' .. x)
  return true
end

return M
