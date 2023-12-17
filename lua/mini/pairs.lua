--- *mini.pairs* Autopairs
--- *MiniPairs*
---
--- MIT License Copyright (c) 2021 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Features:
--- - Functionality to work with 'paired' characters conditional on cursor's
---   neighborhood (two characters to its left and right).
---
--- - Usage should be through making appropriate mappings using |MiniPairs.map|
---   or in |MiniPairs.setup| (for global mapping), |MiniPairs.map_buf| (for
---   buffer mapping).
---
--- - Pairs get automatically registered to be recognized by `<BS>` and `<CR>`.
---
--- What it doesn't do:
--- - It doesn't support multiple characters as "open" and "close" symbols. Use
---   snippets for that.
---
--- - It doesn't support dependency on filetype. Use |i_CTRL-V| to insert
---   single symbol or `autocmd` command or 'after/ftplugin' approach to:
---     - `lua MiniPairs.map_buf(0, 'i', <*>, <pair_info>)` : make new mapping
---       for '<*>' in current buffer.
---     - `lua MiniPairs.unmap_buf(0, 'i', <*>, <pair>)`: unmap key `<*>` while
---       unregistering `<pair>` pair in current buffer. Note: this reverts
---       mapping done by |MiniPairs.map_buf|. If mapping was done with
---       |MiniPairs.map|, unmap for buffer in usual Neovim manner:
---       `inoremap <buffer> <*> <*>` (this maps `<*>` key to do the same it
---       does by default).
---     - Disable module for buffer (see 'Disabling' section).
---
--- # Setup ~
---
--- This module needs a setup with `require('mini.pairs').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniPairs` which you can use for scripting or manually (with
--- `:lua MiniPairs.*`).
---
--- See |MiniPairs.config| for `config` structure and default values.
---
--- This module doesn't have runtime options, so using `vim.b.minipairs_config`
--- will have no effect here.
---
--- # Example mappings ~
---
--- - Register quotes inside `config` of |MiniPairs.setup|: >
---   mappings = {
---     ['"'] = { register = { cr = true } },
---     ["'"] = { register = { cr = true } },
---   }
--- <
--- - Insert `<>` pair if `<` is typed at line start, don't register for `<CR>`: >
---   lua MiniPairs.map('i', '<', { action = 'open', pair = '<>', neigh_pattern = '\r.', register = { cr = false } })
---   lua MiniPairs.map('i', '>', { action = 'close', pair = '<>', register = { cr = false } })
--- <
--- - Create symmetrical `$$` pair only in Tex files: >
---   au FileType tex lua MiniPairs.map_buf(0, 'i', '$', {action = 'closeopen', pair = '$$'})
--- <
--- # Notes ~
---
--- - Make sure to make proper mapping of `<CR>` in order to support completion
---   plugin of your choice:
---     - For |MiniCompletion| see 'Helpful key mappings' section.
---     - For current implementation of "hrsh7th/nvim-cmp" there is no need to
---       make custom mapping. You can use default setup, which will confirm
---       completion selection if popup is visible and expand pair otherwise.
--- - Having mapping in terminal mode can conflict with:
---     - Autopairing capabilities of interpretators (`ipython`, `radian`).
---     - Vim mode of terminal itself.
---
--- # Disabling ~
---
--- To disable, set `vim.g.minipairs_disable` (globally) or `vim.b.minipairs_disable`
--- (for a buffer) to `true`. Considering high number of different scenarios
--- and customization intentions, writing exact rules for disabling module's
--- functionality is left to user. See |mini.nvim-disabling-recipes| for common
--- recipes.

---@alias __pairs_neigh_pattern string|nil Pattern for two neighborhood characters.
---   Character "\r" indicates line start, "\n" - line end.
---@alias __pairs_pair string String with two characters representing pair.
---@alias __pairs_unregistered_pair string Pair which should be unregistered from both
---   `<BS>` and `<CR>`. Should be explicitly supplied to avoid confusion.
---   Supply `''` to not unregister pair.

