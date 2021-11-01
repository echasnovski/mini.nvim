-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Custom somewhat minimal autocompletion Lua plugin. Key design ideas:
--- - Have an async (with customizable 'debounce' delay) 'two-stage chain
---   completion': first try to get completion items from LSP client (if set
---   up) and if no result, fallback to custom action.
--- - Managing completion is done as much with Neovim's built-in tools as
---   possible.
---
--- Features:
--- - Two-stage chain completion:
---     - First stage is an LSP completion implemented via
---       |MiniCompletion.completefunc_lsp()|. It should be set up as either
---       |completefunc| or |omnifunc|. It tries to get completion items from LSP client
---       (via 'textDocument/completion' request). Custom preprocessing of
---       response items is possible (with
---       `MiniCompletion.config.lsp_completion.process_items`), for example
---       with fuzzy matching. By default items which are not snippets and
---       directly start with completed word are kept and sorted according to
---       LSP specification.
---     - If first stage is not set up or resulted into no candidates, fallback
---       action is executed. The most tested actions are Neovim's built-in
---       insert completion (see |ins-completion|).
--- - Automatic display in floating window of completion item info and signature
---   help (with highlighting of active parameter if LSP server provides such
---   information). After opening, window for signature help is fixed and is
---   closed when there is nothing to show, text is different or when leaving
---   Insert mode.
--- - Automatic actions are done after some configurable amount of delay. This
---   reduces computational load and allows fast typing (completion and
---   signature help) and item selection (item info)
--- - Autoactions are triggered on Neovim's built-in events.
--- - User can force two-stage completion via
---   |MiniCompletion.complete_twostage()| (by default is mapped to
---   `<C-Space>`) or fallback completion via
---   |MiniCompletion.complete_fallback()| (maped to `<M-Space>`).
---
--- What it doesn't do:
--- - Snippet expansion.
--- - Many configurable sources.
---
--- # Setup
---
--- This module needs a setup with `require('mini.completion').setup({})`
--- (replace `{}` with your `config` table).
---
--- Default `config`:
--- <pre>
--- {
---   -- Delay (debounce type, in ms) between certain Neovim event and action.
---   -- This can be used to (virtually) disable certain automatic actions by
---   -- setting very high delay time (like 10^7).
---   delay = {completion = 100, info = 100, signature = 50},
---
---   -- Maximum dimensions of floating windows for certain actions. Action entry
---   -- should be a table with 'height' and 'width' fields.
---   window_dimensions = {
---     info = {height = 25, width = 80},
---     signature = {height = 25, width = 80}
---   },
---
---   -- Way of how module does LSP completion:
---   -- - `source_func` should be one of 'completefunc' or 'omnifunc'.
---   -- - `auto_setup` should be boolean indicating if LSP completion is set up on
---   --   every `BufEnter` event.
---   -- - `process_items` should be a function which takes LSP
---   --   'textDocument/completion' response items and word to complete. Its
---   --   output should be a table of the same nature as input items. The most
---   --   common use-cases are custom filtering and sorting. You can use
---   --   default `process_items` as `MiniCompletion.default_process_items()`.
---   lsp_completion = {
---     source_func = 'completefunc',
---     auto_setup = true,
---     process_items = --<function: filters 'not snippets' by prefix and sorts by LSP specification>,
---   },
---
---   -- Fallback action. It will always be run in Insert mode. To use Neovim's
---   -- built-in completion (see `:h ins-completion`), supply its mapping as
---   -- string. For example, to use 'whole lines' completion, supply '<C-x><C-l>'.
---   fallback_action = --<function equivalent to '<C-n>' completion>,
---
---   -- Module mappings. Use `''` (empty string) to disable one. Some of them
---   -- might conflict with system mappings.
---   mappings = {
---     force_twostep  = '<C-Space>', -- Force two-step completion
---     force_fallback = '<A-Space>'  -- Force fallback completion
---   }
---
---   -- Whether to set Vim's settings for better experience (modifies
---   -- `shortmess` and `completeopt`)
---   set_vim_settings = true
--- }
--- </pre>
---
--- # Notes
--- - More appropriate, albeit slightly advanced, LSP completion setup is to set
---   it not on every `BufEnter` event (default), but on every attach of LSP
---   client. To do that:
---     - Use in initial config: `lsp_completion = {source_func = 'omnifunc',
---       auto_setup = false}`.
---     - In `on_attach()` of every LSP client set 'omnifunc' option to exactly
---       `v:lua.MiniCompletion.completefunc_lsp`.
---
--- # Comparisons
---
--- - 'completion-nvim':
---     - Has timer activated on InsertEnter which does something every period
---       of time (makes LSP request, shows floating help). MiniCompletion
---       relies on Neovim's (Vim's) events.
---     - Uses 'textDocument/hover' request to show completion item info.
---     - Doesn't have highlighting of active parameter in signature help.
--- - 'nvim-cmp':
---     - More elaborate design which allows multiple sources. However, it
---       currently does not have a robust 'opened buffers' source, which is
---       very handy.
---     - Doesn't allow fallback action.
---     - Doesn't provide signature help.
--- - Both:
---     - Can manage multiple configurable sources. MiniCompletion has only two:
---       LSP and fallback.
---     - Provide advanced custom ways of filtering and sorting of completion
---       list as user types. MiniCompletion in this case relies on Neovim's
---       (which currently is equal to Vim's) filtering, which keeps only items
---       which directly start with completed word.
---     - Currently use simple text wrapping in completion item window. This
---       module wraps by words (see `:h linebreak` and `:h breakat`).
---     - Support snippet expansions.
---
--- # Highlight groups
---
--- 1. `MiniCompletionActiveParameter` - highlighting of signature active
--- parameter. Default: plain underline.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling
---
--- To disable, set `g:minicompletion_disable` (globally) or
--- `b:minicompletion_disable` (for a buffer) to `v:true`.
---@brief ]]
---@tag MiniCompletion mini.completion

