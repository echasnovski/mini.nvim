local lines = {
  'Error Warning Info Hint',
  '  Error  ',
  '  Warning  ',
  '  Info  ',
  '  Hint  ',
  'Hint Info Warning Error',
}

local severity = vim.diagnostic.severity

--stylua: ignore
local diagnostic_arr = {
  { lnum = 0, end_lnum = 0, col = 0,  end_col = 5,  message = 'Error 1',   severity = severity.ERROR },
  { lnum = 0, end_lnum = 0, col = 6,  end_col = 13, message = 'Warning 1', severity = severity.WARN  },
  { lnum = 0, end_lnum = 0, col = 14, end_col = 18, message = 'Info 1',    severity = severity.INFO  },
  { lnum = 0, end_lnum = 0, col = 19, end_col = 23, message = 'Hint 1',    severity = severity.HINT  },
  { lnum = 1, end_lnum = 1, col = 2,  end_col = 7,  message = 'Error 2',   severity = severity.ERROR },
  { lnum = 2, end_lnum = 2, col = 2,  end_col = 9,  message = 'Warning 2', severity = severity.WARN  },
  { lnum = 3, end_lnum = 3, col = 2,  end_col = 6,  message = 'Info 2',    severity = severity.INFO  },
  { lnum = 4, end_lnum = 4, col = 2,  end_col = 6,  message = 'Hint 2',    severity = severity.HINT  },
  { lnum = 5, end_lnum = 5, col = 0,  end_col = 4,  message = 'Hint 3',    severity = severity.HINT  },
  { lnum = 5, end_lnum = 5, col = 5,  end_col = 9,  message = 'Info 3',    severity = severity.INFO  },
  { lnum = 5, end_lnum = 5, col = 10, end_col = 17, message = 'Warning 3', severity = severity.WARN  },
  { lnum = 5, end_lnum = 5, col = 18, end_col = 23, message = 'Error 3',   severity = severity.ERROR },
}

local filter = function(severity_level)
  return vim.tbl_filter(function(x) return x.severity == severity[severity_level] end, diagnostic_arr)
end

local convert_to_cursor_positions = function(arr)
  return vim.tbl_map(function(x) return { x.lnum + 1, x.col } end, arr)
end

local cursor_positions = {
  all = convert_to_cursor_positions(diagnostic_arr),
  error = convert_to_cursor_positions(filter('ERROR')),
  warning = convert_to_cursor_positions(filter('WARN')),
  info = convert_to_cursor_positions(filter('INFO')),
  hint = convert_to_cursor_positions(filter('HINT')),
  error_warning = convert_to_cursor_positions(
    vim.tbl_filter(function(x) return x.severity == severity.ERROR or x.severity == severity.WARN end, diagnostic_arr)
  ),
}

return { diagnostic_arr = diagnostic_arr, lines = lines, cursor_positions = cursor_positions }
