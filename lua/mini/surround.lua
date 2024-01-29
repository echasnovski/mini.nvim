--- *mini.surround* Surround actions
--- *MiniSurround*
---
--- MIT License Copyright (c) 2021 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Fast and feature-rich surrounding. Can be configured to have experience
--- similar to 'tpope/vim-surround' (see |MiniSurround-vim-surround-config|).
---
--- Features:
--- - Actions (all of them are dot-repeatable out of the box and respect
---   |[count]|) with configurable keymappings:
---     - Add surrounding with `sa` (in visual mode or on motion).
---     - Delete surrounding with `sd`.
---     - Replace surrounding with `sr`.
---     - Find surrounding with `sf` or `sF` (move cursor right or left).
---     - Highlight surrounding with `sh`.
---     - Change number of neighbor lines with `sn` (see |MiniSurround-algorithm|).
---
--- - Surrounding is identified by a single character as both "input" (in
---   `delete` and `replace` start, `find`, and `highlight`) and "output" (in
---   `add` and `replace` end):
---     - 'f' - function call (string of alphanumeric symbols or '_' or '.'
---       followed by balanced '()'). In "input" finds function call, in
---       "output" prompts user to enter function name.
---     - 't' - tag. In "input" finds tag with same identifier, in "output"
---       prompts user to enter tag name.
---     - All symbols in brackets '()', '[]', '{}', '<>". In "input' represents
---       balanced brackets (open - with whitespace pad, close - without), in
---       "output" - left and right parts of brackets.
---     - '?' - interactive. Prompts user to enter left and right parts.
---     - All other alphanumeric, punctuation, or space characters represent
---       surrounding with identical left and right parts.
---
--- - Configurable search methods to find not only covering but possibly next,
---   previous, or nearest surrounding. See more in |MiniSurround.config|.
---
--- - All actions involving finding surrounding (delete, replace, find,
---   highlight) can be used with suffix that changes search method to find
---   previous/last. See more in |MiniSurround.config|.
---
--- Known issues which won't be resolved:
--- - Search for surrounding is done using Lua patterns (regex-like approach).
---   So certain amount of false positives should be expected.
---
--- - When searching for "input" surrounding, there is no distinction if it is
---   inside string or comment. So in this case there will be not proper match
---   for a function call: 'f(a = ")", b = 1)'.
---
--- - Tags are searched using regex-like methods, so issues are inevitable.
---   Overall it is pretty good, but certain cases won't work. Like self-nested
---   tags won't match correctly on both ends: '<a><a></a></a>'.
---
--- # Setup ~
---
--- This module needs a setup with `require('mini.surround').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniSurround` which you can use for scripting or manually (with
--- `:lua MiniSurround.*`).
---
--- See |MiniSurround.config| for `config` structure and default values.
---
--- You can override runtime config settings locally to buffer inside
--- `vim.b.minisurround_config` which should have same structure as
--- `MiniSurround.config`. See |mini.nvim-buffer-local-config| for more details.
---
--- To stop module from showing non-error feedback, set `config.silent = true`.
---
--- # Example usage ~
---
--- Regular mappings:
--- - `saiw)` - add (`sa`) for inner word (`iw`) parenthesis (`)`).
--- - `saiw?[[<CR>]]<CR>` - add (`sa`) for inner word (`iw`) interactive
---   surrounding (`?`): `[[` for left and `]]` for right.
--- - `2sdf` - delete (`sd`) second (`2`) surrounding function call (`f`).
--- - `sr)tdiv<CR>` - replace (`sr`) surrounding parenthesis (`)`) with tag
---   (`t`) with identifier 'div' (`div<CR>` in command line prompt).
--- - `sff` - find right (`sf`) part of surrounding function call (`f`).
--- - `sh}` - highlight (`sh`) for a brief period of time surrounding curly
---   brackets (`}`).
---
--- Extended mappings (temporary force "prev"/"next" search methods):
--- - `sdnf` - delete (`sd`) next (`n`) function call (`f`).
--- - `srlf(` - replace (`sd`) last (`l`) function call (`f`) with padded
---   bracket (`(`).
--- - `2sfnt` - find (`sf`) second (2) next (`n`) tag (`t`).
--- - `shl}` - highlight (`sh`) last (`l`) second (`2`) curly bracket (`}`).
---
--- # Comparisons ~
---
--- - 'tpope/vim-surround':
---     - 'vim-surround' has completely different, with other focus set of
---       default mappings, while 'mini.surround' has a more coherent set.
---     - 'mini.surround' supports dot-repeat, customized search path (see
---       |MiniSurround.config|), customized specifications (see
---       |MiniSurround-surround-specification|) allowing usage of tree-sitter
---       queries (see |MiniSurround.gen_spec.input.treesitter()|),
---       highlighting and finding surrounding, "last"/"next" extended
---       mappings. While 'vim-surround' does not.
--- - 'machakann/vim-sandwich':
---     - Both have same keybindings for common actions (add, delete, replace).
---     - Otherwise same differences as with 'tpop/vim-surround' (except
---       dot-repeat because 'vim-sandwich' supports it).
--- - 'kylechui/nvim-surround':
---     - 'nvim-surround' is designed after 'tpope/vim-surround' with same
---       default mappings and logic, while 'mini.surround' has mappings
---       similar to 'machakann/vim-sandwich'.
---     - 'mini.surround' has more flexible customization of input surrounding
---       (with composed patterns, region pair(s), search methods).
---     - 'mini.surround' supports |[count]| in both input and output
---       surrounding (see |MiniSurround-count|) while 'nvim-surround' doesn't.
---     - 'mini.surround' supports "last"/"next" extended mappings.
--- - |mini.ai|:
---     - Both use similar logic for finding target: textobject in 'mini.ai'
---       and surrounding pair in 'mini.surround'. While 'mini.ai' uses
---       extraction pattern for separate `a` and `i` textobjects,
---       'mini.surround' uses it to select left and right surroundings
---       (basically a difference between `a` and `i` textobjects).
---     - Some builtin specifications are slightly different:
---         - Quotes in 'mini.ai' are balanced, in 'mini.surround' they are not.
---         - The 'mini.surround' doesn't have argument surrounding.
---         - Default behavior in 'mini.ai' selects one of the edges into `a`
---           textobject, while 'mini.surround' - both.
---
--- # Highlight groups ~
---
--- * `MiniSurround` - highlighting of requested surrounding.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling ~
---
--- To disable, set `vim.g.minisurround_disable` (globally) or
--- `vim.b.minisurround_disable` (for a buffer) to `true`. Considering high
--- number of different scenarios and customization intentions, writing exact
--- rules for disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes.

--- Builtin surroundings ~
---
--- This table describes all builtin surroundings along with what they
--- represent. Explanation:
--- - `Key` represents the surrounding identifier: single character which should
---   be typed after action mappings (see |MiniSurround.config.mappings|).
--- - `Name` is a description of surrounding.
--- - `Example line` contains a string for which examples are constructed. The
---   `*` denotes the cursor position over `a` character.
--- - `Delete` shows the result of typing `sd` followed by surrounding identifier.
---   It aims to demonstrate "input" surrounding which is also used in replace
---   with `sr` (surrounding id is typed first), highlight with `sh`, find with
---   `sf` and `sF`.
--- - `Replace` shows the result of typing `sr!` followed by surrounding
---   identifier (with possible follow up from user). It aims to demonstrate
---   "output" surrounding which is also used in adding with `sa` (followed by
---   textobject/motion or in Visual mode).
---
--- Example: typing `sd)` with cursor on `*` (covers `a` character) changes line
--- `!( *a (bb) )!` into `! aa (bb) !`. Typing `sr!)` changes same initial line
--- into `(( aa (bb) ))`.
--- >
---  |Key|     Name      |  Example line |    Delete   |     Replace     |
---  |---|---------------|---------------|-------------|-----------------|
---  | ( |  Balanced ()  | !( *a (bb) )! |  !aa (bb)!  | ( ( aa (bb) ) ) |
---  | [ |  Balanced []  | ![ *a [bb] ]! |  !aa [bb]!  | [ [ aa [bb] ] ] |
---  | { |  Balanced {}  | !{ *a {bb} }! |  !aa {bb}!  | { { aa {bb} } } |
---  | < |  Balanced <>  | !< *a <bb> >! |  !aa <bb>!  | < < aa <bb> > > |
---  |---|---------------|---------------|-------------|-----------------|
---  | ) |  Balanced ()  | !( *a (bb) )! | ! aa (bb) ! | (( aa (bb) ))   |
---  | ] |  Balanced []  | ![ *a [bb] ]! | ! aa [bb] ! | [[ aa [bb] ]]   |
---  | } |  Balanced {}  | !{ *a {bb} }! | ! aa {bb} ! | {{ aa {bb} }}   |
---  | > |  Balanced <>  | !< *a <bb> >! | ! aa <bb> ! | << aa <bb> >>   |
---  | b |  Alias for    | !( *a {bb} )! | ! aa {bb} ! | (( aa {bb} ))   |
---  |   |  ), ], or }   |               |             |                 |
---  |---|---------------|---------------|-------------|-----------------|
---  | q |  Alias for    | !'aa'*a'aa'!  | !'aaaaaa'!  | "'aa'aa'aa'"    |
---  |   |  ", ', or `   |               |             |                 |
---  |---|---------------|---------------|-------------|-----------------|
---  | ? |  User prompt  | !e * o!       | ! a !       | ee a oo         |
---  |   |(typed e and o)|               |             |                 |
---  |---|---------------|---------------|-------------|-----------------|
---  | t |      Tag      | !<x>*</x>!    | !a!         | <y><x>a</x></y> |
---  |   |               |               |             | (typed y)       |
---  |---|---------------|---------------|-------------|-----------------|
---  | f | Function call | !f(*a, bb)!   | !aa, bb!    | g(f(*a, bb))    |
---  |   |               |               |             | (typed g)       |
---  |---|---------------|---------------|-------------|-----------------|
---  |   |    Default    | !_a*a_!       | !aaa!       | __aaa__         |
---  |   |   (typed _)   |               |             |                 |
---  |---|---------------|---------------|-------------|-----------------|
--- <
--- Notes:
--- - All examples assume default `config.search_method`.
--- - Open brackets differ from close brackets by how they treat inner edge
---   whitespace: open includes it left and right parts, close does not.
--- - Output value of `b` alias is same as `)`. For `q` alias - same as `"`.
--- - Default surrounding is activated for all characters which are not
---   configured surrounding identifiers. Note: due to special handling of
---   underlying `x.-x` Lua pattern (see |MiniSurround-search-algorithm|), it
---   doesn't really support non-trivial `[count]` for "cover" search method.
---@tag MiniSurround-surround-builtin