-- Overall implementation design:
-- - Completion:
--     - On `InsertCharPre` event try to start auto completion. If needed,
--       start timer which after delay will start completion process. Stop this
--       timer if it is not needed.
--     - When timer is activated, first execute LSP source (if set up and there
--       is an active LSP client) by calling built-in complete function
--       (`completefunc` or `omnifunc`) which tries LSP completion by
--       asynchronously sending LSP 'textDocument/completion' request to all
--       LSP clients. When all are done, execute callback which processes
--       results, stores them in LSP cache and reruns built-in complete
--       function which produces completion popup.
--     - If previous step didn't result into any completion, execute (in Insert
--       mode and if no popup) fallback action.
-- - Documentation:
--     - On `CompleteChanged` start auto info with similar to completion timer
--       pattern.
--     - If timer is activated, try these sources of item info:
--         - 'info' field of completion item (see `:h complete-items`).
--         - 'documentation' field of LSP's previously returned result.
--         - 'documentation' field in result of asynchronous
--           'completeItem/resolve' LSP request.
--     - If info doesn't consist only from whitespace, show floating window
--       with its content. Its dimensions and position are computed based on
--       current state of Neovim's data and content itself (which will be
--       displayed wrapped with `linebreak` option).
-- - Signature help (similar to item info):
--     - On `CursorMovedI` start auto signature (if there is any active LSP
--       client) with similar to completion timer pattern. Better event might
--       be `InsertCharPre` but there are issues with 'autopair-type' plugins.
--     - Check if character left to cursor is appropriate (')' or LSP's
--       signature help trigger characters). If not, do nothing.
--     - If timer is activated, send 'textDocument/signatureHelp' request to
--       all LSP clients. On callback, process their results. Window is opened
--       if not already with the same text (its characteristics are computed
--       similar to item info). For every LSP client it shows only active
--       signature (in case there are many). If LSP response has data about
--       active parameter, it is highlighted with
--       `MiniCompletionActiveParameter` highlight group.

-- Module and its helper
local MiniCompletion = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.completion').setup({})` (replace `{}` with your `config` table)
function MiniCompletion.setup(config)
  -- Export module
  _G.MiniCompletion = MiniCompletion

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Setup module behavior
  vim.api.nvim_exec(
    [[augroup MiniCompletion
        au!
        au InsertCharPre   * lua MiniCompletion.auto_completion()
        au CompleteChanged * lua MiniCompletion.auto_info()
        au CursorMovedI    * lua MiniCompletion.auto_signature()
        au InsertLeavePre  * lua MiniCompletion.stop()
        au CompleteDonePre * lua MiniCompletion.stop({'completion', 'info'})
        au TextChangedI    * lua MiniCompletion.on_text_changed_i()
        au TextChangedP    * lua MiniCompletion.on_text_changed_p()

        au FileType TelescopePrompt let b:minicompletion_disable=v:true
      augroup END]],
    false
  )

  if config.lsp_completion.auto_setup then
    local command = string.format(
      [[augroup MiniCompletion
          au BufEnter * setlocal %s=v:lua.MiniCompletion.completefunc_lsp
        augroup END]],
      config.lsp_completion.source_func
    )
    vim.api.nvim_exec(command, false)
  end

  -- Create highlighting
  vim.api.nvim_exec([[hi default MiniCompletionActiveParameter term=underline cterm=underline gui=underline]], false)
end

-- Module config
MiniCompletion.config = {
  -- Delay (debounce type, in ms) between certain Neovim event and action.
  -- This can be used to (virtually) disable certain automatic actions by
  -- setting very high delay time (like 10^7).
  delay = { completion = 100, info = 100, signature = 50 },

  -- Maximum dimensions of floating windows for certain actions. Action entry
  -- should be a table with 'height' and 'width' fields.
  window_dimensions = {
    info = { height = 25, width = 80 },
    signature = { height = 25, width = 80 },
  },

  -- Way of how module does LSP completion
  lsp_completion = {
    -- `source_func` should be one of 'completefunc' or 'omnifunc'.
    source_func = 'completefunc',

    -- `auto_setup` should be boolean indicating if LSP completion is set up on
    -- every `BufEnter` event.
    auto_setup = true,

    -- `process_items` should be a function which takes LSP
    -- 'textDocument/completion' response items and word to complete. Its
    -- output should be a table of the same nature as input items. The most
    -- common use-cases are custom filtering and sorting. You can use default
    -- `process_items` as `MiniCompletion.default_process_items()`.
    process_items = function(items, base)
      local res = vim.tbl_filter(function(item)
        -- Keep items which match the base and are not snippets
        return vim.startswith(H.get_completion_word(item), base) and item.kind ~= 15
      end, items)

      table.sort(res, function(a, b)
        return (a.sortText or a.label) < (b.sortText or b.label)
      end)

      return res
    end,
  },

  -- Fallback action. It will always be run in Insert mode. To use Neovim's
  -- built-in completion (see `:h ins-completion`), supply its mapping as
  -- string. For example, to use 'whole lines' completion, supply '<C-x><C-l>'.
  fallback_action = function()
    vim.api.nvim_feedkeys(H.keys.ctrl_n, 'n', false)
  end,

  -- Module mappings. Use `''` (empty string) to disable one. Some of them
  -- might conflict with system mappings.
  mappings = {
    force_twostep = '<C-Space>', -- Force two-step completion
    force_fallback = '<A-Space>', -- Force fallback completion
  },

  -- Whether to set Vim's settings for better experience
  set_vim_settings = true,
}

