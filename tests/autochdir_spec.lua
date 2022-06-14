local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('autochdir', config) end
local unload_module = function() child.mini_unload('autochdir') end
--stylua: ignore end

-- Unit tests =================================================================
describe('MiniAutochdir.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniAutochdir ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniAutochdir'), 1)
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniAutochdir.config)'), 'table')

    -- Check default values
    local assert_config = function(field, value)
      eq(#(child.lua_get('MiniAutochdir.config.' .. field)), value)
    end

    -- Check default values
    assert_config('root_pattern', 105)
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ root_pattern = {} })
    eq(child.lua_get('MiniAutochdir.config.root_pattern'), {})
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ root_pattern = 'a' }, 'root_pattern', 'table')
  end)
end)

describe('MiniAutochdir.findroot()', function()
  child.setup()
  load_module()

  it('works', function()
    eq(child.fn.getcwd(), vim.fn.getcwd())
  end)
end)

child.stop()
