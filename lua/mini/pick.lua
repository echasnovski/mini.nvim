--- *mini.pick* Pick anything
--- *MiniPick*
---
--- MIT License Copyright (c) 2023 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Features:
---
--- - Single window general purpose interface for picking element from any array.
---
--- - On demand toggleable preview and info views.
---
--- - Interactive query matching (filter+sort) with fast non-blocking default
---   which does fuzzy matching and allows other modes (|MiniPick.default_match()|).
---
--- - Built-in pickers (see |MiniPick.builtin|):
---     - Files.
---     - Pattern match (for fixed pattern and with live feedback).
---     - Buffers.
---     - Help tags.
---     - CLI output.
---     - Resume latest picker.
---
--- - |:Pick| command to work with extensible |MiniPick.registry|.
---
--- - |vim.ui.select()| wrapper (see |MiniPick.ui_select()|).
---
--- - Rich and customizable built-in |MiniPick-actions| when picker is active:
---     - Manually change currently focused item.
---     - Scroll vertically and horizontally.
---     - Toggle preview or info view.
---     - Mark/unmark items to choose later.
---     - Refine current matches (make them part of a new picker).
---     - And many more.
---
--- - Minimal yet flexible |MiniPick-source| specification with:
---     - Items (array, callable, or manually set later).
---     - Source name.
---     - Working directory.
---     - Matching algorithm.
---     - Way matches are shown in main window.
---     - Item preview.
---     - "On choice" action for current and marked items.
---
--- - Custom actions/keys can be configured globally, per buffer, or per picker.
---
--- - Out of the box support for 'ignorecase' and 'smartcase'.
---
--- - Match caching to increase responsiveness on repeated prompts.
---
--- Notes:
--- - Works on all supported versions but using Neovim>=0.9 is recommended.
---   Neovim>=0.10 will give more visual feedback in floating window footer.
---
--- - For more pickers see |MiniExtra.pickers|.
---
--- Sources with more details:
--- - |MiniPick-overview|
--- - |MiniPick-source|
--- - |MiniPick-actions|
--- - |MiniPick-examples|
--- - |MiniPick.builtin|
---
--- # Dependencies ~
---
--- Suggested dependencies (provide extra functionality, will work without them):
---
--- - Plugin 'nvim-tree/nvim-web-devicons' for filetype icons near the items
---   representing actual paths. If missing, default or no icons will be used.
---
---                                                             *MiniPick-cli-tools*
--- - CLI tool(s) to power |MiniPick.builtin.files()|, |MiniPick.builtin.grep()|, and
---   |MiniPick.builtin.grep_live()| built-in pickers:
---     - `rg` (github.com/BurntSushi/ripgrep; enough for all three; recommended).
---     - `fd` (github.com/sharkdp/fd; for `files` only).
---     - `git` (github.com/git/git; enough for all three).
---
---   Note: CLI tools are called only with basic arguments needed to get items.
---   To customize the output, use their respective configuration approaches.
---   Here are some examples of where to start:
---     - github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file
---     - github.com/sharkdp/fd#excluding-specific-files-or-directories
---     - git-scm.com/docs/gitignore
---
--- # Setup ~
---
--- This module needs a setup with `require('mini.pick').setup({})` (replace
--- `{}` with your `config` table). It will create global Lua table `MiniPick`
--- which you can use for scripting or manually (with `:lua MiniPick.*`).
---
--- See |MiniPick.config| for available config settings.
---
--- You can override runtime config settings locally to buffer inside
--- `vim.b.minipick_config` which should have same structure as `MiniPick.config`.
--- See |mini.nvim-buffer-local-config| for more details.
---
--- # Comparisons ~
---
--- - 'nvim-telescope/telescope.nvim':
---     - The main inspiration for this module, so there is significant overlap.
---     - Has three (or two) window UI (prompt, matches, preview), while this
---       module combines everything in one window. It allows more straightforward
---       customization for unusual scenarios.
---     - Default match algorithm is somewhat slow, while this module should
---       match relatively lag-free for at least 100K+ items.
---     - Has many built-in pickers, while this module has handful at its core
---       relying on other 'mini.nvim' modules to provide more (see |MiniExtra|).
---
--- - 'ibhagwan/fzf-lua':
---     - Mostly same comparison as with 'nvim-telescope/telescope.nvim'.
---     - Requires 'junegunn/fzf' installed to power fuzzy matching, while this
---       module provides built-in Lua matching.
---
--- # Highlight groups ~
---
--- * `MiniPickBorder` - window border.
--- * `MiniPickBorderBusy` - window border while picker is busy processing.
--- * `MiniPickBorderText` - non-prompt on border.
--- * `MiniPickIconDirectory` - default icon for directory.
--- * `MiniPickIconFile` - default icon for file.
--- * `MiniPickHeader` - headers in info buffer and previews.
--- * `MiniPickMatchCurrent` - current matched item.
--- * `MiniPickMatchMarked` - marked matched items.
--- * `MiniPickMatchRanges` - ranges matching query elements.
--- * `MiniPickNormal` - basic foreground/background highlighting.
--- * `MiniPickPreviewLine` - target line in preview.
--- * `MiniPickPreviewRegion` - target region in preview.
--- * `MiniPickPrompt` - prompt.
---
--- To change any highlight group, modify it directly with |:highlight|.

--- Events ~
---
--- To allow user customization and integration of external tools, certain |User|
--- autocommand events are triggered under common circumstances:
---
--- - `MiniPickStart` - just after picker has started.
--- - `MiniPickStop` - just before picker is stopped.
---@tag MiniPick-events

--- # Overview ~
---
--- General idea is to take array of objects, display them with interactive
--- filter/sort/navigate/preview, and allow to choose one or more items.
---
--- ## How to start a picker ~
---
--- - Use |MiniPick.start()| with `opts.source` defining |MiniPick-source|.
---   Example: `MiniPick.start({ source = { items = vim.fn.readdir('.') } })`
---
--- - Use any of |MiniPick.builtin| pickers directly.
---   Example: `MiniPick.builtin.files({ tool = 'git' })`
---
--- - Use |:Pick| command which uses customizable pickers from |MiniPick.registry|.
---   Example: `:Pick files tool='git'`
---
--- ## User interface ~
---
--- UI consists from a single window capable of displaying three different views:
--- - "Main" - where current query matches are shown.
--- - "Preview" - preview of current item (toggle with `<Tab>`).
--- - "Info" - general info about picker and its state (toggle with `<S-Tab>`).
---
--- Current prompt is displayed (in Neovim>=0.9) at the top left of the window
--- border with vertical line indicating caret (current input position).
---
--- Bottom part of window border displays (in Neovim>=0.10) extra visual feedback:
--- - Left part is a picker name.
--- - Right part contains information in the format >
---   <current index in matches> | <match count> | <marked count> / <total count>
---
--- When picker is busy (like if there are no items yet set or matching is active)
--- window border changes color to be `MiniPickBorderBusy` after `config.delay.busy`
--- milliseconds of idle time.
---
--- ## Life cycle ~
---
--- - Type characters to filter and sort matches. It uses |MiniPick.default_match()|
---   with `query` being an array of pressed characters.
---   Overview of how it matches:
---     - If query starts with `'`, the match is exact.
---     - If query starts with `^`, the match is exact at start.
---     - If query ends with `$`, the match is exact at end.
---     - If query starts with `*`, the match is forced to be fuzzy.
---     - Otherwise match is fuzzy.
---     - Sorting is done to first minimize match width and then match start.
---       Nothing more: no favoring certain places in string, etc.
---
--- - Type special keys to perform |MiniPick-actions|. Here are some basic ones:
---     - `<C-n>` / `<Down>` moves down; `<C-p>` / `<Up>` moves up.
---     - `<Left>` / `<Right>` moves prompt caret left / right.
---     - `<S-Tab>` toggles information window with all available mappings.
---     - `<Tab>` toggles preview.
---     - `<C-x>` / `<C-a>` toggles current / all item(s) as (un)marked.
---     - `<C-Space>` / `<M-Space>` makes all matches or marked items as new picker.
---     - `<CR>` / `<M-CR>` chooses current/marked item(s).
---     - `<Esc>` / `<C-c>` stops picker.
---
--- ## Implementation details ~
---
--- - Any picker is non-blocking but waits to return the chosen item. Example:
---   `file = MiniPick.builtin.files()` allows other actions to be executed when
---   picker is shown while still assigning `file` with value of the chosen item.
---@tag MiniPick-overview

--- Source is defined as a `source` field inside one of (in increasing priority):
--- - |MiniPick.config| - has global effect.
--- - |vim.b.minipick_config| - has buffer-local effect.
--- - `opts.source` in picker call - has effect for that particular call.
---
--- Example of source to choose from |arglist|: >
---   { items = vim.fn.argv, name = 'Arglist' }
--- <
---
--- Note: this is mostly useful for writing pickers. Can safely skip if you
--- want to just use provided pickers.
---
---                                                          *MiniPick-source.items*
--- # Items ~
---
--- `source.items` defines items to choose from. It should be one of the following:
--- - Array of objects which can have different types. Any type is allowed.
--- - `nil`. Picker waits for explicit |MiniPick.set_picker_items()| call.
--- - Callable returning any of the previous types. Will be called once on start.
---
---                                                 *MiniPick-source.items-stritems*
--- Matching is done for items array based on the string representation of its
--- elements (here called "stritems"). For single item it is computed as follows:
--- - Callable is called once with output used in next steps.
--- - String item is used as is.
--- - String <text> field of table item is used (if present).
--- - Use output of |vim.inspect()|.
---
--- Example: >
---
---   items = { 'aaa.txt', { text = 'bbb' }, function() return 'ccc' end }
---   -- corresponding stritems are { 'aaa.txt', 'bbb', 'ccc' }
---
--- Default value is `nil`, assuming it always be supplied by the caller.
---
---                                                   *MiniPick-source.items-common*
--- There are some recommendations for common item types in order for them to work
--- out of the box with |MiniPick.default_show()|, |MiniPick.default_preview()|,
--- |MiniPick.default_choose()|, |MiniPick.default_choose_marked()|:
---
--- - Path (file or directory). Use string or `path` field of a table. Path can
---   be either absolute or relative to the `source.cwd`.
---   Examples: `'aaa.txt'`, `{ path = 'aaa.txt' }`
---
--- - Buffer. Use buffer id as number, string, or `bufnr` / `buf_id` / `buf`
---   field of a table (any name is allowed).
---   Examples: `1`, `'1'`, `{ bufnr = 1 }`, `{ buf_id = 1 }`, `{ buf = 1 }`
---
--- - Line in file or buffer. Use table representation with `lnum` field with line
---   number (starting from 1) or string in "<path>:<line>" format.
---   Examples: >
---   { path = 'aaa.txt', lnum = 2 }, 'aaa.txt:2', { bufnr = 1, lnum = 3 }
---
--- - Position in file or buffer. Use table representation with `lnum` and `col`
---   fields with line and column numbers (starting from 1) or string in
---   "<path>:<line>:<col>" format.
---   Examples: >
---   { path = 'aaa.txt', lnum = 2, col = 3 }, 'aaa.txt:2:3',
---   { bufnr = 1, lnum = 3, col = 4 }
---
--- - Region in file or buffer. Use table representation with `lnum`, `col`,
---   `end_lnum`, `end_col` fields for start and end line/column. All numbers
---   start from 1, end line is inclusive, end column is exclusive.
---   This naming is similar to |getqflist()| and |diagnostic-structure|.
---   Examples: >
---   { path = 'aaa.txt', lnum = 2, col = 3, end_lnum = 4, end_col = 5 },
---   { bufnr = 1, lnum = 3, col = 4, end_lnum = 5, end_col = 6 }
---
--- Note: all table items will benefit from having `text` field for better matching.
---
---                                                           *MiniPick-source.name*
--- # Name ~
---
--- `source.name` defines the name of the picker to be used for visual feedback.
---
--- Default value is "<No name>".
---
---                                                            *MiniPick-source.cwd*
--- # Current working directory ~
---
--- `source.cwd` is a string defining the current working directory in which
--- picker operates. It should point to a valid actually present directory path.
--- This is a part of source to allow persistent way to use relative paths,
--- i.e. not depend on current directory being constant after picker start.
--- It also makes the |MiniPick.builtin.resume()| picker more robust.
---
--- Default value is |current-directory|.
---
---                                                          *MiniPick-source.match*
--- # Match ~
---
--- `source.match` is a callable defining how stritems
--- (see |MiniPick-source.items-stritems|) are matched (filtered and sorted) based
--- on the query.
---
--- It will be called with the following arguments:
--- - `stritems` - all available stritems for current picker.
--- - `inds` - array of `stritems` indexes usually pointing at current matches.
---   It does point to current matches in the case of interactively appending
---   character at the end of the query. It assumes that matches for such bigger
---   query is a subset of previous matches (implementation can ignore it).
---   This can be utilized to increase performance by checking fewer stritems.
--- - `query` - array of strings. Usually (like is common case of user interactively
---   typing query) each string represents one character. However, any strings are
---   allowed, as query can be set with |MiniPick.set_picker_query()|.
---
--- It should either return array of match indexes for stritems elements matching
--- the query (synchronous) or explicitly use |MiniPick.set_picker_match_inds()|
--- to set them (may be asynchronous).
---
--- Notes:
--- - The result can be any array of `stritems` indexes, i.e. not necessarily
---   a subset of input `inds`.
---
--- - Both `stritems` and `query` depend on values of 'ignorecase' and 'smartcase'.
---   If query shows "ignore case" properties (only 'ignorecase' is set or both
---   'ignorecase' / 'smartcase' are set and query has only lowercase characters),
---   then `stritems` and `query` will have only lowercase characters.
---   This allows automatic support for case insensitive matching while being
---   faster and having simpler match function implementation.
---
--- - Writing custom `source.match` usually means also changing |MiniPick-source.show|
---   because it is used to highlight stritems parts actually matching the query.
---
--- Example of simple "exact" `match()` preserving initial order: >
---
---   local match_exact = function(stritems, inds, query)
---     local prompt_pattern = vim.pesc(table.concat(query))
---     local f = function(i) return stritems[i]:find(prompt_pattern) ~= nil end
---     return vim.tbl_filter(f, inds)
---   end
--- <
---   For non-blocking version see |MiniPick.poke_is_picker_active()|.
---
--- Default value is |MiniPick.default_match()|.
---
---                                                           *MiniPick-source.show*
--- # Show ~
---
--- `source.show` is a callable defining how matched items are shown in the window.
---
--- It will be called with the following arguments:
--- - `buf_id` - identifier of the target buffer.
--- - `items_to_show` - array of actual items to be shown in `buf_id`. This is
---   a subset of currently matched items computed to fit in current window view.
--- - `query` - array of strings. Same as in `source.match`.
---
--- It should update buffer `buf_id` to visually represent `items_to_show`
--- __one item per line starting from line one__ (it shouldn't depend on
--- `options.content_from_bottom`). This also includes possible visualization
--- of which parts of stritem actually matched query.
---
--- Example (assuming string items; without highlighting): >
---
---   local show_prepend = function(buf_id, items_arr, query)
---     local lines = vim.tbl_map(function(x) return 'Item: ' .. x end, items_arr)
---     vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
---   end
---
--- Default value is |MiniPick.default_show()|.
---
---                                                        *MiniPick-source.preview*
--- # Preview ~
---
--- `source.preview` is a callable defining how item preview is done.
---
--- It will be called with the following arguments:
--- - `buf_id` - identifier of the target buffer. Note: for every separate instance
---   of item previewing new scratch buffer is be created.
--- - `item` - item to preview.
---
--- It should update buffer `buf_id` to visually represent `item`.
---
--- Example: >
---
---   local preview_inspect = function(buf_id, item)
---     local lines = vim.split(vim.inspect(item), '\n')
---     vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
---   end
---
--- Default value is |MiniPick.default_preview()|.
---
---                                                         *MiniPick-source.choose*
--- # Choose an item ~
---
--- `source.choose` is a callable defining what to do when an item is chosen.
---
--- It will be called with the following arguments:
--- - `item` - chosen item. Always non-`nil`.
---
--- It should perform any intended "choose" action for an item and return
--- a value indicating whether picker should continue (i.e. not stop):
--- `nil` and `false` will stop picker, other values will continue.
---
--- Notes:
--- - It is called when picker window is still current. Use `windows.target` value
---   from |MiniPick.get_picker_state()| output to do something with target window.
---
--- Example: >
---
---   local choose_file_continue = function(item)
---     if vim.fn.filereadable(item) == 0 then return end
---     vim.api.nvim_win_call(
---       MiniPick.get_picker_state().windows.main,
---       function() vim.cmd('edit ' .. item) end
---     )
---     return true
---   end
---
--- Default value is |MiniPick.default_choose()|.
---
---                                                  *MiniPick-source.choose_marked*
--- # Choose marked items ~
---
--- `source.choose_marked` is a callable defining what to do when marked items
--- (see |MiniPick-actions-mark|) are chosen. Serves as a companion to
--- `source.choose` which can choose several items.
---
--- It will be called with the following arguments:
--- - `items_marked` - array of marked items. Can be empty.
---
--- It should perform any intended "choose" action for several items and return
--- a value indicating whether picker should continue (i.e. not stop):
--- `nil` and `false` will stop picker, other values will continue.
---
--- Notes:
--- - It is called when picker window is still current. Use `windows.target` value
---   from |MiniPick.get_picker_state()| output to do something with target window.
---
--- Example: >
---
---   local choose_marked_print = function(items) print(vim.inspect(items)) end
---
--- Default value is |MiniPick.default_choose_marked()|.
---@tag MiniPick-source