-- Module definition ==========================================================
local MiniPairs = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniPairs.config|.
---
---@usage `require('mini.completion').setup({})` (replace `{}` with your `config` table)
MiniPairs.setup = function(config)
  -- Export module
  _G.MiniPairs = MiniPairs

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Define behavior
  H.create_autocommands()
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniPairs.config = {
  -- In which modes mappings from this `config` should be created
  modes = { insert = true, command = false, terminal = false },

  -- Global mappings. Each right hand side should be a pair information, a
  -- table with at least these fields (see more in |MiniPairs.map|):
  -- - <action> - one of "open", "close", "closeopen".
  -- - <pair> - two character string for pair to be used.
  -- By default pair is not inserted after `\`, quotes are not recognized by
  -- `<CR>`, `'` does not insert pair after a letter.
  -- Only parts of tables can be tweaked (others will use these defaults).
  -- Supply `false` instead of table to not map particular key.
  mappings = {
    ['('] = { action = 'open', pair = '()', neigh_pattern = '[^\\].' },
    ['['] = { action = 'open', pair = '[]', neigh_pattern = '[^\\].' },
    ['{'] = { action = 'open', pair = '{}', neigh_pattern = '[^\\].' },

    [')'] = { action = 'close', pair = '()', neigh_pattern = '[^\\].' },
    [']'] = { action = 'close', pair = '[]', neigh_pattern = '[^\\].' },
    ['}'] = { action = 'close', pair = '{}', neigh_pattern = '[^\\].' },

    ['"'] = { action = 'closeopen', pair = '""', neigh_pattern = '[^\\].', register = { cr = false } },
    ["'"] = { action = 'closeopen', pair = "''", neigh_pattern = '[^%a\\].', register = { cr = false } },
    ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\].', register = { cr = false } },
  },
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Make global mapping
---
--- This is a wrapper for |nvim_set_keymap()| but instead of right hand side of
--- mapping (as string) it expects table with pair information:
--- - `action` - one of "open" (for |MiniPairs.open|), "close" (for
---   |MiniPairs.close|), or "closeopen" (for |MiniPairs.closeopen|).
--- - `pair` - two character string to be used as argument for action function.
--- - `neigh_pattern` - optional 'two character' neighborhood pattern to be
---   used as argument for action function. Default: '..' (no restriction from
---   neighborhood).
--- - `register` - optional table with information about whether this pair
---   should be recognized by `<BS>` (in |MiniPairs.bs|) and/or `<CR>` (in
---   |MiniPairs.cr|). Should have boolean elements `bs` and `cr` which are
---   both `true` by default (if not overridden explicitly).
---
--- Using this function instead of |nvim_set_keymap()| allows automatic
--- registration of pairs which will be recognized by `<BS>` and `<CR>`.
--- For Neovim>=0.7 it also infers mapping description from `pair_info`.
---
---@param mode string `mode` for |nvim_set_keymap()|.
---@param lhs string `lhs` for |nvim_set_keymap()|.
---@param pair_info table Table with pair information.
---@param opts table|nil Optional table `opts` for |nvim_set_keymap()|. Elements
---   `expr` and `noremap` won't be recognized (`true` by default).
MiniPairs.map = function(mode, lhs, pair_info, opts)
  pair_info = H.validate_pair_info(pair_info)
  opts = vim.tbl_deep_extend('force', opts or {}, { expr = true, noremap = true })
  opts.desc = H.infer_mapping_description(pair_info)

  vim.api.nvim_set_keymap(mode, lhs, H.pair_info_to_map_rhs(pair_info), opts)
  H.register_pair(pair_info, mode, 'all')

  -- Ensure that `<BS>` and `<CR>` are mapped for input mode
  H.ensure_cr_bs(mode)
end

