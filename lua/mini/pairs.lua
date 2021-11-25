-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom minimal and fast autopairs Lua module. It provides functionality
--- to work with 'paired' characters conditional on cursor's neighborhood (two
--- characters to its left and right). Its usage should be through making
--- appropriate mappings using |MiniPairs.map| or in |MiniPairs.setup| (for
--- global mapping), |MiniPairs.map_buf| (for buffer mapping). Pairs get
--- automatically registered to be recognized by `<BS>` and `<CR>`.
---
--- What it doesn't do:
--- - It doesn't support multiple characters as "open" and "close" symbols. Use
---   snippets for that.
--- - It doesn't support dependency on filetype. Use |i_CTRL-V| to insert
---   single symbol or `autocmd` command or 'after/ftplugin' approach to:
---     - `lua MiniPairs.map_buf(0, 'i', <*>, <pair_info>)` : make new mapping
---       for '<*>' in current buffer.
---     - `lua MiniPairs.unmap_buf(0, 'i', <*>, <pair>)`: unmap key `<*>` while
---       unregistering `<pair>` pair in current buffer.
---     - Disable module for buffer (see 'Disabling' section).
---
--- # Setup
---
--- This module needs a setup with `require('mini.pairs').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniPairs` which you can use for scripting or manually (with
--- `:lua MiniPairs.*`).
---
--- Default `config`:
--- <code>
---   {
---     -- In which modes mappings from this `config` should be created
---     modes = {insert = true, command = false, terminal = false}
---
---     -- Global mappings. Each right hand side should be a pair information, a
---     -- table with at least these fields (see more in |MiniPairs.map|):
---     -- - `action` - one of 'open', 'close', 'closeopen'.
---     -- - `pair` - two character string for pair to be used.
---     -- By default pair is not inserted after `\`, quotes are not recognized by
---     -- `<CR>`, `'` does not insert pair after a letter.
---     -- Only parts of the tables can be tweaked (others will use these defaults).
---     mappings = {
---       ['('] = { action = 'open', pair = '()', neigh_pattern = '[^\\].' },
---       ['['] = { action = 'open', pair = '[]', neigh_pattern = '[^\\].' },
---       ['{'] = { action = 'open', pair = '{}', neigh_pattern = '[^\\].' },
---
---       [')'] = { action = 'close', pair = '()', neigh_pattern = '[^\\].' },
---       [']'] = { action = 'close', pair = '[]', neigh_pattern = '[^\\].' },
---       ['}'] = { action = 'close', pair = '{}', neigh_pattern = '[^\\].' },
---
---       ['"'] = { action = 'closeopen', pair = '""', neigh_pattern = '[^\\].', register = { cr = false } },
---       ["'"] = { action = 'closeopen', pair = "''", neigh_pattern = '[^%a\\].', register = { cr = false } },
---       ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\].', register = { cr = false } },
---     },
---   }
--- </code>
---
--- # Example mappings
---
--- <pre>
--- - Register quotes inside `config` of |MiniPairs.setup|:
---   `mappings = {`
---   `  ['"'] = { register = { cr = true } },`
---   `  ["'"] = { register = { cr = true } },`
---   `}`
--- - Insert `<>` pair if `<` is typed as first character in line, don't register for `<CR>`:
---   `lua MiniPairs.map('i', '<', { action = 'open', pair = '<>', neigh_pattern = '\r.', register = { cr = false } })`
---   `lua MiniPairs.map('i', '>', { action = 'close', pair = '<>', register = { cr = false } })`
--- - Create symmetrical `$$` pair only in Tex files:
---   `au FileType tex lua MiniPairs.map_buf(0, 'i', '$', {action = 'closeopen', pair = '$$'})`
--- </pre>
---
--- # Notes
--- - Make sure to make proper mapping of `<CR>` in order to support completion
---   plugin of your choice.
--- - Having mapping in terminal mode can conflict with:
---     - Autopairing capabilities of interpretators (`ipython`, `radian`).
---     - Vim mode of terminal itself.
---
--- # Disabling
---
--- To disable, set `g:minipairs_disable` (globally) or `b:minipairs_disable`
--- (for a buffer) to `v:true`.
---@brief ]]
---@tag MiniPairs mini.pairs

-- Module and its helper --
local MiniPairs = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.completion').setup({})` (replace `{}` with your `config` table)
function MiniPairs.setup(config)
  -- Export module
  _G.MiniPairs = MiniPairs

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  vim.api.nvim_exec(
    [[augroup MiniPairs
        au!
        au FileType TelescopePrompt let b:minipairs_disable=v:true
        au FileType fzf let b:minipairs_disable=v:true
      augroup END]],
    false
  )
end

