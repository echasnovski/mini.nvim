return {
  { prefix = 'lua_a', body = 'LUA_A=$1', desc = 'Desc LUA_A' },
  { prefix = 'lua_b', body = 'LUA_B=$1', description = 'Desc LUA_B' },

  { prefix = 1, desc = 'Not snippet data #1' },

  { prefix = nil, body = 'LUA_C=$1' },
  { prefix = 'd', body = 'D1=$1' },
  { prefix = 'd', body = nil, desc = 'Dupl2' },

  2,
}