--- When picker is active, `mappings` table defines a set of special keys which when
--- pressed will execute certain actions. Those can be of two types:
--- - Built-in: actions present in default `config.mappings`. Can be only overridden
---   with a different key.
--- - Custom: user defined actions. Should be a table with `char` and `func` fields.
---
---
--- # Built-in ~
---                                                         *MiniPick-actions-caret*
--- ## Caret ~
---
--- User can add character not only at query end, but more generally at caret.
---
--- - `mappings.caret_left` - move caret to left.
--- - `mappings.caret_right` - move caret to right.
---
---                                                        *MiniPick-actions-choose*
--- ## Choose ~
---
--- Choose is a fundamental action that actually implements the intent of
--- calling a picker, i.e. pick an item.
---
--- - `mappings.choose` - choose as is, i.e. apply `source.choose` for current item.
--- - `mappings.choose_in_split` - make horizontal split at target window, update
---   target window to the new split, and choose.
--- - `mappings.choose_in_tabpage` - same as `choose_in_split`, but create tabpage.
--- - `mappings.choose_in_vsplit` - same as `choose_in_split`, but split vertically.
--- - `mappings.choose_marked` - choose marked items as is, i.e.
---   apply `source.choose_marked` at current marked items.
---
---                                                        *MiniPick-actions-delete*
--- ## Delete ~
---
--- Delete actions are for deleting elements from query.
---
--- - `mappings.delete_char` - delete one character to the left.
--- - `mappings.delete_char_right` - delete one character to the right.
--- - `mappings.delete_left` - delete everything to the left (like |i_CTRL-U|).
--- - `mappings.delete_word` - delete word to the left (like |i_CTRL-W|).
---
---                                                          *MiniPick-actions-mark*
--- ## Mark ~
---
--- Marking is an action of adding certain items to a separate list which then can
--- be chosen with `mappings.choose_marked` (for example, sent to quickfix list).
--- This is a companion to a regular choosing which can pick only one item.
---
--- - `mappings.mark` - toggle marked/unmarked state of current item.
--- - `mappings.mark_all` - toggle marked/unmarked state (mark all if not all
---   marked; unmark all otherwise) of all currently matched items.
---
--- Notes:
--- - Marks persist across queries and matches. For example, user can make a query
---   with marking all matches several times and marked items from all queries
---   will be preserved.
---
---                                                          *MiniPick-actions-move*
--- ## Move ~
---
--- Move is a fundamental action of changing which item is current.
---
--- - `mappings.move_down` - change focus to the item below.
--- - `mappings.move_start` change focus to the first currently matched item
--- - `mappings.move_up` - change focus to the item above.
---
--- Notes:
--- - Up and down wrap around edges: `move_down` on last item moves to first,
---   `move_up` on first moves to last.
--- - Moving when preview or info view is shown updates the view with new item.
--- - These also work with non-overridable alternatives:
---     - `<Down>` moves down.
---     - `<Home>` moves to first matched.
---     - `<Up>` moves up.
---
---                                                         *MiniPick-actions-paste*
--- ## Paste ~
---
--- Paste is an action to paste content of |registers| at caret.
---
--- - `mappings.paste` - paste from register defined by the next key press.
---
--- Notes:
--- - Does not support expression register `=`.
---
---                                                        *MiniPick-actions-refine*
--- ## Refine ~
---
--- Refine is an action that primarily executes the following:
--- - Takes certain items and makes them be all items (in order they are present).
--- - Resets query.
--- - Updates `source.match` to be the one from config.
---
--- - `mappings.refine` - refine currently matched items.
--- - `mappings.refin_marked` - refine currently marked items.
---
--- This action is useful in at least two cases:
--- - Perform consecutive "narrowing" queries. Example: to get items that contain
---   both "hello" and "world" exact matches (in no particular order) with default
---   matching, type "'hello" (notice "'" at the start) followed by `<C-Space>` and
---   another "'world".
--- - Reset `match` to default. Particularly useful in |MiniPick.builtin.grep_live()|.
---
---                                                        *MiniPick-actions-scroll*
--- ## Scroll ~
---
--- Scroll is an action to either move current item focus further than to the
--- neighbor item or adjust window view to see more information.
---
--- - `mappings.scroll_down` - when matches are shown, go down by the amount of
---   visible matches. In preview and info view - scroll down as with |CTRL-F|.
--- - `mappings.scroll_left` - scroll left as with |zH|.
--- - `mappings.scroll_right` - scroll right as with |zL|.
--- - `mappings.scroll_up` - when matches are shown, go up by the amount of
---   visible matches. In preview and info view - scroll up as with |CTRL-B|.
---
---                                                          *MiniPick-actions-stop*
--- ## Stop ~
---
--- `mappings.stop` stops the picker. <C-c> also always stops the picker.
---
---
---                                                        *MiniPick-actions-toggle*
--- ## Toggle ~
---
--- Toggle action is a way to change view: show if target is not shown, reset to
--- main view otherwise.
---
--- - `mappings.toggle_info` - toggle info view.
--- - `mappings.toggle_preview` - toggle preview.
---
--- Note:
--- - Updating query in any way resets window view to show matches.
--- - Moving current item focus keeps preview or info view with updated item.
---
---                                                        *MiniPick-actions-custom*
--- # Custom ~
---
--- Along with built-in actions, users can define custom actions. This can be
--- done by supplying custom elements to `mappings` table. The field defines action
--- name (used to infer an action description in info view). The value is a table
--- with the following fields:
--- - <char> `(string)` - single character acting as action trigger.
--- - <func> `(function)` - callable to be executed without arguments after
---   user presses <char>. Its return value is treated as "should stop picker
---   after execution", i.e. returning nothing, `nil`, or `false` continues
---   picker while everything else (prefer `true`) stops it.
---
--- Example of `execute` custom mapping: >
---
---   execute = {
---     char = '<C-e>',
---     func = function() vim.cmd(vim.fn.input('Execute: ')) end,
---   }
---@tag MiniPick-actions

--- Common configuration examples ~
---
--- - Disable icons in |MiniPick.builtin| pickers related to paths: >
---
---   local pick = require('mini.pick')
---   pick.setup({ source = { show = pick.default_show } })
---
--- - Mappings to switch `toggle_{preview,info}` and `move_{up,down}`: >
---
---   require('mini.pick').setup({
---     mappings = {
---       toggle_info    = '<C-k>',
---       toggle_preview = '<C-p>',
---       move_down      = '<Tab>',
---       move_up        = '<S-Tab>',
---     }
---   })
---
--- - Different window styles: >
---
---   -- Different border
---   { window = { config = { border = 'double' } } }
---
---   -- "Cursor tooltip"
---   {
---     window = {
---       config = {
---         relative = 'cursor', anchor = 'NW',
---         row = 0, col = 0, width = 40, height = 20,
---       },
---     },
---   }
---
---   -- Centered on screen
---   local win_config = function()
---     height = math.floor(0.618 * vim.o.lines)
---     width = math.floor(0.618 * vim.o.columns)
---     return {
---       anchor = 'NW', height = height, width = width,
---       row = math.floor(0.5 * (vim.o.lines - height)),
---       col = math.floor(0.5 * (vim.o.columns - width)),
---     }
---   end
---   { window = { config = win_config } }
---@tag MiniPick-examples

---@alias __pick_builtin_opts table|nil Options forwarded to |MiniPick.start()|.
---@alias __pick_builtin_local_opts table|nil Options defining behavior of this particular picker.

---@diagnostic disable:undefined-field
---@diagnostic disable:discard-returns
---@diagnostic disable:unused-local
---@diagnostic disable:cast-local-type

-- Module definition ==========================================================
local MiniPick = {}
local H = {}

--- Module setup
---
---                                                                          *:Pick*
--- Calling this function creates a `:Pick` user command. It takes picker name
--- from |MiniPick.registry| as mandatory first argument and executes it with
--- following (expanded, |expandcmd()|) |<f-args>| combined in a single table.
--- To add custom pickers, update |MiniPick.registry|.
---
--- Example: >
---
---   :Pick files tool='git'
---   :Pick grep pattern='<cword>'
---
---@param config table|nil Module config table. See |MiniPick.config|.
---
---@usage `require('mini.pick').setup({})` (replace `{}` with your `config` table).
MiniPick.setup = function(config)
  -- Export module
  _G.MiniPick = MiniPick

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Define behavior
  H.create_autocommands(config)

  -- Create default highlighting
  H.create_default_hl()

  -- Create user commands
  H.create_user_commands()
end

--stylua: ignore
--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # Delays ~
---
--- `config.delay` defines plugin delays (in ms). All should be strictly positive.
---
--- `delay.async` is a delay between forcing asynchronous behavior. This usually
--- means making screen redraws and utilizing |MiniPick.poke_is_picker_active()|
--- (for example, to stop current matching if query has updated).
--- Smaller values give smoother user experience at the cost of more computations.
---
--- `delay.busy` is a delay between when some computation starts and showing
--- visual feedback about it by making window border to have `MiniPickBorderBusy`
--- highlight group.
--- Smaller values will give feedback faster at the cost of feeling like flicker.
---
--- # Mappings ~
---
--- `config.mappings` defines keys for special actions to be triggered after certain
--- keys. See |MiniPick-actions| for more information.
---
--- # Options ~
---
--- `config.options` contains some general purpose options.
---
--- `options.content_from_bottom` is a boolean indicating whether content should be
--- shown from bottom to top. That means that best matches will be shown at
--- the bottom. Note: for better experience use Neovim>=0.10, which has floating
--- window footer capability. Default: `false`.
---
--- `options.use_cache` is a boolean indicating whether match results should be
--- cached per prompt (i.e. concatenated query). This results into faster response
--- on repeated prompts (like when deleting query entries) at the cost of using
--- more memory. Default: `false`.
---
--- # Source ~
---
--- `config.source` defines fallbacks for source specification. For example, this
--- can be used to change default `match` to use different implementation or `show`
--- to not show icons for some |MiniPick.builtin| pickers (see |MiniPick-examples|).
--- See |MiniPick-source| for more information.
---
--- # Window ~
---
--- `config.window` contains window specific configurations.
---
--- `window.config` defines a (parts of) default floating window config for the main
--- picker window. This can be either a table overriding some parts or a callable
--- returning such table. See |MiniPick-examples| for some examples.
---
--- `window.prompt_cursor` defines how cursor is displayed in window's prompt.
--- Default: '▏'.
---
--- `window.prompt_prefix` defines what prefix is used in window's prompt.
--- Default: '> '.
MiniPick.config = {
  -- Delays (in ms; should be at least 1)
  delay = {
    -- Delay between forcing asynchronous behavior
    async = 10,

    -- Delay between computation start and visual feedback about it
    busy = 50,
  },

  -- Keys for performing actions. See `:h MiniPick-actions`.
  mappings = {
    caret_left  = '<Left>',
    caret_right = '<Right>',

    choose            = '<CR>',
    choose_in_split   = '<C-s>',
    choose_in_tabpage = '<C-t>',
    choose_in_vsplit  = '<C-v>',
    choose_marked     = '<M-CR>',

    delete_char       = '<BS>',
    delete_char_right = '<Del>',
    delete_left       = '<C-u>',
    delete_word       = '<C-w>',

    mark     = '<C-x>',
    mark_all = '<C-a>',

    move_down  = '<C-n>',
    move_start = '<C-g>',
    move_up    = '<C-p>',

    paste = '<C-r>',

    refine        = '<C-Space>',
    refine_marked = '<M-Space>',

    scroll_down  = '<C-f>',
    scroll_left  = '<C-h>',
    scroll_right = '<C-l>',
    scroll_up    = '<C-b>',

    stop = '<Esc>',

    toggle_info    = '<S-Tab>',
    toggle_preview = '<Tab>',
  },

  -- General options
  options = {
    -- Whether to show content from bottom to top
    content_from_bottom = false,

    -- Whether to cache matches (more speed and memory on repeated prompts)
    use_cache = false,
  },

  -- Source definition. See `:h MiniPick-source`.
  source = {
    items = nil,
    name  = nil,
    cwd   = nil,

    match   = nil,
    show    = nil,
    preview = nil,

    choose        = nil,
    choose_marked = nil,
  },

  -- Window related options
  window = {
    -- Float window config (table or callable returning it)
    config = nil,

    -- String to use as cursor in prompt
    prompt_cursor = '▏',

    -- String to use as prefix in prompt
    prompt_prefix = '> ',
  },
}
--minidoc_afterlines_end

--- Start picker
---
--- Notes:
--- - If there is currently an active picker, it is properly stopped and new one
---   is started "soon" in the main event-loop (see |vim.schedule()|).
--- - Current window at the moment of this function call is treated as "target".
---   See |MiniPick.get_picker_state()| and |MiniPick.set_picker_target_window()|.
---
---@param opts table|nil Options. Should have same structure as |MiniPick.config|.
---   Default values are inferred from there.
---   Usually should have proper |MiniPick-source.items| defined.
---
---@return any Item which was current when picker is stopped; `nil` if aborted.
MiniPick.start = function(opts)
  if MiniPick.is_picker_active() then
    -- Try proper 'key query process' stop
    MiniPick.stop()
    -- NOTE: Needs `defer_fn()` for `stop()` to properly finish code flow and
    -- not be executed before it
    return vim.defer_fn(function()
      -- NOTE: if `MiniPick.stop()` still didn't stop, force abort
      if MiniPick.is_picker_active() then H.picker_stop(H.pickers.active, true) end
      MiniPick.start(opts)
    end, 0.5)
  end

  H.cache = {}
  opts = H.validate_picker_opts(opts)
  local picker = H.picker_new(opts)
  H.pickers.active = picker

  H.picker_set_busy(picker, true)
  local items = H.expand_callable(opts.source.items)
  -- - Set items on next event loop to not block when computing stritems
  if vim.tbl_islist(items) then vim.schedule(function() MiniPick.set_picker_items(items) end) end

  H.picker_track_lost_focus(picker)
  return H.picker_advance(picker)
end

--- Stop active picker
MiniPick.stop = function()
  if not MiniPick.is_picker_active() then return end
  H.cache.is_force_stop_advance = true
  if H.cache.is_in_getcharstr then vim.api.nvim_feedkeys('\3', 't', true) end
end

--- Refresh active picker
MiniPick.refresh = function()
  if not MiniPick.is_picker_active() then return end
  H.picker_update(H.pickers.active, false, true)
end

