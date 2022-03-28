local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('fuzzy', config) end
local unload_module = function() child.mini_unload('fuzzy') end
local reload_module = function(config) unload_module(); load_module(config) end
--stylua: ignore end

-- Unit tests =================================================================
describe('MiniFuzzy.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniFuzzy ~= nil'))
  end)

  it('creates `config` field', function()
    eq(child.lua_get('type(_G.MiniFuzzy.config)'), 'table')

    -- Check default values
    eq(child.lua_get('MiniFuzzy.config.cutoff'), 100)
  end)

  it('respects `config` argument', function()
    unload_module()
    load_module({ cutoff = 300 })
    eq(child.lua_get('MiniFuzzy.config.cutoff'), 300)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ cutoff = 'a' }, 'cutoff', 'number')
  end)
end)

describe('MiniFuzzy.match()', function()
  child.setup()
  load_module()

  before_each(function()
    reload_module()
  end)

  it('works', function()
    eq(
      child.lua_get([[MiniFuzzy.match('gettime', 'get_cur_time')]]),
      { positions = { 1, 2, 3, 9, 10, 11, 12 }, score = 1201 }
    )
    eq(child.lua_get([[MiniFuzzy.match('gettime', 'time_get')]]), { score = -1 })
  end)

  it('handles cases when match is impossible', function()
    -- Smaller candidate
    eq(child.lua_get([[MiniFuzzy.match('a', '')]]), { score = -1 })
    eq(child.lua_get([[MiniFuzzy.match('ab', 'a')]]), { score = -1 })

    -- Empty word
    eq(child.lua_get([[MiniFuzzy.match('', 'abc')]]), { score = -1 })
  end)

  local validate_match = function(word, candidate, positions)
    local output = child.lua_get('MiniFuzzy.match(...)', { word, candidate })
    eq(output.positions, positions)
  end

  it('uses smart case', function()
    validate_match('ab', 'aB', { 1, 2 })
    validate_match('ab', 'Ab', { 1, 2 })
    validate_match('ab', 'AB', { 1, 2 })

    validate_match('Ab', 'ab', nil)
    validate_match('Ab', 'Ab', { 1, 2 })
    validate_match('Ab', 'AB', nil)
  end)

  it('respects order of letters', function()
    validate_match('abc', 'bcacbac', { 3, 5, 7 })
  end)

  it('handles special characters', function()
    validate_match('(.+*%-)', 'a(a.a+a*a%a-a)', { 2, 4, 6, 8, 10, 12, 14 })
  end)

  it('finds best match in presence of many', function()
    validate_match('ab', 'a__b_a__b_ab', { 11, 12 })
    validate_match('ab', 'a__b_ab_a__b', { 6, 7 })
    validate_match('ab', 'ab_a__b_a__b', { 1, 2 })

    validate_match('ab', 'ab__ab', { 1, 2 })
  end)

  it('has allowed limitations', function()
    -- Output may be unintuitive if there are several optimal matches with same
    -- score (same width and start position)
    validate_match('abc', 'abbbc', { 1, 4, 5 })
  end)

  local validate_score = function(word, candidate, score)
    local output = child.lua_get('MiniFuzzy.match(...)', { word, candidate })
    eq(output.score, score)
  end

  it('computes correct score', function()
    validate_score('a', 'a', 101)
    validate_score('a', '_a', 102)
    validate_score('a', '__a', 103)

    validate_score('ab', 'ab_', 201)
    validate_score('ab', '_ab', 202)
    validate_score('ab', 'a_b', 301)

    validate_score('abc', 'abc__', 301)
    validate_score('abc', '_abc_', 302)
    validate_score('abc', '__abc', 303)
    validate_score('abc', 'a_bc_', 401)
    validate_score('abc', 'ab_c_', 401)
    validate_score('abc', '_a_bc', 402)
    validate_score('abc', '_ab_c', 402)
    validate_score('abc', 'a__bc', 501)
    validate_score('abc', 'a_b_c', 501)
    validate_score('abc', 'ab__c', 501)

    -- No match
    validate_score('a', 'bcd', -1)
    validate_score('ab', 'ba', -1)
  end)

  it('respects `config.cutoff`', function()
    reload_module({ cutoff = 10 })
    validate_score('ab', 'ab_', 21)
  end)

  it('treats features bigger than `config.cutoff` the same', function()
    reload_module({ cutoff = 4 })

    validate_score('a', '__a', 7)
    validate_score('a', '___a', 8)
    validate_score('a', '____a', 8)

    validate_score('ab', 'a_b', 13)
    validate_score('ab', 'a__b', 17)
    validate_score('ab', 'a___b', 17)
  end)
end)

