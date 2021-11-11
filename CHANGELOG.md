# Version 0.1.0.9000 (development)

## mini.pairs

- Implement pair registration with custom mapping functions. More detailed:
    - Implement `MiniPairs.map()`, `MiniPairs.map_buf()`, `MiniPairs.unmap()`, `MiniPairs.unmap_buf()` to (un)make mappings for pairs which automatically register them for `<BS>` and `<CR>`. Note, that this has a minor break of previous behavior: now `MiniPairs.bs()` and `MiniPairs.cr()` don't have any input argument. But default behavior didn't change.
    - Allow setting global pair mappings inside `config` of `MiniPairs.setup()`.

## mini.statusline

- Implement new section `MiniStatusline.section_searchcount()`.

# Version 0.1.0

- Initial stable version.
