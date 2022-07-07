return {
  get_icon = function(filename, extension, options)
    _G.devicons_args = { filename = filename, extension = extension, options = options }

    if filename == 'LICENSE' then return '', 'DevIconLicense' end
    if extension == 'lua' then return '', 'DevIconLua' end
    if extension == 'txt' then return '', 'DevIconTxt' end
    if (options or {}).default then return '', 'DevIconDefault' end
  end,
}
