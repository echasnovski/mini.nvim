<img src="logo.png" width="800em"/> <br>

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
[![GitHub tag](https://badgen.net/github/tag/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/tags/)
[![Current version](https://badgen.net/badge/Current%20version/development/cyan)](https://github.com/echasnovski/mini.nvim/blob/main/CHANGELOG.md)
<!-- badges: end -->

Library of 35+ independent Lua modules improving overall [Neovim](https://github.com/neovim/neovim) (version 0.7 and higher) experience with minimal effort. They all share same configuration approaches and general design principles.

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

- With [folke/lazy.nvim](https://github.com/folke/lazy.nvim):

| Branch | Code snippet                                         |
|--------|------------------------------------------------------|
| Main   | `{ 'echasnovski/mini.nvim', version = false },`      |
| Stable | `{ 'echasnovski/mini.nvim', version = '*' },`        |

- With [wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim):

| Branch | Code snippet                                         |
|--------|------------------------------------------------------|
| Main   | `use 'echasnovski/mini.nvim'`                        |
| Stable | `use { 'echasnovski/mini.nvim', branch = 'stable' }` |

- With [junegunn/vim-plug](https://github.com/junegunn/vim-plug):

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

If you are browsing without particular objective and don't know which module to look at:

- To improve your editing experience, start with 'mini.ai', 'mini.operators', 'mini.surround'.
- To improve your general workflow, start with 'mini.bracketed', 'mini.files', 'mini.jump2d', 'mini.pick'.
- To make your Neovim more beautiful, start with 'mini.animate', 'mini.hipatterns', 'mini.hues'.

| Module           | Description                              | Overview                              | Details                               |
|------------------|------------------------------------------|---------------------------------------|---------------------------------------|
| mini.ai          | Extend and create `a`/`i` textobjects    | [README](readmes/mini-ai.md)          | [Help file](doc/mini-ai.txt)          |
| mini.align       | Align text interactively                 | [README](readmes/mini-align.md)       | [Help file](doc/mini-align.txt)       |
| mini.animate     | Animate common Neovim actions            | [README](readmes/mini-animate.md)     | [Help file](doc/mini-animate.txt)     |
| mini.base16      | Base16 colorscheme creation              | [README](readmes/mini-base16.md)      | [Help file](doc/mini-base16.txt)      |
| mini.basics      | Common configuration presets             | [README](readmes/mini-basics.md)      | [Help file](doc/mini-basics.txt)      |
| mini.bracketed   | Go forward/backward with square brackets | [README](readmes/mini-bracketed.md)   | [Help file](doc/mini-bracketed.txt)   |
| mini.bufremove   | Remove buffers                           | [README](readmes/mini-bufremove.md)   | [Help file](doc/mini-bufremove.txt)   |
| mini.clue        | Show next key clues                      | [README](readmes/mini-clue.md)        | [Help file](doc/mini-clue.txt)        |
| mini.colors      | Tweak and save any color scheme          | [README](readmes/mini-colors.md)      | [Help file](doc/mini-colors.txt)      |
| mini.comment     | Comment lines                            | [README](readmes/mini-comment.md)     | [Help file](doc/mini-comment.txt)     |
| mini.completion  | Completion and signature help            | [README](readmes/mini-completion.md)  | [Help file](doc/mini-completion.txt)  |
| mini.cursorword  | Autohighlight word under cursor          | [README](readmes/mini-cursorword.md)  | [Help file](doc/mini-cursorword.txt)  |
| mini.doc         | Generate Neovim help files               | [README](readmes/mini-doc.md)         | [Help file](doc/mini-doc.txt)         |
| mini.extra       | Extra 'mini.nvim' functionality          | [README](readmes/mini-extra.md)       | [Help file](doc/mini-extra.txt)       |
| mini.files       | Navigate and manipulate file system      | [README](readmes/mini-files.md)       | [Help file](doc/mini-files.txt)       |
| mini.fuzzy       | Fuzzy matching                           | [README](readmes/mini-fuzzy.md)       | [Help file](doc/mini-fuzzy.txt)       |
| mini.hipatterns  | Highlight patterns in text               | [README](readmes/mini-hipatterns.md)  | [Help file](doc/mini-hipatterns.txt)  |
| mini.hues        | Generate configurable color scheme       | [README](readmes/mini-hues.md)        | [Help file](doc/mini-hues.txt)        |
| mini.indentscope | Visualize and work with indent scope     | [README](readmes/mini-indentscope.md) | [Help file](doc/mini-indentscope.txt) |
| mini.jump        | Jump to next/previous single character   | [README](readmes/mini-jump.md)        | [Help file](doc/mini-jump.txt)        |
| mini.jump2d      | Jump within visible lines                | [README](readmes/mini-jump2d.md)      | [Help file](doc/mini-jump2d.txt)      |
| mini.map         | Window with buffer text overview         | [README](readmes/mini-map.md)         | [Help file](doc/mini-map.txt)         |
| mini.misc        | Miscellaneous functions                  | [README](readmes/mini-misc.md)        | [Help file](doc/mini-misc.txt)        |
| mini.move        | Move any selection in any direction      | [README](readmes/mini-move.md)        | [Help file](doc/mini-move.txt)        |
| mini.notify      | Show notifications                       | [README](readmes/mini-notify.md)      | [Help file](doc/mini-notify.txt)      |
| mini.operators   | Text edit operators                      | [README](readmes/mini-operators.md)   | [Help file](doc/mini-operators.txt)   |
| mini.pairs       | Autopairs                                | [README](readmes/mini-pairs.md)       | [Help file](doc/mini-pairs.txt)       |
| mini.pick        | Pick anything                            | [README](readmes/mini-pick.md)        | [Help file](doc/mini-pick.txt)        |
| mini.sessions    | Session management                       | [README](readmes/mini-sessions.md)    | [Help file](doc/mini-sessions.txt)    |
| mini.splitjoin   | Split and join arguments                 | [README](readmes/mini-splitjoin.md)   | [Help file](doc/mini-splitjoin.txt)   |
| mini.starter     | Start screen                             | [README](readmes/mini-starter.md)     | [Help file](doc/mini-starter.txt)     |
| mini.statusline  | Statusline                               | [README](readmes/mini-statusline.md)  | [Help file](doc/mini-statusline.txt)  |
| mini.surround    | Surround actions                         | [README](readmes/mini-surround.md)    | [Help file](doc/mini-surround.txt)    |
| mini.tabline     | Tabline                                  | [README](readmes/mini-tabline.md)     | [Help file](doc/mini-tabline.txt)     |
| mini.test        | Test Neovim plugins                      | [README](readmes/mini-test.md)        | [Help file](doc/mini-test.txt)        |
| mini.trailspace  | Trailspace (highlight and remove)        | [README](readmes/mini-trailspace.md)  | [Help file](doc/mini-trailspace.txt)  |
| mini.visits      | Track and reuse file system visits       | [README](readmes/mini-visits.md)      | [Help file](doc/mini-visits.txt)      |

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

- **Disabling**. Each module's core functionality can be disabled globally or locally to buffer. See "Disabling" section in module's help page for more details. See `mini.nvim-disabling-recipes` section in main help file for common recipes.

- **Silencing**. Each module providing non-error feedback can be configured to not do that by setting `config.silent = true` (either inside `setup()` call or on the fly).

- **Highlight groups**. Appearance of module's output is controlled by certain highlight group (see `:h highlight-groups`). To customize them, use `highlight` command. **Note**: currently not many Neovim themes support this plugin's highlight groups; fixing this situation is highly appreciated. To see a more calibrated look, use 'mini.hues', 'mini.base16', or any of plugin's colorscheme.

- **Stability**. Each module upon release is considered to be relatively stable: both in terms of setup and functionality. Any non-bugfix backward-incompatible change will be released gradually as much as possible.

## Plugin colorschemes

This plugin comes with several color schemes (all have both dark and light variants):

- `randomhue` - random background and foreground of the same hue with medium saturation.
- `minicyan` - cyan and grey main colors with medium contrast and saturation palette.
- `minischeme` - blue and yellow main colors with high contrast and saturation palette.

Activate them as regular `colorscheme` (for example, `:colorscheme randomhue` or `:colorscheme minicyan`). You can see how they look in [demo of 'mini.hues'](readmes/mini-hues.md#demo) or [demo of 'mini.base16'](readmes/mini-base16.md#demo).

## Planned modules

This is the list of modules I currently intend to implement eventually (as my free time and dedication will allow), in alphabetical order:

- 'mini.cycle' - cycle through alternatives with pre-defined rules. Something like [monaqa/dial.nvim](https://github.com/monaqa/dial.nvim) and [AndrewRadev/switch.vim](https://github.com/AndrewRadev/switch.vim)
- 'mini.git' - utilities for more convenient work with Git. Actual scope is to be defined.
- 'mini.keymap' - utilities to make non-trivial mappings (like [max397574/better-escape.nvim](https://github.com/max397574/better-escape.nvim) and dot-repeatable mappings).
- 'mini.snippets' - work with snippets. Something like [L3MON4D3/LuaSnip](https://github.com/L3MON4D3/LuaSnip) but only with more straightforward functionality.
- 'mini.statuscolumn' - customizable 'statuscolumn'.
- 'mini.terminals' - coherently manage terminal windows and send text from buffers to terminal windows. Something like [kassio/neoterm](https://github.com/kassio/neoterm).
- 'mini.quickfix' - fuzzy search and preview of quickfix entries. Possibly with some presets for populating quickfix list (like files, help tags, etc.). Similar to [kevinhwang91/nvim-bqf](https://github.com/kevinhwang91/nvim-bqf).