-- Module functionality
--- Auto completion
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |MiniCompletion.setup|.
function MiniCompletion.auto_completion()
  if H.is_disabled() then
    return
  end

  H.completion.timer:stop()

  -- Don't do anything if popup is visible
  if H.pumvisible() then
    -- Keep completion source as it is needed all time when popup is visible
    H.stop_completion(true)
    return
  end

  -- Stop everything if inserted character is not appropriate
  local char_is_trigger = H.is_lsp_trigger(vim.v.char, 'completion')
  if not (H.is_char_keyword(vim.v.char) or char_is_trigger) then
    H.stop_completion(false)
    return
  end

  -- If character is purely lsp trigger, make new LSP request without fallback
  -- and force new completion
  if char_is_trigger then
    H.cancel_lsp()
  end
  H.completion.fallback, H.completion.force = not char_is_trigger, char_is_trigger

  -- Cache id of Insert mode "text changed" event for a later tracking (reduces
  -- false positive delayed triggers). The intention is to trigger completion
  -- after the delay only if text wasn't changed during waiting. Using only
  -- `InsertCharPre` is not enough though, as not every Insert mode change
  -- triggers `InsertCharPre` event (notable example - hitting `<CR>`).
  -- Also, using `+ 1` here because it is a `Pre` event and needs to cache
  -- after inserting character.
  H.completion.text_changed_id = H.text_changed_id + 1

  -- Using delay (of debounce type) actually improves user experience
  -- as it allows fast typing without many popups.
  H.completion.timer:start(MiniCompletion.config.delay.completion, 0, vim.schedule_wrap(H.trigger_twostep))
end

--- Run two-stage completion
---
---@param fallback boolean: Whether to use fallback completion.
---@param force boolean: Whether to force update of completion popup.
function MiniCompletion.complete_twostage(fallback, force)
  if H.is_disabled() then
    return
  end

  H.stop_completion()
  H.completion.fallback, H.completion.force = fallback or true, force or true
  H.trigger_twostep()
end

--- Run fallback completion
function MiniCompletion.complete_fallback()
  if H.is_disabled() then
    return
  end

  H.stop_completion()
  H.completion.fallback, H.completion.force = true, true
  H.trigger_fallback()
end

--- Auto completion entry information
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |MiniCompletion.setup|.
function MiniCompletion.auto_info()
  if H.is_disabled() then
    return
  end

  H.info.timer:stop()

  -- Defer execution because of textlock during `CompleteChanged` event
  -- Don't stop timer when closing info window because it is needed
  vim.defer_fn(function()
    H.close_action_window(H.info, true)
  end, 0)

  -- Stop current LSP request that tries to get not current data
  H.cancel_lsp({ H.info })

  -- Update metadata before leaving to register a `CompleteChanged` event
  H.info.event = vim.v.event
  H.info.id = H.info.id + 1

  -- Don't event try to show info if nothing is selected in popup
  if vim.tbl_isempty(H.info.event.completed_item) then
    return
  end

  H.info.timer:start(MiniCompletion.config.delay.info, 0, vim.schedule_wrap(H.show_info_window))
end

--- Auto function signature
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |MiniCompletion.setup|.
function MiniCompletion.auto_signature()
  if H.is_disabled() then
    return
  end

  H.signature.timer:stop()
  if not H.has_lsp_clients('signature_help') then
    return
  end

  local left_char = H.get_left_char()
  local char_is_trigger = left_char == ')' or H.is_lsp_trigger(left_char, 'signature')
  if not char_is_trigger then
    return
  end

  H.signature.timer:start(MiniCompletion.config.delay.signature, 0, vim.schedule_wrap(H.show_signature_window))
end

--- Stop actions
---
--- This stops currently active (because of module delay or LSP answer delay)
--- actions.
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |MiniCompletion.setup|.
---
---@param actions table: List containing any of 'completion', 'info', or 'signature' string.
function MiniCompletion.stop(actions)
  actions = actions or { 'completion', 'info', 'signature' }
  for _, n in pairs(actions) do
    H.stop_actions[n]()
  end
end

--- Act on every |TextChangedI|
function MiniCompletion.on_text_changed_i()
  -- Track Insert mode changes
  H.text_changed_id = H.text_changed_id + 1

  -- Stop 'info' processes in case no completion event is triggered but popup
  -- is not visible. See https://github.com/neovim/neovim/issues/15077
  H.stop_info()
end

--- Act on every |TextChangedP|
function MiniCompletion.on_text_changed_p()
  -- Track Insert mode changes
  H.text_changed_id = H.text_changed_id + 1
end

