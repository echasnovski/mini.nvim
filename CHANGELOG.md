# Version 0.15.0.9000

- Soft deprecate support for Neovim 0.8. It will be fully stopped in next release.

- Unify behavior of floating windows:
    - Truncate title/footer from left if it is too wide.
    - Set default title if window is allowed to have border.
    - BREAKING: Use single space padding for default title/footer.
    - BREAKING: Use 'single' as default window border in modules where it can be configured. On Neovim>=0.11 also respect non-empty 'winborder' option with lower precedence than explicitly configured value for the module.

- BREAKING FEATURE: Unify how module-related buffers are named: `mini<module-name>://<buffer-number>/<useful-info>`. This structure allows creating identifiable, reasonably unique, and useful buffer names. This is a user facing change because in some cases the shown buffer's name will change (like in statusline of opened 'mini.starter' buffer or output of `:buffers!`).

- BREAKING FEATURE: stop forcing recommended option values behind `set_vim_settings` config setting. Instead set them automatically in `setup()` if not set by user/plugin before it (no matter the value). Document this as a new general principle to be followed in the future. Affected modules:
    - 'mini.bufremove' (do nothing as recommended 'hidden' is on by default)
    - 'mini.completion' (set 'completeopt=menuone,noselect' and flags "cC" in 'shortmess')
    - 'mini.statusline' (do nothing as recommended 'laststatus=2' is default)
    - 'mini.tabline' (set 'showtabline=2')

## mini.ai

- FEATURE: textobject identifier can now be any single character supported by `:h getcharstr()`. This also makes it possible to use characters outside of Latin alphanumeric and punctuation sets as `custom_textobjects` keys. Default textobject is extended to be anything but Latin letters (to fall back to `:h text-objects`).
- FEATURE: update `gen_spec.treesitter()` to respect capture ranges specified by query directives (like `(#offset! @table.inner 0 1 0 -1)`).
- BREAKING: visual textobject selection now puts the cursor on the right edge instead of left. This better aligns with the (undocumented) behavior of how built-in `a` / `i` textobjects work in Visual mode, as opposed to the (documented in `:h operator-resulting-pos`) behavior of how it is done after applying the operator.

## mini.base16

- FEATURE: add support for colored markdown headings.
- FEATURE: add new plugin integrations:
    - 'ibhagwan/fzf-lua'
    - 'MeanderingProgrammer/render-markdown.nvim'
    - 'OXY2DEV/helpview.nvim'
    - 'OXY2DEV/markview.nvim'

## mini.colors

- FEATURE: update `convert()` to have `adjust_lightness` option which can be used to disable lightness adjustment (which is enabled by default for a more uniform progression from 0 to 100). This can be useful for output to be more consistent with other Oklab/Oklch implementations.

## mini.comment

- FEATURE: update textobject to respect `ignore_blank_line` option. Blank lines between commented lines are treated as part of a textobject.

## mini.completion

- BREAKING FEATURE: add snippet support. By default uses 'mini.snippets' to manage snippet session (if enabled, **highly recommended), falls back to `vim.snippet` on Neovim>=0.10. See "Snippets" section in `:h MiniCompletion` for more details.<br>
  This is a breaking change mostly because items with `Snippet` kind are no longer filtered out by default.
- FEATURE: add scrolling in info and signature window. By default can be done with `<C-f>` / `<C-b>` when target window is shown. Can be configured via `mappings.scroll_down` and `mappings.scroll_up` config options.
- FEATURE: respect `isIncomplete` in LSP completion response and immediately force new completion request on the next key press.
- FEATURE: add support for context in 'textDocument/completion' request.
- FEATURE: both info and signature help windows now use tree-sitter highlighting:
    - Info window uses "markdown" parser (works best on Neovim>=0.10 as its parser is built-in). Special markdown characters are concealed (i.e. hidden) which might result into seemingly unnecessary whitespace as dimensions are computed not accounting for that.
    - Signature help uses same parser as in current filetype.
- FEATURE: update signature help without delay if it is already shown. This helps to keep signature help up to date after cursor jumps in Insert mode (like during snippet session).
- FEATURE: add support for item defaults in `CompletionList` response.
- FEATURE: add `get_lsp_capabilities()` that returns data about which part of LSP specification is supported in 'mini.completion'.
- BREAKING FEATURE: rework how LSP completion items are converted to Neovim's completion items:
    - Show `detail` highlighted as buffer's language at the start of info window, but only if `detail` provides information not already present in `documentation`. It was previously used as extra text in the popup menu (via `menu` field), but this doesn't quite follow LSP specification: `detail` and `documentation` fields can be delayed up until `completionItem/resolve` request which implies they should be treated similarly.
    - Show `labelDetails` as a part of the popup menu via `menu` completion item field.
- BREAKING: prefer in some cases to use `nil` as default config value with explicit fallback. This should not have any user facing effects and marked as breaking only because a structure of a default config has changed. Affected fields:
    - `lsp_completion.process_items` (use `default_process_items` as fallback) and `fallback_action` (use `'<C-n>'` as fallback). This makes it more aligned with other modules that usually avoid using function values in default config.
    - `window.info.border` and `window.signature.border` (use non-empty 'winborder' and `'single'` as fallback).
