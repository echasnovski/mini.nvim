_G.n_lsp_clients = 0
local mock_buf_clients = function()
  local res = {}
  for i = 1, _G.n_lsp_clients do
    res[i] = { id = i }
  end
  return res
end
vim.lsp.buf_get_clients = mock_buf_clients
vim.lsp.get_clients = mock_buf_clients

_G.attach_lsp = function()
  _G.n_lsp_clients = _G.n_lsp_clients + 1
  vim.api.nvim_exec_autocmds('LspAttach', { data = { client_id = _G.n_lsp_clients } })
end

_G.detach_lsp = function()
  local n = _G.n_lsp_clients
  if n == 0 then return end

  _G.n_lsp_clients = _G.n_lsp_clients - 1
  vim.api.nvim_exec_autocmds('LspDetach', { data = { client_id = n } })
end

_G.attach_lsp()