--- Make buffer mapping
---
--- This is a wrapper for |nvim_buf_set_keymap()| but instead of string right
--- hand side of mapping it expects table with pair information similar to one
--- in |MiniPairs.map|.
---
--- Using this function instead of |nvim_buf_set_keymap()| allows automatic
--- registration of pairs which will be recognized by `<BS>` and `<CR>`.
--- For Neovim>=0.7 it also infers mapping description from `pair_info`.
---
---@param buffer number `buffer` for |nvim_buf_set_keymap()|.
---@param mode string `mode` for |nvim_buf_set_keymap()|.
---@param lhs string `lhs` for |nvim_buf_set_keymap()|.
---@param pair_info table Table with pair information.
---@param opts table|nil Optional table `opts` for |nvim_buf_set_keymap()|.
---   Elements `expr` and `noremap` won't be recognized (`true` by default).
MiniPairs.map_buf = function(buffer, mode, lhs, pair_info, opts)
  pair_info = H.validate_pair_info(pair_info)
  opts = vim.tbl_deep_extend('force', opts or {}, { expr = true, noremap = true })
  opts.desc = H.infer_mapping_description(pair_info)

  vim.api.nvim_buf_set_keymap(buffer, mode, lhs, H.pair_info_to_map_rhs(pair_info), opts)
  H.register_pair(pair_info, mode, buffer == 0 and vim.api.nvim_get_current_buf() or buffer)

  -- Ensure that `<BS>` and `<CR>` are mapped for input mode
  H.ensure_cr_bs(mode)
end

--- Remove global mapping
---
--- A wrapper for |nvim_del_keymap()| which registers supplied `pair`.
---
---@param mode string `mode` for |nvim_del_keymap()|.
---@param lhs string `lhs` for |nvim_del_keymap()|.
---@param pair __pairs_unregistered_pair
MiniPairs.unmap = function(mode, lhs, pair)
  -- `pair` should be supplied explicitly
  vim.validate({ pair = { pair, 'string' } })

  -- Use `pcall` to allow 'deleting' already deleted mapping
  pcall(vim.api.nvim_del_keymap, mode, lhs)
  if pair == '' then return end
  H.unregister_pair(pair, mode, 'all')
end

--- Remove buffer mapping
---
--- Wrapper for |nvim_buf_del_keymap()| which also unregisters supplied `pair`.
---
--- Note: this only reverts mapping done by |MiniPairs.map_buf|. If mapping was
--- done with |MiniPairs.map|, unmap for buffer in usual Neovim manner:
--- `inoremap <buffer> <*> <*>` (this maps `<*>` key to do the same it does by
--- default).
---
---@param buffer number `buffer` for |nvim_buf_del_keymap()|.
---@param mode string `mode` for |nvim_buf_del_keymap()|.
---@param lhs string `lhs` for |nvim_buf_del_keymap()|.
---@param pair __pairs_unregistered_pair
MiniPairs.unmap_buf = function(buffer, mode, lhs, pair)
  -- `pair` should be supplied explicitly
  vim.validate({ pair = { pair, 'string' } })

  -- Use `pcall` to allow 'deleting' already deleted mapping
  pcall(vim.api.nvim_buf_del_keymap, buffer, mode, lhs)
  if pair == '' then return end
  H.unregister_pair(pair, mode, buffer == 0 and vim.api.nvim_get_current_buf() or buffer)
end

--- Process "open" symbols
---
--- Used as |map-expr| mapping for "open" symbols in asymmetric pair ('(', '[',
--- etc.). If neighborhood doesn't match supplied pattern, function results
--- into "open" symbol. Otherwise, it pastes whole pair and moves inside pair
--- with |<Left>|.
---
--- Used inside |MiniPairs.map| and |MiniPairs.map_buf| for an actual mapping.
---
---@param pair __pairs_pair
---@param neigh_pattern __pairs_neigh_pattern
---
---@return string Keys performing "open" action.
MiniPairs.open = function(pair, neigh_pattern)
  if H.is_disabled() or not H.neigh_match(neigh_pattern) then return pair:sub(1, 1) end

  return ('%s%s'):format(pair, H.get_arrow_key('left'))
end

--- Process "close" symbols
---
--- Used as |map-expr| mapping for "close" symbols in asymmetric pair (')',
--- ']', etc.). If neighborhood doesn't match supplied pattern, function
--- results into "close" symbol. Otherwise it jumps over symbol to the right of
--- cursor (with |<Right>|) if it is equal to "close" one and inserts it
--- otherwise.
---
--- Used inside |MiniPairs.map| and |MiniPairs.map_buf| for an actual mapping.
---
---@param pair __pairs_pair
---@param neigh_pattern __pairs_neigh_pattern
---
---@return string Keys performing "close" action.
MiniPairs.close = function(pair, neigh_pattern)
  if H.is_disabled() or not H.neigh_match(neigh_pattern) then return pair:sub(2, 2) end

  local close = pair:sub(2, 2)
  if H.get_cursor_neigh(1, 1) == close then
    return H.get_arrow_key('right')
  else
    return close
  end
