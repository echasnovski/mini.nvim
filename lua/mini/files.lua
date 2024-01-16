--- *mini.files* Navigate and manipulate file system
--- *MiniFiles*
---
--- MIT License Copyright (c) 2023 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Features:
--- - Navigate file system using column view (Miller columns) to display nested
---   directories. See |MiniFiles-navigation| for overview.
---
--- - Opt-in preview of file or directory under cursor.
---
--- - Manipulate files and directories by editing text buffers: create, delete,
---   copy, rename, move. See |MiniFiles-manipulation| for overview.
---
--- - Use as default file explorer instead of |netrw|.
---
--- - Configurable:
---     - Filter/prefix/sort of file system entries.
---     - Mappings used for common explorer actions.
---     - UI options: whether to show preview of file/directory under cursor, etc.
---
--- What it doesn't do:
--- - Try to be replacement of system file explorer. It is mostly designed to
---   be used within Neovim to quickly explore file system structure, open
---   files, and perform some quick file system edits.
---
--- - Work on remote locations. Only local file system is supported.
---
--- - Provide built-in interactive toggle of content `filter` and `sort`.
---   See |MiniFiles-examples| for some common examples.
---
--- - Provide out of the box extra information like git or diagnostic status.
---   This can be achieved by setting |extmarks| on appropriate event(s)
---   (see |MiniFiles-events|)
---
--- Notes:
--- - This module is written and thoroughly tested on Linux. Support for other
---   platform/OS (like Windows or MacOS) is a goal, but there is no guarantee.
---
--- - Works on all supported versions but using Neovim>=0.9 is recommended.
---
--- - This module silently reacts to not enough permissions:
---     - In case of missing file, check its or its parent read permissions.
---     - In case of no manipulation result, check write permissions.
---
--- # Dependencies ~
---
--- Suggested dependencies (provide extra functionality, will work without them):
--- - Plugin 'nvim-tree/nvim-web-devicons' for filetype icons near the entry
---   name. If missing, default icons will be used.
---
--- # Setup ~
---
--- This module needs a setup with `require('mini.files').setup({})` (replace
--- `{}` with your `config` table). It will create global Lua table `MiniFiles`
--- which you can use for scripting or manually (with `:lua MiniFiles.*`).
---
--- See |MiniFiles.config| for available config settings.
---
--- You can override runtime config settings (like mappings or window options)
--- locally to buffer inside `vim.b.minifiles_config` which should have same
--- structure as `MiniFiles.config`. See |mini.nvim-buffer-local-config| for
--- more details.
---
--- # Comparisons ~
---
--- - 'nvim-tree/nvim-tree.lua':
---     - Provides tree view of file system, while this module uses column view.
---     - File system manipulation is done with custom set of mappings for each
---       action, while this module is designed to do that by editing text.
---     - Has more out of the box functionality with extra configuration, while
---       this module has not (by design).
---
--- - 'stevearc/oil.nvim':
---     - Uses single window to show information only about currently explored
---       directory, while this module uses column view to show whole currently
---       explored branch.
---     - Also uses text editing to manipulate file system entries.
---     - Can work for remote file systems, while this module can not (by design).
---
--- - 'nvim-neo-tree/neo-tree.nvim':
---     - Compares to this module mostly the same as 'nvim-tree/nvim-tree.lua'.
---
--- # Highlight groups ~
---
--- * `MiniFilesBorder` - border of regular windows.
--- * `MiniFilesBorderModified` - border of windows showing modified buffer.
--- * `MiniFilesCursorLine` - cursor line in explorer windows.
--- * `MiniFilesDirectory` - text and icon representing directory.
--- * `MiniFilesFile` - text representing file.
--- * `MiniFilesNormal` - basic foreground/background highlighting.
--- * `MiniFilesTitle` - title of regular windows.
--- * `MiniFilesTitleFocused` - title of focused window.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling ~
---
--- This plugin provides only manually started functionality, so no disabling
--- is available.

--- Navigation ~
---
--- Every navigation starts by calling |MiniFiles.open()|, either directly or via
--- mapping (see its help for examples of some common scenarios). It will show
--- an explorer consisting of side-by-side floating windows with the following
--- principles:
---
--- - Explorer shows one branch of nested directories at a time.
---
--- - Explorer consists from several windows:
---
---     - Each window displays entries of a single directory in a modifiable
---       scratch buffer.
---
---     - Windows are organized left to right: for any particular window the left
---       neighbor is its parent directory and right neighbor - its child.
---
--- - Explorer windows are the viewport to some part of current branch, meaning
---   that their opening/closing does not affect the branch. This matters, for
---   example, if there are more elements in the branch than can be shown windows.
---
--- - Every buffer line represents separate file system entry following certain
---   format (not visible for users by default; set |conceallevel| to 0 to see it)
---
--- - Once directory is shown, its buffer is not updated automatically following
---   external file system changes. Manually use |MiniFiles.synchronize()| for that.
---
--- After opening explorer, in-buffer navigation is done the same way as any
--- regular buffer, except without some keys reserved for built-in actions.
---
--- Most common ways to navigate are:
---
--- - Press `j` to move cursor onto next (lower) entry in current directory.
--- - Press `k` to move cursor onto previous (higher) entry in current directory.
--- - Press `l` to expand entry under cursor (see "Go in" action).
--- - Press `h` to focus on parent directory (see "Go out" action).
---
--- Cursor positions in each directory buffer are tracked and saved during
--- navigation. This allows for more convenient repeated navigation to some
--- previously visited branch.
---
--- Available built-in actions (see "Details" for more information): >
---
---  | Action      | Keys | Description                                    |
---  |-------------|------|------------------------------------------------|
---  | Close       |  q   | Close explorer                                 |
---  |-------------|------|------------------------------------------------|
---  | Go in       |  l   | Expand entry (show directory or open file)     |
---  |-------------|------|------------------------------------------------|
---  | Go in plus  |  L   | Expand entry plus extra action                 |
---  |-------------|------|------------------------------------------------|
---  | Go out      |  h   | Focus on parent directory                      |
---  |-------------|------|------------------------------------------------|
---  | Go out plus |  H   | Focus on parent directory plus extra action    |
---  |-------------|------|------------------------------------------------|
---  | Reset       | <BS> | Reset current explorer                         |
---  |-------------|------|------------------------------------------------|
---  | Reveal cwd  |  @   | Reset current current working directory        |
---  |-------------|------|------------------------------------------------|
---  | Show help   |  g?  | Show help window                               |
---  |-------------|------|------------------------------------------------|
---  | Synchronize |  =   | Synchronize user edits and/or external changes |
---  |-------------|------|------------------------------------------------|
---  | Trim left   |  <   | Trim left part of branch                       |
---  |-------------|------|------------------------------------------------|
---  | Trim right  |  >   | Trim right part of branch                      |
---  |-------------|------|------------------------------------------------|
--- <
--- Details:
---
--- - "Go in":
---     - Always opens file in the latest window before `MiniFiles.open()` call.
---     - Never closes explorer.
---     - Works in linewise Visual mode to expand multiple entries.
---
--- - "Go in plus" is regular "Go in" but closes explorer after opening a file.
---
--- - "Go out plus" is regular "Go out" but trims right part of branch.
---
--- - "Reset" focuses only on "anchor" directory (the one used to open current
---   explorer) and resets all stored directory cursor positions.
---
--- - "Reveal cwd" extends branch to include |current-directory|.
---   If it is not an ancestor of the current branch, nothing is done.
---
--- - "Show help" results into new window with helpful information about current
---   explorer. Press `q` to close it.
---
--- - "Synchronize" parses user edits in directory buffers, applies them (after
---   confirmation), and updates all directory buffers with the most relevant
---   file system information. Can also be used without user edits to show up
---   to date file system entries.
---   See |MiniFiles-manipulation| for more info about file system manipulation.
---
--- - "Trim left" and "Trim right" trim parts of the whole branch, not only its
---   currently visible parts.
---
--- Notes:
---
--- - Each action has exported function with more details about it.
---
--- - Keys can be configured with `mappings` table of |MiniFiles.config|.
---@tag MiniFiles-navigation

--- Manipulation ~
---
--- File system manipulation is done by editing text inside directory buffers,
--- which are shown inside dedicated window(s). See |MiniFiles-navigation| for
--- more information about navigating to a particular directory.
---
--- General workflow:
---
--- - Navigate to the directory in which manipulation should be done.
---
--- - Edit buffer in the way representing file system action.
---
--- - Repeat previous steps until all necessary file system actions are recorded.
---   Note: even if directory buffer is hidden, its modifications are preserved,
---   so you can navigate in and out of directory with modified buffer.
---
--- - Execute |MiniFiles.synchronize()| (default key is `=`). This will prompt
---   confirmation dialog listing all file system actions it is about to perform.
---   READ IT CAREFULLY.
---
--- - Confirm by pressing `y`/`<CR>` (applies edits and updates buffers) or
---   don't confirm by pressing `n`/`<Esc>` (updates buffers without applying edits).
---
--- # How does it work ~
---
--- All manipulation functionality is powered by creating and keeping track of
--- path indexes: text of the form `/xxx` (`xxx` is the number path index) placed
--- at the start of every line representing file system entry.
---
--- By default they are hidden as concealed text (along with prefix separators)
--- for more convenience but you can see them by setting |conceallevel| to 0.
--- DO NOT modify text to the left of entry name.
---
--- During synchronization, actual text for entry name is compared to path index
--- at that line (if present) to deduce which file system action to perform.
---
--- # Supported file system actions ~
---
--- ## Create ~
---
--- - Create file by creating new line with file name (including extension).
---
--- - Create directory by creating new line with directory name followed by `/`.
---
--- - Create file or directory inside nested directories by creating new line
---   with text like 'dir/nested-dir/' or 'dir/nested-dir/file'.
---   Always use `/` on any OS.
---
--- ## Delete ~
---
--- - Delete file or directory by deleting **whole line** describing it.
---
--- - If `options.permanent_delete` is `true`, delete is permanent. Otherwise
---   file system entry is moved to a module-specific trash directory
---   (see |MiniFiles.config| for more details).
---
--- ## Rename ~
---
--- - Rename file or directory by editing its name (not icon or path index to
---   the left of it).
---
--- - With default mappings for `h`/`l` it might be not convenient to rename
---   only part of an entry. You can adopt any of the following approaches:
---     - Use different motions, like |$|, |e|, |f|, etc.
---     - Go into Insert mode and navigate inside it.
---     - Change mappings to be more suited for manipulation and not navigation.
---       See "Mappings" section in |MiniFiles.config|.
---
--- - It is not needed to end directory name with `/`.
---
--- - Cyclic renames ('a' to 'b' and 'b' to 'a') are not supported.
---
--- ## Copy ~
---
--- - Copy file or directory by copying **whole line** describing it and pasting
---   it inside buffer of target directory.
---
--- - Change of target path is allowed. Edit only entry name in target location
---   (not icon or path index to the left of it).
---
--- - Copying inside same parent directory is supported only if target path has
---   different name.
---
--- - Copying inside child directory is supported.
---
--- ## Move ~
---
--- - Move file or directory by cutting **whole line** describing it and then
---   pasting it inside target directory.
---
--- - Change of target path is allowed. Edit only entry name in target location
---   (not icon or path index to the left of it).
---
--- - Moving directory inside itself is not supported.
---
---@tag MiniFiles-manipulation

