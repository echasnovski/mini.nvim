<img src="https://github.com/echasnovski/media/blob/main/mini.nvim/logo/logo_test.png" style="width: 100%; max-height: 10em"/>

<!-- badges: start -->
[![GitHub license](https://badgen.net/github/license/echasnovski/mini.nvim)](https://github.com/echasnovski/mini.nvim/blob/main/LICENSE)
<!-- badges: end -->

### Write and use extensive Neovim plugin tests

- Supports hierarchical tests, hooks, parametrization, filtering (like from current file or cursor position), screen tests, "busted-style" emulation, customizable reporters, and more.
- Designed to be used with provided wrapper for managing child Neovim processes.

See more details in [Features](#features) and [help file](../doc/mini-test.txt). For more hands-on introduction based on examples, see [TESTING.md](https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md). For more in-depth usage see ['mini.nvim' tests](https://github.com/echasnovski/mini.nvim/tree/main/tests).

---

⦿ This is a part of [mini.nvim](https://github.com/echasnovski/mini.nvim) library. Please use [this link](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md) if you want to mention this module.

⦿ All contributions (issues, pull requests, discussions, etc.) are done inside of 'mini.nvim'.

⦿ See the repository page to learn about common design principles and configuration recipes.

---

If you want to help this project grow but don't know where to start, check out [contributing guides of 'mini.nvim'](https://github.com/echasnovski/mini.nvim/blob/main/CONTRIBUTING.md) or leave a Github star for 'mini.nvim' project and/or any its standalone Git repositories.

## Demo

https://user-images.githubusercontent.com/24854248/175773105-f33cd3bb-6f62-4a61-95b1-b175e11905bb.mp4

## Features

- Test action is defined as a named callable entry of a table.
- Helper for creating child Neovim process which is designed to be used in tests (including taking and verifying screenshots). See help for `MiniTest.new_child_neovim()` and `Minitest.expect.reference_screenshot()`.
- Hierarchical organization of tests with custom hooks, parametrization, and user data. See help for `MiniTest.new_set()`.
- Emulation of [Olivine-Labs/busted](https://github.com/Olivine-Labs/busted) interface (`describe`, `it`, etc.).
- Predefined small yet usable set of expectations (`assert`-like functions). See help for `MiniTest.expect`.
- Customizable definition of what files should be tested.
- Test case filtering. There are predefined wrappers for testing a file (`MiniTest.run_file()`) and case at a location like current cursor position (`MiniTest.run_at_location()`).
- Customizable reporter of output results. There are two predefined ones:
    - `MiniTest.gen_reporter.buffer()` for interactive usage.
    - `MiniTest.gen_reporter.stdout()` for headless Neovim.
- Customizable project specific testing script.

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
            <td>Main</td> <td><code>{ 'echasnovski/mini.test', version = false },</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>{ 'echasnovski/mini.test', version = '*' },</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>use 'echasnovski/mini.test'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>use { 'echasnovski/mini.test', branch = 'stable' }</code></td>
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
            <td rowspan=2>Standalone plugin</td> <td>Main</td> <td><code>Plug 'echasnovski/mini.test'</code></td>
        </tr>
        <tr>
            <td>Stable</td> <td><code>Plug 'echasnovski/mini.test', { 'branch': 'stable' }</code></td>
        </tr>
    </tbody>
</table>
</details>

<br>

**Important**: don't forget to call `require('mini.test').setup()` to enable its functionality.

**Note**: if you are on Windows, there might be problems with too long file paths (like `error: unable to create file <some file name>: Filename too long`). Try doing one of the following:
- Enable corresponding git global config value: `git config --system core.longpaths true`. Then try to reinstall.
- Install plugin in other place with shorter path.

## Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
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

  -- Whether to disable showing non-error feedback
  silent = false,
}
```

## Similar plugins

- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) ('test_harness', 'busted', 'luassert' modules)
