local severity = vim.diagnostic.severity

vim.diagnostic.get = function()
  local cur_buf_id = vim.api.nvim_get_current_buf()
  local res = {}
  local add = function(severity_level_name, lnum, end_lnum, col, end_col)
    table.insert(res, {
      bufnr = cur_buf_id,
      lnum = lnum - 1,
      end_lnum = end_lnum - 1,
      col = col - 1,
      end_col = end_col - 1,
      severity = severity[severity_level_name],
    })
  end

  -- Multiple entries on single line
  add('HINT', 1, 1, 1, 4)
  add('INFO', 1, 1, 2, 5)
  add('WARN', 1, 1, 3, 6)
  add('ERROR', 1, 1, 4, 7)

  -- One per line entry
  add('HINT', 4, 4, 1, 1)
  add('INFO', 7, 7, 1, 1)
  add('WARN', 10, 10, 1, 1)
  add('ERROR', 13, 13, 1, 1)

  -- Multiline entry
  add('ERROR', 1, 5, 1, 1)

  -- Out of bounds data
  add('ERROR', 0, 0, 1, 1)
  add('ERROR', 1000, 1000, 1, 1)

  return res
end
