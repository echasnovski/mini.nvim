<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_colors.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Tweak and save any color scheme

See more details in [Features](#features) and [help file](../doc/mini-colors.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-colors.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://user-images.githubusercontent.com/24854248/232283566-9a51fa55-d20a-4650-8205-763b55e21366.mp4

## Features

- Create colorscheme object (see `*MiniColors-colorscheme*` tag in help file): either manually (`MiniColors.as_colorscheme()`) or by querying present color schemes (including currently active one; see `MiniColors.get_colorscheme()`).

- Infer data about color scheme and/or modify based on it:
    - Add transparency by removing background color (requires transparency in terminal emulator).
    - Infer cterm attributes based on gui colors making it compatible with 'notermguicolors'.
    - Resolve highlight group links.
    - Compress by removing redundant highlight groups.
    - Extract palette of used colors and/or infer terminal colors based on it.

- Modify colors to better fit your taste and/or goals:
    - Apply any function to color hex string.
    - Update channels (like lightness, saturation, hue, temperature, red, green, blue, etc.).
      Use either own function or one of the implemented methods:
        - Add value to channel or multiply it by coefficient. Like "add 10 to saturation of every color" or "multiply saturation by 2" to make colors more saturated (less gray).
        - Invert. Like "invert lightness" to convert between dark/light theme.
        - Set to one or more values (picks closest to current one). Like "set to one or two hues" to make mono- or dichromatic color scheme.
        - Repel from certain source(s) with stronger effect for closer values. Like "repel from hue 30" to remove red color from color scheme. Repel hue (how much is removed) is configurable.
    - Simulate color vision deficiency.

- Once color scheme is ready, either apply it to see effects right away or write it into a Lua file as a fully functioning separate color scheme.

- Experiment interactively with a feedback.

- Animate transition between color schemes either with `MiniColors.animate()` or with `:Colorscheme` user command.

- Convert within supported color spaces (`MiniColors.convert()`):
    - Hex string.
    - 8-bit number (terminal colors).
    - RGB.
    - Oklab, Oklch, Okhsl (https://bottosson.github.io/posts/oklab/).

## Tweak quick start

- Execute `:lua require('mini.colors').interactive()`.
- Experiment by writing calls to exposed color scheme methods and applying them with `<M-a>`. For more information, see `*MiniColors-colorscheme-methods*` and `*MiniColors-recipes*` tags in help file.
- If you are happy with result, write color scheme with `<M-w>`. If not, reset to initial color scheme with `<M-r>`.
- If only some highlight groups can be made better, adjust them manually inside written color scheme file.

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.colors', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.colors', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.colors'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.colors', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.colors'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.colors', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.colors').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{}
```

## Similar plugins

- [rktjmp/lush.nvim](https://github.com/rktjmp/lush.nvim)
- [lifepillar/vim-colortemplate](https://github.com/lifepillar/vim-colortemplate)
- [tjdevries/colorbuddy.nvim](https://github.com/tjdevries/colorbuddy.nvim)