--- Default match
---
--- Filter target stritems to contain query and sort from best to worst matches.
---
--- Implements default value for |MiniPick-source.match|.
---
--- By default (if no special modes apply) it does the following fuzzy matching:
---
--- - Stritem contains query if it contains all its elements verbatim in the same
---   order (possibly with gaps, i.e. not strictly one after another).
---   Note: empty query and empty string element is contained in any string.
---
--- - Sorting is done with the following ordering (same as in |mini.fuzzy|):
---     - The smaller the match width (end column minus start column) the better.
---     - Among same match width, the smaller start column the better.
---     - Among same match width and start column, preserve original order.
---
--- Notes:
--- - Most common interactive usage results into `query` containing one typed
---   character per element.
---
--- # Special modes ~
---
--- - Forced modes:
---     - Query starts with "*": match the rest fuzzy (without other modes).
---     - Query starts with "'": match the rest exactly (without gaps).
---
--- - Place modes:
---     - Query starts with '^': match the rest exactly at start.
---     - Query ends with '$': match the rest exactly at end.
---     - Both modes can be used simultaneously.
---
--- - Grouped: query contains at least one whitespace element. Output is computed
---   as if query is split at whitespace indexes with concatenation between them.
---
--- Precedence of modes:
---   "forced exact" = "forced fuzzy" > "place start/end" > "grouped" > "default"
---
--- # Examples ~
---
--- Assuming `stritems` are `{ '_abc', 'a_bc', 'ab_c', 'abc_' }`, here are some
--- example matches based on prompt (concatenated query): >
---
---   | Prompt | Matches                |
---   |--------|------------------------|
---   | abc    | All                    |
---   | *abc   | All                    |
---   |        |                        |
---   | 'abc   | abc_, _abc             |
---   | *'abc  | None (no "'" in items) |
---   |        |                        |
---   | ^abc   | abc_                   |
---   | *^abc  | None (no "^" in items) |
---   |        |                        |
---   | abc$   | _abc                   |
---   | *abc$  | None (no "$" in items) |
---   |        |                        |
---   | ab c   | abc_, _abc, ab_c       |
---   | *ab c  | None (no " " in items) |
---
--- Having query `{ 'ab', 'c' }` is the same as "ab c" prompt.
---
--- You can have a feel of how this works with this command: >
---
---   MiniPick.start({ source = { items = { '_abc', 'a_bc', 'ab_c', 'abc_' } } })
---
---@param stritems table Array of all stritems.
---@param inds table Array of `stritems` indexes to match. All of them should point
---   at string elements of `stritems`. No check is done for performance reasons.
---@param query table Array of strings.
---@param do_sync boolean|nil Whether to match synchronously. Default: `nil`.
---
---@return table|nil Depending on whether computation is synchronous (either `do_sync`
---   is truthy or there is an active picker):
---   - If yes, array of `stritems` indexes matching the `query` (from best to worst).
---   - If no, `nil` is returned with |MiniPick.set_picker_match_inds()| used later.
MiniPick.default_match = function(stritems, inds, query, do_sync)
  local is_sync = do_sync or not MiniPick.is_picker_active()
  local set_match_inds = is_sync and function(x) return x end or MiniPick.set_picker_match_inds
  local f = function()
    if #query == 0 then return set_match_inds(H.seq_along(stritems)) end
    local match_data, match_type = H.match_filter(inds, stritems, query)
    if match_data == nil then return end
    if match_type == 'nosort' then return set_match_inds(H.seq_along(stritems)) end
    local match_inds = H.match_sort(match_data)
    if match_inds == nil then return end
    return set_match_inds(match_inds)
  end

  if is_sync then return f() end
  coroutine.resume(coroutine.create(f))
end

--- Default show
---
--- Show items in a buffer and highlight parts that actually match query (assuming
--- match is done with |MiniPick.default_match()|). Lines are computed based on
--- the |MiniPick-source.items-stritems|.
---
--- Implements default value for |MiniPick-source.show|.
---
--- Uses the following highlight groups (see |MiniPick| for their description):
---
--- * `MiniPickIconDirectory`
--- * `MiniPickIconFile`
--- * `MiniPickMatchCurrent`
--- * `MiniPickMatchMarked`
--- * `MiniPickMatchRanges`
---
---@param buf_id number Identifier of target buffer.
---@param items table Array of items to show.
---@param query table Array of strings representing query.
---@param opts table|nil Options. Possible fields:
---   - <show_icons> `(boolean)` - whether to show icons for entries recognized as
---     valid actually present paths on disk (see |MiniPick-source.items-common|),
---     empty space otherwise.
---     Default: `false`. Note: |MiniPick.builtin| pickers showing file/directory
---     paths use `true` by default.
---   - <icons> `(table)` - table with fallback icons. Can have fields:
---       - <directory> `(string)` - icon for directory. Default: " ".
---       - <file> `(string)` - icon for file. Default: " ".
---       - <none> `(string)` - icon for non-valid path. Default: "  ".
MiniPick.default_show = function(buf_id, items, query, opts)
  local default_icons = { directory = ' ', file = ' ', none = '  ' }
  opts = vim.tbl_deep_extend('force', { show_icons = false, icons = default_icons }, opts or {})

  -- Compute and set lines
  local lines = vim.tbl_map(H.item_to_string, items)
  local tab_spaces = string.rep(' ', vim.o.tabstop)
  lines = vim.tbl_map(function(l) return l:gsub('\n', ' '):gsub('\t', tab_spaces) end, lines)

  local get_prefix_data = opts.show_icons and function(line) return H.get_icon(line, opts.icons) end
    or function() return { text = '' } end
  local prefix_data = vim.tbl_map(get_prefix_data, lines)

  local lines_to_show = {}
  for i, l in ipairs(lines) do
    lines_to_show[i] = prefix_data[i].text .. l
  end

  H.set_buflines(buf_id, lines_to_show)

  -- Extract match ranges
  local ns_id = H.ns_id.ranges
  H.clear_namespace(buf_id, ns_id)

  if H.query_is_ignorecase(query) then
    lines, query = vim.tbl_map(H.tolower, lines), vim.tbl_map(H.tolower, query)
  end
  local match_data, match_type, query_adjusted = H.match_filter(H.seq_along(lines), lines, query)
  if match_data == nil then return end

  local match_ranges_fun = match_type == 'fuzzy' and H.match_ranges_fuzzy or H.match_ranges_exact
  local match_ranges = match_ranges_fun(match_data, query_adjusted, lines)

  -- Place range highlights accounting for possible shift due to prefixes
  local extmark_opts = { hl_group = 'MiniPickMatchRanges', hl_mode = 'combine', priority = 200 }
  for i = 1, #match_data do
    local row, ranges = match_data[i][3], match_ranges[i]
    local start_offset = prefix_data[row].text:len()
    for _, range in ipairs(ranges) do
      extmark_opts.end_row, extmark_opts.end_col = row - 1, start_offset + range[2]
      H.set_extmark(buf_id, ns_id, row - 1, start_offset + range[1] - 1, extmark_opts)
    end
  end

  -- Highlight prefixes
  if not opts.show_icons then return end
  local icon_extmark_opts = { hl_mode = 'combine', priority = 200 }
  for i = 1, #prefix_data do
    icon_extmark_opts.hl_group = prefix_data[i].hl
    icon_extmark_opts.end_row, icon_extmark_opts.end_col = i - 1, prefix_data[i].text:len()
    H.set_extmark(buf_id, ns_id, i - 1, 0, icon_extmark_opts)
  end
end

--- Default preview
---
--- Preview item. Logic follows the rules in |MiniPick-source.items-common|:
--- - File and buffer are shown at the start.
--- - Directory has its content listed.
--- - Line/position/region in file or buffer is shown at start.
--- - Others are shown directly with |vim.inspect()|.
---
--- Implements default value for |MiniPick-source.preview|.
---
--- Uses the following highlight groups (see |MiniPick| for their description):
---
--- * `MiniPickPreviewLine`
--- * `MiniPickPreviewRegion`
---
---@param buf_id number Identifier of target buffer.
---@param item any Item to preview.
---@param opts table|nil Options. Possible values:
---   - <n_context_lines> `(number)` - number of lines to load past target position
---     when reading from disk. Useful to explore context. Default: 'lines' twice.
---   - <line_position> `(string)` - where in the window to show item position.
---     One of "top", "center", "bottom". Default: "top".
MiniPick.default_preview = function(buf_id, item, opts)
  opts = vim.tbl_deep_extend('force', { n_context_lines = 2 * vim.o.lines, line_position = 'top' }, opts or {})
  local item_data = H.parse_item(item)
  if item_data.type == 'file' then return H.preview_file(buf_id, item_data, opts) end
  if item_data.type == 'directory' then return H.preview_directory(buf_id, item_data) end
  if item_data.type == 'buffer' then return H.preview_buffer(buf_id, item_data, opts) end
  H.preview_inspect(buf_id, item)
end

--- Default choose
---
--- Choose item. Logic follows the rules in |MiniPick-source.items-common|:
--- - File and directory are called with |:edit| in the target window, possibly
---   followed by setting cursor at the start of line/position/region.
--- - Buffer is set as current in target window.
--- - Others have the output of |vim.inspect()| printed in Command line.
---
--- Implements default value for |MiniPick-source.choose|.
---
---@param item any Item to choose.
MiniPick.default_choose = function(item)
  if item == nil then return end
  local picker_state = MiniPick.get_picker_state()
  local win_target = picker_state ~= nil and picker_state.windows.target or vim.api.nvim_get_current_win()
  if not H.is_valid_win(win_target) then win_target = H.get_first_valid_normal_window() end

  local item_data = H.parse_item(item)
  if item_data.type == 'file' or item_data.type == 'directory' then return H.choose_path(win_target, item_data) end
  if item_data.type == 'buffer' then return H.choose_buffer(win_target, item_data) end
  H.choose_print(item)
end

--- Default choose marked items
---
--- Choose marked items. Logic follows the rules in |MiniPick-source.items-common|:
--- - If among items there is at least one file or buffer, quickfix list is opened
---   with all file or buffer lines/positions/regions.
--- - Otherwise, picker's `source.choose` is called on the first item.
---
--- Implements default value for |MiniPick-source.choose_marked|.
---
---@param items table Array of items to choose.
---@param opts table|nil Options. Possible fields:
---   - <list_type> `(string)` - which type of list to open. One of "quickfix"
---     or "location". Default: "quickfix".
MiniPick.default_choose_marked = function(items, opts)
  if not vim.tbl_islist(items) then H.error('`items` should be an array') end
  if #items == 0 then return end
  opts = vim.tbl_deep_extend('force', { list_type = 'quickfix' }, opts or {})

  -- Construct a potential quickfix/location list
  local list = {}
  for _, item in ipairs(items) do
    local item_data = H.parse_item(item)
    if item_data.type == 'file' or item_data.type == 'buffer' then
      local entry = { bufnr = item_data.buf_id, filename = item_data.path }
      entry.lnum, entry.col, entry.text = item_data.lnum or 1, item_data.col or 1, item_data.text or ''
      entry.end_lnum, entry.end_col = item_data.end_lnum, item_data.end_col
      table.insert(list, entry)
    end
  end

  -- Fall back to choosing first item if no quickfix list was constructed
  local is_active = MiniPick.is_picker_active()
  if #list == 0 then
    if not is_active then return end
    local choose = MiniPick.get_picker_opts().source.choose
    return choose(items[1])
  end

  -- Set as quickfix or location list
  local title = '<No picker>'
  if is_active then
    ---@diagnostic disable:param-type-mismatch
    local source_name, prompt = MiniPick.get_picker_opts().source.name, table.concat(MiniPick.get_picker_query())
    title = source_name .. (prompt == '' and '' or (' : ' .. prompt))
  end
  local list_data = { items = list, title = title, nr = '$' }

  if opts.list_type == 'location' then
    local win_target = MiniPick.get_picker_state().windows.target
    if not H.is_valid_win(win_target) then win_target = H.get_first_valid_normal_window() end
    vim.fn.setloclist(win_target, {}, ' ', list_data)
    vim.schedule(function() vim.cmd('lopen') end)
  else
    vim.fn.setqflist({}, ' ', list_data)
    vim.schedule(function() vim.cmd('copen') end)
  end
end

--- Select rewrite
---
--- Function which can be used to directly override |vim.ui.select()| to use
--- 'mini.pick' for any "select" type of tasks.
---
--- Implements the required by `vim.ui.select()` signature. Plus allows extra
--- `opts.preview_item` to serve as preview.
---
--- Notes:
--- - `on_choice` is called when target window is current.
MiniPick.ui_select = function(items, opts, on_choice)
  local format_item = opts.format_item or H.item_to_string
  local items_ext = {}
  for i = 1, #items do
    table.insert(items_ext, { text = format_item(items[i]), item = items[i], index = i })
  end

  local preview_item = vim.is_callable(opts.preview_item) and opts.preview_item
    or function(x) return vim.split(vim.inspect(x), '\n') end
  local preview = function(buf_id, item) H.set_buflines(buf_id, preview_item(item.item)) end

  local was_aborted = true
  local choose = function(item)
    was_aborted = false
    if item == nil then return end
    local win_target = MiniPick.get_picker_state().windows.target
    if not H.is_valid_win(win_target) then win_target = H.get_first_valid_normal_window() end
    vim.api.nvim_win_call(win_target, function()
      on_choice(item.item, item.index)
      MiniPick.set_picker_target_window(vim.api.nvim_get_current_win())
    end)
  end

  local source = { items = items_ext, name = opts.prompt or opts.kind, preview = preview, choose = choose }
  local item = MiniPick.start({ source = source })
  if item == nil and was_aborted then on_choice(nil) end
end

--- Table with built-in pickers
MiniPick.builtin = {}

--- Pick from files
---
--- Lists all files recursively in all subdirectories. Tries to use one of the
--- CLI tools to create items (see |MiniPick-cli-tools|): `rg`, `fd`, `git`.
--- If none is present, uses fallback which utilizes |vim.fs.dir()|.
---
--- To customize CLI tool search, either use tool's global configuration approach
--- or directly |MiniPick.builtin.cli()| with specific command.
---
---@param local_opts __pick_builtin_local_opts
---   Possible fields:
---   - <tool> `(string)` - which tool to use. One of "rg", "fd", "git", "fallback".
---     Default: whichever tool is present, trying in that same order.
---@param opts __pick_builtin_opts
MiniPick.builtin.files = function(local_opts, opts)
  local_opts = vim.tbl_deep_extend('force', { tool = nil }, local_opts or {})
  local tool = local_opts.tool or H.files_get_tool()
  local show = H.get_config().source.show or H.show_with_icons
  local default_opts = { source = { name = string.format('Files (%s)', tool), show = show } }
  opts = vim.tbl_deep_extend('force', default_opts, opts or {})

  if tool == 'fallback' then
    opts.source.items = function() H.files_fallback_items(opts.source.cwd) end
    return MiniPick.start(opts)
  end

  local postprocess = function(lines)
    local res = H.cli_postprocess(lines)
    -- Correctly process files with `:` without sacrificing much performance
    for i = 1, #res do
      if res[i]:find(':') ~= nil then res[i] = { path = res[i], text = res[i] } end
    end
    return res
  end
  return MiniPick.builtin.cli({ command = H.files_get_command(tool), postprocess = postprocess }, opts)
end

--- Pick from pattern matches
---
--- Lists all pattern matches recursively in all subdirectories.
--- Tries to use one of the CLI tools to create items (see |MiniPick-cli-tools|):
--- `rg`, `git`. If none is present, uses fallback which utilizes |vim.fs.dir()| and
--- Lua pattern matches (NOT recommended in large directories).
---
--- To customize CLI tool search, either use tool's global configuration approach
--- or directly |MiniPick.builtin.cli()| with specific command.
---
---@param local_opts __pick_builtin_local_opts
---   Possible fields:
---   - <tool> `(string)` - which tool to use. One of "rg", "git", "fallback".
---     Default: whichever tool is present, trying in that same order.
---   - <pattern> `(string)` - string pattern to search. If not given, asks user
---     interactively with |input()|.
---@param opts __pick_builtin_opts
MiniPick.builtin.grep = function(local_opts, opts)
  local_opts = vim.tbl_deep_extend('force', { tool = nil, pattern = nil }, local_opts or {})
  local tool = local_opts.tool or H.grep_get_tool()
  local show = H.get_config().source.show or H.show_with_icons
  local default_opts = { source = { name = string.format('Grep (%s)', tool), show = show } }
  opts = vim.tbl_deep_extend('force', default_opts, opts or {})

  local pattern = type(local_opts.pattern) == 'string' and local_opts.pattern or vim.fn.input('Grep pattern: ')
  if tool == 'fallback' then
    opts.source.items = function() H.grep_fallback_items(pattern, opts.source.cwd) end
    return MiniPick.start(opts)
  end

  return MiniPick.builtin.cli({ command = H.grep_get_command(tool, pattern) }, opts)
end

--- Pick from pattern matches with live feedback
---
--- Perform pattern matching treating prompt as pattern. Gives live feedback on
--- which matches are found. Use |MiniPick-actions-refine| to revert to regular
--- matching.
--- Tries to use one of the CLI tools to create items (see |MiniPick-cli-tools|):
--- `rg`, `git`. If none is present, error is thrown (for performance reasons).
---
--- To customize search, use tool's global configuration approach.
---
---@param local_opts __pick_builtin_local_opts
---   Possible fields:
---   - <tool> `(string)` - which tool to use. One of "rg", "git".
---     Default: whichever tool is present, trying in that same order.
---@param opts __pick_builtin_opts
MiniPick.builtin.grep_live = function(local_opts, opts)
  local_opts = vim.tbl_deep_extend('force', { tool = nil }, local_opts or {})
  local tool = local_opts.tool or H.grep_get_tool()
  if tool == 'fallback' or not H.is_executable(tool) then H.error('`grep_live` needs non-fallback executable tool.') end

  local show = H.get_config().source.show or H.show_with_icons
  local default_opts = { source = { name = string.format('Grep live (%s)', tool), show = show } }
  opts = vim.tbl_deep_extend('force', default_opts, opts or {})

  local set_items_opts, spawn_opts = { do_match = false, querytick = H.querytick }, { cwd = opts.source.cwd }
  local process
  local match = function(_, _, query)
    pcall(vim.loop.process_kill, process)
    if H.querytick == set_items_opts.querytick then return end
    if #query == 0 then return MiniPick.set_picker_items({}, set_items_opts) end

    set_items_opts.querytick = H.querytick
    local command = H.grep_get_command(tool, table.concat(query))
    process = MiniPick.set_picker_items_from_cli(command, { set_items_opts = set_items_opts, spawn_opts = spawn_opts })
  end

  opts = vim.tbl_deep_extend('force', opts or {}, { source = { items = {}, match = match } })
  return MiniPick.start(opts)
