<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_clue.png" style="width: 100%">

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Show next key clues

See more details in [Features](#features) and [help file](../doc/mini-clue.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-clue.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://github.com/echasnovski/mini.nvim/assets/24854248/ea931966-067c-48af-93e9-36e9b8afb0ae

## Features

- Implement custom key query process to reach target key combination:
    - Starts after customizable opt-in triggers (mode + keys).

    - Each key press narrows down set of possible targets.

      Pressing `<BS>` removes previous user entry.

      Pressing `<Esc>` or `<C-c>` leads to an early stop.

      Doesn't depend on 'timeoutlen' and has basic support for 'langmap'.

    - Ends when there is at most one target left or user pressed `<CR>`. Results into emulating pressing all query keys plus possible postkeys.

- Show window (after configurable delay) with clues. It lists available next keys along with their descriptions (auto generated from descriptions present keymaps and user-supplied clues; preferring the former).

- Configurable "postkeys" for key combinations - keys which will be emulated after combination is reached during key query process.

- Provide customizable sets of clues for common built-in keys/concepts:
    - `g` key.
    - `z` key.
    - Window commands.
    - Built-in completion.
    - Marks.
    - Registers.

- Lua functions to disable/enable triggers globally or per buffer.

For more details see these tags in help:
- `*MiniClue-key-query-process*`.
- `*MiniClue-examples*`.
- `*MiniClue.config*`.
- `*MiniClue.gen_clues*`.

Notes:
- Works on all supported versions but using Neovim>=0.9 is recommended.

- There is no functionality to create mappings in order to clearly separate two different tasks.

  The best suggested practice is to manually create mappings with descriptions (`desc` field in options), as they will be automatically used inside clue window.

- Triggers are implemented as special buffer-local mappings. This leads to several caveats:
    - They will override same regular buffer-local mappings and have precedence over global one.

      Example: having set `<C-w>` as Normal mode trigger means that there should not be another `<C-w>` mapping.

    - They need to be the latest created buffer-local mappings or they will not function properly. Most common indicator of this is that some mapping starts to work only after clue window is shown.

      Example: `g` is set as Normal mode trigger, but `gcc` from 'mini.comment' doesn't work right away. This is probably because there are some other buffer-local mappings starting with `g` which were created after mapping for `g` trigger. Most common places for this are in LSP server's `on_attach` or during tree-sitter start in buffer.

      To check if trigger is the most recent buffer-local mapping, execute `:<mode-char>map <trigger-keys>` (like `:nmap g` for previous example). Mapping for trigger should be the first listed.

      This module makes the best effort to work out of the box and cover most common cases, but it is not full proof. The solution here is to ensure that triggers are created after making all buffer-local mappings: run either `MiniClue.setup()` or `MiniClue.ensure_buf_triggers()`.

- Descriptions from existing mappings take precedence over user-supplied clues. This is to ensure that information shown in clue window is as relevant as possible. To add/customize description of an already existing mapping, use `MiniClue.set_mapping_desc()`.

- Due to technical difficulties, there is no full proof support for Operator-pending mode triggers (like `a`/`i` from 'mini.ai'):
    - Doesn't work as part of a command in "temporary Normal mode" (like after `<C-o>` in Insert mode) due to implementation difficulties.
    - Can have unexpected behavior with custom operators.

- Has (mostly solved) issues with macros:
    - All triggers are disabled during macro recording due to technical reasons.
    - The `@` and `Q` keys are specially mapped inside `MiniClue.setup()` to temporarily disable triggers.

## Config quick start

```lua
local miniclue = require('mini.clue')
miniclue.setup({
  triggers = {
    -- Leader triggers
    { mode = 'n', keys = '<Leader>' },
    { mode = 'x', keys = '<Leader>' },

    -- Built-in completion
    { mode = 'i', keys = '<C-x>' },

    -- `g` key
    { mode = 'n', keys = 'g' },
    { mode = 'x', keys = 'g' },

    -- Marks
    { mode = 'n', keys = "'" },
    { mode = 'n', keys = '`' },
    { mode = 'x', keys = "'" },
    { mode = 'x', keys = '`' },

    -- Registers
    { mode = 'n', keys = '"' },
    { mode = 'x', keys = '"' },
    { mode = 'i', keys = '<C-r>' },
    { mode = 'c', keys = '<C-r>' },

    -- Window commands
    { mode = 'n', keys = '<C-w>' },

    -- `z` key
    { mode = 'n', keys = 'z' },
    { mode = 'x', keys = 'z' },
  },

  clues = {
    -- Enhance this by adding descriptions for <Leader> mapping groups
    miniclue.gen_clues.builtin_completion(),
    miniclue.gen_clues.g(),
    miniclue.gen_clues.marks(),
    miniclue.gen_clues.registers(),
    miniclue.gen_clues.windows(),
    miniclue.gen_clues.z(),
  },
})
```

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.clue', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.clue', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.clue'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.clue', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.clue'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.clue', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.clue').setup()` to enable its functionality. **Needs to have triggers configured**.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
{
  -- Array of extra clues to show
  clues = {},

  -- Array of opt-in triggers which start custom key query process.
  -- **Needs to have something in order to show clues**.
  triggers = {},

  -- Clue window settings
  window = {
    -- Floating window config
    config = {},

    -- Delay before showing clue window
    delay = 1000,

    -- Keys to scroll inside the clue window
    scroll_down = '<C-d>',
    scroll_up = '<C-u>',
  },
}
```

## Similar plugins

- [folke/which-key.nvim](https://github.com/folke/which-key.nvim)
- [anuvyklack/hydra.nvim](https://github.com/anuvyklack/hydra.nvim)
