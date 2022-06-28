--- Test `@alias` section

---@alias   var_one   fun(type: string, data: any)
---@alias var_two Another data structure.
---   Its description spans over multiple lines.
---@alias %bad_name* This alias has bad name and should still work.

---@param x var_one
---@param y var_two
---@param z var_three
---@alias var_three This alias shouldn't be applied to previous line as it is defined after it.

--- Aliases also expand inside text: var_one

--- Test of `MiniDoc.current.aliases`
---
---@eval return vim.inspect(MiniDoc.current.aliases)