end

--- Process "closeopen" symbols
---
--- Used as |map-expr| mapping for 'symmetrical' symbols (from pairs '""',
--- '\'\'', '``').  It tries to perform 'closeopen action': move over right
--- character (with |<Right>|) if it is equal to second character from pair or
--- conditionally paste pair otherwise (with |MiniPairs.open()|).
---
--- Used inside |MiniPairs.map| and |MiniPairs.map_buf| for an actual mapping.
---
---@param pair __pairs_pair
---@param neigh_pattern __pairs_neigh_pattern
---
---@return string Keys performing "closeopen" action.
MiniPairs.closeopen = function(pair, neigh_pattern)
  if H.is_disabled() or H.get_cursor_neigh(1, 1) ~= pair:sub(2, 2) then
    return MiniPairs.open(pair, neigh_pattern)
  else
    return H.get_arrow_key('right')
  end
end

--- Process |<BS>|
---
--- Used as |map-expr| mapping for `<BS>` in Insert mode. It removes whole pair
--- (via executing `<Del>` after input key) if neighborhood is equal to a whole
--- pair recognized for current buffer. Pair is recognized for current buffer
--- if it is registered for global or current buffer mapping. Pair is
--- registered as a result of calling |MiniPairs.map| or |MiniPairs.map_buf|.
---
--- Mapped by default inside |MiniPairs.setup|.
---
--- This can be used to modify other Insert mode keys to respect neighborhood
--- pair. Examples: >
---
---   local map_bs = function(lhs, rhs)
---     vim.keymap.set('i', lhs, rhs, { expr = true, replace_keycodes = false })
---   end
---
---   map_bs('<C-h>', 'v:lua.MiniPairs.bs()')
---   map_bs('<C-w>', 'v:lua.MiniPairs.bs("\23")')
---   map_bs('<C-u>', 'v:lua.MiniPairs.bs("\21")')
---
---@param key string|nil Key to use. Default: `<BS>`.
---
---@return string Keys performing "backspace" action.
MiniPairs.bs = function(key)
  local res = key or H.keys.bs

  local neigh = H.get_cursor_neigh(0, 1)
  if not H.is_disabled() and H.is_pair_registered(neigh, vim.fn.mode(), 0, 'bs') then
    res = ('%s%s'):format(res, H.keys.del)
  end

  return res
end

--- Process |i_<CR>|
---
--- Used as |map-expr| mapping for `<CR>` in insert mode. It puts "close"
--- symbol on next line (via `<CR><C-o>O`) if neighborhood is equal to a whole
--- pair recognized for current buffer. Pair is recognized for current buffer
--- if it is registered for global or current buffer mapping. Pair is
--- registered as a result of calling |MiniPairs.map| or |MiniPairs.map_buf|.
---
--- Mapped by default inside |MiniPairs.setup|.
---
---@param key string|nil Key to use. Default: `<CR>`.
---
---@return string Keys performing "new line" action.
MiniPairs.cr = function(key)
  local res = key or H.keys.cr

  local neigh = H.get_cursor_neigh(0, 1)
  if not H.is_disabled() and H.is_pair_registered(neigh, vim.fn.mode(), 0, 'cr') then
    res = ('%s%s'):format(res, H.keys.above)
  end

  return res
end

-- Helper data ================================================================
-- Module default config
H.default_config = vim.deepcopy(MiniPairs.config)

-- Default value of `pair_info` for mapping functions
H.default_pair_info = { neigh_pattern = '..', register = { bs = true, cr = true } }

-- Pair sets registered *per mode-buffer-key*. Buffer `'all'` contains pairs
-- registered for all buffers.
H.registered_pairs = {
  i = { all = { bs = {}, cr = {} } },
  c = { all = { bs = {}, cr = {} } },
  t = { all = { bs = {}, cr = {} } },
}