-- Module config --
MiniPairs.config = {
  -- In which modes mappings from this `config` should be created
  modes = { insert = true, command = false, terminal = false },

  -- Global mappings. Each right hand side should be a pair information, a
  -- table with at least these fields (see more in |MiniPairs.map|):
  -- - `action` - one of 'open', 'close', 'closeopen'.
  -- - `pair` - two character string for pair to be used.
  -- By default pair is not inserted after `\`, quotes are not recognized by
  -- `<CR>`, `'` does not insert pair after a letter.
  -- Only parts of the tables can be tweaked (others will use these defaults).
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

-- Module functionality --
--- Make global mapping
---
--- This is similar to |nvim_set_keymap()| but instead of right hand side of
--- mapping (as string) it expects table with pair information:
--- - `action` - one of 'open' (for |MiniPairs.open|), 'close' (for
---   |MiniPairs.close|), or 'closeopen' (for |MiniPairs.closeopen|).
--- - `pair` - two character string to be used as argument for action function.
--- - `neigh_pattern` - optional 'two character' neighborhood pattern to be
---   used as argument for action function. Default: '..' (no restriction from
---   neighborhood).
--- - `register` - optional table with information about whether this pair
---   should be recognized by `<BS>` (in |MiniPairs.bs|) and/or `<CR>` (in
---   |MiniPairs.cr|). Should have boolean elements `bs` and `cr` which are
---   both `true` by default (if not overriden explicitly).
---
--- Using this function instead of |nvim_set_keymap()| allows automatic
--- registration of pairs which will be recognized by `<BS>` and `<CR>`.
---
---@param mode string: `mode` for |nvim_set_keymap()|.
---@param lhs string: `lhs` for |nvim_set_keymap()|.
---@param pair_info table: Table with pair information.
---@param opts table: Optional table `opts` for |nvim_set_keymap()|. Elements `expr` and `noremap` won't be recognized (`true` by default).
function MiniPairs.map(mode, lhs, pair_info, opts)
  pair_info = H.ensure_pair_info(pair_info)
  opts = vim.tbl_deep_extend('force', opts or {}, { expr = true, noremap = true })
  vim.api.nvim_set_keymap(mode, lhs, H.pair_info_to_map_rhs(pair_info), opts)
  H.register_pair(pair_info, mode, 'all')
end

--- Make buffer mapping
---
--- This is similar to |nvim_buf_set_keymap()| but instead of string right hand
--- side of mapping it expects table with pair information similar to one in
--- |MiniPairs.map|.
---
--- Using this function instead of |nvim_buf_set_keymap()| allows automatic
--- registration of pairs which will be recognized by `<BS>` and `<CR>`.
---
---@param mode string: `mode` for |nvim_buf_set_keymap()|.
---@param lhs string: `lhs` for |nvim_buf_set_keymap()|.
---@param pair_info table: Table with pair information.
---@param opts table: Optional table `opts` for |nvim_buf_set_keymap()|. Elements `expr` and `noremap` won't be recognized (`true` by default).
function MiniPairs.map_buf(buffer, mode, lhs, pair_info, opts)
  pair_info = H.ensure_pair_info(pair_info)
  opts = vim.tbl_deep_extend('force', opts or {}, { expr = true, noremap = true })
  vim.api.nvim_buf_set_keymap(buffer, mode, lhs, H.pair_info_to_map_rhs(pair_info), opts)
  H.register_pair(pair_info, mode, buffer == 0 and vim.api.nvim_get_current_buf() or buffer)
end

--- Remove global mapping
---
--- Uses |nvim_del_keymap()| together with unregistering supplied `pair`.
---
---@param mode string: `mode` for |nvim_del_keymap()|.
---@param lhs string: `lhs` for |nvim_del_keymap()|.
---@param pair string: pair which should be unregistered. Supply `''` to not unregister pair.
function MiniPairs.unmap(mode, lhs, pair)
  vim.api.nvim_del_keymap(mode, lhs)
  if pair == nil then
    vim.notify([[(mini.pairs) Supply `pair` argument to `MiniPairs.unmap`.]])
  end
  if (pair or '') ~= '' then
    H.unregister_pair(pair, mode, 'all')
  end
end

--- Remove buffer mapping
---
--- Uses |nvim_buf_del_keymap()| together with unregistering supplied `pair`.
---
---@param mode string: `mode` for |nvim_buf_del_keymap()|.
---@param lhs string: `lhs` for |nvim_buf_del_keymap()|.
---@param pair string: pair which should be unregistered. Supply `''` to not unregister pair.
function MiniPairs.unmap_buf(buffer, mode, lhs, pair)
  vim.api.nvim_buf_del_keymap(buffer, mode, lhs)
  if pair == nil then
    vim.notify([[(mini.pairs) Supply `pair` argument to `MiniPairs.unmap_buf`.]])
  end
  if (pair or '') ~= '' then
    H.unregister_pair(pair, mode, buffer == 0 and vim.api.nvim_get_current_buf() or buffer)
  end
end

--- Process 'open' symbols
---
--- Used as |map-expr| mapping for 'open' symbols in asymmetric pair ('(', '[',
--- etc.). If neighborhood doesn't match supplied pattern, function results
--- into 'open' symbol. Otherwise, it pastes whole pair and moves inside pair
--- with |<Left>|.
---
--- Used inside |MiniPairs.map| and |MiniPairs.map_buf| for an actual mapping.
---
---@param pair string: String with two characters representing pair.
---@param neigh_pattern string: Pattern for two neighborhood characters ("\r" line start, "\n" - line end).
function MiniPairs.open(pair, neigh_pattern)
  if H.is_disabled() or not H.neigh_match(neigh_pattern) then
    return pair:sub(1, 1)
  end

  return ('%s%s'):format(pair, H.get_arrow_key('left'))
end

--- Process 'close' symbols
---
--- Used as |map-expr| mapping for 'close' symbols in asymmetric pair (')',
--- ']', etc.). If neighborhood doesn't match supplied pattern, function
--- results into 'close' symbol. Otherwise it jumps over symbol to the right of
--- cursor (with |<Right>|) if it is equal to 'close' one and inserts it
--- otherwise.
---
--- Used inside |MiniPairs.map| and |MiniPairs.map_buf| for an actual mapping.
---
---@param pair string: String with two characters representing pair.
---@param neigh_pattern string: Pattern for two neighborhood characters ("\r" line start, "\n" - line end).
function MiniPairs.close(pair, neigh_pattern)
  if H.is_disabled() or not H.neigh_match(neigh_pattern) then
    return pair:sub(2, 2)
  end

  local close = pair:sub(2, 2)
  if H.get_cursor_neigh(1, 1) == close then
    return H.get_arrow_key('right')
  else
    return close
  end
end

--- Process 'closeopen' symbols
---
--- Used as |map-expr| mapping for 'symmetrical' symbols (from pairs '""',
--- '\'\'', '``').  It tries to perform 'closeopen action': move over right
--- character (with |<Right>|) if it is equal to second character from pair or
--- conditionally paste pair otherwise (with |MiniPairs.open()|).
---
--- Used inside |MiniPairs.map| and |MiniPairs.map_buf| for an actual mapping.
---
---@param pair string: String with two characters representing pair.
---@param neigh_pattern string: Pattern for two neighborhood characters ("\r" line start, "\n" - line end).
function MiniPairs.closeopen(pair, neigh_pattern)
  if H.is_disabled() or not (H.get_cursor_neigh(1, 1) == pair:sub(2, 2)) then
    return MiniPairs.open(pair, neigh_pattern)
  else
    return H.get_arrow_key('right')
  end
end

--- Process |<BS>|
---
--- Used as |map-expr| mapping for `<BS>`. It removes whole pair (via
--- `<BS><Del>`) if neighborhood is equal to a whole pair recognized for
--- current buffer. Pair is recognized for current buffer if it is registered
--- for global or current buffer mapping. Pair is registered as a result of
--- calling |MiniPairs.map| or |MiniPairs.map_buf|.
---
--- Mapped by default inside |MiniPairs.setup|.
function MiniPairs.bs(pair_set)
  -- TODO: remove `pair_set` argument
  if pair_set ~= nil and not H.showed_deprecation then
    vim.notify(table.concat({
      '(mini.pairs)',
      [[`pair_set` arugment in both `MiniPairs.bs()` and `MiniPairs.cr()` is soft deprecated.]],
      [[It is no longer needed due to the mechanism of pairs registration inside new mapping functions.]],
      [[See `:h MiniPairs.map()` and `:h MiniPairs.map_buf()`.]],
      [[It will be removed in the future. Sorry for this.]],
    }, ' '))
    H.showed_deprecation = true
  end

  local res = H.keys.bs

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
function MiniPairs.cr(pair_set)
  -- TODO: remove `pair_set` argument
  if pair_set ~= nil and not H.showed_deprecation then
    vim.notify(table.concat({
      '(mini.pairs)',
      [[`pair_set` arugment in both `MiniPairs.bs()` and `MiniPairs.cr()` is soft deprecated.]],
      [[It is no longer needed due to the mechanism of pairs registration inside new mapping functions.]],
      [[See `:h MiniPairs.map()` and `:h MiniPairs.map_buf()`.]],
      [[It will be removed in the future. Sorry for this.]],
    }, ' '))
    H.showed_deprecation = true
  end

  local res = H.keys.cr

  local neigh = H.get_cursor_neigh(0, 1)
  if not H.is_disabled() and H.is_pair_registered(neigh, vim.fn.mode(), 0, 'cr') then
    res = ('%s%s'):format(res, H.keys.above)
  end

  return res
end

-- Helpers --
-- Module default config
H.default_config = MiniPairs.config

-- Default value of `pair_info` for mapping functions
H.default_pair_info = { neigh_pattern = '..', register = { bs = true, cr = true } }

-- Pair sets registered *per mode-buffer-key*. Buffer `'all'` contains pairs
-- registered for all buffers.
H.registered_pairs = {
  i = { all = { bs = {}, cr = {} } },
  c = { all = { bs = {}, cr = {} } },
  t = { all = { bs = {}, cr = {} } },
}

-- Deprecation indication. TODO: remove when there is not deprecation.
H.showed_deprecation = false

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

-- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({
    modes = { config.modes, 'table' },
    ['modes.insert'] = { config.modes.insert, 'boolean' },
    ['modes.command'] = { config.modes.command, 'boolean' },
    ['modes.terminal'] = { config.modes.terminal, 'boolean' },

    mappings = { config.mappings, 'table' },
  })

  return config
end

function H.apply_config(config)
  MiniPairs.config = config

  -- Setup mappings in supplied modes
  local mode_ids = { insert = 'i', command = 'c', terminal = 't' }
  ---- Compute in which modes mapping should be set up
  local mode_array = {}
  for name, to_set in pairs(config.modes) do
    if to_set then
      table.insert(mode_array, mode_ids[name])
    end
  end

  for _, mode in pairs(mode_array) do
    for key, pair_info in pairs(config.mappings) do
      MiniPairs.map(mode, key, pair_info)
    end

    vim.api.nvim_set_keymap(mode, '<BS>', [[v:lua.MiniPairs.bs()]], { expr = true, noremap = true })
    if mode == 'i' then
      vim.api.nvim_set_keymap('i', '<CR>', [[v:lua.MiniPairs.cr()]], { expr = true, noremap = true })
    end
  end
end

function H.is_disabled()
  return vim.g.minipairs_disable == true or vim.b.minipairs_disable == true
end

-- Pair registration --
function H.register_pair(pair_info, mode, buffer)
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

function H.unregister_pair(pair, mode, buffer)
  local mode_pairs = H.registered_pairs[mode]
  if not (mode_pairs and mode_pairs[buffer]) then
    return
  end

  local buf_pairs = mode_pairs[buffer]
  for _, key in ipairs({ 'bs', 'cr' }) do
    for i, p in ipairs(buf_pairs[key]) do
      if p == pair then
        table.remove(buf_pairs[key], i)
        break
      end
    end
  end
end

function H.is_pair_registered(pair, mode, buffer, key)
  local mode_pairs = H.registered_pairs[mode]
  if not mode_pairs then
    return false
  end

  if vim.tbl_contains(mode_pairs['all'][key], pair) then
    return true
  end

  buffer = buffer == 0 and vim.api.nvim_get_current_buf() or buffer
  local buf_pairs = mode_pairs[buffer]
  if not buf_pairs then
    return false
  end

  return vim.tbl_contains(buf_pairs[key], pair)
end

-- Work with pair_info --
function H.ensure_pair_info(pair_info)
  vim.validate({ pair_info = { pair_info, 'table' } })
  pair_info = vim.tbl_deep_extend('force', H.default_pair_info, pair_info)

  vim.validate({
    action = { pair_info.action, 'string' },
    pair = { pair_info.pair, 'string' },
    neigh_pattern = { pair_info.neigh_pattern, 'string' },
    register = { pair_info.register, 'table' },
    ['register.bs'] = { pair_info.register.bs, 'boolean' },
    ['register.cr'] = { pair_info.register.cr, 'boolean' },
  })

  return pair_info
end

function H.pair_info_to_map_rhs(pair_info)
  return ('v:lua.MiniPairs.%s(%s, %s)'):format(
    pair_info.action,
    vim.inspect(pair_info.pair),
    vim.inspect(pair_info.neigh_pattern)
  )
end

-- Various helpers
function H.map(mode, key, command)
  vim.api.nvim_set_keymap(mode, key, command, { expr = true, noremap = true })
end

function H.get_cursor_neigh(start, finish)
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

function H.neigh_match(pattern)
  return (pattern == nil) or (H.get_cursor_neigh(0, 1):find(pattern) ~= nil)
end

function H.get_arrow_key(key)
  if vim.fn.mode() == 'i' then
    -- Using left/right keys in insert mode breaks undo sequence and, more
    -- importantly, dot-repeat. To avoid this, use 'i_CTRL-G_U' mapping.
    return H.keys.keep_undo .. H.keys[key]
  else
    return H.keys[key]
  end
end

return MiniPairs
