<img src="logo.png" width="800em"/> <br>

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
[![GitHub tag](https://badgen.net/github/tag/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/tags/)
[![Current version](https://badgen.net/badge/Current%20version/development/cyan)](https://github.com/echasnovski/mini.nvim/blob/main/CHANGELOG.md)
<!-- badges: end -->

Library of 20+ independent Lua modules improving overall [Neovim](https://github.com/neovim/neovim) (version 0.6 and higher) experience with minimal effort. They all share same configuration approaches and general design principles.

Think about this project as "Swiss Army knife" among Neovim plugins: it has many different independent tools (modules) suitable for most common tasks. Each module can be used separately without any startup and usage overhead.

If you want to help this project grow but don't know where to start, check out [contributing guides](CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Table of contents

- [Installation](#installation)
- [Modules](#modules)
- [General principles](#general-principles)
- [Plugin colorschemes](#plugin-colorschemes)
- [Planned modules](#planned-modules)

## Installation

There are two branches to install from:

- `main` (default, **recommended**) will have latest development version of plugin. All changes since last stable release should be perceived as being in beta testing phase (meaning they already passed alpha-testing and are moderately settled).
- `stable` will be updated only upon releases with code tested during public beta-testing phase in `main` branch.

Here are code snippets for some common installation methods:

- Using [wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim):

| Branch | Code snippet                                         |
|--------|------------------------------------------------------|
| Main   | `use 'echasnovski/mini.nvim'`                        |
| Stable | `use { 'echasnovski/mini.nvim', branch = 'stable' }` |

- Using [junegunn/vim-plug](https://github.com/junegunn/vim-plug):

| Branch | Code snippet                                           |
|--------|--------------------------------------------------------|
| Main   | `Plug 'echasnovski/mini.nvim'`                         |
| Stable | `Plug 'echasnovski/mini.nvim', { 'branch': 'stable' }` |

- Every module is also distributed as a standalone Git repository. Check out module's information for more details.

**Important**: don't forget to call module's `setup()` (if required) to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Modules

| Module           | Description                                 | Overview                              | Details                               |
|------------------|---------------------------------------------|---------------------------------------|---------------------------------------|
| mini.ai          | Extend and create `a`/`i` textobjects       | [README](readmes/mini-ai.md)          | [Help file](doc/mini-ai.txt)          |
| mini.align       | Align text interactively                    | [README](readmes/mini-align.md)       | [Help file](doc/mini-align.txt)       |
| mini.base16      | Base16 colorscheme creation                 | [README](readmes/mini-base16.md)      | [Help file](doc/mini-base16.txt)      |
| mini.bufremove   | Remove buffers                              | [README](readmes/mini-bufremove.md)   | [Help file](doc/mini-bufremove.txt)   |
| mini.comment     | Comment                                     | [README](readmes/mini-comment.md)     | [Help file](doc/mini-comment.txt)     |
| mini.completion  | Completion and signature help               | [README](readmes/mini-completion.md)  | [Help file](doc/mini-completion.txt)  |
| mini.cursorword  | Autohighlight word under cursor             | [README](readmes/mini-cursorword.md)  | [Help file](doc/mini-cursorword.txt)  |
| mini.doc         | Generate Neovim help files                  | [README](readmes/mini-doc.md)         | [Help file](doc/mini-doc.txt)         |
| mini.fuzzy       | Fuzzy matching                              | [README](readmes/mini-fuzzy.md)       | [Help file](doc/mini-fuzzy.txt)       |
| mini.indentscope | Visualize and operate on indent scope       | [README](readmes/mini-indentscope.md) | [Help file](doc/mini-indentscope.txt) |
| mini.jump        | Jump forward/backward to a single character | [README](readmes/mini-jump.md)        | [Help file](doc/mini-jump.txt)        |
| mini.jump2d      | Jump within visible lines                   | [README](readmes/mini-jump2d.md)      | [Help file](doc/mini-jump2d.txt)      |
| mini.map         | Window with buffer text overview            | [README](readmes/mini-map.md)         | [Help file](doc/mini-map.txt)         |
| mini.misc        | Miscellaneous functions                     | [README](readmes/mini-misc.md)        | [Help file](doc/mini-misc.txt)        |
| mini.pairs       | Autopairs                                   | [README](readmes/mini-pairs.md)       | [Help file](doc/mini-pairs.txt)       |
| mini.sessions    | Session management                          | [README](readmes/mini-sessions.md)    | [Help file](doc/mini-sessions.txt)    |
| mini.starter     | Start screen                                | [README](readmes/mini-starter.md)     | [Help file](doc/mini-starter.txt)     |
| mini.statusline  | Statusline                                  | [README](readmes/mini-statusline.md)  | [Help file](doc/mini-statusline.txt)  |
| mini.surround    | Surround actions                            | [README](readmes/mini-surround.md)    | [Help file](doc/mini-surround.txt)    |
| mini.tabline     | Tabline                                     | [README](readmes/mini-tabline.md)     | [Help file](doc/mini-tabline.txt)     |
| mini.test        | Test Neovim plugins                         | [README](readmes/mini-test.md)        | [Help file](doc/mini-test.txt)        |
| mini.trailspace  | Trailspace (highlight and remove)           | [README](readmes/mini-trailspace.md)  | [Help file](doc/mini-trailspace.txt)  |

<a name='mini.ai'></a>
### mini.ai

Extend and create `a`/`i` textobjects (like in `di(` or `va"`).

- It enhances some builtin textobjects (like `a(`, `a)`, `a'`, and more), creates new ones (like `a*`, `a<Space>`, `af`, `a?`, and more), and allows user to create their own (like based on treesitter, and more).
- Supports dot-repeat, `v:count`, different search methods, consecutive application, and customization via Lua patterns or functions.
- Has builtins for brackets, quotes, function call, argument, tag, user prompt, and any punctuation/digit/whitespace character.

For video demo and quick overview see its [README](readmes/mini-ai.md). For more details see its [help file](doc/mini-ai.txt).

---

<a name='mini.align'></a>
### mini.align

Align text interactively (with or without instant preview).

For video demo and quick overview see its [README](readmes/mini-align.md). For more details see its [help file](doc/mini-align.txt).

---

<a name='mini.base16'></a>
### mini.base16

Fast implementation of [chriskempson/base16](https://github.com/chriskempson/base16) theme for manually supplied palette.

- Supports 30+ plugin integrations.
- Has unique palette generator which needs only background and foreground colors.
- Comes with several hand-picked color schemes.

For video demo and quick overview see its [README](readmes/mini-base16.md). For more details see its [help file](doc/mini-base16.txt).

---

<a name='mini.bufremove'></a>
### mini.bufremove

Buffer removing (unshow, delete, wipeout), which saves window layout.

For video demo and quick overview see its [README](readmes/mini-bufremove.md). For more details see its [help file](doc/mini-bufremove.txt).

---

<a name='mini.comment'></a>
### mini.comment

Fast and familiar per-line commenting.

For video demo and quick overview see its [README](readmes/mini-comment.md). For more details see its [help file](doc/mini-comment.txt).

---

<a name='mini.completion'></a>
### mini.completion

Autocompletion and signature help plugin.

- Async (with customizable 'debounce' delay) 'two-stage chain completion': first builtin LSP, then configurable fallback.
- Has functionality for completion item info and function signature (both in floating window appearing after customizable delay).

For video demo and quick overview see its [README](readmes/mini-completion.md). For more details see its [help file](doc/mini-completion.txt).

---

<a name='mini.cursorword'></a>
### mini.cursorword

Automatic highlighting of word under cursor (displayed after customizable delay).

For video demo and quick overview see its [README](readmes/mini-cursorword.md). For more details see its [help file](doc/mini-cursorword.txt).

---

<a name='mini.doc'></a>
### mini.doc

Generation of help files from EmmyLua-like annotations. Allows flexible customization of output via hook functions. Used for documenting this plugin.

For video demo and quick overview see its [README](readmes/mini-doc.md). For more details see its [help file](doc/mini-doc.txt).

---

<a name='mini.fuzzy'></a>
### mini.fuzzy

Minimal and fast fuzzy matching.

For video demo and quick overview see its [README](readmes/mini-fuzzy.md). For more details see its [help file](doc/mini-fuzzy.txt).

---

<a name='mini.indentscope'></a>
### mini.indentscope

Visualize and operate on indent scope. Supports customization of debounce delay, animation style, and different granularity of options for scope computing algorithm.

- Customizable debounce delay, animation style, and scope computation options.
- Implements scope-related motions and textobjects.

For video demo and quick overview see its [README](readmes/mini-indentscope.md). For more details see its [help file](doc/mini-indentscope.txt).

---

<a name='mini.jump'></a>
### mini.jump

Smarter forward/backward jumping to a single character.

For video demo and quick overview see its [README](readmes/mini-jump.md). For more details see its [help file](doc/mini-jump.txt).

---

<a name='mini.jump2d'></a>
### mini.jump2d

Jump  within visible lines via iterative label filtering.

For video demo and quick overview see its [README](readmes/mini-jump2d.md). For more details see its [help file](doc/mini-jump2d.txt).

---

<a name='mini.map'></a>
### mini.map

Window with buffer text overview, scrollbar, and highlights.

For video demo and quick overview see its [README](readmes/mini-map.md). For more details see its [help file](doc/mini-map.txt).

---

<a name='mini.misc'></a>
### mini.misc

Miscellaneous useful functions.

For video demo and quick overview see its [README](readmes/mini-misc.md). For more details see its [help file](doc/mini-misc.txt).

---

<a name='mini.pairs'></a>
### mini.pairs

Minimal and fast autopairs.

For video demo and quick overview see its [README](readmes/mini-pairs.md). For more details see its [help file](doc/mini-pairs.txt).

---

<a name='mini.sessions'></a>
### mini.sessions

Session management (read, write, delete).

For video demo and quick overview see its [README](readmes/mini-sessions.md). For more details see its [help file](doc/mini-sessions.txt).

---

<a name='mini.starter'></a>
### mini.starter

Fast and flexible start screen

For video demo and quick overview see its [README](readmes/mini-starter.md). For more details see its [help file](doc/mini-starter.txt).

---

<a name='mini.statusline'></a>
### mini.statusline

Minimal and fast statusline module with opinionated default look.

For video demo and quick overview see its [README](readmes/mini-statusline.md). For more details see its [help file](doc/mini-statusline.txt).

---

<a name='mini.surround'></a>
### mini.surround

Fast and feature-rich surround plugin

- Add, delete, replace, find, highlight surrounding (like pair of parenthesis, quotes, etc.).
- Supports dot-repeat, `v:count`, different search methods, "last"/"next" extended mappings, customization via Lua patterns or functions, and more.
- Has builtins for brackets, function call, tag, user prompt, and any alphanumeric/punctuation/whitespace character.
- Has maintained configuration of setup similar to 'tpope/vim-surround'.

For video demo and quick overview see its [README](readmes/mini-surround.md). For more details see its [help file](doc/mini-surround.txt).

---

<a name='mini.tabline'></a>
### mini.tabline

Minimal and fast tabline showing listed buffers

For video demo and quick overview see its [README](readmes/mini-tabline.md). For more details see its [help file](doc/mini-tabline.txt).

---

<a name='mini.test'></a>
### mini.test

Write and use extensive Neovim plugin tests

- Supports hierarchical tests, hooks, parametrization, filtering (like from current file or cursor position), screen tests, "busted-style" emulation, customizable reporters, and more.
- Designed to be used with provided wrapper for managing child Neovim processes.

For video demo and quick overview see its [README](readmes/mini-test.md). For more details see its [help file](doc/mini-test.txt).

---

<a name='mini.trailspace'></a>
### mini.trailspace

Work with trailing whitespace

For video demo and quick overview see its [README](readmes/mini-trailspace.md). For more details see its [help file](doc/mini-trailspace.txt).

---

## General principles

- **Design**. Each module is designed to solve a particular problem targeting balance between feature-richness (handling as many edge-cases as possible) and simplicity of implementation/support. Granted, not all of them ended up with the same balance, but it is the goal nevertheless.
- **Independence**. Modules are independent of each other and can be run without external dependencies. Although some of them may need dependencies for full experience.
- **Structure**. Each module is a submodule for a placeholder "mini" module. So, for example, "surround" module should be referred to as "mini.surround".  As later will be explained, this plugin can also be referred to as "MiniSurround".
- **Setup**:
    - Each module (if needed) should be setup separately with `require(<name of module>).setup({})` (possibly replace {} with your config table or omit to use defaults).  You can supply only values which differ from defaults, which will be used for the rest ones.
    - Call to module's `setup()` always creates a global Lua object with coherent camel-case name: `require('mini.surround').setup()` creates `_G.MiniSurround`. This allows for a simpler usage of plugin functionality: instead of `require('mini.surround')` use `MiniSurround` (or manually `:lua MiniSurround.*` in command line); available from `v:lua` like `v:lua.MiniSurround`. Considering this, "module" and "Lua object" names can be used interchangeably: 'mini.surround' and 'MiniSurround' will mean the same thing.
    - Each supplied `config` table is stored in `config` field of global object. Like `MiniSurround.config`.
    - Values of `config`, which affect runtime activity, can be changed on the fly to have effect. For example, `MiniSurround.config.n_lines` can be changed during runtime; but changing `MiniSurround.config.mappings` won't have any effect (as mappings are created once during `setup()`).
- **Buffer local configuration**. Each module can be additionally configured to use certain runtime config settings locally to buffer. See `mini.nvim-buffer-local-config` section in help file for more information.
- **Disabling**. Each module's core functionality can be disabled globally or locally to buffer by creating appropriate global or buffer-scoped variables equal to `v:true`. See `mini.nvim-disabling-recipes` section in help file for common recipes.
- **Highlight groups**. Appearance of module's output is controlled by certain highlight group (see `:h highlight-groups`). To customize them, use `highlight` command. **Note**: currently not many Neovim themes support this plugin's highlight groups; fixing this situation is highly appreciated.  To see a more calibrated look, use MiniBase16 or plugin's colorscheme `minischeme`.
- **Stability**. Each module upon release is considered to be relatively stable: both in terms of setup and functionality. Any non-bugfix backward-incompatible change will be released gradually as much as possible.

## Plugin colorschemes

This plugin comes with several color schemes (all of them are made with 'mini.base16' and have both dark and light variants):

- `minischeme` - blue and yellow main colors with high contrast and saturation palette. All examples use this colorscheme.
- `minicyan` - cyan and grey main colors with moderate contrast and saturation palette.

Activate them as regular `colorscheme` (for example, `:colorscheme minicyan`). You can see how they look in [demo of 'mini.base16'](readmes/mini-base16.md#demo).

## Planned modules

This is the list of modules I currently intend to implement eventually (as my free time and dedication will allow), in alphabetical order:

- 'mini.basics' - configurable collection of options and mappings sets intended mostly for quick "up and running" Neovim config. Something like a combination of [tpope/vim-sensible](https://github.com/tpope/vim-sensible) and [tpope/vim-unimpaired](https://github.com/tpope/vim-unimpaired).
- 'mini.clue' - "show as you type" floating window with customizable information. Something like [folke/which-key.nvim](https://github.com/folke/which-key.nvim) and [anuvyklack/hydra.nvim](https://github.com/anuvyklack/hydra.nvim)
- 'mini.filetree' - file tree viewer. Simplified version of [kyazdani42/nvim-tree](https://github.com/kyazdani42/nvim-tree.lua).
- 'mini.snippets' - work with snippets. Something like [L3MON4D3/LuaSnip](https://github.com/L3MON4D3/LuaSnip) but only with more straightforward functionality.
- 'mini.swap' - exchange two regions of text. Something like [tommcdo/vim-exchange](https://github.com/tommcdo/vim-exchange).
- 'mini.terminals' - coherently manage terminal windows and send text from buffers to terminal windows. Something like [kassio/neoterm](https://github.com/kassio/neoterm).
