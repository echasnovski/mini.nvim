<img src="logo.png" width="800em"/> <br>

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
[![GitHub tag](https://badgen.net/github/tag/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/tags/)
[![Current version](https://badgen.net/badge/Current%20version/development/cyan)](https://github.com/echasnovski/mini.nvim/blob/main/CHANGELOG.md)
<!-- badges: end -->

Collection of minimal, independent, and fast Lua modules dedicated to improve [Neovim](https://github.com/neovim/neovim) (version 0.5 and higher) experience. Think about it as "Swiss Army knife" among Neovim plugins: it has many different independent tools (modules) suitable for most common tasks. Each module can be used as a separate sub-plugin without any startup and usage overhead.

If you want to help this project grow but don't know where to start, check out [contributing guides](CONTRIBUTING.md).

## Table of contents

- [Installation](#installation)
- [General principles](#general-principles)
- [Plugin colorscheme](#plugin-colorscheme)
- [Modules](#modules)
    - [mini.base16](#minibase16)
    - [mini.bufremove](#minibufremove)
    - [mini.comment](#minicomment)
    - [mini.completion](#minicompletion)
    - [mini.cursorword](#minicursorword)
    - [mini.doc](#minidoc)
    - [mini.fuzzy](#minifuzzy)
    - [mini.indentscope](#miniindentscope)
    - [mini.jump](#minijump)
    - [mini.jump2d](#minijump2d)
    - [mini.misc](#minimisc)
    - [mini.pairs](#minipairs)
    - [mini.sessions](#minisessions)
    - [mini.starter](#ministarter)
    - [mini.statusline](#ministatusline)
    - [mini.surround](#minisurround)
    - [mini.tabline](#minitabline)
    - [mini.test](#minitest)
    - [mini.trailspace](#minitrailspace)
- [Planned modules](#planned-modules)

## Installation

This plugin offers two branches to install from:

- `main` (default) will have latest development version of plugin. All changes since last stable release should be perceived as being in beta testing phase (meaning they already passed alpha-testing and are moderately settled).
- `stable` will be updated only upon releases with code tested during public beta-testing phase in `main` branch.

There are at least the following ways to install this plugin:

- Using [wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim):

    ```lua
    -- Development
    use 'echasnovski/mini.nvim'

    -- Stable
    use { 'echasnovski/mini.nvim', branch = 'stable' }
    ```

- Using [junegunn/vim-plug](https://github.com/junegunn/vim-plug):

    ```vim
    " Development
    Plug 'echasnovski/mini.nvim'

    " Stable
    Plug 'echasnovski/mini.nvim', { 'branch': 'stable' }
    ```

- Each module is independent and implemented within single file. You can copy corresponding file from 'lua/mini/' directory to your '.config/nvim/lua' directory and use it from there.

Don't forget to call module's `setup()` (if required) to enable its functionality.

## General principles

- **Design**. Each module is designed to solve a particular problem targeting balance between feature-richness (handling as many edge-cases as possible) and simplicity of implementation/support. Granted, not all of them ended up with the same balance, but it is the goal nevertheless.
- **Independence**. Modules are independent of each other and can be run without external dependencies. Although some of them may need dependencies for full experience.
- **Structure**. Each module is a submodule for a placeholder "mini" module. So, for example, "surround" module should be referred to as "mini.surround".  As later will be explained, this plugin can also be referred to as "MiniSurround".
- **Setup**:
    - Each module (if needed) should be setup separately with `require(<name of module>).setup({})` (possibly replace {} with your config table or omit to use defaults).  You can supply only values which differ from defaults, which will be used for the rest ones.
    - Call to module's `setup()` always creates a global Lua object with coherent camel-case name: `require('mini.surround').setup()` creates `_G.MiniSurround`. This allows for a simpler usage of plugin functionality: instead of `require('mini.surround')` use `MiniSurround` (or manually `:lua MiniSurround.*` in command line); available from `v:lua` like `v:lua.MiniSurround`. Considering this, "module" and "Lua object" names can be used interchangeably: 'mini.surround' and 'MiniSurround' will mean the same thing.
    - Each supplied `config` table (aft) is stored in `config` field of global object. Like `MiniSurround.config`.
    - Values of `config`, which affect runtime activity, can be changed on the fly to have effect. For example, `MiniSurround.config.n_lines` can be changed during runtime; but changing `MiniSurround.config.mappings` won't have any effect (as mappings are created once during `setup()`).
- **Disabling**. Each module's core functionality can be disabled globally or buffer-locally by creating appropriate global or buffer-scoped variables equal to `v:true`. See `mini.nvim-disabling-recipes` section in help file for common recipes.
- **Highlight groups**. Appearance of module's output is controlled by certain highlight group (see `:h highlight-groups`). To customize them, use `highlight` command. **Note**: currently not many Neovim themes support this plugin's highlight groups; fixing this situation is highly appreciated.  To see a more calibrated look, use MiniBase16 or plugin's colorscheme `minischeme`.
- **Stability**. Each module upon release is considered to be relatively stable: both in terms of setup and functionality. Any non-bugfix backward-incompatible change will be released gradually as much as possible.

## Plugin colorscheme

This plugin comes with an official colorscheme named `minischeme`. This is a MiniBase16 theme created with faster version of the following Lua code: `require('mini.base16').setup({palette = palette, name = 'minischeme', use_cterm = true})` where `palette` is:
- For dark 'background': `require('mini.base16').mini_palette('#112641', '#e2e98f', 75)`
- For light 'background': `require('mini.base16').mini_palette('#e2e5ca', '#002a83', 75)`

Activate it as a regular `colorscheme`.

All examples use this colorscheme.

## Modules

### mini.base16

Fast implementation of [chriskempson/base16](https://github.com/chriskempson/base16) theme for manually supplied palette. Has unique palette generator which needs only background and foreground colors.

<details><summary><b>DEMO of 'mini.base16'</b></summary>

<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/demo-base16_dark.png" width="400em"/> <img src="https://github.com/echasnovski/media/blob/main/mini.nvim/demo-base16_light.png" width="400em"/>

</details>

Default `config`:

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
}
```

For more information, read 'mini.base16' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [chriskempson/base16-vim](https://github.com/chriskempson/base16-vim)

### mini.bufremove

Buffer removing (unshow, delete, wipeout) while saving window layout.

<details><summary><b>DEMO of 'mini.bufremove'</b></summary>

https://user-images.githubusercontent.com/24854248/173044032-7874cf95-2e41-49fb-8abe-3aa73526972f.mp4

</details>

Default `config`:

```lua
{
  -- Whether to set Vim's settings for buffers (allow hidden buffers)
  set_vim_settings = true,
}
```

For more information, read 'mini.bufremove' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [mhinz/vim-sayonara](https://github.com/mhinz/vim-sayonara)
- [moll/vim-bbye](https://github.com/moll/vim-bbye)

### mini.comment

Fast and familiar per-line code commenting.

<details><summary><b>DEMO of 'mini.comment'</b></summary>

https://user-images.githubusercontent.com/24854248/173044250-1a8bceae-8f14-40e2-a678-31aca0cd6c1a.mp4

</details>

Default `config`:

```lua
{
  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    -- Toggle comment (like `gcip` - comment inner paragraph) for both
    -- Normal and Visual modes
    comment = 'gc',

    -- Toggle comment on current line
    comment_line = 'gcc',

    -- Define 'comment' textobject (like `dgc` - delete whole comment block)
    textobject = 'gc',
  },
  -- Hook functions to be executed at certain stage of commenting
  hooks = {
    -- Before successful commenting. Does nothing by default.
    pre = function() end,
    -- After successful commenting. Does nothing by default.
    post = function() end,
  },
}
```

For more information, read 'mini.comment' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [tpope/vim-commentary](https://github.com/tpope/vim-commentary)
- [preservim/nerdcommenter](https://github.com/preservim/nerdcommenter)
- [b3nj5m1n/kommentary](https://github.com/b3nj5m1n/kommentary)
- [numToStr/Comment.nvim](https://github.com/numToStr/Comment.nvim)

### mini.completion

Async (with customizable 'debounce' delay) 'two-stage chain completion': first builtin LSP, then configurable fallback. Also has functionality for completion item info and function signature (both in floating window appearing after customizable delay).

<details><summary><b>DEMO of 'mini.completion'</b></summary>

https://user-images.githubusercontent.com/24854248/173044355-90bfc230-70c4-4932-b66b-103284558994.mp4

</details>

Default `config`:

```lua
{
  -- Delay (debounce type, in ms) between certain Neovim event and action.
  -- This can be used to (virtually) disable certain automatic actions by
  -- setting very high delay time (like 10^7).
  delay = { completion = 100, info = 100, signature = 50 },

  -- Maximum dimensions of floating windows for certain actions. Action
  -- entry should be a table with 'height' and 'width' fields.
  window_dimensions = {
    info = { height = 25, width = 80 },
    signature = { height = 25, width = 80 },
  },

  -- Way of how module does LSP completion
  lsp_completion = {
    -- `source_func` should be one of 'completefunc' or 'omnifunc'.
    source_func = 'completefunc',

    -- `auto_setup` should be boolean indicating if LSP completion is set up
    -- on every `BufEnter` event.
    auto_setup = true,

    -- `process_items` should be a function which takes LSP
    -- 'textDocument/completion' response items and word to complete. Its
    -- output should be a table of the same nature as input items. The most
    -- common use-cases are custom filtering and sorting. You can use
    -- default `process_items` as `MiniCompletion.default_process_items()`.
    process_items = --<function: filters out snippets; sorts by LSP specs>,
  },

  -- Fallback action. It will always be run in Insert mode. To use Neovim's
  -- built-in completion (see `:h ins-completion`), supply its mapping as
  -- string. Example: to use 'whole lines' completion, supply '<C-x><C-l>'.
  fallback_action = --<function: like `<C-n>` completion>,

  -- Module mappings. Use `''` (empty string) to disable one. Some of them
  -- might conflict with system mappings.
  mappings = {
    force_twostep = '<C-Space>', -- Force two-step completion
    force_fallback = '<A-Space>', -- Force fallback completion
  },

  -- Whether to set Vim's settings for better experience (modifies
  -- `shortmess` and `completeopt`)
  set_vim_settings = true,
}
```

For more information, read 'mini.completion' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [hrsh7th/nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- [Shougo/ddc.vim](https://github.com/Shougo/ddc.vim)

### mini.cursorword

Automatic highlighting of word under cursor (displayed after customizable delay). Current word under cursor can be highlighted differently.

<details><summary><b>DEMO of 'mini.cursorword'</b></summary>

https://user-images.githubusercontent.com/24854248/173044454-0e4ab873-6e73-448d-838f-45f4b2be876b.mp4

</details>

Default `config`:

```lua
{
  -- Delay (in ms) between when cursor moved and when highlighting appeared
  delay = 100,
}
```

For more information, read 'mini.cursorword' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [itchyny/vim-cursorword](https://github.com/itchyny/vim-cursorword)

### mini.doc

Generation of help files from EmmyLua-like annotations. Allows flexible customization of output via hook functions. Used for documenting this plugin.

<details><summary><b>DEMO of 'mini.doc'</b></summary>

https://user-images.githubusercontent.com/24854248/173044513-755dec35-4f6c-4a51-aa96-5e380f6d744f.mp4

</details>

Default `config`:

```lua
{
  -- Lua string pattern to determine if line has documentation annotation.
  -- First capture group should describe possible section id. Default value
  -- means that annotation line should:
  -- - Start with `---` at first column.
  -- - Any non-whitespace after `---` will be treated as new section id.
  -- - Single whitespace at the start of main text will be ignored.
  annotation_pattern = '^%-%-%-(%S*) ?',

  -- Identifier of block annotation lines until first captured identifier
  default_section_id = '@text',

  -- Hooks to be applied at certain stage of document life cycle. Should
  -- modify its input in place (and not return new one).
  hooks = {
    -- Applied to block before anything else
    block_pre = --<function: infers header sections (tag and/or signature)>,

    -- Applied to section before anything else
    section_pre = --<function: replaces current aliases>,

    -- Applied if section has specified captured id
    sections = {
      ['@alias'] = --<function: registers alias in MiniDoc.current.aliases>,
      ['@class'] = --<function>,
      -- For most typical usage see |MiniDoc.afterlines_to_code|
      ['@eval'] = --<function: evaluates lines; replaces with their return>,
      ['@field'] = --<function>,
      ['@param'] = --<function>,
      ['@private'] = --<function: registers block for removal>,
      ['@return'] = --<function>,
      ['@seealso'] = --<function>,
      ['@signature'] = --<function: formats signature of documented object>,
      ['@tag'] = --<function: turns its line in proper tag lines>,
      ['@text'] = --<function: purposefully does nothing>,
      ['@type'] = --<function>,
      ['@usage'] = --<function>,
    },

    -- Applied to section after all previous steps
    section_post = --<function: currently does nothing>,

    -- Applied to block after all previous steps
    block_post = --<function: does many things>,

    -- Applied to file after all previous steps
    file = --<function: adds separator>,

    -- Applied to doc after all previous steps
    doc = --<function: adds modeline>,
  },

  -- Path (relative to current directory) to script which handles project
  -- specific help file generation (like custom input files, hooks, etc.).
  script_path = 'scripts/minidoc.lua',
}
```

For more information, read 'mini.doc' section of [help file](doc/mini.txt) (which is created with this module).

Plugins with similar functionality:

- [tjdevries/tree-sitter-lua](https://github.com/tjdevries/tree-sitter-lua)

### mini.fuzzy

Functions for fast and simple fuzzy matching. It has not only functions to perform fuzzy matching of one string to others, but also a sorter for [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).

<details><summary><b>DEMO of 'mini.fuzzy'</b></summary>

https://user-images.githubusercontent.com/24854248/173044594-3599fcec-02d6-4bb7-a47d-23f8400f6656.mp4

</details>

Default `config`:

```lua
{
  -- Maximum allowed value of match features (width and first match). All
  -- feature values greater than cutoff can be considered "equally bad".
  cutoff = 100,
}
```

For more information, read 'mini.fuzzy' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [nvim-telescope/telescope-fzy-native.nvim](https://github.com/nvim-telescope/telescope-fzy-native.nvim)

### mini.indentscope

Visualize and operate on indent scope. Supports customization of debounce delay, animation style, and different granularity of options for scope computing algorithm.

<details><summary><b>DEMO of 'mini.indentscope'</b></summary>

https://user-images.githubusercontent.com/24854248/173044654-f5f0b928-6bd9-4064-a916-1f980044c7ad.mp4

</details>

Default `config`:

```lua
{
  draw = {
    -- Delay (in ms) between event and start of drawing scope indicator
    delay = 100,

    -- Animation rule for scope's first drawing. A function which, given next
    -- and total step numbers, returns wait time (in ms). See
    -- |MiniIndentscope.gen_animation()| for builtin options. To not use
    -- animation, supply `require('mini.indentscope').gen_animation('none')`.
    animation = --<function: implements constant 20ms between steps>,
  },

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    -- Textobjects
    object_scope = 'ii',
    object_scope_with_border = 'ai',

    -- Motions (jump to respective border line; if not present - body line)
    goto_top = '[i',
    goto_bottom = ']i',
  },

  -- Options which control computation of scope. Buffer local values can be
  -- supplied in buffer variable `vim.b.miniindentscope_options`.
  options = {
    -- Type of scope's border: which line(s) with smaller indent to
    -- categorize as border. Can be one of: 'both', 'top', 'bottom', 'none'.
    border = 'both',

    -- Whether to use cursor column when computing reference indent. Useful to
    -- see incremental scopes with horizontal cursor movements.
    indent_at_cursor = true,

    -- Whether to first check input line to be a border of adjacent scope.
    -- Use it if you want to place cursor on function header to get scope of
    -- its body.
    try_as_border = false,
  },

  -- Which character to use for drawing scope indicator
  symbol = '╎',
}
```

For more information, read 'mini.indentscope' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [lukas-reineke/indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim)
- [michaeljsmith/vim-indent-object](https://github.com/michaeljsmith/vim-indent-object)

### mini.jump

Minimal and fast module for smarter jumping to a single character. Initial idea and implementation by [Adam Blažek](https://github.com/xigoi).

<details><summary><b>DEMO of 'mini.jump'</b></summary>

https://user-images.githubusercontent.com/24854248/173044762-f0f50a73-02df-4432-a79e-54b0ddaa1e48.mp4

</details>

Default `config`:

```lua
{
  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    forward = 'f',
    backward = 'F',
    forward_till = 't',
    backward_till = 'T',
    repeat_jump = ';',
  },

  -- Delay values (in ms) for different functionalities. Set any of them to
  -- a very big number (like 10^7) to virtually disable.
  delay = {
    -- Delay between jump and highlighting all possible jumps
    highlight = 250,

    -- Delay between jump and automatic stop if idle (no jump is done)
    idle_stop = 10000000,
  },
}
```

For more information, read 'mini.jump' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [rhysd/clever-f.vim](https://github.com/rhysd/clever-f.vim)
- [justinmk/vim-sneak](https://github.com/justinmk/vim-sneak)

### mini.jump2d

Minimal and fast Lua plugin for jumping (moving cursor) within visible lines via iterative label filtering. Supports custom jump targets (spots), labels, hooks, allowed windows and lines, and more.

<details><summary><b>DEMO of 'mini.jump2d'</b></summary>

https://user-images.githubusercontent.com/24854248/173044834-b7d428f5-1f5c-4ab5-8563-2c5b7abd3e10.mp4

</details>

Default `config`:

```lua
{
  -- Function producing jump spots (byte indexed) for a particular line.
  -- For more information see |MiniJump2d.start|.
  -- If `nil` (default) - use |MiniJump2d.default_spotter|
  spotter = nil,

  -- Characters used for labels of jump spots (in supplied order)
  labels = 'abcdefghijklmnopqrstuvwxyz',

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
}
```

For more information, read 'mini.jump2d' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [phaazon/hop.nvim](https://github.com/phaazon/hop.nvim) (main inspiration behind this module)
- [ggandor/lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim)

### mini.misc

Collection of miscellaneous useful functions. Like `put()` and `put_text()` which print Lua objects to command line and current buffer respectively.

<details><summary><b>DEMO of 'mini.misc'</b></summary>

https://user-images.githubusercontent.com/24854248/173044891-69b0ccfd-3fe8-4639-bc70-f955bbf4a1a7.mp4

</details>

Default `config`:

```lua
{
  -- Array of fields to make global (to be used as independent variables)
  make_global = { 'put', 'put_text' },
}
```

For more information, read 'mini.misc' section of [help file](doc/mini.txt).

### mini.pairs

Autopairs plugin which has minimal defaults and functionality to do per-key expression mappings.

<details><summary><b>DEMO of 'mini.pairs'</b></summary>

https://user-images.githubusercontent.com/24854248/173044991-18653715-9b4e-444e-a4ba-14eb80bc4e38.mp4

</details>

Default `config`:

```lua
{
  -- In which modes mappings from this `config` should be created
  modes = { insert = true, command = false, terminal = false },

  -- Global mappings. Each right hand side should be a pair information, a
  -- table with at least these fields (see more in |MiniPairs.map|):
  -- - <action> - one of 'open', 'close', 'closeopen'.
  -- - <pair> - two character string for pair to be used.
  -- By default pair is not inserted after `\`, quotes are not recognized by
  -- `<CR>`, `'` does not insert pair after a letter.
  -- Only parts of tables can be tweaked (others will use these defaults).
  mappings = {
    ['('] = { action = 'open', pair = '()', neigh_pattern = '[^\\].' },
    ['['] = { action = 'open', pair = '[]', neigh_pattern = '[^\\].' },
    ['{'] = { action = 'open', pair = '{}', neigh_pattern = '[^\\].' },

    [')'] = { action = 'close', pair = '()', neigh_pattern = '[^\\].' },
    [']'] = { action = 'close', pair = '[]', neigh_pattern = '[^\\].' },
    ['}'] = { action = 'close', pair = '{}', neigh_pattern = '[^\\].' },

    ['"'] = { action = 'closeopen', pair = '""', neigh_pattern = '[^\\].', register = { cr = false } },
    ["'"] = { action = 'closeopen', pair = "''", neigh_pattern = '[^%a\\].', register = { cr = false } },
    ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\].', register = { cr = false } },
  },
}
```

For more information, read 'mini.pairs' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [jiangmiao/auto-pairs](https://github.com/jiangmiao/auto-pairs)
- [windwp/nvim-autopairs](https://github.com/windwp/nvim-autopairs)

### mini.sessions

Session management (read, write, delete) which works using |mksession|. It was heavily inspired by 'vim-startify' and should work out of the box with sessions created by it. Works with global (from configured directory) and local (from current directory) sessions.

<details><summary><b>DEMO of 'mini.sessions'</b></summary>

https://user-images.githubusercontent.com/24854248/173045087-3d18affc-c76f-4d22-8afc-fef687166ef0.mp4

</details>

Default `config`:

```lua
{
  -- Whether to read latest session if Neovim opened without file arguments
  autoread = false,

  -- Whether to write current session before quitting Neovim
  autowrite = true,

  -- Directory where global sessions are stored (use `''` to disable)
  directory = --<"session" subdir of user data directory from |stdpath()|>,

  -- File for local session (use `''` to disable)
  file = 'Session.vim',

  -- Whether to force possibly harmful actions (meaning depends on function)
  force = { read = false, write = true, delete = false },

  -- Hook functions for actions. Default `nil` means 'do nothing'.
  hooks = {
    -- Before successful action
    pre = { read = nil, write = nil, delete = nil },
    -- After successful action
    post = { read = nil, write = nil, delete = nil },
  },

  -- Whether to print session path after action
  verbose = { read = false, write = true, delete = true },
}
```

For more information, read 'mini.sessions' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [mhinz/vim-startify](https://github.com/mhinz/vim-startify)
- [Shatur/neovim-session-manager](https://github.com/Shatur/neovim-session-manager)

### mini.starter

Minimal, fast, and flexible start screen. Displayed items are fully customizable both in terms of what they do and how they look (with reasonable defaults). Item selection can be done using prefix query with instant visual feedback.

<details><summary><b>DEMO of 'mini.starter'</b></summary>

https://user-images.githubusercontent.com/24854248/173045153-19087983-0211-4ab9-8278-909616b53c7e.mp4

</details>

Default `config`:

```lua
{
  -- Whether to open starter buffer on VimEnter. Not opened if Neovim was
  -- started with intent to show something else.
  autoopen = true,

  -- Whether to evaluate action of single active item
  evaluate_single = false,

  -- Items to be displayed. Should be an array with the following elements:
  -- - Item: table with <action>, <name>, and <section> keys.
  -- - Function: should return one of these three categories.
  -- - Array: elements of these three types (i.e. item, array, function).
  -- If `nil` (default), default items will be used (see |mini.starter|).
  items = nil,

  -- Header to be displayed before items. Converted to single string via
  -- `tostring` (use `\n` to display several lines). If function, it is
  -- evaluated first. If `nil` (default), polite greeting will be used.
  header = nil,

  -- Footer to be displayed after items. Converted to single string via
  -- `tostring` (use `\n` to display several lines). If function, it is
  -- evaluated first. If `nil` (default), default usage help will be shown.
  footer = nil,

  -- Array  of functions to be applied consecutively to initial content.
  -- Each function should take and return content for 'Starter' buffer (see
  -- |mini.starter| and |MiniStarter.content| for more details).
  content_hooks = nil,

  -- Characters to update query. Each character will have special buffer
  -- mapping overriding your global ones. Be careful to not add `:` as it
  -- allows you to go into command mode.
  query_updaters = 'abcdefghijklmnopqrstuvwxyz0123456789_-.',
}
```

For more information, read 'mini.starter' section of [help file](doc/mini.txt) (also contains example configurations similar to 'vim-startify' and 'dashboard-nvim'). For its benchmarks alongside plugins with similar functionality, see [benchmarks/starter/startup-summary.md](benchmarks/starter/startup-summary.md) (more details [here](benchmarks/starter/README.md)).

Plugins with similar functionality:

- [mhinz/vim-startify](https://github.com/mhinz/vim-startify)
- [glepnir/dashboard-nvim](https://github.com/glepnir/dashboard-nvim)
- [goolord/alpha-nvim](https://github.com/goolord/alpha-nvim)

### mini.statusline

Minimal and fast statusline. Has ability to use custom content supplied with concise function (using module's provided section functions) along with builtin default. For full experience needs [Nerd font](https://www.nerdfonts.com/), [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) plugin, and [kyazdani42/nvim-web-devicons](https://github.com/kyazdani42/nvim-web-devicons) plugin (but works without any them).

<details><summary><b>DEMO of 'mini.statusline'</b></summary>

https://user-images.githubusercontent.com/24854248/173045208-42463c8f-a2ac-488d-9d30-216891f4bb51.mp4

</details>

Default `config`:

```lua
{
  -- Content of statusline as functions which return statusline string. See
  -- `:h statusline` and code of default contents (used instead of `nil`).
  content = {
    -- Content for active window
    active = nil,
    -- Content for inactive window(s)
    inactive = nil,
  },

  -- Whether to use icons by default
  use_icons = true,

  -- Whether to set Vim's settings for statusline (make it always shown with
  -- 'laststatus' set to 2). To use global statusline in Neovim>=0.7.0, set
  -- this to `false` and 'laststatus' to 3.
  set_vim_settings = true,
}
```

For more information, read 'mini.statusline' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [hoob3rt/lualine.nvim](https://github.com/hoob3rt/lualine.nvim)
- [NTBBloodbath/galaxyline.nvim](https://github.com/NTBBloodbath/galaxyline.nvim)
- [famiu/feline.nvim](https://github.com/famiu/feline.nvim)

### mini.surround

Fast surround plugin. Add, delete, replace, find, highlight surrounding (like pair of parenthesis, quotes, etc.). Has special "function call", "tag", and "interactive" surroundings. Supports dot-repeatability, textobject, motions.

<details><summary><b>DEMO of 'mini.surround'</b></summary>

https://user-images.githubusercontent.com/24854248/173045302-cc4fd421-cc33-4924-a95b-207097973b48.mp4

</details>

Default `config`:

```lua
{
  -- Add custom surroundings to be used on top of builtin ones. For more
  -- information with examples, see `:h MiniSurround.config`.
  custom_surroundings = nil,

  -- Duration (in ms) of highlight when calling `MiniSurround.highlight()`
  highlight_duration = 500,

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    add = 'sa', -- Add surrounding in Normal and Visual modes
    delete = 'sd', -- Delete surrounding
    find = 'sf', -- Find surrounding (to the right)
    find_left = 'sF', -- Find surrounding (to the left)
    highlight = 'sh', -- Highlight surrounding
    replace = 'sr', -- Replace surrounding
    update_n_lines = 'sn', -- Update `n_lines`
  },

  -- Number of lines within which surrounding is searched
  n_lines = 20,

  -- How to search for surrounding (first inside current line, then inside
  -- neighborhood). One of 'cover', 'cover_or_next', 'cover_or_prev',
  -- 'cover_or_nearest'. For more details, see `:h MiniSurround.config`.
  search_method = 'cover',
}
```

For more information, read 'mini.surround' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [tpope/vim-surround](https://github.com/tpope/vim-surround)
- [machakann/vim-sandwich](https://github.com/machakann/vim-sandwich)

### mini.tabline

Minimal tabline which always shows listed (see `:h buflisted`) buffers. Allows showing extra information section in case of multiple vim tabpages. For full experience needs [kyazdani42/nvim-web-devicons](https://github.com/kyazdani42/nvim-web-devicons).

<details><summary><b>DEMO of 'mini.tabline'</b></summary>

https://user-images.githubusercontent.com/24854248/173045373-f5bdea82-fe3e-4488-8c9a-ebba062a373c.mp4

</details>

Default `config`:

```lua
{
  -- Whether to show file icons (requires 'kyazdani42/nvim-web-devicons')
  show_icons = true,

  -- Whether to set Vim's settings for tabline (make it always shown and
  -- allow hidden buffers)
  set_vim_settings = true,

  -- Where to show tabpage section in case of multiple vim tabpages.
  -- One of 'left', 'right', 'none'.
  tabpage_section = 'left',
}
```

For more information, read 'mini.tabline' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [akinsho/bufferline.nvim](https://github.com/akinsho/bufferline.nvim)
- [ap/vim-buftabline](https://github.com/ap/vim-buftabline)

### mini.test

Framework for writing extensive Neovim plugin tests. Supports hierarchical tests, hooks, parametrization, filtering (like from current file or cursor position), screen tests, "busted-style" emulation, customizable reporters, and more. Designed to be used with provided wrapper for managing child Neovim processes.

<details><summary><b>DEMO of 'mini.test'</b></summary>

https://user-images.githubusercontent.com/24854248/175773105-f33cd3bb-6f62-4a61-95b1-b175e11905bb.mp4

</details>

Default `config`:

```lua
{
  -- Options for collection of test cases. See `:h MiniTest.collect()`.
  collect = {
    -- Temporarily emulate functions from 'busted' testing framework
    -- (`describe`, `it`, `before_each`, `after_each`, and more)
    emulate_busted = true,

    -- Function returning array of file paths to be collected.
    -- Default: all Lua files in 'tests' directory starting with 'test_'.
    find_files = function()
      return vim.fn.globpath('tests', '**/test_*.lua', true, true)
    end,

    -- Predicate function indicating if test case should be executed
    filter_cases = function(case) return true end,
  },

  -- Options for execution of test cases. See `:h MiniTest.execute()`.
  execute = {
    -- Table with callable fields `start()`, `update()`, and `finish()`
    reporter = nil,

    -- Whether to stop execution after first error
    stop_on_error = false,
  },

  -- Path (relative to current directory) to script which handles project
  -- specific test running
  script_path = 'scripts/minitest.lua',
}
```

Further reading:
- For more detailed information, read 'mini.test' section of [help file](doc/mini.txt).
- For more hands-on introduction based on examples, see [TESTING.md](TESTING.md).
- For more in-depth usage see [tests](tests) of this plugin.

Plugins with similar functionality:

- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) ('test_harness', 'busted', 'luassert' modules)

### mini.trailspace

Automatic highlighting of trailing whitespace with functionality to remove it.

<details><summary><b>DEMO of 'mini.trailspace'</b></summary>

https://user-images.githubusercontent.com/24854248/173045420-7aaf21b6-1d2e-4333-8a23-dea7e49c3a01.mp4

</details>

Default `config`:

```lua
{
  -- Highlight only in normal buffers (ones with empty 'buftype'). This is
  -- useful to not show trailing whitespace where it usually doesn't matter.
  only_in_normal_buffers = true,
}
```

For more information, read 'mini.trailspace' section of [help file](doc/mini.txt).

Plugins with similar functionality:

- [ntpeters/vim-better-whitespace](https://github.com/ntpeters/vim-better-whitespace)

## Planned modules

This is the list of modules I currently intend to implement eventually (as my free time and dedication will allow):

- 'mini.align' - fast text alignment. Something like [tommcdo/vim-lion](https://github.com/tommcdo/vim-lion).
- 'mini.terminal' (or 'mini.repl') - coherently manage terminal windows and send text from buffers to terminal windows. Something like [kassio/neoterm](https://github.com/kassio/neoterm).
- 'mini.exchange' (or 'mini.swap') - exchange two regions of text. Something like [tommcdo/vim-exchange](https://github.com/tommcdo/vim-exchange).
- 'mini.arguments' - work with listed arguments. Something like [FooSoft/vim-argwrap](https://github.com/FooSoft/vim-argwrap) and [AndrewRadev/sideways.vim](https://github.com/AndrewRadev/sideways.vim).
- 'mini.tree' - file tree explorer. Truncated version of [kyazdani42/nvim-tree](https://github.com/kyazdani42/nvim-tree.lua).
