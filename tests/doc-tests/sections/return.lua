--- Tests for `@return` section

--- Test for general cases
---
---@return number Some number.

--- Test for expanding `?` to `(optional)`
---
---@return number?
---@return boolean? Second ? shouldn't trigger anything.

--- Test for enclosing type
---
---@return number Should work.
---@return number[] Should work.
---@return number|nil Should work.
---@return table<string, number> Should work.
---@return fun(a: string, b:number) Should work.
---@return fun(a: string, b:number): table Should work.
---@return NUMBER Shouldn't work.
---@return function Should not enclose second time: function .
---@return ... Should work.
