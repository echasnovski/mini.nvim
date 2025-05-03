return {
  autopairs_cr = function()
    table.insert(_G.log, 'nvimautopairs.autopairs_cr')
    -- Mock exactly how 'nvim-autopairs' works here
    local res = '<C-G>u<CR><Cmd>normal!<Space>====<CR><Up><End><CR>'
    return vim.api.nvim_replace_termcodes(res, true, true, true)
  end,

  autopairs_bs = function()
    table.insert(_G.log, 'nvimautopairs.autopairs_bs')
    -- Mock exactly how 'nvim-autopairs' works here
    local res = '<C-G>U<BS><Del>'
    return vim.api.nvim_replace_termcodes(res, true, true, true)
  end,
}
