# Version 0.3.0.9000 (development)

## mini.jump

- BREAKING: Soft deprecate `config.highlight_delay` in favor of `config.delay.highlight`.
- Implement idle timeout to stop jumping automatically (@annenpolka, #56).
- Update process of querying target symbol: show help message after delay, allow `<C-c>` to stop selecting target.
- Implement `MiniJump.state`: table with useful model-related information.

## mini.sessions

- Implement `MiniSessions.select()` to select session interactively and perform action on it.

## mini.starter

- Update query logic to not allow queries which result into no items.


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