--- Note: this is similar to |MiniAi-glossary|.
---
--- - REGION - table representing region in a buffer. Fields: <from> and
---   <to> for inclusive start and end positions (<to> might be `nil` to
---   describe empty region). Each position is also a table with line <line>
---   and column <col> (both start at 1). Examples:
---   - `{ from = { line = 1, col = 1 }, to = { line = 2, col = 1 } }`
---   - `{ from = { line = 10, col = 10 } }` - empty region.
--- - REGION PAIR - table representing regions for left and right surroundings.
---   Fields: <left> and <right> with regions. Examples:
---   `{`
---     `left  = { from = { line = 1, col = 1 }, to = { line = 1, col = 1 } },`
---     `right = { from = { line = 1, col = 3 } },`
---   `}`
--- - PATTERN - string describing Lua pattern.
--- - SPAN - interval inside a string (end-exclusive). Like [1, 5). Equal
---   `from` and `to` edges describe empty span at that point.
--- - SPAN `A = [a1, a2)` COVERS `B = [b1, b2)` if every element of
---   `B` is within `A` (`a1 <= b < a2`).
---   It also is described as B IS NESTED INSIDE A.
--- - NESTED PATTERN - array of patterns aimed to describe nested spans.
--- - SPAN MATCHES NESTED PATTERN if there is a sequence of consecutively
---   nested spans each matching corresponding pattern within substring of
---   previous span (or input string for first span). Example:
---     Nested patterns: `{ '%b()', '^. .* .$' }` (balanced `()` with inner space)
---     Input string: `( ( () ( ) ) )`
---                   `123456789012345`
---   Here are all matching spans [1, 15) and [3, 13). Both [5, 7) and [8, 10)
---   match first pattern but not second. All other combinations of `(` and `)`
---   don't match first pattern (not balanced).
--- - COMPOSED PATTERN: array with each element describing possible pattern
---   (or array of them) at that place. Composed pattern basically defines all
---   possible combinations of nested pattern (their cartesian product).
---   Examples:
---     1. Composed pattern: `{ { '%b()', '%b[]' }, '^. .* .$' }`
---        Composed pattern expanded into equivalent array of nested patterns:
---         `{ '%b()', '^. .* .$' }` and `{ '%b[]', '^. .* .$' }`
---        Description: either balanced `()` or balanced `[]` but both with
---        inner edge space.
---     2. Composed pattern:
---        `{ { { '%b()', '^. .* .$' }, { '%b[]', '^.[^ ].*[^ ].$' } }, '.....' }`
---        Composed pattern expanded into equivalent array of nested patterns:
---        `{ '%b()', '^. .* .$', '.....' }` and
---        `{ '%b[]', '^.[^ ].*[^ ].$', '.....' }`
---        Description: either "balanced `()` with inner edge space" or
---        "balanced `[]` with no inner edge space", both with 5 or more characters.
--- - SPAN MATCHES COMPOSED PATTERN if it matches at least one nested pattern
---   from expanded composed pattern.
---@tag MiniSurround-glossary

--- Surround specification is a table with keys:
--- - <input> - defines how to find and extract surrounding for "input"
---   operations (like `delete`). See more in 'Input surrounding' setction.
--- - <output> - defines what to add on left and right for "output" operations
---   (like `add`). See more in 'Output surrounding' section.
---
--- Example of surround info for builtin `)` identifier: >
---   {
---     input = { '%b()', '^.().*().$' },
---     output = { left = '(', right = ')' }
---   }
--- <
--- # Input surrounding ~
---
--- Specification for input surrounding has a structure of composed pattern
--- (see |MiniSurround-glossary|) with two differences:
--- - Last pattern(s) should have two or four empty capture groups denoting
---   how the last string should be processed to extract surrounding parts:
---     - Two captures represent left part from start of string to first
---       capture and right part - from second capture to end of string.
---       Example: `a()b()c` defines left surrounding as 'a', right - 'c'.
---     - Four captures define left part inside captures 1 and 2, right part -
---       inside captures 3 and 4. Example: `a()()b()c()` defines left part as
---       empty, right part as 'c'.
--- - Allows callable objects (see |vim.is_callable()|) in certain places
---   (enables more complex surroundings in exchange of increase in configuration
---   complexity and computations):
---     - If specification itself is a callable, it will be called without
---       arguments and should return one of:
---         - Composed pattern. Useful for implementing user input. Example of
---           simplified variant of input surrounding for function call with
---           name taken from user prompt: >
---
---           function()
---             local left_edge = vim.pesc(vim.fn.input('Function name: '))
---             return { string.format('%s+%%b()', left_edge), '^.-%(().*()%)$' }
---           end
--- <
---         - Single region pair (see |MiniSurround-glossary|). Useful to allow
---           full control over surrounding. Will be taken as is. Example of
---           returning first and last lines of a buffer: >
---
---           function()
---             local n_lines = vim.fn.line('$')
---             return {
---               left = {
---                 from = { line = 1, col = 1 },
---                 to = { line = 1, col = vim.fn.getline(1):len() },
---               },
---               right = {
---                 from = { line = n_lines, col = 1 },
---                 to = { line = n_lines, col = vim.fn.getline(n_lines):len() },
---               },
---             }
---           end
--- <
---         - Array of region pairs. Useful for incorporating other instruments,
---           like treesitter (see |MiniSurround.gen_spec.treesitter()|). The
---           best region pair will be picked in the same manner as with composed
---           pattern (respecting options `n_lines`, `search_method`, etc.) using
---           output region (from start of left region to end of right region).
---           Example using edges of "best" line with display width more than 80: >
---
---           function()
---             local make_line_region_pair = function(n)
---               local left = { line = n, col = 1 }
---               local right = { line = n, col = vim.fn.getline(n):len() }
---               return {
---                 left = { from = left, to = left },
---                 right = { from = right, to = right },
---               }
---             end
---
---             local res = {}
---             for i = 1, vim.fn.line('$') do
---               if vim.fn.getline(i):len() > 80 then
---                 table.insert(res, make_line_region_pair(i))
---               end
---             end
---             return res
---           end
--- <
---     - If there is a callable instead of assumed string pattern, it is expected
---       to have signature `(line, init)` and behave like `pattern:find()`.
---       It should return two numbers representing span in `line` next after
---       or at `init` (`nil` if there is no such span).
---       !IMPORTANT NOTE!: it means that output's `from` shouldn't be strictly
---       to the left of `init` (it will lead to infinite loop). Not allowed as
---       last item (as it should be pattern with captures).
---       Example of matching only balanced parenthesis with big enough width: >
---
---         {
---           '%b()',
---           function(s, init)
---             if init > 1 or s:len() < 5 then return end
---             return 1, s:len()
---           end,
---           '^.().*().$'
---         }
--- <
--- More examples:
--- - See |MiniSurround.gen_spec| for function wrappers to create commonly used
---   surrounding specifications.
---
--- - Pair of balanced brackets from set (used for builtin `b` identifier):
---   `{ { '%b()', '%b[]', '%b{}' }, '^.().*().$' }`
---
--- - Lua block string: `{ '%[%[().-()%]%]' }`
---
--- # Output surrounding ~
---
--- A table with <left> (plain text string) and <right> (plain text string)
--- fields. Strings can contain new lines character `\n` to add multiline parts.
---
--- Examples:
--- - Lua block string: `{ left = '[[', right = ']]' }`
--- - Brackets on separate lines (indentation is not preserved):
---   `{ left = '(\n', right = '\n)' }`
---@tag MiniSurround-surround-specification

--- Count with actions
---
--- |[count]| is supported by all actions in the following ways:
---
--- - In add, two types of `[count]` is supported in Normal mode:
---   `[count1]sa[count2][textobject]`. The `[count1]` defines how many times
---   left and right parts of output surrounding will be repeated and `[count2]` is
---   used for textobject.
---   In Visual mode `[count]` is treated as `[count1]`.
---   Example: `2sa3aw)` and `v3aw2sa)` will result into textobject `3aw` being
---   surrounded by `((` and `))`.
---
--- - In delete/replace/find/highlight `[count]` means "find n-th surrounding
---   and execute operator on it".
---   Example: `2sd)` on line `(a(b(c)b)a)` with cursor on `c` will result into
---   `(ab(c)ba)` (and not in `(abcba)` if it would have meant "delete n times").
---@tag MiniSurround-count

--- Search algorithm design
---
--- Search for the input surrounding relies on these principles:
--- - Input surrounding specification is constructed based on surrounding
---   identifier (see |MiniSurround-surround-specification|).
--- - General search is done by converting some 2d buffer region (neighborhood
---   of reference region) into 1d string (each line is appended with `\n`).
---   Then search for a best span matching specification is done inside string
---   (see |MiniSurround-glossary|). After that, span is converted back into 2d
---   region. Note: first search is done inside reference region lines, and
---   only after that - inside its neighborhood within `config.n_lines` (see
---   |MiniSurround.config|).
--- - The best matching span is chosen by iterating over all spans matching
---   surrounding specification and comparing them with "current best".
---   Comparison also depends on reference region (tighter covering is better,
---   otherwise closer is better) and search method (if span is even considered).
--- - Extract pair of spans (for left and right regions in region pair) based
---   on extraction pattern (last item in nested pattern).
--- - For |[count]| greater than 1, steps are repeated with current best match
---   becoming reference region. One such additional step is also done if final
---   region is equal to reference region.
---
--- Notes:
--- - Iteration over all matched spans is done in depth-first fashion with
---   respect to nested pattern.
--- - It is guaranteed that span is compared only once.
--- - For the sake of increasing functionality, during iteration over all
---   matching spans, some Lua patterns in composed pattern are handled
---   specially.
---     - `%bxx` (`xx` is two identical characters). It denotes balanced pair
---       of identical characters and results into "paired" matches. For
---       example, `%b""` for `"aa" "bb"` would match `"aa"` and `"bb"`, but
---       not middle `" "`.
---     - `x.-y` (`x` and `y` are different strings). It results only in matches with
---       smallest width. For example, `e.-o` for `e e o o` will result only in
---       middle `e o`. Note: it has some implications for when parts have
---       quantifiers (like `+`, etc.), which usually can be resolved with
---       frontier pattern `%f[]`.
---@tag MiniSurround-search-algorithm

