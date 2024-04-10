<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_diff.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Work with diff hunks

See more details in [Features](#features) and [help file](../doc/mini-diff.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-diff.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://github.com/echasnovski/mini.nvim/assets/24854248/77849127-ee9f-430b-9eff-5a8a724c21ea

## Features

- Visualize difference between buffer text and its configurable reference interactively (updates as you type). This is done per line showing whether it is inside added, changed, or deleted part of difference (called hunk). Visualization can be with customizable colored signs or line numbers.

- Special toggleable overlay view with more hunk details inside text area.

- Completely configurable per buffer source of reference text used to keep it up to date and define interactions with it. By default uses buffer's file content in Git index.

- Configurable mappings to manage diff hunks:
    - Apply and reset hunks inside region (selected visually or with a dot-repeatable operator).
    - "Hunk range under cursor" textobject to be used as operator target.
    - Navigate to first/previous/next/last hunk.

What it doesn't do:

- Provide functionality to work directly with Git outside of visualizing and staging (applying) hunks with (default) Git source. In particular, unstaging hunks is not supported.

To read more information, see these tags in help file:
- `*MiniDiff-overview*`
- `*MiniDiff-source-specification*`
- `*MiniDiff-hunk-specification*`
- `*MiniDiff-diff-summary*`

## Overview

### Diffs and hunks

The "diff" (short for "difference") is a result of computing how two text strings differ from one another. This is done on per line basis, i.e. the goal is to compute sequences of lines common to both files, interspersed with groups of differing lines (called "hunks").

Although computing diff is a general concept (used on its own, in Git, etc.), this module computes difference between current text in a buffer and some reference text which is kept up to date specifically for that buffer. For example, default reference text is computed as file content in Git index. This can be customized in `config.source`.

### Life cycle

- When entering proper (not already enabled, valid, showing text) buffer, it is attempted to be enabled for diff processing.
- During enabling, attempt attaching the source. This should set up how reference text is kept up to date.
- On every text change, diff computation is scheduled in debounced fashion after customizable delay (200 ms by default).
- After the diff is computed, do the following:
    - Update visualization based on configurable style: either by placing colored text in sign column or coloring line numbers. Colors for both styles are defined per hunk type in corresponding `MiniDiffSign*` highlight group and sign text for "sign" style can be configured in `config.view.signs`.
    - Update overlay view (if it is enabled).
    - Update `vim.b.minidiff_summary` and `vim.b.minidiff_summary_string` buffer-local variables. These can be used, for example, in statusline.
    - Trigger `MiniDiffUpdated` `User` event. See `*MiniDiff-diff-summary*` help tag for example of how to use it.

Notes:
- Use `:edit` to reset (disable and re-enable) current buffer.

### Overlay

Along with basic visualization, there is a special view called "overlay". Although it is meant for temporary overview of diff details and can be manually toggled via `MiniDiff.toggle_overlay()`, text can be changed with overlay reacting accordingly.

It shows more diff details inside text area:

- Added buffer lines are highlighted with `MiniDiffOverAdd` highlight group.
- Deleted reference lines are shown as virtual text and highlighted with `MiniDiffOverDelete` highlight group.
- Changed reference lines are shown as virtual text and highlighted with `MiniDiffOverChange` highlight group.

  "Change" hunks with equal number of buffer and reference lines have special treatment and show "word diff". Reference line is shown next to its buffer counterpart and only changed parts of both lines are highlighted with `MiniDiffOverChange`. The rest of reference line has `MiniDiffOverContext` highlighting.

  This usually is the case when `config.options.linematch` is enabled.

### Mappings

This module provides mappings for common actions with diffs, like:
- Apply and reset hunks.
- "Hunk range under cursor" textobject.
- Go to first/previous/next/last hunk range.

Examples:
- `vip` followed by `gh` / `gH` applies/resets hunks inside current paragraph. Same can be achieved in operator form `ghip` / `gHip`, which has the advantage of being dot-repeatable.
- `gh_` / `gH_` applies/resets current line (even if it is not a full hunk).
- `ghgh` / `gHgh` applies/resets hunk range under cursor.
- `dgh` deletes hunk range under cursor.
- `[H` / `[h` / `]h` / `]H` navigate cursor to the first / previous / next / last hunk range of the current buffer.

### Buffer-local variables

Each enabled buffer has the following buffer-local variables which can be used in custom statusline to show an overview of hunks in current buffer:

- `vim.b.minidiff_summary` is a table with the following fields:
    - `source_name` - name of the source.
    - `n_ranges` - number of hunk ranges (sequences of contiguous hunks).
    - `add` - number of added lines.
    - `change` - number of changed lines.
    - `delete` - number of deleted lines.

- `vim.b.minidiff_summary_string` is a string representation of summary with a fixed format. It is expected to be used as is. To achieve different formatting, use `vim.b.minidiff_summary` to construct one. The best way to do this is by overriding `vim.b.minidiff_summary_string` in the callback for `MiniDiffUpdated` event:

    ```lua
    local format_summary = function(data)
      local summary = vim.b[data.buf].minidiff_summary
      local t = {}
      if summary.add > 0 then table.insert(t, '+' .. summary.add) end
      if summary.change > 0 then table.insert(t, '~' .. summary.change) end
      if summary.delete > 0 then table.insert(t, '-' .. summary.delete) end
      vim.b[data.buf].minidiff_summary_string = table.concat(t, ' ')
    end
    local au_opts = { pattern = 'MiniDiffUpdated', callback = format_summary }
    vim.api.nvim_create_autocmd('User', au_opts)
    ```

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
            <!-- <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>add('echasnovski/mini.diff')</code></td> -->
            <td rowspan=1>Standalone plugin</td> <td>Main</td> <td><code>add('echasnovski/mini.diff')</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>add({ source = 'echasnovski/mini.diff', checkout = 'stable' })</code></td> -->
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
            <!-- <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>{ 'echasnovski/mini.diff', version = false },</code></td> -->
            <td rowspan=1>Standalone plugin</td> <td>Main</td> <td><code>{ 'echasnovski/mini.diff', version = false },</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>{ 'echasnovski/mini.diff', version = '*' },</code></td> -->
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
            <!-- <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.diff'</code></td> -->
            <td rowspan=1>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.diff'</code></td>
        </tr>
        <!-- <tr> -->
        <!--     <td>Stable</td> <td><code>Plug 'echasnovski/mini.diff', { 'branch': 'stable' }</code></td> -->
        <!-- </tr> -->
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.diff').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- Options for how hunks are visualized
  view = {
    -- Visualization style. Possible values are 'sign' and 'number'.
    -- Default: 'number' if line numbers are enabled, 'sign' otherwise.
    style = vim.go.number and 'number' or 'sign',

    -- Signs used for hunks with 'sign' view
    signs = { add = '▒', change = '▒', delete = '▒' },

    -- Priority of used visualization extmarks
    priority = vim.highlight.priorities.user - 1,
  },

  -- Source for how reference text is computed/updated/etc
  -- Uses content from Git index by default
  source = nil,

  -- Delays (in ms) defining asynchronous processes
  delay = {
    -- How much to wait before update following every text change
    text_change = 200,
  },

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    -- Apply hunks inside a visual/operator region
    apply = 'gh',

    -- Reset hunks inside a visual/operator region
    reset = 'gH',

    -- Hunk range textobject to be used inside operator
    textobject = 'gh',

    -- Go to hunk range in corresponding direction
    goto_first = '[H',
    goto_prev = '[h',
    goto_next = ']h',
    goto_last = ']H',
  },

  -- Various options
  options = {
    -- Diff algorithm. See `:h vim.diff()`.
    algorithm = 'histogram',

    -- Whether to use "indent heuristic". See `:h vim.diff()`.
    indent_heuristic = true,

    -- The amount of second-stage diff to align lines (in Neovim>=0.9)
    linematch = 60,

    -- Whether to wrap around edges during hunk navigation
    wrap_goto = false,
  },
}
```

## Similar plugins

- [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)