-- Precomputed keys to increase speed
-- stylua: ignore start
local function escape(s) return vim.api.nvim_replace_termcodes(s, true, true, true) end
H.keys = {
  above     = escape('<C-o>O'),
  bs        = escape('<bs>'),
  cr        = escape('<cr>'),
  del       = escape('<del>'),
  keep_undo = escape('<C-g>U'),
  -- NOTE: use `get_arrow_key()` instead of `H.keys.left` or `H.keys.right`
  left      = escape('<left>'),
  right     = escape('<right>')
}
-- stylua: ignore end

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  -- Validate per nesting level to produce correct error message
  vim.validate({
    modes = { config.modes, 'table' },
    mappings = { config.mappings, 'table' },
  })

  vim.validate({
    ['modes.insert'] = { config.modes.insert, 'boolean' },
    ['modes.command'] = { config.modes.command, 'boolean' },
    ['modes.terminal'] = { config.modes.terminal, 'boolean' },
  })

  local validate_mapping = function(pair_info, prefix)
    -- Allow `false` to not create mapping
    if pair_info == false then return end
    H.validate_pair_info(pair_info, prefix)
  end

  validate_mapping(config.mappings['('], "mappings['(']")
  validate_mapping(config.mappings['['], "mappings['[']")
  validate_mapping(config.mappings['{'], "mappings['{']")
  validate_mapping(config.mappings[')'], "mappings[')']")
  validate_mapping(config.mappings[']'], "mappings[']']")
  validate_mapping(config.mappings['}'], "mappings['}']")
  validate_mapping(config.mappings['"'], "mappings['\"']")
  validate_mapping(config.mappings["'"], 'mappings["\'"]')
  validate_mapping(config.mappings['`'], "mappings['`']")

  return config
end

H.apply_config = function(config)
  MiniPairs.config = config

  -- Setup mappings in supplied modes
  local mode_ids = { insert = 'i', command = 'c', terminal = 't' }
  -- Compute in which modes mapping should be set up
  local mode_array = {}
  for name, to_set in pairs(config.modes) do
    if to_set then table.insert(mode_array, mode_ids[name]) end
  end

  local map_conditionally = function(mode, key, pair_info)
    -- Allow `false` to not create mapping
    if pair_info == false then return end

    -- This also should take care of mapping `<BS>` and `<CR>`
    MiniPairs.map(mode, key, pair_info)
  end

  for _, mode in pairs(mode_array) do
    for key, pair_info in pairs(config.mappings) do
      map_conditionally(mode, key, pair_info)
    end
  end
end

H.create_autocommands = function()
  local augroup = vim.api.nvim_create_augroup('MiniPairs', {})

  local au = function(event, pattern, callback, desc)
    vim.api.nvim_create_autocmd(event, { group = augroup, pattern = pattern, callback = callback, desc = desc })
  end

  au('FileType', { 'TelescopePrompt', 'fzf' }, function() vim.b.minipairs_disable = true end, 'Disable locally')
end

H.is_disabled = function() return vim.g.minipairs_disable == true or vim.b.minipairs_disable == true end

-- Pair registration ----------------------------------------------------------
H.register_pair = function(pair_info, mode, buffer)
  -- Process new mode
  H.registered_pairs[mode] = H.registered_pairs[mode] or { all = { bs = {}, cr = {} } }
  local mode_pairs = H.registered_pairs[mode]

  -- Process new buffer
  mode_pairs[buffer] = mode_pairs[buffer] or { bs = {}, cr = {} }

  -- Register pair if it is not already registered
  local register, pair = pair_info.register, pair_info.pair
  if register.bs and not vim.tbl_contains(mode_pairs[buffer].bs, pair) then
    table.insert(mode_pairs[buffer].bs, pair)
  end
  if register.cr and not vim.tbl_contains(mode_pairs[buffer].cr, pair) then
    table.insert(mode_pairs[buffer].cr, pair)
  end
end

H.unregister_pair = function(pair, mode, buffer)
  local mode_pairs = H.registered_pairs[mode]
  if not (mode_pairs and mode_pairs[buffer]) then return end

  local buf_pairs = mode_pairs[buffer]
  for _, key in ipairs({ 'bs', 'cr' }) do
    for i, p in ipairs(buf_pairs[key]) do
      if p == pair then table.remove(buf_pairs[key], i) end
    end
  end
end

