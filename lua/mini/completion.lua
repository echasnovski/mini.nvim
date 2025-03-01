--- *mini.completion* Completion and signature help
--- *MiniCompletion*
---
--- MIT License Copyright (c) 2021 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Key design ideas:
--- - Have an async (with customizable "debounce" delay) "two-stage chain
---   completion": first try to get completion items from LSP client (if set
---   up) and if no result, fallback to custom action.
---
--- - Managing completion is done as much with Neovim's built-in tools as
---   possible.
---
--- Features:
--- - Two-stage chain completion:
---     - First stage is an LSP completion implemented via
---       |MiniCompletion.completefunc_lsp()|. It should be set up as either
---       |completefunc| or |omnifunc|. It tries to get completion items from
---       LSP client (via 'textDocument/completion' request). Custom
---       preprocessing of response items is possible (with
---       `MiniCompletion.config.lsp_completion.process_items`), for example
---       with fuzzy matching. By default items which are not snippets and
---       directly start with completed word are kept and sorted according to
---       LSP specification. Supports `additionalTextEdits`, like auto-import
---       and others (see 'Notes').
---     - If first stage is not set up or resulted into no candidates, fallback
---       action is executed. The most tested actions are Neovim's built-in
---       insert completion (see |ins-completion|).
---
--- - Automatic display in floating window of completion item info (via
---   'completionItem/resolve' request) and signature help (with highlighting
---   of active parameter if LSP server provides such information). After
---   opening, window for signature help is fixed and is closed when there is
---   nothing to show, text is different or
---   when leaving Insert mode.
---
--- - Automatic actions are done after some configurable amount of delay. This
---   reduces computational load and allows fast typing (completion and
---   signature help) and item selection (item info)
---
--- - User can force two-stage completion via
---   |MiniCompletion.complete_twostage()| (by default is mapped to
---   `<C-Space>`) or fallback completion via
---   |MiniCompletion.complete_fallback()| (mapped to `<M-Space>`).
---
--- - LSP kind highlighting ("Function", "Keyword", etc.). Requires Neovim>=0.11.
---   By default uses "lsp" category of |MiniIcons| (if enabled). Can be customized
---   via `config.lsp_completion.process_items` by adding field <kind_hlgroup>
---   (same meaning as in |complete-items|) to items.
---
--- What it doesn't do:
--- - Snippet expansion.
--- - Many configurable sources.
--- - Automatic mapping of `<CR>`, `<Tab>`, etc., as those tend to have highly
---   variable user expectations. See 'Helpful mappings' for suggestions.
---
--- # Dependencies ~
---
--- Suggested dependencies (provide extra functionality, will work without them):
---
--- - Enabled |MiniIcons| module to highlight LSP kind (requires Neovim>=0.11).
---   Otherwise |MiniCompletion.default_process_items()| does not add highlighting.
---   Also take a look at |MiniIcons.tweak_lsp_kind()|.
---
--- # Setup ~
---
--- This module needs a setup with `require('mini.completion').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniCompletion` which you can use for scripting or manually (with
--- `:lua MiniCompletion.*`).
---
--- See |MiniCompletion.config| for `config` structure and default values.
---
--- You can override runtime config settings locally to buffer inside
--- `vim.b.minicompletion_config` which should have same structure as
--- `MiniCompletion.config`. See |mini.nvim-buffer-local-config| for more details.
---
--- # Notes ~
---
--- - More appropriate, albeit slightly advanced, LSP completion setup is to set
---   it not on every `BufEnter` event (default), but on every attach of LSP
---   client. To do that:
---     - Use in initial config:
---     `lsp_completion = {source_func = 'omnifunc', auto_setup = false}`.
---     - In `on_attach()` of every LSP client set 'omnifunc' option to exactly
---       `v:lua.MiniCompletion.completefunc_lsp`.
---
--- - Uses `vim.lsp.protocol.CompletionItemKind` map in LSP step to show a readable
---   version of item's kind. Modify it directly to change what is displayed.
---   If you have |mini.icons| enabled, take a look at |MiniIcons.tweak_lsp_kind()|.
---
--- - If you have trouble using custom (overridden) |vim.ui.input| (like from
---   'stevearc/dressing.nvim'), make automated disable of 'mini.completion'
---   for input buffer. For example, currently for 'dressing.nvim' it can be
---   with `au FileType DressingInput lua vim.b.minicompletion_disable = true`.
---
--- - Support of `additionalTextEdits` tries to handle both types of servers:
---     - When `additionalTextEdits` are supplied in response to
---       'textDocument/completion' request (like currently in 'pyright').
---     - When `additionalTextEdits` are supplied in response to
---       'completionItem/resolve' request (like currently in
---       'typescript-language-server'). In this case to apply edits user needs
---       to trigger such request, i.e. select completion item and wait for
---       `MiniCompletion.config.delay.info` time plus server response time.
---
--- # Comparisons ~
---
--- - 'nvim-cmp':
---     - More complex design which allows multiple sources each in form of
---       separate plugin. `MiniCompletion` has two built in: LSP and fallback.
---     - Supports snippet expansion.
---     - Doesn't have customizable delays for basic actions.
---     - Doesn't allow fallback action.
---     - Doesn't provide signature help.
---
--- # Helpful mappings ~
---
--- To use `<Tab>` and `<S-Tab>` for navigation through completion list, make
--- these mappings: >lua
---
---   local imap_expr = function(lhs, rhs)
---     vim.keymap.set('i', lhs, rhs, { expr = true })
---   end
---   imap_expr('<Tab>',   [[pumvisible() ? "\<C-n>" : "\<Tab>"]])
---   imap_expr('<S-Tab>', [[pumvisible() ? "\<C-p>" : "\<S-Tab>"]])
--- <
--- To get more consistent behavior of `<CR>`, you can use this template in
--- your 'init.lua' to make customized mapping: >lua
---
---   local keycode = vim.keycode or function(x)
---     return vim.api.nvim_replace_termcodes(x, true, true, true)
---   end
---   local keys = {
---     ['cr']        = keycode('<CR>'),
---     ['ctrl-y']    = keycode('<C-y>'),
---     ['ctrl-y_cr'] = keycode('<C-y><CR>'),
---   }
---
---   _G.cr_action = function()
---     if vim.fn.pumvisible() ~= 0 then
---       -- If popup is visible, confirm selected item or add new line otherwise
---       local item_selected = vim.fn.complete_info()['selected'] ~= -1
---       return item_selected and keys['ctrl-y'] or keys['ctrl-y_cr']
---     else
---       -- If popup is not visible, use plain `<CR>`. You might want to customize
---       -- according to other plugins. For example, to use 'mini.pairs', replace
---       -- next line with `return require('mini.pairs').cr()`
---       return keys['cr']
---     end
---   end
---
---   vim.keymap.set('i', '<CR>', 'v:lua._G.cr_action()', { expr = true })
--- <
--- # Highlight groups ~
---
--- * `MiniCompletionActiveParameter` - signature active parameter.
---   By default displayed as plain underline.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling ~
---
--- To disable, set `vim.g.minicompletion_disable` (globally) or
--- `vim.b.minicompletion_disable` (for a buffer) to `true`. Considering high
--- number of different scenarios and customization intentions, writing exact
--- rules for disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes.

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

