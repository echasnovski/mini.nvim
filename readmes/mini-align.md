<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_align.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Align text interactively

See more details in [Features](#features) and [help file](../doc/mini-align.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-align.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://user-images.githubusercontent.com/24854248/191686791-2c8b345a-2bcc-4de7-a065-5e7a36e2eb1a.mp4

## Features

- Alignment is done in three main steps:
    - **Split** lines into parts based on Lua pattern(s) or user-supplied rule.
    - **Justify** parts for certain side(s) to be same width inside columns.
    - **Merge** parts to be lines, with customizable delimiter(s).

    Each main step can be preceded by other steps (pre-steps) to achieve highly customizable outcome. See `steps` value in `:h MiniAlign.config`. For more details, see `:h MiniAlign-glossary` and `:h MiniAlign-algorithm`.
- User can control alignment interactively by pressing customizable modifiers (single keys representing how alignment steps and/or options should change). Some of default modifiers:
    - Press `s` to enter split Lua pattern.
    - Press `j` to choose justification side from available ones ("left", "center", "right", "none").
    - Press `m` to enter merge delimiter.
    - Press `f` to enter filter Lua expression to configure which parts will be affected (like "align only first column").
    - Press `i` to ignore some commonly unwanted split matches.
    - Press `p` to pair neighboring parts so they be aligned together.
    - Press `t` to trim whitespace from parts.
    - Press `<BS>` (backspace) to delete some last pre-step.

    For more details, see `:h MiniAlign-modifiers-builtin` and `:h MiniAlign-examples`.
- Alignment can be done with instant preview (result is updated after each modifier) or without it (result is shown and accepted after non-default split pattern is set).
- Every user interaction is accompanied with helper status message showing relevant information about current alignment process.

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.align', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.align', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.align'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.align', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.align'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.align', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.align').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    start = 'ga',
    start_with_preview = 'gA',
  },

  -- Modifiers changing alignment steps and/or options
  modifiers = {
    -- Main option modifiers
    ['s'] = --<function: enter split pattern>,
    ['j'] = --<function: choose justify side>,
    ['m'] = --<function: enter merge delimiter>,

    -- Modifiers adding pre-steps
    ['f'] = --<function: filter parts by entering Lua expression>,
    ['i'] = --<function: ignore some split matches>,
    ['p'] = --<function: pair parts>,
    ['t'] = --<function: trim parts>,

    -- Delete some last pre-step
    ['<BS>'] = --<function: delete some last pre-step>,

    -- Special configurations for common splits
    ['='] = --<function: enhanced setup for '='>,
    [','] = --<function: enhanced setup for ','>,
    [' '] = --<function: enhanced setup for ' '>,
  },

  -- Default options controlling alignment process
  options = {
    split_pattern = '',
    justify_side = 'left',
    merge_delimiter = '',
  },

  -- Default steps performing alignment (if `nil`, default is used)
  steps = {
    pre_split = {},
    split = nil,
    pre_justify = {},
    justify = nil,
    pre_merge = {},
    merge = nil,
  },

  -- Whether to disable showing non-error feedback
  silent = false,
}
```

## Similar plugins

- [junegunn/vim-easy-align](https://github.com/junegunn/vim-easy-align)
- [godlygeek/tabular](https://github.com/godlygeek/tabular)
- [tommcdo/vim-lion](https://github.com/tommcdo/vim-lion)
- [Vonr/align.nvim](https://github.com/Vonr/align.nvim)
