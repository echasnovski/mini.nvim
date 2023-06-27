return {
  get_icon = function(filename, _, options)
    if filename == 'LICENSE' then return '', 'DevIconLicense' end
    if filename == 'Makefile' then return '', 'DevIconMakefile' end
    if vim.endswith(filename, 'gif') then return '', 'DevIconGif' end
    if vim.endswith(filename, 'lua') then return '', 'DevIconLua' end
    if vim.endswith(filename, 'txt') then return '', 'DevIconTxt' end
    if (options or {}).default then return '', 'DevIconDefault' end
  end,
}