-- Module definition ==========================================================
local MiniCompletion = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniCompletion.config|.
---
---@usage >lua
---   require('mini.completion').setup() -- use default config
---   -- OR
---   require('mini.completion').setup({}) -- replace {} with your config table
--- <
MiniCompletion.setup = function(config)
  -- Export module
  _G.MiniCompletion = MiniCompletion

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Define behavior
  H.create_autocommands(config)

  -- Create default highlighting
  H.create_default_hl()
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniCompletion.config = {
  -- Delay (debounce type, in ms) between certain Neovim event and action.
  -- This can be used to (virtually) disable certain automatic actions by
  -- setting very high delay time (like 10^7).
  delay = { completion = 100, info = 100, signature = 50 },

  -- Configuration for action windows:
  -- - `height` and `width` are maximum dimensions.
  -- - `border` defines border (as in `nvim_open_win()`).
  window = {
    info = { height = 25, width = 80, border = 'single' },
    signature = { height = 25, width = 80, border = 'single' },
  },

  -- Way of how module does LSP completion
  lsp_completion = {
    -- `source_func` should be one of 'completefunc' or 'omnifunc'.
    source_func = 'completefunc',

    -- `auto_setup` should be boolean indicating if LSP completion is set up
    -- on every `BufEnter` event.
    auto_setup = true,

    -- A function which takes LSP 'textDocument/completion' response items
    -- and word to complete. Output should be a table of the same nature as
    -- input items. Common use case is custom filter/sort.
    --minidoc_replace_start process_items = --<function: MiniCompletion.default_process_items>,
    process_items = function(items, base)
      local res = vim.tbl_filter(function(item)
        -- Keep items which match the base and are not snippets
        local text = item.filterText or H.get_completion_word(item)
        return vim.startswith(text, base) and item.kind ~= 15
      end, items)

      res = vim.deepcopy(res)
      table.sort(res, function(a, b) return (a.sortText or a.label) < (b.sortText or b.label) end)

      -- Possibly add "kind" highlighting
      if _G.MiniIcons ~= nil then
        local add_kind_hlgroup = H.make_add_kind_hlgroup()
        for _, item in ipairs(res) do
          add_kind_hlgroup(item)
        end
      end

      return res
    end,
    --minidoc_replace_end
  },

  -- Fallback action. It will always be run in Insert mode. To use Neovim's
  -- built-in completion (see `:h ins-completion`), supply its mapping as
  -- string. Example: to use 'whole lines' completion, supply '<C-x><C-l>'.
  --minidoc_replace_start fallback_action = --<function: like `<C-n>` completion>,
  fallback_action = function() vim.api.nvim_feedkeys(H.keys.ctrl_n, 'n', false) end,
  --minidoc_replace_end

  -- Module mappings. Use `''` (empty string) to disable one. Some of them
  -- might conflict with system mappings.
  mappings = {
    force_twostep = '<C-Space>', -- Force two-step completion
    force_fallback = '<A-Space>', -- Force fallback completion
  },

  -- Whether to set Vim's settings for better experience (modifies
  -- `shortmess` and `completeopt`)
  set_vim_settings = true,
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Run two-stage completion
---
---@param fallback boolean|nil Whether to use fallback completion. Default: `true`.
---@param force boolean|nil Whether to force update of completion popup.
---   Default: `true`.
MiniCompletion.complete_twostage = function(fallback, force)
  if H.is_disabled() then return end
  if fallback == nil then fallback = true end
  if force == nil then force = true end

  H.stop_completion()
  H.completion.fallback, H.completion.force = fallback, force
  H.trigger_twostep()
end

--- Run fallback completion
MiniCompletion.complete_fallback = function()
  if H.is_disabled() then return end

  H.stop_completion()
  H.completion.fallback, H.completion.force = true, true
  H.trigger_fallback()
end

--- Stop actions
---
--- This stops currently active (because of module delay or LSP answer delay)
--- actions.
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |MiniCompletion.setup|.
---
---@param actions table|nil Array containing any of 'completion', 'info', or
---   'signature' string. Default: array containing all of them.
MiniCompletion.stop = function(actions)
  actions = actions or { 'completion', 'info', 'signature' }
  for _, n in pairs(actions) do
    H.stop_actions[n]()
  end
end

