# Version 0.11.0.9999

## mini.basics

- BREAKING: Remove `<C-z>` mapping, as it is more useful in most terminal emulators for suspending Neovim process (to later resume with `fg` command). To correct latest misspelled word, use mappings like this:

```lua
vim.keymap.set('n', '<C-z>', '[s1z=',                     { desc = 'Correct latest misspelled word' })
vim.keymap.set('i', '<C-z>', '<C-g>u<Esc>[s1z=`]a<C-g>u', { desc = 'Correct latest misspelled word' })
```

- FEATURE: Add `tab:> ` to 'listchars' option when `options.extra_ui` is set. This prevents showing `^I` instead of a tab and actual value comes from Neovim's default.
- FEATURE: Set `termguicolors` only on Neovim<0.10, as later versions should have it on by default (if terminal emulator supports it).

## mini.doc

- BREAKING: Stop using `:echo` to display messages and warnings in favor of `vim.notify()`.
- BREAKING: Update default `write_post` hook to not display current time in success message.
- Update to include space before `~` in generated section headings.

## mini.files

- FEATURE: Update `go_in()` to have `close_on_file` option.

## mini.hues

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
