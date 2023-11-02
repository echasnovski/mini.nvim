local severity = vim.diagnostic.severity
_G.diag_ns = vim.api.nvim_create_namespace('mock-diagnostics')

-- Open files
vim.cmd('edit tests/dir-extra/mocks/diagnostic-file-1')
_G.buf_id_1 = vim.api.nvim_get_current_buf()
vim.cmd('edit tests/dir-extra/mocks/diagnostic-file-2')
_G.buf_id_2 = vim.api.nvim_get_current_buf()

-- Define diagnostic
--stylua: ignore
_G.diagnostic_arr = {
  -- Several entries on one line
  { bufnr = buf_id_1, lnum = 0, end_lnum = 0, col = 0,  end_col = 5,  message = 'Error 1',   severity = severity.ERROR },
  { bufnr = buf_id_1, lnum = 0, end_lnum = 0, col = 6,  end_col = 13, message = 'Warning 1', severity = severity.WARN  },
  { bufnr = buf_id_1, lnum = 0, end_lnum = 0, col = 14, end_col = 18, message = 'Info 1',    severity = severity.INFO  },
  { bufnr = buf_id_1, lnum = 0, end_lnum = 0, col = 19, end_col = 23, message = 'Hint 1',    severity = severity.HINT  },

  -- Entries on separate lines not at line start
  { bufnr = buf_id_1, lnum = 1, end_lnum = 1, col = 2,  end_col = 7,  message = 'Error 2',   severity = severity.ERROR },
  { bufnr = buf_id_1, lnum = 2, end_lnum = 2, col = 2,  end_col = 9,  message = 'Warning 2', severity = severity.WARN  },
  { bufnr = buf_id_1, lnum = 3, end_lnum = 3, col = 2,  end_col = 6,  message = 'Info 2',    severity = severity.INFO  },
  { bufnr = buf_id_1, lnum = 4, end_lnum = 4, col = 2,  end_col = 6,  message = 'Hint 2',    severity = severity.HINT  },

  -- Another buffer
  { bufnr = buf_id_2, lnum = 0, end_lnum = 0, col = 0,  end_col = 5,  message = 'Error 3',   severity = severity.ERROR },
  { bufnr = buf_id_2, lnum = 1, end_lnum = 1, col = 0,  end_col = 7,  message = 'Warning 3', severity = severity.WARN  },
  { bufnr = buf_id_2, lnum = 2, end_lnum = 2, col = 0,  end_col = 4,  message = 'Info 3',    severity = severity.INFO  },
  { bufnr = buf_id_2, lnum = 3, end_lnum = 3, col = 0,  end_col = 4,  message = 'Hint 3',    severity = severity.HINT  },
}

-- Set diagnostic
vim.diagnostic.set(diag_ns, buf_id_1, vim.tbl_filter(function(x) return x.bufnr == buf_id_1 end, _G.diagnostic_arr), {})
vim.diagnostic.set(diag_ns, buf_id_2, vim.tbl_filter(function(x) return x.bufnr == buf_id_2 end, _G.diagnostic_arr), {})
