_G.Months = {}

--stylua: ignore start
Months.items = {
  { name = 'January',   kind = 1},
  { name = 'February',  kind = 1 },
  { name = 'March',     kind = 2 },
  { name = 'April',     kind = 2 },
  { name = 'May',       kind = 2 },
  { name = 'June',      kind = 3 },
  { name = 'July',      kind = 3 },
  { name = 'August',    kind = 3 },
  { name = 'September', kind = 4 },
  { name = 'October',   kind = 4 },
  { name = 'November',  kind = 4 },
  { name = 'December',  kind = 1 },
}

Months.data = {
  January   = { documentation = 'Month #01' },
  February  = { documentation = 'Month #02' },
  March     = { documentation = 'Month #03' },
  April     = { documentation = 'Month #04' },
  May       = { documentation = 'Month #05' },
  June      = { documentation = 'Month #06' },
  July      = { documentation = 'Month #07' },
  August    = { documentation = 'Month #08' },
  September = { documentation = 'Month #09' },
  October   = { documentation = 'Month #10' },
  November  = { documentation = 'Month #11' },
  December  = { documentation = string.rep('a ', 1000) },
}
--stylua: ignore end

local construct_additionTextEdits = function(id, name)
  return {
    {
      newText = ('from months.%s import %s\n'):format(id, name),
      range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = 0, character = 0 },
      },
    },
  }
end

Months.requests = {
  ['textDocument/completion'] = function(params)
    local items = {}
    for i, item in ipairs(Months.items) do
      local res = { label = item.name, kind = item.kind, sortText = ('%03d'):format(i) }
      -- Mock additionalTextEdits as in `pyright`
      if vim.tbl_contains({ 'September', 'November' }, item.name) then
        res.additionalTextEdits = construct_additionTextEdits('completion', item.name)
      end
      table.insert(items, res)
    end

    return { { result = { items = items } } }
  end,

  ['completionItem/resolve'] = function(params)
    params.documentation = { kind = 'markdown', value = Months.data[params.label].documentation }
    -- Mock additionalTextEdits as in `typescript-language-server`
    if vim.tbl_contains({ 'October', 'November' }, params.label) then
      params.additionalTextEdits = construct_additionTextEdits('resolve', params.label)
    end
    return { { result = params } }
  end,

  ['textDocument/signatureHelp'] = function(params)
    local n_line, n_col = params.position.line, params.position.character
    local line = vim.api.nvim_buf_get_lines(0, n_line, n_line + 1, false)[1]
    line = line:sub(1, n_col)

    local after_open_paren = line:match('%(.*$') or line
    local after_close_paren = line:match('%).*$') or line

    -- Stop showing signature help after closing bracket
    if after_close_paren:len() < after_open_paren:len() then return { {} } end

    -- Compute active parameter id by counting number of ',' from latest '('
    local _, active_param_id = after_open_paren:gsub('%,', '%,')

    -- Compute what is displayed in signature help: text and parameter info
    -- (for highlighting) based on latest word
    local word = line:match('%S+$')
    local label, parameters
    if word == 'long(' then
      label = string.rep('a ', 1000)
    else
      label = 'abc(param1, param2)'
      parameters = { { label = { 4, 10 } }, { label = { 12, 18 } } }
    end

    -- Construct output
    local signature = {
      activeParameter = active_param_id,
      label = label,
      parameters = parameters,
    }
    return { { result = { signatures = { signature } } } }
  end,
}

-- Replace builtin functions with custom testable ones ========================
vim.lsp.buf_request_all = function(bufnr, method, params, callback)
  local requests = Months.requests[method]
  if requests == nil then return end
  callback(requests(params))
end

vim.lsp.buf_get_clients = function(bufnr)
  return {
    {
      name = 'months-lsp',
      offset_encoding = 'utf-16',
      server_capabilities = {
        completionProvider = { resolveProvider = true, triggerCharacters = { '.' } },
        signatureHelpProvider = { triggerCharacters = { '(', ',' } },
      },
    },
  }
end

vim.lsp.get_client_by_id = function(client_id) return vim.lsp.buf_get_clients(0)[client_id] end
