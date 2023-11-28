<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_visits.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Track and reuse file system visits

See more details in [Features](#features) and [help file](../doc/mini-visits.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-visits.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://github.com/echasnovski/mini.nvim/assets/24854248/ad8ff054-9b95-4e9c-84b1-b39ddba9d7d3

**Note**: This demo uses custom `vim.ui.select()` from [mini.pick](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-pick.md).

## Features

- Persistently track file system visits (both files and directories) per project directory. Store visit index is human readable and editable.

- Visit index is normalized on every write to contain relevant information. Exact details can be customized. See `*MiniVisits.normalize()*`.

- Built-in ability to persistently use label paths for later use. See `*MiniVisits.add_label()*` and `*MiniVisits.remove_label()*`.

- Exported functions to reuse visit data:
    - List visited paths/labels with custom filter and sort (uses "robust frecency" by default). Can be used as source for pickers.

      See `*MiniVisits.list_paths()*` and `*MiniVisits.list_labels()*`. See `*MiniVisits.gen_filter*` and `*MiniVisits.gen_sort*`.

    - Select visited paths/labels using `vim.ui.select()`.

      See `*MiniVisits.select_path()*` and `*MiniVisits.select_labels()*`.

    - Iterate through visit paths in target direction ("forward", "backward", "first", "last"). See `*MiniVisits.iterate_paths()*`.

- Exported functions to manually update visit index allowing persistent track of any user information. See `*_index()` functions.

Notes:
- All data is stored _only_ in in-session Lua variable (for quick operation) and at `config.store.path` on disk (for persistent usage).

- It doesn't account for paths being renamed or moved (because there is no general way to detect that). Usually a manual intervention to the visit index is required after the change but _before_ the next writing to disk (usually before closing current session) because it will treat previous path as deleted and remove it from index.

    There is a `MiniVisits.rename_in_index()` helper for that.
    If rename/move is done with ['mini.files'](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-files.md), index is autoupdated.

For more information, see these tags in help file:

- `*MiniVisits-overview*`
- `*MiniVisits-index-specification*`
- `*MiniVisits-examples*`

## Overview

### Tracking visits

File system visits (both directory and files) tracking is done in two steps:

- On every dedicated event timer is (re)started to actually register visit after certain amount of time.

- When delay time passes without any dedicated events being triggered (meaning user is "settled" on certain buffer), visit is registered if all of the following conditions are met:
    - Module is not disabled.
    - Buffer is normal with non-empty name (used as visit path).
    - Visit path does not equal to the latest tracked one.

Visit is autoregistered for current directory and leads to increase of count
and latest time of visit. See `*MiniVisits-index-specification*` help tag for more details.

Notes:
- All data is stored _only_ in in-session Lua variable (for quick operation) and in one place on disk (for persistent usage). It is automatically written to disk before every Neovim exit.

- Tracking can be disabled by supplying empty string as `track.event`. Then it is up to the user to properly call `MiniVisits.register_visit()`.

### Reusing visits ~

Visit data can be reused in at least these ways:

- Get a list of visited paths and use it to visualize/pick/navigate visit history.

- Select one of the visited paths to open it.

- Move along visit history.

- Utilize labels. Any visit can be added one or more labels (like "core", "tmp", etc.). They are bound to the visit and are stored persistently.

    Labels can be used to manually create groups of files and/or directories that have particular interest to the user.

    There is no one right way to use them, though. See `*MiniVisits-examples*` help tag for some inspiration.

- Utilizing custom data. Visit index can be manipulated manually using
  `_index()` set of functions. All "storeable" user data inside index is then stored on disk, so it can be used to create any kind of workflow user wants.

See `*MiniVisits-examples*` help tag for some actual configuration and workflow examples.

## Installation

This plugin can be installed as part of 'mini.nvim' library (**recommended**) or as a standalone Git repository.

<!-- TODO: Uncomment use of `stable` branch before 0.12.0 release -->

<!-- There are two branches to install from: -->

During beta-testing phase there is only one branch to install from:

- `main` (default, **recommended**) will have latest development version of plugin. All changes since last stable release should be perceived as being in beta testing phase (meaning they already passed alpha-testing and are moderately settled).
<!-- - `stable` will be updated only upon releases with code tested during public beta-testing phase in `main` branch. -->

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
            <!-- <td rowspan=2>'mini.nvim' library</td> -->
            <td rowspan=1>'mini.nvim' library</td>
            <td>Main</td> <td><code>{ 'echasnovski/mini.nvim', version = false },</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>{ 'echasnovski/mini.nvim', version = '*' },</code></td> -->
        <!-- </tr> -->
        <tr>
            <!-- <td rowspan=2>Standalone plugin</td> -->
            <td rowspan=1>Standalone plugin</td>
            <td>Main</td> <td><code>{ 'echasnovski/mini.visits', version = false },</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>{ 'echasnovski/mini.visits', version = '*' },</code></td> -->
        <!-- </tr> -->
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
            <!-- <td rowspan=2>'mini.nvim' library</td> -->
            <td rowspan=1>'mini.nvim' library</td>
            <td>Main</td> <td><code>use 'echasnovski/mini.nvim'</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>use { 'echasnovski/mini.nvim', branch = 'stable' }</code></td> -->
        <!-- </tr> -->
        <tr>
            <!-- <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.visits'</code></td> -->
            <td rowspan=1>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.visits'</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>use { 'echasnovski/mini.visits', branch = 'stable' }</code></td> -->
        <!-- </tr> -->
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
            <!-- <td rowspan=2>'mini.nvim' library</td> -->
            <td rowspan=1>'mini.nvim' library</td>
            <td>Main</td> <td><code>Plug 'echasnovski/mini.nvim'</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>Plug 'echasnovski/mini.nvim', { 'branch': 'stable' }</code></td> -->
        <!-- </tr> -->
        <tr>
            <!-- <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.visits'</code></td> -->
            <td rowspan=1>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.visits'</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>Plug 'echasnovski/mini.visits', { 'branch': 'stable' }</code></td> -->
        <!-- </tr> -->
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.visits').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- How visit index is converted to list of paths
  list = {
    -- Predicate for which paths to include (all by default)
    filter = nil,

    -- Sort paths based on the visit data (robust frecency by default)
    sort = nil,
  },

  -- Whether to disable showing non-error feedback
  silent = false,

  -- How visit index is stored
  store = {
    -- Whether to write all visits before Neovim is closed
    autowrite = true,

    -- Function to ensure that written index is relevant
    normalize = nil,

    -- Path to store visit index
    path = vim.fn.stdpath('data') .. '/mini-visits-index',
  },

  -- How visit tracking is done
  track = {
    -- Start visit register timer at this event
    -- Supply empty string (`''`) to not do this automatically
    event = 'BufEnter',

    -- Debounce delay after event to register a visit
    delay = 1000,
  },
}
```

## Similar plugins

- [nvim-telescope/telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim)
- [ThePrimeagen/harpoon](https://github.com/ThePrimeagen/harpoon)
