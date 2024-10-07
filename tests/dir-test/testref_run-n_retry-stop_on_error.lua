local new_set = MiniTest.new_set

local T = new_set()

_G.log = {}
local log = function(msg) table.insert(_G.log, msg) end

local n1 = 0
T['retries until first success'] = new_set({ n_retry = 10 }, {
  test = function()
    n1 = n1 + 1
    log('try #' .. n1)
    if n1 < 3 then error() end
  end,
})

T['continues even if first tries were errors'] = function()
  log('continue')
  error()
end

T['should not reach here'] = function() log('not reach') end

return T