-- Module definition ==========================================================
local MiniSurround = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniSurround.config|.
---
---@usage `require('mini.surround').setup({})` (replace `{}` with your `config` table)
MiniSurround.setup = function(config)
  -- Export module
  _G.MiniSurround = MiniSurround

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Create default highlighting
  H.create_default_hl()
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text                                               *MiniSurround-vim-surround-config*
--- # Setup similar to 'tpope/vim-surround' ~
---
--- This module is primarily designed after 'machakann/vim-sandwich'. To get
--- behavior closest to 'tpope/vim-surround' (but not identical), use this setup:
--- >
---   require('mini.surround').setup({
---     mappings = {
---       add = 'ys',
---       delete = 'ds',
---       find = '',
---       find_left = '',
---       highlight = '',
---       replace = 'cs',
---       update_n_lines = '',
---
---       -- Add this only if you don't want to use extended mappings
---       suffix_last = '',
---       suffix_next = '',
---     },
---     search_method = 'cover_or_next',
---   })
---
---   -- Remap adding surrounding to Visual mode selection
---   vim.keymap.del('x', 'ys')
---   vim.keymap.set('x', 'S', [[:<C-u>lua MiniSurround.add('visual')<CR>]], { silent = true })
---
---   -- Make special mapping for "add surrounding for line"
---   vim.keymap.set('n', 'yss', 'ys_', { remap = true })
--- <
--- # Options ~
---
--- ## Custom surroundings ~
---
--- User can define own surroundings by supplying `config.custom_surroundings`.
--- It should be a **table** with keys being single character surrounding
--- identifier and values - surround specification (see
--- |MiniSurround-surround-specification|).
---
--- General recommendations:
--- - In `config.custom_surroundings` only some data can be defined (like only
---   `output`). Other fields will be taken from builtin surroundings.
--- - Function returning surround info at <input> or <output> fields of
---   specification is helpful when user input is needed (like asking for
---   function name). Use |input()| or |MiniSurround.user_input()|. Return
---   `nil` to stop any current surround operation.
---
--- Examples of using `config.custom_surroundings` (see more examples at
--- |MiniSurround.gen_spec|):
--- >
---   local surround = require('mini.surround')
---   surround.setup({
---     custom_surroundings = {
---       -- Make `)` insert parts with spaces. `input` pattern stays the same.
---       [')'] = { output = { left = '( ', right = ' )' } },
---
---       -- Use function to compute surrounding info
---       ['*'] = {
---         input = function()
---           local n_star = MiniSurround.user_input('Number of * to find: ')
---           local many_star = string.rep('%*', tonumber(n_star) or 1)
---           return { many_star .. '().-()' .. many_star }
---         end,
---         output = function()
---           local n_star = MiniSurround.user_input('Number of * to output: ')
---           local many_star = string.rep('*', tonumber(n_star) or 1)
---           return { left = many_star, right = many_star }
---         end,
---       },
---     },
---   })
---
---   -- Create custom surrounding for Lua's block string `[[...]]`. Use this inside
---   -- autocommand or 'after/ftplugin/lua.lua' file.
---   vim.b.minisurround_config = {
---     custom_surroundings = {
---       s = {
---         input = { '%[%[().-()%]%]' },
---         output = { left = '[[', right = ']]' },
---       },
---     },
---   }
--- <
--- ## Respect selection type ~
---
--- Boolean option `config.respect_selection_type` controls whether to respect
--- selection type when adding and deleting surrounding. When enabled:
--- - Linewise adding places surroundings on separate lines while indenting
---   surrounded lines ones.
--- - Deleting surroundings which look like they were the result of linewise
---   adding will act to revert it: delete lines with surroundings and dedent
---   surrounded lines ones.
--- - Blockwise adding places surroundings on whole edges, not only start and
---   end of selection. Note: it doesn't really work outside of text and in
---   presence of multibyte characters; and probably won't due to
---   implementation difficulties.
---
--- ## Search method ~
---
--- Value of `config.search_method` defines how best match search is done.
--- Based on its value, one of the following matches will be selected:
--- - Covering match. Left/right edge is before/after left/right edge of
---   reference region.
--- - Previous match. Left/right edge is before left/right edge of reference
---   region.
--- - Next match. Left/right edge is after left/right edge of reference region.
--- - Nearest match. Whichever is closest among previous and next matches.
---
--- Possible values are:
--- - `'cover'` - use only covering match. Don't use either previous or
---   next; report that there is no surrounding found.
--- - `'cover_or_next'` (default) - use covering match. If not found, use next.
--- - `'cover_or_prev'` - use covering match. If not found, use previous.
--- - `'cover_or_nearest'` - use covering match. If not found, use nearest.
--- - `'next'` - use next match.
--- - `'previous'` - use previous match.
--- - `'nearest'` - use nearest match.
---
--- Note: search is first performed on the reference region lines and only
--- after failure - on the whole neighborhood defined by `config.n_lines`. This
--- means that with `config.search_method` not equal to `'cover'`, "previous"
--- or "next" surrounding will end up as search result if they are found on
--- first stage although covering match might be found in bigger, whole
--- neighborhood. This design is based on observation that most of the time
--- operation is done within reference region lines (usually cursor line).
---
--- Here is an example of how replacing `)` with `]` surrounding is done based
--- on a value of `'config.search_method'` when cursor is inside `bbb` word:
--- - `'cover'`:         `(a) bbb (c)` -> `(a) bbb (c)` (with message)
--- - `'cover_or_next'`: `(a) bbb (c)` -> `(a) bbb [c]`
--- - `'cover_or_prev'`: `(a) bbb (c)` -> `[a] bbb (c)`
--- - `'cover_or_nearest'`: depends on cursor position.
---   For first and second `b` - as in `cover_or_prev` (as previous match is
---   nearer), for third - as in `cover_or_next` (as next match is nearer).
--- - `'next'`:          `(a) bbb (c)` -> `(a) bbb [c]`. Same outcome for `(bbb)`.
--- - `'prev'`:          `(a) bbb (c)` -> `[a] bbb (c)`. Same outcome for `(bbb)`.
--- - `'nearest'`: depends on cursor position (same as in `'cover_or_nearest'`).
---
--- ## Search suffixes ~
---
--- To provide more searching possibilities, 'mini.surround' creates extended
--- mappings force "prev" and "next" methods for particular search. It does so
--- by appending mapping with certain suffix: `config.mappings.suffix_last` for
--- mappings which will use "prev" search method, `config.mappings.suffix_next`
--- - "next" search method.
---
--- Notes:
--- - It creates new mappings only for actions involving surrounding search:
---   delete, replace, find (right and left), highlight.
--- - All new mappings behave the same way as if `config.search_method` is set
---   to certain search method. They are dot-repeatable, respect |[count]|, etc.
--- - Supply empty string to disable creation of corresponding set of mappings.
---
--- Example with default values (`n` for `suffix_next`, `l` for `suffix_last`)
--- and initial line `(aa) (bb) (cc)`.
--- - Typing `sdn)` with cursor inside `(aa)` results into `(aa) bb (cc)`.
--- - Typing `sdl)` with cursor inside `(cc)` results into `(aa) bb (cc)`.
--- - Typing `2srn)]` with cursor inside `(aa)` results into `(aa) (bb) [cc]`.
MiniSurround.config = {
  -- Add custom surroundings to be used on top of builtin ones. For more
  -- information with examples, see `:h MiniSurround.config`.
  custom_surroundings = nil,

  -- Duration (in ms) of highlight when calling `MiniSurround.highlight()`
  highlight_duration = 500,

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    add = 'sa', -- Add surrounding in Normal and Visual modes
    delete = 'sd', -- Delete surrounding
    find = 'sf', -- Find surrounding (to the right)
    find_left = 'sF', -- Find surrounding (to the left)
    highlight = 'sh', -- Highlight surrounding
    replace = 'sr', -- Replace surrounding
    update_n_lines = 'sn', -- Update `n_lines`

    suffix_last = 'l', -- Suffix to search with "prev" method
    suffix_next = 'n', -- Suffix to search with "next" method
  },

  -- Number of lines within which surrounding is searched
  n_lines = 20,

  -- Whether to respect selection type:
  -- - Place surroundings on separate lines in linewise mode.
  -- - Place surroundings on each line in blockwise mode.
  respect_selection_type = false,

  -- How to search for surrounding (first inside current line, then inside
  -- neighborhood). One of 'cover', 'cover_or_next', 'cover_or_prev',
  -- 'cover_or_nearest', 'next', 'prev', 'nearest'. For more details,
  -- see `:h MiniSurround.config`.
  search_method = 'cover',

  -- Whether to disable showing non-error feedback
  silent = false,
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Add surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
---
---@param mode string Mapping mode (normal by default).
MiniSurround.add = function(mode)
  -- Needed to disable in visual mode
  if H.is_disabled() then return '<Esc>' end

  -- Get marks' positions based on current mode
  local marks = H.get_marks_pos(mode)

  -- Get surround info. Try take from cache only in not visual mode (as there
  -- is no intended dot-repeatability).
  local surr_info
  if mode == 'visual' then
    surr_info = H.get_surround_spec('output', false)
  else
    surr_info = H.get_surround_spec('output', true)
  end
  if surr_info == nil then return '<Esc>' end

  -- Extend parts based on provided `[count]` before operator (if this is not
  -- from dot-repeat and was done already)
  if not surr_info.did_count then
    local count = H.cache.count or vim.v.count1
    surr_info.left, surr_info.right = surr_info.left:rep(count), surr_info.right:rep(count)
    surr_info.did_count = true
  end

  -- Add surrounding.
  -- Possibly deal with linewise and blockwise addition separately
  local respect_selection_type = H.get_config().respect_selection_type

  if not respect_selection_type or marks.selection_type == 'charwise' then
    -- Begin insert from right to not break column numbers
    -- Insert after the right mark (`+ 1` is for that)
    H.region_replace({ from = { line = marks.second.line, col = marks.second.col + 1 } }, surr_info.right)
    H.region_replace({ from = marks.first }, surr_info.left)

    -- Set cursor to be on the right of left surrounding
    H.set_cursor(marks.first.line, marks.first.col + surr_info.left:len())

    return
  end

  if marks.selection_type == 'linewise' then
    local from_line, to_line = marks.first.line, marks.second.line

    -- Save current range indent and indent surrounded lines
    local init_indent = H.get_range_indent(from_line, to_line)
    H.shift_indent('>', from_line, to_line)

    -- Put cursor on the start of first surrounded line
    H.set_cursor_nonblank(from_line)

    -- Put surroundings on separate lines
    vim.fn.append(to_line, init_indent .. surr_info.right)
    vim.fn.append(from_line - 1, init_indent .. surr_info.left)

    return
  end

  if marks.selection_type == 'blockwise' then
    -- NOTE: this doesn't work with mix of multibyte and normal characters, as
    -- well as outside of text lines.
    local from_col, to_col = marks.first.col, marks.second.col
    -- - Ensure that `to_col` is to the right of `from_col`. Can be not the
    --   case if visual block was selected from "south-west" to "north-east".
    from_col, to_col = math.min(from_col, to_col), math.max(from_col, to_col)

    for i = marks.first.line, marks.second.line do
      H.region_replace({ from = { line = i, col = to_col + 1 } }, surr_info.right)
      H.region_replace({ from = { line = i, col = from_col } }, surr_info.left)
    end

    H.set_cursor(marks.first.line, from_col + surr_info.left:len())

    return
  end
end

--- Delete surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
MiniSurround.delete = function()
  -- Find input surrounding region
  local surr = H.find_surrounding(H.get_surround_spec('input', true))
  if surr == nil then return '<Esc>' end

  -- Delete surrounding region. Begin with right to not break column numbers.
  H.region_replace(surr.right, {})
  H.region_replace(surr.left, {})

  -- Set cursor to be on the right of deleted left surrounding
  local from = surr.left.from
  H.set_cursor(from.line, from.col)

  -- Possibly tweak deletion of linewise surrounding. Should act as reverse to
  -- linewise addition.
  if not H.get_config().respect_selection_type then return end

  local from_line, to_line = surr.left.from.line, surr.right.from.line
  local is_linewise_delete = from_line < to_line and H.is_line_blank(from_line) and H.is_line_blank(to_line)
  if is_linewise_delete then
    -- Dedent surrounded lines
    H.shift_indent('<', from_line, to_line)

    -- Place cursor on first surrounded line
    H.set_cursor_nonblank(from_line + 1)

    -- Delete blank lines left after deleting surroundings
    local buf_id = vim.api.nvim_get_current_buf()
    vim.fn.deletebufline(buf_id, to_line)
    vim.fn.deletebufline(buf_id, from_line)
  end
