-- MIT License Copyright (c) 2021 Evgeni Chasnovski

---@brief [[
--- Lua module for minimal, fast, and flexible start screen. Displayed items
--- are fully customizable both in terms of what they do and how they look
--- (with reasonable defaults). Item selection can be done using prefix query
--- with instant visual feedback.This is mostly inspired by
--- [mhinz/vim-startify](https://github.com/mhinz/vim-startify).
---
--- Key design ideas:
--- - All available actions are defined inside items. Each item should have the
---   following info:
---     - `action` - function or string for |vim.cmd| which is executed when
---       item is chosen. Empty string result in placeholder "inactive" item.
---     - `name` - string which will be displayed and used for choosing.
---     - `section` - string representing to which section item belongs.
---   There are pre-configured whole sections in |MiniStarter.sections|.
--- - Configure what items are displayed by supplying an array which can be
---   normalized to an array of items. Read about how supplied items are
---   normalized in |MiniStarter.refresh|.
--- - Modify the final look by supplying content hooks: functions which take
---   buffer content as input (see |MiniStarter.content| for more information)
---   and return buffer content as output. There are pre-configured content
---   hook generators in |MiniStarter.gen_hook|.
--- - Choosing an item can be done in two ways:
---     - Type prefix query to filter item by matching its name (ignoring
---       case). Displayed information is updated after every typed character.
---       For every item its unique prefix is highlighted.
---     - Use Up/Down arrows and hit Enter.
---
--- What is doesn't do:
--- - It doesn't support fuzzy query for items. And probably will never do.
---
--- # Setup
---
--- This module needs a setup with `require('mini.starter').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniStarter` which you can use for scripting or manually (with
--- `:lua MiniStarter.*`).
---
--- Default `config`:
--- <code>
---   {
---     -- Whether to open starter buffer on VimEnter. Not opened if Neovim was
---     -- started with intent to show something else.
---     autoopen = true,
---
---     -- Whether to evaluate action of single active item
---     evaluate_single = false,
---
---     -- Items to be displayed. Should be an array with the following elements:
---     -- - Item: table with `action`, `name`, and `section` keys.
---     -- - Function: should return one of these three categories.
---     -- - Array: elements of these three types (i.e. item, array, function).
---     -- If `nil`, default items will be used (see |mini.starter|).
---     items = nil,
---
---     -- Header to be displayed before items. Should be a string or function
---     -- evaluating to single string (use `\n` for new lines). If `nil` (default),
---     -- polite greeting will be used.
---     header = nil,
---
---     -- Footer to be displayed after items. Should be a string or function
---     -- evaluating to string. If `nil`, default usage instructions will be used.
---     footer = nil,
---
---     -- Array  of functions to be applied consecutively to initial content. Each
---     -- function should take and return content for "Starter" buffer (see
---     -- |mini.starter| for more details).
---     content_hooks = nil,
---
---     -- Characters to update query. Each character will have special buffer
---     -- mapping overriding your global ones. Be careful to not add `:` as it
---     -- allows you to go into command mode.
---     query_updaters = [[abcdefghijklmnopqrstuvwxyz0123456789_-.]],
---   }
--- </code>
--- # Lifecycle of Starter buffer
---
--- - Open with |MiniStarter.open()|. It includes creating buffer with
---   appropriate options, mappings, behavior; call to |MiniStarter.refresh()|;
---   issue `MiniStarterOpened` |User| event.
--- - Wait for user to choose an item. This is done using following logic:
---     - Typing any character from `MiniStarter.config.query_updaters` leads
---       to updating query. Read more in |MiniStarter.add_to_query|.
---     - <BS> deletes latest character from query.
---     - <Down>/<Up> and <M-j>/<M-k> move current item.
---     - <CR> executes action of current item.
---     - <C-c> closes Starter buffer.
--- - Evaluate current item when appropriate (after `<CR>` or when there is a
---   single item and `MiniStarter.config.evaluate_single` is `true`). This
---   executes item's `action`.
---
--- # Example configurations
---
--- Configuration similar to 'mhinz/vim-startify':
--- <code>
---   local starter = require('mini.starter')
---   starter.setup({
---     evaluate_single = true,
---     items = {
---       starter.sections.builtin_actions(),
---       starter.sections.recent_files(10, false),
---       starter.sections.recent_files(10, true),
---       -- Use this if you set up 'mini.sessions'
---       starter.sections.sessions(5, true)
---     },
---     content_hooks = {
---       starter.gen_hook.adding_bullet(),
---       starter.gen_hook.indexing('all', { 'Builtin actions' }),
---       starter.gen_hook.padding(3, 2),
---     },
---   })
--- </code>
--- Configuration similar to 'glepnir/dashboard-nvim':
--- <code>
---   local starter = require('mini.starter')
---   starter.setup({
---     items = {
---       starter.sections.telescope(),
---     },
---     content_hooks = {
---       starter.gen_hook.adding_bullet(),
---       starter.gen_hook.aligning('center', 'center'),
---     },
---   })
--- </code>
--- Elaborated configuration showing capabilities of custom items,
--- header/footer, and content hooks:
--- <code>
---   local my_items = {
---     { name = 'Echo random number', action = [[lua print(math.random())]], section = 'Section 1' },
---     function()
---       return {
---         { name = 'Item #1 from function', action = [[echo 'Item #1']], section = 'From function' },
---         { name = 'Placeholder (always incative) item', action = '', section = 'From function' },
---         function()
---           return {
---             name = 'Item #1 from double function',
---             action = [[echo 'Double function']],
---             section = 'From double function',
---           }
---         end,
---       }
---     end,
---     { name = [[Another item in 'Section 1']], action = [[lua print(math.random() + 10)]], section = 'Section 1' },
---   }
---
---   local footer_n_seconds = (function()
---     local timer = vim.loop.new_timer()
---     local n_seconds = 0
---     timer:start(0, 1000, vim.schedule_wrap(function()
---       if vim.api.nvim_buf_get_option(0, 'filetype') ~= 'starter' then
---         timer:stop()
---         return
---       end
---       n_seconds = n_seconds + 1
---       MiniStarter.refresh()
---     end))
---
---     return function()
---       return 'Number of seconds since opening: ' .. n_seconds
---     end
---   end)()
---
---   local hook_top_pad_10 = function(content)
---     -- Pad from top
---     for _ = 1, 10 do
---       -- Insert at start a line with single content unit
---       table.insert(content, 1, { { type = 'empty', string = '' } })
---     end
---     return content
---   end
---
---   local starter = require('mini.starter')
---   starter.setup({
---     items = my_items,
---     footer = footer_n_seconds,
---     content_hooks = { hook_top_pad_10 },
---   })
--- </code>
---
--- # Definition of buffer content
---
--- Generally, buffer content is a table in the form of "2d array" (or rather
--- "2d list" because number of elements can differ):
--- - Each element represents content line: an array with content units to be
---   displayed in one buffer line.
--- - Each content unit is a table with at least the following elements:
---     - "type" - string with type of content. Something like "item",
---       "section", "header", "footer", "empty", etc.
---     - "string" - which string should be displayed. May be an empty string.
---     - "hl" - which highlighting should be applied to content string. May be
---       `nil` for no highlighting.
---
--- See |MiniStarter.content_to_lines| for converting content to buffer lines
--- and |MiniStarter.content_to_items| - to list of parsed items.
---
--- Notes:
--- - Content units with type "item" also have `item` element with all
---   information about an item it represents. Those elements are used directly
---   to create an array of items used for query.
---
--- # Highlight groups
---
--- - `MiniStarterCurrent` - current item.
--- - `MiniStarterFooter` - footer units.
--- - `MiniStarterHeader` - header units.
--- - `MiniStarterInactive` - inactive item.
--- - `MiniStarterItem` - item name.
--- - `MiniStarterItemBullet` - units from |MiniStarter.gen_hook.adding_bullet|.
--- - `MiniStarterItemPrefix` - unique query for item.
--- - `MiniStarterSection` - section units.
--- - `MiniStarterQuery` - current query in active items.
---
--- # Disabling
---
--- To disable core functionality, set `g:ministarter_disable` (globally) or
--- `b:ministarter_disable` (for a buffer) to `v:true`.
---@brief ]]
---@tag MiniStarter mini.starter

-- Module and its helper --
local MiniStarter = {}
local H = {}

--- Module setup
---
---@param config table: Module config table.
---@usage `require('mini.starter').setup({})` (replace `{}` with your `config` table)
function MiniStarter.setup(config)
  -- Export module
  _G.MiniStarter = MiniStarter

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  vim.api.nvim_exec(
    [[augroup MiniStarter
        au!
        au VimEnter * ++nested ++once lua MiniStarter.on_vimenter()
      augroup END]],
    false
  )

  -- Create highlighting
  vim.api.nvim_exec(
    [[hi default link MiniStarterCurrent    NONE
      hi default link MiniStarterFooter     Title
      hi default link MiniStarterHeader     Title
      hi default link MiniStarterInactive   Comment
      hi default link MiniStarterItem       Normal
      hi default link MiniStarterItemBullet Delimiter
      hi default link MiniStarterItemPrefix WarningMsg
      hi default link MiniStarterSection    Delimiter
      hi default link MiniStarterQuery      MoreMsg]],
    false
  )
end

-- Module config --
MiniStarter.config = {
  -- Whether to open starter buffer on VimEnter. Not opened if Neovim was
  -- started with intent to show something else.
  autoopen = true,

  -- Whether to evaluate action of single active item
  evaluate_single = false,

  -- Items to be displayed. Should be an array with the following elements:
  -- - Item: table with `action`, `name`, and `section` keys.
  -- - Function: should return one of these three categories.
  -- - Array: elements of these three types (i.e. item, array, function).
  -- If `nil` (default), default items will be used (see |mini.starter|).
  items = nil,

  -- Header to be displayed before items. Should be a string or function
  -- evaluating to string.
  header = nil,

  -- Footer to be displayed after items. Should be a string or function
  -- evaluating to string.
  footer = nil,

  -- Array  of functions to be applied consecutively to initial content. Each
  -- function should take and return content for 'Starter' buffer (see
  -- |mini.starter| for more details).
  content_hooks = nil,

  -- Characters to update query. Each character will have special buffer
  -- mapping overriding your global ones. Be careful to not add `:` as it
  -- allows you to go into command mode.
  query_updaters = [[abcdefghijklmnopqrstuvwxyz0123456789_-.]],
}

-- Module data --
---@class MiniStarter.content@ Final content of Starter buffer. For more information see "Definition of buffer content" section in |mini.starter|.
MiniStarter.content = {}

-- Module functionality --
--- Act on |VimEnter|.
function MiniStarter.on_vimenter()
  -- It is assumed that something is shown if there is something in 'current'
  -- buffer or if at least one file was supplied on startup
  local is_something_shown = vim.fn.line2byte('$') > 0 or vim.fn.argc() > 0
  if MiniStarter.config.autoopen and not is_something_shown then
    MiniStarter.open()
  end
end

--- Open Starter buffer
---
--- - Create and move into buffer.
--- - Set buffer options. Note that settings are done with |noautocmd| to
---   achieve a massive speedup.
--- - Set buffer mappings. Besides basic mappings (described inside "Lifecycle
---   of Starter buffer" of |mini.starter|), map every character from
---   `MiniStarter.config.query_updaters` to add itself to query with
---   |MiniStarter.add_to_query|.
--- - Populate buffer with |MiniStarter.refresh|.
--- - Issue custom `MiniStarterOpened` event to allow acting upon opening
---   Starter buffer. Use it with
---   `autocmd User MiniStarterOpened <your command>`.
function MiniStarter.open()
  if H.is_disabled() then
    return
  end

  -- Reset helper data
  H.current_item_id = 1
  H.query = ''

  -- Create and open buffer
  H.buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(H.buf_id)

  -- Setup buffer behavior
  H.apply_buffer_options()
  H.apply_buffer_mappings()
  vim.cmd([[au VimResized <buffer> lua MiniStarter.refresh()]])
  vim.cmd([[au CursorMoved <buffer> lua MiniStarter.on_cursormoved()]])
  vim.cmd([[au BufLeave <buffer> echo '']])

  -- Populate buffer
  MiniStarter.refresh()

  -- Issue custom event
  vim.cmd([[doautocmd User MiniStarterOpened]])
end

--- Refresh Starter buffer
---
--- - Normalize `MiniStarter.config.items`:
---     - Flatten: recursively (in depth-first fashion) parse its elements. If
---       function is found, execute it and continue with parsing its output
---       (this allows deferring item collection up until it is actually
---       needed).  If proper item is found (table with fields `action`,
---       `name`, `section`), add it to output.
---     - Sort: order first by section and then by item id (both in order of
---       appearance).
--- - Normalize `MiniStarter.config.header` and `MiniStarter.config.footer` to
---   be a table of strings (per line). If function - evaluate it first.
--- - Make initial buffer content (see |MiniStarter.content| for a description
---   of what a buffer content is). It consist from content lines with single
---   content unit:
---     - First lines contain strings of normalized header.
---     - Body is for normalized items. Section names have own lines preceded
---       by empty line.
---     - Last lines contain separate strings of normalized footer.
--- - Sequentially apply hooks from `MiniStarter.config.content_hooks` to
---   content. Output of one hook serves as input to the next.
--- - Gather final items from content with |MiniStarter.content_to_items|.
--- - Convert content to buffer lines with |MiniStarter.content_to_lines| and
---   add them to buffer.
--- - Add highlighting of content units.
--- - Position cursor.
--- - Make current query. This results into some items being marked as
---   "inactive" and updating highlighting of current query on "active" items.
---
--- Note: this function is executed on every |VimResized| to allow more
--- responsive behavior.
function MiniStarter.refresh()
  if H.is_disabled() or H.buf_id == nil or not vim.api.nvim_buf_is_valid(H.buf_id) then
    return
  end

  -- Normalize certain config values
  local items = H.normalize_items(MiniStarter.config.items or H.default_items)
  H.header = H.normalize_header_footer(MiniStarter.config.header or H.default_header, 'header')
  H.footer = H.normalize_header_footer(MiniStarter.config.footer or H.default_footer, 'footer')

  -- Evaluate content
  H.make_initial_content(items)
  local hooks = MiniStarter.config.content_hooks or H.default_content_hooks
  for _, f in ipairs(hooks) do
    MiniStarter.content = f(MiniStarter.content)
  end
  H.items = MiniStarter.content_to_items()

  -- Add content
  vim.api.nvim_buf_set_option(H.buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_lines(H.buf_id, 0, -1, false, MiniStarter.content_to_lines())
  vim.api.nvim_buf_set_option(H.buf_id, 'modifiable', false)

  -- Add highlighting
  H.content_highlight()
  H.items_highlight()

  -- -- Always position cursor on current item
  H.position_cursor_on_current_item()
  H.add_hl_current_item()

  -- Apply current query (clear command line afterwards)
  H.make_query()
end

--- Close Starter buffer
function MiniStarter.close()
  vim.api.nvim_buf_delete(H.buf_id, {})
  H.buf_id = nil
end

-- Sections --
---@class MiniStarter.sections@Table of pre-configured sections
MiniStarter.sections = {}

--- Section with builtin actions
---
---@return table: Array of items.
function MiniStarter.sections.builtin_actions()
  return {
    { name = 'Edit new buffer', action = 'enew', section = 'Builtin actions' },
    { name = 'Quit Neovim', action = 'qall', section = 'Builtin actions' },
  }
end

--- Section with |MiniSessions| sessions
---
--- Sessions are taken from |MiniSessions.detected|. Notes:
--- - If it shows "'mini.sessions' is not set up", it means that you didn't
---   call `require('mini.sessions').setup()`.
--- - If it shows "There are no detected sessions in 'mini.sessions'", it means
---   that there are no sessions at the current sessions directory. Either
---   create session or supply different directory where session files are
---   stored (see |MiniSessions.setup|).
---
---@param n number: Number of returned items. Default: 5.
---@param recent boolean: Whether to use recent sessions (instead of alphabetically by name). Default: true.
---@return function: Function which returns array of items.
function MiniStarter.sections.sessions(n, recent)
  n = n or 5
  recent = recent == nil and true or recent

  return function()
    if _G.MiniSessions == nil then
      return { { name = [['mini.sessions' is not set up]], action = '', section = 'Sessions' } }
    end

    local items = {}
    for session_name, session in pairs(_G.MiniSessions.detected) do
      table.insert(items, {
        modify_time = session.modify_time,
        name = session_name,
        action = ([[lua _G.MiniSessions.read('%s')]]):format(session_name),
        section = 'Sessions',
      })
    end

    if vim.tbl_count(items) == 0 then
      return { { name = [[There are no detected sessions in 'mini.sessions']], action = '', section = 'Sessions' } }
    end

    local sort_fun
    if recent then
      sort_fun = function(a, b)
        return a.modify_time > b.modify_time
      end
    else
      sort_fun = function(a, b)
        return a.name < b.name
      end
    end
    table.sort(items, sort_fun)

    -- Take only first `n` elements and remove helper `modify_time`
    return vim.tbl_map(function(x)
      x.modify_time = nil
      return x
    end, vim.list_slice(items, 1, n))
  end
end

--- Section with most recently used files
---
--- Files are taken from |vim.v.oldfiles|.
---
---@param n number: Number of returned items. Default: 5.
---@param current_dir boolean: Whether to return files only from current working directory. Default: false.
---@param show_path boolean: Whether to append file name with its full path. Default: true.
---@return function: Function which returns array of items.
function MiniStarter.sections.recent_files(n, current_dir, show_path)
  n = n or 5
  current_dir = current_dir == nil and false or current_dir
  show_path = show_path == nil and true or show_path

  if current_dir then
    vim.cmd([[au DirChanged * lua MiniStarter.refresh()]])
  end

  return function()
    local section = ('Recent files%s'):format(current_dir and ' (current directory)' or '')

    -- Use only actual readable files
    local files = vim.tbl_filter(function(f)
      return vim.fn.filereadable(f) == 1
    end, vim.v.oldfiles or {})

    if #files == 0 then
      return { { name = [[There are no recent files (`v:oldfiles` is empty)]], action = '', section = section } }
    end

    -- Possibly filter files from current directory
    if current_dir then
      local cwd = vim.loop.cwd()
      local n_cwd = cwd:len()
      files = vim.tbl_filter(function(f)
        return f:sub(1, n_cwd) == cwd
      end, files)
    end

    if #files == 0 then
      return { { name = [[There are no recent files in current directory]], action = '', section = section } }
    end

    -- Create items
    local items = {}
    local fmodify = vim.fn.fnamemodify
    for _, f in ipairs(vim.list_slice(files, 1, n)) do
      local path = show_path and (' (%s)'):format(fmodify(f, ':~:.')) or ''
      local name = ('%s%s'):format(fmodify(f, ':t'), path)
      table.insert(items, { action = ('edit %s'):format(fmodify(f, ':p')), name = name, section = section })
    end

    return items
  end
end

-- stylua: ignore start
--- Section with basic Telescope pickers relevant to start screen
---
---@return function: Function which returns array of items.
function MiniStarter.sections.telescope()
  return function()
    return {
      {action = 'Telescope file_browser',    name = 'Browser',         section = 'Telescope'},
      {action = 'Telescope command_history', name = 'Command history', section = 'Telescope'},
      {action = 'Telescope find_files',      name = 'Files',           section = 'Telescope'},
      {action = 'Telescope help_tags',       name = 'Help tags',       section = 'Telescope'},
      {action = 'Telescope live_grep',       name = 'Live grep',       section = 'Telescope'},
      {action = 'Telescope oldfiles',        name = 'Old files',       section = 'Telescope'},
    }
  end
end
-- stylua: ignore end

-- Content hooks --
---@class MiniStarter.gen_hook@Table with pre-configured content hook generators. Each element is a function which returns content hook. So to use them inside |MiniStarter.setup|, call them.
MiniStarter.gen_hook = {}

--- Hook generator for padding
---
--- Output is a content hook which adds constant padding from left and top.
--- This allows tweaking the screen position of buffer content.
---
---@param left number: Number of empty spaces to add to start of each content line. Default: 0.
---@param top number: Number of empty lines to add to start of content. Default: 0.
---@return function: Content hook.
function MiniStarter.gen_hook.padding(left, top)
  left = math.max(left or 0, 0)
  top = math.max(top or 0, 0)
  return function(content)
    -- Add left padding
    local left_pad = string.rep(' ', left)
    for _, line in ipairs(content) do
      table.insert(line, 1, H.content_unit(left_pad, 'empty', nil))
    end

    -- Add top padding
    local top_lines = {}
    for _ = 1, top do
      table.insert(top_lines, { H.content_unit('', 'empty', nil) })
    end
    content = vim.list_extend(top_lines, content)

    return content
  end
end

--- Hook generator for adding bullet to items
---
--- Output is a content hook which adds supplied string to be displayed to the
--- left of item.
---
---@param bullet string: String to be placed to the left of item name. Default: "░ ".
---@param place_cursor boolean: Whether to place cursor on the first character of bullet when corresponding item becomes current. Default: true.
---@return function: Content hook.
function MiniStarter.gen_hook.adding_bullet(bullet, place_cursor)
  bullet = bullet or '░ '
  place_cursor = place_cursor == nil and true or place_cursor
  return function(content)
    local coords = MiniStarter.content_coords(content, 'item')
    -- Go backwards to avoid conflict when inserting units
    for i = #coords, 1, -1 do
      local l_num, u_num = coords[i].line, coords[i].unit
      local bullet_unit = {
        string = bullet,
        type = 'item_bullet',
        hl = 'MiniStarterItemBullet',
        -- Use `_item` instead of `item` because it is better to be 'private'
        _item = content[l_num][u_num].item,
        _place_cursor = place_cursor,
      }
      table.insert(content[l_num], u_num, bullet_unit)
    end

    return content
  end
end

--- Hook generator for indexing items
---
--- Output is a content hook which adds unique index to the start of item's
--- name. It results into shortening queries required to choose an item (at
--- expense of clarity).
---
---@param grouping string: One of "all" (number indexing across all sections) or "section" (letter-number indexing within each section). Default: "all".
---@param exclude_sections table: Array of section names (values of `section` element of item) for which index won't be added. Default: `{}`.
---@return function: Content hook.
function MiniStarter.gen_hook.indexing(grouping, exclude_sections)
  grouping = grouping or 'all'
  exclude_sections = exclude_sections or {}
  local per_section = grouping == 'section'

  return function(content)
    local cur_section, n_section, n_item = nil, 0, 0
    local coords = MiniStarter.content_coords(content, 'item')

    for _, c in ipairs(coords) do
      local unit = content[c.line][c.unit]
      local item = unit.item

      if not vim.tbl_contains(exclude_sections, item.section) then
        n_item = n_item + 1
        if cur_section ~= item.section then
          cur_section = item.section
          -- Cycle through lower case letters
          n_section = math.fmod(n_section, 26) + 1
          n_item = per_section and 1 or n_item
        end

        local section_index = per_section and string.char(96 + n_section) or ''
        unit.string = ('%s%s. %s'):format(section_index, n_item, unit.string)
      end
    end

    return content
  end
end

--- Hook generator for aligning content
---
--- Output is a content hook which independently aligns content horizontally
--- and vertically. Basically, this computes left and top pads for
--- |MiniStarter.gen_hook.padding| such that output lines would appear aligned
--- in certain way.
---
---@param horizontal string: One of "left", "center", "right". Default: "left".
---@param vertical string: One of "top", "center", "bottom". Default: "top".
---@return function: Content hook.
function MiniStarter.gen_hook.aligning(horizontal, vertical)
  horizontal = horizontal == nil and 'left' or horizontal
  vertical = vertical == nil and 'top' or vertical

  local horiz_coef = ({ left = 0, center = 0.5, right = 1.0 })[horizontal]
  local vert_coef = ({ top = 0, center = 0.5, bottom = 1.0 })[vertical]

  return function(content)
    local line_strings = MiniStarter.content_to_lines(content)

    -- Align horizontally
    -- Don't use `string.len()` to account for multibyte characters
    local lines_width = vim.tbl_map(function(l)
      return vim.fn.strdisplaywidth(l)
    end, line_strings)
    local min_right_space = vim.fn.winwidth(0) - math.max(unpack(lines_width))
    local left_pad = math.max(math.floor(horiz_coef * min_right_space), 0)

    -- Align vertically
    local bottom_space = vim.fn.winheight(0) - #line_strings
    local top_pad = math.max(math.floor(vert_coef * bottom_space), 0)

    return MiniStarter.gen_hook.padding(left_pad, top_pad)(content)
  end
end

-- Work with content --
--- Helper to iterate through content
---
--- Basically, this traverses content "2d array" (in depth-first fashion; top
--- to bottom, left to right) and returns "coordinates" of units for which
--- `predicate` is true-ish.
---
---@param content table: Content "2d array".
---@param predicate function|string: Predictate to filter units. If function, evaluated with unit as input. If string, checks unit to have this type (allows easy getting of units with some type). If `nil`, all units are kept.
---@return table: Array of resulting units' coordinates. Each coordinate is a table with `line` and `unit` keys. To retrieve actual unit from coordinate `c`, use `content[c.line][c.unit]`.
function MiniStarter.content_coords(content, predicate)
  content = content or MiniStarter.content
  if type(predicate) == 'string' then
    local pred_type = predicate
    predicate = function(unit)
      return unit.type == pred_type
    end
  end

  local res = {}
  for l_num, line in ipairs(content) do
    for u_num, unit in ipairs(line) do
      if predicate == nil or predicate(unit) then
        table.insert(res, { line = l_num, unit = u_num })
      end
    end
  end
  return res
end

-- stylua: ignore start
--- Convert content to buffer lines
---
--- One buffer line is made by concatenating `string` element of units within
--- same content line.
---
---@param content table: Content "2d array".
---@return table: Array of strings for each buffer line.
function MiniStarter.content_to_lines(content)
  return vim.tbl_map(
    function(content_line)
      return table.concat(
      -- Ensure that each content line is indeed a single buffer line
        vim.tbl_map(function(x) return x.string:gsub('\n', ' ') end, content_line), ''
      )
    end,
    content or MiniStarter.content
  )
end
-- stylua: ignore end

--- Convert content to items
---
--- Parse content (in depth-first fashion) and retrieve each item from `item`
--- element of content units with type "item". This also:
--- - Computes some helper information about how item will be actually
---   displayed (after |MiniStarter.content_to_lines|) and minimum number of
---   prefix characters needed for a particular item to be queried single.
--- - Modifies item's `name` element taking it from corresponing `string`
---   element of content unit. This allows modifying item's `name` at the stage
---   of content hooks (like, for example, in |MiniStarter.gen_hook.indexing|).
---
---@param content table: Content "2d array".
---@return table: Array of items.
function MiniStarter.content_to_items(content)
  content = content or MiniStarter.content

  -- NOTE: this havily utilizes 'modify by reference' nature of Lua tables
  local items = {}
  for l_num, line in ipairs(content) do
    -- Track 0-based starting column of current unit (using byte length)
    local start_col = 0
    for _, unit in ipairs(line) do
      -- Cursor position is (1, 0)-based
      local cursorpos = { l_num, start_col }

      if unit.type == 'item' then
        local item = unit.item
        -- Take item's name from content string
        item.name = unit.string:gsub('\n', ' ')
        item._line = l_num - 1
        item._start_col = start_col
        item._end_col = start_col + unit.string:len()
        -- Don't overwrite possible cursor position from item's bullet
        item._cursorpos = item._cursorpos or cursorpos

        table.insert(items, item)
      end

      -- Prefer placing cursor at start of item's bullet
      if unit.type == 'item_bullet' and unit._place_cursor then
        -- Item bullet uses 'private' `_item` element instead of `item`
        unit._item._cursorpos = cursorpos
      end

      start_col = start_col + unit.string:len()
    end
  end

  -- Compute length of unique prefix for every item's name (ignoring case)
  local strings = vim.tbl_map(function(x)
    return x.name:lower()
  end, items)
  local nprefix = H.unique_nprefix(strings)
  for i, n in ipairs(nprefix) do
    items[i]._nprefix = n
  end

  return items
end

-- Other exported functions --
--- Evaluate current item
function MiniStarter.eval_current_item()
  H.eval_fun_or_string(H.items[H.current_item_id].action, true)
end

--- Update current item
---
--- This makes next (with respect to `direction`) active item to be current.
---
---@param direction string: One of "next" or "previous".
function MiniStarter.update_current_item(direction)
  -- Advance current item
  local prev_current = H.current_item_id
  H.current_item_id = H.next_active_item_id(H.current_item_id, direction)
  if H.current_item_id == prev_current then
    return
  end

  -- Update cursor position
  H.position_cursor_on_current_item()

  -- Highlight current item
  vim.api.nvim_buf_clear_namespace(H.buf_id, H.ns.current_item, 0, -1)
  H.add_hl_current_item()
end

--- Add character to current query
---
--- - Update current query by appending `char` to its end or delete latest
---   character if `char` is `nil`.
--- - Recompute status of items: "active" if its name starts with new query,
---   "inactive" otherwise.
--- - Update highlighting: whole strings for "inactive" items, current query
---   for "active" items.
---
---@param char string: Single character to be added to query. If `nil`, deletes latest character from query.
function MiniStarter.add_to_query(char)
  if char == nil then
    H.query = H.query:sub(0, H.query:len() - 1)
  else
    H.query = ('%s%s'):format(H.query, char)
  end
  H.make_query()
end

--- Act on |CursorMoved| by repositioning cursor in fixed place.
function MiniStarter.on_cursormoved()
  H.position_cursor_on_current_item()
end

-- Helper data --
-- Module default config
H.default_config = MiniStarter.config

-- Default config values
H.default_items = {
  function()
    if _G.MiniSessions == nil then
      return {}
    end
    return MiniStarter.sections.sessions(5, true)()
  end,
  MiniStarter.sections.recent_files(5, false, false),
  MiniStarter.sections.builtin_actions(),
}

H.default_header = function()
  local hour = tonumber(vim.fn.strftime('%H'))
  -- [04:00, 12:00) - morning, [12:00, 20:00) - day, [20:00, 04:00) - evening
  local part_id = math.floor((hour + 4) / 8) + 1
  local day_part = ({ 'evening', 'morning', 'afternoon', 'evening' })[part_id]
  local username = vim.fn.getenv('USERNAME') or 'USERNAME'

  return ('Good %s, %s'):format(day_part, username)
end

H.default_footer = [[
Type query to filter items
<BS> deletes latest character from query
<Down>/<Up> and <M-j>/<M-k> move current item
<CR> executes action of current item
<C-c> closes this buffer]]

H.default_content_hooks = { MiniStarter.gen_hook.adding_bullet(), MiniStarter.gen_hook.aligning('center', 'center') }

-- Normalized values from config
H.items = {} -- items gathered with `MiniStarter.content_to_items` from final content
H.header = {} -- table of strings
H.footer = {} -- table of strings

-- Identifier of current item
H.current_item_id = nil

-- Buffer identifier where everything is displayed
H.buf_id = nil

-- Namespaces for highlighting
H.ns = {
  activity = vim.api.nvim_create_namespace(''),
  current_item = vim.api.nvim_create_namespace(''),
  general = vim.api.nvim_create_namespace(''),
}

-- Current search query
H.query = ''

-- Settings --
function H.setup_config(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', H.default_config, config or {})

  vim.validate({
    autoopen = { config.autoopen, 'boolean' },
    evaluate_single = { config.evaluate_single, 'boolean' },

    items = { config.items, 'table', true },
    header = { config.header, H.is_fun_or_string, 'function or string' },
    footer = { config.footer, H.is_fun_or_string, 'function or string' },

    content_hooks = { config.content_hooks, 'table', true },

    query_updaters = { config.query_updaters, 'string' },
  })

  return config
end

function H.apply_config(config)
  MiniStarter.config = config
end

function H.is_disabled()
  return vim.g.ministarter_disable == true or vim.b.ministarter_disable == true
end

-- Normalize config elements --
function H.normalize_items(items)
  local res = H.items_flatten(items)
  if #res == 0 then
    return { { name = '`MiniStarter.config.items` is empty', action = '', section = '' } }
  end
  return H.items_sort(res)
end

function H.normalize_header_footer(x, x_name)
  local res = H.eval_fun_or_string(x)
  if type(res) ~= 'string' then
    H.notify(('`config.%s` should be evaluated into string.'):format(x_name))
    return {}
  end
  if res == '' then
    return {}
  end
  return vim.split(res, '\n')
end

-- Work with buffer content --
function H.make_initial_content(items)
  MiniStarter.content = {}

  -- Add header lines
  for _, l in ipairs(H.header) do
    H.content_add_line({ H.content_unit(l, 'header', 'MiniStarterHeader') })
  end
  H.content_add_empty_lines(#H.header > 0 and 1 or 0)

  -- Add item lines
  H.content_add_items(items)

  -- Add footer lines
  H.content_add_empty_lines(#H.footer > 0 and 1 or 0)
  for _, l in ipairs(H.footer) do
    H.content_add_line({ H.content_unit(l, 'footer', 'MiniStarterFooter') })
  end
end

function H.content_unit(string, type, hl, extra)
  return vim.tbl_extend('force', { string = string, type = type, hl = hl }, extra or {})
end

function H.content_add_line(content_line)
  table.insert(MiniStarter.content, content_line)
end

function H.content_add_empty_lines(n)
  for _ = 1, n do
    H.content_add_line({ H.content_unit('', 'empty', nil) })
  end
end

function H.content_add_items(items)
  local cur_section
  for _, item in ipairs(items) do
    -- Possibly add section line
    if cur_section ~= item.section then
      -- Don't add empty line before first section line
      H.content_add_empty_lines(cur_section == nil and 0 or 1)
      H.content_add_line({ H.content_unit(item.section, 'section', 'MiniStarterSection') })
      cur_section = item.section
    end

    H.content_add_line({ H.content_unit(item.name, 'item', 'MiniStarterItem', { item = item }) })
  end
end

function H.content_highlight()
  for l_num, content_line in ipairs(MiniStarter.content) do
    -- Track 0-based starting column of current unit (using byte length)
    local start_col = 0
    for _, unit in ipairs(content_line) do
      if unit.hl ~= nil then
        H.buf_hl(H.ns.general, unit.hl, l_num - 1, start_col, start_col + unit.string:len())
      end
      start_col = start_col + unit.string:len()
    end
  end
end

-- Work with items --
function H.items_flatten(items)
  local res, f = {}, nil
  f = function(x)
    if H.is_item(x) then
      -- Use deepcopy to allow adding fields to items without changing original
      table.insert(res, vim.deepcopy(x))
      return
    end

    -- Expand (possibly recursively) functions immediately
    local n_nested = 0
    while type(x) == 'function' do
      n_nested = n_nested + 1
      if n_nested > 100 then
        H.notify('Too many nested functions in `config.items`.')
      end
      x = x()
    end

    if type(x) ~= 'table' then
      return
    end
    return vim.tbl_map(f, x)
  end

  f(items)
  return res
end

function H.items_sort(items)
  -- Order first by section and then by item id (both in order of appearence)
  -- Gather items grouped per section in order of their appearence
  local sections, section_order = {}, {}
  for _, item in ipairs(items) do
    local sec = item.section
    if section_order[sec] == nil then
      table.insert(sections, {})
      section_order[sec] = #sections
    end
    table.insert(sections[section_order[sec]], item)
  end

  -- Unroll items in depth-first fashion
  local res = {}
  for _, section_items in ipairs(sections) do
    for _, item in ipairs(section_items) do
      table.insert(res, item)
    end
  end

  return res
end

function H.items_highlight()
  for _, item in ipairs(H.items) do
    H.buf_hl(H.ns.general, 'MiniStarterItemPrefix', item._line, item._start_col, item._start_col + item._nprefix)
  end
end

function H.next_active_item_id(item_id, direction)
  -- Advance in cyclic fashion
  local id = item_id
  local n_items = vim.tbl_count(H.items)
  local increment = direction == 'next' and 1 or (n_items - 1)

  -- Increment modulo `n` but for 1-based indexing
  id = math.fmod(id + increment - 1, n_items) + 1
  while not (H.items[id]._active or id == item_id) do
    id = math.fmod(id + increment - 1, n_items) + 1
  end

  return id
end

function H.position_cursor_on_current_item()
  vim.api.nvim_win_set_cursor(0, H.items[H.current_item_id]._cursorpos)
end

-- Work with queries --
function H.make_query(query)
  -- Ignore case
  query = (query or H.query):lower()

  -- Item is active = item's name starts with query (ignoring case) and item's
  -- action is non-empty
  local n_active = 0
  for _, item in ipairs(H.items) do
    item._active = vim.startswith(item.name:lower(), query) and item.action ~= ''
    n_active = n_active + (item._active and 1 or 0)
  end

  -- Move to next active item if current is not active
  if not H.items[H.current_item_id]._active then
    MiniStarter.update_current_item('next')
  end

  -- Update activity highlighting. This should go before `evaluate_single`
  -- check because evaluation might not result into closing Starter buffer
  vim.api.nvim_buf_clear_namespace(H.buf_id, H.ns.activity, 0, -1)
  H.add_hl_activity(query)

  -- Possibly evaluate single active item
  if MiniStarter.config.evaluate_single and n_active == 1 then
    MiniStarter.eval_current_item()
    return
  end

  -- Notify about new query
  local msg = ('Query: %s'):format(H.query)
  if n_active == 0 then
    msg = ('%s . There is no active items. Use <BS> to delete symbols from query.'):format(msg)
  end
  -- Use `echo` because it doesn't write to `:messages`
  vim.cmd(([[echo '(mini.starter) %s']]):format(vim.fn.escape(msg, [[']])))
end

-- Work with starter buffer --
function H.apply_buffer_options()
  -- Force Normal mode
  vim.cmd([[normal! <ESC>]])

  vim.api.nvim_buf_set_name(H.buf_id, 'Starter')
  -- Having `noautocmd` is crucial for performance: ~9ms without it, ~1.6ms with it
  vim.cmd([[noautocmd silent! set filetype=starter]])

  local options = {
    -- Taken from 'vim-startify'
    [[bufhidden=wipe]],
    [[colorcolumn=]],
    [[foldcolumn=0]],
    [[matchpairs=]],
    [[nobuflisted]],
    [[nocursorcolumn]],
    [[nocursorline]],
    [[nolist]],
    [[nonumber]],
    [[noreadonly]],
    [[norelativenumber]],
    [[nospell]],
    [[noswapfile]],
    [[signcolumn=no]],
    [[synmaxcol&]],
    -- Differ from 'vim-startify'
    [[nomodifiable]],
    [[foldlevel=999]],
  }
  -- Vim's `setlocal` is currently more robust comparing to `opt_local`
  vim.cmd(('silent! noautocmd setlocal %s'):format(table.concat(options, ' ')))

  -- Hide tabline (but not statusline as it weirdly feels 'naked' without it)
  vim.cmd(('au BufLeave <buffer> set showtabline=%s'):format(vim.o.showtabline))
  vim.o.showtabline = 0

  -- Disable 'mini.cursorword'
  vim.b.minicursorword_disable = true
end

function H.apply_buffer_mappings()
  H.buf_keymap('<CR>', [[MiniStarter.eval_current_item()]])

  H.buf_keymap('<Up>', [[MiniStarter.update_current_item('prev')]])
  H.buf_keymap('<M-k>', [[MiniStarter.update_current_item('prev')]])
  H.buf_keymap('<Down>', [[MiniStarter.update_current_item('next')]])
  H.buf_keymap('<M-j>', [[MiniStarter.update_current_item('next')]])

  -- Make all special symbols to update query
  for _, key in ipairs(vim.split(MiniStarter.config.query_updaters, '')) do
    H.buf_keymap(key, ([[MiniStarter.add_to_query('%s')]]):format(key))
  end

  H.buf_keymap('<BS>', [[MiniStarter.add_to_query()]])
  H.buf_keymap('<C-c>', [[MiniStarter.close()]])
end

function H.add_hl_activity(query)
  for _, item in ipairs(H.items) do
    local l = item._line
    local s = item._start_col
    local e = item._end_col
    if item._active then
      H.buf_hl(H.ns.activity, 'MiniStarterQuery', l, s, s + query:len())
    else
      H.buf_hl(H.ns.activity, 'MiniStarterInactive', l, s, e)
    end
  end
end

function H.add_hl_current_item()
  local cur_item = H.items[H.current_item_id]
  H.buf_hl(H.ns.current_item, 'MiniStarterCurrent', cur_item._line, cur_item._start_col, cur_item._end_col)
end

-- Predicates --
function H.is_fun_or_string(x, allow_nil)
  allow_nil = allow_nil == nil and true or allow_nil
  return (allow_nil and x == nil) or type(x) == 'function' or type(x) == 'string'
end

function H.is_item(x)
  return type(x) == 'table'
    and H.is_fun_or_string(x['action'], false)
    and type(x['name']) == 'string'
    and type(x['section']) == 'string'
end

-- Utilities --
function H.eval_fun_or_string(x, string_as_cmd)
  if type(x) == 'function' then
    return x()
  end
  if type(x) == 'string' then
    if string_as_cmd then
      vim.cmd(x)
    else
      return x
    end
  end
end

function H.buf_keymap(key, cmd)
  vim.api.nvim_buf_set_keymap(H.buf_id, 'n', key, ('<Cmd>lua %s<CR>'):format(cmd), { nowait = true, silent = true })
end

function H.buf_hl(ns_id, hl_group, line, col_start, col_end)
  vim.api.nvim_buf_add_highlight(H.buf_id, ns_id, hl_group, line, col_start, col_end)
end

function H.notify(msg)
  vim.notify(('(mini.starter) %s'):format(msg))
end

function H.unique_nprefix(strings)
  -- For every string compute minimum width of unique prefix. NOTE: this can be
  -- done simpler but it would be O(n^2) which *will* have noticable effect
  -- when there are a) many items and b) some of them are identical and have
  -- big length (like recent files with full paths).

  -- Make copy because it will be modified
  local str_set = vim.deepcopy(strings)
  local res, cur_n = {}, 0
  while vim.tbl_count(str_set) > 0 do
    cur_n = cur_n + 1

    -- `prefix_tbl`: string id's with current prefix
    -- `nowhere_to_go` is `true` if all strings have lengths less than `cur_n`
    local prefix_tbl, nowhere_to_go = {}, true
    for id, s in pairs(str_set) do
      nowhere_to_go = nowhere_to_go and (#s < cur_n)
      local prefix = s:sub(1, cur_n)
      prefix_tbl[prefix] = prefix_tbl[prefix] == nil and {} or prefix_tbl[prefix]
      table.insert(prefix_tbl[prefix], id)
    end

    -- Output for non-unique string is its length
    if nowhere_to_go then
      for k, s in pairs(str_set) do
        res[k] = #s
      end
      break
    end

    for _, keys_with_prefix in pairs(prefix_tbl) do
      -- If prefix is seen only once, it is unique
      if #keys_with_prefix == 1 then
        local k = keys_with_prefix[1]
        -- Use `math.min` to account for empty strings and non-unique ones
        res[k] = math.min(#str_set[k], cur_n)
        -- Remove this string as it already has final nprefix
        str_set[k] = nil
      end
    end
  end

  return res
end

return MiniStarter
