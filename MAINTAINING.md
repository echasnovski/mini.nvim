# Maintaining

- See [CONTRIBUTING.md](CONTRIBUTING.md) for how to generate help files, run tests, and format.

## Dual distribution

Modules of 'mini.nvim' are distributed both as part of 'mini.nvim' repository and each one in its standalone repository. All development takes place in 'mini.nvim' while being synced to standalone ones. This is done by keeping track of special `sync` branch which points to the latest commit which was synced to standalone repositories.

Usual workflow involves performing these steps after every commit in 'mini.nvim':

- Ensure current `main` branch has no immediate defects. Usually it means to wait until all CI checks passed.
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

## Implementation details

- Use module's `H.get_config()` helper to get its `config`. This way allows using buffer local configuration.

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
- Regenerate documentation (see [section in CONTRIBUTING.md](CONTRIBUTING.md#generating-help-file)).

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
- Commit changes with message '(mini.xxx) NEW MODULE: initial commit.'. NOTE: it is cleaner to synchronize standalone repositories prior to this commit.
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
- Make annotated tag: `git tag -a v0.xx.0 -m 'Version 0.xx.0'`. Push it.
- Check that all CI has passed.
- Make GitHub release. Get description from copying entries of version's 'CHANGELOG.md' section.
- Move `stable` branch to point at new tag.
- Synchronize standalone repositories.
- Release standalone repositories. It should be enough to use 'scripts/dual_release.sh' like so:
```
# REPLACE `xx` with your version number
TAG_NAME="v0.xx.0" TAG_MESSAGE="Version 0.xx.0" make dual_release
```
- Use development version in 'CHANGELOG.md' ('0.(xx + 1).0.9000'). Commit.
- Check for `TODO`s about actions to be done *after* release.