end

--- Replace surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
MiniSurround.replace = function()
  -- Find input surrounding region
  local surr = H.find_surrounding(H.get_surround_spec('input', true))
  if surr == nil then return '<Esc>' end

  -- Get output surround info
  local new_surr_info = H.get_surround_spec('output', true)
  if new_surr_info == nil then return '<Esc>' end

  -- Replace by parts starting from right to not break column numbers
  H.region_replace(surr.right, new_surr_info.right)
  H.region_replace(surr.left, new_surr_info.left)

  -- Set cursor to be on the right of left surrounding
  local from = surr.left.from
  H.set_cursor(from.line, from.col + new_surr_info.left:len())
end

--- Find surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
MiniSurround.find = function()
  -- Find surrounding region
  local surr = H.find_surrounding(H.get_surround_spec('input', true))
  if surr == nil then return '<Esc>' end

  -- Make array of unique positions to cycle through
  local pos_array = H.surr_to_pos_array(surr)

  -- Cycle cursor through positions
  local dir = H.cache.direction or 'right'
  H.cursor_cycle(pos_array, dir)

  -- Open 'enough folds' to show cursor
  vim.cmd('normal! zv')
end

--- Highlight surrounding
---
--- No need to use it directly, everything is setup in |MiniSurround.setup|.
MiniSurround.highlight = function()
  -- Find surrounding region
  local surr = H.find_surrounding(H.get_surround_spec('input', true))
  if surr == nil then return '<Esc>' end

  -- Highlight surrounding region
  local config = H.get_config()
  local buf_id = vim.api.nvim_get_current_buf()

  H.region_highlight(buf_id, surr.left)
  H.region_highlight(buf_id, surr.right)

  vim.defer_fn(function()
    H.region_unhighlight(buf_id, surr.left)
    H.region_unhighlight(buf_id, surr.right)
  end, config.highlight_duration)
end

--- Update `MiniSurround.config.n_lines`
---
--- Convenient wrapper for updating `MiniSurround.config.n_lines` in case the
--- default one is not appropriate.
MiniSurround.update_n_lines = function()
  if H.is_disabled() then return '<Esc>' end

  local n_lines = MiniSurround.user_input('New number of neighbor lines', MiniSurround.config.n_lines)
  n_lines = math.floor(tonumber(n_lines) or MiniSurround.config.n_lines)
  MiniSurround.config.n_lines = n_lines
end

--- Ask user for input
---
--- This is mainly a wrapper for |input()| which allows empty string as input,
--- cancelling with `<Esc>` and `<C-c>`, and slightly modifies prompt. Use it
--- to ask for input inside function custom surrounding (see |MiniSurround.config|).
MiniSurround.user_input = function(prompt, text)
  -- Major issue with both `vim.fn.input()` is that the only way to distinguish
  -- cancelling with `<Esc>` and entering empty string with immediate `<CR>` is
  -- through `cancelreturn` option (see `:h input()`). In that case the return
  -- of `cancelreturn` will mean actual cancel, which removes possibility of
  -- using that string. Although doable with very obscure string, this is not
  -- very clean.
  -- Overcome this by adding temporary keystroke listener.
  local on_key = vim.on_key or vim.register_keystroke_callback
  local was_cancelled = false
  on_key(function(key)
    if key == vim.api.nvim_replace_termcodes('<Esc>', true, true, true) then was_cancelled = true end
  end, H.ns_id.input)

  -- Ask for input
  -- NOTE: it would be GREAT to make this work with `vim.ui.input()` but I
  -- didn't find a way to make it work without major refactor of whole module.
  -- The main issue is that `vim.ui.input()` is designed to perform action in
  -- callback and current module design is to get output immediately. Although
  -- naive approach of
  -- `local res; vim.ui.input({...}, function(input) res = input end)`
  -- works in default `vim.ui.input`, its reimplementations can return from it
  -- immediately and proceed in main event loop. Couldn't find a relatively
  -- simple way to stop execution of this current function until `ui.input()`'s
  -- callback finished execution.
  local opts = { prompt = '(mini.surround) ' .. prompt .. ': ', default = text or '' }
  vim.cmd('echohl Question')
  -- Use `pcall` to allow `<C-c>` to cancel user input
  local ok, res = pcall(vim.fn.input, opts)
  vim.cmd([[echohl None | echo '' | redraw]])

  -- Stop key listening
  on_key(nil, H.ns_id.input)

  if not ok or was_cancelled then return end
  return res
end

--- Generate common surrounding specifications
---
--- This is a table with two sets of generator functions: <input> and <output>
--- (currently empty). Each is a table with values being function generating
--- corresponding surrounding specification.
---
--- Example: >
---   local ts_input = require('mini.surround').gen_spec.input.treesitter
---   require('mini.surround').setup({
---     custom_surroundings = {
---       -- Use tree-sitter to search for function call
---       f = {
---         input = ts_input({ outer = '@call.outer', inner = '@call.inner' })
---       },
---     }
---   })
---
---@seealso |MiniAi.gen_spec|
MiniSurround.gen_spec = { input = {}, output = {} }

