-- MIT License Copyright (c) 2021 Evgeni Chasnovski

-- Documentation ==============================================================
--- Automatically change directory to a project root.
--- Main inspiration is a "mattn/vim-findroot" and "airblade/vim-rooter" plugin.
---
--- Features:
---   Automatically change directory to a project root defined in
---   |MiniAutochdir.config|. The patterns are written in the glob pattern.
---
--- General overview of how to find a project root:
--- - Check whether the designated file or the directory
---   exists in current directory.
--- - If not, move to the parent directory to find a project root.
---
--- # Setup~
--- This module doesn't need setup, but it can be done to improve usability.
--- Setup with `require('mini.autochdir').setup({})` (replace `{}` with your
--- `config` table). It will create global Lua table `MiniAutochdir` which
--- you can use for scripting or manually (with `:lua MiniAutochdir.*`).
---
--- # Example usage~
--- - Modify default root_pattern to find a project root: >
---   require('mini.autochdir').setup({ root_pattern = { '.git' }})
--- - At the time changing a buffer, it also changes CWD.
---
--- # Disabling~
--- To disable, set `g:miniautochdir_disable` (globally) or `b:miniautochdir_disable`
--- (for a buffer) to `v:true`. Considering high number of different scenarios
--- and customization intentions, writing exact rules for disabling module's
--- functionality is left to user. See |mini.nvim-disabling-recipes| for common
--- recipes.
---
--- # Notice~
--- https://github.com/mattn/vim-findroot is an OSS project licensed
--- under the MIT License.
---
---@tag mini.autochdir
---@tag MiniAutochdir
---@toc_entry Smart autochdir
-- Module definition ==========================================================

local MiniAutochdir = {}
local H = {}

--- Module setup
---
---@param config table Module config table. See |MiniAutochdir.config|.
---
---@usage `require('mini.autochdir').setup({})` (replace `{}` with your `config` table)
function MiniAutochdir.setup(config)
  -- Export module
  _G.MiniAutochdir = MiniAutochdir

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
MiniAutochdir.config = {
  -- Array of glob root_pattern to find a project root.
  root_pattern = {
    '.svn',
    '.hg',
    '.bzr',
    '*.adc',
    'angular.json',
    'bower.json',
    'build',
    'BUILD.bazel',
    'build.boot',
    'build.gradle',
    'build.sbt',
    'build.sc',
    '*.cabal',
    'cabal.config',
    'cabal.project',
    'Cargo.toml',
    'compile_commands.json',
    'composer.json',
    '.csproj',
    'deno.json',
    'deno.jsonc',
    'deps.edn',
    'Dockerfile',
    'dub.json',
    'dub.sdl',
    'dune-project',
    'dune-workspace',
    'elm.json',
    'ember-cli-build.js',
    'erlang.mk',
    'esy.json',
    'flake.nix',
    '.flowconfig',
    '.fortls',
    'Gemfile',
    '.git',
    '.golangci.yaml',
    'go.mod',
    'go.work',
    '*.gpr',
    '.graphql.config.*',
    'graphql.config.*',
    '.graphqlrc*',
    '.hhconfig',
    'hie-bios',
    'hiera.yaml',
    'hie.yaml',
    '*.hxml',
    'jsconfig.json',
    'jsonnetfile.json',
    'lakefile.lean',
    'leanpkg.toml',
    'lean-toolchain',
    '.luacheckrc',
    '.luarc.json',
    'Makefile',
    'manifests',
    '.marksman.toml',
    'meson.build',
    'mix.exs',
    'node_modules',
    'ols.json',
    '*.opam',
    'package.json',
    'Package.swift',
    'package.yaml',
    'pom.xml',
    'postcss.config.js',
    'postcss.config.ts',
    'project.clj',
    'project.godot',
    'psalm.xml',
    'psalm.xml.dist',
    'psc-package.json',
    'pubspec.yaml',
    '.puppet-lint.rc',
    'pyproject.toml',
    'rebar.config',
    'requirements.txt',
    'robotidy.toml',
    'rust-project.json',
    'selene.toml',
    'settings.gradle',
    'sfdx-project.json',
    'shadow-cljs.edn',
    'shard.yml',
    'shell.nix',
    '.sln',
    'spago.dhall',
    'stack.yaml',
    'Steepfile',
    '.stylelintrc',
    '.stylua.toml',
    '.svlangserver',
    'tailwind.config.js',
    'tailwind.config.ts',
    '.terraform',
    '.tflint.hcl',
    'tlconfig.lua',
    '*.toml',
    'tsconfig.json',
    'v.mod',
    'vue.config.js',
    '.zk',
    'zls.json',
  },
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Find a project root from the directory of current buffer.
---
---@return ... this function returns nothing.
function MiniAutochdir.findroot()
  if H.is_disabled() then
    return
  end

  local bufname = vim.fn.expand('%:p')
  if vim.o.buftype ~= '' or bufname == '' or bufname:find('://') then
    return
  end
  local root_pattern = MiniAutochdir.config.root_pattern
  local dir = vim.fn.fnamemodify(bufname, ':p:h:gs!\\!/!:gs!//!/!')
  dir = vim.fn.escape(dir, ' ')
  dir = H.goup(dir, root_pattern)
  if not dir then
    return
  end
  vim.fn.chdir(dir)
  print('cwd: ' .. dir)
end

vim.cmd([[
augroup MiniAutochdir
  autocmd!
  autocmd BufEnter * :lua require('mini.autochdir').findroot()
augroup END
]])

-- Helper functionality =======================================================
-- Directory walker -----------------------------------------------------------
--
-- This returns the path which matches the pattern. If not, it returns nil.
function H.goup(path, root_pattern)
  -- General idea: go up directory from the given path.
  -- It returns the path which matches the root_pattern.
  while true do
    for _, pattern in ipairs(root_pattern) do
      local path_pattern = path .. '/' .. pattern
      if pattern:find('*') ~= nil and not vim.fn.glob(path_pattern, 1) == '' then
        return path
      elseif vim.fn.isdirectory(path_pattern) or vim.fn.filereadable(path_pattern) then
        return path
      end
    end
    local parent_dir = vim.fn.fnamemodify(path, ':h')
    if parent_dir == path or (vim.fn.has('win32') and parent_dir:match('^//[^/]+$')) then
      break
    end
    path = parent_dir
  end
  return nil
end

-- Module default config
H.default_config = MiniAutochdir.config

-- Settings -------------------------------------------------------------------
function H.setup_config(config)
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({ root_pattern = { config.root_pattern, 'table' } })

  return config
end

function H.apply_config(config)
  MiniAutochdir.config = config
end

function H.is_disabled()
  return vim.g.minijump2d_disable or vim.b.minijump2d_disable
end

return MiniAutochdir
