# Contributing

Thank you for your willingness to contribute to 'mini.nvim'. It means a lot!

You can make contributions in the following ways:

- **Mention it** somehow to help reach broader audience. This helps a lot.
- **Create a GitHub issue**. It can be one of two types:
    - **Bug report**. Describe your actions in a reproducible way along with their effect and what you expected should happen. Before making one, please make your best efforts to make sure that it is not an intended behavior (not described in documentation as such).
    - **Feature request**. A concise and justified description of what one or several modules should be able to do. Before making one, please make your best efforts to make sure that it is not a feature that won't get implemented (these should be described in documentation; for example: block comments in 'mini.comment').
- **Create a pull request (PR)**. It can be one of two types:
    - **Code related**. For example, fix a bug or implement a feature. **Before even starting one, please make sure that it is aligned with project vision and goals**. The best way to do it is to receive a positive feedback from maintainer on your initiative in one of the GitHub issues (existing one or created by you otherwise). Please, make sure to regenerate latest help file and that all tests are passed (see later sections).
    - **Documentation related**. For example, fix typo/wording in 'README.md', code comments or annotations (which are used to generate Neovim documentation; see later section). Feel free to make these without creating a GitHub issue.
- **Add explicit support to colorschemes**. Any 'mini.nvim' module supports any colorscheme right out of the box. This is done by making most highlight groups be linked to a semantically similar builtin highlight group. Other groups are hard-coded based on personal preference. However, these choices might be out of tune with a particular colorscheme. Updating as many colorschemes as possible to have explicit 'mini.nvim' support is highly appreciated. For your convenience, there is a list of all highlight groups in later section of this file.
- **Participate in [discussions](https://github.com/echasnovski/mini.nvim/discussions)**.

All well-intentioned, polite, and respectful contributions are always welcome! Thanks for reading this!

## Generating help file

If your contribution updates annotations used to generate help file, please regenerate it. You can make this with one of the following (assuming current directory being project root):

- From command line execute `make documentation`.
- Inside Neovim instance run `:luafile scripts/minidoc.lua`.

## Running tests

If your contribution updates code, please make sure that it doesn't break existing tests. If it adds new functionality or fixes a recognized bug, add new test case(s). There are two ways of running tests:

- From command line execute `make test` to run all tests or `FILE=<name of file> make test_file` to run tests only from file `<name of file>`.
- Inside Neovim instance execute `:lua require('mini.test').setup(); MiniTest.run()` to run all tests or `:lua require('mini.test').setup(); MiniTest.run_file()` to run tests only from current buffer.

This plugin uses 'mini.test' to manage its tests. For more hands-on introduction, see [TESTING.md](TESTING.md).

## Formatting

This project uses [StyLua](https://github.com/JohnnyMorganz/StyLua) for formatting Lua code. Before making changes to code, please:

- [Install StyLua](https://github.com/JohnnyMorganz/StyLua#installation).
- Format with it. Currently there are two ways to do this:
    - Manually run `stylua .` from the root directory of this project.
    - [Install pre-commit](https://pre-commit.com/#install) and enable it with `pre-commit install` (from the root directory). This will auto-format relevant code before making commits.

## List of highlight groups

Here is a list of all highlight groups defined inside 'mini.nvim' modules. See documentation in 'doc' directory to find out what they are used for.

- 'mini.completion':
    - `MiniCompletionActiveParameter`

- 'mini.cursorword':
    - `MiniCursorword`
    - `MiniCursorwordCurrent`

- 'mini.indentscope':
    - `MiniIndentscopeSymbol`
    - `MiniIndentscopePrefix`

- 'mini.jump':
    - `MiniJump`

- 'mini.jump2d':
    - `MiniJump2dSpot`

- 'mini.starter':
    - `MiniStarterCurrent`
    - `MiniStarterFooter`
    - `MiniStarterHeader`
    - `MiniStarterInactive`
    - `MiniStarterItem`
    - `MiniStarterItemBullet`
    - `MiniStarterItemPrefix`
    - `MiniStarterSection`
    - `MiniStarterQuery`

- 'mini.statusline':
    - `MiniStatuslineDevinfo`
    - `MiniStatuslineFileinfo`
    - `MiniStatuslineFilename`
    - `MiniStatuslineInactive`
    - `MiniStatuslineModeCommand`
    - `MiniStatuslineModeInsert`
    - `MiniStatuslineModeNormal`
    - `MiniStatuslineModeOther`
    - `MiniStatuslineModeReplace`
    - `MiniStatuslineModeVisual`

- 'mini.surround':
    - `MiniSurround`

- 'mini.tabline':
    - `MiniTablineCurrent`
    - `MiniTablineFill`
    - `MiniTablineHidden`
    - `MiniTablineModifiedCurrent`
    - `MiniTablineModifiedHidden`
    - `MiniTablineModifiedVisible`
    - `MiniTablineTabpagesection`
    - `MiniTablineVisible`

- 'mini.test':
    - `MiniTestEmphasis`
    - `MiniTestFail`
    - `MiniTestPass`

- 'mini.trailspace':
    - `MiniTrailspace`
