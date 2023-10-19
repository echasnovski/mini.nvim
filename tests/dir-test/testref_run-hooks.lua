local new_set = MiniTest.new_set

_G.log = {}
local logging = function(msg)
  return function() table.insert(_G.log, msg) end
end

local T = new_set()

-- Track order of hook execution via adding to `_G.log`
T['order'] = new_set({
  hooks = {
    pre_once = logging('pre_once_1'),
    pre_case = logging('pre_case_1'),
    post_case = logging('post_case_1'),
    post_once = logging('post_once_1'),
  },
})

T['order']['first level'] = logging('First level test')

T['order']['nested'] = new_set({
  hooks = {
    pre_once = logging('pre_once_2'),
    pre_case = logging('pre_case_2'),
    post_case = logging('post_case_2'),
    post_once = logging('post_once_2'),
  },
})

T['order']['nested']['first'] = logging('Nested #1')
T['order']['nested']['second'] = logging('Nested #2')

-- Test that non-post-hooks are not executed if there is an error in pre hook
local erroring = function(x)
  return function() error(x, 0) end
end

T['skip_case_on_hook_error #1'] = new_set({
  hooks = {
    pre_once = erroring('pre_once_3'),
    pre_case = logging('pre_case_3'),
    post_case = logging('post_case_3'),
    post_once = logging('post_once_3'),
  },
})

T['skip_case_on_hook_error #1']['case'] = logging('Skipped Case #1')

T['skip_case_on_hook_error #2'] = new_set({
  hooks = {
    pre_once = logging('pre_once_4'),
    pre_case = erroring('pre_case_4'),
    post_case = logging('post_case_4'),
    post_once = logging('post_once_4'),
  },
})

T['skip_case_on_hook_error #2']['case'] = logging('Skipped Case #2')

-- Ensure that this will be called even if represented by the same function.
-- Use this in several `_once` hooks and see that they all got executed.
local f = logging('Same function')
T['same `*_once` hooks'] = new_set({ hooks = { pre_once = f, post_once = f } })
T['same `*_once` hooks']['nested'] = new_set({ hooks = { pre_once = f, post_once = f } })
T['same `*_once` hooks']['nested']['test'] = logging('Same hook test')

return T
