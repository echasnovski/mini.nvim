<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_files.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Navigate and manipulate file system

For full experience needs [nvim-tree/nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) plugin (but works without it).

See more details in [Features](#features) and [help file](../doc/mini-files.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-files.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://github.com/echasnovski/mini.nvim/assets/24854248/530483a5-fe9a-4e18-9813-a6d609fc89ff

## Features

- Navigate file system using column view (Miller columns) to display nested directories. See `*MiniFiles-navigation*` tag in help file for overview.

- Opt-in preview of file or directory under cursor.

- Manipulate files and directories by editing text buffers: create, delete, copy, rename, move. See `*MiniFiles-manipulation*` tag in help file for overview.

- Use as default file explorer instead of `netrw`.

- Configurable:
    - Filter/prefix/sort of file system entries.
    - Mappings used for common explorer actions.
    - UI options: whether to show preview of file/directory under cursor, etc.

See `*MiniFiles-examples*` tag in help file for some common configuration examples.

Notes:

- This module is written and thoroughly tested on Linux. Support for other platform/OS (like Windows or MacOS) is a goal, but there is no guarantee.

- Works on all supported versions but using Neovim>=0.9 is recommended.

- This module silently reacts to not enough permissions:
    - In case of missing file, check its or its parent read permissions.
    - In case of no manipulation result, check write permissions.

## Quick start

### Navigation

- Run `:lua MiniFiles.open()`.

- Navigate:
    - Press `j`/`k` to navigate down/up.
    - Press `l` to expand entry under cursor: show directory or open file in the most recent window.
    - Press `h` to go to parent directory.
    - Type `g?` for more information about other available mappings.
    - Move as in any other buffer (`$`, `G`, `f`/`t`, etc.).

For bigger overview, see `*MiniFiles-navigation*` tag in help file.

### Manipulation

- Navigate to the directory in which manipulation should be done.

- Edit buffer in the way representing file system action:
    - **Create file/directory**: create new line like `file` or `dir/`.
    - **Create file/directory in the descendant directory**: create new line like `dir/file` or `dir/nested/`.
    - **Delete file/directory**: delete whole line representing that entry.
    - **Rename file/directory**: change text to the right of that entry's icon.
    - **Copy file/directory**: copy whole line and paste it in target directory.
    - **Move file/directory**: cut whole line and paste it in target directory.

- Press `=`; **read confirmation dialog**; confirm with `y`/`<CR>` or not confirm with `n`/`<Esc>`.

For bigger overview, see `*MiniFiles-manipulation*` tag in help file.

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.files', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.files', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.files'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.files', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.files'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.files', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.files').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- Customization of shown content
  content = {
    -- Predicate for which file system entries to show
    filter = nil,
    -- What prefix to show to the left of file system entry
    prefix = nil,
    -- In which order to show file system entries
    sort = nil,
  },

  -- Module mappings created only inside explorer.
  -- Use `''` (empty string) to not create one.
  mappings = {
    close       = 'q',
    go_in       = 'l',
    go_in_plus  = 'L',
    go_out      = 'h',
    go_out_plus = 'H',
    reset       = '<BS>',
    reveal_cwd  = '@',
    show_help   = 'g?',
    synchronize = '=',
    trim_left   = '<',
    trim_right  = '>',
  },

  -- General options
  options = {
    -- Whether to delete permanently or move into module-specific trash
    permanent_delete = true,
    -- Whether to use for editing directories
    use_as_default_explorer = true,
  },

  -- Customization of explorer windows
  windows = {
    -- Maximum number of windows to show side by side
    max_number = math.huge,
    -- Whether to show preview of file/directory under cursor
    preview = false,
    -- Width of focused window
    width_focus = 50,
    -- Width of non-focused window
    width_nofocus = 15,
    -- Width of preview window
    width_preview = 25,
  },
}
```

## Similar plugins

- [nvim-tree/nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)
- [stevearc/oil.nvim](https://github.com/stevearc/oil.nvim)
- [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
