local helpers = dofile('tests/helpers.lua')

local child = helpers.new_child_neovim()
local expect, eq, no_eq = helpers.expect, helpers.expect.equality, helpers.expect.no_equality
local new_set = MiniTest.new_set

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('icons', config) end
local unload_module = function() child.mini_unload('icons') end
--stylua: ignore end

-- Common test wrappers
local forward_lua = function(fun_str)
  local lua_cmd = fun_str .. '(...)'
  return function(...) return child.lua_get(lua_cmd, { ... }) end
end

local get = function(...) return child.lua_get('{ MiniIcons.get(...) }', { ... }) end

-- Output test set ============================================================
local T = new_set({
  hooks = {
    pre_case = function()
      child.setup()
      load_module()
    end,
    post_once = child.stop,
  },
})

-- Unit tests =================================================================
T['setup()'] = new_set()

T['setup()']['creates side effects'] = function()
  -- Global variable
  eq(child.lua_get('type(_G.MiniIcons)'), 'table')

  -- Highlight groups
  child.cmd('hi clear')
  load_module()
  local has_highlight = function(group, value) expect.match(child.cmd_capture('hi ' .. group), value) end

  has_highlight('MiniIconsAzure', 'links to Function')
  has_highlight('MiniIconsBlue', 'links to DiagnosticInfo')
  has_highlight('MiniIconsCyan', 'links to DiagnosticHint')
  has_highlight('MiniIconsGreen', 'links to DiagnosticOk')
  has_highlight('MiniIconsGrey', child.fn.has('nvim-0.10') == 1 and 'cleared' or 'cterm= gui=')
  has_highlight('MiniIconsOrange', 'links to DiagnosticWarn')
  has_highlight('MiniIconsPurple', 'links to Constant')
  has_highlight('MiniIconsRed', 'links to DiagnosticError')
  has_highlight('MiniIconsYellow', 'links to DiagnosticWarn')
end

T['setup()']['creates `config` field'] = function()
  eq(child.lua_get('type(_G.MiniIcons.config)'), 'table')

  -- Check default values
  local expect_config = function(field, value) eq(child.lua_get('MiniIcons.config.' .. field), value) end

  expect_config('style', 'glyph')

  expect_config('default', {})
  expect_config('directory', {})
  expect_config('extension', {})
  expect_config('file', {})
  expect_config('filetype', {})
  expect_config('lsp', {})
  expect_config('os', {})
end

T['setup()']['respects `config` argument'] = function()
  unload_module()
  load_module({ style = 'ascii' })
  eq(child.lua_get('MiniIcons.config.style'), 'ascii')
end

T['setup()']['validates `config` argument'] = function()
  unload_module()

  local expect_config_error = function(config, name, target_type)
    expect.error(load_module, vim.pesc(name) .. '.*' .. vim.pesc(target_type), config)
  end

  expect_config_error('a', 'config', 'table')
  expect_config_error({ style = 1 }, 'style', 'string')
  expect_config_error({ default = 1 }, 'default', 'table')
  expect_config_error({ directory = 1 }, 'directory', 'table')
  expect_config_error({ extension = 1 }, 'extension', 'table')
  expect_config_error({ file = 1 }, 'file', 'table')
  expect_config_error({ filetype = 1 }, 'filetype', 'table')
  expect_config_error({ lsp = 1 }, 'lsp', 'table')
  expect_config_error({ os = 1 }, 'os', 'table')
end

T['setup()']['can customize icons'] = function()
  -- Both override existing and provide new ones
  load_module({
    default = {
      -- Can provide only customized attributes
      extension = { glyph = 'E' },
      file = { hl = 'AAA' },
    },
    directory = {
      my_dir = { glyph = 'D', hl = 'Directory' },
    },
  })

  eq(get('default', 'extension')[1], 'E')
  eq(get('default', 'file')[2], 'AAA')
  eq(get('directory', 'my_dir'), { 'D', 'Directory', false })
end

T['setup()']['customization respects `vim.filetype.match()` fallback'] = function()
  child.lua([[vim.filetype.add({ extension = { myext = 'extinguisher' } })]])

  load_module({
    filetype = { extinguisher = { glyph = '󰻲', hl = 'MiniIconsRed' } },
    extension = { myext = { hl = 'Special' } },
    file = { ['hello.myext'] = { hl = 'String' } },
  })
  eq(get('file', 'hello.myext'), { '󰻲', 'String', false })
  eq(get('extension', 'myext'), { '󰻲', 'Special', false })
  eq(get('filetype', 'extinguisher'), { '󰻲', 'MiniIconsRed', false })
