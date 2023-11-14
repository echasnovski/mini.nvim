local filename = vim.fn.fnamemodify('tests/dir-extra/real-files/a.lua', ':p')

_G.lsp_buf_calls = {}

local make_context = function(lsp_method)
  return {
    bufnr = vim.api.nvim_get_current_buf(),
    method = lsp_method,
    -- There are more fields, but none are relevant
  }
end

vim.lsp.buf.declaration = function(opts)
  table.insert(_G.lsp_buf_calls, 'declaration')
  local data = {
    context = make_context('textDocument/declaration'),
    items = { { col = 16, filename = filename, lnum = 3, text = '  x = math.max(a, 2),' } },
    title = 'Declaration',
  }
  opts.on_list(data)
end

vim.lsp.buf.definition = function(opts)
  table.insert(_G.lsp_buf_calls, 'definition')
  local data = {
    context = make_context('textDocument/definition'),
    items = { { col = 16, filename = filename, lnum = 3, text = '  x = math.max(a, 2),' } },
    title = 'Definition',
  }
  opts.on_list(data)
end

vim.lsp.buf.document_symbol = function(opts)
  table.insert(_G.lsp_buf_calls, 'document_symbol')
  local data = {
    context = make_context('textDocument/documentSymbol'),
    items = {
      { col = 7, filename = filename, kind = 'Number', lnum = 1, text = '[Number] a' },
      { col = 7, filename = filename, kind = 'Object', lnum = 2, text = '[Object] t' },
      { col = 3, filename = filename, kind = 'Variable', lnum = 3, text = '[Variable] x' },
      { col = 3, filename = filename, kind = 'Variable', lnum = 4, text = '[Variable] y' },
    },
    title = 'Symbols in a.lua',
  }
  opts.on_list(data)
end

vim.lsp.buf.implementation = function(opts)
  table.insert(_G.lsp_buf_calls, 'implementation')
  local data = {
    context = make_context('textDocument/implementation'),
    items = { { col = 16, filename = filename, lnum = 3, text = '  x = math.max(a, 2),' } },
    title = 'Implementation',
  }
  opts.on_list(data)
end

vim.lsp.buf.references = function(_, opts)
  table.insert(_G.lsp_buf_calls, 'references')
  local data = {
    context = make_context('textDocument/references'),
    items = {
      { col = 7, filename = filename, lnum = 1, text = 'local a = 1' },
      { col = 16, filename = filename, lnum = 3, text = '  x = math.max(a, 2),' },
      { col = 16, filename = filename, lnum = 4, text = '  y = math.min(a, 2),' },
    },
    title = 'References',
  }
  opts.on_list(data)
end

vim.lsp.buf.type_definition = function(opts)
  table.insert(_G.lsp_buf_calls, 'type_definition')
  local data = {
    context = make_context('textDocument/typeDefinition'),
    items = { { col = 16, filename = filename, lnum = 3, text = '  x = math.max(a, 2),' } },
    title = 'Type definition',
  }
  opts.on_list(data)
end

vim.lsp.buf.workspace_symbol = function(query, opts)
  table.insert(_G.lsp_buf_calls, 'workspace_symbol')
  _G.workspace_symbol_query = query
  local data = {
    context = make_context('textDocument/workspaceSymbol'),
    items = {
      { col = 7, filename = filename, kind = 'Number', lnum = 1, text = '[Number] a' },
      { col = 7, filename = filename, kind = 'Object', lnum = 2, text = '[Object] t' },
      { col = 3, filename = filename, kind = 'Variable', lnum = 3, text = '[Variable] x' },
      { col = 3, filename = filename, kind = 'Variable', lnum = 4, text = '[Variable] y' },
    },
    title = "Symbols matching ''",
  }
  opts.on_list(data)
end