- BREAKING FEATURE: update behavior and capabilities of `default_process_items()`:
    - Add `filtersort` option to control how items are filtered and/or sorted. Its default value has new (breaking) value: do fuzzy matching if 'completeopt' option contains "fuzzy" entry; same as before otherwise.
    - Use `filterText` and `label` item fields during matching (instead of `textEdit.newText`, `insertText`, and `label` as before). This is more aligned with LSP specification.
- BREAKING: change default value of `MiniCompletionActiveParameter` highlight group to link to `LspSignatureActiveParameter` (instead of forcing underline).

## mini.diff

- FEATURE: `config.source` can now be array of sources, which will be attempted to attach in order. Important for source's `attach` to either return `false` or call `MiniDiff.fail_attach()` (even not immediately) to signal that source has failed to attach to a particular buffer.
- FEATURE: overlay virtual lines now scroll horizontally along with buffer lines. Requires Neovim>=0.11 and disabled 'wrap' option.
- FEATURE: highlighting of buffer parts of change hunks can now be customized with these new highlight groups:
    - `MiniDiffOverChangeBuf` - changed buffer text. Previously used `MiniDiffOverChange` (for changed reference text); links to it by default.
    - `MiniDiffOverContextBuf` - context of a change shown in buffer overlay. Previously not highlighted, default highlight group is not created.

## mini.doc

- FEATURE: improve detection and formatting for types in `@param`, `@return`, and similar.

## mini.fuzzy

- BREAKING: update `process_lsp_items()` to only use `filterText` and `label` item fields during fuzzy matching (instead of `textEdit.newText`, `insertText`, and `label` as before). This is more aligned with LSP specification.
- BREAKING: treat empty `word` as matching any candidate (matched positions is empty array and score is -1). This behavior is usually more useful in practice.

## mini.hues

- FEATURE: add support for colored markdown headings.
- FEATURE: add new plugin integrations:
    - 'ibhagwan/fzf-lua'
    - 'MeanderingProgrammer/render-markdown.nvim'
    - 'OXY2DEV/helpview.nvim'
    - 'OXY2DEV/markview.nvim'

## mini.notify

- FEATURE: add `lsp_progress.level` option to control level of LSP progress notifications.
- FEATURE: add `MiniNotifyLspProgress` highlight group to be used for LSP progress notifications.
- FEATURE: add `data` field to notification specification and as a new argument to `MiniNotify.add()`. It can be used to store any data relevant to the notification. For example, notifications from `make_notify()` output set `source` field to `'vim.notify'`, while notifications from LSP progress set `source` to `'lsp_progress'`.

## mini.pairs

- FEATURE: update all actions to work with pairs containing multibyte characters (like "¿?", "「」", and similar).

## mini.statusline

- BREAKING: `section_fileinfo()` got several updates:
    - File size is now computed based on the current buffer text and not for file's saved version.
    - File info is now shown even for buffers with empty 'filetype'. It previously was treated as a sign of a "temporary buffer", but it might be a result of an unsuccessful filetype matching.

## mini.surround

- FEATURE: surrounding identifier can now be any single character supported by `:h getcharstr()`. This also makes it possible to use characters outside of Latin alphanumeric and punctuation sets as `custom_surroundings` keys.
- FEATURE: update `gen_spec.input.treesitter()` to respect capture ranges specified by query directives (like `(#offset! @table.inner 0 1 0 -1)`).

## mini.tabline

- FEATURE: add support for showing special (truncation) characters at left and/or right if there are more tabs to the left and/or right. They are shown with the new `MiniTablineTrunc` highlight group in case 'list' option is enabled (i.e. user deliberately enabled similar functionality for windows). Exact characters are taken from 'listchars' option: `precedes` and `extends` fields.
- FEATURE: labels for quickfix and location lists are now different.


# Version 0.15.0

## mini.align

- FEATURE: add built-in modifier for "|" character with aligning Markdown-like tables in mind.

## mini.animate

- BREAKING FEATURE: add `max_output_steps` option to `gen_path.line()` and `gen_path.angle()` to limit the number of steps the return. Default is 1000 to improve performance on large cursor jumps which also is set for `config.cursor.path`.

## mini.files

- FEATURE: closing and refreshing explorer now requires confirmation only if there are pending file system actions (and not in case of at least one modified buffer present).
- FEATURE: confirming file system actions in `synchronize()` now can cancel synchronization (by pressing `c`) while keeping buffer contents the same. `synchronize()` also returns a boolean representing whether synchronization was done.

## mini.git

- FEATURE: Git data is computed after resolving symlinks. This allows working with files symlinked into outside of Git repo. This behavior is the same as in 'mini.diff'.

## mini.hipatterns

- BREAKING FEATURE: make `MiniHipatterns{Fixme,Hack,Todo,Note}` highlight groups by default be reverse and bold variant of `Diagnostic{Error,Warn,Info,Hint}` group instead of directly link to them. This ensures better visibility for color schemes which don't have explicit 'mini.hipatterns' support.

## mini.hues

- FEATURE: add `'lowmedium'` and `'mediumhigh'` saturation levels.

## mini.icons

- FEATURE: add distinctive glyphs and highlighting for special Neovim directories (from `:h 'runtimepath'`).

## mini.indentscope

- BREAKING FEATURE: add `options.n_lines` option to limit the scope computation (for better performance). It is breaking because the default value is 10000 while previous behavior had no restriction (as with `n_lines = math.huge`) which should matter only in very big scopes.
- BREAKING FEATURE: add `draw.predicate` configuration to customize whether the scope should be autodrawn. It is breaking because the default value does not draw scope with incomplete computation (i.e. interrupted due to `options.n_lines` value), which should matter only in very big scopes.

