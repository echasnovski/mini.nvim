-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom minimal and fast autopairs Lua module. It provides functionality
--- to work with 'paired' characters conditional on cursor's neighborhood (two
--- characters to its left and right). Its usage should be through making
--- appropriate `<expr>` mappings.
---
--- What it doesn't do:
--- - It doesn't support multiple characters as "open" and "close" symbols. Use
---   snippets for that.
--- - It doesn't support dependency on filetype. Use |i_CTRL-V| to insert
---   single symbol or `autocmd` command or 'after/ftplugin' approach to:
---     - Disable module for buffer (see 'Disabling' section).
---     - `inoremap <buffer> <*> <*>` : return mapping of '<*>' to its original
---       action, virtually unmapping.
---     - `inoremap <buffer> <expr> <*> v:lua.MiniPairs.?` : make new
---       buffer mapping for '<*>'.
---
--- # Setup
---
--- This module needs a setup with `require('mini.pairs').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`:
--- <pre>
--- {
---   -- In which modes mappings should be created
---   modes = {insert = true, command = false, terminal = false}
--- }
--- </pre>
---
--- By default in `MiniPairs.setup()`:
--- - The following pairs are respected: `()`, `[]`, `{}`, `""`, `''`, `\`\``.
---   Single opening symbol is inserted after `\`. Single `'` is inserted after
---   a letter (to be used in English comments).
--- - `<BS>` respects same pairs.
--- - `<CR>` is mapped only in insert mode and respects `()`, `[]`, `{}`.
---
--- # Example mappings
---
--- <pre>
--- - Insert `<>` pair if `<` is typed as first character in line:
---     Vimscript:
---     `inoremap <expr> < v:lua.MiniPairs.open('<>', "\r.")`
---     `inoremap <expr> > v:lua.MiniPairs.close('<>', "..")`
---     Lua:
---     `vim.api.nvim_set_keymap('i', '<', [[v:lua.MiniPairs.open('<>', "\r.")]], { expr = true, noremap = true })`
---     `vim.api.nvim_set_keymap('i', '>', [[v:lua.MiniPairs.close('<>', "..")]], { expr = true, noremap = true })`
--- - Create symmerical `$$` pair only in Tex files:
---     Vimscript:
---     `au FileType tex inoremap <buffer> <expr> $ v:lua.MiniPairs.closeopen('$$', "[^\\].")`
---     Lua:
---     `au FileType tex lua vim.api.nvim_buf_set_keymap(0, 'i', '$', [[v:lua.MiniPairs.closeopen('$$', "[^\\].")]], { expr = true, noremap = true })`
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

-- Module and its helper
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

-- Module config
MiniPairs.config = {
  -- In which modes mappings should be created
  modes = { insert = true, command = false, terminal = false },
}

-- Module functionality
--- Process 'open' symbols
---
--- Use this for mapping 'open' symbols in asymmetric pair ('(', '[', etc.). If
--- neighborhood doesn't match supplied pattern, function results into 'open'
--- symbol. Otherwise, it pastes whole pair and moves inside pair with
--- |<Left>|.
---
--- Example:
--- <pre>
--- - Vimscript: `inoremap <expr> ( v:lua.MiniPairs.open('()', "[^\\].")`
--- - Lua: `vim.api.nvim_set_keymap('i', '(', [[v:lua.MiniPairs.open('()', "[^\\].")]], { expr = true, noremap = true })`
--- </pre>
---
---@param pair string: String with two characters representing pair.
---@param twochars_pattern string: Pattern for two neighborhood characters ("\r" line start, "\n" - line end).
function MiniPairs.open(pair, twochars_pattern)
  if H.is_disabled() or not H.neigh_match(twochars_pattern) then
    return pair:sub(1, 1)
  end

  return pair .. H.get_arrow_key('left')
end

--- Process 'close' symbols
---
--- Use this for mapping 'close' symbols in asymmetric pair (')', ']', etc.).
--- If neighborhood doesn't match supplied pattern, function results into
--- 'close' symbol. Otherwise it jumps over symbol to the right of cursor (with
--- |<Right>|) if it is equal to 'close' one and inserts it otherwise.
---
--- Example:
--- <pre>
--- - Vimscript: `inoremap <expr> ) v:lua.MiniPairs.close('()', "[^\\].")`
--- - Lua: `vim.api.nvim_set_keymap('i', ')', [[v:lua.MiniPairs.close('()', "[^\\].")]], { expr = true, noremap = true })`
--- </pre>
---
---@param pair string: String with two characters representing pair.
---@param twochars_pattern string: Pattern for two neighborhood characters ("\r" line start, "\n" - line end).
function MiniPairs.close(pair, twochars_pattern)
  if H.is_disabled() or not H.neigh_match(twochars_pattern) then
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
--- Use this for mapping 'symmetrical' symbols (from pairs '""', '\'\'', '``').
--- It tries to perform 'closeopen action': move over right character (with
--- |<Right>|) if it is equal to second character from pair or conditionally
--- paste pair otherwise (with |MiniPairs.open()|).
---
--- Example:
--- <pre>
--- - Vimscript: `inoremap <expr> " v:lua.MiniPairs.closeopen('""', "[^\\].")`
--- - Lua: `vim.api.nvim_set_keymap('i', '"', [[v:lua.MiniPairs.closeopen('""', "[^\\].")]], { expr = true, noremap = true })`
--- </pre>
---
---@param pair string: String with two characters representing pair.
---@param twochars_pattern string: Pattern for two neighborhood characters ("\r" line start, "\n" - line end).
function MiniPairs.closeopen(pair, twochars_pattern)
  if H.is_disabled() or not (H.get_cursor_neigh(1, 1) == pair:sub(2, 2)) then
    return MiniPairs.open(pair, twochars_pattern)
  else
    return H.get_arrow_key('right')
  end
