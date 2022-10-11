_G.n_test_integration_calls = 0

_G.test_integration = function()
  _G.n_test_integration_calls = _G.n_test_integration_calls + 1

  -- Match lines which start with at least three whitespaces
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  local res = {}
  for i, l in ipairs(lines) do
    if l:find('^%s%s%s') ~= nil then table.insert(res, { line = i, hl_group = 'Operator' }) end
  end
  return res
end