## mini.notify

- FEATURE: `setup()` now also can be used to clean history (for example, like `MiniNotify.setup(MiniNotify.config)`).

## mini.pick

- BREAKING FEATURE: picker window now has local current directory set to source's `cwd`. This allows easier code for "in window" functions (callable items, choose, preview, etc.) as relative paths will be properly resolved. It also results in some changes:
    - Calling `set_picker_items_from_cli()` with active picker now resolves explicitly set to relative path `spawn_opts.cwd` against picker's `cwd` (and not against global current directory as was done previously).
- FEATURE: update `grep` and `grep_live` pickers to allow `globs` local option which restricts search to files that match any of its glob patterns (for example, `{ '*.lua', 'lua/**' }` will only search in Lua files and files in 'lua' directory). The `grep_live` picker also has custom `<C-o>` mapping to add globs interactively after picker is opened.
- FEATURE: update `help` picker to have `default_split` local option which customizes split direction of `choose` action (`<CR>` by default).
- FEATURE: update `ui_select()` to allow fourth argument `start_opts` to customize `MiniPick.start()` call.
- FEATURE: add `MiniPickMatch` event triggered after updating query matches or setting items. Can be used, for example, to adjust window height based on current matches.

## mini.snippets

- Introduction of a new module.

## mini.surround

- BREAKING: created mappings for `find`, `find_left`, and `highlight` are now *not* dot-repeatable. Dot-repeat should repeat last text change but neither of those actions change text. Having them dot-repeatable breaks the common "move cursor -> press dot" workflow. Initially making them dot-repeatable was a "you can but you should not" type of mistake.

## mini.test

- FEATURE: add `n_retry` test set property. When set, each case will be tried that at most that many times until first success (if any).
- FEATURE: add `hooks.pre_source` and `hooks.post_source` fields to collected cases. They can be either `'once'` or `'case'` and allow a more granular control over case execution.
- FEATURE: `finally()` now can be called several times inside a single function with callbacks executed in order of how they were registered.
- BREAKING FEATURE: now calling `skip()` in set's `pre_case` hook results in skipping all test cases in a set. Calling in other hooks has no effect. This enables a more structured skipping of all test cases inside a set. To skip inside hooks, use `add_note()` followed by `return`.
- FEATURE: update `expect.reference_screenshot()` to allow `directory` option pointing to a directory where automatically constructed reference path is located.


# Version 0.14.0

- Stop official support of Neovim 0.7.
- Update help files to use code blocks with language annotation, as it results in a better code highlighting. Implies enabled tree-sitter highlighting in 'help' filetype:
    - It is default in Neovim>=0.10.
    - Tree-sitter parser is built-in in Neovim 0.9.x, needs manual enabling via `vim.treesitter.start()`.
    - Has visual regressions on Neovim 0.8.0 and 0.8.1 without enabled tree-sitter (code blocks are highlighted as normal text). Use 0.8.2 or newer.
- Universally prefer 'mini.icons' module over 'nvim-tree/nvim-web-devicons'.
- Start automated testing on Windows and MacOS.
- Universally ensure that all plugin's highlight groups are defined after any color scheme takes effect.

## mini.base16

- FEATURE: add 'kevinhwang91/nvim-bqf' plugin integration.

## mini.completion

- FEATURE: add highlighting of LSP kind (like "Function", "Keyword", etc.). Works only on Neovim>=0.11. Requires enabled 'mini.icons' to work out of the box.

## mini.doc

- BREAKING FEATURE: update `afterlines_to_code()` to result into Lua code block in help file by using `>lua` at the start instead of `>`. NOTE: users need enabled `help` tree-sitter parser (which is default on Neovim>=0.9) for code blocks to have proper highlighting.

## mini.extra

- FEATURE: update `oldfiles` picker to have `current_dir` option which if `true` shows files only from picker's working directory. By @abeldekat, PR #997.
- FEATURE: make `git_hunks`, `list`, and `lsp` pickers show icons. Scopes `document_symbol` and `workspace_symbol` in `lsp` picker show icon based on LSP kind (requires set up 'mini.icons'), others - based on path data.
- FEATURE: update `buf_lines` and `oldfiles` pickers to have `preserve_order` local option, similar to `visit_paths` picker. Other possible candidates for this option are intentionally not updated to not increase maintenance (manually override `match` source method to call `MiniPick.default_match()` with `{ preserve_order = true }` options).
- FEATURE: update `buf_lines` picker to pad line numbers to achieve more aligned look.
- BREAKING FEATURE: use "│" as line/position separator instead of ":". This aligns with changes in 'mini.pick' and makes line/position more easily visible.

## mini.git

- FEATURE: update `show_at_cursor()` to include commit's statistics when showing commit.
- FEATURE: update `show_at_cursor()` to show relevant at cursor commit data inside 'mini.deps' confirmation buffer.

## mini.hipatterns

- BREAKING FEATURE: update `compute_hex_color_group()` to compute based on combination of `hex_color` and `style`, opposed to just `hex_color`. This allows simultaneous usage of several styles in user's custom highlighters.

## mini.hues

- FEATURE: implement `apply_palette()` (to compliment `make_palette()`) providing a way to tweak applied palette before applying it.
- FEATURE: add 'kevinhwang91/nvim-bqf' plugin integration.

## mini.files