end

--- Pick from help tags
---
--- Notes:
--- - On choose executes |:help| command with appropriate modifier
---   (|:horizontal|, |:vertical|, |:tab|) due to the effect of custom mappings.
---
---@param local_opts __pick_builtin_local_opts
---   Not used at the moment.
---@param opts __pick_builtin_opts
MiniPick.builtin.help = function(local_opts, opts)
  -- Get all tags
  local help_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[help_buf].buftype = 'help'
  local tags = vim.api.nvim_buf_call(help_buf, function() return vim.fn.taglist('.*') end)
  vim.api.nvim_buf_delete(help_buf, { force = true })
  vim.tbl_map(function(t) t.text = t.name end, tags)

  -- NOTE: Choosing is done on next event loop to properly overcome special
  -- nature of `:help {subject}` command. For example, it didn't quite work
  -- when choosing tags in same file consecutively.
  local choose = function(item, modifier)
    if item == nil then return end
    vim.schedule(function() vim.cmd((modifier or '') .. 'help ' .. (item.name or '')) end)
  end
  local preview = function(buf_id, item)
    -- Take advantage of `taglist` output on how to open tag
    vim.api.nvim_buf_call(buf_id, function()
      vim.cmd('noautocmd edit ' .. vim.fn.fnameescape(item.filename))
      vim.bo.buftype, vim.bo.buflisted, vim.bo.bufhidden = 'nofile', false, 'wipe'
      local has_ts = pcall(vim.treesitter.start, 0)
      if not has_ts then vim.bo.syntax = 'help' end

      local cache_hlsearch = vim.v.hlsearch
      -- Make a "very nomagic" search to account for special characters in tag
      local search_cmd = string.gsub(item.cmd, '^/', '/\\V')
      vim.cmd('silent keeppatterns ' .. search_cmd)
      -- Here `vim.v` doesn't work: https://github.com/neovim/neovim/issues/25294
      vim.cmd('let v:hlsearch=' .. cache_hlsearch)
      vim.cmd('normal! zt')
    end)
  end

  -- Modify default mappings to work with special `:help` command
  local map_custom = function(char, modifier)
    local f = function()
      choose(MiniPick.get_picker_matches().current, modifier .. ' ')
      return true
    end
    return { char = char, func = f }
  end

  --stylua: ignore
  local mappings = {
    choose_in_split   = '', show_help_in_split   = map_custom('<C-s>', ''),
    choose_in_vsplit  = '', show_help_in_vsplit  = map_custom('<C-v>', 'vertical'),
    choose_in_tabpage = '', show_help_in_tabpage = map_custom('<C-t>', 'tab'),
  }

  local source = { items = tags, name = 'Help', choose = choose, preview = preview }
  opts = vim.tbl_deep_extend('force', { source = source, mappings = mappings }, opts or {})
  return MiniPick.start(opts)
end

--- Pick from buffers
---
--- Notes:
--- - There are not built-in mappings for buffer manipulation. Here is an example
---   of how to call this function with mapping to wipeout the current item: >
---
---   local wipeout_cur = function()
---     vim.api.nvim_buf_delete(MiniPick.get_picker_matches().current.bufnr, {})
---   end
---   local buffer_mappings = { wipeout = { char = '<C-d>', func = wipeout_cur } }
---   MiniPick.builtin.buffers(local_opts, { mappings = buffer_mappings })
---
---@param local_opts __pick_builtin_local_opts
---   Possible fields:
---   - <include_current> `(boolean)` - whether to include current buffer in
---     the output. Default: `true`.
---   - <include_unlisted> `(boolean)` - whether to include |unlisted-buffer|s in
---     the output. Default: `false`.
---@param opts __pick_builtin_opts
MiniPick.builtin.buffers = function(local_opts, opts)
  local_opts = vim.tbl_deep_extend('force', { include_current = true, include_unlisted = false }, local_opts or {})

  local buffers_output = vim.api.nvim_exec('buffers' .. (local_opts.include_unlisted and '!' or ''), true)
  local cur_buf_id, include_current = vim.api.nvim_get_current_buf(), local_opts.include_current
  local items = {}
  for _, l in ipairs(vim.split(buffers_output, '\n')) do
    local buf_str, name = l:match('^%s*%d+'), l:match('"(.*)"')
    local buf_id = tonumber(buf_str)
    local item = { text = name, bufnr = buf_id }
    if buf_id ~= cur_buf_id or include_current then table.insert(items, item) end
  end

  local show = H.get_config().source.show or H.show_with_icons
  local default_opts = { source = { name = 'Buffers', show = show } }
  opts = vim.tbl_deep_extend('force', default_opts, opts or {}, { source = { items = items } })
  return MiniPick.start(opts)
end

--- Pick from CLI output
---
--- Executes command line tool and constructs items based on its output.
--- Uses |MiniPick.set_picker_items_from_cli()|.
---
--- Example: `MiniPick.builtin.cli({ command = { 'echo', 'a\nb\nc' } })`
---
---@param local_opts __pick_builtin_local_opts
---   Possible fields:
---   - <command> `(table)` - forwarded to `set_picker_items_from_cli()`.
---   - <postprocess> `(function)` - forwarded to `set_picker_items_from_cli()`.
---   - <spawn_opts> `(table)` - forwarded to `set_picker_items_from_cli()`.
---     Note: if `cwd` field is absent, it is inferred from |MiniPick-source.cwd|.
---@param opts __pick_builtin_opts
MiniPick.builtin.cli = function(local_opts, opts)
  local_opts = vim.tbl_deep_extend('force', { command = {}, postprocess = nil, spawn_opts = {} }, local_opts or {})
  local name = string.format('CLI (%s)', tostring(local_opts.command[1] or ''))
  opts = vim.tbl_deep_extend('force', { source = { name = name } }, opts or {})
  local_opts.spawn_opts.cwd = local_opts.spawn_opts.cwd or opts.source.cwd

  local command = local_opts.command
  local set_from_cli_opts = { postprocess = local_opts.postprocess, spawn_opts = local_opts.spawn_opts }
  opts.source.items = vim.schedule_wrap(function() MiniPick.set_picker_items_from_cli(command, set_from_cli_opts) end)
  return MiniPick.start(opts)
end

--- Resume latest picker
MiniPick.builtin.resume = function()
  local picker = H.pickers.latest
  if picker == nil then H.error('There is no picker to resume.') end

  H.cache = {}
  local buf_id = H.picker_new_buf()
  local win_target = vim.api.nvim_get_current_win()
  local win_id = H.picker_new_win(buf_id, picker.opts.window.config)
  picker.buffers = { main = buf_id }
  picker.windows = { main = win_id, target = win_target }
  picker.view_state = 'main'
  H.pickers.active = picker

  return H.picker_advance(picker)
end

--- Picker registry
---
--- Place for users and extensions to manage pickers with their commonly used
--- global options. By default contains all |MiniPick.builtin| entries.
---
--- Serves as a source for |:Pick| command.
---
--- Customization examples: >
---
---   -- Adding custom picker to pick `register` entries
---   MiniPick.registry.registry = function()
---     local items = vim.tbl_keys(MiniPick.registry)
---     table.sort(items)
---     local source = {items = items, name = 'Registry', choose = function() end}
---     local chosen_picker_name = MiniPick.start({ source = source })
---     if chosen_picker_name == nil then return end
---     return MiniPick.registry[chosen_picker_name]()
---   end
---
---   -- Make `:Pick files` accept `cwd`
---   MiniPick.registry.files = function(local_opts)
---     local opts = { source = { cwd = local_opts.cwd } }
---     local_opts.cwd = nil
---     return MiniPick.builtin.files(local_opts, opts)
---   end
MiniPick.registry = {}

for name, f in pairs(MiniPick.builtin) do
  MiniPick.registry[name] = function(local_opts) return f(local_opts) end
end

if type(MiniExtra) == 'table' then
  for name, f in pairs(MiniExtra.pickers) do
    MiniPick.registry[name] = function(local_opts) return f(local_opts) end
  end
end

--- Get items of active picker
---
---@return table|nil Picker items or `nil` if no active picker.
---
---@seealso |MiniPick.set_picker_items()| and |MiniPick.set_picker_items_from_cli()|
MiniPick.get_picker_items = function() return vim.deepcopy((H.pickers.active or {}).items) end

--- Get stritems of active picker
---
---@return table|nil Picker stritems (|MiniPick-source.items-stritems|) or `nil` if
---   no active picker.
---
---@seealso |MiniPick.set_picker_items()| and |MiniPick.set_picker_items_from_cli()|
MiniPick.get_picker_stritems = function() return vim.deepcopy((H.pickers.active or {}).stritems) end

--- Get matches of active picker
---
---@return table|nil Picker matches or `nil` if no active picker. Matches is a table
---   with the following fields:
---   - <all> `(table|nil)` - all currently matched items.
---   - <all_inds> `(table|nil)` - indexes of all currently matched items.
---   - <current> `(any)` - current matched item.
---   - <current_ind> `(number|nil)` - index of current matched item.
---   - <marked> `(table|nil)` - marked items.
---   - <marked_inds> `(table|nil)` - indexes of marked items.
---
---@seealso |MiniPick.set_picker_match_inds()|
MiniPick.get_picker_matches = function()
  if not MiniPick.is_picker_active() then return end
  local picker = H.pickers.active
  local items = picker.items
  if items == nil or #items == 0 then return {} end

  local res = { all_inds = vim.deepcopy(picker.match_inds), current_ind = picker.match_inds[picker.current_ind] }
  res.all = vim.tbl_map(function(ind) return items[ind] end, picker.match_inds)
  res.current = picker.items[res.current_ind]
  local marked_inds = vim.tbl_keys(picker.marked_inds_map)
  table.sort(marked_inds)
  res.marked_inds, res.marked = marked_inds, vim.tbl_map(function(ind) return items[ind] end, marked_inds)
  return res
end

