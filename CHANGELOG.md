# Version 0.6.0.9000

- Start dual distribution. Every module is now distributed both as part of 'mini.nvim' library and as standalone plugin (in separate git repository).

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