- FEATURE: prefer using 'mini.icons' as icon provider.
- FEATURE: implement bookmarks. With default config:
    - Type `m` followed by a single character `<char>` to set directory path of focused window as a bookmark with id `<char>`.
    - Type `'` followed by a bookmark id to make bookmark's path focused in explorer.
    - Use `MiniFiles.set_bookmark()` inside `MiniFilesExplorerOpen` event to set custom bookmarks.
- FEATURE: make data for `MiniFilesActionDelete` contain `to` field in case of not permanent delete.
- FEATURE: make file manipulation work better for special complex/overlapping cases (like delete 'file-a' and copy 'file-b' as 'file-a'). It is **still** a better idea to split overlapping manipulations into smaller and not related steps, as there *are* cases which won't work.
- FEATURE: add `get_explorer_state()` to allow more reliable user customizations.
- FEATURE: add `set_branch()` to allow to set what paths should be displayed and focused.
- BREAKING: soft deprecate `get_target_window()` in favor of `get_explorer_state().target_window`. Will be completely removed after the next release.
- BREAKING: update how confirmation lines are computed:
    - Show create actions in the group directory where text manipulation took place. This matters during creating nested entries and is usually a more intuitive representation.
    - For delete show its type after the file name ("permanently" or "to trash") as an additional visual indication of delete type.
    - For create, copy and move prefer showing its "to" path relative to group directory.
    - Separate action name and paths with "│" (instead of ":") for better visual separation.
    - Don't enclose paths in quotes. Initially it was done to reliably show possible whitespace in paths, but inferring it from overall line structure should be good enough.

## mini.icons

- Introduction of a new module.

## mini.misc

- FEATURE: implement `setup_termbg_sync()` to set up terminal background synchronization (removes possible "frame" around current Neovim instance). Works only on Neovim>=0.10.

## mini.pick