--- Treesitter specification for input surrounding
---
--- This is a specification in function form. When called with a pair of
--- treesitter captures, it returns a specification function outputting an
--- array of region pairs derived from <outer> and <inner> captures. It first
--- searches for all matched nodes of outer capture and then completes each one
--- with the biggest match of inner capture inside that node (if any). The result
--- region pair is a difference between regions of outer and inner captures.
---
--- In order for this to work, apart from working treesitter parser for desired
--- language, user should have a reachable language-specific 'textobjects'
--- query (see |vim.treesitter.query.get()| or |get_query()|, depending on your
--- Neovim version).
--- The most straightforward way for this is to have 'textobjects.scm' query
--- file with treesitter captures stored in some recognized path. This is
--- primarily designed to be compatible with plugin
--- 'nvim-treesitter/nvim-treesitter-textobjects', but can be used without it.
---
--- Two most common approaches for having a query file:
--- - Install 'nvim-treesitter/nvim-treesitter-textobjects'. It has curated and
---   well maintained builtin query files for many languages with a standardized
---   capture names, like `call.outer`, `call.inner`, etc.
--- - Manually create file 'after/queries/<language name>/textobjects.scm' in
---   your |$XDG_CONFIG_HOME| directory. It should contain queries with
---   captures (later used to define surrounding parts). See |lua-treesitter-query|.
--- To verify that query file is reachable, run (example for "lua" language)
--- `:lua print(vim.inspect(vim.treesitter.query.get_files('lua', 'textobjects')))`
--- (output should have at least an intended file).
---
--- Example configuration for function definition textobject with
--- 'nvim-treesitter/nvim-treesitter-textobjects' captures:
--- >
---   local ts_input = require('mini.surround').gen_spec.input.treesitter
---   require('mini.surround').setup({
---     custom_textobjects = {
---       f = ts_input({ outer = '@call.outer', inner = '@call.inner' }),
---     }
---   })
--- <
--- Notes:
--- - By default query is done using 'nvim-treesitter' plugin if it is present
---   (falls back to builtin methods otherwise). This allows for a more
---   advanced features (like multiple buffer languages, custom directives, etc.).
---   See `opts.use_nvim_treesitter` for how to disable this.
--- - It uses buffer's |filetype| to determine query language.
--- - On large files it is slower than pattern-based textobjects. Still very
---   fast though (one search should be magnitude of milliseconds or tens of
---   milliseconds on really large file).
---
---@param captures table Captures for outer and inner parts of region pair:
---   table with <outer> and <inner> fields with captures for outer
---   (`[left.form; right.to]`) and inner (`(left.to; right.from)` both edges
---   exclusive, i.e. they won't be a part of surrounding) regions. Each value
---   should be a string capture starting with `'@'`.
---@param opts table|nil Options. Possible values:
---   - <use_nvim_treesitter> - whether to try to use 'nvim-treesitter' plugin
---     (if present) to do the query. It implements more advanced behavior at
---     cost of increased execution time. Provides more coherent experience if
---     'nvim-treesitter-textobjects' queries are used. Default: `true`.
---
---@return function Function which returns array of current buffer region pairs
---   representing differences between outer and inner captures.
---
---@seealso |MiniSurround-surround-specification| for how this type of
---   surrounding specification is processed.
--- |get_query()| for how query is fetched in case of no 'nvim-treesitter'.
--- |Query:iter_captures()| for how all query captures are iterated in case of
---   no 'nvim-treesitter'.
--- |MiniAi.gen_spec.treesitter()| for similar 'mini.ai' generator.
MiniSurround.gen_spec.input.treesitter = function(captures, opts)
  opts = vim.tbl_deep_extend('force', { use_nvim_treesitter = true }, opts or {})
  captures = H.prepare_captures(captures)

  return function()
    -- Get array of matched treesitter nodes
    local has_nvim_treesitter = pcall(require, 'nvim-treesitter') and pcall(require, 'nvim-treesitter.query')
    local node_pair_querier = (has_nvim_treesitter and opts.use_nvim_treesitter) and H.get_matched_node_pairs_plugin
      or H.get_matched_node_pairs_builtin
    local matched_node_pairs = node_pair_querier(captures)

    -- Return array of region pairs
    return vim.tbl_map(function(node_pair)
      -- `node:range()` returns 0-based numbers for end-exclusive region
      local left_from_line, left_from_col, right_to_line, right_to_col = node_pair.outer:range()
      local left_from = { line = left_from_line + 1, col = left_from_col + 1 }
      local right_to = { line = right_to_line + 1, col = right_to_col }

      local left_to, right_from
      if node_pair.inner == nil then
        left_to = right_to
        right_from = H.pos_to_right(right_to)
        right_to = nil
      else
        local left_to_line, left_to_col, right_from_line, right_from_col = node_pair.inner:range()
        left_to = { line = left_to_line + 1, col = left_to_col + 1 }
        right_from = { line = right_from_line + 1, col = right_from_col }
        -- Take into account that inner capture should be both edges exclusive
        left_to, right_from = H.pos_to_left(left_to), H.pos_to_right(right_from)
      end

      return { left = { from = left_from, to = left_to }, right = { from = right_from, to = right_to } }
    end, matched_node_pairs)
  end
end

-- Helper data ================================================================
-- Module default config
H.default_config = vim.deepcopy(MiniSurround.config)

-- Namespaces to be used within module
H.ns_id = {
  highlight = vim.api.nvim_create_namespace('MiniSurroundHighlight'),
  input = vim.api.nvim_create_namespace('MiniSurroundInput'),
}

--stylua: ignore
-- Builtin surroundings
H.builtin_surroundings = {
  -- Use balanced pair for brackets. Use opening ones to possibly
  -- replace/delete innder edge whitespace.
  ['('] = { input = { '%b()', '^.%s*().-()%s*.$' }, output = { left = '( ', right = ' )' } },
  [')'] = { input = { '%b()', '^.().*().$' },       output = { left = '(',  right = ')' } },
  ['['] = { input = { '%b[]', '^.%s*().-()%s*.$' }, output = { left = '[ ', right = ' ]' } },
  [']'] = { input = { '%b[]', '^.().*().$' },       output = { left = '[',  right = ']' } },
  ['{'] = { input = { '%b{}', '^.%s*().-()%s*.$' }, output = { left = '{ ', right = ' }' } },
  ['}'] = { input = { '%b{}', '^.().*().$' },       output = { left = '{',  right = '}' } },
  ['<'] = { input = { '%b<>', '^.%s*().-()%s*.$' }, output = { left = '< ', right = ' >' } },
  ['>'] = { input = { '%b<>', '^.().*().$' },       output = { left = '<',  right = '>' } },
  -- Derived from user prompt
  ['?'] = {
    input = function()
      local left = MiniSurround.user_input('Left surrounding')
      if left == nil or left == '' then return end
      local right = MiniSurround.user_input('Right surrounding')
      if right == nil or right == '' then return end

      return { vim.pesc(left) .. '().-()' .. vim.pesc(right) }
    end,
    output = function()
      local left = MiniSurround.user_input('Left surrounding')
      if left == nil then return end
      local right = MiniSurround.user_input('Right surrounding')
      if right == nil then return end
      return { left = left, right = right }
    end,
  },
  -- Brackets
  ['b'] = { input = { { '%b()', '%b[]', '%b{}' }, '^.().*().$' }, output = { left = '(', right = ')' } },
  -- Function call
  ['f'] = {
    input = { '%f[%w_%.][%w_%.]+%b()', '^.-%(().*()%)$' },
    output = function()
      local fun_name = MiniSurround.user_input('Function name')
      if fun_name == nil then return nil end
      return { left = ('%s('):format(fun_name), right = ')' }
    end,
  },
  -- Tag
  ['t'] = {
    input = { '<(%w-)%f[^<%w][^<>]->.-</%1>', '^<.->().*()</[^/]->$' },
    output = function()
      local tag_full = MiniSurround.user_input('Tag name')
      if tag_full == nil then return nil end
      local tag_name = tag_full:match('^%S*')
      return { left = '<' .. tag_full .. '>', right = '</' .. tag_name .. '>' }
    end,
  },
  -- Quotes
  ['q'] = { input = { { "'.-'", '".-"', '`.-`' }, '^.().*().$' }, output = { left = '"', right = '"' } },
}

-- Cache for dot-repeatability. This table is currently used with these keys:
-- - 'input' - surround info for searching (in 'delete' and 'replace' start).
-- - 'output' - surround info for adding (in 'add' and 'replace' end).
-- - 'direction' - direction in which `MiniSurround.find()` should go. Used to
--   enable same `operatorfunc` pattern for dot-repeatability.
-- - 'search_method' - search method.
-- - 'msg_shown' - whether helper message was shown.
H.cache = {}

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  -- Validate per nesting level to produce correct error message
  vim.validate({
    custom_surroundings = { config.custom_surroundings, 'table', true },
    highlight_duration = { config.highlight_duration, 'number' },
    mappings = { config.mappings, 'table' },
    n_lines = { config.n_lines, 'number' },
    respect_selection_type = { config.respect_selection_type, 'boolean' },
    search_method = { config.search_method, H.is_search_method },
    silent = { config.silent, 'boolean' },
  })

  vim.validate({
    ['mappings.add'] = { config.mappings.add, 'string' },
    ['mappings.delete'] = { config.mappings.delete, 'string' },
    ['mappings.find'] = { config.mappings.find, 'string' },
    ['mappings.find_left'] = { config.mappings.find_left, 'string' },
    ['mappings.highlight'] = { config.mappings.highlight, 'string' },
    ['mappings.replace'] = { config.mappings.replace, 'string' },
    ['mappings.update_n_lines'] = { config.mappings.update_n_lines, 'string' },

    ['mappings.suffix_last'] = { config.mappings.suffix_last, 'string' },
    ['mappings.suffix_next'] = { config.mappings.suffix_next, 'string' },
  })

  return config
end

H.apply_config = function(config)
  MiniSurround.config = config

  local expr_map = function(lhs, rhs, desc) H.map('n', lhs, rhs, { expr = true, desc = desc }) end
  --stylua: ignore start
  -- Make regular mappings
  local m = config.mappings

  expr_map(m.add,       H.make_operator('add', nil, nil, true), 'Add surrounding')
  expr_map(m.delete,    H.make_operator('delete'),              'Delete surrounding')
  expr_map(m.replace,   H.make_operator('replace'),             'Replace surrounding')
  expr_map(m.find,      H.make_operator('find', 'right'),       'Find right surrounding')
  expr_map(m.find_left, H.make_operator('find', 'left'),        'Find left surrounding')
  expr_map(m.highlight, H.make_operator('highlight'),           'Highlight surrounding')

  H.map('n', m.update_n_lines, MiniSurround.update_n_lines, { desc = 'Update `MiniSurround.config.n_lines`' })
  H.map('x', m.add, [[:<C-u>lua MiniSurround.add('visual')<CR>]], { desc = 'Add surrounding to selection' })

  -- Make extended mappings
  local suffix_map = function(lhs, suffix, rhs, desc)
    -- Don't create extended mapping if user chose not to create regular one
    if lhs == '' then return end
    expr_map(lhs .. suffix, rhs, desc)
  end

  if m.suffix_last ~= '' then
    local operator_prev = function(method, direction)
      return H.make_operator(method, direction, 'prev')
    end

    local suff = m.suffix_last
    suffix_map(m.delete,    suff, operator_prev('delete'),        'Delete previous surrounding')
    suffix_map(m.replace,   suff, operator_prev('replace'),       'Replace previous surrounding')
    suffix_map(m.find,      suff, operator_prev('find', 'right'), 'Find previous right surrounding')
    suffix_map(m.find_left, suff, operator_prev('find', 'left'),  'Find previous left surrounding')
    suffix_map(m.highlight, suff, operator_prev('highlight'),     'Highlight previous surrounding')
  end

  if m.suffix_next ~= '' then
    local operator_next = function(method, direction)
      return H.make_operator(method, direction, 'next')
    end

    local suff = m.suffix_next
    suffix_map(m.delete,    suff, operator_next('delete'),        'Delete next surrounding')
    suffix_map(m.replace,   suff, operator_next('replace'),       'Replace next surrounding')
    suffix_map(m.find,      suff, operator_next('find', 'right'), 'Find next right surrounding')
    suffix_map(m.find_left, suff, operator_next('find', 'left'),  'Find next left surrounding')
    suffix_map(m.highlight, suff, operator_next('highlight'),     'Highlight next surrounding')
  end
  --stylua: ignore end
end

H.create_default_hl = function() vim.api.nvim_set_hl(0, 'MiniSurround', { default = true, link = 'IncSearch' }) end

H.is_disabled = function() return vim.g.minisurround_disable == true or vim.b.minisurround_disable == true end

H.get_config = function(config)
  return vim.tbl_deep_extend('force', MiniSurround.config, vim.b.minisurround_config or {}, config or {})
end

H.is_search_method = function(x, x_name)
  x = x or H.get_config().search_method
  x_name = x_name or '`config.search_method`'

  local allowed_methods = vim.tbl_keys(H.span_compare_methods)
  if vim.tbl_contains(allowed_methods, x) then return true end

  table.sort(allowed_methods)
  local allowed_methods_string = table.concat(vim.tbl_map(vim.inspect, allowed_methods), ', ')
  local msg = ([[%s should be one of %s.]]):format(x_name, allowed_methods_string)
  return false, msg
end

H.validate_search_method = function(x, x_name)
  local is_valid, msg = H.is_search_method(x, x_name)
  if not is_valid then H.error(msg) end
end

-- Mappings -------------------------------------------------------------------
H.make_operator = function(task, direction, search_method, ask_for_textobject)
  return function()
    if H.is_disabled() then
      -- Using `<Esc>` helps to stop moving cursor caused by current
      -- implementation detail of adding `' '` inside expression mapping
      return [[\<Esc>]]
    end

    H.cache = { count = vim.v.count1, direction = direction, search_method = search_method }

    vim.o.operatorfunc = 'v:lua.MiniSurround.' .. task

    -- NOTEs:
    -- - Prepend with command to reset `vim.v.count1` to allow
    -- `[count1]sa[count2][textobject]`.
    -- - Concatenate `' '` to operator output to "disable" motion
    --   required by `g@`. It is used to enable dot-repeatability.
    return '<Cmd>echon ""<CR>g@' .. (ask_for_textobject and '' or ' ')
  end
end

-- Work with surrounding info -------------------------------------------------
H.get_surround_spec = function(sur_type, use_cache)
  local res

  -- Try using cache
  if use_cache then
    res = H.cache[sur_type]
    if res ~= nil then return res end
  else
    H.cache = {}
  end

  -- Prompt user to enter identifier of surrounding
  local char = H.user_surround_id(sur_type)
  if char == nil then return nil end

  -- Get surround specification
  res = H.make_surrounding_table()[char][sur_type]

  -- Allow function returning spec or surrounding region(s)
  if vim.is_callable(res) then res = res() end

  -- Do nothing if supplied not appropriate structure
  if not H.is_surrounding_info(res, sur_type) then return nil end

  -- Wrap callable tables to be an actual functions. Otherwise they might be
  -- confused with list of patterns.
  if H.is_composed_pattern(res) then res = vim.tbl_map(H.wrap_callable_table, res) end

  -- Track identifier for possible messages. Use metatable to pass
  -- `vim.tbl_islist()` check.
  res = setmetatable(res, { __index = { id = char } })

  -- Cache result
  if use_cache then H.cache[sur_type] = res end

  return res
end

H.make_surrounding_table = function()
  -- Extend builtins with data from `config`
  local surroundings = vim.tbl_deep_extend('force', H.builtin_surroundings, H.get_config().custom_surroundings or {})

  -- Add possibly missing information from default surrounding info
  for char, info in pairs(surroundings) do
    local default = H.get_default_surrounding_info(char)
    surroundings[char] = vim.tbl_deep_extend('force', default, info)
  end

  -- Use default surrounding info for not supplied single character identifier
  --stylua: ignore start
  return setmetatable(surroundings, {
    __index = function(_, key) return H.get_default_surrounding_info(key) end,
  })
  --stylua: ignore end
end

H.get_default_surrounding_info = function(char)
  local char_esc = vim.pesc(char)
  return { input = { char_esc .. '().-()' .. char_esc }, output = { left = char, right = char } }
end

H.is_surrounding_info = function(x, sur_type)
  if sur_type == 'input' then
    return H.is_composed_pattern(x) or H.is_region_pair(x) or H.is_region_pair_array(x)
  elseif sur_type == 'output' then
    return (type(x) == 'table' and type(x.left) == 'string' and type(x.right) == 'string')
  end
end

H.is_region = function(x)
  if type(x) ~= 'table' then return false end
  local from_is_valid = type(x.from) == 'table' and type(x.from.line) == 'number' and type(x.from.col) == 'number'
  -- Allow `to` to be `nil` to describe empty regions
  local to_is_valid = true
  if x.to ~= nil then
    to_is_valid = type(x.to) == 'table' and type(x.to.line) == 'number' and type(x.to.col) == 'number'
  end
  return from_is_valid and to_is_valid
end

H.is_region_pair = function(x)
  if type(x) ~= 'table' then return false end
  return H.is_region(x.left) and H.is_region(x.right)
end

H.is_region_pair_array = function(x)
  if not vim.tbl_islist(x) then return false end
  for _, v in ipairs(x) do
    if not H.is_region_pair(v) then return false end
  end
  return true
end

H.is_composed_pattern = function(x)
  if not (vim.tbl_islist(x) and #x > 0) then return false end
  for _, val in ipairs(x) do
    local val_type = type(val)
    if not (val_type == 'table' or val_type == 'string' or vim.is_callable(val)) then return false end
  end
  return true
end

-- Work with finding surrounding ----------------------------------------------
---@param surr_spec table Composed pattern. Last item(s) - extraction template.
---@param opts table Options.
---@private
H.find_surrounding = function(surr_spec, opts)
  if surr_spec == nil then return end
  if H.is_region_pair(surr_spec) then return surr_spec end

  opts = vim.tbl_deep_extend('force', H.get_default_opts(), opts or {})
  H.validate_search_method(opts.search_method, 'search_method')

  local region_pair = H.find_surrounding_region_pair(surr_spec, opts)
  if region_pair == nil then
    local msg = ([[No surrounding '%s%s' found within %d line%s and `config.search_method = '%s'`.]]):format(
      opts.n_times > 1 and opts.n_times or '',
      surr_spec.id,
      opts.n_lines,
      opts.n_lines > 1 and 's' or '',
      opts.search_method
    )
    H.message(msg)
  end

  return region_pair
end

H.find_surrounding_region_pair = function(surr_spec, opts)
  local reference_region, n_times, n_lines = opts.reference_region, opts.n_times, opts.n_lines

  if n_times == 0 then return end

  -- Find `n_times` matching spans evolving from reference region span
  -- First try to find inside 0-neighborhood
  local neigh = H.get_neighborhood(reference_region, 0)
  local reference_span = neigh.region_to_span(reference_region)

  local find_next = function(cur_reference_span)
    local res = H.find_best_match(neigh, surr_spec, cur_reference_span, opts)

    -- If didn't find in 0-neighborhood, possibly try extend one
    if res.span == nil then
      -- Stop if no need to extend neighborhood
      if n_lines == 0 or neigh.n_neighbors > 0 then return {} end

      -- Update data with respect to new neighborhood
      local cur_reference_region = neigh.span_to_region(cur_reference_span)
      neigh = H.get_neighborhood(reference_region, n_lines)
      reference_span = neigh.region_to_span(reference_region)
      cur_reference_span = neigh.region_to_span(cur_reference_region)

      -- Recompute based on new neighborhood
      res = H.find_best_match(neigh, surr_spec, cur_reference_span, opts)
    end

    return res
  end

  local find_res = { span = reference_span }
  for _ = 1, n_times do
    find_res = find_next(find_res.span)
    if find_res.span == nil then return end
  end

  -- Extract final span
  local extract = function(span, extract_pattern)
    -- Use table extract pattern to allow array of regions as surrounding spec
    -- Pair of spans is constructed based on best region pair
    if type(extract_pattern) == 'table' then return extract_pattern end

    -- First extract local (with respect to best matched span) surrounding spans
    local s = neigh['1d']:sub(span.from, span.to - 1)
    local local_surr_spans = H.extract_surr_spans(s, extract_pattern)

    -- Convert local spans to global
    local off = span.from - 1
    local left, right = local_surr_spans.left, local_surr_spans.right
    return {
      left = { from = left.from + off, to = left.to + off },
      right = { from = right.from + off, to = right.to + off },
    }
  end

  local final_spans = extract(find_res.span, find_res.extract_pattern)
  local outer_span = { from = final_spans.left.from, to = final_spans.right.to }

  -- Ensure that output region is different from reference.
  if H.is_span_covering(reference_span, outer_span) then
    find_res = find_next(find_res.span)
    if find_res.span == nil then return end
    final_spans = extract(find_res.span, find_res.extract_pattern)
    outer_span = { from = final_spans.left.from, to = final_spans.right.to }
    if H.is_span_covering(reference_span, outer_span) then return end
  end

  -- Convert to region pair
  return { left = neigh.span_to_region(final_spans.left), right = neigh.span_to_region(final_spans.right) }
end

H.get_default_opts = function()
  local config = H.get_config()
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  return {
    n_lines = config.n_lines,
    n_times = H.cache.count or vim.v.count1,
    -- Empty region at cursor position
    reference_region = { from = { line = cur_pos[1], col = cur_pos[2] + 1 } },
    search_method = H.cache.search_method or config.search_method,
  }
end

-- Work with treesitter surrounding -------------------------------------------
H.prepare_captures = function(captures)
  local is_capture = function(x) return type(x) == 'string' and x:sub(1, 1) == '@' end

  if not (type(captures) == 'table' and is_capture(captures.outer) and is_capture(captures.inner)) then
    H.error('Wrong format for `captures`. See `MiniSurround.gen_spec.input.treesitter()` for details.')
  end

  return { outer = captures.outer, inner = captures.inner }
end

H.get_matched_node_pairs_plugin = function(captures)
  local ts_queries = require('nvim-treesitter.query')
  local ts_parsers = require('nvim-treesitter.parsers')

  -- This is a modified version of `ts_queries.get_capture_matches_recursively`
  -- source code which keeps track of match language
  local matches = {}
  local parser = ts_parsers.get_parser(0)
  if parser then
    parser:for_each_tree(function(tree, lang_tree)
      local lang = lang_tree:lang()
      local lang_matches = ts_queries.get_capture_matches(0, captures.outer, 'textobjects', tree:root(), lang)
      for _, m in pairs(lang_matches) do
        m.lang = lang
      end
      vim.list_extend(matches, lang_matches)
    end)
  end

  return vim.tbl_map(
    function(match)
      local node_outer = match.node
      -- Pick inner node as the biggest node matching inner query. This is
      -- needed because query output is not quaranteed to come in order.
      local matches_inner = ts_queries.get_capture_matches(0, captures.inner, 'textobjects', node_outer, match.lang)
      local nodes_inner = vim.tbl_map(function(x) return x.node end, matches_inner)
      return { outer = node_outer, inner = H.get_biggest_node(nodes_inner) }
    end,
    -- This call should handle multiple languages in buffer
    matches
  )
end

H.get_matched_node_pairs_builtin = function(captures)
  -- Fetch treesitter data for buffer
  local lang = vim.bo.filetype
  local ok, parser = pcall(vim.treesitter.get_parser, 0, lang)
  if not ok then H.error_treesitter('parser', lang) end

  local get_query = vim.fn.has('nvim-0.9') == 1 and vim.treesitter.query.get or vim.treesitter.get_query
  local query = get_query(lang, 'textobjects')
  if query == nil then H.error_treesitter('query', lang) end

  -- Remove leading '@'
  local capture_outer, capture_inner = captures.outer:sub(2), captures.inner:sub(2)

  -- Compute nodes matching outer capture
  local nodes_outer = {}
  for _, tree in ipairs(parser:trees()) do
    vim.list_extend(nodes_outer, H.get_builtin_matched_nodes(capture_outer, tree:root(), query))
  end

  -- Make node pairs with biggest node matching inner capture inside outer node
  return vim.tbl_map(function(node_outer)
    local nodes_inner = H.get_builtin_matched_nodes(capture_inner, node_outer, query)
    return { outer = node_outer, inner = H.get_biggest_node(nodes_inner) }
  end, nodes_outer)
end

H.get_builtin_matched_nodes = function(capture, root, query)
  local res = {}
  for capture_id, node, _ in query:iter_captures(root, 0) do
    if query.captures[capture_id] == capture then table.insert(res, node) end
  end
  return res
end

H.get_biggest_node = function(node_arr)
  local best_node, best_byte_count = nil, -math.huge
  for _, node in ipairs(node_arr) do
    local _, _, start_byte = node:start()
    local _, _, end_byte = node:end_()
    local byte_count = end_byte - start_byte + 1
    if best_byte_count < byte_count then
      best_node, best_byte_count = node, byte_count
    end
  end

  return best_node
end

H.error_treesitter = function(failed_get, lang)
  local bufnr = vim.api.nvim_get_current_buf()
  local msg = string.format([[Can not get %s for buffer %d and language '%s'.]], failed_get, bufnr, lang)
  H.error(msg)
end

-- Work with matching spans ---------------------------------------------------
---@param neighborhood table Output of `get_neighborhood()`.
---@param surr_spec table
---@param reference_span table Span to cover.
---@param opts table Fields: <search_method>.
---@private
H.find_best_match = function(neighborhood, surr_spec, reference_span, opts)
  local best_span, best_nested_pattern, current_nested_pattern
  local f = function(span)
    if H.is_better_span(span, best_span, reference_span, opts) then
      best_span = span
      best_nested_pattern = current_nested_pattern
    end
  end

  if H.is_region_pair_array(surr_spec) then
    -- Iterate over all spans representing outer regions in array
    for _, region_pair in ipairs(surr_spec) do
      -- Construct outer region used to find best region pair
      local outer_region = { from = region_pair.left.from, to = region_pair.right.to or region_pair.right.from }

      -- Consider outer region only if it is completely within neighborhood
      if neighborhood.is_region_inside(outer_region) then
        -- Make future extract pattern based directly on region pair
        current_nested_pattern = {
          {
            left = neighborhood.region_to_span(region_pair.left),
            right = neighborhood.region_to_span(region_pair.right),
          },
        }

        f(neighborhood.region_to_span(outer_region))
      end
    end
  else
    -- Iterate over all matched spans
    for _, nested_pattern in ipairs(H.cartesian_product(surr_spec)) do
      current_nested_pattern = nested_pattern
      H.iterate_matched_spans(neighborhood['1d'], nested_pattern, f)
    end
  end

  local extract_pattern
  if best_nested_pattern ~= nil then extract_pattern = best_nested_pattern[#best_nested_pattern] end
  return { span = best_span, extract_pattern = extract_pattern }
end

H.iterate_matched_spans = function(line, nested_pattern, f)
  local max_level = #nested_pattern
  -- Keep track of visited spans to ensure only one call of `f`.
  -- Example: `((a) (b))`, `{'%b()', '%b()'}`
  local visited = {}

  local process
  process = function(level, level_line, level_offset)
    local pattern = nested_pattern[level]
    local next_span = function(s, init) return H.string_find(s, pattern, init) end
    if vim.is_callable(pattern) then next_span = pattern end

    local is_same_balanced = type(pattern) == 'string' and pattern:match('^%%b(.)%1$') ~= nil
    local init = 1
    while init <= level_line:len() do
      local from, to = next_span(level_line, init)
      if from == nil then break end

      if level == max_level then
        local found_match = H.new_span(from + level_offset, to + level_offset)
        local found_match_id = string.format('%s_%s', found_match.from, found_match.to)
        if not visited[found_match_id] then
          f(found_match)
          visited[found_match_id] = true
        end
      else
        local next_level_line = level_line:sub(from, to)
        local next_level_offset = level_offset + from - 1
        process(level + 1, next_level_line, next_level_offset)
      end

      -- Start searching from right end to implement "balanced" pair.
      -- This doesn't work with regular balanced pattern because it doesn't
      -- capture nested brackets.
      init = (is_same_balanced and to or from) + 1
    end
  end

  process(1, line, 0)
end

-- NOTE: spans are end-exclusive to allow empty spans via `from == to`
H.new_span = function(from, to) return { from = from, to = to == nil and from or (to + 1) } end

---@param candidate table Candidate span to test against `current`.
---@param current table|nil Current best span.
---@param reference table Reference span to cover.
---@param opts table Fields: <search_method>.
---@private
H.is_better_span = function(candidate, current, reference, opts)
  -- Candidate should be never equal or nested inside reference
  if H.is_span_covering(reference, candidate) or H.is_span_equal(candidate, reference) then return false end

  return H.span_compare_methods[opts.search_method](candidate, current, reference)
end

H.span_compare_methods = {
  cover = function(candidate, current, reference)
    local res = H.is_better_covering_span(candidate, current, reference)
    if res ~= nil then return res end
    -- If both are not covering, `candidate` is not better (as it must cover)
    return false
  end,

  cover_or_next = function(candidate, current, reference)
    local res = H.is_better_covering_span(candidate, current, reference)
    if res ~= nil then return res end

    -- If not covering, `candidate` must be "next" and closer to reference
    if not H.is_span_on_left(reference, candidate) then return false end
    if current == nil then return true end

    local dist = H.span_distance.next
    return dist(candidate, reference) < dist(current, reference)
  end,

  cover_or_prev = function(candidate, current, reference)
    local res = H.is_better_covering_span(candidate, current, reference)
    if res ~= nil then return res end

    -- If not covering, `candidate` must be "previous" and closer to reference
    if not H.is_span_on_left(candidate, reference) then return false end
    if current == nil then return true end

    local dist = H.span_distance.prev
    return dist(candidate, reference) < dist(current, reference)
  end,

  cover_or_nearest = function(candidate, current, reference)
    local res = H.is_better_covering_span(candidate, current, reference)
    if res ~= nil then return res end

    -- If not covering, `candidate` must be closer to reference
    if current == nil then return true end

    local dist = H.span_distance.near
    return dist(candidate, reference) < dist(current, reference)
  end,

  next = function(candidate, current, reference)
    if H.is_span_covering(candidate, reference) then return false end

    -- `candidate` must be "next" and closer to reference
    if not H.is_span_on_left(reference, candidate) then return false end
    if current == nil then return true end

    local dist = H.span_distance.next
    return dist(candidate, reference) < dist(current, reference)
  end,

  prev = function(candidate, current, reference)
    if H.is_span_covering(candidate, reference) then return false end

    -- `candidate` must be "previous" and closer to reference
    if not H.is_span_on_left(candidate, reference) then return false end
    if current == nil then return true end

    local dist = H.span_distance.prev
    return dist(candidate, reference) < dist(current, reference)
  end,

  nearest = function(candidate, current, reference)
    if H.is_span_covering(candidate, reference) then return false end

    -- `candidate` must be closer to reference
    if current == nil then return true end

    local dist = H.span_distance.near
    return dist(candidate, reference) < dist(current, reference)
  end,
}

H.span_distance = {
  -- Other possible choices of distance between [a1, a2] and [b1, b2]:
  -- - Hausdorff distance: max(|a1 - b1|, |a2 - b2|).
  --   Source:
  --   https://math.stackexchange.com/questions/41269/distance-between-two-ranges
  -- - Minimum distance: min(|a1 - b1|, |a2 - b2|).

  -- Distance is chosen so that "next span" in certain direction is the closest
  next = function(span_1, span_2) return math.abs(span_1.from - span_2.from) end,
  prev = function(span_1, span_2) return math.abs(span_1.to - span_2.to) end,
  near = function(span_1, span_2) return math.min(math.abs(span_1.from - span_2.from), math.abs(span_1.to - span_2.to)) end,
}

H.is_better_covering_span = function(candidate, current, reference)
  local candidate_is_covering = H.is_span_covering(candidate, reference)
  local current_is_covering = H.is_span_covering(current, reference)

  if candidate_is_covering and current_is_covering then
    -- Covering candidate is better than covering current if it is narrower
    return (candidate.to - candidate.from) < (current.to - current.from)
  end
  if candidate_is_covering and not current_is_covering then return true end
  if not candidate_is_covering and current_is_covering then return false end

  -- Return `nil` if neither span is covering
  return nil
end

--stylua: ignore
H.is_span_covering = function(span, span_to_cover)
  if span == nil or span_to_cover == nil then return false end
  if span.from == span.to then
    return (span.from == span_to_cover.from) and (span_to_cover.to == span.to)
  end
  if span_to_cover.from == span_to_cover.to then
    return (span.from <= span_to_cover.from) and (span_to_cover.to < span.to)
  end

  return (span.from <= span_to_cover.from) and (span_to_cover.to <= span.to)
end

H.is_span_equal = function(span_1, span_2)
  if span_1 == nil or span_2 == nil then return false end
  return (span_1.from == span_2.from) and (span_1.to == span_2.to)
end

H.is_span_on_left = function(span_1, span_2)
  if span_1 == nil or span_2 == nil then return false end
  return (span_1.from <= span_2.from) and (span_1.to <= span_2.to)
end

H.is_point_inside_spans = function(point, spans)
  for _, span in ipairs(spans) do
    if span[1] <= point and point <= span[2] then return true end
  end
  return false
end

-- Work with operator marks ---------------------------------------------------
H.get_marks_pos = function(mode)
  -- Region is inclusive on both ends
  local mark1, mark2
  if mode == 'visual' then
    mark1, mark2 = '<', '>'
  else
    mark1, mark2 = '[', ']'
  end

  local pos1 = vim.api.nvim_buf_get_mark(0, mark1)
  local pos2 = vim.api.nvim_buf_get_mark(0, mark2)

  local selection_type = H.get_selection_type(mode)

  -- Tweak position in linewise mode as marks are placed on the first column
  if selection_type == 'linewise' then
    -- Move start mark past the indent
    local _, line1_indent = vim.fn.getline(pos1[1]):find('^%s*')
    pos1[2] = line1_indent

    -- Move end mark to the last character (` - 2` here because `col()` returns
    -- column right after the last 1-based column)
    pos2[2] = vim.fn.col({ pos2[1], '$' }) - 2
  end

  -- Make columns 1-based instead of 0-based. This is needed because
  -- `nvim_buf_get_mark()` returns the first 0-based byte of mark symbol and
  -- all the following operations are done with Lua's 1-based indexing.
  pos1[2], pos2[2] = pos1[2] + 1, pos2[2] + 1

  -- Tweak second position to respect multibyte characters. Reasoning:
  -- - These positions will be used with `region_replace()` to add some text,
  --   which operates on byte columns.
  -- - For the first mark we want the first byte of symbol, then text will be
  --   insert to the left of the mark.
  -- - For the second mark we want last byte of symbol. To add surrounding to
  --   the right, use `pos2[2] + 1`.
  if mode == 'visual' and vim.o.selection == 'exclusive' then
    -- Respect 'selection' option
    pos2[2] = pos2[2] - 1
  else
    local line2 = vim.fn.getline(pos2[1])
    -- Use `math.min()` because it might lead to 'index out of range' error
    -- when mark is positioned at the end of line (that extra space which is
    -- selected when selecting with `v$`)
    local utf_index = vim.str_utfindex(line2, math.min(#line2, pos2[2]))
    -- This returns the last byte inside character because `vim.str_byteindex()`
    -- 'rounds upwards to the end of that sequence'.
    pos2[2] = vim.str_byteindex(line2, utf_index)
  end

  return {
    first = { line = pos1[1], col = pos1[2] },
    second = { line = pos2[1], col = pos2[2] },
    selection_type = selection_type,
  }
end

H.get_selection_type = function(mode)
  if (mode == 'char') or (mode == 'visual' and vim.fn.visualmode() == 'v') then return 'charwise' end
  if (mode == 'line') or (mode == 'visual' and vim.fn.visualmode() == 'V') then return 'linewise' end
  if (mode == 'block') or (mode == 'visual' and vim.fn.visualmode() == '\22') then return 'blockwise' end
end

-- Work with cursor -----------------------------------------------------------
H.set_cursor = function(line, col) vim.api.nvim_win_set_cursor(0, { line, col - 1 }) end

H.set_cursor_nonblank = function(line)
  H.set_cursor(line, 1)
  vim.cmd('normal! ^')
end

H.compare_pos = function(pos1, pos2)
  if pos1.line < pos2.line then return '<' end
  if pos1.line > pos2.line then return '>' end
  if pos1.col < pos2.col then return '<' end
  if pos1.col > pos2.col then return '>' end
  return '='
end

H.cursor_cycle = function(pos_array, dir)
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  cur_pos = { line = cur_pos[1], col = cur_pos[2] + 1 }

  local compare, to_left, to_right, res_pos
  -- NOTE: `pos_array` should be an increasingly ordered array of positions
  for _, pos in pairs(pos_array) do
    compare = H.compare_pos(cur_pos, pos)
    -- Take position when moving to left if cursor is strictly on right.
    -- This will lead to updating `res_pos` until the rightmost such position.
    to_left = compare == '>' and dir == 'left'
    -- Take position when moving to right if cursor is strictly on left.
    -- This will update result only once leading to the leftmost such position.
    to_right = res_pos == nil and compare == '<' and dir == 'right'
    if to_left or to_right then res_pos = pos end
  end

  res_pos = res_pos or (dir == 'right' and pos_array[1] or pos_array[#pos_array])
  H.set_cursor(res_pos.line, res_pos.col)
end

-- Work with user input -------------------------------------------------------
H.user_surround_id = function(sur_type)
  -- Get from user single character surrounding identifier
  local needs_help_msg = true
  vim.defer_fn(function()
    if not needs_help_msg then return end

    local msg = string.format('Enter %s surrounding identifier (single character) ', sur_type)
    H.echo(msg)
    H.cache.msg_shown = true
  end, 1000)
  local ok, char = pcall(vim.fn.getcharstr)
  needs_help_msg = false
  H.unecho()

  -- Terminate if couldn't get input (like with <C-c>) or it is `<Esc>`
  if not ok or char == '\27' then return nil end

  if char:find('^[%w%p%s]$') == nil then
    H.message('Input must be single character: alphanumeric, punctuation, or space.')
    return nil
  end

  return char
end

-- Work with positions --------------------------------------------------------
H.pos_to_left = function(pos)
  if pos.line == 1 and pos.col == 1 then return { line = pos.line, col = pos.col } end
  if pos.col == 1 then return { line = pos.line - 1, col = H.get_line_cols(pos.line - 1) } end
  return { line = pos.line, col = pos.col - 1 }
end

H.pos_to_right = function(pos)
  local n_cols = H.get_line_cols(pos.line)
  -- Using `>` and not `>=` helps with removing '\n' and in the last line
  if pos.line == vim.api.nvim_buf_line_count(0) and pos.col > n_cols then return { line = pos.line, col = n_cols } end
  if pos.col > n_cols then return { line = pos.line + 1, col = 1 } end
  return { line = pos.line, col = pos.col + 1 }
end

-- Work with regions ----------------------------------------------------------
H.region_replace = function(region, text)
  -- Compute start and end position for `vim.api.nvim_buf_set_text()`.
  -- Indexing is zero-based. Rows - end-inclusive, columns - end-exclusive.
  local start_row, start_col = region.from.line - 1, region.from.col - 1

  local end_row, end_col
  -- Allow empty region
  if H.region_is_empty(region) then
    end_row, end_col = start_row, start_col
  else
    end_row, end_col = region.to.line - 1, region.to.col

    -- Possibly correct to allow removing new line character
    if end_row < vim.api.nvim_buf_line_count(0) and H.get_line_cols(end_row + 1) < end_col then
      end_row, end_col = end_row + 1, 0
    end
  end

  -- Allow single string as replacement
  if type(text) == 'string' then text = { text } end

  -- Allow `\n` in string to denote new lines
  if #text > 0 then text = vim.split(table.concat(text, '\n'), '\n') end

  -- Replace. Use `pcall()` to do nothing if some position is out of bounds.
  pcall(vim.api.nvim_buf_set_text, 0, start_row, start_col, end_row, end_col, text)
end

H.surr_to_pos_array = function(surr)
  local res = {}

  local append_position = function(pos, correction_direction)
    if pos == nil then return end
    -- Don't go past the line if it is not empty
    if H.get_line_cols(pos.line) < pos.col and pos.col > 1 then
      pos = correction_direction == 'left' and H.pos_to_left(pos) or H.pos_to_right(pos)
    end

    -- Don't add duplicate. Assumes that positions are used increasingly.
    local line, col = pos.line, pos.col
    local last = res[#res]
    if not (last ~= nil and last.line == line and last.col == col) then
      table.insert(res, { line = line, col = col })
    end
  end

  -- Possibly correct position towards inside of surrounding region
  -- Also don't add positions from empty regions
  if not H.region_is_empty(surr.left) then
    append_position(surr.left.from, 'right')
    append_position(surr.left.to, 'right')
  end
  if not H.region_is_empty(surr.right) then
    append_position(surr.right.from, 'left')
    append_position(surr.right.to, 'left')
  end

  return res
end

H.region_highlight = function(buf_id, region)
  -- Don't highlight empty region
  if H.region_is_empty(region) then return end
  local ns_id = H.ns_id.highlight

  -- Indexing is zero-based. Rows - end-inclusive, columns - end-exclusive.
  local from_line, from_col, to_line, to_col =
    region.from.line - 1, region.from.col - 1, region.to.line - 1, region.to.col
  vim.highlight.range(buf_id, ns_id, 'MiniSurround', { from_line, from_col }, { to_line, to_col })
end

H.region_unhighlight = function(buf_id, region)
  local ns_id = H.ns_id.highlight

  -- Remove highlights from whole lines as it is the best available granularity
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, region.from.line - 1, (region.to or region.from).line)
end

H.region_is_empty = function(region) return region.to == nil end

-- Work with text -------------------------------------------------------------
H.get_range_indent = function(from_line, to_line)
  local n_indent, indent = math.huge, nil

  local lines = vim.api.nvim_buf_get_lines(0, from_line - 1, to_line, true)
  local n_indent_cur, indent_cur
  for _, l in ipairs(lines) do
    _, n_indent_cur, indent_cur = l:find('^(%s*)')

    -- Don't indent blank lines
    if n_indent_cur < n_indent and n_indent_cur < l:len() then
      n_indent, indent = n_indent_cur, indent_cur
    end
  end

  return indent or ''
end

H.shift_indent = function(command, from_line, to_line)
  if to_line < from_line then return end
  vim.cmd('silent ' .. from_line .. ',' .. to_line .. command)
end

H.is_line_blank = function(line_num) return vim.fn.nextnonblank(line_num) ~= line_num end

-- Work with Lua patterns -----------------------------------------------------
H.extract_surr_spans = function(s, extract_pattern)
  local positions = { s:match(extract_pattern) }

  local is_all_numbers = true
  for _, pos in ipairs(positions) do
    if type(pos) ~= 'number' then is_all_numbers = false end
  end

  local is_valid_positions = is_all_numbers and (#positions == 2 or #positions == 4)
  if not is_valid_positions then
    local msg = 'Could not extract proper positions (two or four empty captures) from '
      .. string.format([[string '%s' with extraction pattern '%s'.]], s, extract_pattern)
    H.error(msg)
  end

  if #positions == 2 then
    return { left = H.new_span(1, positions[1] - 1), right = H.new_span(positions[2], s:len()) }
  end
  return { left = H.new_span(positions[1], positions[2] - 1), right = H.new_span(positions[3], positions[4] - 1) }
end

-- Work with cursor neighborhood ----------------------------------------------
---@param reference_region table Reference region.
---@param n_neighbors number Maximum number of neighbors to include before
---   start line and after end line.
---@private
H.get_neighborhood = function(reference_region, n_neighbors)
  -- Compute '2d neighborhood' of (possibly empty) region
  local from_line, to_line = reference_region.from.line, (reference_region.to or reference_region.from).line
  local line_start = math.max(1, from_line - n_neighbors)
  local line_end = math.min(vim.api.nvim_buf_line_count(0), to_line + n_neighbors)
  local neigh2d = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)
  -- Append 'newline' character to distinguish between lines in 1d case
  for k, v in pairs(neigh2d) do
    neigh2d[k] = v .. '\n'
  end

  -- '1d neighborhood': position is determined by offset from start
  local neigh1d = table.concat(neigh2d, '')

  -- Convert 2d buffer position to 1d offset
  local pos_to_offset = function(pos)
    if pos == nil then return nil end
    local line_num = line_start
    local offset = 0
    while line_num < pos.line do
      offset = offset + neigh2d[line_num - line_start + 1]:len()
      line_num = line_num + 1
    end

    return offset + pos.col
  end

  -- Convert 1d offset to 2d buffer position
  local offset_to_pos = function(offset)
    if offset == nil then return nil end
    local line_num = 1
    local line_offset = 0
    while line_num <= #neigh2d and line_offset + neigh2d[line_num]:len() < offset do
      line_offset = line_offset + neigh2d[line_num]:len()
      line_num = line_num + 1
    end

    return { line = line_start + line_num - 1, col = offset - line_offset }
  end

  -- Convert 2d region to 1d span
  local region_to_span = function(region)
    if region == nil then return nil end
    local is_empty = region.to == nil
    local to = region.to or region.from
    return { from = pos_to_offset(region.from), to = pos_to_offset(to) + (is_empty and 0 or 1) }
  end

  -- Convert 1d span to 2d region
  local span_to_region = function(span)
    if span == nil then return nil end
    -- NOTE: this might lead to outside of line positions due to added `\n` at
    -- the end of lines in 1d-neighborhood.
    local res = { from = offset_to_pos(span.from) }

    -- Convert empty span to empty region
    if span.from < span.to then res.to = offset_to_pos(span.to - 1) end
    return res
  end

  local is_region_inside = function(region)
    local res = line_start <= region.from.line
    if region.to ~= nil then res = res and (region.to.line <= line_end) end
    return res
  end

  return {
    n_neighbors = n_neighbors,
    region = reference_region,
    ['1d'] = neigh1d,
    ['2d'] = neigh2d,
    pos_to_offset = pos_to_offset,
    offset_to_pos = offset_to_pos,
    region_to_span = region_to_span,
    span_to_region = span_to_region,
    is_region_inside = is_region_inside,
  }
end

-- Utilities ------------------------------------------------------------------
H.echo = function(msg, is_important)
  if H.get_config().silent then return end

  -- Construct message chunks
  msg = type(msg) == 'string' and { { msg } } or msg
  table.insert(msg, 1, { '(mini.surround) ', 'WarningMsg' })

  -- Avoid hit-enter-prompt
  local max_width = vim.o.columns * math.max(vim.o.cmdheight - 1, 0) + vim.v.echospace
  local chunks, tot_width = {}, 0
  for _, ch in ipairs(msg) do
    local new_ch = { vim.fn.strcharpart(ch[1], 0, max_width - tot_width), ch[2] }
    table.insert(chunks, new_ch)
    tot_width = tot_width + vim.fn.strdisplaywidth(new_ch[1])
    if tot_width >= max_width then break end
  end

  -- Echo. Force redraw to ensure that it is effective (`:h echo-redraw`)
  vim.cmd([[echo '' | redraw]])
  vim.api.nvim_echo(chunks, is_important, {})
end

H.unecho = function()
  if H.cache.msg_shown then vim.cmd([[echo '' | redraw]]) end
end

H.message = function(msg) H.echo(msg, true) end

H.error = function(msg) error(string.format('(mini.surround) %s', msg)) end

H.map = function(mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

H.get_line_cols = function(line_num) return vim.fn.getline(line_num):len() end

H.string_find = function(s, pattern, init)
  init = init or 1

  -- Match only start of full string if pattern says so.
  -- This is needed because `string.find()` doesn't do this.
  -- Example: `string.find('(aaa)', '^.*$', 4)` returns `4, 5`
  if pattern:sub(1, 1) == '^' then
    if init > 1 then return nil end
    return string.find(s, pattern)
  end

  -- Handle patterns `x.-y` differently: make match as small as possible. This
  -- doesn't allow `x` be present inside `.-` match, just as with `yyy`. Which
  -- also leads to a behavior similar to punctuation id (like with `va_`): no
  -- covering is possible, only next, previous, or nearest.
  local check_left, _, prev = string.find(pattern, '(.)%.%-')
  local is_pattern_special = check_left ~= nil and prev ~= '%'
  if not is_pattern_special then return string.find(s, pattern, init) end

  -- Make match as small as possible
  local from, to = string.find(s, pattern, init)
  if from == nil then return end

  local cur_from, cur_to = from, to
  while cur_to == to do
    from, to = cur_from, cur_to
    cur_from, cur_to = string.find(s, pattern, cur_from + 1)
  end

  return from, to
end

---@param arr table List of items. If item is list, consider as set for
---   product. Else - make it single item list.
---@private
H.cartesian_product = function(arr)
  if not (type(arr) == 'table' and #arr > 0) then return {} end
  arr = vim.tbl_map(function(x) return vim.tbl_islist(x) and x or { x } end, arr)

  local res, cur_item = {}, {}
  local process
  process = function(level)
    for i = 1, #arr[level] do
      table.insert(cur_item, arr[level][i])
      if level == #arr then
        -- Flatten array to allow tables as elements of step tables
        table.insert(res, vim.tbl_flatten(cur_item))
      else
        process(level + 1)
      end
      table.remove(cur_item, #cur_item)
    end
  end

  process(1)
  return res
end

H.wrap_callable_table = function(x)
  if vim.is_callable(x) and type(x) == 'table' then return function(...) return x(...) end end
  return x
end

return MiniSurround