end

T['setup()']['respects `config.style` when customizing icons'] = function()
  load_module({
    style = 'ascii',
    default = { default = { glyph = '-', hl = 'Comment' } },
    extension = { ext = { glyph = '󰻲', hl = 'MiniIconsRed' } },
  })

  eq(get('default', 'default'), { 'D', 'Comment', false })
  eq(get('extension', 'ext'), { 'E', 'MiniIconsRed', false })
end

T['get()'] = new_set()

T['get()']['works with "default" category'] = function()
  local validate = function(name, icon, hl, is_default) eq(get('default', name), { icon, hl, is_default }) end

  validate('default', '󰟢', 'MiniIconsGrey', false)
  validate('directory', '󰉋', 'MiniIconsAzure', false)
  validate('extension', '󰈔', 'MiniIconsGrey', false)
  validate('file', '󰈔', 'MiniIconsGrey', false)
  validate('filetype', '󰈔', 'MiniIconsGrey', false)
  validate('lsp', '󰞋', 'MiniIconsRed', false)
  validate('os', '󰟀', 'MiniIconsPurple', false)

  -- Can be customized
  load_module({
    default = {
      file = { glyph = '󱁂', hl = 'Comment' },
    },
  })
  validate('file', '󱁂', 'Comment', false)

  -- Validates not supported category
  expect.error(function() get('default', 'aaa') end, 'aaa.*not.*category')
end

T['get()']['works with "directory" category'] = function()
  load_module({
    default = { directory = { glyph = 'D', hl = 'Comment' } },
    directory = { mydir = { glyph = '󱁂', hl = 'AA' } },
  })

  local validate = function(name, icon, hl, is_default) eq(get('directory', name), { icon, hl, is_default }) end

  validate('.git', '', 'MiniIconsOrange', false)
  validate('mydir', '󱁂', 'AA', false)
  validate('should-be-default', 'D', 'Comment', true)
end

T['get()']['works with "extension" category'] = function()
  load_module({
    default = { extension = { glyph = 'E', hl = 'Comment' } },
    extension = {
      myext = { glyph = '󱁂', hl = 'AA' },
      ['my.ext'] = { glyph = '󰻲', hl = 'MiniIconsRed' },
    },
    filetype = { squirrel = { glyph = 'S', hl = 'Special' } },
  })
  local validate = function(name, icon, hl, is_default) eq(get('extension', name), { icon, hl, is_default }) end

  validate('lua', '󰢱', 'MiniIconsAzure', false)
  validate('myext', '󱁂', 'AA', false)
  validate('my.ext', '󰻲', 'MiniIconsRed', false)
  validate('xpm', '󰍹', 'MiniIconsYellow', false)
  validate('should-be-default', 'E', 'Comment', true)
end

T['get()']['works with "file" category'] = function()
  load_module({
    default = { file = { glyph = 'F', hl = 'Comment' } },
    file = { myfile = { glyph = '󱁂', hl = 'AA' } },
    filetype = { gitignore = { glyph = 'G', hl = 'Ignore' } },
    extension = {
      py = { glyph = 'PY', hl = 'String' },
      ['my.ext'] = { glyph = '󰻲', hl = 'MiniIconsRed' },
      ext = { glyph = 'E', hl = 'Comment' },
    },
  })

  local validate = function(name, icon, hl, is_default) eq(get('file', name), { icon, hl, is_default }) end

  -- Works with different sources of resolution
  -- - Exact basename
  validate('init.lua', '', 'MiniIconsGreen', false)
  -- - Extension
  validate('hello.lua', '󰢱', 'MiniIconsAzure', false)
  -- - `vim.filetype.match()`
  validate('Cargo.lock', '', 'MiniIconsOrange', false)
  -- - `vim.filetype.match()` which relies on supplied `buf`
  validate('hello.xpm', '󰍹', 'MiniIconsYellow', false)
  -- - Default
  validate('should-be-default', 'F', 'Comment', true)

  -- Can accept full paths
  eq(get('file', '/home/user/hello.lua'), get('file', 'hello.lua'))

  -- Can use customizations
  validate('myfile', '󱁂', 'AA', false)
  validate('hello.py', 'PY', 'String', false)
  validate('.gitignore', 'G', 'Ignore', false)

  -- Can use complex "extension"
  validate('hello.ext', 'E', 'Comment', false)
  validate('hello.my.ext', '󰻲', 'MiniIconsRed', false)
