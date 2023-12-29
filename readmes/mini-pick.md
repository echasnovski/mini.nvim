<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_pick.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Pick anything

For full experience needs [nvim-tree/nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) plugin and [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) (but works without it).

See more details in [Features](#features) and [help file](../doc/mini-pick.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-pick.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://github.com/echasnovski/mini.nvim/assets/24854248/65849d1e-3f96-4085-a4cf-f9962cfdbdfd

## Features

- Single window general purpose interface for picking element from any array.

- On demand toggleable preview and info views.

- Interactive query matching (filter+sort) with fast non-blocking default which does fuzzy matching and allows other modes.

- Built-in pickers:
    - Files.
    - Pattern match (for fixed pattern and with live feedback).
    - Buffers.
    - Help tags.
    - CLI output.
    - Resume latest picker.

- `:Pick` command to work with extensible `MiniPick.registry`.

- `vim.ui.select()` wrapper.

- Rich and customizable built-in actions when picker is active:
    - Manually change currently focused item.
    - Scroll vertically and horizontally.
    - Toggle preview or info view.
    - Mark/unmark items to choose later.
    - Refine current matches (make them part of a new picker).
    - And many more.

- Minimal yet flexible source specification with:
    - Items (array, callable, or manually set later).
    - Source name.
    - Working directory.
    - Matching algorithm.
    - Way matches are shown in main window.
    - Item preview.
    - "On choice" action for current and marked items.

- Custom actions/keys can be configured globally, per buffer, or per picker.

- Out of the box support for 'ignorecase' and 'smartcase'.

- Match caching to increase responsiveness on repeated prompts.

Notes:
- Works on all supported versions but using Neovim>=0.9 is recommended. Neovim>=0.10 will give more visual feedback in floating window footer.

- For more pickers see ['mini.extra'](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-extra.md).

- CLI tools are called only with basic arguments needed to get items. To customize the output, use their respective configuration approaches. Here are some examples of where to start:
  - [ripgrep](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file)
  - [fd](https://github.com/sharkdp/fd#excluding-specific-files-or-directories)
  - [git](https://git-scm.com/docs/gitignore)

Read more information, see these tags in help file:
- `*MiniPick-overview*`
- `*MiniPick-source*`
- `*MiniPick-actions*`
- `*MiniPick-examples*`
- `*MiniPick.builtin*`

## Overview

General idea is to take array of objects, display them with interactive filter/sort/navigate/preview, and allow to choose one or more items.

### How to start a picker

- Use `MiniPick.start()` with `opts.source` defining source.<br>
  Example: `MiniPick.start({ source = { items = vim.fn.readdir('.') } })`

- Use any of `MiniPick.builtin` pickers directly.<br>
  Example: `MiniPick.builtin.files({ tool = 'git' })`

- Use `:Pick` command which uses customizable pickers from `MiniPick.registry`.<br>
  Example: `:Pick files tool='git'`

### User interface

UI consists from a single window capable of displaying three different views:
- "Main" - where current query matches are shown.
- "Preview" - preview of current item (toggle with `<Tab>`).
- "Info" - general info about picker and its state (toggle with `<S-Tab>`).

Current prompt is displayed (in Neovim>=0.9) at the top left of the window border with vertical line indicating caret (current input position).

Bottom part of window border displays (in Neovim>=0.10) extra visual feedback:
- Left part is a picker name.
- Right part contains information in the format<br>
  `<current index in matches> | <match count> | <marked count> / <total count>`

When picker is busy (like if there are no items yet set or matching is active) window border changes color to be `MiniPickBorderBusy` after `config.delay.busy` milliseconds of idle time.

### Life cycle

- Type characters to filter and sort matches. It uses `MiniPick.default_match()` with `query` being an array of pressed characters.<br>
  Overview of how it matches:
    - If query starts with `'`, the match is exact.
    - If query starts with `^`, the match is exact at start.
    - If query ends with `$`, the match is exact at end.
    - If query starts with `*`, the match is forced to be fuzzy.
    - Otherwise match is fuzzy.
    - Sorting is done to first minimize match width and then match start.
      Nothing more: no favoring certain places in string, etc.

- Type special keys to perform actions. Here are some basic ones:
    - `<C-n>` / `<Down>` moves down; `<C-p>` / `<Up>` moves up.
    - `<Left>` / `<Right>` moves prompt caret left / right.
    - `<S-Tab>` toggles information window with all available mappings.
    - `<Tab>` toggles preview.
    - `<C-x>` / `<C-a>` toggles current / all item(s) as (un)marked.
    - `<C-Space>` / `<M-Space>` makes all matches or marked items as new picker.
    - `<CR>` / `<M-CR>` chooses current/marked item(s).
    - `<Esc>` / `<C-c>` stops picker.

## Installation

This plugin can be installed as part of 'mini.nvim' library (**recommended**) or as a standalone Git repository.

There are two branches to install from:

- `main` (default, **recommended**) will have latest development version of plugin. All changes since last stable release should be perceived as being in beta testing phase (meaning they already passed alpha-testing and are moderately settled).
- `stable` will be updated only upon releases with code tested during public beta-testing phase in `main` branch.

Here are code snippets for some common installation methods (use only one):

<details>
<summary>With <a href="https://github.com/folke/lazy.nvim">folke/lazy.nvim</a></summary>
<table>
    <thead>
        <tr>
            <th>Github repo</th>
            <th>Branch</th> <th>Code snippet</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan=2>'mini.nvim' library</td>
            <td>Main</td> <td><code>{ 'echasnovski/mini.nvim', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.nvim', version = '*' },</code></td>
        </tr>
        <tr>
            <td rowspan=2>Standalone plugin</td>
            <td>Main</td> <td><code>{ 'echasnovski/mini.pick', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.pick', version = '*' },</code></td>
        </tr>
    </tbody>
</table>
</details>

<details>
<summary>With <a href="https://github.com/wbthomason/packer.nvim">wbthomason/packer.nvim</a></summary>
<table>
    <thead>
        <tr>
            <th>Github repo</th>
            <th>Branch</th> <th>Code snippet</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan=2>'mini.nvim' library</td>
            <td>Main</td> <td><code>use 'echasnovski/mini.nvim'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.nvim', branch = 'stable' }</code></td>
        </tr>
        <tr>
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.pick'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.pick', branch = 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<details>
<summary>With <a href="https://github.com/junegunn/vim-plug">junegunn/vim-plug</a></summary>
<table>
    <thead>
        <tr>
            <th>Github repo</th>
            <th>Branch</th> <th>Code snippet</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan=2>'mini.nvim' library</td>
            <td>Main</td> <td><code>Plug 'echasnovski/mini.nvim'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.nvim', { 'branch': 'stable' }</code></td>
        </tr>
        <tr>
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.pick'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.pick', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.pick').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
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
```

## Similar plugins

- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ibhagwan/fzf-lua](https://github.com/ibhagwan/fzf-lua)
