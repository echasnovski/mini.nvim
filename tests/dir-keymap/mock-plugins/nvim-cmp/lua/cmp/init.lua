return {
  visible = function()
    table.insert(_G.log, 'cmp.visible')
    return _G.cmp_visible_res
  end,

  get_selected_entry = function()
    table.insert(_G.log, 'cmp.get_selected_entry')
    return _G.cmp_get_selected_entry_res
  end,

  select_next_item = function() table.insert(_G.log, 'cmp.select_next_item') end,
  select_prev_item = function() table.insert(_G.log, 'cmp.select_prev_item') end,
  confirm = function() table.insert(_G.log, 'cmp.confirm') end,
}
