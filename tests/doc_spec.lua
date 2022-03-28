-- NOTE: These are basic tests which cover basic functionliaty. A lot of
-- nuances are not tested to meet "complexity-necessity" trade-off.
local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('doc', config) end
local unload_module = function() child.mini_unload('doc') end
local reload_module = function(config) unload_module(); load_module(config) end
local cd = function(path) child.cmd('cd ' .. path) end
local source_helpers = function() child.cmd('luafile tests/doc-tests/helpers.lua') end
local remove_dir = function(path) child.lua('_G.remove_dir(...)', { path }) end
--stylua: ignore end

-- Make helpers
local assert_equal_file_contents = function(file1, file2)
  eq(child.fn.readfile(file1), child.fn.readfile(file2))
end

-- Data =======================================================================
--stylua: ignore start
local default_section_names = {
  '@alias',  '@class',    '@diagnostic', '@eval',
  '@field',  '@overload', '@param',      '@private',
  '@return', '@seealso',  '@signature',  '@tag',
  '@text',   '@toc',      '@toc_entry',  '@type',
  '@usage',
}
--stylua: ignore end

-- Unit tests =================================================================
describe('MiniDoc.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniDoc ~= nil'))
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniDoc.config)'), 'table')

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniDoc.config.' .. field), value)
    end
    local assert_config_function = function(field)
      local command = ([[type(MiniDoc.config.%s)]]):format(field)
      eq(child.lua_get(command), 'function')
    end
    local assert_sections = function(section_names)
      local t = child.lua_get('vim.tbl_keys(MiniDoc.config.hooks.sections)')
      table.sort(t)
      eq(t, section_names)

      for _, key in ipairs(t) do
        local command = string.format([[type(MiniDoc.config.hooks.sections[%s])]], vim.inspect(key))
        eq(child.lua_get(command), 'function')
      end
    end

    -- Check default values
    assert_config_function('annotation_extractor')
    assert_config('default_section_id', '@text')
    assert_config_function('hooks.block_pre')
    assert_config_function('hooks.section_pre')
    assert_sections(default_section_names)
    assert_config_function('hooks.section_post')
    assert_config_function('hooks.block_post')
    assert_config_function('hooks.file')
    assert_config_function('hooks.doc')
    assert_config_function('hooks.write_post')
    assert_config('script_path', 'scripts/minidoc.lua')
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ default_section_id = 'aaa' })
    eq(child.lua_get('MiniDoc.config.default_section_id'), 'aaa')
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    local assert_sections_validation = function(section_names)
      assert_config_error({ hooks = { sections = 1 } }, 'hooks.sections', 'table')
      for _, s_name in ipairs(section_names) do
        assert_config_error({ hooks = { sections = { [s_name] = 1 } } }, 'hooks.sections.' .. s_name, 'function')
      end
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ annotation_extractor = 'a' }, 'annotation_extractor', 'function')
    assert_config_error({ default_section_id = 1 }, 'default_section_id', 'string')
    assert_config_error({ hooks = 1 }, 'hooks', 'table')
    assert_config_error({ hooks = { block_pre = 1 } }, 'hooks.block_pre', 'function')
    assert_config_error({ hooks = { section_pre = 1 } }, 'hooks.section_pre', 'function')
    assert_sections_validation(default_section_names)
    assert_config_error({ hooks = { section_post = 1 } }, 'hooks.section_post', 'function')
    assert_config_error({ hooks = { block_post = 1 } }, 'hooks.block_post', 'function')
    assert_config_error({ hooks = { file = 1 } }, 'hooks.file', 'function')
    assert_config_error({ hooks = { doc = 1 } }, 'hooks.doc', 'function')
    assert_config_error({ hooks = { write_post = 1 } }, 'hooks.write_post', 'function')
    assert_config_error({ script_path = 1 }, 'script_path', 'string')
  end)
end)