--- Module's |complete-function|
---
--- This is the main function which enables two-stage completion. It should be
--- set as one of |completefunc| or |omnifunc|.
---
--- No need to use it directly, everything is setup in |MiniCompletion.setup|.
MiniCompletion.completefunc_lsp = function(findstart, base)
  -- Early return
  if not H.has_lsp_clients('completionProvider') or H.completion.lsp.status == 'sent' then
    return findstart == 1 and -3 or {}
  end

  -- NOTE: having code for request inside this function enables its use
  -- directly with `<C-x><...>` and as a reaction to `<BS>`.
  if H.completion.lsp.status ~= 'received' then
    -- NOTE: it is CRUCIAL to make LSP request on the first call to
    -- 'complete-function' (as in Vim's help). This is due to the fact that
    -- cursor line and position are different on the first and second calls to
    -- 'complete-function'. For example, when calling this function at the end
    -- of the line '  he', cursor position on the first call will be
    -- (<linenum>, 4) and line will be '  he' but on the second call -
    -- (<linenum>, 2) and '  ' (because 2 is a column of completion start).
    --
    -- This request is not executed on second call because it returns `-3` on
    -- first call (which means cancel and leave completion mode).
    H.make_completion_request()

    -- End completion and wait for LSP callback to re-trigger this
    return findstart == 1 and -3 or {}
  else
    if findstart == 1 then return H.get_completion_start(H.completion.lsp.result) end

    local process_items, is_incomplete = H.get_config().lsp_completion.process_items, false
    local words = H.process_lsp_response(H.completion.lsp.result, function(response, client_id)
      is_incomplete = is_incomplete or response.isIncomplete
      -- Response can be `CompletionList` with 'items' field or `CompletionItem[]`
      local items = H.table_get(response, { 'items' }) or response
      if type(items) ~= 'table' then return {} end
      items = process_items(items, base)
      return H.lsp_completion_response_items_to_complete_items(items, client_id)
    end)

    H.completion.lsp.status = is_incomplete and 'done-isincomplete' or 'done'

    -- Maybe trigger fallback action
    if vim.tbl_isempty(words) and H.completion.fallback then return H.trigger_fallback() end

    -- Track from which source is current popup
    H.completion.source = 'lsp'
    return words
  end
end

--- Default `MiniCompletion.config.lsp_completion.process_items`
---
--- Steps:
--- - Filter out items not matching `base` and snippet items.
--- - Sort by LSP specification.
--- - If |MiniIcons| is enabled, add <kind_hlgroup> based on the "lsp" category.
MiniCompletion.default_process_items = function(items, base)
  return H.default_config.lsp_completion.process_items(items, base)
end

-- Helper data ================================================================
-- Module default config
H.default_config = vim.deepcopy(MiniCompletion.config)

-- Track Insert mode changes
H.text_changed_id = 0

-- Namespace for highlighting
H.ns_id = vim.api.nvim_create_namespace('MiniCompletion')

-- Commonly used key sequences
H.keys = {
  completefunc = vim.api.nvim_replace_termcodes('<C-x><C-u>', true, false, true),
  omnifunc = vim.api.nvim_replace_termcodes('<C-x><C-o>', true, false, true),
  ctrl_n = vim.api.nvim_replace_termcodes('<C-g><C-g><C-n>', true, false, true),
}

-- Caches for different actions -----------------------------------------------
-- Field `lsp` is a table describing state of all used LSP requests. It has the
-- following structure:
-- - id: identifier (consecutive numbers).
-- - status: one of 'sent', 'received', 'done', 'done-isincomplete', 'canceled'
-- - result: result of request.
-- - cancel_fun: function which cancels current request.

-- Cache for completion
H.completion = {
  fallback = true,
  force = false,
  source = nil,
  text_changed_id = 0,
  timer = vim.loop.new_timer(),
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

-- Cache for completion item info
H.info = {
  bufnr = nil,
  event = nil,
  id = 0,
  timer = vim.loop.new_timer(),
  win_id = nil,
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

-- Cache for signature help
H.signature = {
  bufnr = nil,
  text = nil,
  timer = vim.loop.new_timer(),
  win_id = nil,
  lsp = { id = 0, status = nil, result = nil, cancel_fun = nil },
}

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  H.check_type('config', config, 'table', true)
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  H.check_type('delay', config.delay, 'table')
  H.check_type('window', config.window, 'table')
  H.check_type('lsp_completion', config.lsp_completion, 'table')
  if not (type(config.fallback_action) == 'function' or type(config.fallback_action) == 'string') then
    H.error('`fallback_action` should be function or string, not ' .. type(config.fallback_action))
  end
  H.check_type('mappings', config.mappings, 'table')
  H.check_type('set_vim_settings', config.set_vim_settings, 'boolean')

  H.check_type('delay.completion', config.delay.completion, 'number')
  H.check_type('delay.info', config.delay.info, 'number')
  H.check_type('delay.signature', config.delay.signature, 'number')

  H.check_type('window.info', config.window.info, 'table')
  H.check_type('window.signature', config.window.signature, 'table')

  if not (config.lsp_completion.source_func == 'completefunc' or config.lsp_completion.source_func == 'omnifunc') then
    H.error('`lsp_completion.source_func` should be one of "completefunc" or "omnifunc"')
  end
  H.check_type('lsp_completion.auto_setup', config.lsp_completion.auto_setup, 'boolean')
  H.check_type('lsp_completion.process_items', config.lsp_completion.process_items, 'function')

  H.check_type('mappings.force_twostep', config.mappings.force_twostep, 'string')
  H.check_type('mappings.force_fallback', config.mappings.force_fallback, 'string')

  local is_string_or_array = function(x) return type(x) == 'string' or H.islist(x) end
  H.check_type('window.info.height', config.window.info.height, 'number')
  H.check_type('window.info.width', config.window.info.width, 'number')
  if not is_string_or_array(config.window.info.border) then
    H.error('`config.window.info.border` should be either string or array, not ' .. type(config.window.info.border))
  end
  H.check_type('window.signature.height', config.window.signature.height, 'number')
  H.check_type('window.signature.width', config.window.signature.width, 'number')
  if not is_string_or_array(config.window.signature.border) then
    H.error(
      '`config.window.signature.border` should be either string or array, not ' .. type(config.window.signature.border)
    )
  end

  return config
end

H.apply_config = function(config)
  MiniCompletion.config = config

  --stylua: ignore start
  H.map('i', config.mappings.force_twostep, MiniCompletion.complete_twostage, { desc = 'Complete with two-stage' })
  H.map('i', config.mappings.force_fallback, MiniCompletion.complete_fallback, { desc = 'Complete with fallback' })
  --stylua: ignore end

  if config.set_vim_settings then
    -- Don't give ins-completion-menu messages
    vim.opt.shortmess:append('c')
    if vim.fn.has('nvim-0.9') == 1 then vim.opt.shortmess:append('C') end

    -- More common completion behavior
    vim.o.completeopt = 'menuone,noselect'
  end
end

H.create_autocommands = function(config)
  local gr = vim.api.nvim_create_augroup('MiniCompletion', {})

  local au = function(event, pattern, callback, desc)
    vim.api.nvim_create_autocmd(event, { group = gr, pattern = pattern, callback = callback, desc = desc })
  end

  au('InsertCharPre', '*', H.auto_completion, 'Auto show completion')
  au('CompleteChanged', '*', H.auto_info, 'Auto show info')
  au('CursorMovedI', '*', H.auto_signature, 'Auto show signature')
  au('ModeChanged', 'i*:[^i]*', function() MiniCompletion.stop() end, 'Stop completion')
  au('CompleteDonePre', '*', H.on_completedonepre, 'On CompleteDonePre')
  au('TextChangedI', '*', H.on_text_changed_i, 'On TextChangedI')
  au('TextChangedP', '*', H.on_text_changed_p, 'On TextChangedP')

  if config.lsp_completion.auto_setup then
    local source_func = config.lsp_completion.source_func
    local callback = function() vim.bo[source_func] = 'v:lua.MiniCompletion.completefunc_lsp' end
    au('BufEnter', '*', callback, 'Set completion function')
  end

  au('ColorScheme', '*', H.create_default_hl, 'Ensure colors')
  au('FileType', 'TelescopePrompt', function() vim.b.minicompletion_disable = true end, 'Disable locally')
end

H.create_default_hl = function()
  vim.api.nvim_set_hl(0, 'MiniCompletionActiveParameter', { default = true, underline = true })
end

H.is_disabled = function() return vim.g.minicompletion_disable == true or vim.b.minicompletion_disable == true end

H.get_config = function(config)
  return vim.tbl_deep_extend('force', MiniCompletion.config, vim.b.minicompletion_config or {}, config or {})
end

-- Autocommands ---------------------------------------------------------------
H.auto_completion = function()
  if H.is_disabled() then return end

  H.completion.timer:stop()

  local is_incomplete = H.completion.lsp.status == 'done-isincomplete'
  local force = H.is_lsp_trigger(vim.v.char, 'completion') or is_incomplete
  if force then
    -- If character is LSP trigger, force fresh LSP completion later
    -- Check LSP trigger before checking for pumvisible because it should be
    -- forced even if there are visible candidates
    H.stop_completion(false)
  elseif H.pumvisible() then
    -- Do nothing if popup is visible. `H.pumvisible()` might be `true` even if
    -- there is no popup. It is common when manually typing candidate followed
    -- by an LSP trigger (like ".").
    -- Keep completion source as it is needed all time when popup is visible.
    return H.stop_completion(true)
  elseif not H.is_char_keyword(vim.v.char) then
    -- Stop everything if inserted character is not appropriate. Check this
    -- after popup check to allow completion candidates to have bad characters.
    return H.stop_completion(false)
  end

  -- Start non-forced completion with fallback or forced LSP source for trigger
  H.completion.fallback, H.completion.force = not force, force

  -- Cache id of Insert mode "text changed" event for a later tracking (reduces
  -- false positive delayed triggers). The intention is to trigger completion
  -- after the delay only if text wasn't changed during waiting. Using only
  -- `InsertCharPre` is not enough though, as not every Insert mode change
  -- triggers `InsertCharPre` event (notable example - hitting `<CR>`).
  -- Also, using `+ 1` here because it is a `Pre` event and needs to cache
  -- after inserting character.
  H.completion.text_changed_id = H.text_changed_id + 1

  -- If completion was requested after 'lsp' source exhausted itself (there
  -- were matches on typing start, but they disappeared during filtering), call
  -- fallback immediately.
  if H.completion.source == 'lsp' then return H.trigger_fallback() end

  -- Debounce delay improves experience (can type fast without many popups)
  -- Request immediately if improving incomplete suggestions (less flickering)
  if is_incomplete then return H.trigger_twostep() end
  H.completion.timer:start(H.get_config().delay.completion, 0, vim.schedule_wrap(H.trigger_twostep))
end

H.auto_info = function()
  if H.is_disabled() then return end

  H.info.timer:stop()

  -- Defer execution because of textlock during `CompleteChanged` event
  -- Don't stop timer when closing info window because it is needed
  vim.schedule(function() H.close_action_window(H.info, true) end)

  -- Stop current LSP request that tries to get not current data
  H.cancel_lsp({ H.info })

  -- Update metadata before leaving to register a `CompleteChanged` event
  H.info.event = vim.v.event
  H.info.id = H.info.id + 1

  -- Don't even try to show info if nothing is selected in popup
  if vim.tbl_isempty(H.info.event.completed_item) then return end

  H.info.timer:start(H.get_config().delay.info, 0, vim.schedule_wrap(H.show_info_window))
end

H.auto_signature = function()
  if H.is_disabled() then return end

  H.signature.timer:stop()
  if not H.has_lsp_clients('signatureHelpProvider') then return end

  local left_char = H.get_left_char()
  local char_is_trigger = left_char == ')' or H.is_lsp_trigger(left_char, 'signature')
  if not char_is_trigger then return end

  H.signature.timer:start(H.get_config().delay.signature, 0, vim.schedule_wrap(H.show_signature_window))
end

H.on_completedonepre = function()
  -- Do nothing if it is triggered inside `trigger_lsp()` as a result of
  -- emulating 'completefunc'/'omnifunc' keys. This can happen if popup is
  -- visible and pressing keys first hides it with 'CompleteDonePre' event.
  if H.completion.lsp.status == 'received' then return end

  -- Try to apply additional text edits
  H.apply_additional_text_edits()

  -- Stop processes
  MiniCompletion.stop({ 'completion', 'info' })
end

H.on_text_changed_i = function()
  -- Track Insert mode changes
  H.text_changed_id = H.text_changed_id + 1

  -- Stop 'info' processes in case no completion event is triggered but popup
  -- is not visible. See https://github.com/neovim/neovim/issues/15077
  H.stop_info()
end

H.on_text_changed_p = function()
  -- Track Insert mode changes
  H.text_changed_id = H.text_changed_id + 1
end

-- Completion triggers --------------------------------------------------------
H.trigger_twostep = function()
  -- Trigger only in Insert mode and if text didn't change after trigger
  -- request, unless completion is forced
  -- NOTE: check for `text_changed_id` equality is still not 100% solution as
  -- there are cases when, for example, `<CR>` is hit just before this check.
  -- Because of asynchronous id update and this function call (called after
  -- delay), these still match.
  local allow_trigger = (vim.fn.mode() == 'i')
    and (H.completion.force or (H.completion.text_changed_id == H.text_changed_id))
  if not allow_trigger then return end

  if H.has_lsp_clients('completionProvider') and H.has_lsp_completion() then
    H.trigger_lsp()
  elseif H.completion.fallback then
    H.trigger_fallback()
  end
end

H.trigger_lsp = function()
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

  -- Do not trigger if not needed and/or allowed
  if vim.fn.mode() ~= 'i' or (H.pumvisible() and not H.completion.force) then return end

  -- Overall idea: first make LSP request and re-trigger this same function
  -- inside its callback to take the "received" route. This reduces flickering
  -- in case popup is visible (like for `isIncomplete` and trigger characters)
  -- as pressing 'completefunc'/'omnifunc' keys first hides completion menu.
  -- There are still minor visual defects: typing new character reduces number
  -- of matched items which can visually shrink popup while later increase it
  -- again after LSP response is received. This is usually fine (especially
  -- with not huge 'pumheight').
  if H.completion.lsp.status ~= 'received' then return H.make_completion_request() end
  local keys = H.keys[H.get_config().lsp_completion.source_func]
  vim.api.nvim_feedkeys(keys, 'n', false)
end

H.trigger_fallback = function()
  -- Fallback only in Insert mode when no popup is visible
  local has_popup = H.pumvisible() and not H.completion.force
  if has_popup or vim.fn.mode() ~= 'i' then return end

  -- Track from which source is current popup
  H.completion.source = 'fallback'

  -- Execute fallback action
  local fallback_action = H.get_config().fallback_action
  if vim.is_callable(fallback_action) then return fallback_action() end
  if type(fallback_action) ~= 'string' then return end

  -- Having `<C-g><C-g>` also (for some mysterious reason) helps to avoid
  -- some weird behavior. For example, if `keys = '<C-x><C-l>'` then Neovim
  -- starts new line when there is no suggestions.
  local keys = string.format('<C-g><C-g>%s', fallback_action)
  local trigger_keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(trigger_keys, 'n', false)
end

-- Stop actions ---------------------------------------------------------------
H.stop_completion = function(keep_source)
  H.completion.timer:stop()
  H.cancel_lsp({ H.completion })
  H.completion.fallback, H.completion.force = true, false
  if H.completion.lsp.status == 'done-isincomplete' then H.completion.lsp.status = 'done' end
  if not keep_source then H.completion.source = nil end
end

H.stop_info = function()
  -- Id update is needed to notify that all previous work is not current
  H.info.id = H.info.id + 1
  H.info.timer:stop()
  H.cancel_lsp({ H.info })
  H.close_action_window(H.info)
end

H.stop_signature = function()
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

-- LSP ------------------------------------------------------------------------
---@param capability string|table|nil Server capability (possibly nested
---   supplied via table) to check.
---
---@return boolean Whether at least one LSP client supports `capability`.
---@private
H.has_lsp_clients = function(capability)
  local clients = H.get_buf_lsp_clients()
  if vim.tbl_isempty(clients) then return false end
  if not capability then return true end

  for _, c in pairs(clients) do
    local has_capability = H.table_get(c.server_capabilities, capability)
    if has_capability then return true end
  end
  return false
end

H.has_lsp_completion = function()
  local source_func = H.get_config().lsp_completion.source_func
  local func = vim.bo[source_func]
  return func == 'v:lua.MiniCompletion.completefunc_lsp'
end

H.is_lsp_trigger = function(char, type)
  local triggers
  local providers = { completion = 'completionProvider', signature = 'signatureHelpProvider' }

  for _, client in pairs(H.get_buf_lsp_clients()) do
    triggers = H.table_get(client, { 'server_capabilities', providers[type], 'triggerCharacters' })
    if vim.tbl_contains(triggers or {}, char) then return true end
  end
  return false
end

H.cancel_lsp = function(caches)
  caches = caches or { H.completion, H.info, H.signature }
  for _, c in pairs(caches) do
    if vim.tbl_contains({ 'sent', 'received' }, c.lsp.status) then
      if c.lsp.cancel_fun then c.lsp.cancel_fun() end
      c.lsp.status = 'canceled'
    end

    c.lsp.result, c.lsp.cancel_fun = nil, nil
  end
end

H.process_lsp_response = function(request_result, processor)
  if not request_result then return {} end

  local res = {}
  for client_id, item in pairs(request_result) do
    if not item.err and item.result then vim.list_extend(res, processor(item.result, client_id) or {}) end
  end

  return res
end

H.is_lsp_current = function(cache, id) return cache.lsp.id == id and cache.lsp.status == 'sent' end

-- Completion -----------------------------------------------------------------
H.make_completion_request = function()
  local current_id = H.completion.lsp.id + 1
  H.completion.lsp.id = current_id
  H.completion.lsp.status = 'sent'

  local buf_id, params = vim.api.nvim_get_current_buf(), H.make_position_params()
  -- NOTE: use `buf_request_all()` (instead of `buf_request()`) to easily
  -- handle possible fallback and to have all completion suggestions be later
  -- filtered with one `base`. Anyway, the most common situation is with one
  -- attached LSP client.
  local cancel_fun = vim.lsp.buf_request_all(buf_id, 'textDocument/completion', params, function(result)
    if not H.is_lsp_current(H.completion, current_id) then return end

    H.completion.lsp.status = 'received'
    H.completion.lsp.result = result

    -- Trigger LSP completion to use completefunc/omnifunc route
    H.trigger_lsp()
  end)

  -- Cache cancel function to disable requests when they are not needed
  H.completion.lsp.cancel_fun = cancel_fun
end

-- This is a truncated version of
-- `vim.lsp.util.text_document_completion_list_to_complete_items` which does
-- not filter and sort items.
-- For extra information see 'Response' section:
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_completion
H.lsp_completion_response_items_to_complete_items = function(items, client_id)
  if vim.tbl_count(items) == 0 then return {} end

  local res, item_kinds = {}, vim.lsp.protocol.CompletionItemKind
  for _, item in pairs(items) do
    local label_details, menu = item.labelDetails, nil
    if label_details ~= nil then menu = (label_details.detail or '') .. (label_details.description or '') end
    table.insert(res, {
      word = H.get_completion_word(item),
      abbr = item.label,
      kind = item_kinds[item.kind] or 'Unknown',
      kind_hlgroup = item.kind_hlgroup,
      menu = menu,
      -- Do not set `info` field in favor of trying to first resolve it
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = { nvim = { lsp = { completion_item = item, client_id = client_id } } },
    })
  end
  return res
end

H.make_add_kind_hlgroup = function()
  -- Account for possible effect of `MiniIcons.tweak_lsp_kind()` which modifies
  -- only array part of `CompletionItemKind` but not "map" part
  if H.kind_map == nil then
    -- Cache kind map so as to not recompute it each time (as it will be called
    -- in performance sensitive context). Assumes `tweak_lsp_kind()` is called
    -- right after `require('mini.icons').setup()`.
    H.kind_map = {}
    for k, v in pairs(vim.lsp.protocol.CompletionItemKind) do
      if type(k) == 'string' and type(v) == 'number' then H.kind_map[v] = k end
    end
  end

  return function(item)
    local _, hl, is_default = _G.MiniIcons.get('lsp', H.kind_map[item.kind] or 'Unknown')
    item.kind_hlgroup = not is_default and hl or nil
  end
end

H.get_completion_word = function(item)
  -- Completion word (textEdit.newText > insertText > label). This doesn't
  -- support snippet expansion.
  return H.table_get(item, { 'textEdit', 'newText' }) or item.insertText or item.label or ''
end

H.apply_additional_text_edits = function()
  -- Code originally.inspired by https://github.com/neovim/neovim/issues/12310

  -- Try to get `additionalTextEdits`. First from 'completionItem/resolve';
  -- then - from selected item. The reason for this is inconsistency in how
  -- servers provide `additionTextEdits`: on 'textDocument/completion' or
  -- 'completionItem/resolve'.
  local resolve_data = H.process_lsp_response(H.info.lsp.result, function(response, client_id)
    -- Return nested table because this will be a second argument of
    -- `vim.list_extend()` and the whole inner table is a target value here.
    return { { edits = response.additionalTextEdits, client_id = client_id } }
  end)
  local edits, client_id
  if #resolve_data >= 1 then
    edits, client_id = resolve_data[1].edits, resolve_data[1].client_id
  else
    local lsp_data = H.table_get(vim.v.completed_item, { 'user_data', 'nvim', 'lsp' }) or {}
    edits = H.table_get(lsp_data, { 'completion_item', 'additionalTextEdits' })
    client_id = lsp_data.client_id
  end

  if edits == nil then return end
  client_id = client_id or 0

  -- Use extmark to track relevant cursor position after text edits
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  local extmark_id = vim.api.nvim_buf_set_extmark(0, H.ns_id, cur_pos[1] - 1, cur_pos[2], {})

  local offset_encoding = vim.lsp.get_client_by_id(client_id).offset_encoding
  vim.lsp.util.apply_text_edits(edits, vim.api.nvim_get_current_buf(), offset_encoding)

  local extmark_data = vim.api.nvim_buf_get_extmark_by_id(0, H.ns_id, extmark_id, {})
  pcall(vim.api.nvim_buf_del_extmark, 0, H.ns_id, extmark_id)
  pcall(vim.api.nvim_win_set_cursor, 0, { extmark_data[1] + 1, extmark_data[2] })
end

-- Completion item info -------------------------------------------------------
H.show_info_window = function()
  local event = H.info.event
  if not event then return end

  -- Get info lines to show
  local lines = H.info_window_lines(H.info.id)
  if lines == nil or H.is_whitespace(lines) then return end

  -- Ensure permanent buffer with "markdown" highlighting to display info
  H.ensure_buffer(H.info, 'MiniCompletion:completion-item-info')
  H.ensure_highlight(H.info, 'markdown')
  vim.api.nvim_buf_set_lines(H.info.bufnr, 0, -1, false, lines)

  -- Compute floating window options
  local opts = H.info_window_options()
  -- Adjust to hide top/bottom code block delimiters (as they are concealed)
  local top_is_codeblock_start = lines[1]:find('^```%S*$')
  if top_is_codeblock_start then opts.height = opts.height - 1 end
  if lines[#lines]:find('^```$') then opts.height = opts.height - 1 end

  -- Adjust section separator with better visual alternative
  lines = vim.tbl_map(function(l) return l:gsub('^%-%-%-%-*$', string.rep('─', opts.width)) end, lines)
  vim.api.nvim_buf_set_lines(H.info.bufnr, 0, -1, false, lines)

  -- Defer execution because of textlock during `CompleteChanged` event
  vim.schedule(function()
    -- Ensure that window doesn't open when it shouldn't be
    if not (H.pumvisible() and vim.fn.mode() == 'i') then return end
    H.open_action_window(H.info, opts)
    local win_id = H.info.win_id
    if not H.is_valid_win(win_id) then return end

    -- Hide helper syntax elements (like ``` code blocks, etc.)
    vim.wo[H.info.win_id].conceallevel = 3

    -- Scroll past first line if it is a start of a code block
    if top_is_codeblock_start then vim.api.nvim_win_call(win_id, function() vim.fn.winrestview({ topline = 2 }) end) end
  end)
end

H.info_window_lines = function(info_id)
  local completed_item = H.table_get(H.info, { 'event', 'completed_item' }) or {}

  -- If popup is not from LSP, try using 'info' field of completion item
  if H.completion.source ~= 'lsp' then
    local text = completed_item.info or ''
    return (not H.is_whitespace(text)) and vim.split(text, '\n') or nil
  end

  -- Try to get documentation from LSP's latest completion result
  if H.info.lsp.status == 'received' then
    local lines = H.process_lsp_response(H.info.lsp.result, H.normalize_item_doc)
    H.info.lsp.status = 'done'
    return lines
  end

  -- If server doesn't support resolving completion item, reuse first response
  local lsp_data = H.table_get(completed_item, { 'user_data', 'nvim', 'lsp' })
  -- NOTE: If there is no LSP's completion item, then there is no point to
  -- proceed as it should serve as parameters to LSP request
  if lsp_data.completion_item == nil then return end

  local client = vim.lsp.get_client_by_id(lsp_data.client_id) or {}
  local can_resolve = H.table_get(client.server_capabilities, { 'completionProvider', 'resolveProvider' })
  if not can_resolve then return H.normalize_item_doc(lsp_data.completion_item) end

  -- Finally, request to resolve current completion to add more documentation
  local bufnr = vim.api.nvim_get_current_buf()
  local current_id = H.info.lsp.id + 1
  H.info.lsp.id = current_id
  H.info.lsp.status = 'sent'

  local cancel_fun = vim.lsp.buf_request_all(bufnr, 'completionItem/resolve', lsp_data.completion_item, function(result)
    -- Don't do anything if there is other LSP request in action
    if not H.is_lsp_current(H.info, current_id) then return end

    H.info.lsp.status = 'received'

    -- Don't do anything if completion item was changed
    if H.info.id ~= info_id then return end

    H.info.lsp.result = result
    H.show_info_window()
  end)

  H.info.lsp.cancel_fun = cancel_fun
end

H.info_window_options = function()
  local win_config = H.get_config().window.info

  -- Compute dimensions based on lines to be displayed
  local lines = vim.api.nvim_buf_get_lines(H.info.bufnr, 0, -1, false)
  local info_height, info_width = H.floating_dimensions(lines, win_config.height, win_config.width)

  -- Compute position
  local event = H.info.event
  local left_to_pum = event.col - 1
  local right_to_pum = event.col + event.width + (event.scrollbar and 1 or 0)

  local border_offset = win_config.border == 'none' and 0 or 2
  local space_left = left_to_pum - border_offset
  local space_right = vim.o.columns - right_to_pum - border_offset

  -- Decide side at which info window will be displayed
  local anchor, col, space
  if info_width <= space_right or space_left <= space_right then
    anchor, col, space = 'NW', right_to_pum, space_right
  else
    anchor, col, space = 'NE', left_to_pum, space_left
  end

  -- Possibly adjust floating window dimensions to fit screen
  if space < info_width then
    info_height, info_width = H.floating_dimensions(lines, win_config.height, space)
  end

  local title = vim.fn.has('nvim-0.9') == 1 and H.fit_to_width(' Info ', info_width) or nil
  return {
    relative = 'editor',
    anchor = anchor,
    row = event.row,
    col = col,
    width = info_width,
    height = info_height,
    focusable = false,
    style = 'minimal',
    border = win_config.border,
    title = title,
  }
end

-- Signature help -------------------------------------------------------------
H.show_signature_window = function()
  -- If there is no received LSP result, make request and exit
  if H.signature.lsp.status ~= 'received' then
    local current_id = H.signature.lsp.id + 1
    H.signature.lsp.id = current_id
    H.signature.lsp.status = 'sent'

    local bufnr = vim.api.nvim_get_current_buf()
    local params = H.make_position_params()

    local cancel_fun = vim.lsp.buf_request_all(bufnr, 'textDocument/signatureHelp', params, function(result)
      if not H.is_lsp_current(H.signature, current_id) then return end

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

  -- Ensure permanent buffer with current highlighting to display signature
  H.ensure_buffer(H.signature, 'MiniCompletion:signature-help')
  H.ensure_highlight(H.signature, vim.bo.filetype)
  vim.api.nvim_buf_set_lines(H.signature.bufnr, 0, -1, false, lines)

  -- Add highlighting of active parameter
  local buf_id = H.signature.bufnr
  for i, hl_range in ipairs(hl_ranges) do
    if not vim.tbl_isempty(hl_range) and hl_range.first and hl_range.last then
      local first, last = hl_range.first, hl_range.last
      vim.api.nvim_buf_add_highlight(buf_id, H.ns_id, 'MiniCompletionActiveParameter', i - 1, first, last)
    end
  end

  -- If window is already opened and displays the same text, don't reopen it
  local cur_text = table.concat(lines, '\n')
  if H.signature.win_id and cur_text == H.signature.text then return end

  -- Cache lines for later checks if window should be reopened
  H.signature.text = cur_text

  -- Ensure window is closed
  H.close_action_window(H.signature)

  -- Compute floating window options
  local opts = H.signature_window_opts()

  -- Ensure that window doesn't open when it shouldn't
  if vim.fn.mode() == 'i' then H.open_action_window(H.signature, opts) end
end

H.signature_window_lines = function()
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

H.process_signature_response = function(response)
  if not response.signatures or vim.tbl_isempty(response.signatures) then return {} end

  -- Get active signature (based on textDocument/signatureHelp specification)
  local signature_id = response.activeSignature or 0
  -- This is according to specification: "If ... value lies outside ...
  -- defaults to zero"
  local n_signatures = vim.tbl_count(response.signatures or {})
  if signature_id < 0 or signature_id >= n_signatures then signature_id = 0 end
  local signature = response.signatures[signature_id + 1]

  -- Get displayed signature label
  local signature_label = signature.label

  -- Get start and end of active parameter (for highlighting)
  local hl_range = {}
  local n_params = vim.tbl_count(signature.parameters or {})
  local has_params = signature.parameters and n_params > 0

  -- Take values in this order because data inside signature takes priority
  local parameter_id = signature.activeParameter or response.activeParameter or 0
  local param_id_inrange = 0 <= parameter_id and parameter_id < n_params

  -- Computing active parameter only when parameter id is inside bounds is not
  -- strictly based on specification, as currently (v3.16) it says to treat
  -- out-of-bounds value as first parameter. However, some clients seem to use
  -- those values to indicate that nothing needs to be highlighted.
  -- Sources:
  -- https://github.com/microsoft/pyright/pull/1876
  -- https://github.com/microsoft/language-server-protocol/issues/1271
  if has_params and param_id_inrange then
    local param_label = signature.parameters[parameter_id + 1].label

    -- Compute highlight range based on type of supplied parameter label: can
    -- be string label which should be a part of signature label or direct start
    -- (inclusive) and end (exclusive) range values
    local first, last = nil, nil
    if type(param_label) == 'string' then
      first, last = signature_label:find(vim.pesc(param_label))
      -- Make zero-indexed and end-exclusive
      if first then first = first - 1 end
    elseif type(param_label) == 'table' then
      first, last = unpack(param_label)
    end
    if first then hl_range = { first = first, last = last } end
  end

  -- Return nested table because this will be a second argument of
  -- `vim.list_extend()` and the whole inner table is a target value here.
  return { { label = signature_label, hl_range = hl_range } }
end

H.signature_window_opts = function()
  local win_config = H.get_config().window.signature
  local lines = vim.api.nvim_buf_get_lines(H.signature.bufnr, 0, -1, false)
  local height, width = H.floating_dimensions(lines, win_config.height, win_config.width)

  -- Compute position
  local win_line = vim.fn.winline()
  local border_offset = win_config.border == 'none' and 0 or 2
  local space_above = win_line - 1 - border_offset
  local space_below = vim.api.nvim_win_get_height(0) - win_line - border_offset

  local anchor, row, space
  if height <= space_above or space_below <= space_above then
    anchor, row, space = 'SW', 0, space_above
  else
    anchor, row, space = 'NW', 1, space_below
  end

  -- Possibly adjust floating window dimensions to fit screen
  if space < height then
    height, width = H.floating_dimensions(lines, space, win_config.width)
  end

  -- Get zero-indexed current cursor position
  local bufpos = vim.api.nvim_win_get_cursor(0)
  bufpos[1] = bufpos[1] - 1

  local title = vim.fn.has('nvim-0.9') == 1 and H.fit_to_width(' Signature ', width) or nil
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
    border = win_config.border,
    title = title,
  }
end

-- Helpers for floating windows -----------------------------------------------
H.ensure_buffer = function(cache, name)
  if H.is_valid_buf(cache.bufnr) then return end

  local buf_id = vim.api.nvim_create_buf(false, true)
  cache.bufnr = buf_id
  vim.api.nvim_buf_set_name(buf_id, name)
  vim.bo[buf_id].buftype = 'nofile'
end

H.ensure_highlight = function(cache, filetype)
  if cache.hl_filetype == filetype then return end
  cache.hl_filetype = filetype
  local buf_id = cache.bufnr

  local has_lang, lang = pcall(vim.treesitter.language.get_lang, filetype)
  lang = has_lang and lang or filetype
  -- TODO: Remove `opts.error` after compatibility with Neovim=0.11 is dropped
  local has_parser, parser = pcall(vim.treesitter.get_parser, buf_id, lang, { error = false })
  has_parser = has_parser and parser ~= nil
  if has_parser then has_parser = pcall(vim.treesitter.start, buf_id, lang) end
  if not has_parser then vim.bo[buf_id].syntax = filetype end
end

-- Returns tuple of height and width
H.floating_dimensions = function(lines, max_height, max_width)
  max_height, max_width = math.max(max_height, 1), math.max(max_width, 1)

  -- Simulate how lines will look in window with `wrap` and `linebreak`.
  -- This is not 100% accurate (mostly because of concealed characters and
  -- multibyte manifest into empty space at bottom), but does the job
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
    if i <= height and width < l_width then width = l_width end
  end
  -- It should already be less that that because of wrapping, so this is "just
  -- in case"
  width = math.min(width, max_width)

  return math.max(height, 1), math.max(width, 1)
end

H.open_action_window = function(cache, opts)
  local win_id = vim.api.nvim_open_win(cache.bufnr, false, opts)
  vim.wo[win_id].breakindent = false
  vim.wo[win_id].foldenable = false
  vim.wo[win_id].foldmethod = 'manual'
  vim.wo[win_id].linebreak = true
  vim.wo[win_id].wrap = true
  cache.win_id = win_id
end

H.close_action_window = function(cache, keep_timer)
  if not keep_timer then cache.timer:stop() end

  if H.is_valid_win(cache.win_id) then vim.api.nvim_win_close(cache.win_id, true) end
  cache.win_id = nil

  -- For some reason 'buftype' might be reset. Ensure that buffer is scratch.
  if H.is_valid_buf(cache.bufnr) then vim.bo[cache.bufnr].buftype = 'nofile' end
end

-- Utilities ------------------------------------------------------------------
H.error = function(msg) error('(mini.completion) ' .. msg, 0) end

H.check_type = function(name, val, ref, allow_nil)
  if type(val) == ref or (ref == 'callable' and vim.is_callable(val)) or (allow_nil and val == nil) then return end
  H.error(string.format('`%s` should be %s, not %s', name, ref, type(val)))
end

H.is_valid_buf = function(buf_id) return type(buf_id) == 'number' and vim.api.nvim_buf_is_valid(buf_id) end

H.is_valid_win = function(win_id) return type(win_id) == 'number' and vim.api.nvim_win_is_valid(win_id) end

H.is_char_keyword = function(char)
  -- Using Vim's `match()` and `keyword` enables respecting Cyrillic letters
  return vim.fn.match(char, '[[:keyword:]]') >= 0
end

-- NOTE: Might return `true` even if there is no visible completion popup, but
-- built-in completion is still "active" (`<BS>` will show previous completion
-- immediately).
H.pumvisible = function() return vim.fn.pumvisible() > 0 end

H.get_completion_start = function(lsp_result)
  local pos = vim.api.nvim_win_get_cursor(0)

  -- Prefer completion start from LSP response(s)
  for _, response_data in pairs(lsp_result or {}) do
    local server_start = H.get_completion_start_server(response_data, pos[1] - 1)
    if server_start ~= nil then return server_start end
  end

  -- Fall back to start position of latest keyword
  local line = vim.api.nvim_get_current_line()
  return vim.fn.match(line:sub(1, pos[2]), '\\k*$')
end

H.get_completion_start_server = function(response_data, line_num)
  if response_data.err or type(response_data.result) ~= 'table' then return end
  local items = response_data.result.items or response_data.result
  for _, item in pairs(items) do
    if type(item.textEdit) == 'table' then
      -- NOTE: As per LSP spec, `textEdit` can be either `TextEdit` or `InsertReplaceEdit`
      local range = type(item.textEdit.range) == 'table' and item.textEdit.range or item.textEdit.insert
      -- NOTE: Return immediately, ignoring possibly several conflicting starts
      return range.start.character
    end
  end
end

H.is_whitespace = function(s)
  if type(s) == 'string' then return s:find('^%s*$') end
  if type(s) == 'table' then
    for _, val in pairs(s) do
      if not H.is_whitespace(val) then return false end
    end
    return true
  end
  return false
end

H.fit_to_width = function(text, width)
  local t_width = vim.fn.strchars(text)
  return t_width <= width and text or ('…' .. vim.fn.strcharpart(text, t_width - width + 1, width - 1))
end

-- Simulate splitting single line `l` like how it would look inside window with
-- `wrap` and `linebreak` set to `true`
H.wrap_line = function(l, width)
  local res = {}

  local success, width_id = true, nil
  -- Use `strdisplaywidth()` to account for multibyte characters
  while success and vim.fn.strdisplaywidth(l) > width do
    -- Simulate wrap by looking at breaking character from end of current break
    -- Use `pcall()` to handle complicated multibyte characters (like Chinese)
    -- for which even `strdisplaywidth()` seems to return incorrect values.
    success, width_id = pcall(vim.str_byteindex, l, width)

    if success then
      local break_match = vim.fn.match(l:sub(1, width_id):reverse(), '[- \t.,;:!?]')
      -- If no breaking character found, wrap at whole width
      local break_id = width_id - (break_match < 0 and 0 or break_match)
      table.insert(res, l:sub(1, break_id))
      l = l:sub(break_id + 1)
    end
  end
  table.insert(res, l)

  return res
end

H.table_get = function(t, id)
  if type(id) ~= 'table' then return H.table_get(t, { id }) end
  local success, res = true, t
  for _, i in ipairs(id) do
    --stylua: ignore start
    success, res = pcall(function() return res[i] end)
    if not success or res == nil then return end
    --stylua: ignore end
  end
  return res
end

H.get_left_char = function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  return string.sub(line, col, col)
end

H.map = function(mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

H.normalize_item_doc = function(completion_item)
  local detail, doc = completion_item.detail, completion_item.documentation
  if detail == nil and doc == nil then return {} end

  -- Extract string content. Treat markdown and plain kinds the same.
  -- Show both `detail` and `documentation` if the first provides new info.
  detail, doc = detail or '', (type(doc) == 'table' and doc.value or doc) or ''
  detail = (H.is_whitespace(detail) or doc:find(detail, 1, true) ~= nil) and ''
    -- Wrap details in language's code block to (usually) improve highlighting
    -- This approach seems to work in 'hrsh7th/nvim-cmp'
    or string.format('```%s\n%s\n```\n', vim.bo.filetype:match('^[^%.]*'), vim.trim(detail))
  local text = detail .. doc

  -- Ensure consistent line separators
  text = text:gsub('\r\n?', '\n')
  -- Remove trailing whitespace (converts blank lines to empty)
  text = text:gsub('[ \t]+\n', '\n'):gsub('[ \t]+$', '\n')
  -- Collapse multiple empty lines, remove top and bottom padding
  text = text:gsub('\n\n+', '\n\n'):gsub('^\n+', ''):gsub('\n+$', '')
  -- Remove padding around code blocks as they are concealed and appear empty
  text = text:gsub('\n*(\n```%S+\n)', '%1'):gsub('(\n```\n?)\n*', '%1')

  return text == '' and {} or vim.split(text, '\n')
end

-- TODO: Remove after compatibility with Neovim=0.9 is dropped
H.islist = vim.fn.has('nvim-0.10') == 1 and vim.islist or vim.tbl_islist

H.get_buf_lsp_clients = function() return vim.lsp.get_clients({ bufnr = 0 }) end
if vim.fn.has('nvim-0.10') == 0 then H.get_buf_lsp_clients = function() return vim.lsp.buf_get_clients() end end

-- TODO: Remove after compatibility with Neovim=0.10 is dropped
H.make_position_params = function() return vim.lsp.util.make_position_params() end
if vim.fn.has('nvim-0.11') == 1 then
  -- Use callable `params` to workaround mandatory non-nil `offset_encoding` in
  -- `vim.lsp.util.make_position_params()` on Neovim>=0.11
  H.make_position_params = function()
    return function(client, _) return vim.lsp.util.make_position_params(0, client.offset_encoding) end
  end
end

return MiniCompletion