end

T['get()']['works with "filetype" category'] = function()
  load_module({
    default = { filetype = { glyph = 'F', hl = 'Comment' } },
    filetype = { myfiletype = { glyph = '󱁂', hl = 'AA' } },
  })

  local validate = function(name, icon, hl, is_default) eq(get('filetype', name), { icon, hl, is_default }) end

  validate('help', '󰋖', 'MiniIconsPurple', false)
  validate('myfiletype', '󱁂', 'AA', false)
  validate('should-be-default', 'F', 'Comment', true)
end

T['get()']['works with "lsp" category'] = function()
  load_module({
    default = { lsp = { glyph = 'L', hl = 'Comment' } },
    lsp = { mylsp = { glyph = '󱁂', hl = 'AA' } },
  })

  local validate = function(name, icon, hl, is_default) eq(get('lsp', name), { icon, hl, is_default }) end

  validate('array', '', 'MiniIconsOrange', false)
  validate('mylsp', '󱁂', 'AA', false)
  validate('should-be-default', 'L', 'Comment', true)
end

T['get()']['works with "os" category'] = function()
  load_module({
    default = { os = { glyph = 'O', hl = 'Comment' } },
    os = { myos = { glyph = '󱁂', hl = 'AA' } },
  })

  local validate = function(name, icon, hl, is_default) eq(get('os', name), { icon, hl, is_default }) end

  validate('arch', '󰣇', 'MiniIconsAzure', false)
  validate('myos', '󱁂', 'AA', false)
  validate('should-be-default', 'O', 'Comment', true)
end

T['get()']['caches output'] = function()
  local durations = child.lua([[
    local file = 'complex.file.name.which.should.fall.back.to.vim.filetype.match'
    local bench = function()
      local start_time = vim.loop.hrtime()
      MiniIcons.get('file', file)
      return vim.loop.hrtime() - start_time
    end

    local dur_no_cache = bench()
    local dur_cache = bench()

    -- Calling `setup()` should reset cache
    MiniIcons.setup()
    local dur_no_cache_2 = bench()

    return { no_cache = dur_no_cache, cache = dur_cache, no_cache_2 = dur_no_cache_2 }
  ]])

  eq(durations.cache <= 0.02 * durations.no_cache, true)
  eq(durations.cache <= 0.02 * durations.no_cache_2, true)
end

T['get()']['adds to cache resolved output source'] = function()
  -- NOTES:
  -- - Only manually tracked extensions can be target of resolve.
  -- - There should also be caching of both "file" and "extension" category
  --   resolving to "filetype", but as "filetype" is already very fast without
  --   caching, the benchmarking is not stable.
  local durations = child.lua([[
    local bench = function(category, name)
      local start_time = vim.loop.hrtime()
      MiniIcons.get(category, name)
      return vim.loop.hrtime() - start_time
    end

    local ext_no_cache = bench('extension', 'lua')

    -- "file" category resolving to "extension"
    MiniIcons.get('file', 'hello.py')
    local ext_cache_after_file = bench('extension', 'py')

    return {
      ext_no_cache = ext_no_cache,
      ext_cache_after_file = ext_cache_after_file,
    }
  ]])

  -- Resolution with manually tracked data is usually fast, hence high coeff
  eq(durations.ext_cache_after_file < 0.7 * durations.ext_no_cache, true)
end

