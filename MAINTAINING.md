# Maintaining

- See [CONTRIBUTING.md](CONTRIBUTING.md) for how to generate help files, run tests, and format.

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
- Make standalone plugin:
    - Create new empty GitHub repository. Disable Issues and limit PRs.
    - Create initial structure. For list of tracked files see 'scripts/dual_sync.sh'. Initially they are 'doc/mini-xxx.txt', 'lua/mini/xxx.lua', 'LICENSE', and 'readmes/mini-xxx.md' (copied to be 'README.md' in standalone repository). NOTE: Modify 'README.md' to have appropriate relative links (see patch script).
    - Make initial commit and push.

## Making stable release

- Check for `TODO`s about actions to be done *before* release.
- Update READMEs of new modules to mention `stable` branch.
- Bump version in 'CHANGELOG.md'. Commit.
- Checkout to `new_release` branch and push to check in CI. **Proceed only if it is successful**.
- Make annotated tag: `git tag -a v0.xx.0 -m 'Version 0.xx.0'`. Push it.
- Check that all CI has passed.
- Make GitHub release. Get description from copying entries of version's 'CHANGELOG.md' section.
- Move `stable` branch to point at new tag.
- Manage standalone repositories. It should be enough to use 'scripts/dual_release.sh' like so:
```
# REPLACE `xx` with your version number
TAG_NAME="v0.xx.0" TAG_MESSAGE="Version 0.xx.0" make dual_release
```
- Use development version in 'CHANGELOG.md' ('0.(xx + 1).0.9000'). Commit.
- Check for `TODO`s about actions to be done *after* release.