H.is_pair_registered = function(pair, mode, buffer, key)
  local mode_pairs = H.registered_pairs[mode]
  if not mode_pairs then return false end

  if vim.tbl_contains(mode_pairs['all'][key], pair) then return true end

  buffer = buffer == 0 and vim.api.nvim_get_current_buf() or buffer
  local buf_pairs = mode_pairs[buffer]
  if not buf_pairs then return false end

  return vim.tbl_contains(buf_pairs[key], pair)
end

H.ensure_cr_bs = function(mode)
  local has_any_cr_pair, has_any_bs_pair = false, false
  for _, pair_tbl in pairs(H.registered_pairs[mode]) do
    has_any_cr_pair = has_any_cr_pair or not vim.tbl_isempty(pair_tbl.cr)
    has_any_bs_pair = has_any_bs_pair or not vim.tbl_isempty(pair_tbl.bs)
  end

  -- NOTE: this doesn't distinguish between global and buffer mappings. Both
  -- `<BS>` and `<CR>` should work as normal even if no pairs are registered
  if has_any_bs_pair then
    -- Use not `silent` in Command mode to make it redraw
    local opts = { silent = mode ~= 'c', expr = true, replace_keycodes = false, desc = 'MiniPairs <BS>' }
    H.map(mode, '<BS>', 'v:lua.MiniPairs.bs()', opts)
  end
  if mode == 'i' and has_any_cr_pair then
    local opts = { expr = true, replace_keycodes = false, desc = 'MiniPairs <CR>' }
    H.map(mode, '<CR>', 'v:lua.MiniPairs.cr()', opts)
  end
end

-- Work with pair_info --------------------------------------------------------
H.validate_pair_info = function(pair_info, prefix)
  prefix = prefix or 'pair_info'
  vim.validate({ [prefix] = { pair_info, 'table' } })
  pair_info = vim.tbl_deep_extend('force', H.default_pair_info, pair_info)

  vim.validate({
    [prefix .. '.action'] = { pair_info.action, 'string' },
    [prefix .. '.pair'] = { pair_info.pair, 'string' },
    [prefix .. '.neigh_pattern'] = { pair_info.neigh_pattern, 'string' },
    [prefix .. '.register'] = { pair_info.register, 'table' },
  })

  vim.validate({
    [prefix .. '.register.bs'] = { pair_info.register.bs, 'boolean' },
    [prefix .. '.register.cr'] = { pair_info.register.cr, 'boolean' },
  })

  return pair_info
end

H.pair_info_to_map_rhs = function(pair_info)
  return ('v:lua.MiniPairs.%s(%s, %s)'):format(
    pair_info.action,
    vim.inspect(pair_info.pair),
    vim.inspect(pair_info.neigh_pattern)
  )
end

H.infer_mapping_description = function(pair_info)
  local action_name = pair_info.action:sub(1, 1):upper() .. pair_info.action:sub(2)
  return ('%s action for %s pair'):format(action_name, vim.inspect(pair_info.pair))
end

-- Utilities ------------------------------------------------------------------
H.get_cursor_neigh = function(start, finish)
  local line, col
  if vim.fn.mode() == 'c' then
    line = vim.fn.getcmdline()
    col = vim.fn.getcmdpos()
    -- Adjust start and finish because output of `getcmdpos()` starts counting
    -- columns from 1
    start = start - 1
    finish = finish - 1
  else
    line = vim.api.nvim_get_current_line()
    col = vim.api.nvim_win_get_cursor(0)[2]
  end

  -- Add '\r' and '\n' to always return 2 characters
  return string.sub(('%s%s%s'):format('\r', line, '\n'), col + 1 + start, col + 1 + finish)
end

H.neigh_match = function(pattern) return (pattern == nil) or (H.get_cursor_neigh(0, 1):find(pattern) ~= nil) end

H.get_arrow_key = function(key)
  if vim.fn.mode() == 'i' then
    -- Using left/right keys in insert mode breaks undo sequence and, more
    -- importantly, dot-repeat. To avoid this, use 'i_CTRL-G_U' mapping.
    return H.keys.keep_undo .. H.keys[key]
  else
    return H.keys[key]
  end
end

H.map = function(mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

return MiniPairs