T['get()']['prefers user configured data over `vim.filetype.match()`'] = function()
  load_module({
    extension = {
      ['complex.extension.which.user.configured.to.not.fall.back.to.vim.filetype.match'] = { glyph = 'E' },
      ['complex.extension.two.which.user.configured.to.not.fall.back.to.vim.filetype.match'] = { glyph = 'e' },
    },
    file = { ['complex.file.name.which.user.configured.to.not.fall.back.to.vim.filetype.match'] = { glyph = 'C' } },
  })

  local durations = child.lua([[
    local bench = function(category, name)
      local start_time = vim.loop.hrtime()
      MiniIcons.get(category, name)
      return vim.loop.hrtime() - start_time
    end

    local ext_fallback = bench('extension', 'not-supported-extension')
    local ext_ext = bench('extension', 'complex.extension.which.user.configured.to.not.fall.back.to.vim.filetype.match')

    local file_fallback = bench('file', 'not-supported-file')
    local file_file = bench('file', 'complex.file.name.which.user.configured.to.not.fall.back.to.vim.filetype.match')
    local file_ext = bench('file', 'FILENAME.complex.extension.two.which.user.configured.to.not.fall.back.to.vim.filetype.match')

    return {
      ext_fallback = ext_fallback,
      ext_ext = ext_ext,

      file_fallback = file_fallback,
      file_file = file_file,
      file_ext = file_ext,
    }
  ]])

  eq(durations.ext_ext < 0.1 * durations.ext_fallback, true)
  eq(durations.file_file < 0.1 * durations.file_fallback, true)
  eq(durations.file_ext < 0.1 * durations.file_fallback, true)
end

T['get()']['respects `config.style`'] = function()
  load_module({
    style = 'ascii',
    default = { file = { glyph = '󱁂' } },
    extension = { myext = { glyph = '󰻲', hl = 'MiniIconsRed' } },
  })

  -- ASCII style is upper variant of the first byte of the resolved name
  eq(get('default', 'directory'), { 'D', 'MiniIconsAzure', false })

  -- - 'init.lua' is explicitly tracked
  eq(get('file', 'init.lua'), { 'I', 'MiniIconsGreen', false })
  -- - 'hello.lua' is resolved to use "lua" extension
  eq(get('file', 'hello.lua'), { 'L', 'MiniIconsAzure', false })
  -- - 'Cargo.lock' is resolved to use "toml" filetype
  eq(get('file', 'Cargo.lock'), { 'T', 'MiniIconsOrange', false })
  -- - 'not-supported' is resolved to use "file" default
  eq(get('file', 'not-supported'), { 'F', 'MiniIconsGrey', true })

  -- Should work with all categories
  eq(get('default', 'lsp')[1], 'L')
  eq(get('directory', 'nvim')[1], 'N')
  eq(get('extension', 'lua')[1], 'L')
  eq(get('filetype', 'help')[1], 'H')
  eq(get('lsp', 'array')[1], 'A')
  eq(get('os', 'arch')[1], 'A')

  -- Should work with customized icons
  eq(get('default', 'directory')[1], 'D')
  eq(get('extension', 'myext')[1], 'M')
  eq(get('file', 'hello.myext')[1], 'M')

  -- Should properly return if output is fallback (even if icons are the same)
  eq(get('directory', 'dir-not-supported'), { 'D', 'MiniIconsAzure', true })
  eq(get('extension', 'ext-not-supported'), { 'E', 'MiniIconsGrey', true })
  eq(get('file', 'file-not-supported'), { 'F', 'MiniIconsGrey', true })
  eq(get('filetype', 'filetype-not-supported'), { 'F', 'MiniIconsGrey', true })
  eq(get('lsp', 'lsp-not-supported'), { 'L', 'MiniIconsRed', true })
  eq(get('os', 'os-not-supported'), { 'O', 'MiniIconsPurple', true })
end

T['get()']['respects multibyte characters with "ascii" style'] = function()
  load_module({
    style = 'ascii',
    directory = { й_dir = { glyph = 'M' } },
    extension = { й_ext = { glyph = 'M' } },
    file = { й_file = { glyph = 'M' } },
    filetype = { й_filetype = { glyph = 'M' } },
    lsp = { й_lsp = { glyph = 'M' } },
    os = { й_os = { glyph = 'M' } },
  })

  -- Currently matched without making  it upper case to save speed for
  -- overwhelmingly common single byte case (because `vim.fn.toupper()` is
  -- *much* slower than `string.upper()`)
  eq(get('directory', 'й_dir')[1], 'Й')
  eq(get('extension', 'й_ext')[1], 'Й')
  eq(get('file', 'й_file')[1], 'Й')
  eq(get('filetype', 'й_filetype')[1], 'Й')
  eq(get('lsp', 'й_lsp')[1], 'Й')
  eq(get('os', 'й_os')[1], 'Й')

  -- Default stil should match with category's first letter
  eq(get('directory', 'й_default_dir')[1], 'D')
  eq(get('extension', 'й_default_ext')[1], 'E')
  eq(get('file', 'й_default_file')[1], 'F')
  eq(get('filetype', 'й_default_filetype')[1], 'F')
  eq(get('lsp', 'й_default_lsp')[1], 'L')
  eq(get('os', 'й_default_os')[1], 'O')
