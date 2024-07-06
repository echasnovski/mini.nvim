<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_icons.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Icon provider

See more details in [Features](#features) and [help file](../doc/mini-icons.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-icons.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

![demo-icons_glyph-dark](https://github.com/echasnovski/mini.nvim/assets/24854248/37aedd6b-3b2e-452b-90f9-bfef96acbede)
![demo-icons_ascii](https://github.com/echasnovski/mini.nvim/assets/24854248/18f4527c-a7ee-4d40-9066-4fe8623c5632)
![demo-icons_glyph-light](https://github.com/echasnovski/mini.nvim/assets/24854248/93091aa7-2334-4d6d-9876-b687cfeff8bd)

## Features

- Provide icons with their highlighting via a single `MiniIcons.get()` for various categories: filetype, file/directory path, extension, operating system, LSP kind values. Icons and category defaults can be overridden.

- Configurable styles: "glyph" (icon glyphs) or "ascii" (non-glyph fallback).

- Fixed set of highlight groups (linked to built-in groups by default) for better blend with color scheme.

- Caching for maximum performance.

- Integration with `vim.filetype.add()` and `vim.filetype.match()`.

- Mocking methods of 'nvim-tree/nvim-web-devicons' for better integrations with plugins outside 'mini.nvim'. See `:h MiniIcons.mock_nvim_web_devicons()`.

Notes:

- It is not a goal to become a collection of icons for as much use cases as possible. There are specific criteria for icon data to be included as built-in in each category (see `:h MiniIcons.get()`). The main supported category is "filetype".

## Dependencies

Suggested dependencies:

- Terminal emulator that supports showing special utf8 glyphs, possibly with "overflow" view (displaying is done not in one but two visual cells). Most modern feature-rich terminal emulators support this out of the box: WezTerm, Kitty, Alacritty, iTerm2, Ghostty.

  Not having "overflow" feature only results into smaller icons. Not having support for special utf8 glyphs will result into seemingly random symbols (or question mark squares) instead of icon glyphs.

- Font that supports [Nerd Fonts](https://www.nerdfonts.com) icons from version 3.0.0+ (in particular `nf-md-*` class).
  This should be configured on terminal emulator level either by using font patched with Nerd Fonts icons or using [`NerdFontsSymbolsOnly`](https://github.com/ryanoasis/nerd-fonts/releases) font as a fallback for glyphs that are not supported in main font.

If using terminal emulator and/or font with icon support is impossible, use `config.style = 'ascii'`. It will use a (less visually appealing) set of non-glyph icons.

## Installation

This plugin can be installed as part of 'mini.nvim' library (**recommended**) or as a standalone Git repository.

During beta-testing phase there is only one branch to install from:
<!-- There are two branches to install from: -->

- `main` (default, **recommended**) will have latest development version of plugin. All changes since last stable release should be perceived as being in beta testing phase (meaning they already passed alpha-testing and are moderately settled).
<!-- - `stable` will be updated only upon releases with code tested during public beta-testing phase in `main` branch. -->

Here are code snippets for some common installation methods (use only one):

<details>
<summary>With <a href="https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-deps.md">mini.deps</a></summary>
<table>
    <thead>
        <tr>
            <th>Github repo</th> <th>Branch</th> <th>Code snippet</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <!-- <td rowspan=2>'mini.nvim' library</td> <td>Main</td> <td rowspan=2><i>Follow recommended 'mini.deps' installation</i></td> -->
            <td rowspan=1>'mini.nvim' library</td> <td>Main</td> <td rowspan=1><i>Follow recommended 'mini.deps' installation</i></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> -->
        <!-- </tr> -->
        <tr>
            <td rowspan=1>Standalone plugin</td> <td>Main</td> <td><code>add('echasnovski/mini.icons')</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>add({ source = 'echasnovski/mini.icons', checkout = 'stable' })</code></td> -->
        <!-- </tr> -->
    </tbody>
</table>
</details>

<details>
<summary>With <a href="https://github.com/folke/lazy.nvim">folke/lazy.nvim</a></summary>
<table>
    <thead>
        <tr>
            <th>Github repo</th> <th>Branch</th> <th>Code snippet</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <!-- <td rowspan=2>'mini.nvim' library</td> <td>Main</td> <td><code>{ 'echasnovski/mini.nvim', version = false },</code></td> -->
            <td rowspan=1>'mini.nvim' library</td> <td>Main</td> <td><code>{ 'echasnovski/mini.nvim', version = false },</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>{ 'echasnovski/mini.nvim', version = '*' },</code></td> -->
        <!-- </tr> -->
        <tr>
            <!-- <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>{ 'echasnovski/mini.icons', version = false, main = 'mini.git' },</code></td> -->
            <td rowspan=1>Standalone plugin</td> <td>Main</td> <td><code>{ 'echasnovski/mini.icons', version = false },</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>{ 'echasnovski/mini.icons', version = '*', main = 'mini.git' },</code></td> -->
        <!-- </tr> -->
    </tbody>
</table>
</details>

<details>
<summary>With <a href="https://github.com/junegunn/vim-plug">junegunn/vim-plug</a></summary>
<table>
    <thead>
        <tr>
            <th>Github repo</th> <th>Branch</th> <th>Code snippet</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <!-- <td rowspan=2>'mini.nvim' library</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.nvim'</code></td> -->
            <td rowspan=1>'mini.nvim' library</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.nvim'</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>Plug 'echasnovski/mini.nvim', { 'branch': 'stable' }</code></td> -->
        <!-- </tr> -->
        <tr>
            <!-- <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.icons'</code></td> -->
            <td rowspan=1>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.icons'</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>Plug 'echasnovski/mini.icons', { 'branch': 'stable' }</code></td> -->
        <!-- </tr> -->
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.icons').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- Icon style: 'glyph' or 'ascii'
  style = 'glyph',

  -- Customize per category. See `:h MiniIcons.config` for details.
  default   = {},
  directory = {},
  extension = {},
  file      = {},
  filetype  = {},
  lsp       = {},
  os        = {},
}
```

## Similar plugins

- [nvim-tree/nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)
