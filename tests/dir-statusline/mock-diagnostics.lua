vim.lsp.buf_get_clients = function() return { 'mock client' } end

vim.diagnostic.get = function(buf_id, opts)
  local severity = vim.diagnostic.severity
  local n = ({ [severity.ERROR] = 4, [severity.WARN] = 3, [severity.INFO] = 2, [severity.HINT] = 1 })[opts.severity]

  -- Original returns array with one entry per diagnostic element
  return (vim.split(string.rep('a', n), ''))
end
