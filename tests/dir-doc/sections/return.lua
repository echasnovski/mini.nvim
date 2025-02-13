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
---@return (number | nil) Should not be doubly enclosed in ().
---@return table<string, number> Should work.
---@return fun(a: string, b:number) Should work.
---@return fun(a: string, b:number): table Should work.
---@return NUMBER Should still work as custom classes are allowed.
---@return NUMBER|nil Should still work as custom classes are allowed.
---@return (NUMBER | nil) Should not be doubly enclosed in ().
---@return ... Should work.