--- Module's |complete-function|
---
--- This is the main function which enables two-stage completion. It should be
--- set as one of |completefunc| or |omnifunc|.
---
--- No need to use it directly, everything is setup in |MiniCompletion.setup|.
function MiniCompletion.completefunc_lsp(findstart, base)
  -- Early return
  if (not H.has_lsp_clients('completion')) or H.completion.lsp.status == 'sent' then
    if findstart == 1 then
      return -3
    else
      return {}
    end
  end

  -- NOTE: having code for request inside this function enables its use
  -- directly with `<C-x><...>`.
  if H.completion.lsp.status ~= 'received' then
    local current_id = H.completion.lsp.id + 1
    H.completion.lsp.id = current_id
    H.completion.lsp.status = 'sent'

    local bufnr = vim.api.nvim_get_current_buf()
    local params = vim.lsp.util.make_position_params()

    -- NOTE: it is CRUCIAL to make LSP request on the first call to
    -- 'complete-function' (as in Vim's help). This is due to the fact that
    -- cursor line and position are different on the first and second calls to
    -- 'complete-function'. For example, when calling this function at the end
    -- of the line '  he', cursor position on the second call will be
    -- (<linenum>, 4) and line will be '  he' but on the second call -
    -- (<linenum>, 2) and '  ' (because 2 is a column of completion start).
    -- This request is executed only on first call because it returns `-3` on
    -- first call (which means cancel and leave completion mode).
    -- NOTE: using `buf_request_all()` (instead of `buf_request()`) to easily
    -- handle possible fallback and to have all completion suggestions be
    -- filtered with one `base` in the other route of this function. Anyway,
    -- the most common situation is with one attached LSP client.
    local cancel_fun = vim.lsp.buf_request_all(bufnr, 'textDocument/completion', params, function(result)
      if not H.is_lsp_current(H.completion, current_id) then
        return
      end

      H.completion.lsp.status = 'received'
      H.completion.lsp.result = result

      -- Trigger LSP completion to take 'received' route
      H.trigger_lsp()
    end)

    -- Cache cancel function to disable requests when they are not needed
    H.completion.lsp.cancel_fun = cancel_fun

    -- End completion and wait for LSP callback
    if findstart == 1 then
      return -3
    else
      return {}
    end
  else
    if findstart == 1 then
      return H.get_completion_start()
    end

    local words = H.process_lsp_response(H.completion.lsp.result, function(response)
      -- Response can be `CompletionList` with 'items' field or `CompletionItem[]`
      local items = H.table_get(response, { 'items' }) or response
      if type(items) ~= 'table' then
        return {}
      end
      items = MiniCompletion.config.lsp_completion.process_items(items, base)
      return H.lsp_completion_response_items_to_complete_items(items)
    end)

    H.completion.lsp.status = 'done'

    -- Maybe trigger fallback action
    if vim.tbl_isempty(words) and H.completion.fallback then
      H.trigger_fallback()
      return
    end

    -- Track from which source is current popup
    H.completion.source = 'lsp'
    return words
  end
end

--- Default `MiniCompletion.config.lsp_completion.process_items`.
function MiniCompletion.default_process_items(items, base)
  return H.default_config.lsp_completion.process_items(items, base)
end

-- Helper data
---- Module default config
H.default_config = MiniCompletion.config

---- Track Insert mode changes
H.text_changed_id = 0

---- Commonly used key sequences
H.keys = {
  completefunc = vim.api.nvim_replace_termcodes('<C-x><C-u>', true, false, true),
  omnifunc = vim.api.nvim_replace_termcodes('<C-x><C-o>', true, false, true),
  ctrl_n = vim.api.nvim_replace_termcodes('<C-g><C-g><C-n>', true, false, true),
}

---- Caches for different actions. Field `lsp` is a table describing state of
---- all used LSP requests. It has the following structure:
---- - id: identifier (consecutive numbers).
---- - status: status. One of 'sent', 'received', 'done', 'canceled'.
---- - result: result of request.
---- - cancel_fun: function which cancels current request.
------ Cache for completion
H.completion = {
  fallback = true,
  force = false,
  source = nil,
  text_changed_id = 0,
  timer = vim.loop.new_timer(),
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

------ Cache for completion item info
H.info = {
  bufnr = nil,
  event = nil,
  id = 0,
  timer = vim.loop.new_timer(),
  winnr = nil,
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

------ Cache for signature help
H.signature = {
  bufnr = nil,
  text = nil,
  timer = vim.loop.new_timer(),
  winnr = nil,
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

-- Helper functions
---- Settings
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({
    delay = { config.delay, 'table' },
    ['delay.completion'] = { config.delay.completion, 'number' },
    ['delay.info'] = { config.delay.info, 'number' },
    ['delay.signature'] = { config.delay.signature, 'number' },

    window_dimensions = { config.window_dimensions, 'table' },
    ['window_dimensions.info'] = { config.window_dimensions.info, 'table' },
    ['window_dimensions.info.height'] = { config.window_dimensions.info.height, 'number' },
    ['window_dimensions.info.width'] = { config.window_dimensions.info.width, 'number' },
    ['window_dimensions.signature'] = { config.window_dimensions.signature, 'table' },
    ['window_dimensions.signature.height'] = { config.window_dimensions.signature.height, 'number' },
    ['window_dimensions.signature.width'] = { config.window_dimensions.signature.width, 'number' },

    lsp_completion = { config.lsp_completion, 'table' },
    ['lsp_completion.source_func'] = {
      config.lsp_completion.source_func,
      function(x)
        return x == 'completefunc' or x == 'omnifunc'
      end,
      'one of strings: "completefunc" or "omnifunc"',
    },
    ['lsp_completion.auto_setup'] = { config.lsp_completion.auto_setup, 'boolean' },
    ['lsp_completion.process_items'] = { config.lsp_completion.process_items, 'function' },

    fallback_action = {
      config.fallback_action,
      function(x)
        return type(x) == 'function' or type(x) == 'string'
      end,
      'function or string',
    },

    mappings = { config.mappings, 'table' },
    ['mappings.force_twostep'] = { config.mappings.force_twostep, 'string' },
    ['mappings.force_fallback'] = { config.mappings.force_fallback, 'string' },

    set_vim_settings = { config.set_vim_settings, 'boolean' },
  })

  return config
end

function H.apply_config(config)
  MiniCompletion.config = config

  H.keymap(
    'i',
    config.mappings.force_twostep,
    '<cmd>lua MiniCompletion.complete_twostage()<cr>',
    { noremap = true, silent = true }
  )
  H.keymap(
    'i',
    config.mappings.force_fallback,
    '<cmd>lua MiniCompletion.complete_fallback()<cr>',
    { noremap = true, silent = true }
  )

  if config.set_vim_settings then
    -- Don't give ins-completion-menu messages
    vim.cmd([[set shortmess+=c]])
    -- More common completion behavior
    vim.cmd([[set completeopt=menuone,noinsert,noselect]])
  end
end

function H.is_disabled()
  return vim.g.minicompletion_disable == true or vim.b.minicompletion_disable == true
end

---- Completion triggers
function H.trigger_twostep()
  -- Trigger only in Insert mode and if text didn't change after trigger
  -- request, unless completion is forced
  -- NOTE: check for `text_changed_id` equality is still not 100% solution as
  -- there are cases when, for example, `<CR>` is hit just before this check.
  -- Because of asynchronous id update and this function call (called after
  -- delay), these still match.
  local allow_trigger = (vim.fn.mode() == 'i')
    and (H.completion.force or (H.completion.text_changed_id == H.text_changed_id))
  if not allow_trigger then
    return
  end

  if H.has_lsp_clients('completion') and H.has_lsp_completion() then
    H.trigger_lsp()
  elseif H.completion.fallback then
    H.trigger_fallback()
  end
end

function H.trigger_lsp()
  -- Check for popup visibility is needed to reduce flickering.
  -- Possible issue timeline (with 100ms delay with set up LSP):
  -- 0ms: Key is pressed.
  -- 100ms: LSP is triggered from first key press.
  -- 110ms: Another key is pressed.
  -- 200ms: LSP callback is processed, triggers complete-function which
  --   processes "received" LSP request.
  -- 201ms: LSP request is processed, completion is (should be almost
  --   immediately) provided, request is marked as "done".
  -- 210ms: LSP is triggered from second key press. As previous request is
  --   "done", it will once make whole LSP request. Having check for visible
  --   popup should prevent here the call to complete-function.

  -- When `force` is `true` then presence of popup shouldn't matter.
  local no_popup = H.completion.force or (not H.pumvisible())
  if no_popup and vim.fn.mode() == 'i' then
    local key = H.keys[MiniCompletion.config.lsp_completion.source_func]
    vim.api.nvim_feedkeys(key, 'n', false)
  end
end

function H.trigger_fallback()
  local no_popup = H.completion.force or (not H.pumvisible())
  if no_popup and vim.fn.mode() == 'i' then
    -- Track from which source is current popup
    H.completion.source = 'fallback'
    if type(MiniCompletion.config.fallback_action) == 'string' then
      -- Having `<C-g><C-g>` also (for some mysterious reason) helps to avoid
      -- some weird behavior. For example, if `keys = '<C-x><C-l>'` then Neovim
      -- starts new line when there is no suggestions.
      local keys = string.format('<C-g><C-g>%s', MiniCompletion.config.fallback_action)
      local trigger_keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
      vim.api.nvim_feedkeys(trigger_keys, 'n', false)
    else
      MiniCompletion.config.fallback_action()
    end
  end
end

---- Stop actions
function H.stop_completion(keep_source)
  H.completion.timer:stop()
  H.cancel_lsp({ H.completion })
  H.completion.fallback, H.completion.force = true, false
  if not keep_source then
    H.completion.source = nil
  end
end

function H.stop_info()
  -- Id update is needed to notify that all previous work is not current
  H.info.id = H.info.id + 1
  H.info.timer:stop()
  H.cancel_lsp({ H.info })
  H.close_action_window(H.info)
end

function H.stop_signature()
  H.signature.text = nil
  H.signature.timer:stop()
  H.cancel_lsp({ H.signature })
  H.close_action_window(H.signature)
end

H.stop_actions = {
  completion = H.stop_completion,
  info = H.stop_info,
  signature = H.stop_signature,
}

---- LSP
--@param capability string|nil: Capability to check (as in `resolved_capabilities` of `vim.lsp.buf_get_clients` output).
--@return boolean: Whether there is at least one LSP client that has resolved `capability`.
function H.has_lsp_clients(capability)
  local clients = vim.lsp.buf_get_clients()
  if vim.tbl_isempty(clients) then
    return false
  end
  if not capability then
    return true
  end

  for _, c in pairs(clients) do
    if c.resolved_capabilities[capability] then
      return true
    end
  end
  return false
end

function H.has_lsp_completion()
  local func = vim.api.nvim_buf_get_option(0, MiniCompletion.config.lsp_completion.source_func)
  return func == 'v:lua.MiniCompletion.completefunc_lsp'
end

function H.is_lsp_trigger(char, type)
  local triggers
  local providers = {
    completion = 'completionProvider',
    signature = 'signatureHelpProvider',
  }

  for _, client in pairs(vim.lsp.buf_get_clients()) do
    triggers = H.table_get(client, { 'server_capabilities', providers[type], 'triggerCharacters' })
    if vim.tbl_contains(triggers or {}, char) then
      return true
    end
  end
  return false
end

function H.cancel_lsp(caches)
  caches = caches or { H.completion, H.info, H.signature }
  for _, c in pairs(caches) do
    if vim.tbl_contains({ 'sent', 'received' }, c.lsp.status) then
      if c.lsp.cancel_fun then
        c.lsp.cancel_fun()
      end
      c.lsp.status = 'canceled'
    end
  end
end

function H.process_lsp_response(request_result, processor)
  if not request_result then
    return {}
  end

  local res = {}
  for _, item in pairs(request_result) do
    if not item.err and item.result then
      vim.list_extend(res, processor(item.result) or {})
    end
  end

  return res
end

function H.is_lsp_current(cache, id)
  return cache.lsp.id == id and cache.lsp.status == 'sent'
end

---- Completion
------ This is a truncated version of
------ `vim.lsp.util.text_document_completion_list_to_complete_items` which
------ does not filter and sort items.
------ For extra information see 'Response' section:
------ https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_completion
function H.lsp_completion_response_items_to_complete_items(items)
  if vim.tbl_count(items) == 0 then
    return {}
  end

  local res = {}
  local docs, info
  for _, item in pairs(items) do
    -- Documentation info
    docs = item.documentation
    info = H.table_get(docs, { 'value' })
    if not info and type(docs) == 'string' then
      info = docs
    end
    info = info or ''

    table.insert(res, {
      word = H.get_completion_word(item),
      abbr = item.label,
      kind = vim.lsp.protocol.CompletionItemKind[item.kind] or 'Unknown',
      menu = item.detail or '',
      info = info,
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = { nvim = { lsp = { completion_item = item } } },
    })
  end
  return res
end

function H.get_completion_word(item)
  -- Completion word (textEdit.newText > insertText > label). This doesn't
  -- support snippet expansion.
  return H.table_get(item, { 'textEdit', 'newText' }) or item.insertText or item.label or ''
end

---- Completion item info
function H.show_info_window()
  local event = H.info.event
  if not event then
    return
  end

  -- Try first to take lines from LSP request result.
  local lines
  if H.info.lsp.status == 'received' then
    lines = H.process_lsp_response(H.info.lsp.result, function(response)
      if not response.documentation then
        return {}
      end
      local res = vim.lsp.util.convert_input_to_markdown_lines(response.documentation)
      return vim.lsp.util.trim_empty_lines(res)
    end)

    H.info.lsp.status = 'done'
  else
    lines = H.info_window_lines(H.info.id)
  end

  -- Don't show anything if there is nothing to show
  if not lines or H.is_whitespace(lines) then
    return
  end

  -- If not already, create a permanent buffer where info will be
  -- displayed. For some reason, it is important to have it created not in
  -- `setup()` because in that case there is a small flash (which is really a
  -- brief open of window at screen top, focus on it, and its close) on the
  -- first show of info window.
  H.ensure_buffer(H.info, 'MiniCompletion:completion-item-info')

  -- Add `lines` to info buffer. Use `wrap_at` to have proper width of
  -- 'non-UTF8' section separators.
  vim.lsp.util.stylize_markdown(H.info.bufnr, lines, { wrap_at = MiniCompletion.config.window_dimensions.info.width })

  -- Compute floating window options
  local opts = H.info_window_options()

  -- Defer execution because of textlock during `CompleteChanged` event
  vim.defer_fn(function()
    -- Ensure that window doesn't open when it shouldn't be
    if not (H.pumvisible() and vim.fn.mode() == 'i') then
      return
    end
    H.open_action_window(H.info, opts)
  end, 0)
end

function H.info_window_lines(info_id)
  -- Try to use 'info' field of Neovim's completion item
  local completed_item = H.table_get(H.info, { 'event', 'completed_item' }) or {}
  local text = completed_item.info or ''

  if not H.is_whitespace(text) then
    -- Use `<text></text>` to be properly processed by `stylize_markdown()`
    local lines = { '<text>' }
    vim.list_extend(lines, vim.split(text, '\n', false))
    table.insert(lines, '</text>')
    return lines
  end

  -- If popup is not from LSP then there is nothing more to do
  if H.completion.source ~= 'lsp' then
    return nil
  end

  -- Try to get documentation from LSP's initial completion result
  local lsp_completion_item = H.table_get(completed_item, { 'user_data', 'nvim', 'lsp', 'completion_item' })
  ---- If there is no LSP's completion item, then there is no point to proceed
  ---- as it should serve as parameters to LSP request
  if not lsp_completion_item then
    return
  end
  local doc = lsp_completion_item.documentation
  if doc then
    local lines = vim.lsp.util.convert_input_to_markdown_lines(doc)
    return vim.lsp.util.trim_empty_lines(lines)
  end

  -- Finally, try request to resolve current completion to add documentation
  local bufnr = vim.api.nvim_get_current_buf()
  local params = lsp_completion_item

  local current_id = H.info.lsp.id + 1
  H.info.lsp.id = current_id
  H.info.lsp.status = 'sent'

  local cancel_fun = vim.lsp.buf_request_all(bufnr, 'completionItem/resolve', params, function(result)
    -- Don't do anything if there is other LSP request in action
    if not H.is_lsp_current(H.info, current_id) then
      return
    end

    H.info.lsp.status = 'received'

    -- Don't do anything if completion item was changed
    if H.info.id ~= info_id then
      return
    end

    H.info.lsp.result = result
    H.show_info_window()
  end)

  H.info.lsp.cancel_fun = cancel_fun

  return nil
end

function H.info_window_options()
  -- Compute dimensions based on lines to be displayed
  local lines = vim.api.nvim_buf_get_lines(H.info.bufnr, 0, -1, {})
  local info_height, info_width = H.floating_dimensions(
    lines,
    MiniCompletion.config.window_dimensions.info.height,
    MiniCompletion.config.window_dimensions.info.width
  )

  -- Compute position
  local event = H.info.event
  local left_to_pum = event.col - 1
  local right_to_pum = event.col + event.width + (event.scrollbar and 1 or 0)

  local space_left, space_right = left_to_pum, vim.o.columns - right_to_pum

  local anchor, col, space
  -- Decide side at which info window will be displayed
  if info_width <= space_right or space_left <= space_right then
    anchor, col, space = 'NW', right_to_pum, space_right
  else
    anchor, col, space = 'NE', left_to_pum, space_left
  end

  -- Possibly adjust floating window dimensions to fit screen
  if space < info_width then
    info_height, info_width = H.floating_dimensions(lines, MiniCompletion.config.window_dimensions.info.height, space)
  end

  return {
    relative = 'editor',
    anchor = anchor,
    row = event.row,
    col = col,
    width = info_width,
    height = info_height,
    focusable = false,
    style = 'minimal',
  }
end

---- Signature help
function H.show_signature_window()
  -- If there is no received LSP result, make request and exit
  if H.signature.lsp.status ~= 'received' then
    local current_id = H.signature.lsp.id + 1
    H.signature.lsp.id = current_id
    H.signature.lsp.status = 'sent'

    local bufnr = vim.api.nvim_get_current_buf()
    local params = vim.lsp.util.make_position_params()

    local cancel_fun = vim.lsp.buf_request_all(bufnr, 'textDocument/signatureHelp', params, function(result)
      if not H.is_lsp_current(H.signature, current_id) then
        return
      end

      H.signature.lsp.status = 'received'
      H.signature.lsp.result = result

      -- Trigger `show_signature` again to take 'received' route
      H.show_signature_window()
    end)

    -- Cache cancel function to disable requests when they are not needed
    H.signature.lsp.cancel_fun = cancel_fun

    return
  end

  -- Make lines to show in floating window
  local lines, hl_ranges = H.signature_window_lines()
  H.signature.lsp.status = 'done'

  -- Close window and exit if there is nothing to show
  if not lines or H.is_whitespace(lines) then
    H.close_action_window(H.signature)
    return
  end

  -- Make markdown code block
  table.insert(lines, 1, '```' .. vim.bo.filetype)
  table.insert(lines, '```')

  -- If not already, create a permanent buffer for signature
  H.ensure_buffer(H.signature, 'MiniCompletion:signature-help')

  -- Add `lines` to signature buffer. Use `wrap_at` to have proper width of
  -- 'non-UTF8' section separators.
  vim.lsp.util.stylize_markdown(
    H.signature.bufnr,
    lines,
    { wrap_at = MiniCompletion.config.window_dimensions.signature.width }
  )

  -- Add highlighting of active parameter
  for i, hl_range in ipairs(hl_ranges) do
    if not vim.tbl_isempty(hl_range) and hl_range.first and hl_range.last then
      vim.api.nvim_buf_add_highlight(
        H.signature.bufnr,
        -1,
        'MiniCompletionActiveParameter',
        i - 1,
        hl_range.first,
        hl_range.last
      )
    end
  end

  -- If window is already opened and displays the same text, don't reopen it
  local cur_text = table.concat(lines, '\n')
  if H.signature.winnr and cur_text == H.signature.text then
    return
  end

  -- Cache lines for later checks if window should be reopened
  H.signature.text = cur_text

  -- Ensure window is closed
  H.close_action_window(H.signature)

  -- Compute floating window options
  local opts = H.signature_window_opts()

  -- Ensure that window doesn't open when it shouldn't
  if vim.fn.mode() == 'i' then
    H.open_action_window(H.signature, opts)
  end
end

function H.signature_window_lines()
  local signature_data = H.process_lsp_response(H.signature.lsp.result, H.process_signature_response)
  -- Each line is a single-line active signature string from one attached LSP
  -- client. Each highlight range is a table which indicates (if not empty)
  -- what parameter to highlight for every LSP client's signature string.
  local lines, hl_ranges = {}, {}
  for _, t in pairs(signature_data) do
    -- `t` is allowed to be an empty table (in which case nothing is added) or
    -- a table with two entries. This ensures that `hl_range`'s integer index
    -- points to an actual line in future buffer.
    table.insert(lines, t.label)
    table.insert(hl_ranges, t.hl_range)
  end

  return lines, hl_ranges
end

function H.process_signature_response(response)
  if not response.signatures or vim.tbl_isempty(response.signatures) then
    return {}
  end

  -- Get active signature (based on textDocument/signatureHelp specification)
  local signature_id = response.activeSignature or 0
  ---- This is according to specification: "If ... value lies outside ...
  ---- defaults to zero"
  local n_signatures = vim.tbl_count(response.signatures or {})
  if signature_id < 0 or signature_id >= n_signatures then
    signature_id = 0
  end
  local signature = response.signatures[signature_id + 1]

  -- Get displayed signature label
  local signature_label = signature.label

  -- Get start and end of active parameter (for highlighting)
  local hl_range = {}
  local n_params = vim.tbl_count(signature.parameters or {})
  local has_params = signature.parameters and n_params > 0

  ---- Take values in this order because data inside signature takes priority
  local parameter_id = signature.activeParameter or response.activeParameter or 0
  local param_id_inrange = 0 <= parameter_id and parameter_id < n_params

  ---- Computing active parameter only when parameter id is inside bounds is not
  ---- strictly based on specification, as currently (v3.16) it says to treat
  ---- out-of-bounds value as first parameter. However, some clients seems to
  ---- use those values to indicate that nothing needs to be highlighted.
  ---- Sources:
  ---- https://github.com/microsoft/pyright/pull/1876
  ---- https://github.com/microsoft/language-server-protocol/issues/1271
  if has_params and param_id_inrange then
    local param_label = signature.parameters[parameter_id + 1].label

    -- Compute highlight range based on type of supplied parameter label: can
    -- be string label which should be a part of signature label or direct start
    -- (inclusive) and end (exclusive) range values
    local first, last = nil, nil
    if type(param_label) == 'string' then
      first, last = signature_label:find(vim.pesc(param_label))
      -- Make zero-indexed and end-exclusive
      if first then
        first, last = first - 1, last
      end
    elseif type(param_label) == 'table' then
      first, last = unpack(param_label)
    end
    if first then
      hl_range = { first = first, last = last }
    end
  end

  -- Return nested table because this will be a second argument of
  -- `vim.list_extend()` and the whole inner table is a target value here.
  return { { label = signature_label, hl_range = hl_range } }
end

function H.signature_window_opts()
  local lines = vim.api.nvim_buf_get_lines(H.signature.bufnr, 0, -1, {})
  local height, width = H.floating_dimensions(
    lines,
    MiniCompletion.config.window_dimensions.signature.height,
    MiniCompletion.config.window_dimensions.signature.width
  )

  -- Compute position
  local win_line = vim.fn.winline()
  local space_above, space_below = win_line - 1, vim.fn.winheight(0) - win_line

  local anchor, row, space
  if height <= space_above or space_below <= space_above then
    anchor, row, space = 'SW', 0, space_above
  else
    anchor, row, space = 'NW', 1, space_below
  end

  -- Possibly adjust floating window dimensions to fit screen
  if space < height then
    height, width = H.floating_dimensions(lines, space, MiniCompletion.config.window_dimensions.signature.width)
  end

  -- Get zero-indexed current cursor position
  local bufpos = vim.api.nvim_win_get_cursor(0)
  bufpos[1] = bufpos[1] - 1

  return {
    relative = 'win',
    bufpos = bufpos,
    anchor = anchor,
    row = row,
    col = 0,
    width = width,
    height = height,
    focusable = false,
    style = 'minimal',
  }
end

---- Helpers for floating windows
function H.ensure_buffer(cache, name)
  if cache.bufnr then
    return
  end

  cache.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(cache.bufnr, name)
  -- Make this buffer a scratch (can close without saving)
  vim.fn.setbufvar(cache.bufnr, '&buftype', 'nofile')
end

------ @return height, width
function H.floating_dimensions(lines, max_height, max_width)
  -- Simulate how lines will look in window with `wrap` and `linebreak`.
  -- This is not 100% accurate (mostly when multibyte characters are present
  -- manifesting into empty space at bottom), but does the job
  local lines_wrap = {}
  for _, l in pairs(lines) do
    vim.list_extend(lines_wrap, H.wrap_line(l, max_width))
  end
  -- Height is a number of wrapped lines truncated to maximum height
  local height = math.min(#lines_wrap, max_height)

  -- Width is a maximum width of the first `height` wrapped lines truncated to
  -- maximum width
  local width = 0
  local l_width
  for i, l in ipairs(lines_wrap) do
    -- Use `strdisplaywidth()` to account for 'non-UTF8' characters
    l_width = vim.fn.strdisplaywidth(l)
    if i <= height and width < l_width then
      width = l_width
    end
  end
  ---- It should already be less that that because of wrapping, so this is
  ---- "just in case"
  width = math.min(width, max_width)

  return height, width
end

function H.open_action_window(cache, opts)
  cache.winnr = vim.api.nvim_open_win(cache.bufnr, false, opts)
  vim.api.nvim_win_set_option(cache.winnr, 'wrap', true)
  vim.api.nvim_win_set_option(cache.winnr, 'linebreak', true)
  vim.api.nvim_win_set_option(cache.winnr, 'breakindent', false)
end

function H.close_action_window(cache, keep_timer)
  if not keep_timer then
    cache.timer:stop()
  end

  if cache.winnr then
    vim.api.nvim_win_close(cache.winnr, true)
  end
  cache.winnr = nil

  -- For some reason 'buftype' might be reset. Ensure that buffer is scratch.
  if cache.bufnr then
    vim.fn.setbufvar(cache.bufnr, '&buftype', 'nofile')
  end
end

---- Utilities
function H.is_char_keyword(char)
  -- Using Vim's `match()` and `keyword` enables respecting Cyrillic letters
  return vim.fn.match(char, '[[:keyword:]]') >= 0
end

function H.pumvisible()
  return vim.fn.pumvisible() > 0
end

function H.get_completion_start()
  -- Compute start position of latest keyword (as in `vim.lsp.omnifunc`)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])
  return vim.fn.match(line_to_cursor, '\\k*$')
end

function H.is_whitespace(s)
  if type(s) == 'string' then
    return s:find('^%s*$')
  end
  if type(s) == 'table' then
    for _, val in pairs(s) do
      if not H.is_whitespace(val) then
        return false
      end
    end
    return true
  end
  return false
end

------ Simulate splitting single line `l` like how it would look inside window
------ with `wrap` and `linebreak` set to `true`
function H.wrap_line(l, width)
  local breakat_pattern = '[' .. vim.o.breakat .. ']'
  local res = {}

  local break_id, break_match, width_id
  -- Use `strdisplaywidth()` to account for 'non-UTF8' characters
  while vim.fn.strdisplaywidth(l) > width do
    -- Simulate wrap by looking at breaking character from end of current break
    width_id = vim.str_byteindex(l, width)
    break_match = vim.fn.match(l:sub(1, width_id):reverse(), breakat_pattern)
    -- If no breaking character found, wrap at whole width
    break_id = width_id - (break_match < 0 and 0 or break_match)
    table.insert(res, l:sub(1, break_id))
    l = l:sub(break_id + 1)
  end
  table.insert(res, l)

  return res
end

function H.table_get(t, id)
  if type(id) ~= 'table' then
    return H.table_get(t, { id })
  end
  local success, res = true, t
  for _, i in pairs(id) do
    success, res = pcall(function()
      return res[i]
    end)
    if not (success and res) then
      return nil
    end
  end
  return res
end

function H.get_left_char()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  return string.sub(line, col, col)
end

function H.keymap(mode, keys, cmd, opts)
  if keys == '' then
    return
  end
  vim.api.nvim_set_keymap(mode, keys, cmd, opts)
end

return MiniCompletion