end

T['get()']['respects customizations in config'] = function()
  load_module({
    default = { directory = { glyph = '󱁂', hl = 'Directory' } },
    directory = { mydir = { glyph = 'A', hl = 'Comment' } },
    extension = { myext = { glyph = 'B' } },
    file = { myfile = { hl = 'String' } },
    filetype = { myfiletype = { glyph = 'D' } },
    lsp = { mylsp = { glyph = 'E' } },
    os = { myos = { glyph = 'F' } },
  })

  eq(get('default', 'directory'), { '󱁂', 'Directory', false })
  eq(get('directory', 'mydir'), { 'A', 'Comment', false })
  eq(get('extension', 'myext'), { 'B', 'MiniIconsGrey', false })
  eq(get('file', 'myfile'), { '󰈔', 'String', false })
  eq(get('filetype', 'myfiletype'), { 'D', 'MiniIconsGrey', false })
  eq(get('lsp', 'mylsp'), { 'E', 'MiniIconsRed', false })
  eq(get('os', 'myos'), { 'F', 'MiniIconsPurple', false })
end

T['get()']['handles different casing'] = function()
  load_module({
    directory = { mydir = { glyph = 'A' } },
    extension = { myext = { glyph = 'B' } },
    file = { myfile = { glyph = 'C' } },
    filetype = { myfiletype = { glyph = 'D' } },
    lsp = { mylsp = { glyph = 'E' } },
    os = { myos = { glyph = 'F' } },
  })

  -- Should match exactly for "file" and "directory"
  no_eq(get('directory', 'nvim'), get('directory', 'Nvim'))
  no_eq(get('directory', 'mydir'), get('directory', 'MyDir'))

  -- - 'Cargo.lock' is matched as 'toml' in `vim.filetype.match()`
  no_eq(get('file', 'Cargo.lock'), get('file', 'cargo.lock'))
  no_eq(get('file', 'myfile'), get('file', 'MyFile'))

  -- Others - ignoring case
  eq(get('default', 'file'), get('default', 'FILE'))

  eq(get('extension', 'lua'), get('extension', 'LUA'))
  eq(get('file', 'hello.R'), get('file', 'hello.r'))

  eq(get('extension', 'MyExT')[1], 'B')
  eq(get('file', 'hello.MyExT')[1], 'B')

  eq(get('filetype', 'help'), get('filetype', 'Help'))
  eq(get('filetype', 'myfiletype'), get('filetype', 'MyFileType'))

  eq(get('lsp', 'array'), get('lsp', 'Array'))
  eq(get('lsp', 'mylsp'), get('lsp', 'MyLsp'))

  eq(get('os', 'arch'), get('os', 'Arch'))
  eq(get('os', 'myos'), get('os', 'MyOs'))
end

T['get()']['can be used without `setup()`'] = function()
  unload_module()
  eq(child.lua_get('{ require("mini.icons").get("default", "file") }'), { '󰈔', 'MiniIconsGrey', false })
end

T['get()']['can be used after deleting all buffers'] = function()
  -- As `vim.filetype.match()` requries a buffer to be more useful, make sure
  -- that this cached buffer is persistent
  eq(get('file', 'hello.xpm'), { '󰍹', 'MiniIconsYellow', false })
  child.cmd('%bwipeout')
  eq(get('file', 'hello.tcsh'), { '', 'MiniIconsAzure', false })
end

T['get()']['validates arguments'] = function()
  expect.error(function() get(1, 'lua') end, 'category.*string')
  expect.error(function() get('file', 1) end, 'name.*string')

  expect.error(function() get('aaa', 'lua') end, 'aaa.*not.*category')
end

T['list()'] = new_set()

local list = forward_lua('MiniIcons.list')

