# Contributing

Thank you for your willingness to contribute to 'mini.nvim'. It means a lot!

You can make contributions in the following ways:

- **Create a GitHub issue**. It can be one of two types:
    - **Bug report**. Describe your actions in a reproducible way along with their effect and what you expected should happen. Before making one, please make your best efforts to make sure that it is not an intended behavior (not described in documentation as such).
    - **Feature request**. A concise and justified description of what one or several modules should be able to do. Before making one, please make your best efforts to make sure that it is not a feature that won't get implemented (these should be described in documentation; for example: block comments in 'mini.comment').
- **Create a pull request (PR)**. It can be one of two types:
    - **Code related**. For example, fix a bug or implement a feature. Before even starting one, please make sure that it is aligned with project vision and goals. The best way to do it is to receive a positive feedback from maintainer on your initiative in one of the GitHub issues (existing one or created by you otherwise).
    - **Documentation related**. For example, fix typo/wording in 'README.md', code comments or annotations (which are used to generate Neovim documentation). Feel free to make these without creating a GitHub issue.

All well-intentioned, polite, and respectful contributions are always welcome! Thanks for reading this!

## Formatting

This project uses [StyLua](https://github.com/JohnnyMorganz/StyLua) for formatting Lua code. Before making changes to code, please:

- [Install StyLua](https://github.com/JohnnyMorganz/StyLua#installation).
- Format with it. Currently there are two ways to do this:
    - Manually run `stylua .` from the root directory of this project.
    - [Install pre-commit](https://pre-commit.com/#install) and enable it with `pre-commit install` (from the root directory). This will auto-format relevant code before making commits.