- FEATURE: prefer using 'mini.icons' as icon provider.
- BREAKING: update `default_match()` to have table `opts` as fourth argument (instead of boolean `do_sync`). Use `{ sync = true }` to run synchronously. The new design is more aligned with other functions and is more forward compatible.
- FEATURE: add `preserve_order` option to `default_match()` to allow asynchronous matching which preserves order (i.e. doesn't do sort step of fuzzy matching).
- BREAKING: encoding line or position in string items has changed:
    - Use "\0" (null character; use "\000" form if it is in a string before digit) instead of ":" as delimiter. This makes it work with files similar to ":" position encoding (like "time_12:34:56"). This only matters for custom sources which provide line or position in string items.
    - Update `default_show()` to display "│" character instead of "\0" in item's string representation (previously was ":"). In particular, this changes how line/position is displayed in `grep` and `grep_live` built-in pickers. This change was done because "│" is more visible as separator.
- FEATURE: explicitly hide cursor when picker is active (instead of putting it in command line).

## mini.starter

- BREAKING: change filetype of Starter buffer from 'starter' to 'ministarter'. This is a more robust value and more aligned with other modules.

## mini.statusline

- BREAKING FEATURE: update `section_fileinfo()` to show non-empty filetype even in not normal buffers (like plugin's scratch buffers, help, quickfix, etc.). Previously it showed nothing, which was a mistake as filetype can be a valuable information.
- BREAKING FEATURE: the default `set_vim_settings` config value now does not affect `laststatus = 3` (aka global statusline).
- FEATURE: prefer using 'mini.icons' as icon provider for `section_fileinfo()`.

## mini.surround

- BREAKING FEATURE: adding surrounding in linewise mode now also ignores trailing whitespace on the last line (same as it ignores indent on the first line).

## mini.tabline

- FEATURE: prefer using 'mini.icons' as icon provider.

## mini.test

- FEATURE: make it work on Windows. By @cameronr, PR #1101.


# Version 0.13.0

## mini.comment

- BREAKING FEATURE: blank lines are now completely ignored when deciding the toggling action. In practice this means that if target block consists only from commented and/or blank lines, it will be uncommented rather than commented.

- BREAKING: Whitespace in comment parts is now treated more explicitly. In particular:
    - Default `options.pad_comment_parts = true` now more explicitly means that any value of 'commentstring' is transformed so that comment parts have exactly single space inner padding.

      Example: any `/*%s*/`, ` /* %s */ `, or `/*  %s  */` is equivalent to having `/* %s */`.

    - Detection of whether consecutive lines are commented or not does not depend on whitespace in comment parts. Uncommenting is first attempted with exact comment parts and falls back on trying its trimmed parts.

      Example of toggling comment on single line with `/* %s */` 'commentstring' value:
        - `/* this is commented */` -> `this is commented`.
        - `/*this is also commented */` -> `this is also commented ` (notice trailing space).

    - Commenting blank lines is done with trimmed comments parts, while uncommenting explicitly results into empty lines.

- FEATURE: Support dot-repeat after initial commenting is done for visual selection; repeating is done for same relative range.

## mini.deps

- FEATURE: add `MiniDepsMsgBreaking` highlight group for messages indicating a breaking change in a conventional commit style.

## mini.diff

- Introduction of a new module.

## mini.files

- FEATURE: add new `MiniFilesExplorerOpen` and `MiniFilesExplorerClose` events.

## mini.git

- Introduction of a new module.

## mini.hues

- BREAKING FEATURE: update some highlight groups for better usability:
    - `DiffChange` and `DiffText` - make changed diff lines have colored background.
    - `Folded` - make folds differ from `CursorLine`.
    - `QuickFixLine` - make current quickfix item differ from `CursorLine`.

## mini.map

- FEATURE: add `gen_integration.diff()` which highlights general diff hunks from 'mini.diff'.

## mini.pick

- BREAKING: stop trying to parse path for special format ("path:row" and "path:row:col") if supplied inside a table item. This made impossible working with paths containing ":".
- FEATURE: respect general URI format for paths inside table items.
- Update `builtin.files()` to use table items when string item might be ambiguous.

## mini.starter

- Explicitly block all events in `open()` during startup for a better performance.

## mini.statusline

- BREAKING: `section_diagnostics()` now depends only on defined diagnostic. This means:
    - Something is shown **only** if there is any diagnostic actually present in the buffer. No diagnostic entries - nothing is shown.
    Previously it did not show if there was no LSP servers attached (as initially diagnostics came only from LSP) or buffer was not normal.
    - Fallback icon is "Diag" instead of "LSP".
- FEATURE: `section_diagnostics()` now supports `signs` table option to customize signs for severity levels.
- BREAKING FEATURE: `section_git()` now prefers using data from 'mini.git' with fallback on pure HEAD data from 'lewis6991/gistigns.nvim'.
- FEATURE: add `section_diff()` to show data from 'mini.diff' with fallback on diff data from 'lewis6991/gistigns.nvim'.
- FEATURE: add `section_lsp()` to show indicator of LSP servers attached to the buffer.
- BREAKING FEATURE: update default active content:
    - Add `section_diff()` (shows diff data near  icon) following refactor of `section_git()`.
    - Add `section_lsp()` (shows number of attached LSP servers near 󰰎 icon) following refactor of `section_diagnostics()`.

## mini.tabline

- FEATURE: Implement `config.format` for custom label formatting.

## mini.test

- BREAKING FEATURE: child process is now created with extra `--headless --cmd "set lines=24 columns=80"` arguments making it headless but still reasonably similar to fully functioning Neovim during interactive usage. This change should generally not break a lot of things, while enabling a faster and more robust test execution.


# Version 0.12.0

## mini.basics

- BREAKING: Remove `<C-z>` mapping, as it is more useful in most terminal emulators for suspending Neovim process (to later resume with `fg` command). To correct latest misspelled word, use mappings like this:

```lua
vim.keymap.set('n', '<C-z>', '[s1z=',                     { desc = 'Correct latest misspelled word' })
vim.keymap.set('i', '<C-z>', '<C-g>u<Esc>[s1z=`]a<C-g>u', { desc = 'Correct latest misspelled word' })
```

- FEATURE: Add `tab:> ` to 'listchars' option when `options.extra_ui` is set. This prevents showing `^I` instead of a tab and actual value comes from Neovim's default.
- FEATURE: Set `termguicolors` only on Neovim<0.10, as later versions should have it on by default (if terminal emulator supports it).

## mini.comment

- FEATURE: Hooks are now called with data about commenting action.

## mini.deps

Introduction of a new module.

## mini.doc

- BREAKING: Stop using `:echo` to display messages and warnings in favor of `vim.notify()`.
- BREAKING: Update default `write_post` hook to not display current time in success message.
- Update to include space before `~` in generated section headings.

## mini.files

- FEATURE: Update `go_in()` to have `close_on_file` option.
- Show warning if action is set to override existing path.

## mini.hues

- BREAKING FEATURE: Update verbatim text (`@text.literal` and `@markup.raw`) color to be distinctive instead of dimmed.
- FEATURE: Add support for new standard tree-sitter captures on Neovim>=0.10 (see https://github.com/neovim/neovim/pull/27067).

## mini.misc

- Update `bench_time()` to use `vim.loop.hrtime()` (as better designed for benchmarking) instead of `vim.loop.gettimeofday()`.

## mini.notify

Introduction of a new module.

## mini.pick

- FEATURE: Implement `window.prompt_cursor` and `window.prompt_prefix` config options.
- FEATURE: Update `builtin.help()` to use tree-sitter highlighting (if there is any).

## mini.sessions

- FEATURE: Update `read()` to first `write()` current session (if there is any).

## mini.starter

- FEATURE: Add `sections.pick()` with 'mini.pick' pickers.

## mini.statusline

- BREAKING FEATURE: Add `search_count` section to default active content.

## mini.visits

Introduction of a new module.


# Version 0.11.0

## mini.base16

- BREAKING: Stop supporting deprecated 'HiPhish/nvim-ts-rainbow2'.

## mini.bufremove

- BREAKING FEATURE: Applying `delete()` and `wipeout()` without `force` in a modified buffer now asks for confirmation instead of declining and showing message.

## mini.clue

- FEATURE: `config.window.config` now can be callable returning window config.

## mini.comment

- FEATURE: Implement `config.mappings.comment_visual` to configure mapped keys in Visual mode.

## mini.completion

- FEATURE: Start adding `C` flag to `shortmess` option on Neovim>=0.9. By @yamin-shihab, PR #554.

## mini.extra

Introduction of a new module.

## mini.files

- BREAKING: Opening file which is present in unlisted buffer now makes the buffer listed.
- BREAKING: Highlight in preview now is not enabled if file is sufficiently large.
- FEATURE: Explorer now tracks if focus is lost and properly closes on detection.
- FEATURE: Implement `MiniFilesCursorLine` highlight group.

## mini.hipatterns

- FEATURE: Allow `pattern` in highlighter definitions to be an array to highlight several patterns under the same highlighter name.
- FEATURE: Implement `extmark_opts` in highlighter definitions for a more control over extmarks placed at matches.
- BREAKING: Field `priority` in highlighter definitions is soft deprecated in favor of `extmark_opts = { priority = <value> }`.
- FEATURE: Update `compute_hex_color_group()` to allow `style = 'fg'`.
- FEATURE: Update `gen_highlighter.hex_color()` to allow `style = 'inline'` (requires Neovim>=0.10 with support of inline extmarks).
- FEATURE: Implement `get_matches()` to get buffer matches.

## mini.hues

- BREAKING: Stop supporting deprecated 'HiPhish/nvim-ts-rainbow2'.

## mini.map

- FEATURE: Implement `config.window.zindex` to configure z-index of map window.

## mini.misc

- FEATURE: `setup_auto_root()` and `find_root()` now have `fallback` argument to be applied when no root is found with `vim.fn.find()`.

## mini.pick

Introduction of a new module.

## mini.starter

- FEATURE: `show_path` in `sections.recent_files()` can now be callable for more control on how full path is displayed.

## mini.test

- BREAKING: Error in any "pre" hook now leads to test case not being executed (with note).
- BREAKING FEATURE: `child.get_screenshot()` now by default calls `:redraw` prior to computing screenshot. Can be disabled by new `opts.redraw` argument.
- FEATURE: New method `child.lua_func()` can execute simple functions inside child process and return the result (stasjok, #437).
- FEATURE: `expect.reference_screenshot()` now has `ignore_lines` option allowing to ignore specified lines during screenshot compare.


# Version 0.10.0

## mini.ai

- FEATURE: Allow `vis_mode` field in custom texobject region to force Visual mode with which textobject is selected.

## mini.animate

- FEATURE: Add `MiniAnimateNormalFloat` highlight group to tweak highlighting of `open` and `close` animations.

## mini.base16

- FEATURE: Add 'HiPhish/rainbow-delimiters.nvim' integration.

## mini.basics

- BREAKING: Remove `<C-w>` mapping in Terminal mode, as it is more useful inside terminal emulator itself.

## mini.bracketed

- FEATURE: Add `add_to_jumplist` option to relevant targets (which move cursor and don't already add to jumplist).

## mini.bufremove

- BREAKING: Create normal buffer instead of scratch when there is no reasonable target to focus (#394).

## mini.clue

Introduction of a new module.

## mini.files

Introduction of a new module.

## mini.hues

- FEATURE: Add 'HiPhish/rainbow-delimiters.nvim' integration.

## mini.jump2d

- FEATURE: Add `gen_union_spotter()` to allow combining separate spotters into one.

## mini.operators

Introduction of a new module.

## mini.pairs

- FEATURE: Allow `false` in `config.mappings` to not map the key.

## mini.surround

- FEATURE: Update `add` (`sa`) with ability to replicate left and right parts by respecting `[count]`. In Normal mode two kinds of `[count]` is respected: one for operator (replicates left and right parts) and one for textobject/motion. In Visual mode `[count]` replicates parts.


# Version 0.9.0

- Stop official support of Neovim 0.6.
- Use Lua API to create autocommands. Stop exporting functions only related to autocommands.
- Use Lua API to create default highlight groups.
- Use `vim.keymap` to deal with mappings. Stop exporting functions only related to mappings.
- Add 'randomhue' color scheme.

## mini.base16

- FEATURE: Add new integrations:
    - Lsp semantic tokens.
    - 'folke/lazy.nvim'.
    - 'folke/noice.nvim'.
    - 'kevinhwang91/nvim-ufo'.
- BREAKING FEATURE: Stop supporting archived 'p00f/nvim-ts-rainbow' in favor of 'HiPhish/nvim-ts-rainbow2'.

## mini.basics

- Add dot-repeat support for adding empty lines (`go` and `gO` mappings).

## mini.colors

Introduction of a new module.

## mini.comment

- FEATURE: Use tree-sitter information about locally active language to infer 'commentstring' option value.
- FEATURE: Add `options.custom_commentstring` option for a more granular customization of comment structure.
- FEATURE: Add `get_commentstring()` function representing built-in logic of computing relevant 'commentstring'.

## mini.hipatterns

Introduction of a new module.

## mini.hues

Introduction of a new module.


# Version 0.8.0

- Add and implement design principle for silencing module by setting `config.silent = true`. It is now present in modules capable of showing non-error feedback:
    - mini.ai
    - mini.align
    - mini.basics
    - mini.bufremove
    - mini.doc
    - mini.jump
    - mini.jump2d
    - mini.starter
    - mini.surround
    - mini.test

## mini.bracketed

Introduction of a new module.

## mini.comment

- FEATURE: Add `options.start_of_line` option which controls whether to recognize as comment only lines without indent.
- FEATURE: Add `options.ignore_blank_line` option which controls whether to ignore blank lines.
- FEATURE: Add `options.pad_comment_parts` option which controls whether to ensure single space pad for comment leaders.

## mini.doc

- FEATURE: Add `config.hooks.write_pre` hook to be executed before writing to a file.

## mini.indentscope

- FEATURE: Add `MiniIndentscopeSymbolOff` highlight group to be used if scope's indent is not multiple of 'shiftwidth'.
- FEATURE: Add `draw.priority` option to control priority of scope line draw.

## mini.jump2d

- FEATURE: Add `view.n_steps_ahead` option which controls how many steps ahead to show. Appearance is controlled by new `MiniJump2dSpotAhead` highlight group.
- FEATURE: Add `view.dim` option which controls whether to dim lines with at least one jump spot. Appearance is controlled by new `MiniJump2dDim` highlight group.
- FEATURE: Add `MiniJump2dSpotUnique` highlight group to be used for spots with unique label for next step.

## mini.pairs

- FEATURE: Both `MiniPairs.br()` and `MiniPairs.cr()` can now take a key which will be used instead of default `<BS>` and `<CR>`.

## mini.sessions

- FEATURE: `setup()` now creates global directory at path `config.directory` if it doesn't exist.
- All actions now keep list of detected sessions up to date.

## mini.splitjoin

Introduction of a new module.

## mini.surround

- FEATURE: Add `respect_selection_type` option which, when enabled, makes adding and deleting surrounding respect selection type:
    - Linewise adding places surrounding parts on separate lines while indenting surrounded lines once.
    - Deleting surrounding which looks like a result of linewise adding will act to revert it: delete lines with surrounding parts and dedent surrounded lines once.
    - Blockwise adding places surrounding parts on whole edges, not only start and end of selection.


# Version 0.7.0

- Start dual distribution. Every module is now distributed both as part of 'mini.nvim' library and as standalone plugin (in separate git repository).

## mini.ai

- BREAKING FEATURE: In `MiniAi.gen_spec.argument()` option `separators` (plural; array of characters) is soft deprecated in favor of `separator` (singular; Lua pattern) option.

## mini.animate

Introduction of new module.

## mini.basics

Introduction of a new module.

## mini.completion

- BREAKING: `MiniCompletion.config.window_dimensions` is renamed to `MiniCompletion.config.window` to be able to handle more general configuration.
- FEATURE: Add `MiniCompletion.config.window.info.border` and `MiniCompletion.config.window.signature.border` which can be used to define border of info and signature floating windows respectively.

## mini.indentscope

- BREAKING: `MiniIndentscopePrefix` is now not used (deprecated). It was initially introduced as a way to properly show scope indicator on empty lines. It had a drawback of overshadowing 'listchars' symbols (see #125) and vertical guides from 'lukas-reineke/indent-blankline.nvim'. As the other implementation approach was found by @mivort (see #161), `MiniIndentscopePrefix` is no longer needed and no overshadowing is done.
- BREAKING: `MiniIndentscope.gen_animation` is now a table (for consistency with other `gen_*` functions in 'mini.nvim'). See "Migrate from function type" section of `:h MiniIndentscope.gen_animation`. Calling it as function will be available until next release.

## mini.misc

- FEATURE: Add `MiniMisc.setup_auto_root()` and `MiniMisc.find_root()` for root finding functionality. NOTE: requires Neovim>=0.8.
- FEATURE: Add `MiniMisc.setup_restore_cursor()` for automatically restoring latest cursor position on file reopen. By @cryptomilk, PR #198.

## mini.move

Introduction of new module.


# Version 0.6.0

- Stop official support of Neovim 0.5.
- Make all messages use colors and not cause hit-enter-prompt.

## mini.align

Introduction of new module.

## mini.base16

- FEATURE: Add support for many plugin integrations.
- FEATURE: Implement `MiniBase16.config.plugins` for configuring plugin integrations.
- BREAKING: Change some 'mini.nvim' highlights:
    - `MiniCompletionActiveParameter` now highlights with background instead of underline.
    - `MiniJump2dSpot` now explicitly defined to use plugin's palette.
    - `MiniStarterItemPrefix` and `MiniStarterQuery` are now bold for better visibility.
- BREAKING: Update highlight for changed git diff to be more visible and to comply more with general guidelines.

## mini.jump

- BREAKING: Allow cursor to be positioned past the end of previous/current line (#113).

## mini.map

Introduction of new module.

## mini.starter

- Item evaluation is now prepended with query reset, as it is rarely needed any more (#105).
- All hooks are now called with `(content, buf_id)` signature allowing them properly use current window layout.

## mini.surround

- BREAKING FEATURE: update 'mini.surround' to share as much with 'mini.ai' as possible. This provides more integrated experience while enabling more useful features. Details:
    - Custom surrounding specification for input action has changed. Instead of `{ find = <string>, extract = <string> }` it is now `{ <function or composed pattern> }`. Previous format will work until the next release. See more in help file.
    - Algorithm for finding surrounding is now more powerful. It allows searching for more complex surroundings (via composed patterns or array of region pairs) and respects `v:count`.
    - Multiline input and output surroundings are now supported.
    - Opening brackets (`(`, `[`, `{`, `<`) now include whitespace in surrounding: input surrounding selects all inner edge whitespace, output surrounding is padded with single space.
    - Surrounding identifier `i` ("interactive") is soft deprecated in favor of `?` ("user prompt").
    - New surrounding aliases:
        - `b` for "brackets". Input - any of balanced `()`, `[]` `{}`. Output - `()`.
        - `q` for "quotes". Input - any of `"`, `'`, `` ` ``. Output - `""`.
    - Three new search methods `'prev'`, `'next'`, and `'nearest'` for finding non-covering previous and next surrounding.
- BREAKING FEATURE: Implement "last"/"next" extended mappings which force `'prev'` or `'next'` search method. Controlled with `config.mappings.suffix_last` and `config.mappings.suffix_next`respectively. This also means that custom surroundings with identifier equal to "last"/"next" mappings suffixes (defaults to 'l' and 'n') will work only with long enough delay after typing action mapping.
- FEATURE: Implement `MiniSurround.gen_spec` with generators of common surrounding specifications (like `MiniSurround.gen_spec.input.treesitter` for tree-sitter based input surrounding).


# Version 0.5.0

- Update all tests to use new 'mini.test' module.
- FEATURE: Implement buffer local configuration. This is done with `vim.b.mini*_config` buffer variables.
- Add new `minicyan` color scheme.

## mini.ai

Introduction of new module.

## mini.comment

- FEATURE: Now hooks can be used to terminate further actions by returning `false` (#108).

## mini.indentscope

- BREAKING: Soft deprecate `vim.b.miniindentscope_options` in favor of using `options` field of `miniindentscope_config`.

## mini.sessions

- FEATURE: Hooks are now called with active session data as argument.

## mini.starter

- FEATURE: Now it is possible to open multiple Starter buffers at the same time (#82). This comes with several changes which won't affect most users:
    - BREAKING: `MiniStarter.content` is deprecated. Use `MiniStarter.get_content()`.
    - All functions dealing with Starter buffer now have `buf_id` as argument (no breaking behavior).

## mini.statusline

- FEATURE: Implement `config.use_icons` which controls whether to use icons by default.

## mini.test

Introduction of new module.

## mini.trailspace

- FEATURE: Implement `MiniTrailspace.trim_last_lines()`.


# Version 0.4.0

- Update all modules to supply mapping description for Neovim>=0.7.
- Add new module 'mini.jump2d'.
- Cover all modules with extensive tests.

## mini.comment

- FEATURE: Implement `config.hooks` with `pre` and `post` hooks (executed before and after successful commenting). Fixes #50, #59.

## mini.completion

- Implement support for `additionalTextEdits` (issue #61).

## mini.jump

- FEATURE: Implement idle timeout to stop jumping automatically (@annenpolka, #56).
- FEATURE: Implement `MiniJump.state`: table with useful model-related information.
- BREAKING: Soft deprecate `config.highlight_delay` in favor of `config.delay.highlight`.
- Update process of querying target symbol: show help message after delay, allow `<C-c>` to stop selecting target.

## mini.jump2d

Introduction of new module.

## mini.pairs

- Create mappings for `<BS>` and `<CR>` in certain mode only after some pair is registered in that mode.

## mini.sessions

- FEATURE: Implement `MiniSessions.select()` to select session interactively and perform action on it.
- FEATURE: Implement `config.hooks` to execute hook functions before and after successful action.
- BREAKING: All feedback about incorrect behavior is now an error instead of message notifications.

## mini.starter

- Allow `config.header` and `config.footer` be any value, which will be converted to string via `tostring()`.
- Update query logic to not allow queries which result into no items.
- Add `<C-n>` and `<C-p>` to default mappings.

## mini.statusline

- BREAKING: change default icon for `MiniStatusline.section_diagnostics()` from ﯭ to  due to former having issues in some terminal emulators.

## mini.surround

- FEATURE: Implement `config.search_method`.
- FEATURE: Implement custom surroundings via `config.custom_surroundings`.
- FEATURE: Implement `MiniSurround.user_input()`.
- BREAKING: Deprecate `config.funname_pattern` option in favor of manually modifying `f` surrounding.
- BREAKING: Always move cursor to the right of left surrounding in `add()`, `delete()`, and `replace()` (instead of moving only if it was on the same line as left surrounding).
- Update process of getting user input: allow `<C-c>` to cancel and make empty string a valid input.

## mini.tabline

- FEATURE: Implement `config.tabpage_section`.
- BREAKING: Show listed buffers also in case of multiple tabpages (instead of using builtin behavior).
- Show quickfix/loclist buffers with special `*quickfix*` label.


# Version 0.3.0

- Update all modules to have annotations formatted for 'mini.doc'.

## mini.cursorword

- Current word under cursor now can be highlighted differently.

## mini.doc

Introduction of new module.

## mini.indentscope

Introduction of new module.

## mini.starter

- Implement `MiniStarter.set_query()` and make `<Esc>` mapping for resetting query.


# Version 0.2.0

## mini.base16

- Use new `Diagnostic*` highlight groups in Neovim 0.6.0.

## mini.comment

- Respect tab indentation (#20).

## mini.jump

Introduction of new module.

## mini.pairs

- Implement pair registration with custom mapping functions. More detailed:
    - Implement `MiniPairs.map()`, `MiniPairs.map_buf()`, `MiniPairs.unmap()`, `MiniPairs.unmap_buf()` to (un)make mappings for pairs which automatically register them for `<BS>` and `<CR>`. Note, that this has a minor break of previous behavior: now `MiniPairs.bs()` and `MiniPairs.cr()` don't have any input argument. But default behavior didn't change.
    - Allow setting global pair mappings inside `config` of `MiniPairs.setup()`.

## mini.sessions

Introduction of new module.

## mini.starter

Introduction of new module.

## mini.statusline

- Implement new section `MiniStatusline.section_searchcount()`.
- Update `section_diagnostics` to use `vim.diagnostic` in Neovim 0.6.0.


# Version 0.1.0

- Initial stable version.
