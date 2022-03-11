local eq = assert.are.same
local not_eq = assert.are.not_same

local unload_module = function()
  package.loaded['mini.indentscope'] = nil
  _G.MiniIndentscope = nil
end

describe('setup()', function()
  before_each(function()
    require('mini.indentscope').setup()
  end)
  after_each(unload_module)

  it('Creates side effects', function()
    -- Global variable
    not_eq(_G.MiniIndentscope, nil)

    -- Autocommand group
    eq(vim.fn.exists('#MiniIndentscope'), 1)

    -- Autocommand on `ModeChanged` event
    if vim.fn.has('nvim-0.7.0') == 1 then
      eq(vim.fn.exists('#MiniIndentscope#ModeChanged'), 1)
    end

    -- Highlight groups
    eq(vim.fn.hlexists('MiniIndentscopeSymbol'), 1)
    eq(vim.fn.hlexists('MiniIndentscopePrefix'), 1)
  end)

  it('Creates `config` field', function()
    assert.is.table(MiniIndentscope.config)

    -- Check default values
    local config = MiniIndentscope.config

    assert.is['function'](config.draw.animation)
    eq(config.draw.delay, 100)
    eq(config.mappings.goto_bottom, ']i')
    eq(config.mappings.goto_top, '[i')
    eq(config.mappings.object_scope, 'ii')
    eq(config.mappings.object_scope_with_border, 'ai')
    eq(config.options.border, 'both')
    eq(config.options.indent_at_cursor, true)
    eq(config.options.try_as_border, false)
    eq(config.symbol, '╎')
  end)

  it('Respects `config` argument', function()
    unload_module()
    require('mini.indentscope').setup({ symbol = 'a' })
    eq(MiniIndentscope.config.symbol, 'a')
  end)
end)