--- Events ~
---
--- To allow user customization and integration of external tools, certain |User|
--- autocommand events are triggered under common circumstances.
---
--- UI events ~
---
--- - `MiniFilesBufferCreate` - when buffer is created to show a particular
---   directory. Triggered once per directory during one explorer session.
---   Can be used to create buffer-local mappings.
---
--- - `MiniFilesBufferUpdate` - when directory buffer is updated with new content.
---   Can be used for integrations to set |extmarks| with useful information.
---
--- - `MiniFilesWindowOpen` - when new window is opened. Can be used to set
---   window-local settings (like border, 'winblend', etc.)
---
--- - `MiniFilesWindowUpdate` - when a window is updated. Triggers frequently,
---   for example, for every "go in" or "go out" action.
---
--- Callback for each UI event will receive `data` field (see |nvim_create_autocmd()|)
--- with the following information:
---
--- - <buf_id> - index of target buffer.
--- - <win_id> - index of target window. Can be `nil`, like in
---   `MiniFilesBufferCreate` and buffer's first `MiniFilesBufferUpdate` as
---   they are triggered before window is created.
---
--- File action events ~
---
--- - `MiniFilesActionCreate` - after entry is successfully created.
---
--- - `MiniFilesActionDelete` - after entry is successfully deleted.
---
--- - `MiniFilesActionRename` - after entry is successfully renamed.
---
--- - `MiniFilesActionCopy` - after entry is successfully copied.
---
--- - `MiniFilesActionMove` - after entry is successfully moved.
---
--- Callback for each file action event will receive `data` field
--- (see |nvim_create_autocmd()|) with the following information:
---
--- - <action> - string with action name.
--- - <from> - absolute path of entry before action (`nil` for "create" action).
--- - <to> - absolute path of entry after action (`nil` for "delete" action).
---@tag MiniFiles-events

--- Common configuration examples ~
---
--- # Toggle explorer ~
---
--- Use a combination of |MiniFiles.open()| and |MiniFiles.close()|: >
---
---   local minifiles_toggle = function(...)
---     if not MiniFiles.close() then MiniFiles.open(...) end
---   end
---
--- # Customize windows ~
---
--- Create an autocommand for `MiniFilesWindowOpen` event: >
---
---   vim.api.nvim_create_autocmd('User', {
---     pattern = 'MiniFilesWindowOpen',
---     callback = function(args)
---       local win_id = args.data.win_id
---
---       -- Customize window-local settings
---       vim.wo[win_id].winblend = 50
---       vim.api.nvim_win_set_config(win_id, { border = 'double' })
---     end,
---   })
---
--- # Customize icons ~
---
--- Use different directory icon: >
---
---   local my_prefix = function(fs_entry)
---     if fs_entry.fs_type == 'directory' then
---       -- NOTE: it is usually a good idea to use icon followed by space
---       return ' ', 'MiniFilesDirectory'
---     end
---     return MiniFiles.default_prefix(fs_entry)
---   end
---
---   require('mini.files').setup({ content = { prefix = my_prefix } })
---
--- Show no icons: >
---
---   require('mini.files').setup({ content = { prefix = function() end } })
---
--- # Create mapping to show/hide dot-files ~
---
--- Create an autocommand for `MiniFilesBufferCreate` event which calls
--- |MiniFiles.refresh()| with explicit `content.filter` functions: >
---
---   local show_dotfiles = true
---
---   local filter_show = function(fs_entry) return true end
---
---   local filter_hide = function(fs_entry)
---     return not vim.startswith(fs_entry.name, '.')
---   end
---
---   local toggle_dotfiles = function()
---     show_dotfiles = not show_dotfiles
---     local new_filter = show_dotfiles and filter_show or filter_hide
---     MiniFiles.refresh({ content = { filter = new_filter } })
---   end
---
---   vim.api.nvim_create_autocmd('User', {
---     pattern = 'MiniFilesBufferCreate',
---     callback = function(args)
---       local buf_id = args.data.buf_id
---       -- Tweak left-hand side of mapping to your liking
---       vim.keymap.set('n', 'g.', toggle_dotfiles, { buffer = buf_id })
---     end,
---   })
---
--- # Create mappings to modify target window via split ~
---
--- Combine |MiniFiles.get_target_window()| and |MiniFiles.set_target_window()|: >
---
---   local map_split = function(buf_id, lhs, direction)
---     local rhs = function()
---       -- Make new window and set it as target
---       local new_target_window
---       vim.api.nvim_win_call(MiniFiles.get_target_window(), function()
---         vim.cmd(direction .. ' split')
---         new_target_window = vim.api.nvim_get_current_win()
---       end)
---
---       MiniFiles.set_target_window(new_target_window)
---     end
---
---     -- Adding `desc` will result into `show_help` entries
---     local desc = 'Split ' .. direction
---     vim.keymap.set('n', lhs, rhs, { buffer = buf_id, desc = desc })
---   end
---
---   vim.api.nvim_create_autocmd('User', {
---     pattern = 'MiniFilesBufferCreate',
---     callback = function(args)
---       local buf_id = args.data.buf_id
---       -- Tweak keys to your liking
---       map_split(buf_id, 'gs', 'belowright horizontal')
---       map_split(buf_id, 'gv', 'belowright vertical')
---     end,
---   })
---
--- # Create mapping to set current working directory ~
---
--- Use |MiniFiles.get_fs_entry()| together with |vim.fs.dirname()|: >
---
---   local files_set_cwd = function(path)
---     -- Works only if cursor is on the valid file system entry
---     local cur_entry_path = MiniFiles.get_fs_entry().path
---     local cur_directory = vim.fs.dirname(cur_entry_path)
---     vim.fn.chdir(cur_directory)
---   end
---
---   vim.api.nvim_create_autocmd('User', {
---     pattern = 'MiniFilesBufferCreate',
---     callback = function(args)
---       vim.keymap.set('n', 'g~', files_set_cwd, { buffer = args.data.buf_id })
---     end,
---   })
---@tag MiniFiles-examples

---@diagnostic disable:luadoc-miss-type-name
---@alias __minifiles_fs_entry_data_fields   - <fs_type> `(string)` - one of "file" or "directory".
---   - <name> `(string)` - basename of an entry (including extension).
---   - <path> `(string)` - full path of an entry.

---@diagnostic disable:undefined-field
---@diagnostic disable:discard-returns
---@diagnostic disable:unused-local
---@diagnostic disable:cast-local-type

-- Module definition ==========================================================
local MiniFiles = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |MiniFiles.config|.
---
---@usage `require('mini.files').setup({})` (replace `{}` with your `config` table).
MiniFiles.setup = function(config)
  -- Export module
  _G.MiniFiles = MiniFiles

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  -- Define behavior
  H.create_autocommands(config)

  -- Create default highlighting
  H.create_default_hl()
end

--stylua: ignore
--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # Content ~
---
--- `content.filter` is a predicate which takes file system entry data as input
--- and returns `true`-ish value if it should be shown.
--- Uses |MiniFiles.default_filter()| by default.
---
--- A file system entry data is a table with the following fields:
--- __minifiles_fs_entry_data_fields
---
--- `content.prefix` describes what text (prefix) to show to the left of file
--- system entry name (if any) and how to highlight it. It also takes file
--- system entry data as input and returns tuple of text and highlight group
--- name to be used to highlight prefix. See |MiniFiles-examples| for common
--- examples of how to use it.
--- Note: due to how lines are parsed to detect user edits for file system
--- manipulation, output of `content.prefix` should not contain `/` character.
--- Uses |MiniFiles.default_prefix()| by default.
---
--- `content.sort` describes in which order directory entries should be shown
--- in directory buffer. Takes as input and returns as output an array of file
--- system entry data. Note: technically, it can be used to filter and modify
--- its elements as well.
--- Uses |MiniFiles.default_sort()| by default.
---
--- # Mappings ~
---
--- `mappings` table can be used to customize buffer-local mappings created in each
--- directory buffer for built-in actions. Entry name corresponds to the function
--- name of the action, value - right hand side of the mapping. Supply empty
--- string to not create a particular mapping.
---
--- Default mappings are mostly designed for consistent navigation experience.
--- Here are some alternatives: >
---
---   -- Close explorer after opening file with `l`
---   mappings = {
---     go_in = 'L',
---     go_in_plus = 'l',
---   }
---
---   -- Don't use `h`/`l` for easier cursor navigation during text edit
---   mappings = {
---     go_in = 'L',
---     go_in_plus = '',
---     go_out = 'H',
---     go_out_plus = '',
---   }
---
--- # Options ~
---
--- `options.use_as_default_explorer` is a boolean indicating whether this module
--- should be used as a default file explorer for editing directories (instead of
--- |netrw| by default).
---
--- `options.permanent_delete` is a boolean indicating whether to perform
--- permanent delete or move into special trash directory.
--- This is a module-specific variant of "remove to trash".
--- Target directory is 'mini.files/trash' inside standard path of Neovim data
--- directory (execute `:echo stdpath('data')` to see its path in your case).
---
--- # Windows ~
---
--- `windows.max_number` is a maximum number of windows allowed to be open
--- simultaneously. For example, use value 1 to always show single window.
--- There is no constraint by default.
---
--- `windows.preview` is a boolean indicating whether to show preview of
--- file/directory under cursor. Note: it is shown with highlighting if Neovim
--- version is sufficient and file is small enough (less than 1K bytes per line
--- or 1M bytes in total).
---
--- `windows.width_focus` and `windows.width_nofocus` are number of columns used
--- as `width` for focused and non-focused windows respectively.
MiniFiles.config = {
  -- Customization of shown content
  content = {
    -- Predicate for which file system entries to show
    filter = nil,
    -- What prefix to show to the left of file system entry
    prefix = nil,
    -- In which order to show file system entries
    sort = nil,
  },

  -- Module mappings created only inside explorer.
  -- Use `''` (empty string) to not create one.
  mappings = {
    close       = 'q',
    go_in       = 'l',
    go_in_plus  = 'L',
    go_out      = 'h',
    go_out_plus = 'H',
    reset       = '<BS>',
    reveal_cwd  = '@',
    show_help   = 'g?',
    synchronize = '=',
    trim_left   = '<',
    trim_right  = '>',
  },

  -- General options
  options = {
    -- Whether to delete permanently or move into module-specific trash
    permanent_delete = true,
    -- Whether to use for editing directories
    use_as_default_explorer = true,
  },

  -- Customization of explorer windows
  windows = {
    -- Maximum number of windows to show side by side
    max_number = math.huge,
    -- Whether to show preview of file/directory under cursor
    preview = false,
    -- Width of focused window
    width_focus = 50,
    -- Width of non-focused window
    width_nofocus = 15,
    -- Width of preview window
    width_preview = 25,
  },
}
--minidoc_afterlines_end