T['list()']['works'] = function()
  local islist = vim.fn.has('nvim-0.10') == 1 and vim.islist or vim.tbl_islist
  local validate = function(category, ref_present_entry)
    local res = list(category)
    eq(islist(res), true)
    eq(vim.tbl_contains(res, ref_present_entry), true)
  end

  eq(list('default'), { 'default', 'directory', 'extension', 'file', 'filetype', 'lsp', 'os' })
  validate('directory', 'nvim')
  validate('extension', 'lua')
  validate('file', 'init.lua')
  validate('filetype', 'lua')
  validate('lsp', 'array')
  validate('os', 'arch')

  -- Should not add cached but not explicitly supported items
  local validate_no = function(category, name)
    get(category, name)
    eq(vim.tbl_contains(list(category), name), false)
  end

  validate_no('directory', 'mydir')
  validate_no('extension', 'myext')
  validate_no('file', 'myfile')
  validate_no('filetype', 'myfiletype')
  validate_no('lsp', 'mylsp')
  validate_no('os', 'myos')
end

T['list()']['uses lowercase icon names for categories which ignore case'] = function()
  -- Otherwise `get()` will not match names with uppercase letter
  local validate = function(category)
    local not_lowercase = vim.tbl_filter(function(name) return name ~= name:lower() end, list(category))
    eq(not_lowercase, {})
  end
  validate('default')
  validate('extension')
  validate('filetype')
  validate('lsp')
  validate('os')
end

T['list()']['validates arguments'] = function()
  expect.error(function() list(1) end, '1.*not.*category')
  expect.error(function() list('aaa') end, 'aaa.*not.*category')
end

T['mock_nvim_web_devicons()'] = new_set()