describe('MiniDoc.default_hooks', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('is same as default `MiniDoc.config.hooks`', function()
    -- `tostring()` when applied to table returns string with its hex id
    -- (except in Neovim<0.6, where it seems to return `vim.empty_dict()` if
    -- table has metatable). So this checks for *exact* equality of two tables.
    if vim.fn.has('nvim-0.6') == 1 then
      eq(child.lua_get('tostring(MiniDoc.default_hooks) == tostring(MiniDoc.config.hooks)'), true)
    end
  end)
end)

-- General overview of testing workflow:
-- - Tests are organized per test scope: collection of source code file with
--   annotations demonstating similar functionality. Every test scope organized
--   in separate subdirectory of 'tests/doc-tests'.
-- - Testing is performed by evaluating `MiniDoc.generate()` (with possibly
--   non-default arguments) with current directory being equal to directory of
--   tested scope (for example, 'default-collation'). It will produce some
--   output help file ('doc/default-collation.txt' by default). Test is
--   performed by comparing its contents line by line with manually computed
--   reference file ('default-collation_reference.txt' by default).
-- - To add/update tests either:
--     - Update files in existing test scope and regenerate reference file (run
--       corresponding `MiniDoc.generate()` manually and save it to correct
--       '***_reference.txt' file).
--     - Add new test scope: create direcotry, add files, generate reference
--       help file, add separate `it()` call.
describe('MiniDoc.generate()', function()
  before_each(function()
    child.setup()
    load_module()

    -- Add inside child process some useful codebase
    source_helpers()

    -- Set current directory to one containing all input data for tests
    cd('tests/doc-tests')

    -- Set high height of command line to not encounter hit-enter-prompt
    child.o.cmdheight = 10
  end)

  local validate_test_scope = function(test_scope_name)
    cd(test_scope_name)
    child.lua('MiniDoc.generate()')
    local output_path = ('doc/%s.txt'):format(test_scope_name)
    local reference_path = ('%s_reference.txt'):format(test_scope_name)
    assert_equal_file_contents(output_path, reference_path)

    -- Cleanup 'doc' subdirectory from current directory
    remove_dir('doc')
  end

  it('uses correct default collation order', function()
    validate_test_scope('default-collation')
  end)

  it('makes correct afterlines inference', function()
    validate_test_scope('inference')
  end)

  it('handles sections correctly', function()
    validate_test_scope('sections')
  end)

  it('respects arguments', function()
    unload_module()

    -- Add project root to runtimepath to be able to `require('mini.doc')`
    child.cmd([[set rtp+=../..]])
    child.lua([[
      require('mini.doc').setup({
        hooks = {
          section_post = function(s)
            s:insert('This line should be added in `section_post` hook.')
          end,
        },
      })
    ]])

    cd('arguments')
    child.lua([[
      MiniDoc.generate({ 'file.lua' }, 'output.txt', {
        annotation_extractor = function(l)
          return string.find(l, '^%-%-(%S*) ?')
        end,
      })
    ]])

    assert_equal_file_contents('output.txt', 'output_reference.txt')

    -- Cleanup
    child.loop.fs_unlink('output.txt')
  end)

  it('returns correct data structure', function()
    child.cmd('luafile helpers.lua')
    cd('structure')

    assert.not_error(function()
      child.lua('_G.validate_doc_structure(MiniDoc.generate())')
    end)

    remove_dir('doc')
  end)

  it('uses custom script', function()
    -- Add project root to runtimepath to be able to `require('mini.doc')`
    child.cmd([[set rtp+=../..]])
    reload_module({ script_path = 'gendoc/gendoc-script.lua' })

    cd('custom-script')
    -- This should execute 'gendoc/gendoc-script.lua' and return what it returns
    assert.not_error(function()
      child.lua('_G.validate_doc_structure(MiniDoc.generate())')
    end)
    assert_equal_file_contents('output.txt', 'output_reference.txt')

    -- Script is executed only if all arguments are `nil` (default).
    child.lua([[MiniDoc.generate({ 'init.lua' })]])
    assert_equal_file_contents('doc/custom-script.txt', 'output_reference.txt')

    -- Cleanup
    child.loop.fs_unlink('output.txt')
    remove_dir('doc')
  end)
end)

child.stop()
