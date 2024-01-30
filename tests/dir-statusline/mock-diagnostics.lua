vim.lsp.buf_get_clients = function() return { 'mock client' } end
if vim.fn.has('nvim-0.8') == 1 then
  vim.api.nvim_exec_autocmds('LspAttach', { data = { client_id = 1 } })
  _G.detach_lsp = function() vim.api.nvim_exec_autocmds('LspDetach', { data = { client_id = 1 } }) end
end

vim.diagnostic.get = function(_, _)
  local s = vim.diagnostic.severity
  return {
    { severity = s.ERROR },
    { severity = s.WARN },
    { severity = s.INFO },
    { severity = s.HINT },
    { severity = s.ERROR },
    { severity = s.WARN },
    { severity = s.INFO },
    { severity = s.ERROR },
    { severity = s.WARN },
    { severity = s.ERROR },
  }
end

if vim.fn.has('nvim-0.10') == 1 then
  vim.diagnostic.count = function(_, _)
    local s = vim.diagnostic.severity
    return { [s.ERROR] = 4, [s.WARN] = 3, [s.INFO] = 2, [s.HINT] = 1 }
  end
end
