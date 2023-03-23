<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_doc.png" style="width: 100%"/>

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Generation of help files from EmmyLua-like annotations

See more details in [Features](#features) and [help file](../doc/mini-doc.txt).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-doc.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://user-images.githubusercontent.com/24854248/173044513-755dec35-4f6c-4a51-aa96-5e380f6d744f.mp4

## Features

- Keep documentation next to code by writing EmmyLua-like annotation comments. They will be parsed as is, so formatting should follow built-in guide. However, custom hooks are allowed at many generation stages for more granular management of output help file.
- Generation is done by processing a set of ordered files line by line. Each line can either be considered as a part of documentation block (if it matches certain configurable pattern) or not (considered to be an "afterline" of documentation block). See `MiniDoc.generate()` help for more details.
- Processing is done by using nested data structures (section, block, file, doc) describing certain parts of help file. See `MiniDoc-data-structures` help page for more details.
- Allow flexible customization of output via hook functions.
- Project specific script can be written as plain Lua file with configuratble path. See `MiniDoc.generate()` help for more details.

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.doc', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.doc', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.doc'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.doc', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.doc'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.doc', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.doc').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
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

    -- Applied before output file is written. Takes lines array as argument.
    write_pre = --<function: currently returns its input>,

    -- Applied after output help file is written. Takes doc as argument.
    write_post = --<function: various convenience actions>,
  },

  -- Path (relative to current directory) to script which handles project
  -- specific help file generation (like custom input files, hooks, etc.).
  script_path = 'scripts/minidoc.lua',

  -- Whether to disable showing non-error feedback
  silent = false,
}
```

## Similar plugins

- [tjdevries/tree-sitter-lua](https://github.com/tjdevries/tree-sitter-lua)
- [numToStr/lemmy-help](https://github.com/numToStr/lemmy-help) (command line tool)