--- Get config of active picker
---
---@return table|nil Picker config (`start()`'s input `opts` table) or `nil` if
---   no active picker.
---
---@seealso |MiniPick.set_picker_opts()|
MiniPick.get_picker_opts = function() return vim.deepcopy((H.pickers.active or {}).opts) end

--- Get state data of active picker
---
---@return table|nil Table with picker state data or `nil` if no active picker.
---   State data is a table with the following fields:
---   - <buffers> `(table)` - table with `main`, `preview`, `info` fields representing
---     buffer identifier (or `nil`) for corresponding view.
---   - <windows> `(table)` - table with `main` and `target` fields representing
---     window identifiers for main and target windows.
---   - <caret> `(number)` - caret column.
---   - <is_bust> `(boolean)` - whether picker is busy with computations.
---
---@seealso |MiniPick.set_picker_target_window()|
MiniPick.get_picker_state = function()
  if not MiniPick.is_picker_active() then return end
  local picker = H.pickers.active
  --stylua: ignore
  return vim.deepcopy({
    buffers = picker.buffers, windows = picker.windows, caret = picker.caret, is_busy = picker.is_busy
  })
end

--- Get query of active picker
---
---@return table|nil Array of picker query or `nil` if no active picker.
---
---@seealso |MiniPick.set_picker_query()|
MiniPick.get_picker_query = function() return vim.deepcopy((H.pickers.active or {}).query) end

--- Set items for active picker
---
--- Note: sets items asynchronously in non-blocking fashion.
---
---@param items table Array of items.
---@param opts table|nil Options. Possible fields:
---   - <do_match> `(boolean)` - whether to perform match after setting items.
---     Default: `true`.
---   - <querytick> `(number|nil)` - value of querytick (|MiniPick.get_querytick()|)
---     to periodically check against when setting items. If checked querytick
---     differs from supplied, no items are set.
---
---@seealso |MiniPick.get_picker_items()| and |MiniPick.get_picker_stritems()|
MiniPick.set_picker_items = function(items, opts)
  if not vim.tbl_islist(items) then H.error('`items` should be an array.') end
  if not MiniPick.is_picker_active() then return end
  opts = vim.tbl_deep_extend('force', { do_match = true, querytick = nil }, opts or {})

  -- Set items in async because computing lower `stritems` can block much time
  coroutine.wrap(H.picker_set_items)(H.pickers.active, items, opts)
end

--- Set items for active picker based on CLI output
---
--- Asynchronously executes `command` and sets items to its postprocessed output.
---
--- Example: >
---   local items = vim.schedule_wrap(function()
---     MiniPick.set_picker_items_from_cli({ 'echo', 'a\nb\nc' })
---   end)
---   MiniPick.start({ source = { items = items, name = 'Echo abc' } })
---
---@param command table Array with (at least one) string command parts.
---@param opts table|nil Options. Possible fields:
---   - <postprocess> `(function)` - callable performing postprocessing of output.
---     Will be called with array of lines as input, should return array of items.
---     Default: removes trailing empty lines and uses rest as string items.
---   - <spawn_opts> `(table)` - `options` for |uv.spawn|, except `args` and `stdio` fields.
---   - <set_items_opts> `(table)` - table forwarded to |MiniPick.set_picker_items()|.
---
---@seealso |MiniPick.get_picker_items()| and |MiniPick.get_picker_stritems()|
MiniPick.set_picker_items_from_cli = function(command, opts)
  if not MiniPick.is_picker_active() then return end
  local is_valid_command = H.is_array_of(command, 'string') and #command >= 1
  if not is_valid_command then H.error('`command` should be an array of strings.') end
  local default_opts = { postprocess = H.cli_postprocess, set_items_opts = {}, spawn_opts = {} }
  opts = vim.tbl_deep_extend('force', default_opts, opts or {})

  local executable, args = command[1], vim.list_slice(command, 2, #command)
  local process, pid, stdout = nil, nil, vim.loop.new_pipe()
  local spawn_opts = vim.tbl_deep_extend('force', opts.spawn_opts, { args = args, stdio = { nil, stdout, nil } })
  if type(spawn_opts.cwd) == 'string' then spawn_opts.cwd = H.full_path(spawn_opts.cwd) end
  process, pid = vim.loop.spawn(executable, spawn_opts, function() process:close() end)

  local data_feed = {}
  stdout:read_start(function(err, data)
    assert(not err, err)
    if data ~= nil then return table.insert(data_feed, data) end

    local items = vim.split(table.concat(data_feed), '\n')
    data_feed = nil
    stdout:close()
    vim.schedule(function() MiniPick.set_picker_items(opts.postprocess(items), opts.set_items_opts) end)
  end)

  return process, pid
end

--- Set match indexes for active picker
---
--- This is intended to be used inside custom asynchronous |MiniPick-source.match|
--- implementations. See |MiniPick.poke_is_picker_active()| for an example.
---
---@param match_inds table Array of numbers indicating which elements of picker's
---   stritems match the query.
---
---@seealso |MiniPick.get_picker_matches()|
MiniPick.set_picker_match_inds = function(match_inds)
  if not MiniPick.is_picker_active() then return end
  if not H.is_array_of(match_inds, 'number') then H.error('`match_inds` should be an array of numbers.') end
  H.picker_set_match_inds(H.pickers.active, match_inds)
  H.picker_update(H.pickers.active, false)
end

--- Set config for active picker
---
---@param opts table Table overriding initial `opts` input of |MiniPick.start()|.
---
---@seealso |MiniPick.get_picker_opts()|
MiniPick.set_picker_opts = function(opts)
  if not MiniPick.is_picker_active() then return end
  H.pickers.active.opts = vim.tbl_deep_extend('force', H.pickers.active.opts, opts or {})
  H.picker_update(H.pickers.active, true, true)
end

--- Set target window for active picker
---
---@param win_id number Valid window identifier to be used as the new target window.
---
---@seealso |MiniPick.get_picker_state()|
MiniPick.set_picker_target_window = function(win_id)
  if not MiniPick.is_picker_active() then return end
  if not H.is_valid_win(win_id) then H.error('`win_id` is not a valid window identifier.') end
  H.pickers.active.windows.target = win_id
end

--- Set query for active picker
---
---@param query table Array of strings to be set as the new picker query.
---
---@seealso |MiniPick.get_picker_query()|
MiniPick.set_picker_query = function(query)
  if not MiniPick.is_picker_active() then return end
  if not H.is_array_of(query, 'string') then H.error('`query` should be an array of strings.') end

  H.pickers.active.query, H.pickers.active.caret = query, #query + 1
  H.querytick = H.querytick + 1
  H.pickers.active.match_inds = H.seq_along(MiniPick.get_picker_items())
  H.picker_update(H.pickers.active, true)
end

--- Get query tick
---
--- Query tick is a unique query identifier. Intended to be used to detect user
--- activity during and between |MiniPick.start()| calls for efficient non-blocking
--- functionality. Updates after any query change, picker start and stop.
---
--- See |MiniPick.poke_is_picker_active()| for usage example.
---
---@return number Query tick.
MiniPick.get_querytick = function() return H.querytick end

--- Check if there is an active picker
---
---@return boolean Whether there is currently an active picker.
---
---@seealso |MiniPick.poke_is_picker_active()|
MiniPick.is_picker_active = function() return H.pickers.active ~= nil end

--- Poke if picker is active
---
--- Intended to be used for non-blocking implementation of source methods.
--- Returns an output of |MiniPick.is_picker_active()|, but depending on
--- whether there is a coroutine running:
--- - If no, return it immediately.
--- - If yes, return it after `coroutine.yield()` with `coroutine.resume()`
---   called "soon" by the main event-loop (see |vim.schedule()|).
---
--- Example of non-blocking exact `match` (as demo; can be optimized further): >
---
---   local match_nonblock = function(match_inds, stritems, query)
---     local prompt, querytick = table.concat(query), MiniPick.get_querytick()
---     local f = function()
---       local res = {}
---       for _, ind in ipairs(match_inds) do
---         local should_stop = not MiniPick.poke_is_picker_active() or
---           MiniPick.get_querytick() ~= querytick
---         if should_stop then return end
---
---         if stritems[ind]:find(prompt) ~= nil then table.insert(res, ind) end
---       end
---
---       MiniPick.set_picker_match_inds(res)
---     end
---
---     coroutine.resume(coroutine.create(f))
---   end
---
---@return boolean Whether there is an active picker.
---
---@seealso |MiniPick.is_picker_active()|
MiniPick.poke_is_picker_active = function()
  local co = coroutine.running()
  if co == nil then return MiniPick.is_picker_active() end
  H.schedule_resume_is_active(co)
  return coroutine.yield()
end

-- Helper data ================================================================
-- Module default config
H.default_config = vim.deepcopy(MiniPick.config)

-- Namespaces
H.ns_id = {
  matches = vim.api.nvim_create_namespace('MiniPickMatches'),
  headers = vim.api.nvim_create_namespace('MiniPickHeaders'),
  preview = vim.api.nvim_create_namespace('MiniPickPreview'),
  ranges = vim.api.nvim_create_namespace('MiniPickRanges'),
}

-- Timers
H.timers = {
  busy = vim.loop.new_timer(),
  focus = vim.loop.new_timer(),
  getcharstr = vim.loop.new_timer(),
}

-- Pickers
H.pickers = { active = nil, latest = nil }

-- Picker-independent counter of query updates
H.querytick = 0

-- General purpose cache
H.cache = {}

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({
    delay = { config.delay, 'table' },
    mappings = { config.mappings, 'table' },
    options = { config.options, 'table' },
    source = { config.source, 'table' },
    window = { config.window, 'table' },
  })

  local is_table_or_callable = function(x) return x == nil or type(x) == 'table' or vim.is_callable(x) end
  vim.validate({
    ['delay.async'] = { config.delay.async, 'number' },
    ['delay.busy'] = { config.delay.busy, 'number' },

    ['mappings.caret_left'] = { config.mappings.caret_left, 'string' },
    ['mappings.caret_right'] = { config.mappings.caret_right, 'string' },
    ['mappings.choose'] = { config.mappings.choose, 'string' },
    ['mappings.choose_in_split'] = { config.mappings.choose_in_split, 'string' },
    ['mappings.choose_in_tabpage'] = { config.mappings.choose_in_tabpage, 'string' },
    ['mappings.choose_in_vsplit'] = { config.mappings.choose_in_vsplit, 'string' },
    ['mappings.choose_marked'] = { config.mappings.choose_marked, 'string' },
    ['mappings.delete_char'] = { config.mappings.delete_char, 'string' },
    ['mappings.delete_char_right'] = { config.mappings.delete_char_right, 'string' },
    ['mappings.delete_left'] = { config.mappings.delete_left, 'string' },
    ['mappings.delete_word'] = { config.mappings.delete_word, 'string' },
    ['mappings.mark'] = { config.mappings.mark, 'string' },
    ['mappings.mark_all'] = { config.mappings.mark_all, 'string' },
    ['mappings.move_down'] = { config.mappings.move_down, 'string' },
    ['mappings.move_start'] = { config.mappings.move_start, 'string' },
    ['mappings.move_up'] = { config.mappings.move_up, 'string' },
    ['mappings.paste'] = { config.mappings.paste, 'string' },
    ['mappings.refine'] = { config.mappings.refine, 'string' },
    ['mappings.refine_marked'] = { config.mappings.refine_marked, 'string' },
    ['mappings.scroll_down'] = { config.mappings.scroll_down, 'string' },
    ['mappings.scroll_up'] = { config.mappings.scroll_up, 'string' },
    ['mappings.scroll_left'] = { config.mappings.scroll_left, 'string' },
    ['mappings.scroll_right'] = { config.mappings.scroll_right, 'string' },
    ['mappings.stop'] = { config.mappings.stop, 'string' },
    ['mappings.toggle_info'] = { config.mappings.toggle_info, 'string' },
    ['mappings.toggle_preview'] = { config.mappings.toggle_preview, 'string' },

    ['options.content_from_bottom'] = { config.options.content_from_bottom, 'boolean' },
    ['options.use_cache'] = { config.options.use_cache, 'boolean' },

    ['source.items'] = { config.source.items, 'table', true },
    ['source.name'] = { config.source.name, 'string', true },
    ['source.cwd'] = { config.source.cwd, 'string', true },
    ['source.match'] = { config.source.match, 'function', true },
    ['source.show'] = { config.source.show, 'function', true },
    ['source.preview'] = { config.source.preview, 'function', true },
    ['source.choose'] = { config.source.choose, 'function', true },
    ['source.choose_marked'] = { config.source.choose_marked, 'function', true },

    ['window.config'] = { config.window.config, is_table_or_callable, 'table or callable' },
    ['window.prompt_cursor'] = { config.window.prompt_cursor, 'string' },
    ['window.prompt_prefix'] = { config.window.prompt_prefix, 'string' },
  })

  return config
end

H.apply_config = function(config) MiniPick.config = config end

H.get_config = function(config)
  return vim.tbl_deep_extend('force', MiniPick.config, vim.b.minipick_config or {}, config or {})
end

H.create_autocommands = function(config)
  local augroup = vim.api.nvim_create_augroup('MiniPick', {})

  local au = function(event, pattern, callback, desc)
    vim.api.nvim_create_autocmd(event, { group = augroup, pattern = pattern, callback = callback, desc = desc })
  end

  au('VimResized', '*', MiniPick.refresh, 'Refresh on resize')
end

--stylua: ignore
H.create_default_hl = function()
  local hi = function(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end

  hi('MiniPickBorder',        { link = 'FloatBorder' })
  hi('MiniPickBorderBusy',    { link = 'DiagnosticFloatingWarn' })
  hi('MiniPickBorderText',    { link = 'FloatTitle' })
  hi('MiniPickIconDirectory', { link = 'Directory' })
  hi('MiniPickIconFile',      { link = 'MiniPickNormal' })
  hi('MiniPickHeader',        { link = 'DiagnosticFloatingHint' })
  hi('MiniPickMatchCurrent',  { link = 'CursorLine' })
  hi('MiniPickMatchMarked',   { link = 'Visual' })
  hi('MiniPickMatchRanges',   { link = 'DiagnosticFloatingHint' })
  hi('MiniPickNormal',        { link = 'NormalFloat' })
  hi('MiniPickPreviewLine',   { link = 'CursorLine' })
  hi('MiniPickPreviewRegion', { link = 'IncSearch' })
  hi('MiniPickPrompt',        { link = 'DiagnosticFloatingInfo' })
end

H.create_user_commands = function()
  local callback = function(input)
    local name, local_opts = H.command_parse_fargs(input.fargs)
    local f = MiniPick.registry[name]
    if f == nil then H.error(string.format('There is no picker named "%s" in registry.', name)) end
    f(local_opts)
  end
  local opts = { nargs = '+', complete = H.command_complete, desc = "Pick from 'mini.pick' registry" }
  vim.api.nvim_create_user_command('Pick', callback, opts)
end

-- Command --------------------------------------------------------------------
H.command_parse_fargs = function(fargs)
  local name, opts_parts = fargs[1], vim.tbl_map(H.expandcmd, vim.list_slice(fargs, 2, #fargs))
  local tbl_string = string.format('{ %s }', table.concat(opts_parts, ', '))
  local lua_load = loadstring('return ' .. tbl_string)
  if lua_load == nil then H.error('Could not convert extra command arguments to table: ' .. tbl_string) end
  return name, lua_load()
end

H.command_complete = function(_, line, col)
  local prefix_from, prefix_to, prefix = string.find(line, '^%S+%s+(%S*)')
  if col < prefix_from or prefix_to < col then return {} end
  local candidates = vim.tbl_filter(
    function(x) return tostring(x):find(prefix, 1, true) ~= nil end,
    vim.tbl_keys(MiniPick.registry)
  )
  table.sort(candidates)
  return candidates
end

-- Picker object --------------------------------------------------------------
H.validate_picker_opts = function(opts)
  opts = opts or {}
  if type(opts) ~= 'table' then H.error('Picker options should be table.') end

  opts = vim.deepcopy(H.get_config(opts))

  local validate_callable = function(x, x_name)
    if not vim.is_callable(x) then H.error(string.format('`%s` should be callable.', x_name)) end
  end

  -- Source
  local source = opts.source

  local items = source.items or {}
  local is_valid_items = vim.tbl_islist(items) or vim.is_callable(items)
  if not is_valid_items then H.error('`source.items` should be array or callable.') end

  source.name = tostring(source.name or '<No name>')

  if type(source.cwd) == 'string' then source.cwd = H.full_path(source.cwd) end
  if source.cwd == nil then source.cwd = vim.fn.getcwd() end
  if vim.fn.isdirectory(source.cwd) == 0 then H.error('`source.cwd` should be a valid directory path.') end

  source.match = source.match or MiniPick.default_match
  validate_callable(source.match, 'source.match')

  source.show = source.show or MiniPick.default_show
  validate_callable(source.show, 'source.show')

  source.preview = source.preview or MiniPick.default_preview
  validate_callable(source.preview, 'source.preview')

  source.choose = source.choose or MiniPick.default_choose
  validate_callable(source.choose, 'source.choose')

  source.choose_marked = source.choose_marked or MiniPick.default_choose_marked
  validate_callable(source.choose_marked, 'source.choose_marked')

  -- Delay
  for key, value in pairs(opts.delay) do
    local is_valid_value = type(value) == 'number' and value > 0
    if not is_valid_value then H.error(string.format('`delay.%s` should be a positive number.', key)) end
  end

  -- Mappings
  local default_mappings = H.default_config.mappings
  for field, x in pairs(opts.mappings) do
    if type(field) ~= 'string' then H.error('`mappings` should have only string fields.') end
    local is_builtin_action = default_mappings[field] ~= nil
    if is_builtin_action and type(x) ~= 'string' then
      H.error(string.format('Mapping for built-in action "%s" should be string.', field))
    end
    if not is_builtin_action and not (type(x) == 'table' and type(x.char) == 'string' and vim.is_callable(x.func)) then
      H.error(string.format('Mapping for custom action "%s" should be table with `char` and `func`.', field))
    end
  end

  -- Options
  local options = opts.options
  if type(options.content_from_bottom) ~= 'boolean' then H.error('`options.content_from_bottom` should be boolean.') end
  if type(options.use_cache) ~= 'boolean' then H.error('`options.use_cache` should be boolean.') end

  -- Window
  local win_config = opts.window.config
  local is_valid_winconfig = win_config == nil or type(win_config) == 'table' or vim.is_callable(win_config)
  if not is_valid_winconfig then H.error('`window.config` should be table or callable.') end

  return opts
end

H.picker_new = function(opts)
  -- Create buffer
  local buf_id = H.picker_new_buf()

  -- Create window
  local win_target = vim.api.nvim_get_current_win()
  local win_id = H.picker_new_win(buf_id, opts.window.config)

  -- Construct and return object
  local picker = {
    -- Permanent data about picker (should not change)
    opts = opts,

    -- Items to pick from
    items = nil,
    stritems = nil,
    stritems_ignorecase = nil,

    -- Associated Neovim objects
    buffers = { main = buf_id, preview = nil, info = nil },
    windows = { main = win_id, target = win_target },

    -- Query data
    query = {},
    -- - Query index at which new entry will be inserted
    caret = 1,
    -- - Array of `stritems` indexes matching current query
    match_inds = nil,
    -- - Map of of currently marked `stritems` indexes (as keys)
    marked_inds_map = {},

    -- Whether picker is currently busy processing data
    is_busy = false,

    -- Cache for `matches` per prompt for more performant querying
    cache = {},

    -- View data
    -- - Which buffer should currently be shown
    view_state = 'main',

    -- - Index range of `match_inds` currently visible. Present for significant
    --   performance increase to render only what is visible.
    visible_range = { from = nil, to = nil },

    -- - Index of `match_inds` pointing at current item
    current_ind = nil,
  }

  H.querytick = H.querytick + 1

  return picker
end

H.picker_advance = function(picker)
  vim.schedule(function() vim.api.nvim_exec_autocmds('User', { pattern = 'MiniPickStart' }) end)

  local char_data = H.picker_get_char_data(picker)

  local do_match, is_aborted = false, false
  for _ = 1, 1000000 do
    if H.cache.is_force_stop_advance then break end
    H.picker_update(picker, do_match)

    local char = H.getcharstr(picker.opts.delay.async)
    if H.cache.is_force_stop_advance then break end

    is_aborted = char == nil
    if is_aborted then break end

    local cur_data = char_data[char] or {}
    do_match = cur_data.name == nil or vim.startswith(cur_data.name, 'delete') or cur_data.name == 'paste'
    is_aborted = cur_data.name == 'stop'

    local should_stop
    if cur_data.is_custom then
      should_stop = cur_data.func()
    else
      should_stop = (cur_data.func or H.picker_query_add)(picker, char)
    end
    if should_stop then break end
  end

  local item
  if not is_aborted then item = H.picker_get_current_item(picker) end
  H.cache.is_force_stop_advance = nil
  H.picker_stop(picker)
  return item
end

H.picker_update = function(picker, do_match, update_window)
  if do_match then H.picker_match(picker) end
  if update_window then
    local config = H.picker_compute_win_config(picker.opts.window.config)
    vim.api.nvim_win_set_config(picker.windows.main, config)
    H.picker_set_current_ind(picker, picker.current_ind, true)
  end
  H.picker_set_bordertext(picker)
  H.picker_set_lines(picker)
  H.redraw()
end

H.picker_new_buf = function()
  local buf_id = H.create_scratch_buf()
  vim.bo[buf_id].filetype = 'minipick'
  return buf_id
end

H.picker_new_win = function(buf_id, win_config)
  -- Focus cursor on Command line to not see it
  if vim.fn.mode() == 'n' then
    H.cache.cmdheight = vim.o.cmdheight
    vim.o.cmdheight = 1
    vim.cmd('noautocmd normal! :')
  end
  -- Create window and focus on it
  local win_id = vim.api.nvim_open_win(buf_id, true, H.picker_compute_win_config(win_config, true))

  -- Set window-local data
  vim.wo[win_id].foldenable = false
  vim.wo[win_id].list = true
  vim.wo[win_id].listchars = 'extends:…'
  vim.wo[win_id].scrolloff = 0
  vim.wo[win_id].wrap = false
  H.win_update_hl(win_id, 'NormalFloat', 'MiniPickNormal')
  H.win_update_hl(win_id, 'FloatBorder', 'MiniPickBorder')
  vim.fn.clearmatches(win_id)

  return win_id
end

H.picker_compute_win_config = function(win_config, is_for_open)
  local has_tabline = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  local has_statusline = vim.o.laststatus > 0
  local max_height = vim.o.lines - vim.o.cmdheight - (has_tabline and 1 or 0) - (has_statusline and 1 or 0)
  local max_width = vim.o.columns

  local default_config = {
    relative = 'editor',
    anchor = 'SW',
    width = math.floor(0.618 * max_width),
    height = math.floor(0.618 * max_height),
    col = 0,
    row = max_height + (has_tabline and 1 or 0),
    border = 'single',
    style = 'minimal',
    noautocmd = is_for_open,
  }
  local config = vim.tbl_deep_extend('force', default_config, H.expand_callable(win_config) or {})

  -- Tweak config values to ensure they are proper
  if config.border == 'none' then config.border = { '', ' ', '', '', '', ' ', '', '' } end
  -- - Account for border
  config.height = math.min(config.height, max_height - 2)
  config.width = math.min(config.width, max_width - 2)

  return config
end

H.picker_track_lost_focus = function(picker)
  local track = vim.schedule_wrap(function()
    local is_cur_win = vim.api.nvim_get_current_win() == picker.windows.main
    local is_proper_focus = is_cur_win and (H.cache.is_in_getcharstr or vim.fn.mode() ~= 'n')
    if is_proper_focus then return end
    H.picker_stop(picker, true)
  end)
  H.timers.focus:start(1000, 1000, track)
end

H.picker_set_items = function(picker, items, opts)
  -- Compute string items to work with (along with their lower variants)
  local stritems, stritems_ignorecase, tolower = {}, {}, H.tolower
  local poke_picker = H.poke_picker_throttle(opts.querytick)
  for i, x in ipairs(items) do
    if not poke_picker() then return end
    local to_add = H.item_to_string(x)
    table.insert(stritems, to_add)
    table.insert(stritems_ignorecase, tolower(to_add))
  end

  picker.items, picker.stritems, picker.stritems_ignorecase = items, stritems, stritems_ignorecase
  picker.cache, picker.marked_inds_map = {}, {}
  H.picker_set_busy(picker, false)

  H.picker_set_match_inds(picker, H.seq_along(items))
  H.picker_update(picker, opts.do_match)
end

H.item_to_string = function(item)
  item = H.expand_callable(item)
  if type(item) == 'string' then return item end
  if type(item) == 'table' and type(item.text) == 'string' then return item.text end
  return vim.inspect(item, { newline = ' ', indent = '' })
end

H.picker_set_busy = function(picker, value)
  picker.is_busy = value

  -- NOTE: Don't precompute highlight group to always set a valid one
  local update_border_hl = function()
    H.timers.busy:stop()
    H.win_update_hl(picker.windows.main, 'FloatBorder', picker.is_busy and 'MiniPickBorderBusy' or 'MiniPickBorder')
  end

  if value then return H.timers.busy:start(picker.opts.delay.busy, 0, vim.schedule_wrap(update_border_hl)) end
  update_border_hl()
end

H.picker_set_match_inds = function(picker, inds)
  if inds == nil then return end
  H.picker_set_busy(picker, false)

  picker.match_inds = inds

  local cache_prompt = table.concat(picker.query)
  if picker.opts.options.use_cache then picker.cache[cache_prompt] = { inds = inds } end

  -- Always show result of updated matches
  H.picker_show_main(picker)

  -- Reset current index if match indexes are updated
  H.picker_set_current_ind(picker, 1)
end

H.picker_set_current_ind = function(picker, ind, force_update)
  if picker.items == nil or #picker.match_inds == 0 then
    picker.current_ind, picker.visible_range = nil, {}
    return
  end

  -- Wrap index around edges
  local n_matches = #picker.match_inds
  ind = (ind - 1) % n_matches + 1

  -- (Re)Compute visible range (centers current index if it is currently outside)
  local from, to, querytick = picker.visible_range.from, picker.visible_range.to, picker.visible_range.querytick
  local needs_update = H.querytick ~= querytick or from == nil or to == nil or not (from <= ind and ind <= to)
  if (force_update or needs_update) and H.is_valid_win(picker.windows.main) then
    local win_height = vim.api.nvim_win_get_height(picker.windows.main)
    to = math.min(n_matches, math.floor(ind + 0.5 * win_height))
    from = math.max(1, to - win_height + 1)
    to = from + math.min(win_height, n_matches) - 1
  end

  -- Set data
  picker.current_ind = ind
  picker.visible_range = { from = from, to = to, querytick = H.querytick }
end

H.picker_set_lines = function(picker)
  local buf_id, win_id = picker.buffers.main, picker.windows.main
  if not (H.is_valid_buf(buf_id) and H.is_valid_win(win_id)) then return end

  if picker.is_busy then return end

  local visible_range, query = picker.visible_range, picker.query
  if picker.items == nil or visible_range.from == nil or visible_range.to == nil then
    picker.opts.source.show(buf_id, {}, query)
    H.clear_namespace(buf_id, H.ns_id.matches)
    return
  end

  -- Construct target items
  local items_to_show, items, match_inds = {}, picker.items, picker.match_inds
  local cur_ind, cur_line = picker.current_ind, nil
  local marked_inds_map, marked_lnums = picker.marked_inds_map, {}
  local is_from_bottom = picker.opts.options.content_from_bottom
  local from = is_from_bottom and visible_range.to or visible_range.from
  local to = is_from_bottom and visible_range.from or visible_range.to
  for i = from, to, (from <= to and 1 or -1) do
    table.insert(items_to_show, items[match_inds[i]])
    if i == cur_ind then cur_line = #items_to_show end
    if marked_inds_map[match_inds[i]] then table.insert(marked_lnums, #items_to_show) end
  end

  local n_empty_top_lines = is_from_bottom and (vim.api.nvim_win_get_height(win_id) - #items_to_show) or 0
  cur_line = cur_line + n_empty_top_lines
  marked_lnums = vim.tbl_map(function(x) return x + n_empty_top_lines end, marked_lnums)

  -- Update visible lines accounting for "from_bottom" direction
  picker.opts.source.show(buf_id, items_to_show, query)
  if n_empty_top_lines > 0 then
    local empty_lines = vim.fn['repeat']({ '' }, n_empty_top_lines)
    vim.api.nvim_buf_set_lines(buf_id, 0, 0, true, empty_lines)
  end

  local ns_id = H.ns_id.matches
  H.clear_namespace(buf_id, ns_id)

  -- Add highlighting for marked lines
  local marked_opts = { end_col = 0, hl_group = 'MiniPickMatchMarked', priority = 202 }
  for _, lnum in ipairs(marked_lnums) do
    marked_opts.end_row = lnum
    H.set_extmark(buf_id, ns_id, lnum - 1, 0, marked_opts)
  end

  -- Update current item
  if cur_line > vim.api.nvim_buf_line_count(buf_id) then return end

  local cur_opts = { end_row = cur_line, end_col = 0, hl_eol = true, hl_group = 'MiniPickMatchCurrent', priority = 201 }
  H.set_extmark(buf_id, ns_id, cur_line - 1, 0, cur_opts)

  -- - Update cursor if showing item matches (needed for 'scroll_{left,right}')
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  if picker.view_state == 'main' and cursor[1] ~= cur_line then H.set_cursor(win_id, cur_line, cursor[2] + 1) end
end

H.picker_match = function(picker)
  if picker.items == nil then return end

  -- Try to use cache first
  local prompt_cache
  if picker.opts.options.use_cache then prompt_cache = picker.cache[table.concat(picker.query)] end
  if prompt_cache ~= nil then return H.picker_set_match_inds(picker, prompt_cache.inds) end

  local is_ignorecase = H.query_is_ignorecase(picker.query)
  local stritems = is_ignorecase and picker.stritems_ignorecase or picker.stritems
  local query = is_ignorecase and vim.tbl_map(H.tolower, picker.query) or picker.query

  H.picker_set_busy(picker, true)
  local new_inds = picker.opts.source.match(stritems, picker.match_inds, query)
  H.picker_set_match_inds(picker, new_inds)
end

H.query_is_ignorecase = function(query)
  if not vim.o.ignorecase then return false end
  if not vim.o.smartcase then return true end
  local prompt = table.concat(query)
  return prompt == vim.fn.tolower(prompt)
end

H.picker_get_char_data = function(picker, skip_alternatives)
  local term = H.replace_termcodes
  local res = {}

  -- Use alternative keys for some common actions
  local alt_chars = {}
  if not skip_alternatives then alt_chars = { move_down = '<Down>', move_start = '<Home>', move_up = '<Up>' } end

  -- Process
  for name, rhs in pairs(picker.opts.mappings) do
    local is_custom = type(rhs) == 'table'
    local char = is_custom and rhs.char or rhs
    local data = { char = char, name = name, func = is_custom and rhs.func or H.actions[name], is_custom = is_custom }
    res[term(char)] = data

    local alt = alt_chars[name]
    if alt ~= nil then res[term(alt)] = data end
  end

  return res
end

H.picker_set_bordertext = function(picker)
  local opts = picker.opts
  local win_id = picker.windows.main
  if not H.is_valid_win(win_id) then return end

  -- Compute main text managing views separately and truncating from left
  local view_state = picker.view_state
  local config
  if view_state == 'main' then
    local query, caret = picker.query, picker.caret
    local before_caret = table.concat(vim.list_slice(query, 1, caret - 1), '')
    local after_caret = table.concat(vim.list_slice(query, caret, #query), '')
    local prompt_text = opts.window.prompt_prefix .. before_caret .. opts.window.prompt_cursor .. after_caret
    local prompt = { { H.win_trim_to_width(win_id, prompt_text), 'MiniPickPrompt' } }
    config = { title = prompt }
  end

  local has_items = picker.items ~= nil
  if view_state == 'preview' and has_items then
    local stritem_cur = picker.stritems[picker.match_inds[picker.current_ind]] or ''
    -- Sanitize title
    stritem_cur = stritem_cur:gsub('[%s%z]', ' ')
    config = { title = { { H.win_trim_to_width(win_id, stritem_cur), 'MiniPickBorderText' } } }
  end

  if view_state == 'info' then
    config = { title = { { H.win_trim_to_width(win_id, 'Info'), 'MiniPickBorderText' } } }
  end

  -- Compute helper footer only if Neovim version permits and not in busy
  -- picker (otherwise it will flicker number of matches data on char delete)
  local nvim_has_window_footer = vim.fn.has('nvim-0.10') == 1
  if nvim_has_window_footer and not picker.is_busy then
    config.footer, config.footer_pos = H.picker_compute_footer(picker, win_id), 'left'
  end

  -- Respect `options.content_from_bottom`
  if nvim_has_window_footer and opts.options.content_from_bottom then
    config.title, config.footer = config.footer, config.title
  end

  vim.api.nvim_win_set_config(win_id, config)
  vim.wo[win_id].list = true
end

-- - No border text functionality is available in Neovim<0.9
if vim.fn.has('nvim-0.9') == 0 then H.picker_set_bordertext = function() end end

H.picker_compute_footer = function(picker, win_id)
  local info = H.picker_get_general_info(picker)
  local source_name = string.format(' %s ', info.source_name)
  local n_marked_text = info.n_marked == 0 and '' or (info.n_marked .. '/')
  local inds = string.format(' %s|%s|%s%s ', info.relative_current_ind, info.n_matched, n_marked_text, info.n_total)
  local win_width, source_width, inds_width =
    vim.api.nvim_win_get_width(win_id), vim.fn.strchars(source_name), vim.fn.strchars(inds)

  local footer = { { source_name, 'MiniPickBorderText' } }
  local n_spaces_between = win_width - (source_width + inds_width)
  if n_spaces_between > 0 then
    local border_hl = picker.is_busy and 'MiniPickBorderBusy' or 'MiniPickBorder'
    footer[2] = { H.win_get_bottom_border(win_id):rep(n_spaces_between), border_hl }
    footer[3] = { inds, 'MiniPickBorderText' }
  end
  return footer
end

H.picker_stop = function(picker, abort)
  vim.tbl_map(function(timer) pcall(vim.loop.timer_stop, timer) end, H.timers)
  pcall(function() vim.o.cmdheight = H.cache.cmdheight end)

  if picker == nil then return end

  vim.api.nvim_exec_autocmds('User', { pattern = 'MiniPickStop' })

  if abort then
    H.pickers = {}
  else
    local new_latest = vim.deepcopy(picker)
    H.picker_free(H.pickers.latest)
    H.pickers = { active = nil, latest = new_latest }
  end

  H.set_curwin(picker.windows.target)
  pcall(vim.api.nvim_win_close, picker.windows.main, true)
  pcall(vim.api.nvim_buf_delete, picker.buffers.main, { force = true })
  pcall(vim.api.nvim_buf_delete, picker.buffers.info, { force = true })
  picker.windows, picker.buffers = {}, {}

  H.querytick = H.querytick + 1
end

H.picker_free = function(picker)
  if picker == nil then return end
  picker.match_inds = nil
  picker.cache = nil
  picker.stritems, picker.stritems_ignorecase, picker.marked_inds_map = nil, nil, nil
  picker.items = nil
  picker = nil
  vim.schedule(function() collectgarbage('collect') end)
end

--stylua: ignore
H.actions = {
  caret_left  = function(picker, _) H.picker_move_caret(picker, -1) end,
  caret_right = function(picker, _) H.picker_move_caret(picker, 1)  end,

  choose            = function(picker, _) return H.picker_choose(picker, nil)      end,
  choose_in_split   = function(picker, _) return H.picker_choose(picker, 'split')  end,
  choose_in_tabpage = function(picker, _) return H.picker_choose(picker, 'tabnew') end,
  choose_in_vsplit  = function(picker, _) return H.picker_choose(picker, 'vsplit') end,
  choose_marked     = function(picker, _) return not picker.opts.source.choose_marked(MiniPick.get_picker_matches().marked) end,

  delete_char       = function(picker, _) H.picker_query_delete(picker, 1)                end,
  delete_char_right = function(picker, _) H.picker_query_delete(picker, 0)                end,
  delete_left       = function(picker, _) H.picker_query_delete(picker, picker.caret - 1) end,
  delete_word = function(picker, _)
    local init, n_del = picker.caret - 1, 0
    if init == 0 then return end
    local ref_is_keyword = vim.fn.match(picker.query[init], '[[:keyword:]]') >= 0
    for i = init, 1, -1 do
      local cur_is_keyword = vim.fn.match(picker.query[i], '[[:keyword:]]') >= 0
      if (ref_is_keyword and not cur_is_keyword) or (not ref_is_keyword and cur_is_keyword) then break end
      n_del = n_del + 1
    end
    H.picker_query_delete(picker, n_del)
  end,

  mark     = function(picker, _) H.picker_mark_indexes(picker, 'current') end,
  mark_all = function(picker, _) H.picker_mark_indexes(picker, 'all') end,

  move_down  = function(picker, _) H.picker_move_current(picker, 1)  end,
  move_start = function(picker, _) H.picker_move_current(picker, nil, 1)  end,
  move_up    = function(picker, _) H.picker_move_current(picker, -1) end,

  paste = function(picker, _)
    local register = H.getcharstr(picker.opts.delay.async)
    local has_register, reg_contents = pcall(vim.fn.getreg, register)
    if not has_register then return end
    reg_contents = reg_contents:gsub('[\n\t]', ' ')
    for i = 1, vim.fn.strchars(reg_contents) do
      H.picker_query_add(picker, vim.fn.strcharpart(reg_contents, i - 1, 1))
    end
  end,

  refine        = function(picker, _) H.picker_refine(picker, 'all') end,
  refine_marked = function(picker, _) H.picker_refine(picker, 'marked') end,

  scroll_down  = function(picker, _) H.picker_scroll(picker, 'down')  end,
  scroll_up    = function(picker, _) H.picker_scroll(picker, 'up')    end,
  scroll_left  = function(picker, _) H.picker_scroll(picker, 'left')  end,
  scroll_right = function(picker, _) H.picker_scroll(picker, 'right') end,

  toggle_info = function(picker, _)
    if picker.view_state == 'info' then return H.picker_show_main(picker) end
    H.picker_show_info(picker)
  end,

  toggle_preview = function(picker, _)
    if picker.view_state == 'preview' then return H.picker_show_main(picker) end
    H.picker_show_preview(picker)
  end,

  stop = function(_, _) return true end,
}

H.picker_query_add = function(picker, char)
  -- Determine if it **is** proper single character
  if vim.fn.strchars(char) > 1 or vim.fn.char2nr(char) <= 31 then return end
  table.insert(picker.query, picker.caret, char)
  picker.caret = picker.caret + 1
  H.querytick = H.querytick + 1

  -- Adding character inside query might not result into narrowing matches, so
  -- reset match indexes. Use cache to speed this up.
  local should_reset = picker.items ~= nil and picker.caret <= #picker.query
  if should_reset then picker.match_inds = H.seq_along(picker.items) end
end

H.picker_query_delete = function(picker, n)
  local delete_to_left = n > 0
  local left = delete_to_left and math.max(picker.caret - n, 1) or picker.caret
  local right = delete_to_left and picker.caret - 1 or math.min(picker.caret + n, #picker.query)
  for i = right, left, -1 do
    table.remove(picker.query, i)
  end
  picker.caret = left
  H.querytick = H.querytick + 1

  -- Deleting query character increases number of possible matches, so need to
  -- reset already matched indexes prior deleting. Use cache to speed this up.
  if picker.items ~= nil then picker.match_inds = H.seq_along(picker.items) end
end

H.picker_choose = function(picker, pre_command)
  local cur_item = H.picker_get_current_item(picker)
  if cur_item == nil then return true end

  local win_id_target = picker.windows.target
  if pre_command ~= nil and H.is_valid_win(win_id_target) then
    vim.api.nvim_win_call(win_id_target, function()
      vim.cmd(pre_command)
      picker.windows.target = vim.api.nvim_get_current_win()
    end)
  end

  -- Returning nothing, `nil`, or `false` should lead to picker stop
  return not picker.opts.source.choose(cur_item)
end

H.picker_mark_indexes = function(picker, range_type)
  if picker.items == nil then return end
  local test_inds = range_type == 'current' and { picker.match_inds[picker.current_ind] } or picker.match_inds

  -- Mark if not all marked, unmark otherwise
  local marked_inds_map, is_all_marked = picker.marked_inds_map, true
  for _, ind in ipairs(test_inds) do
    is_all_marked = is_all_marked and marked_inds_map[ind]
  end

  -- NOTE: Set to `nil` and not `false` for easier counting of present values
  local new_val
  if not is_all_marked then new_val = true end
  for _, ind in ipairs(test_inds) do
    marked_inds_map[ind] = new_val
  end

  if picker.view_state == 'info' then H.picker_show_info(picker) end
end

H.picker_move_caret = function(picker, n) picker.caret = math.min(math.max(picker.caret + n, 1), #picker.query + 1) end

H.picker_move_current = function(picker, by, to)
  if picker.items == nil then return end
  local n_matches = #picker.match_inds
  if n_matches == 0 then return end

  if to == nil then
    -- Account for content direction
    by = (picker.opts.options.content_from_bottom and -1 or 1) * by

    -- Wrap around edges only if current index is at edge
    to = picker.current_ind
    if to == 1 and by < 0 then
      to = n_matches
    elseif to == n_matches and by > 0 then
      to = 1
    else
      to = to + by
    end
    to = math.min(math.max(to, 1), n_matches)
  end

  H.picker_set_current_ind(picker, to)

  -- Update not main buffer(s)
  if picker.view_state == 'info' then H.picker_show_info(picker) end
  if picker.view_state == 'preview' then H.picker_show_preview(picker) end
end

H.picker_refine = function(picker, refine_type)
  if picker.items == nil then return end

  -- Make current matches be new items to be matched with default match
  picker.opts.source.match = H.get_config().source.match or MiniPick.default_match
  picker.query, picker.caret = {}, 1
  MiniPick.set_picker_items(MiniPick.get_picker_matches()[refine_type] or {})

  picker._refine = picker._refine or { orig_name = picker.opts.source.name, count = 0 }
  picker._refine.count = picker._refine.count + 1
  local count_suffix = picker._refine.count == 1 and '' or (' ' .. picker._refine.count)
  picker.opts.source.name = string.format('%s (Refine%s)', picker._refine.orig_name, count_suffix)
end

H.picker_scroll = function(picker, direction)
  local win_id = picker.windows.main
  if picker.view_state == 'main' and (direction == 'down' or direction == 'up') then
    local n = (direction == 'down' and 1 or -1) * vim.api.nvim_win_get_height(win_id)
    H.picker_move_current(picker, n)
  else
    local keys = ({ down = '<C-f>', up = '<C-b>', left = 'zH', right = 'zL' })[direction]
    vim.api.nvim_win_call(win_id, function() vim.cmd('normal! ' .. H.replace_termcodes(keys)) end)
  end
end

H.picker_get_current_item = function(picker)
  if picker.items == nil then return nil end
  return picker.items[picker.match_inds[picker.current_ind]]
end

H.picker_show_main = function(picker)
  H.set_winbuf(picker.windows.main, picker.buffers.main)
  picker.view_state = 'main'
end

H.picker_show_info = function(picker)
  -- General information
  local info = H.picker_get_general_info(picker)
  local lines = {
    'General',
    'Source name   │ ' .. info.source_name,
    'Source cwd    │ ' .. info.source_cwd,
    'Total items   │ ' .. info.n_total,
    'Matched items │ ' .. info.n_matched,
    'Marked items  │ ' .. info.n_marked,
    'Current index │ ' .. info.relative_current_ind,
  }
  local hl_lines = { 1 }

  local append_char_data = function(data, header)
    if #data == 0 then return end
    table.insert(lines, '')
    table.insert(lines, header)
    table.insert(hl_lines, #lines)

    local width_max = 0
    for _, t in ipairs(data) do
      local desc = t.name:gsub('[%s%p]', ' ')
      t.desc = vim.fn.toupper(desc:sub(1, 1)) .. desc:sub(2)
      t.width = vim.fn.strchars(t.desc)
      width_max = math.max(width_max, t.width)
    end
    table.sort(data, function(a, b) return a.desc < b.desc end)

    for _, t in ipairs(data) do
      table.insert(lines, string.format('%s%s │ %s', t.desc, string.rep(' ', width_max - t.width), t.char))
    end
  end

  local char_data = H.picker_get_char_data(picker, true)
  append_char_data(vim.tbl_filter(function(x) return x.is_custom end, char_data), 'Mappings (custom)')
  append_char_data(vim.tbl_filter(function(x) return not x.is_custom end, char_data), 'Mappings (built-in)')

  -- Manage buffer/window/state
  local buf_id_info = picker.buffers.info
  if not H.is_valid_buf(buf_id_info) then buf_id_info = H.create_scratch_buf() end
  picker.buffers.info = buf_id_info

  H.set_buflines(buf_id_info, lines)
  H.set_winbuf(picker.windows.main, buf_id_info)
  picker.view_state = 'info'

  local ns_id = H.ns_id.headers
  H.clear_namespace(buf_id_info, ns_id)
  for _, lnum in ipairs(hl_lines) do
    H.set_extmark(buf_id_info, ns_id, lnum - 1, 0, { end_row = lnum, end_col = 0, hl_group = 'MiniPickHeader' })
  end
end

H.picker_get_general_info = function(picker)
  local has_items = picker.items ~= nil
  return {
    source_name = picker.opts.source.name or '---',
    source_cwd = vim.fn.fnamemodify(picker.opts.source.cwd, ':~') or '---',
    n_total = has_items and #picker.items or '-',
    n_matched = has_items and #picker.match_inds or '-',
    n_marked = has_items and vim.tbl_count(picker.marked_inds_map) or '-',
    relative_current_ind = has_items and picker.current_ind or '-',
  }
end

H.picker_show_preview = function(picker)
  local preview = picker.opts.source.preview
  local item = H.picker_get_current_item(picker)
  if item == nil then return end

  local win_id, buf_id = picker.windows.main, H.create_scratch_buf()
  vim.bo[buf_id].bufhidden = 'wipe'
  H.set_winbuf(win_id, buf_id)
  preview(buf_id, item)
  picker.buffers.preview = buf_id
  picker.view_state = 'preview'
end

-- Default match --------------------------------------------------------------
H.match_filter = function(inds, stritems, query)
  -- 'abc' and '*abc' - fuzzy; "'abc" and 'a' - exact substring;
  -- 'ab c' - grouped fuzzy; '^abc' and 'abc$' - exact substring at start/end.
  local is_fuzzy_forced, is_exact_plain, is_exact_start, is_exact_end =
    query[1] == '*', query[1] == "'", query[1] == '^', query[#query] == '$'
  local is_grouped, grouped_parts = H.match_query_group(query)

  if is_fuzzy_forced or is_exact_plain or is_exact_start or is_exact_end then
    local start_offset = (is_fuzzy_forced or is_exact_plain or is_exact_start) and 2 or 1
    local end_offset = #query - ((not is_fuzzy_forced and not is_exact_plain and is_exact_end) and 1 or 0)
    query = vim.list_slice(query, start_offset, end_offset)
  elseif is_grouped then
    query = grouped_parts
  end

  if #query == 0 then return {}, 'nosort', query end

  local is_fuzzy_plain = not (is_exact_plain or is_exact_start or is_exact_end) and #query > 1
  if is_fuzzy_forced or is_fuzzy_plain then return H.match_filter_fuzzy(inds, stritems, query), 'fuzzy', query end

  local prefix = is_exact_start and '^' or ''
  local suffix = is_exact_end and '$' or ''
  local pattern = prefix .. vim.pesc(table.concat(query)) .. suffix

  return H.match_filter_exact(inds, stritems, query, pattern), 'exact', query
end

H.match_filter_exact = function(inds, stritems, query, pattern)
  local match_single = H.match_filter_exact_single
  local poke_picker = H.poke_picker_throttle(H.querytick)
  local match_data = {}
  for _, ind in ipairs(inds) do
    if not poke_picker() then return nil end
    local data = match_single(stritems[ind], ind, pattern)
    if data ~= nil then table.insert(match_data, data) end
  end

  return match_data
end

H.match_filter_exact_single = function(candidate, index, pattern)
  local start = string.find(candidate, pattern)
  if start == nil then return nil end

  return { 0, start, index }
end

H.match_ranges_exact = function(match_data, query)
  -- All matches have same match ranges relative to match start
  local cur_start, rel_ranges = 0, {}
  for i = 1, #query do
    rel_ranges[i] = { cur_start, cur_start + query[i]:len() - 1 }
    cur_start = rel_ranges[i][2] + 1
  end

  local res = {}
  for i = 1, #match_data do
    local start = match_data[i][2]
    res[i] = vim.tbl_map(function(x) return { start + x[1], start + x[2] } end, rel_ranges)
  end

  return res
end

H.match_filter_fuzzy = function(inds, stritems, query)
  local match_single, find_query = H.match_filter_fuzzy_single, H.match_find_query
  local poke_picker = H.poke_picker_throttle(H.querytick)
  local match_data = {}
  for _, ind in ipairs(inds) do
    if not poke_picker() then return nil end
    local data = match_single(stritems[ind], ind, query, find_query)
    if data ~= nil then table.insert(match_data, data) end
  end
  return match_data
end

H.match_filter_fuzzy_single = function(candidate, index, query, find_query)
  -- Search for query chars match positions with the following properties:
  -- - All are present in `candidate` in the same order.
  -- - Has smallest width among all such match positions.
  -- - Among same width has smallest first match.

  -- Search forward to find matching positions with left-most last char match
  local first, last = find_query(candidate, query, 1)
  if first == nil then return nil end
  if first == last then return { 0, first, index, { first } } end

  -- NOTE: This approach doesn't iterate **all** query matches. It is fine for
  -- width optimization but maybe not for more (like contiguous groups number).
  -- Example: for query {'a', 'b', 'c'} candidate 'aaxbbbc' will be matched as
  -- having 3 groups (indexes 2, 4, 7) but correct one is 2 groups (2, 6, 7).

  -- Iteratively try to find better matches by advancing last match
  local best_first, best_last, best_width = first, last, last - first
  while last do
    local width = last - first
    if width < best_width then
      best_first, best_last, best_width = first, last, width
    end

    first, last = find_query(candidate, query, first + 1)
  end

  -- NOTE: No field names is not clear code, but consistently better performant
  return { best_last - best_first, best_first, index }
end

H.match_ranges_fuzzy = function(match_data, query, stritems)
  local res, n_query, query_lens = {}, #query, vim.tbl_map(string.len, query)
  for i_match, data in ipairs(match_data) do
    local s, from, to = stritems[data[3]], data[2], data[2] + query_lens[1] - 1
    local ranges = { { from, to } }
    for j_query = 2, n_query do
      from, to = string.find(s, query[j_query], to + 1, true)
      ranges[j_query] = { from, to }
    end
    res[i_match] = ranges
  end
  return res
end

H.match_find_query = function(s, query, init)
  local first, to = string.find(s, query[1], init, true)
  if first == nil then return nil, nil end

  -- Both `first` and `last` indicate the start byte of first and last match
  local last = first
  for i = 2, #query do
    last, to = string.find(s, query[i], to + 1, true)
    if not last then return nil, nil end
  end
  return first, last
end

H.match_query_group = function(query)
  local parts = { {} }
  for _, x in ipairs(query) do
    local is_whitespace = x:find('^%s+$') ~= nil
    if is_whitespace then table.insert(parts, {}) end
    if not is_whitespace then table.insert(parts[#parts], x) end
  end
  return #parts > 1, vim.tbl_map(table.concat, parts)
end

H.match_sort = function(match_data)
  -- Spread indexes in width-start buckets
  local buckets, max_width, width_max_start = {}, 0, {}
  for i = 1, #match_data do
    local data, width, start = match_data[i], match_data[i][1], match_data[i][2]
    local buck_width = buckets[width] or {}
    local buck_start = buck_width[start] or {}
    table.insert(buck_start, data[3])
    buck_width[start] = buck_start
    buckets[width] = buck_width

    max_width = math.max(max_width, width)
    width_max_start[width] = math.max(width_max_start[width] or 0, start)
  end

  -- Sort index in place (to make stable sort) within buckets
  local poke_picker = H.poke_picker_throttle(H.querytick)
  for _, buck_width in pairs(buckets) do
    for _, buck_start in pairs(buck_width) do
      if not poke_picker() then return nil end
      table.sort(buck_start)
    end
  end

  -- Gather indexes back in order
  local res = {}
  for width = 0, max_width do
    local buck_width = buckets[width]
    for start = 1, (width_max_start[width] or 0) do
      local buck_start = buck_width[start] or {}
      for i = 1, #buck_start do
        table.insert(res, buck_start[i])
      end
    end
  end

  return res
end

-- Default show ---------------------------------------------------------------
H.get_icon = function(x, icons)
  local path_type, path = H.parse_path(x)
  if path_type == nil then return { text = '' } end
  if path_type == 'directory' then return { text = icons.directory, hl = 'MiniPickIconDirectory' } end
  if path_type == 'none' then return { text = icons.none, hl = 'MiniPickNormal' } end
  local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
  if not has_devicons then return { text = icons.file, hl = 'MiniPickIconFile' } end

  local icon, hl = devicons.get_icon(vim.fn.fnamemodify(path, ':t'), nil, { default = false })
  icon = type(icon) == 'string' and (icon .. ' ') or icons.file
  return { text = icon, hl = hl or 'MiniPickIconFile' }
end

H.show_with_icons = function(buf_id, items, query) MiniPick.default_show(buf_id, items, query, { show_icons = true }) end

-- Items helpers for default functions ----------------------------------------
H.parse_item = function(item)
  -- Try parsing table item first
  if type(item) == 'table' then return H.parse_item_table(item) end

  -- Parse item's string representation
  local stritem = H.item_to_string(item)

  -- - Buffer
  local ok, numitem = pcall(tonumber, stritem)
  if ok and H.is_valid_buf(numitem) then return { type = 'buffer', buf_id = numitem } end

  -- File or Directory
  local path_type, path, lnum, col, rest = H.parse_path(stritem)
  if path_type ~= 'none' then return { type = path_type, path = path, lnum = lnum, col = col, text = rest } end

  return {}
end

H.parse_item_table = function(item)
  -- Buffer
  local buf_id = item.bufnr or item.buf_id or item.buf
  if H.is_valid_buf(buf_id) then
    --stylua: ignore
    return {
      type = 'buffer',  buf_id   = buf_id,
      lnum = item.lnum, end_lnum = item.end_lnum,
      col  = item.col,  end_col  = item.end_col,
      text = item.text,
    }
  end

  -- File or Directory
  if type(item.path) == 'string' then
    local path_type = H.get_fs_type(item.path)
    if path_type == 'file' then
      --stylua: ignore
      return {
        type = 'file',    path     = item.path,
        lnum = item.lnum, end_lnum = item.end_lnum,
        col  = item.col,  end_col  = item.end_col,
        text = item.text,
      }
    end

    if path_type == 'directory' then return { type = 'directory', path = item.path } end
  end

  return {}
end

H.parse_path = function(x)
  if type(x) ~= 'string' or x == '' then return nil end
  -- Allow inputs like 'aa/bb', 'aa/bb:10', 'aa/bb:10:5', 'aa/bb:10:5:xxx'
  -- Should also work for paths like 'aa-5'
  local location_pattern = ':(%d+):?(%d*):?(.*)$'
  local lnum, col, rest = x:match(location_pattern)
  local path = x:gsub(location_pattern, '', 1)
  path = path:sub(1, 1) == '~' and (vim.loop.os_homedir() or '~') .. path:sub(2) or path

  -- Verify that path is real
  local path_type = H.get_fs_type(path)
  if path_type == 'none' and path ~= '' then
    local cwd = H.pickers.active == nil and vim.fn.getcwd() or H.pickers.active.opts.source.cwd
    path = string.format('%s/%s', cwd, path)
    path_type = H.get_fs_type(path)
  end

  return path_type, path, tonumber(lnum), tonumber(col), rest or ''
end

H.get_fs_type = function(path)
  if path == '' then return 'none' end
  if vim.fn.filereadable(path) == 1 then return 'file' end
  if vim.fn.isdirectory(path) == 1 then return 'directory' end
  return 'none'
end

-- Default preview ------------------------------------------------------------
H.preview_file = function(buf_id, item_data, opts)
  -- Fully preview only text files
  if not H.is_file_text(item_data.path) then return H.set_buflines(buf_id, { '-Non-text-file-' }) end

  -- Compute lines. Limit number of read lines to work better on large files.
  local has_lines, lines = pcall(vim.fn.readfile, item_data.path, '', (item_data.lnum or 1) + opts.n_context_lines)
  if not has_lines then return end

  item_data.line_position = opts.line_position
  H.preview_set_lines(buf_id, lines, item_data)
end

H.preview_directory = function(buf_id, item_data)
  local path = item_data.path
  local format = function(x) return x .. (vim.fn.isdirectory(path .. '/' .. x) == 1 and '/' or '') end
  local lines = vim.tbl_map(format, vim.fn.readdir(path))
  H.set_buflines(buf_id, lines)
end

H.preview_buffer = function(buf_id, item_data, opts)
  -- NOTE: ideally just setting target buffer to window would be enough, but it
  -- has side effects. See https://github.com/neovim/neovim/issues/24973 .
  -- Reading lines and applying custom styling is a passable alternative.
  local buf_id_source = item_data.buf_id

  -- Get lines from buffer ensuring it is loaded without important consequences
  local cache_eventignore = vim.o.eventignore
  vim.o.eventignore = 'BufEnter'
  vim.fn.bufload(buf_id_source)
  vim.o.eventignore = cache_eventignore
  local lines = vim.api.nvim_buf_get_lines(buf_id_source, 0, (item_data.lnum or 1) + opts.n_context_lines, false)

  item_data.filetype, item_data.line_position = vim.bo[buf_id_source].filetype, opts.line_position
  H.preview_set_lines(buf_id, lines, item_data)
end

H.preview_inspect = function(buf_id, obj) H.set_buflines(buf_id, vim.split(vim.inspect(obj), '\n')) end

H.preview_set_lines = function(buf_id, lines, extra)
  -- Lines
  H.set_buflines(buf_id, lines)

  -- Highlighting
  H.preview_highlight_region(buf_id, extra.lnum, extra.col, extra.end_lnum, extra.end_col)

  if H.preview_should_highlight(buf_id) then
    local ft = extra.filetype or vim.filetype.match({ buf = buf_id, filename = extra.path })
    local has_lang, lang = pcall(vim.treesitter.language.get_lang, ft)
    local has_ts, _ = pcall(vim.treesitter.start, buf_id, has_lang and lang or ft)
    if not has_ts then vim.bo[buf_id].syntax = ft end
  end

  -- Cursor position and window view
  local state = MiniPick.get_picker_state()
  local win_id = state ~= nil and state.windows.main or vim.fn.bufwinid(buf_id)
  H.set_cursor(win_id, extra.lnum, extra.col)
  local pos_keys = ({ top = 'zt', center = 'zz', bottom = 'zb' })[extra.line_position] or 'zt'
  pcall(vim.api.nvim_win_call, win_id, function() vim.cmd('normal! ' .. pos_keys) end)
end

H.preview_should_highlight = function(buf_id)
  -- Neovim>=0.8 has more stable API
  if vim.fn.has('nvim-0.8') == 0 then return false end

  -- Highlight if buffer size is not too big, both in total and per line
  local buf_size = vim.api.nvim_buf_call(buf_id, function() return vim.fn.line2byte(vim.fn.line('$') + 1) end)
  return buf_size <= 1000000 and buf_size <= 1000 * vim.api.nvim_buf_line_count(buf_id)
end

H.preview_highlight_region = function(buf_id, lnum, col, end_lnum, end_col)
  -- Highlight line
  if lnum == nil then return end
  local hl_line_opts = { end_row = lnum, end_col = 0, hl_eol = true, hl_group = 'MiniPickPreviewLine', priority = 201 }
  H.set_extmark(buf_id, H.ns_id.preview, lnum - 1, 0, hl_line_opts)

  -- Highlight position/region
  if col == nil then return end

  local ext_end_row, ext_end_col = lnum - 1, col
  if end_lnum ~= nil and end_col ~= nil then
    ext_end_row, ext_end_col = end_lnum - 1, end_col - 1
  end
  ext_end_col = H.get_next_char_bytecol(vim.fn.getbufline(buf_id, ext_end_row + 1)[1], ext_end_col)

  local hl_region_opts = { end_row = ext_end_row, end_col = ext_end_col, priority = 202 }
  hl_region_opts.hl_group = 'MiniPickPreviewRegion'
  H.set_extmark(buf_id, H.ns_id.preview, lnum - 1, col - 1, hl_region_opts)
end

-- Default choose -------------------------------------------------------------
H.choose_path = function(win_target, item_data)
  -- Try to use already created buffer, if present. This avoids not needed
  -- `:edit` call and avoids some problems with auto-root from 'mini.misc'.
  local path, path_buf_id = item_data.path, nil
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local is_target = H.is_valid_buf(buf_id) and vim.bo[buf_id].buflisted and vim.api.nvim_buf_get_name(buf_id) == path
    if is_target then path_buf_id = buf_id end
  end

  -- Set buffer in target window
  if path_buf_id ~= nil then
    H.set_winbuf(win_target, path_buf_id)
  else
    -- Use relative path for a better initial view in `:buffers`
    local path_norm = vim.fn.fnameescape(vim.fn.fnamemodify(path, ':.'))
    -- Use `pcall()` to avoid possible `:edit` errors, like present swap file
    vim.api.nvim_win_call(win_target, function() pcall(vim.cmd, 'edit ' .. path_norm) end)
  end

  H.choose_set_cursor(win_target, item_data.lnum, item_data.col)
end

H.choose_buffer = function(win_target, item_data)
  H.set_winbuf(win_target, item_data.buf_id)
  H.choose_set_cursor(win_target, item_data.lnum, item_data.col)
end

H.choose_print = function(x) print(vim.inspect(x)) end

H.choose_set_cursor = function(win_id, lnum, col)
  if lnum == nil then return end
  H.set_cursor(win_id, lnum, col)
  pcall(vim.api.nvim_win_call, win_id, function() vim.cmd('normal! zvzz') end)
end

-- Builtins -------------------------------------------------------------------
H.cli_postprocess = function(items)
  while items[#items] == '' do
    items[#items] = nil
  end
  return items
end

H.is_executable = function(tool)
  if tool == 'fallback' then return true end
  return vim.fn.executable(tool) == 1
end

H.files_get_tool = function()
  if H.is_executable('rg') then return 'rg' end
  if H.is_executable('fd') then return 'fd' end
  if H.is_executable('git') then return 'git' end
  return 'fallback'
end

H.files_get_command = function(tool)
  if tool == 'rg' then return { 'rg', '--files', '--no-follow', '--color=never' } end
  if tool == 'fd' then return { 'fd', '--type=f', '--no-follow', '--color=never' } end
  if tool == 'git' then return { 'git', 'ls-files', '--cached', '--others', '--exclude-standard' } end
  H.error([[Wrong 'tool' for `files` builtin.]])
end

H.files_fallback_items = function(cwd)
  if vim.fn.has('nvim-0.9') == 0 then H.error('Tool "fallback" of `files` builtin needs Neovim>=0.9.') end
  cwd = cwd or '.'
  local poke_picker = H.poke_picker_throttle()
  local f = function()
    local items = {}
    for path, path_type in vim.fs.dir(cwd, { depth = math.huge }) do
      if not poke_picker() then return end
      if path_type == 'file' and H.is_file_text(string.format('%s/%s', cwd, path)) then table.insert(items, path) end
    end
    MiniPick.set_picker_items(items)
  end

  vim.schedule(coroutine.wrap(f))
end

H.grep_get_tool = function()
  if H.is_executable('rg') then return 'rg' end
  if H.is_executable('git') then return 'git' end
  return 'fallback'
end

--stylua: ignore
H.grep_get_command = function(tool, pattern)
  if tool == 'rg' then
    return { 'rg', '--column', '--line-number', '--no-heading', '--no-follow', '--color=never', '--', pattern }
  end
  if tool == 'git' then
    local res = { 'git', 'grep', '--column', '--line-number', '--color=never', '--', pattern }
    if vim.o.ignorecase then table.insert(res, 6, '--ignore-case') end
    return res
  end
  H.error([[Wrong 'tool' for `grep` builtin.]])
end

H.grep_fallback_items = function(pattern, cwd)
  if vim.fn.has('nvim-0.9') == 0 then H.error('Tool "fallback" of `grep` builtin needs Neovim>=0.9.') end
  cwd = cwd or '.'
  local poke_picker = H.poke_picker_throttle()
  local f = function()
    local files, files_full = {}, {}
    for path, path_type in vim.fs.dir(cwd, { depth = math.huge }) do
      if not poke_picker() then return end
      local path_full = string.format('%s/%s', cwd, path)
      if path_type == 'file' and H.is_file_text(path_full) then
        table.insert(files, path)
        table.insert(files_full, path_full)
      end
    end

    local items = {}
    for i, path in ipairs(files_full) do
      local file = files[i]
      if not poke_picker() then return end
      for lnum, l in ipairs(vim.fn.readfile(path)) do
        local col = string.find(l, pattern)
        if col ~= nil then table.insert(items, string.format('%s:%d:%d:%s', file, lnum, col, l)) end
      end
    end

    MiniPick.set_picker_items(items)
  end

  vim.schedule(coroutine.wrap(f))
end

-- Async ----------------------------------------------------------------------
H.schedule_resume_is_active = vim.schedule_wrap(function(co) coroutine.resume(co, MiniPick.is_picker_active()) end)

H.poke_picker_throttle = function(querytick_ref)
  -- Allow calling this even if no picker is active
  if not MiniPick.is_picker_active() then return function() return true end end

  local latest_time, dont_check_querytick = vim.loop.hrtime(), querytick_ref == nil
  local threshold = 1000000 * H.get_config().delay.async
  local hrtime = vim.loop.hrtime
  local poke_is_picker_active = MiniPick.poke_is_picker_active
  return function()
    local now = hrtime()
    if (now - latest_time) < threshold then return true end
    latest_time = now
    -- Return positive if picker is active and no query updates (if asked)
    return poke_is_picker_active() and (dont_check_querytick or querytick_ref == H.querytick)
  end
end

-- Utilities ------------------------------------------------------------------
H.error = function(msg) error(string.format('(mini.pick) %s', msg), 0) end

H.is_valid_buf = function(buf_id) return type(buf_id) == 'number' and vim.api.nvim_buf_is_valid(buf_id) end

H.is_valid_win = function(win_id) return type(win_id) == 'number' and vim.api.nvim_win_is_valid(win_id) end

H.is_array_of = function(x, ref_type)
  if not vim.tbl_islist(x) then return false end
  for i = 1, #x do
    if type(x[i]) ~= ref_type then return false end
  end
  return true
end

H.create_scratch_buf = function()
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.bo[buf_id].matchpairs = ''
  vim.b[buf_id].minicursorword_disable = true
  vim.b[buf_id].miniindentscope_disable = true
  return buf_id
end

H.get_first_valid_normal_window = function()
  for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win_id).relative == '' then return win_id end
  end
end

H.set_buflines = function(buf_id, lines) pcall(vim.api.nvim_buf_set_lines, buf_id, 0, -1, false, lines) end

H.set_winbuf = function(win_id, buf_id) vim.api.nvim_win_set_buf(win_id, buf_id) end

H.set_extmark = function(...) pcall(vim.api.nvim_buf_set_extmark, ...) end

H.set_cursor = function(win_id, lnum, col) pcall(vim.api.nvim_win_set_cursor, win_id, { lnum or 1, (col or 1) - 1 }) end

H.set_curwin = function(win_id)
  if not H.is_valid_win(win_id) then return end
  -- Explicitly preserve cursor to fix Neovim<=0.9 after choosing position in
  -- already shown buffer
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  vim.api.nvim_set_current_win(win_id)
  H.set_cursor(win_id, cursor[1], cursor[2] + 1)
end

H.clear_namespace = function(buf_id, ns_id) pcall(vim.api.nvim_buf_clear_namespace, buf_id, ns_id, 0, -1) end

H.replace_termcodes = function(x)
  if x == nil then return nil end
  return vim.api.nvim_replace_termcodes(x, true, true, true)
end

H.expand_callable = function(x, ...)
  if vim.is_callable(x) then return x(...) end
  return x
end

H.expandcmd = function(x)
  local ok, res = pcall(vim.fn.expandcmd, x)
  return ok and res or x
end

H.redraw = function() vim.cmd('redraw') end

H.redraw_scheduled = vim.schedule_wrap(H.redraw)

H.getcharstr = function(delay_async)
  -- Ensure that redraws still happen
  H.timers.getcharstr:start(0, delay_async, H.redraw_scheduled)
  H.cache.is_in_getcharstr = true
  local ok, char = pcall(vim.fn.getcharstr)
  H.cache.is_in_getcharstr = nil
  H.timers.getcharstr:stop()

  -- Terminate if no input, on hard-coded <C-c>, or outside mouse click
  local main_win_id
  if H.pickers.active ~= nil then main_win_id = H.pickers.active.windows.main end
  local is_bad_mouse_click = vim.v.mouse_winid ~= 0 and vim.v.mouse_winid ~= main_win_id
  if not ok or char == '' or char == '\3' or is_bad_mouse_click then return end
  return char
end

H.tolower = (function()
  -- Cache `tolower` for speed
  local tolower = vim.fn.tolower
  return function(x)
    -- `vim.fn.tolower` can throw errors on bad string (like with '\0')
    local ok, res = pcall(tolower, x)
    return ok and res or string.lower(x)
  end
end)()

H.win_update_hl = function(win_id, new_from, new_to)
  if not H.is_valid_win(win_id) then return end

  local new_entry = new_from .. ':' .. new_to
  local replace_pattern = string.format('(%s:[^,]*)', vim.pesc(new_from))
  local new_winhighlight, n_replace = vim.wo[win_id].winhighlight:gsub(replace_pattern, new_entry)
  if n_replace == 0 then new_winhighlight = new_winhighlight .. ',' .. new_entry end

  -- Use `pcall()` because Neovim<0.8 doesn't allow non-existing highlight
  -- groups inside `winhighlight` (like `FloatTitle` at the time).
  pcall(function() vim.wo[win_id].winhighlight = new_winhighlight end)
end

H.win_trim_to_width = function(win_id, text)
  local win_width = vim.api.nvim_win_get_width(win_id)
  return vim.fn.strcharpart(text, vim.fn.strchars(text) - win_width, win_width)
end

H.win_get_bottom_border = function(win_id)
  local border = vim.api.nvim_win_get_config(win_id).border or {}
  local res = border[6]
  if type(res) == 'table' then res = res[1] end
  return res or ' '
end

H.seq_along = function(arr)
  if arr == nil then return nil end
  local res = {}
  for i = 1, #arr do
    table.insert(res, i)
  end
  return res
end

H.get_next_char_bytecol = function(line_str, col)
  if type(line_str) ~= 'string' then return col end
  local utf_index = vim.str_utfindex(line_str, math.min(line_str:len(), col))
  return vim.str_byteindex(line_str, utf_index)
end

H.is_file_text = function(path)
  local fd = vim.loop.fs_open(path, 'r', 1)
  local is_text = vim.loop.fs_read(fd, 1024):find('\0') == nil
  vim.loop.fs_close(fd)
  return is_text
end

H.full_path = function(path) return (vim.fn.fnamemodify(path, ':p'):gsub('(.)/$', '%1')) end

return MiniPick