describe('MiniFuzzy.filtersort()', function()
  child.setup()
  load_module()

  before_each(function()
    reload_module()
  end)

  local filtersort = function(...)
    return child.lua_get('{ MiniFuzzy.filtersort(...) }', { ... })
  end

  local validate_filtersort = function(word, candidate_array, matched_candidates)
    local output = filtersort(word, candidate_array)
    eq(output[1], matched_candidates)
  end

  it('works', function()
    eq(filtersort('a', { '_a', '__a', 'b', 'a' }), { { 'a', '_a', '__a' }, { 4, 1, 2 } })
    eq(filtersort('a', {}), { {}, {} })
  end)

  it('uses smart case', function()
    validate_filtersort('ab', { 'ab', 'aB', 'Ab', 'AB' }, { 'ab', 'aB', 'Ab', 'AB' })
    validate_filtersort('Ab', { 'ab', 'aB', 'Ab', 'AB' }, { 'Ab' })
  end)

  it('preserves original order with equal matching score', function()
    validate_filtersort(
      'abc',
      { 'ab__c', 'a__bc', 'a_b_c', '__abc', 'abc__' },
      { 'abc__', '__abc', 'ab__c', 'a__bc', 'a_b_c' }
    )
  end)

  it('works with empty arguments', function()
    validate_filtersort('', { 'a', 'b', '_a' }, {})
    validate_filtersort('a', {}, {})
  end)
end)

describe('MiniFuzzy.process_lsp_items()', function()
  child.setup()
  load_module()

  before_each(function()
    reload_module()
  end)

  local new_item = function(newText, insertText, label)
    return { textEdit = { newText = newText }, insertText = insertText, label = label }
  end

  local process_lsp_items = function(...)
    return child.lua_get('MiniFuzzy.process_lsp_items(...)', { ... })
  end

  it('works', function()
    local items

    items = { new_item('___a', nil, nil), new_item('__a', nil, nil), new_item('_a', nil, nil) }
    eq(process_lsp_items(items, 'a'), { items[3], items[2], items[1] })

    items = { new_item(nil, '___a', nil), new_item(nil, '__a', nil), new_item(nil, '_a', nil) }
    eq(process_lsp_items(items, 'a'), { items[3], items[2], items[1] })

    items = { new_item(nil, nil, '___a'), new_item(nil, nil, '__a'), new_item(nil, nil, '_a') }
    eq(process_lsp_items(items, 'a'), { items[3], items[2], items[1] })
  end)

  it('correctly extracts candidate from fields', function()
    local items

    -- textEdit.newText > insertText > label
    items = { new_item('__a', '_a', nil), new_item('_a', '__a', nil) }
    eq(process_lsp_items(items, 'a'), { items[2], items[1] })

    items = { new_item('__a', nil, '_a'), new_item('_a', nil, '__a') }
    eq(process_lsp_items(items, 'a'), { items[2], items[1] })

    items = { new_item(nil, '__a', '_a'), new_item(nil, '_a', '__a') }
    eq(process_lsp_items(items, 'a'), { items[2], items[1] })
  end)
end)

describe('MiniFuzzy.get_telescope_sorter()', function()
  child.setup()
  load_module()

  it('is present', function()
    eq(child.lua_get('MiniFuzzy.get_telescope_sorter ~= nil'), true)
  end)
end)

child.stop()
