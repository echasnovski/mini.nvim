local new_set = MiniTest.new_set

local T = new_set()

local erroring = function(x)
  return function()
    error(x, 0)
  end
end

-- Track order of hook execution via error messages in `exec.fails`
T = new_set()

T['order'] = new_set({
  hooks = {
    pre_once = erroring('pre_once_1'),
    pre_case = erroring('pre_case_1'),
    post_case = erroring('post_case_1'),
    post_once = erroring('post_once_1'),
  },
})

T['order']['first level'] = erroring('First level test')

T['order']['nested'] = new_set({
  hooks = {
    pre_once = erroring('pre_once_2'),
    pre_case = erroring('pre_case_2'),
    post_case = erroring('post_case_2'),
    post_once = erroring('post_once_2'),
  },
})

T['order']['nested']['first'] = erroring('Nested #1')
T['order']['nested']['second'] = erroring('Nested #2')

-- Ensure that this will be called even if represented by the same function.
-- Use this in several `_once` hooks and see that they all got executed.
local f = erroring('Same function')
T['same `*_once` hooks'] = new_set({ hooks = { pre_once = f, post_once = f } })
T['same `*_once` hooks']['nested'] = new_set({ hooks = { pre_once = f, post_once = f } })
T['same `*_once` hooks']['nested']['test'] = erroring('Same hook test')

return T
