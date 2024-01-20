<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_base16.png" style="width: 100%"/>

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Fast implementation of [chriskempson/base16](https://github.com/chriskempson/base16) theme for manually supplied palette

- Supports 30+ plugin integrations.
- Has unique palette generator which needs only background and foreground colors.
- Comes with several hand-picked color schemes.

See more details in [Features](#features) and [help file](../doc/mini-base16.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-base16.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

Using `minischeme` color scheme:

<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/demo/demo-base16_minischeme-dark.png" style="width: 45%"/> <img src="https://github.com/echasnovski/media/blob/main/mini.nvim/demo/demo-base16_minischeme-light.png" style="width: 45%"/>

Using `minicyan` color scheme:

<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/demo/demo-base16_minicyan-dark.png" style="width: 45%"/> <img src="https://github.com/echasnovski/media/blob/main/mini.nvim/demo/demo-base16_minicyan-light.png" style="width: 45%"/>

## Features

Supported highlight groups:
- Built-in Neovim LSP and diagnostic.
- Plugins (either with explicit definition or by verification that default
  highlighting works appropriately):
    - [echasnovski/mini.nvim](https://github.com/echasnovski/mini.nvim)
    - [akinsho/bufferline.nvim](https://github.com/akinsho/bufferline.nvim)
    - [anuvyklack/hydra.nvim](https://github.com/anuvyklack/hydra.nvim)
    - [DanilaMihailov/beacon.nvim](https://github.com/DanilaMihailov/beacon.nvim)
    - [folke/lazy.nvim](https://github.com/folke/lazy.nvim)
    - [folke/noice.nvim](https://github.com/folke/noice.nvim)
    - [folke/todo-comments.nvim](https://github.com/folke/todo-comments.nvim)
    - [folke/trouble.nvim](https://github.com/folke/trouble.nvim)
    - [folke/which-key.nvim](https://github.com/folke/which-key.nvim)
    - [ggandor/leap.nvim](https://github.com/ggandor/leap.nvim)
    - [ggandor/lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim)
    - [glepnir/dashboard-nvim](https://github.com/glepnir/dashboard-nvim)
    - [glepnir/lspsaga.nvim](https://github.com/glepnir/lspsaga.nvim)
    - [HiPhish/rainbow-delimiters.nvim](https://github.com/HiPhish/rainbow-delimiters.nvim)
    - [hrsh7th/nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
    - [justinmk/vim-sneak](https://github.com/justinmk/vim-sneak)
    - [kevinhwang91/nvim-ufo](https://github.com/kevinhwang91/nvim-ufo)
    - [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)
    - [lukas-reineke/indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim)
    - [neoclide/coc.nvim](https://github.com/neoclide/coc.nvim)
    - [NeogitOrg/neogit](https://github.com/NeogitOrg/neogit)
    - [nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
    - [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
    - [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
    - [nvim-tree/nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)
    - [phaazon/hop.nvim](https://github.com/phaazon/hop.nvim)
    - [rcarriga/nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui)
    - [rcarriga/nvim-notify](https://github.com/rcarriga/nvim-notify)
    - [rlane/pounce.nvim](https://github.com/rlane/pounce.nvim)
    - [romgrk/barbar.nvim](https://github.com/romgrk/barbar.nvim)
    - [stevearc/aerial.nvim](https://github.com/stevearc/aerial.nvim)
    - [williamboman/mason.nvim](https://github.com/williamboman/mason.nvim)

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.base16', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.base16', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.base16'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.base16', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.base16'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.base16', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.base16').setup()` with appropriate `palette` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Default config

```lua
{
  -- Table with names from `base00` to `base0F` and values being strings of
  -- HEX colors with format "#RRGGBB". NOTE: this should be explicitly
  -- supplied in `setup()`.
  palette = nil,

  -- Whether to support cterm colors. Can be boolean, `nil` (same as
  -- `false`), or table with cterm colors. See `setup()` documentation for
  -- more information.
  use_cterm = nil,

  -- Plugin integrations. Use `default = false` to disable all integrations.
  -- Also can be set per plugin (see |MiniBase16.config|).
  plugins = { default = true },
}
```

## Similar plugins

- [chriskempson/base16-vim](https://github.com/chriskempson/base16-vim)
