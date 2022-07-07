vim.lsp.buf_get_clients = function() return { 'mock client' } end

-- Neovim <= 0.5.1
vim.lsp.diagnostic.get_count =
  function(buf_id, id) return ({ Error = 4, Warning = 3, Information = 2, Hint = 1 })[id] end

-- Neovim >= 0.6
if vim.diagnostic == nil then vim.diagnostic = {} end

vim.diagnostic.get = function(buf_id, opts)
  local severity = vim.diagnostic.severity
  local n = ({ [severity.ERROR] = 4, [severity.WARN] = 3, [severity.INFO] = 2, [severity.HINT] = 1 })[opts.severity]

  -- Original returns array with one entry per diagnostic element
  return (vim.split(string.rep('a', n), ''))
end