end

--- Process |<BS>|
---
--- Use this to map `<BS>`. It removes whole pair (via `<BS><Del>`) if
--- neighborhood is equal to whole pair.
---
--- Example:
--- <pre>
--- - Vimscript: `inoremap <expr> <BS> v:lua.MiniPairs.bs(['()', '[]', '{}', '""', "''", '``'])`
--- - Lua: `vim.api.nvim_set_keymap('i', '<BS>', [[v:lua.MiniPairs.bs(['()', '[]', '{}', '""', "''", '``'])]], { expr = true, noremap = true })`
--- </pre>
---
---@param pair_set table: List with pairs which trigger extra action.
function MiniPairs.bs(pair_set)
  local res = H.keys.bs

  if not H.is_disabled() and H.is_in_table(H.get_cursor_neigh(0, 1), pair_set) then
    res = res .. H.keys.del
  end

  return res
end

--- Process |i_<CR>|
---
--- Use this to map `<CR>` in insert mode. It puts "close" symbol on next line
--- (via `<CR><C-o>O`) if neighborhood is equal to whole pair. Should be used
--- only in insert mode.
---
--- Example:
--- <pre>
--- - Vimscript: `inoremap <expr> <CR> v:lua.MiniPairs.cr(['()', '[]', '{}'])`
--- - Lua: `vim.api.nvim_set_keymap('i', '<CR>', [[v:lua.MiniPairs.cr(['()', '[]', '{}'])]], { expr = true, noremap = true })`
--- </pre>
---
---@param pair_set table: List with pairs which trigger extra action.
function MiniPairs.cr(pair_set)
  local res = H.keys.cr

  if not H.is_disabled() and H.is_in_table(H.get_cursor_neigh(0, 1), pair_set) then
    res = res .. H.keys.above
  end

  return res
end

-- Helpers
---- Module default config
H.default_config = MiniPairs.config

---- Settings
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
  })

  return config
end

function H.apply_config(config)
  MiniPairs.config = config

  -- Setup mappings in supplied modes
  local mode_ids = { insert = 'i', command = 'c', terminal = 't' }
  ---- Compute in which modes mapping should be set up
  local mode_list = {}
  for name, to_set in pairs(config.modes) do
    if to_set then
      table.insert(mode_list, mode_ids[name])
    end
  end

  for _, mode in pairs(mode_list) do
    -- Adding pair is disabled if symbol is after `\`
    H.map(mode, '(', [[v:lua.MiniPairs.open('()', "[^\\].")]])
    H.map(mode, '[', [[v:lua.MiniPairs.open('[]', "[^\\].")]])
    H.map(mode, '{', [[v:lua.MiniPairs.open('{}', "[^\\].")]])

    H.map(mode, ')', [[v:lua.MiniPairs.close("()", "[^\\].")]])
    H.map(mode, ']', [[v:lua.MiniPairs.close("[]", "[^\\].")]])
    H.map(mode, '}', [[v:lua.MiniPairs.close("{}", "[^\\].")]])

    H.map(mode, '"', [[v:lua.MiniPairs.closeopen('""', "[^\\].")]])
    ---- Single quote is used in plain English, so disable pair after a letter
    H.map(mode, "'", [[v:lua.MiniPairs.closeopen("''", "[^%a\\].")]])
    H.map(mode, '`', [[v:lua.MiniPairs.closeopen('``', "[^\\].")]])

    H.map(mode, '<BS>', [[v:lua.MiniPairs.bs(['()', '[]', '{}', '""', "''", '``'])]])

    if mode == 'i' then
      H.map('i', '<CR>', [[v:lua.MiniPairs.cr(['()', '[]', '{}'])]])
    end
  end
end

function H.is_disabled()
  return vim.g.minipairs_disable == true or vim.b.minipairs_disable == true
end

---- Various helpers
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
  return string.sub('\r' .. line .. '\n', col + 1 + start, col + 1 + finish)
end

function H.neigh_match(pattern)
  return (pattern == nil) or (H.get_cursor_neigh(0, 1):find(pattern) ~= nil)
end

function H.escape(s)
  return vim.api.nvim_replace_termcodes(s, true, true, true)
end

-- stylua: ignore start
H.keys = {
  above     = H.escape('<C-o>O'),
  bs        = H.escape('<bs>'),
  cr        = H.escape('<cr>'),
  del       = H.escape('<del>'),
  keep_undo = H.escape('<C-g>U'),
  -- NOTE: use `get_arrow_key()` instead of `H.keys.left` or `H.keys.right`
  left      = H.escape('<left>'),
  right     = H.escape('<right>')
}
-- stylua: ignore end

function H.get_arrow_key(key)
  if vim.fn.mode() == 'i' then
    -- Using left/right keys in insert mode breaks undo sequence and, more
    -- importantly, dot-repeat. To avoid this, use 'i_CTRL-G_U' mapping.
    return H.keys.keep_undo .. H.keys[key]
  else
    return H.keys[key]
  end
end

function H.is_in_table(val, tbl)
  if tbl == nil then
    return false
  end
  for _, value in pairs(tbl) do
    if val == value then
      return true
    end
  end
  return false
end

return MiniPairs
