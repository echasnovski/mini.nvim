; Source: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
[ (function_declaration) (function_definition) ] @function.outer

(function_declaration body: (_) @function.inner)
(function_definition body: (_) @function.inner)

; Custom
[ (return_statement) ] @return.outer

(return_statement (expression_list (_) @return.inner))

(string) @string
