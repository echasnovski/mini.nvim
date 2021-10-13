-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom minimal and fast module for autohighlighting word under cursor with
--- customizable delay. It is triggered only if current cursor character is a
--- |[:keyword:]|. "Word under cursor" is meant as in Vim's |<cword>|:
--- something user would get as 'iw' text object. Highlighting stops in insert
--- and terminal modes.
---
--- # Setup
---
--- This module needs a setup with `require('mini.cursorword').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`:
--- <pre>
--- {
---  -- Delay (in ms) between when cursor moved and when highlighting appeared
---  delay = 100,
--- }
--- </pre>
---
--- # Highlight groups
---
--- 1. `MiniCursorword` - highlight group of cursor word. Default: plain
---    underline.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling
---
--- To disable core functionality, set `g:minicursorword_disable` (globally) or
--- `b:minicursorword_disable` (for a buffer) to `v:true`. Note: after
--- disabling there might be highlighting left; it will be removed after next
--- highlighting update.
---@brief ]]
---@tag MiniCursorword mini.cursorword

-- Module and its helper
local MiniCursorword = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.cursorword').setup({})` (replace `{}` with your `config` table)
function MiniCursorword.setup(config)
  -- Export module
  _G.MiniCursorword = MiniCursorword

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  vim.api.nvim_exec(
    [[augroup MiniCursorword
        au!
        au CursorMoved                   * lua MiniCursorword.auto_highlight()
        au InsertEnter,TermEnter,QuitPre * lua MiniCursorword.auto_unhighlight()

        au FileType TelescopePrompt let b:minicursorword_disable=v:true
      augroup END]],
    false
  )

  -- Create highlighting
  vim.api.nvim_exec([[hi MiniCursorword term=underline cterm=underline gui=underline]], false)
end

-- Module config
MiniCursorword.config = {
  -- Delay (in ms) between when cursor moved and when highlighting appeared
  delay = 100,
}

--- Auto highlight word under cursor
---
--- Designed to be used with |autocmd|. No need to use it directly,
--- everything is setup in |MiniCursorword.setup|.
function MiniCursorword.auto_highlight()
  -- Stop any possible previous delayed highlighting
  H.timer:stop()

  -- Stop highlighting immediately if module is disabled when cursor is not on
  -- 'keyword'
  if H.is_disabled() or not H.is_cursor_on_keyword() then
    H.unhighlight()
    return
  end

  -- Get current information
  local win_id = vim.fn.win_getid()
  local win_match = H.window_matches[win_id] or {}
  local curword = H.get_cursor_word()

  -- Don't do anything if currently highlighted word equals one under cursor
  if win_match.word == curword then
    return
  end

  -- Stop highlighting previous match (if it exists)
  H.unhighlight()

  -- Delay highlighting
  H.timer:start(
    MiniCursorword.config.delay,
    0,
    vim.schedule_wrap(function()
      -- Ensure that always only one word is highlighted
      H.unhighlight()
      H.highlight()
    end)
  )
end

--- Auto unhighlight word under cursor
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |MiniCursorword.setup|.
function MiniCursorword.auto_unhighlight()
  -- Stop any possible previous delayed highlighting
  H.timer:stop()
  H.unhighlight()
end

-- Helper data
---- Module default config
H.default_config = MiniCursorword.config

---- Delay timer
H.timer = vim.loop.new_timer()

---- Information about last match highlighting: word and match id (returned
---- from `vim.fn.matchadd()`). Stored *per window* by its unique identifier.
H.window_matches = {}

-- Helper functions
---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({ delay = { config.delay, 'number' } })

  return config
end

function H.apply_config(config)
  MiniCursorword.config = config
end

function H.is_disabled()
  return vim.g.minicursorword_disable == true or vim.b.minicursorword_disable == true
end

---- Highlighting
function H.highlight()
  -- A modified version of https://stackoverflow.com/a/25233145
  -- Using `matchadd()` instead of a simpler `:match` to tweak priority of
  -- 'current word' highlighting: with `:match` it is higher than for
  -- `incsearch` which is not convenient.

  local curword = H.get_cursor_word()

  -- Make highlighting pattern 'very nomagic' ('\V') and to match whole word
  -- ('\<' and '\>')
  local curpattern = string.format([[\V\<%s\>]], curword)

  -- Add match highlight with very low priority and store match information
  local win_id = vim.fn.win_getid()
  local match_id = vim.fn.matchadd('MiniCursorword', curpattern, -1)
  H.window_matches[win_id] = { word = curword, id = match_id }
end

function H.unhighlight()
  local win_id = vim.fn.win_getid()
  local win_match = H.window_matches[win_id]
  if win_match ~= nil then
    vim.fn.matchdelete(win_match.id)
    H.window_matches[win_id] = nil
  end
end

function H.is_cursor_on_keyword()
  local col = vim.fn.col('.')
  local curchar = vim.fn.getline('.'):sub(col, col)

  return vim.fn.match(curchar, '[[:keyword:]]') >= 0
end

function H.get_cursor_word()
  return vim.fn.escape(vim.fn.expand('<cword>'), [[\/]])
end

return MiniCursorword
