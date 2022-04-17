# Version 0.3.0.9000 (development)

## mini.comment

- Implement `config.hooks` with `pre` and `post` hooks (executed before and after successful commenting). Fixes #50, #59.

## mini.jump

- BREAKING: Soft deprecate `config.highlight_delay` in favor of `config.delay.highlight`.
- Implement idle timeout to stop jumping automatically (@annenpolka, #56).
- Update process of querying target symbol: show help message after delay, allow `<C-c>` to stop selecting target.
- Implement `MiniJump.state`: table with useful model-related information.

## mini.pairs

- Create mappings for `<BS>` and `<CR>` in certain mode only after some pair is registered in that mode.

## mini.sessions

- BREAKING: All feedback about incorrect behavior is now an error instead of message notifications.
- Implement `MiniSessions.select()` to select session interactively and perform action on it.

## mini.starter

- Allow `config.header` and `config.footer` be any value, which will be converted to string via `tostring()`.
- Update query logic to not allow queries which result into no items.

## mini.statusline

- BREAKING: change default icon for `MiniStatusline.section_diagnostics()` from ﯭ to  due to former having issues in some terminal emulators.

## mini.surround

- BREAKING: always move cursor to the right of left surrounding in `add()`, `delete()`, and `replace()` (instead of moving only if it was on the same line as left surrounding).
- Update process of getting user input: allow `<C-c>` to cancel and make empty string a valid input.


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
