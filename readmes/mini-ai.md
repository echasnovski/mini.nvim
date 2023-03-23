<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_ai.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Extend and create `a`/`i` textobjects

- It enhances some builtin textobjects (like `a(`, `a)`, `a'`, and more), creates new ones (like `a*`, `a<Space>`, `af`, `a?`, and more), and allows user to create their own (like based on treesitter, and more).
- Supports dot-repeat, `v:count`, different search methods, consecutive application, and customization via Lua patterns or functions.
- Has builtins for brackets, quotes, function call, argument, tag, user prompt, and any punctuation/digit/whitespace character.

See more details in [Features](#features) and [help file](../doc/mini-ai.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-ai.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://user-images.githubusercontent.com/24854248/181909691-b6f6b677-c37f-468f-85db-8eb8b1e1314e.mp4

## Features

- Customizable creation of `a`/`i` textobjects using Lua patterns and functions. Supports:
    - Dot-repeat.
    - `v:count`.
    - Different search methods (see help for `MiniAi.config`).
    - Consecutive application (update selection without leaving Visual mode).
    - Aliases for multiple textobjects.
- Comprehensive builtin textobjects (see more in help for `MiniAi-textobject-builtin`):
    - Balanced brackets (with and without whitespace) plus alias.
    - Balanced quotes plus alias.
    - Function call.
    - Argument.
    - Tag.
    - Derived from user prompt.
    - Default for punctuation, digit, or whitespace single character.
- Motions for jumping to left/right edge of textobject.
- Set of specification generators to tweak some builtin textobjects (see
  help for `MiniAi.gen_spec`).
- Treesitter textobjects (through `MiniAi.gen_spec.treesitter()` helper).

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.ai', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.ai', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.ai'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.ai', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.ai'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.ai', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.ai').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- Table with textobject id as fields, textobject specification as values.
  -- Also use this to disable builtin textobjects. See |MiniAi.config|.
  custom_textobjects = nil,

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    -- Main textobject prefixes
    around = 'a',
    inside = 'i',

    -- Next/last variants
    around_next = 'an',
    inside_next = 'in',
    around_last = 'al',
    inside_last = 'il',

    -- Move cursor to corresponding edge of `a` textobject
    goto_left = 'g[',
    goto_right = 'g]',
  },

  -- Number of lines within which textobject is searched
  n_lines = 50,

  -- How to search for object (first inside current line, then inside
  -- neighborhood). One of 'cover', 'cover_or_next', 'cover_or_prev',
  -- 'cover_or_nearest', 'next', 'previous', 'nearest'.
  search_method = 'cover_or_next',

  -- Whether to disable showing non-error feedback
  silent = false,
}
```

## Similar plugins

- [wellle/targets.vim](https://github.com/wellle/targets.vim)
- [nvim-treesitter/nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
- [kana/vim-textobj-user](https://github.com/kana/vim-textobj-user)