--- Open file explorer
---
--- Common ways to use this function:
---
--- - `MiniFiles.open()` - open current working directory in a last used state.
---
--- - `MiniFiles.open(nil, false)` - fresh explorer in current working directory.
---
--- - `MiniFiles.open(vim.api.nvim_buf_get_name(0))` - open directory of current
---   file (in a last used state) with focus on that file.
---
--- - `MiniFiles.open(vim.api.nvim_buf_get_name(0), false)` - fresh explorer in
---   directory of current file.
---
--- - `MiniFiles.open(MiniFiles.get_latest_path())` - open last used `path`
---   (per tabpage). Current working directory for the first time.
---
---@param path string|nil A valid file system path used as anchor.
---   If it is a path to directory, used directly.
---   If it is a path to file, its parent directory is used as anchor while
---   explorer will focus on the supplied file.
---   Default: path of |current-directory|.
---@param use_latest boolean|nil Whether to load explorer state from history
---   (based on the supplied anchor path). Default: `true`.
---@param opts table|nil Table of options overriding |MiniFiles.config| and
---   `vim.b.minifiles_config` for this particular explorer session.
MiniFiles.open = function(path, use_latest, opts)
  -- Validate path: allow only valid file system path
  path = H.fs_full_path(path or vim.fn.getcwd())

  local fs_type = H.fs_get_type(path)
  if fs_type == nil then H.error('`path` is not a valid path ("' .. path .. '")') end

  -- - Allow file path to use its parent while focusing on file
  local entry_name
  if fs_type == 'file' then
    path, entry_name = H.fs_get_parent(path), H.fs_get_basename(path)
  end

  -- Validate rest of the arguments
  if use_latest == nil then use_latest = true end

  -- Properly close possibly opened in the tabpage explorer
  local did_close = MiniFiles.close()
  if did_close == false then return end

  -- Get explorer to open
  local explorer
  if use_latest then explorer = H.explorer_path_history[path] end
  explorer = explorer or H.explorer_new(path)

  -- Update explorer data. Don't use current explorer's data to allow more
  -- interactive config change by modifying global/local configs.
  explorer.opts = H.normalize_opts(nil, opts)
  explorer.target_window = vim.api.nvim_get_current_win()

  -- Possibly focus on file entry
  explorer = H.explorer_focus_on_entry(explorer, path, entry_name)

  -- Refresh and register as opened
  H.explorer_refresh(explorer)

  -- Register latest used path
  H.latest_paths[vim.api.nvim_get_current_tabpage()] = path

  -- Track lost focus
  H.explorer_track_lost_focus()
end

--- Refresh explorer
---
--- Notes:
--- - If in `opts` at least one of `content` entry is not `nil`, all directory
---   buffers are forced to update.
---
---@param opts table|nil Table of options to update.
MiniFiles.refresh = function(opts)
  local explorer = H.explorer_get()
  if explorer == nil then return end

  -- Decide whether buffers should be forcefully updated
  local content_opts = (opts or {}).content or {}
  local force_update = #vim.tbl_keys(content_opts) > 0

  -- Confirm refresh if there is modified buffer
  if force_update then force_update = H.explorer_confirm_modified(explorer, 'buffer updates') end

  -- Respect explorer local options supplied inside its `open()` call but give
  -- current `opts` higher precedence
  explorer.opts = H.normalize_opts(explorer.opts, opts)

  H.explorer_refresh(explorer, { force_update = force_update })
end

--- Synchronize explorer
---
--- - Parse user edits in directory buffers.
--- - Convert edits to file system actions and apply them after confirmation.
--- - Update all directory buffers with the most relevant file system information.
---   Can be used without user edits to account for external file system changes.
MiniFiles.synchronize = function()
  local explorer = H.explorer_get()
  if explorer == nil then return end

  -- Parse and apply file system operations
  local fs_actions = H.explorer_compute_fs_actions(explorer)
  if fs_actions ~= nil and H.fs_actions_confirm(fs_actions) then H.fs_actions_apply(fs_actions, explorer.opts) end

  H.explorer_refresh(explorer, { force_update = true })
end

--- Reset explorer
---
--- - Show single window focused on anchor directory (which was used as first
---   argument for |MiniFiles.open()|).
--- - Reset all tracked directory cursors to point at first entry.
MiniFiles.reset = function()
  local explorer = H.explorer_get()
  if explorer == nil then return end

  -- Reset branch
  explorer.branch = { explorer.anchor }
  explorer.depth_focus = 1

  -- Reset views
  for _, view in pairs(explorer.views) do
    view.cursor = { 1, 0 }
  end

  -- Skip update cursors, as they are already set
  H.explorer_refresh(explorer, { skip_update_cursor = true })
end

--- Close explorer
---
---@return boolean|nil Whether closing was done or `nil` if there was nothing to close.
MiniFiles.close = function()
  local explorer = H.explorer_get()
  if explorer == nil then return nil end

  -- Stop tracking lost focus
  pcall(vim.loop.timer_stop, H.timers.focus)

  -- Confirm close if there is modified buffer
  if not H.explorer_confirm_modified(explorer, 'close') then return false end

  -- Focus on target window
  explorer = H.explorer_ensure_target_window(explorer)
  -- - Use `pcall()` because window might still be invalid
  pcall(vim.api.nvim_set_current_win, explorer.target_window)

  -- Update currently shown cursors
  explorer = H.explorer_update_cursors(explorer)

  -- Close shown explorer windows
  for i, win_id in pairs(explorer.windows) do
    H.window_close(win_id)
    explorer.windows[i] = nil
  end

  -- Close possibly visible help window
  for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    if vim.bo[buf_id].filetype == 'minifiles-help' then vim.api.nvim_win_close(win_id, true) end
  end

  -- Invalidate views
  for path, view in pairs(explorer.views) do
    explorer.views[path] = H.view_invalidate_buffer(H.view_encode_cursor(view))
  end

  -- Update histories and unmark as opened
  local tabpage_id, anchor = vim.api.nvim_get_current_tabpage(), explorer.anchor
  H.explorer_path_history[anchor] = explorer
  H.opened_explorers[tabpage_id] = nil

  -- Return `true` indicating success in closing
  return true
end

--- Go in entry under cursor
---
--- Depends on entry under cursor:
--- - If directory, focus on it in the window to the right.
--- - If file, open it in the window which was current during |MiniFiles.open()|.
---   Explorer is not closed after that.
---
---@param opts Options. Possible fields:
---   - <close_on_file> `(boolean)` - whether to close explorer after going
---     inside a file. Powers the `go_in_plus` mapping.
---     Default: `false`.
MiniFiles.go_in = function(opts)
  local explorer = H.explorer_get()
  if explorer == nil then return end

  opts = vim.tbl_deep_extend('force', { close_on_file = false }, opts or {})

  local should_close = opts.close_on_file
  if should_close then
    local fs_entry = MiniFiles.get_fs_entry()
    should_close = fs_entry ~= nil and fs_entry.fs_type == 'file'
  end

  local cur_line = vim.fn.line('.')
  explorer = H.explorer_go_in_range(explorer, vim.api.nvim_get_current_buf(), cur_line, cur_line)

  H.explorer_refresh(explorer)

  if should_close then MiniFiles.close() end
end

--- Go out to parent directory
---
--- - Focus on window to the left showing parent of current directory.
MiniFiles.go_out = function()
  local explorer = H.explorer_get()
  if explorer == nil then return end

  if explorer.depth_focus == 1 then
    explorer = H.explorer_open_root_parent(explorer)
  else
    explorer.depth_focus = explorer.depth_focus - 1
  end

  H.explorer_refresh(explorer)
end

--- Trim left part of branch
---
--- - Remove all branch paths to the left of currently focused one. This also
---   results into current window becoming the most left one.
MiniFiles.trim_left = function()
  local explorer = H.explorer_get()
  if explorer == nil then return end

  explorer = H.explorer_trim_branch_left(explorer)
  H.explorer_refresh(explorer)
end

--- Trim right part of branch
---
--- - Remove all branch paths to the right of currently focused one. This also
---   results into current window becoming the most right one.
MiniFiles.trim_right = function()
  local explorer = H.explorer_get()
  if explorer == nil then return end

  explorer = H.explorer_trim_branch_right(explorer)
  H.explorer_refresh(explorer)
end

--- Reveal current working directory
---
--- - Prepend branch with parent paths until current working directory is reached.
---   Do nothing if not inside it.
MiniFiles.reveal_cwd = function()
  local explorer = H.explorer_get()
  if explorer == nil then return end

  local cwd = H.fs_full_path(vim.fn.getcwd())
  local cwd_ancestor_pattern = string.format('^%s/.', vim.pesc(cwd))
  while explorer.branch[1]:find(cwd_ancestor_pattern) ~= nil do
    -- Add parent to branch
    local parent, name = H.fs_get_parent(explorer.branch[1]), H.fs_get_basename(explorer.branch[1])
    table.insert(explorer.branch, 1, parent)

    explorer.depth_focus = explorer.depth_focus + 1

    -- Set cursor on child entry
    local parent_view = explorer.views[parent] or {}
    parent_view.cursor = name
    explorer.views[parent] = parent_view
  end

  H.explorer_refresh(explorer)
end

--- Show help window
---
--- - Open window with helpful information about currently shown explorer and
---   focus on it. To close it, press `q`.
MiniFiles.show_help = function()
  local explorer = H.explorer_get()
  if explorer == nil then return end

  local buf_id = vim.api.nvim_get_current_buf()
  if not H.is_opened_buffer(buf_id) then return end

  H.explorer_show_help(buf_id, vim.api.nvim_get_current_win())
end

--- Get file system entry data
---
---@param buf_id number|nil Buffer identifier of valid directory buffer.
---   Default: current buffer.
---@param line number|nil Line number of entry for which to return information.
---   Default: cursor line.
---
---@return table|nil Table of file system entry data with the following fields:
--- __minifiles_fs_entry_data_fields
---
--- Returns `nil` if there is no proper file system entry path at the line.
MiniFiles.get_fs_entry = function(buf_id, line)
  buf_id = H.validate_opened_buffer(buf_id)
  line = H.validate_line(buf_id, line)

  local path_id = H.match_line_path_id(H.get_bufline(buf_id, line))
  if path_id == nil then return nil end

  local path = H.path_index[path_id]
  return { fs_type = H.fs_get_type(path), name = H.fs_get_basename(path), path = path }
end

--- Get target window
---
---@return number|nil Window identifier inside which file will be opened or
---   `nil` if no explorer is opened.
MiniFiles.get_target_window = function()
  local explorer = H.explorer_get()
  if explorer == nil then return end

  explorer = H.explorer_ensure_target_window(explorer)
  return explorer.target_window
end

--- Set target window
---
---@param win_id number Window identifier inside which file will be opened.
MiniFiles.set_target_window = function(win_id)
  if not H.is_valid_win(win_id) then H.error('`win_id` should be valid window identifier.') end

  local explorer = H.explorer_get()
  if explorer == nil then return end

  explorer.target_window = win_id
end

--- Get latest used anchor path
---
--- Note: if latest used `path` argument for |MiniFiles.open()| was for file,
--- this will return its parent (as it was used as anchor path).
MiniFiles.get_latest_path = function() return H.latest_paths[vim.api.nvim_get_current_tabpage()] end

--- Default filter of file system entries
---
--- Currently does not filter anything out.
---
---@param fs_entry table Table with the following fields:
--- __minifiles_fs_entry_data_fields
---
---@return boolean Always `true`.
MiniFiles.default_filter = function(fs_entry) return true end

--- Default prefix of file system entries
---
--- - For directory return fixed icon and 'MiniFilesDirectory' highlight group.
--- - For file try to use `get_icon()` from 'nvim-tree/nvim-web-devicons'.
---   If missing, return fixed icon and 'MiniFilesFile' highlight group.
---
---@param fs_entry table Table with the following fields:
--- __minifiles_fs_entry_data_fields
---
---@return ... Icon and highlight group name. For more details, see |MiniFiles.config|
---   and |MiniFiles-examples|.
MiniFiles.default_prefix = function(fs_entry)
  if fs_entry.fs_type == 'directory' then return ' ', 'MiniFilesDirectory' end
  local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
  if not has_devicons then return ' ', 'MiniFilesFile' end

  local icon, hl = devicons.get_icon(fs_entry.name, nil, { default = false })
  return (icon or '') .. ' ', hl or 'MiniFilesFile'
end

