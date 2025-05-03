return {
  is_menu_visible = function()
    table.insert(_G.log, 'blink.is_menu_visible')
    return _G.blink_is_menu_visible_res
  end,

  get_selected_item = function()
    table.insert(_G.log, 'blink.get_selected_item')
    return _G.blink_get_selected_item_res
  end,

  select_next = function() table.insert(_G.log, 'blink.select_next') end,
  select_prev = function() table.insert(_G.log, 'blink.select_prev') end,
  accept = function() table.insert(_G.log, 'blink.accept') end,
}
