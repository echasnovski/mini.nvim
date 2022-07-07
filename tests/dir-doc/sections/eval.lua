local M = {}

--- Tests of `@eval` section
---
--- Generic case
---
---@eval local i = 1
--- return ('This string is ' .. 'evaluated using local variable. '
---   .. i .. ' + ' .. i .. ' = ' .. (i + i))

--- Usage of `MiniDoc.afterlines_to_code()` and `MiniDoc.current.eval_section`
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
M.tab = {
  -- Some functional setting
  --minidoc_replace_start     a = <function; should be padded>,
  a = function() return 1 + 1 end,
  --minidoc_replace_end
  -- A very important setting
  b = 2,
  c = {
    d = 3,
    e = 4,
  },
  --minidoc_replace_start
  f = 'This line should be completely removed',
  --minidoc_replace_end
}
--minidoc_afterlines_end

M.entry = [[Shouldn't be included in afterlines]]
