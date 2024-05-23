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