--- Default sort of file system entries
---
--- Sort directories and files separately (alphabetically ignoring case) and
--- put directories first.
---
---@param fs_entries table Array of file system entry data.
---   Each one is a table with the following fields:
--- __minifiles_fs_entry_data_fields
---
---@return table Sorted array of file system entries.
MiniFiles.default_sort = function(fs_entries)
  -- Sort ignoring case
  local res = vim.tbl_map(
    function(x)
      return {
        fs_type = x.fs_type,
        name = x.name,
        path = x.path,
        lower_name = x.name:lower(),
        is_dir = x.fs_type == 'directory',
      }
    end,
    fs_entries
  )

  -- Sort based on default order
  table.sort(res, H.compare_fs_entries)

  return vim.tbl_map(function(x) return { name = x.name, fs_type = x.fs_type, path = x.path } end, res)
end

-- Helper data ================================================================
-- Module default config
H.default_config = vim.deepcopy(MiniFiles.config)

-- Namespaces
H.ns_id = {
  highlight = vim.api.nvim_create_namespace('MiniFilesHighlight'),
}

-- Timers
H.timers = {
  focus = vim.loop.new_timer(),
}

-- Index of all visited files
H.path_index = {}

-- History of explorers per root directory
H.explorer_path_history = {}

-- Register of opened explorers per tabpage
H.opened_explorers = {}

-- Register of latest used paths per tabpage
H.latest_paths = {}

