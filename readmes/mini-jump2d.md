<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_jump2d.png" style="width: 100%; max-height: 10em"/>

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Jump  within visible lines via iterative label filtering

See more details in [Features](#features) and [help file](../doc/mini-jump2d.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-jump2d.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://user-images.githubusercontent.com/24854248/227734716-e7b6f2a8-4db1-441d-9b37-873da6772138.mp4

## Features

- Make jump by iterative filtering of possible, equally considered jump spots until there is only one. Filtering is done by typing a label character that is visualized at jump spot.
- Customizable:
    - Way of computing possible jump spots with opinionated default.
    - Characters used to label jump spots during iterative filtering.
    - Visual effects: how many steps ahead to show; dim lines with spots.
    - Action hooks to be executed at certain events during jump.
    - Allowed windows: current and/or not current.
    - Allowed lines: whether to process blank or folded lines, lines before/at/after cursor line, etc. Example: user can configure to look for spots only inside current window at or after cursor line.
    Example: user can configure to look for word starts only inside current window at or after cursor line with 'j' and 'k' labels performing some action after jump.
- Works in Visual and Operator-pending (with dot-repeat) modes.
- Preconfigured ways of computing jump spots (see help for `MiniJump2d.builtin_opts()`).
- Works with multibyte characters.

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.jump2d', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.jump2d', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.jump2d'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.jump2d', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.jump2d'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.jump2d', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.jump2d').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- Function producing jump spots (byte indexed) for a particular line.
  -- For more information see |MiniJump2d.start|.
  -- If `nil` (default) - use |MiniJump2d.default_spotter|
  spotter = nil,

  -- Characters used for labels of jump spots (in supplied order)
  labels = 'abcdefghijklmnopqrstuvwxyz',

  -- Options for visual effects
  view = {
    -- Whether to dim lines with at least one jump spot
    dim = false,

    -- How many steps ahead to show. Set to big number to show all steps.
    n_steps_ahead = 0,
  },

  -- Which lines are used for computing spots
  allowed_lines = {
    blank = true, -- Blank line (not sent to spotter even if `true`)
    cursor_before = true, -- Lines before cursor line
    cursor_at = true, -- Cursor line
    cursor_after = true, -- Lines after cursor line
    fold = true, -- Start of fold (not sent to spotter even if `true`)
  },

  -- Which windows from current tabpage are used for visible lines
  allowed_windows = {
    current = true,
    not_current = true,
  },

  -- Functions to be executed at certain events
  hooks = {
    before_start = nil, -- Before jump start
    after_jump = nil, -- After jump was actually done
  },

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    start_jumping = '<CR>',
  },

  -- Whether to disable showing non-error feedback
  silent = false,
}
```

## Similar plugins

- [phaazon/hop.nvim](https://github.com/phaazon/hop.nvim) (main inspiration behind this module)
- [ggandor/lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim)
- [ggandor/leap.nvim](https://github.com/ggandor/leap.nvim)
- [rlane/pounce.nvim](https://github.com/rlane/pounce.nvim)
