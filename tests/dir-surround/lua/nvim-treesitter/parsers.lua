local parser = {
  for_each_tree = function(_, f)
    local tree = { root = function(_) return {} end }
    local lang_tree = { lang = function(_) return 'lua' end }
    f(tree, lang_tree)
  end,
}

local get_parser = function(_) return parser end

return { get_parser = get_parser }