-- Register of opened buffer data for quick access. Tables per buffer id:
-- - <path> - path which contents this buffer displays.
-- - <win_id> - id of window this buffer is shown. Can be `nil`.
-- - <n_modified> - number of modifications since last update from this module.
--   Values bigger than 0 can be treated as if buffer was modified by user.
--   It uses number instead of boolean is to overcome `TextChanged` event on
--   initial `buf_set_lines` (`noautocmd` doesn't quick work for this event).
H.opened_buffers = {}

-- File system information
H.is_windows = vim.loop.os_uname().sysname == 'Windows_NT'

-- Register table to decide whether certain autocmd events should be triggered
H.block_event_trigger = {}

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({
    content = { config.content, 'table' },
    mappings = { config.mappings, 'table' },
    options = { config.options, 'table' },
    windows = { config.windows, 'table' },
  })

  vim.validate({
    ['content.filter'] = { config.content.filter, 'function', true },
    ['content.prefix'] = { config.content.prefix, 'function', true },
    ['content.sort'] = { config.content.sort, 'function', true },

    ['mappings.close'] = { config.mappings.close, 'string' },
    ['mappings.go_in'] = { config.mappings.go_in, 'string' },
    ['mappings.go_in_plus'] = { config.mappings.go_in_plus, 'string' },
    ['mappings.go_out'] = { config.mappings.go_out, 'string' },
    ['mappings.go_out_plus'] = { config.mappings.go_out_plus, 'string' },
    ['mappings.reset'] = { config.mappings.reset, 'string' },
    ['mappings.reveal_cwd'] = { config.mappings.reveal_cwd, 'string' },
    ['mappings.show_help'] = { config.mappings.show_help, 'string' },
    ['mappings.synchronize'] = { config.mappings.synchronize, 'string' },
    ['mappings.trim_left'] = { config.mappings.trim_left, 'string' },
    ['mappings.trim_right'] = { config.mappings.trim_right, 'string' },

    ['options.use_as_default_explorer'] = { config.options.use_as_default_explorer, 'boolean' },
    ['options.permanent_delete'] = { config.options.permanent_delete, 'boolean' },

    ['windows.max_number'] = { config.windows.max_number, 'number' },
    ['windows.preview'] = { config.windows.preview, 'boolean' },
    ['windows.width_focus'] = { config.windows.width_focus, 'number' },
    ['windows.width_nofocus'] = { config.windows.width_nofocus, 'number' },
    ['windows.width_preview'] = { config.windows.width_preview, 'number' },
  })

  return config
end

H.apply_config = function(config) MiniFiles.config = config end

H.create_autocommands = function(config)
  local augroup = vim.api.nvim_create_augroup('MiniFiles', {})

  local au = function(event, pattern, callback, desc)
    vim.api.nvim_create_autocmd(event, { group = augroup, pattern = pattern, callback = callback, desc = desc })
  end

  au('VimResized', '*', MiniFiles.refresh, 'Refresh on resize')

  if config.options.use_as_default_explorer then
    -- Stop 'netrw' from showing. Needs `VimEnter` event autocommand if
    -- this is called prior 'netrw' is set up
    vim.cmd('silent! autocmd! FileExplorer *')
    vim.cmd('autocmd VimEnter * ++once silent! autocmd! FileExplorer *')

    au('BufEnter', '*', H.track_dir_edit, 'Track directory edit')
  end
end

--stylua: ignore
H.create_default_hl = function()
  local hi = function(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end

  hi('MiniFilesBorder',         { link = 'FloatBorder' })
  hi('MiniFilesBorderModified', { link = 'DiagnosticFloatingWarn' })
  hi('MiniFilesCursorLine',     { link = 'CursorLine' })
  hi('MiniFilesDirectory',      { link = 'Directory'   })
  hi('MiniFilesFile',           {})
  hi('MiniFilesNormal',         { link = 'NormalFloat' })
  hi('MiniFilesTitle',          { link = 'FloatTitle'  })
  hi('MiniFilesTitleFocused',   { link = 'FloatTitle' })
end

H.get_config = function(config)
  return vim.tbl_deep_extend('force', MiniFiles.config, vim.b.minifiles_config or {}, config or {})
end

H.normalize_opts = function(explorer_opts, opts)
  opts = vim.tbl_deep_extend('force', H.get_config(), explorer_opts or {}, opts or {})
  opts.content.filter = opts.content.filter or MiniFiles.default_filter
  opts.content.prefix = opts.content.prefix or MiniFiles.default_prefix
  opts.content.sort = opts.content.sort or MiniFiles.default_sort

  return opts
end

-- Autocommands ---------------------------------------------------------------
H.track_dir_edit = function(data)
  -- Make early returns
  if vim.api.nvim_get_current_buf() ~= data.buf then return end

  if vim.b.minifiles_processed_dir then return vim.api.nvim_buf_delete(0, { force = true }) end

  local path = vim.api.nvim_buf_get_name(0)
  if vim.fn.isdirectory(path) ~= 1 then return end

  -- Make directory buffer disappear when it is not needed
  vim.bo.bufhidden = 'wipe'
  vim.b.minifiles_processed_dir = true

  -- Open directory without history
  vim.schedule(function() MiniFiles.open(path, false) end)
end

-- Explorers ------------------------------------------------------------------
---@class Explorer
---
---@field branch table Array of absolute directory paths from parent to child.
---   Its ids are called depth.
---@field depth_focus number Depth to focus.
---@field views table Views for paths. Each view is a table with:
---   - <buf_id> where to show directory content.
---   - <cursor> to position cursor; can be:
---       - `{ line, col }` table to set cursor when buffer changes window.
---       - `entry_name` string entry name to find inside directory buffer.
---   - <children_path_ids> - array with children path ids present during
---     latest directory update.
---@field windows table Array of currently opened window ids (left to right).
---@field anchor string Anchor directory of the explorer. Used as index in
---   history and for `reset()` operation.
---@field target_window number Id of window in which files will be opened.
---@field opts table Options used for this particular explorer.
---@field is_corrupted boolean Whether this particular explorer can not be
---   normalized and should be closed.
---@private
H.explorer_new = function(path)
  return {
    branch = { path },
    depth_focus = 1,
    views = {},
    windows = {},
    anchor = path,
    target_window = vim.api.nvim_get_current_win(),
    opts = {},
  }
end

H.explorer_get = function(tabpage_id)
  tabpage_id = tabpage_id or vim.api.nvim_get_current_tabpage()
  local res = H.opened_explorers[tabpage_id]

  if H.explorer_is_visible(res) then return res end

  H.opened_explorers[tabpage_id] = nil
  return nil
end

H.explorer_is_visible = function(explorer)
  if explorer == nil then return nil end
  for _, win_id in ipairs(explorer.windows) do
    if H.is_valid_win(win_id) then return true end
  end
  return false
end

H.explorer_refresh = function(explorer, opts)
  explorer = H.explorer_normalize(explorer)
  if explorer.is_corrupted then
    -- Make sure that same explorer can be opened later from history
    explorer.is_corrupted = false
    MiniFiles.close()
    return
  end
  if #explorer.branch == 0 then return end
  opts = opts or {}

  -- Update cursor data in shown views. Do this prior to buffer updates for
  -- cursors to "stick" to current items.
  if not opts.skip_update_cursor then explorer = H.explorer_update_cursors(explorer) end

  -- Possibly force content updates on all explorer buffers. Doing it for *all*
  -- of them and not only on modified once to allow synch outside changes.
  if opts.force_update then
    for path, view in pairs(explorer.views) do
      -- Encode cursors to allow them to "stick" to current entry
      view = H.view_encode_cursor(view)
      view.children_path_ids = H.buffer_update(view.buf_id, path, explorer.opts)
      explorer.views[path] = view
    end
  end

  -- Make sure that cursors point at paths to their right.
  -- NOTE: Doing this here and not relying on `CursorMoved` autocommand ensures
  -- that no more windows are opened than necessary (reduces flickering).
  for depth = 1, #explorer.branch do
    explorer = H.explorer_sync_cursor_and_branch(explorer, depth)
  end

  -- Unregister windows from showed buffers, as they might get outdated
  for _, win_id in ipairs(explorer.windows) do
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    H.opened_buffers[buf_id].win_id = nil
  end

  -- Compute depth range which is possible to show in current window
  local depth_range = H.compute_visible_depth_range(explorer, explorer.opts)

  -- Refresh window for every target depth keeping track of position column
  local cur_win_col, cur_win_count = 0, 0
  for depth = depth_range.from, depth_range.to do
    cur_win_count = cur_win_count + 1
    local cur_width = H.explorer_refresh_depth_window(explorer, depth, cur_win_count, cur_win_col)

    -- Add 2 to account for left and right borders
    cur_win_col = cur_win_col + cur_width + 2
  end

  -- Close possibly opened window that don't fit (like after `VimResized`)
  for depth = cur_win_count + 1, #explorer.windows do
    H.window_close(explorer.windows[depth])
    explorer.windows[depth] = nil
  end

  -- Focus on proper window
  local win_focus_count = explorer.depth_focus - depth_range.from + 1
  local win_id_focused = explorer.windows[win_focus_count]
  H.window_focus(win_id_focused)

  -- Register as currently opened
  local tabpage_id = vim.api.nvim_win_get_tabpage(win_id_focused)
  H.opened_explorers[tabpage_id] = explorer

  return explorer
end

H.explorer_track_lost_focus = function()
  local track = vim.schedule_wrap(function()
    local ft = vim.bo.filetype
    if ft == 'minifiles' or ft == 'minifiles-help' then return end
    local cur_win_id = vim.api.nvim_get_current_win()
    MiniFiles.close()
    pcall(vim.api.nvim_set_current_win, cur_win_id)
  end)
  H.timers.focus:start(1000, 1000, track)
end

H.explorer_normalize = function(explorer)
  -- Ensure that all paths from branch are valid present paths
  local norm_branch = {}
  for _, path in ipairs(explorer.branch) do
    if not H.fs_is_present_path(path) then break end
    table.insert(norm_branch, path)
  end

  local cur_max_depth = #norm_branch

  explorer.branch = norm_branch
  explorer.depth_focus = math.min(math.max(explorer.depth_focus, 1), cur_max_depth)

  -- Close all unnecessary windows
  for i = cur_max_depth + 1, #explorer.windows do
    H.window_close(explorer.windows[i])
    explorer.windows[i] = nil
  end

  -- Compute if explorer is corrupted and should not operate further
  for _, win_id in pairs(explorer.windows) do
    if not H.is_valid_win(win_id) then explorer.is_corrupted = true end
  end

  return explorer
end

H.explorer_sync_cursor_and_branch = function(explorer, depth)
  -- Compute helper data while making early returns
  if #explorer.branch < depth then return explorer end

  local path, path_to_right = explorer.branch[depth], explorer.branch[depth + 1]
  local view = explorer.views[path]
  if view == nil then return explorer end

  local buf_id, cursor = view.buf_id, view.cursor
  if cursor == nil then return explorer end

  -- Compute if path at cursor and path to the right are equal (in sync)
  local cursor_path
  if type(cursor) == 'table' and H.is_valid_buf(buf_id) then
    local l = H.get_bufline(buf_id, cursor[1])
    cursor_path = H.path_index[H.match_line_path_id(l)]
  elseif type(cursor) == 'string' then
    cursor_path = H.fs_child_path(path, cursor)
  else
    return explorer
  end

  if cursor_path == path_to_right then return explorer end

  -- Trim branch if cursor path is not in sync with path to the right
  for i = depth + 1, #explorer.branch do
    explorer.branch[i] = nil
  end
  explorer.depth_focus = math.min(explorer.depth_focus, #explorer.branch)

  -- Show preview to the right of current buffer if needed
  local show_preview = explorer.opts.windows.preview
  local path_is_present = type(cursor_path) == 'string' and H.fs_is_present_path(cursor_path)
  local is_cur_buf = buf_id == vim.api.nvim_get_current_buf()
  if show_preview and path_is_present and is_cur_buf then table.insert(explorer.branch, cursor_path) end

  return explorer
end

H.explorer_go_in_range = function(explorer, buf_id, from_line, to_line)
  -- Compute which entries to go in: all files and only last directory
  local files, path, line = {}, nil, nil
  for i = from_line, to_line do
    local fs_entry = MiniFiles.get_fs_entry(buf_id, i) or {}
    if fs_entry.fs_type == 'file' then table.insert(files, fs_entry.path) end
    if fs_entry.fs_type == 'directory' then
      path, line = fs_entry.path, i
    end
  end

  for _, file_path in ipairs(files) do
    explorer = H.explorer_open_file(explorer, file_path)
  end

  if path ~= nil then
    explorer = H.explorer_open_directory(explorer, path, explorer.depth_focus + 1)

    -- Ensure that cursor points to the directory in current window (can be not
    -- the case if cursor is not on the actually opened directory)
    local win_id = H.opened_buffers[buf_id].win_id
    if H.is_valid_win(win_id) then vim.api.nvim_win_set_cursor(win_id, { line, 0 }) end
  end

  return explorer
end

H.explorer_focus_on_entry = function(explorer, path, entry_name)
  if entry_name == nil then return explorer end

  -- Set focus on directory. Reset if it is not in current branch.
  explorer.depth_focus = H.explorer_get_path_depth(explorer, path)
  if explorer.depth_focus == nil then
    explorer.branch, explorer.depth_focus = { path }, 1
  end

  -- Set cursor on entry
  local path_view = explorer.views[path] or {}
  path_view.cursor = entry_name
  explorer.views[path] = path_view

  return explorer
end

H.explorer_compute_fs_actions = function(explorer)
  -- Compute differences
  local fs_diffs = {}
  for _, view in pairs(explorer.views) do
    local dir_fs_diff = H.buffer_compute_fs_diff(view.buf_id, view.children_path_ids)
    if #dir_fs_diff > 0 then vim.list_extend(fs_diffs, dir_fs_diff) end
  end
  if #fs_diffs == 0 then return nil end

  -- Convert differences into actions
  local create, delete_map, rename, move, raw_copy = {}, {}, {}, {}, {}

  -- - Differentiate between create, delete, and copy
  for _, diff in ipairs(fs_diffs) do
    if diff.from == nil then
      table.insert(create, diff.to)
    elseif diff.to == nil then
      delete_map[diff.from] = true
    else
      table.insert(raw_copy, diff)
    end
  end

  -- - Possibly narrow down copy action into move or rename:
  --   `delete + copy` is `rename` if in same directory and `move` otherwise
  local copy = {}
  for _, diff in pairs(raw_copy) do
    if delete_map[diff.from] then
      if H.fs_get_parent(diff.from) == H.fs_get_parent(diff.to) then
        table.insert(rename, diff)
      else
        table.insert(move, diff)
      end

      -- NOTE: Can't use `delete` as array here in order for path to be moved
      -- or renamed only single time
      delete_map[diff.from] = nil
    else
      table.insert(copy, diff)
    end
  end

  return { create = create, delete = vim.tbl_keys(delete_map), copy = copy, rename = rename, move = move }
end

H.explorer_update_cursors = function(explorer)
  for _, win_id in ipairs(explorer.windows) do
    if H.is_valid_win(win_id) then
      local buf_id = vim.api.nvim_win_get_buf(win_id)
      local path = H.opened_buffers[buf_id].path
      explorer.views[path].cursor = vim.api.nvim_win_get_cursor(win_id)
    end
  end

  return explorer
end

H.explorer_refresh_depth_window = function(explorer, depth, win_count, win_col)
  local path = explorer.branch[depth]
  local views, windows, opts = explorer.views, explorer.windows, explorer.opts

  -- Prepare target view
  local view = views[path] or {}
  view = H.view_ensure_proper(view, path, opts)
  views[path] = view

  -- Compute width based on window role
  local win_is_focused = depth == explorer.depth_focus
  local win_is_preview = opts.windows.preview and (depth == (explorer.depth_focus + 1))
  local cur_width = win_is_focused and opts.windows.width_focus
    or (win_is_preview and opts.windows.width_preview or opts.windows.width_nofocus)

  -- Create relevant window config
  local config = {
    col = win_col,
    height = vim.api.nvim_buf_line_count(view.buf_id),
    width = cur_width,
    -- Use shortened full path in left most window
    title = win_count == 1 and H.fs_shorten_path(H.fs_full_path(path)) or H.fs_get_basename(path),
  }

  -- Prepare and register window
  local win_id = windows[win_count]
  if not H.is_valid_win(win_id) then
    H.window_close(win_id)
    win_id = H.window_open(view.buf_id, config)
    windows[win_count] = win_id
  end

  H.window_update(win_id, config)

  -- Show view in window
  H.window_set_view(win_id, view)

  -- Update explorer data
  explorer.views = views
  explorer.windows = windows

  -- Return width of current window to keep track of window column
  return cur_width
end

H.explorer_get_path_depth = function(explorer, path)
  for depth, depth_path in pairs(explorer.branch) do
    if path == depth_path then return depth end
  end
end

H.explorer_confirm_modified = function(explorer, action_name)
  local has_modified = false
  for _, view in pairs(explorer.views) do
    if H.is_modified_buffer(view.buf_id) then has_modified = true end
  end

  -- Exit if nothing to confirm
  if not has_modified then return true end

  local msg = string.format('There is at least one modified buffer\n\nConfirm %s without synchronization?', action_name)
  local confirm_res = vim.fn.confirm(msg, '&Yes\n&No', 1, 'Question')
  return confirm_res == 1
end

H.explorer_open_file = function(explorer, path)
  explorer = H.explorer_ensure_target_window(explorer)

  -- Try to use already created buffer, if present. This avoids not needed
  -- `:edit` call and avoids some problems with auto-root from 'mini.misc'.
  local path_buf_id
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local is_target = H.is_valid_buf(buf_id) and vim.bo[buf_id].buflisted and vim.api.nvim_buf_get_name(buf_id) == path
    if is_target then path_buf_id = buf_id end
  end

  if path_buf_id ~= nil then
    vim.api.nvim_win_set_buf(explorer.target_window, path_buf_id)
  else
    -- Use relative path for a better initial view in `:buffers`
    local path_norm = vim.fn.fnameescape(vim.fn.fnamemodify(path, ':.'))
    -- Use `pcall()` to avoid possible `:edit` errors, like present swap file
    pcall(vim.fn.win_execute, explorer.target_window, 'edit ' .. path_norm)
  end

  return explorer
end

H.explorer_ensure_target_window = function(explorer)
  if not H.is_valid_win(explorer.target_window) then explorer.target_window = H.get_first_valid_normal_window() end
  return explorer
end

H.explorer_open_directory = function(explorer, path, target_depth)
  -- Update focused depth
  explorer.depth_focus = target_depth

  -- Truncate rest of the branch if opening another path at target depth
  local show_new_path_at_depth = path ~= explorer.branch[target_depth]
  if show_new_path_at_depth then
    explorer.branch[target_depth] = path
    explorer = H.explorer_trim_branch_right(explorer)
  end

  return explorer
end

H.explorer_open_root_parent = function(explorer)
  local root = explorer.branch[1]
  local root_parent = H.fs_get_parent(root)
  if root_parent == nil then return explorer end

  -- Update branch data
  table.insert(explorer.branch, 1, root_parent)

  -- Focus on previous root entry in its parent
  return H.explorer_focus_on_entry(explorer, root_parent, H.fs_get_basename(root))
end

H.explorer_trim_branch_right = function(explorer)
  for i = explorer.depth_focus + 1, #explorer.branch do
    explorer.branch[i] = nil
  end
  return explorer
end

H.explorer_trim_branch_left = function(explorer)
  local new_branch = {}
  for i = explorer.depth_focus, #explorer.branch do
    table.insert(new_branch, explorer.branch[i])
  end
  explorer.branch = new_branch
  explorer.depth_focus = 1
  return explorer
end

H.explorer_show_help = function(explorer_buf_id, explorer_win_id)
  -- Compute lines
  local buf_mappings = vim.api.nvim_buf_get_keymap(explorer_buf_id, 'n')
  local map_data, desc_width = {}, 0
  for _, data in ipairs(buf_mappings) do
    if data.desc ~= nil then
      map_data[data.desc] = data.lhs:lower() == '<lt>' and '<' or data.lhs
      desc_width = math.max(desc_width, data.desc:len())
    end
  end

  local desc_arr = vim.tbl_keys(map_data)
  table.sort(desc_arr)
  local map_format = string.format('%%-%ds │ %%s', desc_width)

  local lines = { 'Buffer mappings:', '' }
  for _, desc in ipairs(desc_arr) do
    table.insert(lines, string.format(map_format, desc, map_data[desc]))
  end
  table.insert(lines, '')
  table.insert(lines, '(Press `q` to close)')

  -- Create buffer
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf_id, desc = 'Close this window' })

  vim.b[buf_id].minicursorword_disable = true
  vim.b[buf_id].miniindentscope_disable = true

  vim.bo[buf_id].filetype = 'minifiles-help'

  -- Compute window data
  local line_widths = vim.tbl_map(vim.fn.strdisplaywidth, lines)
  local max_line_width = math.max(unpack(line_widths))

  local config = vim.api.nvim_win_get_config(explorer_win_id)
  config.relative = 'win'
  config.row = 0
  config.col = 0
  config.width = max_line_width
  config.height = #lines
  config.title = vim.fn.has('nvim-0.9') == 1 and [['mini.files' help]] or nil
  config.zindex = config.zindex + 1
  config.style = 'minimal'

  -- Open window
  local win_id = vim.api.nvim_open_win(buf_id, false, config)
  H.window_update_highlight(win_id, 'NormalFloat', 'MiniFilesNormal')
  H.window_update_highlight(win_id, 'FloatTitle', 'MiniFilesTitle')
  H.window_update_highlight(win_id, 'CursorLine', 'MiniFilesCursorLine')
  vim.wo[win_id].cursorline = true

  vim.api.nvim_set_current_win(win_id)
  return win_id
end

H.compute_visible_depth_range = function(explorer, opts)
  -- Compute maximum number of windows possible to fit in current Neovim width
  -- Add 2 to widths to take into account width of left and right borders
  local width_focus, width_nofocus = opts.windows.width_focus + 2, opts.windows.width_nofocus + 2

  local has_preview = explorer.opts.windows.preview and explorer.depth_focus < #explorer.branch
  local width_preview = has_preview and (opts.windows.width_preview + 2) or width_nofocus

  local max_number = 1
  if (width_focus + width_preview) <= vim.o.columns then max_number = max_number + 1 end
  if (width_focus + width_preview + width_nofocus) <= vim.o.columns then
    max_number = max_number + math.floor((vim.o.columns - width_focus - width_preview) / width_nofocus)
  end

  -- - Account for dedicated option
  max_number = math.min(math.max(max_number, 1), opts.windows.max_number)

  -- Compute which branch entries to show with the following idea:
  -- - Always show focused depth as centered as possible.
  -- - Show as much as possible.
  -- Logic is similar to how text for 'mini.tabline' is computed.
  local branch_depth, depth_focus = #explorer.branch, explorer.depth_focus
  local n_panes = math.min(branch_depth, max_number)

  local to = math.min(branch_depth, math.floor(depth_focus + 0.5 * n_panes))
  local from = math.max(1, to - n_panes + 1)
  to = from + math.min(n_panes, branch_depth) - 1

  return { from = from, to = to }
end

-- Views ----------------------------------------------------------------------
H.view_ensure_proper = function(view, path, opts)
  -- Ensure proper buffer
  if not H.is_valid_buf(view.buf_id) then
    H.buffer_delete(view.buf_id)
    view.buf_id = H.buffer_create(path, opts.mappings)
    view.children_path_ids = H.buffer_update(view.buf_id, path, opts)
  end

  -- Ensure proper cursor. If string, find it as line in current buffer.
  view.cursor = view.cursor or { 1, 0 }
  if type(view.cursor) == 'string' then view = H.view_decode_cursor(view) end

  return view
end

H.view_encode_cursor = function(view)
  local buf_id, cursor = view.buf_id, view.cursor
  if not H.is_valid_buf(buf_id) or type(cursor) ~= 'table' then return view end

  -- Replace exact cursor coordinates with entry name to try and find later.
  -- This allows more robust opening explorer from history (as directory
  -- content may have changed and exact cursor position would be not valid).
  local l = H.get_bufline(buf_id, cursor[1])
  view.cursor = H.match_line_entry_name(l)
  return view
end

H.view_decode_cursor = function(view)
  local buf_id, cursor = view.buf_id, view.cursor
  if not H.is_valid_buf(buf_id) or type(cursor) ~= 'string' then return view end

  -- Find entry name named as stored in `cursor`. If not - use {1, 0}.
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  for i, l in ipairs(lines) do
    if cursor == H.match_line_entry_name(l) then view.cursor = { i, 0 } end
  end

  if type(view.cursor) ~= 'table' then view.cursor = { 1, 0 } end

  return view
end

H.view_invalidate_buffer = function(view)
  H.buffer_delete(view.buf_id)
  view.buf_id = nil
  view.children_path_ids = nil
  return view
end

H.view_track_cursor = vim.schedule_wrap(function(data)
  -- Schedule this in order to react *after* all pending changes are applied
  local buf_id = data.buf
  local buf_data = H.opened_buffers[buf_id]
  if buf_data == nil then return end

  local win_id = buf_data.win_id
  if not H.is_valid_win(win_id) then return end

  -- Ensure cursor doesn't go over path id and icon
  local cur_cursor = H.window_tweak_cursor(win_id, buf_id)

  -- Ensure cursor line doesn't contradict window on the right
  local tabpage_id = vim.api.nvim_win_get_tabpage(win_id)
  local explorer = H.explorer_get(tabpage_id)
  if explorer == nil then return end

  local buf_depth = H.explorer_get_path_depth(explorer, buf_data.path)
  if buf_depth == nil then return end

  -- Update cursor in view and sync it with branch
  local view = explorer.views[buf_data.path]
  if view ~= nil then
    view.cursor = cur_cursor
    explorer.views[buf_data.path] = view
  end

  explorer = H.explorer_sync_cursor_and_branch(explorer, buf_depth)

  -- Don't trigger redundant window update events
  H.block_event_trigger['MiniFilesWindowUpdate'] = true
  H.explorer_refresh(explorer)
  H.block_event_trigger['MiniFilesWindowUpdate'] = false
end)

H.view_track_text_change = function(data)
  -- Track 'modified'
  local buf_id = data.buf
  local new_n_modified = H.opened_buffers[buf_id].n_modified + 1
  H.opened_buffers[buf_id].n_modified = new_n_modified
  local win_id = H.opened_buffers[buf_id].win_id
  if new_n_modified > 0 and H.is_valid_win(win_id) then H.window_update_border_hl(win_id) end

  -- Track window height
  if not H.is_valid_win(win_id) then return end

  local n_lines = vim.api.nvim_buf_line_count(buf_id)
  local height = math.min(n_lines, H.window_get_max_height())
  vim.api.nvim_win_set_height(win_id, height)

  -- Ensure that only buffer lines are shown. This can be not the case if after
  -- text edit cursor moved past previous last line.
  local last_visible_line = vim.fn.line('w0', win_id) + height - 1
  local out_of_buf_lines = last_visible_line - n_lines
  -- - Possibly scroll window upward (`\25` is an escaped `<C-y>`)
  if out_of_buf_lines > 0 then vim.cmd('normal! ' .. out_of_buf_lines .. '\25') end
end

-- Buffers --------------------------------------------------------------------
H.buffer_create = function(path, mappings)
  -- Create buffer
  local buf_id = vim.api.nvim_create_buf(false, true)

  -- Register buffer
  H.opened_buffers[buf_id] = { path = path }

  -- Make buffer mappings
  H.buffer_make_mappings(buf_id, mappings)

  -- Make buffer autocommands
  local augroup = vim.api.nvim_create_augroup('MiniFiles', { clear = false })
  local au = function(events, desc, callback)
    vim.api.nvim_create_autocmd(events, { group = augroup, buffer = buf_id, desc = desc, callback = callback })
  end

  au({ 'CursorMoved', 'CursorMovedI' }, 'Tweak cursor position', H.view_track_cursor)
  au({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, 'Track buffer modification', H.view_track_text_change)

  -- Tweak buffer to be used nicely with other 'mini.nvim' modules
  vim.b[buf_id].minicursorword_disable = true

  -- Set buffer options
  vim.bo[buf_id].filetype = 'minifiles'

  -- Trigger dedicated event
  H.trigger_event('MiniFilesBufferCreate', { buf_id = buf_id })

  return buf_id
end

H.buffer_make_mappings = function(buf_id, mappings)
  local go_in_with_count = function()
    for _ = 1, vim.v.count1 do
      MiniFiles.go_in()
    end
  end

  local go_in_plus = function()
    for _ = 1, vim.v.count1 do
      MiniFiles.go_in({ close_on_file = true })
    end
  end

  local go_out_with_count = function()
    for _ = 1, vim.v.count1 do
      MiniFiles.go_out()
    end
  end

  local go_out_plus = function()
    go_out_with_count()
    MiniFiles.trim_right()
  end

  local go_in_visual = function()
    -- React only on linewise mode, as others can be used for editing
    if vim.fn.mode() ~= 'V' then return mappings.go_in end

    -- Schedule actions because they are not allowed inside expression mapping
    local line_1, line_2 = vim.fn.line('v'), vim.fn.line('.')
    local from_line, to_line = math.min(line_1, line_2), math.max(line_1, line_2)
    vim.schedule(function()
      local explorer = H.explorer_get()
      explorer = H.explorer_go_in_range(explorer, buf_id, from_line, to_line)
      H.explorer_refresh(explorer)
    end)

    -- Go to Normal mode. '\28\14' is an escaped version of `<C-\><C-n>`.
    return [[<C-\><C-n>]]
  end

  local buf_map = function(mode, lhs, rhs, desc)
    -- Use `nowait` to account for non-buffer mappings starting with `lhs`
    H.map(mode, lhs, rhs, { buffer = buf_id, desc = desc, nowait = true })
  end

  --stylua: ignore start
  buf_map('n', mappings.close,       MiniFiles.close,       'Close')
  buf_map('n', mappings.go_in,       go_in_with_count,      'Go in entry')
  buf_map('n', mappings.go_in_plus,  go_in_plus,            'Go in entry plus')
  buf_map('n', mappings.go_out,      go_out_with_count,     'Go out of directory')
  buf_map('n', mappings.go_out_plus, go_out_plus,           'Go out of directory plus')
  buf_map('n', mappings.reset,       MiniFiles.reset,       'Reset')
  buf_map('n', mappings.reveal_cwd,  MiniFiles.reveal_cwd,  'Reveal cwd')
  buf_map('n', mappings.show_help,   MiniFiles.show_help,   'Show Help')
  buf_map('n', mappings.synchronize, MiniFiles.synchronize, 'Synchronize')
  buf_map('n', mappings.trim_left,   MiniFiles.trim_left,   'Trim branch left')
  buf_map('n', mappings.trim_right,  MiniFiles.trim_right,  'Trim branch right')

  H.map('x', mappings.go_in, go_in_visual, { buffer = buf_id, desc = 'Go in selected entries', expr = true })
  --stylua: ignore end
end

H.buffer_update = function(buf_id, path, opts)
  if not (H.is_valid_buf(buf_id) and H.fs_is_present_path(path)) then return end

  -- Perform entry type specific updates
  local update_fun = H.fs_get_type(path) == 'directory' and H.buffer_update_directory or H.buffer_update_file
  local fs_entries = update_fun(buf_id, path, opts)

  -- Trigger dedicated event
  H.trigger_event('MiniFilesBufferUpdate', { buf_id = buf_id, win_id = H.opened_buffers[buf_id].win_id })

  -- Reset buffer as not modified
  H.opened_buffers[buf_id].n_modified = -1

  -- Return array with children entries path ids for future synchronization
  return vim.tbl_map(function(x) return x.path_id end, fs_entries)
end

H.buffer_update_directory = function(buf_id, path, opts)
  local lines, icon_hl, name_hl = {}, {}, {}

  -- Compute lines
  local fs_entries = H.fs_read_dir(path, opts.content)

  -- - Compute format expression resulting into same width path ids
  local path_width = math.floor(math.log10(#H.path_index)) + 1
  local line_format = '/%0' .. path_width .. 'd/%s/%s'

  local prefix_fun = opts.content.prefix
  for _, entry in ipairs(fs_entries) do
    local prefix, hl = prefix_fun(entry)
    prefix, hl = prefix or '', hl or ''
    table.insert(lines, string.format(line_format, H.path_index[entry.path], prefix, entry.name))
    table.insert(icon_hl, hl)
    table.insert(name_hl, entry.fs_type == 'directory' and 'MiniFilesDirectory' or 'MiniFilesFile')
  end

  -- Set lines
  H.set_buflines(buf_id, lines)

  -- Add highlighting
  local ns_id = H.ns_id.highlight
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)

  local set_hl = function(line, col, hl_opts) H.set_extmark(buf_id, ns_id, line, col, hl_opts) end

  for i, l in ipairs(lines) do
    local icon_start, name_start = l:match('^/%d+/().-()/')

    -- NOTE: Use `right_gravity = false` for persistent highlights during edit
    local icon_opts = { hl_group = icon_hl[i], end_col = name_start - 1, right_gravity = false }
    set_hl(i - 1, icon_start - 1, icon_opts)

    local name_opts = { hl_group = name_hl[i], end_row = i, end_col = 0, right_gravity = false }
    set_hl(i - 1, name_start - 1, name_opts)
  end

  return fs_entries
end

H.buffer_update_file = function(buf_id, path, opts)
  -- Determine if file is text. This is not 100% proof, but good enough.
  -- Source: https://github.com/sharkdp/content_inspector
  local fd = vim.loop.fs_open(path, 'r', 1)
  local is_text = vim.loop.fs_read(fd, 1024):find('\0') == nil
  vim.loop.fs_close(fd)
  if not is_text then
    H.set_buflines(buf_id, { '-Non-text-file' .. string.rep('-', opts.windows.width_preview) })
    return {}
  end

  -- Compute lines. Limit number of read lines to work better on large files.
  local has_lines, read_res = pcall(vim.fn.readfile, path, '', vim.o.lines)
  -- - Make sure that lines don't contain '\n' (might happen in binary files).
  local lines = has_lines and vim.split(table.concat(read_res, '\n'), '\n') or {}

  -- Set lines
  H.set_buflines(buf_id, lines)

  -- Add highlighting if reasonable (for performance or functionality reasons)
  if H.buffer_should_highlight(buf_id) then
    local ft = vim.filetype.match({ buf = buf_id, filename = path })
    local has_lang, lang = pcall(vim.treesitter.language.get_lang, ft)
    local has_ts, _ = pcall(vim.treesitter.start, buf_id, has_lang and lang or ft)
    if not has_ts then vim.bo[buf_id].syntax = ft end
  end

  return {}
end

H.buffer_delete = function(buf_id)
  if buf_id == nil then return end
  pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
  H.opened_buffers[buf_id] = nil
end

H.buffer_compute_fs_diff = function(buf_id, ref_path_ids)
  if not H.is_modified_buffer(buf_id) then return {} end

  local path = H.opened_buffers[buf_id].path
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local res, present_path_ids = {}, {}

  -- Process present file system entries
  for _, l in ipairs(lines) do
    local path_id = H.match_line_path_id(l)
    local path_from = H.path_index[path_id]

    -- Use whole line as name if no path id is detected
    local name_to = path_id ~= nil and l:sub(H.match_line_offset(l)) or l

    -- Preserve trailing '/' to distinguish between creating file or directory
    local path_to = H.fs_child_path(path, name_to) .. (vim.endswith(name_to, '/') and '/' or '')

    -- Ignore blank lines and already synced entries (even several user-copied)
    if l:find('^%s*$') == nil and path_from ~= path_to then
      table.insert(res, { from = path_from, to = path_to })
    elseif path_id ~= nil then
      present_path_ids[path_id] = true
    end
  end

  -- Detect missing file system entries
  for _, ref_id in ipairs(ref_path_ids) do
    if not present_path_ids[ref_id] then table.insert(res, { from = H.path_index[ref_id], to = nil }) end
  end

  return res
end

H.buffer_should_highlight = function(buf_id)
  -- Neovim>=0.8 has more stable API
  if vim.fn.has('nvim-0.8') == 0 then return false end

  -- Highlight if buffer size is not too big, both in total and per line
  local buf_size = vim.api.nvim_buf_call(buf_id, function() return vim.fn.line2byte(vim.fn.line('$') + 1) end)
  return buf_size <= 1000000 and buf_size <= 1000 * vim.api.nvim_buf_line_count(buf_id)
end

H.is_opened_buffer = function(buf_id) return H.opened_buffers[buf_id] ~= nil end

H.is_modified_buffer = function(buf_id)
  local data = H.opened_buffers[buf_id]
  return data ~= nil and data.n_modified > 0
end

H.match_line_entry_name = function(l)
  if l == nil then return nil end
  local offset = H.match_line_offset(l)
  -- Go up until first occurrence of path separator allowing to track entries
  -- like `a/b.lua` when creating nested structure
  local res = l:sub(offset):gsub('/.*$', '')
  return res
end

H.match_line_offset = function(l)
  if l == nil then return nil end
  return l:match('^/.-/.-/()') or 1
end

H.match_line_path_id = function(l)
  if l == nil then return nil end

  local id_str = l:match('^/(%d+)')
  local ok, res = pcall(tonumber, id_str)
  if not ok then return nil end
  return res
end

-- Windows --------------------------------------------------------------------
H.window_open = function(buf_id, config)
  -- Add always the same extra data
  config.anchor = 'NW'
  config.border = 'single'
  config.focusable = true
  config.relative = 'editor'
  config.style = 'minimal'
  -- - Use 99 to allow built-in completion to be on top
  config.zindex = 99

  -- Add temporary data which will be updated later
  config.row = 1

  -- Ensure it works on Neovim<0.9
  if vim.fn.has('nvim-0.9') == 0 then config.title = nil end

  -- Open without entering
  local win_id = vim.api.nvim_open_win(buf_id, false, config)

  -- Set permanent window options
  vim.wo[win_id].concealcursor = 'nvic'
  vim.wo[win_id].foldenable = false
  vim.wo[win_id].wrap = false

  -- Conceal path id and prefix separators
  vim.api.nvim_win_call(win_id, function()
    vim.fn.matchadd('Conceal', [[^/\d\+/]])
    vim.fn.matchadd('Conceal', [[^/\d\+/[^/]*\zs/\ze]])
  end)

  -- Set permanent window highlights
  H.window_update_highlight(win_id, 'NormalFloat', 'MiniFilesNormal')
  H.window_update_highlight(win_id, 'FloatTitle', 'MiniFilesTitle')
  H.window_update_highlight(win_id, 'CursorLine', 'MiniFilesCursorLine')

  -- Trigger dedicated event
  H.trigger_event('MiniFilesWindowOpen', { buf_id = buf_id, win_id = win_id })

  return win_id
end

H.window_update = function(win_id, config)
  -- Compute helper data
  local has_tabline = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  local max_height = H.window_get_max_height()

  -- Ensure proper fit
  config.row = has_tabline and 1 or 0
  config.height = config.height ~= nil and math.min(config.height, max_height) or nil
  config.width = config.width ~= nil and math.min(config.width, vim.o.columns) or nil

  -- Ensure proper title on Neovim>=0.9 (as they are not supported earlier)
  if vim.fn.has('nvim-0.9') == 1 and config.title ~= nil then
    -- Show only tail if title is too long
    local title_string, width = config.title, config.width
    local title_chars = vim.fn.strcharlen(title_string)
    if width < title_chars then
      title_string = '…' .. vim.fn.strcharpart(title_string, title_chars - width + 1, width - 1)
    end
    config.title = title_string
    config.border = vim.api.nvim_win_get_config(win_id).border
  else
    config.title = nil
  end

  -- Update config
  config.relative = 'editor'
  vim.api.nvim_win_set_config(win_id, config)

  -- Reset basic highlighting (removes possible "focused" highlight group)
  H.window_update_highlight(win_id, 'FloatTitle', 'MiniFilesTitle')

  -- Make sure that 'cursorline' is not overridden by `config.style`
  vim.wo[win_id].cursorline = true

  -- Make sure proper `conceallevel` (can be not the case with 'noice.nvim')
  vim.wo[win_id].conceallevel = 3

  -- Trigger dedicated event
  H.trigger_event('MiniFilesWindowUpdate', { buf_id = vim.api.nvim_win_get_buf(win_id), win_id = win_id })
end

H.window_update_highlight = function(win_id, new_from, new_to)
  local new_entry = new_from .. ':' .. new_to
  local replace_pattern = string.format('(%s:[^,]*)', vim.pesc(new_from))
  local new_winhighlight, n_replace = vim.wo[win_id].winhighlight:gsub(replace_pattern, new_entry)
  if n_replace == 0 then new_winhighlight = new_winhighlight .. ',' .. new_entry end

  -- Use `pcall()` because Neovim<0.8 doesn't allow non-existing highlight
  -- groups inside `winhighlight` (like `FloatTitle` at the time).
  pcall(function() vim.wo[win_id].winhighlight = new_winhighlight end)
end

H.window_focus = function(win_id)
  vim.api.nvim_set_current_win(win_id)
  H.window_update_highlight(win_id, 'FloatTitle', 'MiniFilesTitleFocused')
end

H.window_close = function(win_id)
  if win_id == nil then return end
  local has_buffer, buf_id = pcall(vim.api.nvim_win_get_buf, win_id)
  if has_buffer then H.opened_buffers[buf_id].win_id = nil end
  pcall(vim.api.nvim_win_close, win_id, true)
end

H.window_set_view = function(win_id, view)
  -- Set buffer
  local buf_id = view.buf_id
  vim.api.nvim_win_set_buf(win_id, buf_id)
  -- - Update buffer register. No need to update previous buffer data, as it
  --   should already be invalidated.
  H.opened_buffers[buf_id].win_id = win_id

  -- Set cursor
  pcall(H.window_set_cursor, win_id, view.cursor)

  -- Set 'cursorline' here also because changing buffer might have removed it
  vim.wo[win_id].cursorline = true

  -- Update border highlight based on buffer status
  H.window_update_border_hl(win_id)
end

H.window_set_cursor = function(win_id, cursor)
  if type(cursor) ~= 'table' then return end

  vim.api.nvim_win_set_cursor(win_id, cursor)

  -- Tweak cursor here and don't rely on `CursorMoved` event to reduce flicker
  H.window_tweak_cursor(win_id, vim.api.nvim_win_get_buf(win_id))
end

H.window_tweak_cursor = function(win_id, buf_id)
  local cursor = vim.api.nvim_win_get_cursor(win_id)
  local l = H.get_bufline(buf_id, cursor[1])

  local cur_offset = H.match_line_offset(l)
  if cursor[2] < (cur_offset - 1) then
    cursor[2] = cur_offset - 1
    vim.api.nvim_win_set_cursor(win_id, cursor)
    -- Ensure icons are shown (may be not the case after horizontal scroll)
    vim.cmd('normal! 1000zh')
  end

  return cursor
end

H.window_update_border_hl = function(win_id)
  if not H.is_valid_win(win_id) then return end
  local buf_id = vim.api.nvim_win_get_buf(win_id)

  local border_hl = H.is_modified_buffer(buf_id) and 'MiniFilesBorderModified' or 'MiniFilesBorder'
  H.window_update_highlight(win_id, 'FloatBorder', border_hl)
end

H.window_get_max_height = function()
  local has_tabline = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  local has_statusline = vim.o.laststatus > 0
  -- Remove 2 from maximum height to account for top and bottom borders
  return vim.o.lines - vim.o.cmdheight - (has_tabline and 1 or 0) - (has_statusline and 1 or 0) - 2
end

-- File system ----------------------------------------------------------------
-- TODO: Replace with `vim.fs` after Neovim=0.7 compatibility is dropped

---@class fs_entry
---@field name string Base name.
---@field fs_type string One of "directory" or "file".
---@field path string Full path.
---@field path_id number Id of full path.
---@private
H.fs_read_dir = function(path, content_opts)
  local fs = vim.loop.fs_scandir(path)
  local res = {}
  if not fs then return res end

  -- Read all entries
  local name, fs_type = vim.loop.fs_scandir_next(fs)
  while name do
    if not (fs_type == 'file' or fs_type == 'directory') then fs_type = H.fs_get_type(H.fs_child_path(path, name)) end
    table.insert(res, { fs_type = fs_type, name = name, path = H.fs_child_path(path, name) })
    name, fs_type = vim.loop.fs_scandir_next(fs)
  end

  -- Filter and sort entries
  res = content_opts.sort(vim.tbl_filter(content_opts.filter, res))

  -- Add new data: absolute file path and its index
  for _, entry in ipairs(res) do
    entry.path_id = H.add_path_to_index(entry.path)
  end

  return res
end

H.add_path_to_index = function(path)
  local cur_id = H.path_index[path]
  if cur_id ~= nil then return cur_id end

  local new_id = #H.path_index + 1
  H.path_index[new_id] = path
  H.path_index[path] = new_id

  return new_id
end

H.replace_path_in_index = function(from, to)
  local from_id, to_id = H.path_index[from], H.path_index[to]
  H.path_index[from_id], H.path_index[to] = to, from_id
  if to_id then H.path_index[to_id] = nil end
  -- Remove `from` from index assuming it doesn't exist anymore (no duplicates)
  H.path_index[from] = nil
end

H.compare_fs_entries = function(a, b)
  -- Put directory first
  if a.is_dir and not b.is_dir then return true end
  if not a.is_dir and b.is_dir then return false end

  -- Otherwise order alphabetically ignoring case
  return a.lower_name < b.lower_name
end

H.fs_normalize_path = function(path)
  -- Use only forward slashes (for proper work on Windows)
  -- Don't use trailing slashes for proper 'get_parent' (account for plain '/')
  local res = path:gsub('\\', '/'):gsub('/+', '/'):gsub('(.)/$', '%1')
  return res
end

H.fs_is_present_path = function(path) return vim.loop.fs_stat(path) ~= nil end

H.fs_child_path = function(dir, name) return H.fs_normalize_path(string.format('%s/%s', dir, name)) end

H.fs_full_path = function(path) return H.fs_normalize_path(vim.fn.fnamemodify(path, ':p')) end

H.fs_shorten_path = function(path)
  -- Replace home directory with '~'
  path = H.fs_normalize_path(path)
  local home_dir = H.fs_normalize_path(vim.loop.os_homedir() or '~')
  local res = path:gsub('^' .. vim.pesc(home_dir), '~')
  return res
end

H.fs_get_basename = function(path) return H.fs_normalize_path(path):match('[^/]+$') end

H.fs_get_parent = function(path)
  path = H.fs_full_path(path)

  -- Deal with top root paths
  local is_top = H.fs_is_windows_top(path) or path == '/'
  if is_top then return nil end

  -- Compute parent
  local res = H.fs_normalize_path(path:match('^.*/'))
  -- - Deal with Windows top directory separately
  local suffix = H.fs_is_windows_top(res) and '/' or ''
  return res .. suffix
end

H.fs_is_windows_top = function(path) return H.is_windows and path:find('^%w:[\\/]?$') ~= nil end

H.fs_get_type = function(path)
  if not H.fs_is_present_path(path) then return nil end
  return vim.fn.isdirectory(path) == 1 and 'directory' or 'file'
end

-- File system actions --------------------------------------------------------
H.fs_actions_confirm = function(fs_actions)
  local msg = table.concat(H.fs_actions_to_lines(fs_actions), '\n')
  local confirm_res = vim.fn.confirm(msg, '&Yes\n&No', 1, 'Question')
  return confirm_res == 1
end

H.fs_actions_to_lines = function(fs_actions)
  -- Gather actions per source directory
  local actions_per_dir = {}

  local get_dir_actions = function(path)
    local dir_path = H.fs_shorten_path(H.fs_get_parent(path))
    local dir_actions = actions_per_dir[dir_path] or {}
    actions_per_dir[dir_path] = dir_actions
    return dir_actions
  end

  local get_quoted_basename = function(path) return string.format("'%s'", H.fs_get_basename(path)) end

  for _, diff in ipairs(fs_actions.copy) do
    local dir_actions = get_dir_actions(diff.from)
    local l = string.format("    COPY: %s to '%s'", get_quoted_basename(diff.from), H.fs_shorten_path(diff.to))
    table.insert(dir_actions, l)
  end

  for _, path in ipairs(fs_actions.create) do
    local dir_actions = get_dir_actions(path)
    local fs_type = path:find('/$') == nil and 'file' or 'directory'
    local l = string.format('  CREATE: %s (%s)', get_quoted_basename(path), fs_type)
    table.insert(dir_actions, l)
  end

  for _, path in ipairs(fs_actions.delete) do
    local dir_actions = get_dir_actions(path)
    local l = string.format('  DELETE: %s', get_quoted_basename(path))
    table.insert(dir_actions, l)
  end

  for _, diff in ipairs(fs_actions.move) do
    local dir_actions = get_dir_actions(diff.from)
    local l = string.format("    MOVE: %s to '%s'", get_quoted_basename(diff.from), H.fs_shorten_path(diff.to))
    table.insert(dir_actions, l)
  end

  for _, diff in ipairs(fs_actions.rename) do
    local dir_actions = get_dir_actions(diff.from)
    local l = string.format('  RENAME: %s to %s', get_quoted_basename(diff.from), get_quoted_basename(diff.to))
    table.insert(dir_actions, l)
  end

  -- Convert to lines
  local res = { 'CONFIRM FILE SYSTEM ACTIONS', '' }
  for path, dir_actions in pairs(actions_per_dir) do
    table.insert(res, path .. ':')
    vim.list_extend(res, dir_actions)
    table.insert(res, '')
  end

  return res
end

H.fs_actions_apply = function(fs_actions, opts)
  -- Copy first to allow later proper deleting
  for _, diff in ipairs(fs_actions.copy) do
    local ok, success = pcall(H.fs_copy, diff.from, diff.to)
    local data = { action = 'copy', from = diff.from, to = diff.to }
    if ok and success then H.trigger_event('MiniFilesActionCopy', data) end
  end

  for _, path in ipairs(fs_actions.create) do
    local ok, success = pcall(H.fs_create, path)
    local data = { action = 'create', to = H.fs_normalize_path(path) }
    if ok and success then H.trigger_event('MiniFilesActionCreate', data) end
  end

  for _, diff in ipairs(fs_actions.move) do
    local ok, success = pcall(H.fs_move, diff.from, diff.to)
    local data = { action = 'move', from = diff.from, to = diff.to }
    if ok and success then H.trigger_event('MiniFilesActionMove', data) end
  end

  for _, diff in ipairs(fs_actions.rename) do
    local ok, success = pcall(H.fs_rename, diff.from, diff.to)
    local data = { action = 'rename', from = diff.from, to = diff.to }
    if ok and success then H.trigger_event('MiniFilesActionRename', data) end
  end

  -- Delete last to not lose anything too early (just in case)
  for _, path in ipairs(fs_actions.delete) do
    local ok, success = pcall(H.fs_delete, path, opts.options.permanent_delete)
    local data = { action = 'delete', from = path }
    if ok and success then H.trigger_event('MiniFilesActionDelete', data) end
  end
end

H.fs_create = function(path)
  -- Don't override existing path
  if H.fs_is_present_path(path) then return false end

  -- Create parent directory allowing nested names
  vim.fn.mkdir(H.fs_get_parent(path), 'p')

  -- Create
  local fs_type = path:find('/$') == nil and 'file' or 'directory'
  if fs_type == 'directory' then
    return vim.fn.mkdir(path) == 1
  else
    return vim.fn.writefile({}, path) == 0
  end
end

H.fs_copy = function(from, to)
  -- Don't override existing path
  if H.fs_is_present_path(to) then return false end

  local from_type = H.fs_get_type(from)
  if from_type == nil then return false end

  -- Allow copying inside non-existing directory
  vim.fn.mkdir(H.fs_get_parent(to), 'p')

  -- Copy file directly
  if from_type == 'file' then return vim.loop.fs_copyfile(from, to) end

  -- Recursively copy a directory
  local fs_entries = H.fs_read_dir(from, { filter = function() return true end, sort = function(x) return x end })
  -- NOTE: Create directory *after* reading entries to allow copy inside itself
  vim.fn.mkdir(to)

  local success = true
  for _, entry in ipairs(fs_entries) do
    success = success and H.fs_copy(entry.path, H.fs_child_path(to, entry.name))
  end

  return success
end

H.fs_delete = function(path, permanent_delete)
  if permanent_delete then return vim.fn.delete(path, 'rf') == 0 end

  -- Move to trash instead of permanent delete
  local trash_dir = H.fs_child_path(vim.fn.stdpath('data'), 'mini.files/trash')
  vim.fn.mkdir(trash_dir, 'p')

  local trash_path = H.fs_child_path(trash_dir, H.fs_get_basename(path))

  -- Ensure that same basenames are replaced
  pcall(vim.fn.delete, trash_path, 'rf')

  return vim.loop.fs_rename(path, trash_path)
end

H.fs_move = function(from, to)
  -- Don't override existing path
  if H.fs_is_present_path(to) then return false end

  -- Move while allowing to create directory
  vim.fn.mkdir(H.fs_get_parent(to), 'p')
  local success = vim.loop.fs_rename(from, to)

  if not success then return success end

  -- Update path index to allow consecutive moves after undo (which also
  -- restores previous concealed path index)
  H.replace_path_in_index(from, to)

  -- Rename in loaded buffers
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    H.rename_loaded_buffer(buf_id, from, to)
  end

  return success
end

H.fs_rename = H.fs_move

H.rename_loaded_buffer = function(buf_id, from, to)
  if not (vim.api.nvim_buf_is_loaded(buf_id) and vim.bo[buf_id].buftype == '') then return end
  -- Make sure buffer name is normalized (same as `from` and `to`)
  local cur_name = H.fs_normalize_path(vim.api.nvim_buf_get_name(buf_id))

  -- Use `gsub('^' ...)` to also take into account directory renames
  local new_name = cur_name:gsub('^' .. vim.pesc(from), to)
  if cur_name == new_name then return end
  vim.api.nvim_buf_set_name(buf_id, new_name)

  -- Force write to avoid the 'overwrite existing file' error message on write
  -- for normal files
  vim.api.nvim_buf_call(buf_id, function() vim.cmd('silent! write! | edit') end)
end

-- Validators -----------------------------------------------------------------
H.validate_opened_buffer = function(x)
  if x == nil or x == 0 then x = vim.api.nvim_get_current_buf() end
  if not H.is_opened_buffer(x) then H.error('`buf_id` should be an identifier of an opened directory buffer.') end
  return x
end

H.validate_line = function(buf_id, x)
  x = x or vim.fn.line('.')
  if not (type(x) == 'number' and 1 <= x and x <= vim.api.nvim_buf_line_count(buf_id)) then
    H.error('`line` should be a valid line number in buffer ' .. buf_id .. '.')
  end
  return x
end

-- Utilities ------------------------------------------------------------------
H.error = function(msg) error(string.format('(mini.files) %s', msg), 0) end

H.map = function(mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

H.trigger_event = function(event_name, data)
  if H.block_event_trigger[event_name] then return end

  -- TODO: Remove after compatibility with Neovim=0.7 is dropped
  if vim.fn.has('nvim-0.8') == 0 then data = nil end
  vim.api.nvim_exec_autocmds('User', { pattern = event_name, data = data })
end

H.is_valid_buf = function(buf_id) return type(buf_id) == 'number' and vim.api.nvim_buf_is_valid(buf_id) end

H.is_valid_win = function(win_id) return type(win_id) == 'number' and vim.api.nvim_win_is_valid(win_id) end

H.get_bufline = function(buf_id, line) return vim.api.nvim_buf_get_lines(buf_id, line - 1, line, false)[1] end

H.set_buflines = function(buf_id, lines)
  local cmd =
    string.format('lockmarks lua vim.api.nvim_buf_set_lines(%d, 0, -1, false, %s)', buf_id, vim.inspect(lines))
  vim.cmd(cmd)
end

H.set_extmark = function(...) pcall(vim.api.nvim_buf_set_extmark, ...) end

H.get_first_valid_normal_window = function()
  for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win_id).relative == '' then return win_id end
  end
end

return MiniFiles
