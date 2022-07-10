--stylua: ignore start
--- Tests for inferring from afterline

local M = {}

-- Functions

--- This function definition should be inferred
M.a = function(x, y)
  print('M.a')
end

--- This function definition should not be inferred (not from first column)
  M.a_no = function() end

--- This function definition should be inferred
local function b(x, y)
  print('b')
end

--- This function definition should not be inferred (not from first column)
  local function b_no() end

--- This function definition should be inferred
M.c = function(x, y)
  print('M.c')
end

--- This function definition should be inferred
M.c_1=function() end

--- This function definition should not be inferred (not from first column)
  M.c_no = function() end

--- This function definition should be inferred
local d = function(x, y)
  print('d')
end

--- This function definition should be inferred
local d_1=function() end

--- This function definition should not be inferred (not from first column)
  local d_no = function() end


-- Assignments

--- This assignment should be inferred
M.A = 1

--- This assignment should be inferred
M.A_1=1

--- This assignment should not be inferred (not from first column)
  M.A_no = 1

--- This assignment should be inferred
local B = 1

--- This assignment should be inferred
local B_1=1

--- This assignment should not be inferred (not from first column)
  local B_no = 1

return M
--stylua: ignore end
