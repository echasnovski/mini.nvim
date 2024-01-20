<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_hues.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Generate configurable color scheme

See more details in [Features](#features) and [help file](../doc/mini-hues.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-hues.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://user-images.githubusercontent.com/24854248/236634787-ab0c33df-f697-4d96-a754-d77eccee7513.mp4

Sample screenshots of 'randomhue' color scheme which uses 'mini.hues' with **randomly generated** background and foreground of same hue (color will change on every `:colorscheme randomhue` call):

<img alt="Dark purple" src="https://user-images.githubusercontent.com/24854248/236633651-1c2a69aa-b1d3-4e2a-a537-bf39f94cdfe5.png" style="width: 45%"/> <img alt="Light purple" src="https://user-images.githubusercontent.com/24854248/236633659-87332f44-c7da-4144-9581-5b610f9316bb.png" style="width: 45%"/>

<img alt="Dark azure" src="https://user-images.githubusercontent.com/24854248/236633641-08c21e39-29bb-41bf-ae7a-b93bc1d029f1.png" style="width: 45%"/> <img alt="Light azure" src="https://user-images.githubusercontent.com/24854248/236633654-c4391c94-1f34-4adb-aaaa-235d1cded327.png" style="width: 45%"/>

<img alt="Dark green" src="https://user-images.githubusercontent.com/24854248/236633645-a967617c-74d6-4592-9372-ea5062245b97.png" style="width: 45%"/> <img alt="Light green" src="https://user-images.githubusercontent.com/24854248/236633656-26d11c1c-edca-4735-be60-cfb9a78627ce.png" style="width: 45%"/>

<img alt="Dark orange" src="https://user-images.githubusercontent.com/24854248/236633649-73ea93f6-1cad-492a-9a05-f4c52effa78b.png" style="width: 45%"/> <img alt="Light orange" src="https://user-images.githubusercontent.com/24854248/236633658-0b03cdbd-5c56-4330-871c-fdbedc8668bd.png" style="width: 45%"/>

## Example configurations

```lua
-- Choose background and foreground
require('mini.hues').setup({ background = '#351721', foreground = '#cdc4c6' }) -- red
require('mini.hues').setup({ background = '#361a0d', foreground = '#cdc5c1' }) -- orange
require('mini.hues').setup({ background = '#2c2101', foreground = '#c9c6c0' }) -- yellow
require('mini.hues').setup({ background = '#17280e', foreground = '#c4c8c2' }) -- green
require('mini.hues').setup({ background = '#002923', foreground = '#c0c9c7' }) -- cyan
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc' }) -- azure
require('mini.hues').setup({ background = '#19213a', foreground = '#c4c6cd' }) -- blue
require('mini.hues').setup({ background = '#2b1a33', foreground = '#c9c5cb' }) -- purple

-- Different number of non-base hues
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', n_hues = 6 })
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', n_hues = 4 })
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', n_hues = 2 })
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', n_hues = 0 })

-- Different text saturation
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', saturation = 'low' })
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', saturation = 'medium' })
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', saturation = 'high' })

-- Choose accent color
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', accent = 'yellow' })
require('mini.hues').setup({ background = '#002734', foreground = '#c0c8cc', accent = 'blue' })
```

## Features

- Required to set two base colors: background and foreground. Their shades and other non-base colors are computed to be as much perceptually different as reasonably possible.

- Configurable:
    - Number of hues used for non-base colors (from 0 to 8).
    - Saturation level ('low', 'medium', 'high').
    - Accent color used for some selected UI elements.
    - Plugin integration (can be selectively enabled for faster startup).

- Random generator for base colors. Powers `randomhue` color scheme.

- Lua function to compute palette used in color scheme.

Supported highlight groups:

- All built-in UI and syntax groups.

- Built-in Neovim LSP and diagnostic.

- Tree-sitter.

- LSP semantic tokens.

- Plugins (either with explicit definition or by verification that default highlighting works appropriately):
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
            <td>Main</td> <td><code>{ 'echasnovski/mini.hues', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.hues', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.hues'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.hues', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.hues'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.hues', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.hues').setup()` **with `background` and `foreground` fields** to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- **Required** base colors as '#rrggbb' hex strings
  background = nil,
  foreground = nil,

  -- Number of hues used for non-base colors
  n_hues = 8,

  -- Saturation level. One of 'low', 'medium', 'high'.
  saturation = 'medium',

  -- Accent color. One of: 'bg', 'fg', 'red', 'orange', 'yellow', 'green',
  -- 'cyan', 'azure', 'blue', 'purple'
  accent = 'bg',

  -- Plugin integrations. Use `default = false` to disable all integrations.
  -- Also can be set per plugin (see |MiniHues.config|).
  plugins = { default = true },
}
```

## Similar plugins

- [mini.base16](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-base16.md)
