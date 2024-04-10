# Maintaining

This document contains knowledge about specifically maintaining 'mini.nvim'. It assumes general knowledge about how Open Source and GitHub issues/PRs work.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to generate help files, run tests, and format.

## General advice

- Follow common boilerplate code as much as possible when creating new module, as it makes easier to use "search and replace" in the long term. This includes:
    - Documentation at the beginning: describing module, its setup, highlight groups, similar plugins, disabling, `setup()`, and `config`.
    - Create and use `H` helper table at the beginning to allow having exported code written before helpers (severely improves readability).
    - Structure of `setup()` function with its helper functions: `H.setup_config()`, `H.apply_config()`, `H.create_autocommands()`, `H.create_default_hl()`, `H.create_user_commands()`.
- Use module's `H.get_config()` and `H.is_disabled()` helpers. They both should respect buffer local configuration.
- From time to time some test cases will break on Neovim Nightly. This is usually due to the following reasons:
    - There was an intended change in Neovim Nightly to which affected module(s) should adapt. Update module and/or tests.
    - There was a change in Neovim Nightly disrupting only tests (usually screenshots due to changed way of how highlight attributes are computed). Update test: ideally so that it passes on all versions, but testing some parts only on Nightly is allowed if needed (usually by regenerating screenshot on Nightly and verifying it only on versions starting from it).
    - There was an unintended change in Neovim Nightly which breaks functionality it should not break. Create an issue in ['neovim/neovim' repo](https://github.com/neovim/neovim). If the issue is not resolved for a long-ish time (i.e. more than a week) try to make tests pass and/or adapt the code to new behavior.

## Maintainer setup

Mandatory:
- Have `nvim` executable for latest stable release.
- Install [`git`](https://www.git-scm.com).
- Install [`StyLua`](https://github.com/JohnnyMorganz/StyLua) with version described in [CONTRIBUTING.md](CONTRIBUTING.md).
- Install [`make`](https://www.gnu.org/software/make/).

Recommended:
- Have executables for all supported Neovim versions. For example, `nvim_07`, `nvim_08`, `nvim_09`, `nvim_010`. This is useful for running tests on multiple versions.
- Install [`lua-language-server`](https://github.com/LuaLS/lua-language-server).
- Install [`pre-commit`](https://pre-commit.com/#install) and enable it with `pre-commit install` and `pre-commit install --hook-type commit-msg` (run from repository's root).
- Set up 'mini.doc' and 'mini.test' and make mappings for the following frequently used commands:
    - `'<Cmd>lua MiniDoc.generate()<CR>'` - to generate documentation.
    - `'<Cmd>lua MiniTest.run_at_location()<CR>'` - to run test under cursor.
    - `'<Cmd>lua MiniTest.run_file()<CR>'` - to run current test file.

## Supported Neovim versions

Aim for supporting 4 latest minor Neovim releases: current stable, current Nightly, and two latest stable releases.

For example, if 0.9.x is current stable, then all latest patch versions of 0.7, 0.8, 0.9 should be supported plus Nightly (0.10.0).

NOTE: some modules can have less supported versions during their release **only** if it is absolutely necessary for the core functionality.

## Dual distribution

Modules of 'mini.nvim' are distributed both as part of 'mini.nvim' repository and each one in its standalone repository. All development takes place in 'mini.nvim' while being synced to standalone ones. This is done by having special `sync` branch which points to the latest commit which was synced to standalone repositories.

Usual workflow involves performing these steps after every commit in 'mini.nvim':

- Check out to `main` branch.
- Ensure there are no immediate defects. Usually it means to wait until all CI checks passed.
- Run `make dual_sync`. This should:
    - Create 'dual' directory if doesn't exist yet.
    - Pull standalone repositories in 'dual/repos'.
    - Create patches in 'dual/patches' and apply them for standalone repositories.

    See 'scripts/dual_sync.sh' for more details.
- Run `make dual_log` to make sure that all and correct patches were applied. If some commit touches files from several modules, it results into commits for every affected standalone repository.
- Run `make dual_push`. This should:
    - Push updates for affected standalone repositories.
    - Clean up 'dual/patches'.
    - Update `sync` branch to point to latest commit and push it to `origin`.

## Typical workflow for adding change

- Solve the problem.
- If change is in code, write test which breaks before problem is solved and passes after.
- If change introduces new config setting, consult with [dedicated checklist](#adding-new-config-settings).
- If change is worth to be seen by users (notable/breaking feature/fix), update 'CHANGELOG.md' following formatting from previous versions.
- Make sure that all tests in affected module(s) pass in all supported versions. See [Maintainer setup](#maintainer-setup) and ['Testing' section in CONTRIBUTING.md](CONTRIBUTING.md#testing).
- Stage and commit changes into a separate Git branch. Push the branch.
- Make sure that all CI pass.
- Merge branch into `main` branch. Push `main`.
- Make sure that all CI pass (again).
- Synchronize dual distribution:
    - `make dual_sync` to sync.
    - `make dual_log` and look at changes which are about to be applied to standalone repositories. Make sure that they are what you'd expect.
    - `make dual_push` to push changes to standalone repositories.

## Typical workflow for processing a GitHub issue

- Add label with module name issue is about (if any). If issue is worded politely and/or with much details, thank user for opening an issue.
- Make sure the underlying problem is valid, i.e. it can be reproduced and the root cause is in this project. If it can not be reproduced, politely explain that and ask for more reproduction details. If the cause is not related to the project, politely explain that, close an issue, and direct towards the real root cause.
- Check already existing issues for possible duplicates. If there is at least one, review its reasoning before making decision about the current issue.
- Decide whether and how an issue should be resolved. Use ["General principles"](README.md#general-principles), module's help and code documentation while making the decision.
    - If decision is to not resolve, politely explain that and close an issue (possibly mentioning similar reasoning in the past).
    - If decision is to resolve, resolve the issue while putting `Resolve #xxx` at the bottom of commit message.

## Typical workflow for processing GitHub pull request

- Add label with module name pull request (PR) is about (if any). If PR is worded politely, thank user for doing that.
- Make sure the PR is valid, i.e. resolves an issue or adds a feature any of which aligns with the project. Ideally, it should have been agreed in the prior created issue (as per [CONTRIBUTING.md](CONTRIBUTING.md)).
- Review PR code and iterate towards making it have enough code quality. Use first steps of ["Typical workflow for adding change"](#typical-workflow-for-adding-change) as reference. **Note**: if what is left to do requires some overly specific project knowledge (i.e. can be done _much_ quicker if you know how, but requires non-trivial amount of reading/discovering first time), consider merging PR in a new separate branch and finish it manually (usually with preserving original commit authorship).
- When change is of enough quality, merge it and proceed treating it as regular change.

## Adding new config settings

- Add code which uses new setting.
- Add default value to `Mini*.config` definition.
- Update module's `H.setup_config()` with type check of new setting.
- Update tests to test default config value and its type check.
- Regenerate help file.
- Update module's README in 'readmes' directory.
- Possibly update demo for it to be aligned with current config values.
- Update 'CHANGELOG.md'. In module's section of current version add line starting with `- FEATURE: Implement ...`.

## Adding new color scheme plugin integration

- Update color scheme module file in a way similar to other already added plugins:
    - Add definitions for highlight groups.
    - Add plugin entry in a list of supported plugins in help annotations.
    - Add plugin entry in a module's README.
- Regenerate documentation (see [corresponding section in CONTRIBUTING.md](CONTRIBUTING.md#generating-help-file)).

## Adding new module

- Add Lua source code in 'lua' directory.
- Add tests in 'tests' directory. Use 'tests/dir-xxx' name for module-specific non-test helpers.
- Update 'lua/init.lua' to mention new module: both in initial table of contents and list of modules.
- Update 'scripts/basic-setup_init.lua' to include new module.
- Update 'scripts/dual_sync.sh' to include new module.
- Update 'scripts/minidoc.lua' to generate separate help file.
- Generate help files.
- Add README to 'readmes' directory. NOTE: comment out mentions of `stable` branch, as it won't work during beta-testing.
- Update main README to mention new module in table of contents.
- Update 'CHANGELOG.md' to mention introduction of new module.
- Update 'CONTRIBUTING.md' to mention new highlight groups (if there are any).
- Commit changes with message 'feat(xxx): add NEW MODULE'. NOTE: it is cleaner to synchronize standalone repositories prior to this commit.
- If there are new highlight groups, follow up with adding explicit support in color scheme modules.
- Make standalone plugin:
    - Create new empty GitHub repository. Disable Issues and limit PRs.
    - Synchronize standalone repositories. It should have created new git repository with single initial commit.
    - Make sure that all tracked files are synchronized. For list of tracked files see 'scripts/dual_sync.sh'. Initially they are 'doc/mini-xxx.txt', 'lua/mini/xxx.lua', 'LICENSE', and 'readmes/mini-xxx.md' (copied to be 'README.md' in standalone repository).
    - Make sure that 'README.md' in standalone repository has appropriate relative links (see patch script).
    - **Amend** initial commit and push.
- Push `main` and sync dual distribution.

## Making stable release

- Check for `TODO`s about actions to be done *before* release.
- Update READMEs of new modules to mention `stable` branch.
- Bump version in 'CHANGELOG.md'. Commit.
- Checkout to `new_release` branch and push to check in CI. **Proceed only if it is successful**.
- Merge `new_release` to `main` and push it.
- Synchronize standalone repositories.
- Make annotated tag: `git tag -a v0.xx.0 -m 'Version 0.xx.0'`. Push it.
- Check that all CI has passed.
- Make GitHub release. Get description from copying entries of version's 'CHANGELOG.md' section.
- Move `stable` branch to point at new tag (`git branch --force stable` when on latest tag's commit). Push it.
- Release standalone repositories. It should be enough to use 'scripts/dual_release.sh' like so:
    ```
    # REPLACE `xx` with your version number
    TAG_NAME="v0.xx.0" TAG_MESSAGE="Version 0.xx.0" make dual_release
    ```
- Use development version in 'CHANGELOG.md' ('0.(xx + 1).0.9000'). Commit.
- Check for `TODO`s about actions to be done *after* release.
