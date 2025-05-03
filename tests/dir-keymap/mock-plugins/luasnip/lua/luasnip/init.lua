return {
  jumpable = function()
    table.insert(_G.log, 'luasnip.jumpable')
    return _G.luasnip_jumpable_res
  end,

  expandable = function()
    table.insert(_G.log, 'luasnip.expandable')
    return _G.luasnip_expandable_res
  end,

  jump = function(dir) table.insert(_G.log, 'luasnip.jump ' .. dir) end,
  expand = function() table.insert(_G.log, 'luasnip.expand') end,
}