T['mock_nvim_web_devicons()']['works'] = function()
  load_module({
    default = {
      file = { glyph = 'f', hl = 'Comment' },
      filetype = { glyph = 't', hl = 'Comment' },
      extension = { glyph = 'e', hl = 'Comment' },
    },
    extension = { myext = { glyph = 'E', hl = 'Constant' } },
    file = { myfile = { glyph = 'F', hl = 'String' } },
    filetype = { myfiletype = { glyph = 'T', hl = 'Special' } },
    os = { myos = { glyph = 'O', hl = 'Delimiter' } },
  })
  child.api.nvim_set_hl(0, 'Comment', { fg = '#aaaaaa', ctermfg = 248 })
  child.api.nvim_set_hl(0, 'Constant', { fg = '#e0e060', ctermfg = 185 })
  child.api.nvim_set_hl(0, 'String', { fg = '#60e060', ctermfg = 77 })
  child.api.nvim_set_hl(0, 'Special', { fg = '#e060e0', ctermfg = 170 })
  child.api.nvim_set_hl(0, 'Delimiter', { fg = '#60e0e0', ctermfg = 80 })

  expect.error(function() child.lua('require("nvim-web-devicons")') end, 'nvim%-web%-devicons.*not found')
  child.lua('MiniIcons.mock_nvim_web_devicons()')
  expect.no_error(function() child.lua('require("nvim-web-devicons")') end)

  child.lua('_G.devicons = require("nvim-web-devicons")')

  -- Should reasonable mock at least common functions which return something
  local get_icon = function(...) return child.lua_get('{ devicons.get_icon(...) }', { ... }) end
  eq(child.lua_get('{ devicons.get_icon("init.lua", nil) }'), { '', 'MiniIconsGreen' })
  eq(child.lua_get('{ devicons.get_icon(nil, "lua") }'), { '󰢱', 'MiniIconsAzure' })
  eq(child.lua_get('{ devicons.get_icon("hello.py", "lua", {}) }'), { '󰌠', 'MiniIconsYellow' })
  eq(child.lua_get('{ devicons.get_icon("init.lua", "lua", {}) }'), { '', 'MiniIconsGreen' })
  eq(child.lua_get('{ devicons.get_icon("xxx", nil, {}) }'), {})
  eq(child.lua_get('{ devicons.get_icon(nil, "xxx", {}) }'), {})
  eq(child.lua_get('{ devicons.get_icon("xxx", nil, { default = true }) }'), { 'f', 'Comment' })
  eq(child.lua_get('{ devicons.get_icon(nil, "xxx", { default = true }) }'), { 'e', 'Comment' })
  expect.error(function() child.lua('devicons.get_icon(1, nil, {})') end)
  expect.error(function() child.lua('devicons.get_icon(nil, 1, {})') end)

  local get_icon_by_filetype = function(...) return child.lua_get('{ devicons.get_icon_by_filetype(...) }', { ... }) end
  eq(get_icon_by_filetype('help', {}), { '󰋖', 'MiniIconsPurple' })
  eq(get_icon_by_filetype('xxx', {}), {})
  eq(get_icon_by_filetype('xxx', { default = true }), { 't', 'Comment' })

  eq(child.lua_get('{ devicons.get_icon_color("myfile", nil, {}) }'), { 'F', '#60e060' })
  eq(child.lua_get('{ devicons.get_icon_color("xxx", nil, {}) }'), {})
  eq(child.lua_get('{ devicons.get_icon_color("xxx", nil, { default = true }) }'), { 'f', '#aaaaaa' })

  eq(child.lua_get('{ devicons.get_icon_cterm_color("myfile", nil, {}) }'), { 'F', 77 })
  eq(child.lua_get('{ devicons.get_icon_cterm_color("xxx", nil, {}) }'), {})
  eq(child.lua_get('{ devicons.get_icon_cterm_color("xxx", nil, { default = true }) }'), { 'f', 248 })

  eq(child.lua_get('{ devicons.get_icon_colors("myfile", nil, {}) }'), { 'F', '#60e060', 77 })
  eq(child.lua_get('{ devicons.get_icon_colors("xxx", nil, {}) }'), {})
  eq(child.lua_get('{ devicons.get_icon_colors("xxx", nil, { default = true }) }'), { 'f', '#aaaaaa', 248 })

  eq(child.lua_get('{ devicons.get_icon_color_by_filetype("myfiletype", {}) }'), { 'T', '#e060e0' })
  eq(child.lua_get('{ devicons.get_icon_color_by_filetype("xxx", {}) }'), {})
  eq(child.lua_get('{ devicons.get_icon_color_by_filetype("xxx", { default = true }) }'), { 't', '#aaaaaa' })

  eq(child.lua_get('{ devicons.get_icon_cterm_color_by_filetype("myfiletype", {}) }'), { 'T', 170 })
  eq(child.lua_get('{ devicons.get_icon_cterm_color_by_filetype("xxx", {}) }'), {})
  eq(child.lua_get('{ devicons.get_icon_cterm_color_by_filetype("xxx", { default = true }) }'), { 't', 248 })

  eq(child.lua_get('{ devicons.get_icon_colors_by_filetype("myfiletype", {}) }'), { 'T', '#e060e0', 170 })
  eq(child.lua_get('{ devicons.get_icon_colors_by_filetype("xxx", {}) }'), {})
  eq(child.lua_get('{ devicons.get_icon_colors_by_filetype("xxx", { default = true }) }'), { 't', '#aaaaaa', 248 })

  eq(child.lua_get('devicons.get_icon_name_by_filetype("myfiletype")'), 'myfiletype')

  local ref_default_icon = { color = '#aaaaaa', cterm_color = '248', icon = 'f', name = 'Default' }
  eq(child.lua_get('devicons.get_default_icon()'), ref_default_icon)

  local ref_all = {
    default = ref_default_icon,
    myext = { color = '#e0e060', cterm_color = '185', icon = 'E', name = 'myext' },
    myfile = { color = '#60e060', cterm_color = '77', icon = 'F', name = 'myfile' },
    myos = { color = '#60e0e0', cterm_color = '80', icon = 'O', name = 'myos' },
  }
  local out_all = child.lua([[
    local t = devicons.get_icons()
    return {
      default = t[1],
      myext = t.myext,
      myfile = t.myfile,
      myos = t.myos,
      -- Should not be present, i.e. should be `nil`
      myfiletype = t.myfiletype,
    }
  ]])
  eq(out_all, ref_all)

  eq(child.lua_get('devicons.get_icons_by_desktop_environment()'), {})
  eq(child.lua_get('{ myext = devicons.get_icons_by_extension().myext }'), { myext = ref_all.myext })
  eq(child.lua_get('{ myfile = devicons.get_icons_by_filename().myfile }'), { myfile = ref_all.myfile })
  eq(child.lua_get('{ myos = devicons.get_icons_by_operating_system().myos }'), { myos = ref_all.myos })
  eq(child.lua_get('devicons.get_icons_by_window_manager()'), {})

  -- Should have others at least present
  local present =
    { 'has_loaded', 'refresh', 'set_default_icon', 'set_icon', 'set_icon_by_filetype', 'set_up_highlights', 'setup' }
  for _, method in ipairs(present) do
    eq(child.lua_get('type(devicons.' .. method .. ')'), 'function')
  end
end

return T
