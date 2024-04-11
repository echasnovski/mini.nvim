-- Validate commit message. Designed to be run as pre-commit hook and in CI.
--
-- Each Neovim's argument for when it is opened is assumed to be a path to
-- a file containing commit message to validate
-- Example usage:
-- ```
-- nvim --headless --noplugin -u scripts/lintcommit.lua -- .git/COMMIT_EDITMSG
-- ```

-- Validator functions
local allowed_commit_types = { 'ci', 'docs', 'feat', 'fix', 'refactor', 'style', 'test' }

local allowed_scopes = { 'ALL' }
for _, module in ipairs(vim.fn.readdir('lua/mini')) do
  if module ~= 'init.lua' then table.insert(allowed_scopes, module:match('^(.+)%.lua$')) end
end

local validate_subject = function(line)
  -- Possibly allow starting with 'fixup' to disable commit linting
  if vim.startswith(line, 'fixup') then
    local fail_on_fixup = vim.loop.os_getenv('LINTCOMMIT_FAIL_ON_FIXUP') ~= nil
    local msg = fail_on_fixup and 'No "fixup" commits are allowed.' or ''
    return not fail_on_fixup, msg
  end

  -- Should match overall conventional commit spec
  local commit_type, scope, desc = string.match(line, '^([^(]+)(%b())!?: (.+)$')
  if commit_type == nil then
    commit_type, desc = string.match(line, '^([^!:]+)!?: (.+)$')
  end
  if commit_type == nil or desc == nil then
    return false,
      'First line does not match conventional commit specification of `<type>[optional scope][!]: <description>`: '
        .. vim.inspect(line)
  end

  -- Commit type should be present and be from one of allowed
  if not vim.tbl_contains(allowed_commit_types, commit_type) then
    local one_of = table.concat(vim.tbl_map(vim.inspect, allowed_commit_types), ', ')
    return false, 'Commit type ' .. vim.inspect(commit_type) .. ' is not allowed. Use one of ' .. one_of .. '.'
  end

  -- Scope, if present, should be from one of allowed
  if scope ~= nil then
    scope = scope:sub(2, -2)
    if not vim.tbl_contains(allowed_scopes, scope) then
      local one_of = table.concat(vim.tbl_map(vim.inspect, allowed_scopes), ', ')
      return false, 'Scope ' .. vim.inspect(scope) .. ' is not allowed. Use one of ' .. one_of .. '.'
    end
  end

  -- Description should be present and properly formatted
  if string.find(desc, '^%w') == nil then
    return false, 'Description should start with alphanumeric character: ' .. vim.inspect(desc)
  end

  if string.find(desc, '^%u%l') ~= nil then
    return false, 'Description should not start with capitalized word: ' .. vim.inspect(desc)
  end

  if string.find(desc, '[.,?!;]$') ~= nil then
    return false, 'Description should not end with any of `.,?!;`: ' .. vim.inspect(desc)
  end

  -- Subject should not be too long
  if vim.fn.strdisplaywidth(line) > 72 then
    return false, 'First line is longer than 72 characters: ' .. vim.inspect(desc)
  end

  return true, nil
end

local validate_body = function(parts)
  if #parts == 1 then return true, nil end

  if parts[2] ~= '' then return false, 'Second line should be empty' end
  if parts[3] == nil then return false, 'If first line is not enough, body should be present' end
  if string.find(parts[3], '^%S') == nil then return false, 'First body line should not start with whitespace.' end

  for i = 3, #parts do
    if vim.fn.strdisplaywidth(parts[i]) > 80 then
      return false, 'Body line is longer than 80 characters: ' .. vim.inspect(parts[i])
    end
  end

  if string.find(parts[#parts], '^%s*$') ~= nil then return false, 'Body should not end with blank line.' end

  return true, nil
end

local validate_bad_wording = function(msg)
  local has_fix = msg:find('[Ff]ix #') or msg:find('[Ff]ixes #') or msg:find('[Ff]ixed #')
  local has_bad_close = msg:find('[Cc]lose[sd]? #') ~= nil
  local has_bad_resolve = msg:find('[Rr]esolve[sd] #') ~= nil
  if has_fix or has_bad_close or has_bad_resolve then
    return false,
      'Use "Resolve #" GitHub keyword to resolve issue/PR '
        .. '(not "Fix(/es/ed)", not "Close(/s/d)", not "Resolve(s/d)").'
  end
  return true, nil
end

local validate_commit_msg = function(lines)
  -- Ignore Git comments
  lines = vim.tbl_filter(function(l) return l:find('^%s*#') == nil end, lines)
  local is_valid, err_msg

  -- Allow all lines to be empty to abort committing
  local all_empty = true
  for _, l in ipairs(lines) do
    if l ~= '' then all_empty = false end
  end
  if all_empty then return true, nil end

  -- Validate subject (first line)
  is_valid, err_msg = validate_subject(lines[1])
  if not is_valid then return is_valid, err_msg end

  -- Validate body
  is_valid, err_msg = validate_body(lines)
  if not is_valid then return is_valid, err_msg end

  -- No validation for footer

  -- Should not contain bad wording
  for _, l in ipairs(lines) do
    is_valid, err_msg = validate_bad_wording(l)
    if not is_valid then return is_valid, err_msg end
  end

  return true, nil
end

local validate_commit_msg_from_file = function(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return false, 'Could not read file ' .. path end
  return validate_commit_msg(lines)
end

-- Actual validation
local exit_code = 0
for i = 0, vim.fn.argc(-1) - 1 do
  local path = vim.fn.argv(i, -1)
  io.write('Commit message of ' .. vim.fn.fnamemodify(path, ':t') .. ':\n')
  local is_valid, err_msg = validate_commit_msg_from_file(path)
  io.write((is_valid and 'OK' or err_msg) .. '\n\n')
  if not is_valid then exit_code = 1 end
end

os.exit(exit_code)

-- Tests to be run interactively: `_G.test_cases_failed` should be empty.
-- NOTE: Comment out previous `os.exit()` call
local test_cases = {
  -- Subject
  ['fixup'] = true,
  ['fixup: commit message'] = true,
  ['fixup! commit message'] = true,

  ['ci: normal message'] = true,
  ['docs: normal message'] = true,
  ['feat: normal message'] = true,
  ['fix: normal message'] = true,
  ['refactor: normal message'] = true,
  ['style: normal message'] = true,
  ['test: normal message'] = true,

  ['feat(ai): message with scope'] = true,
  ['feat!: message with breaking change'] = true,
  ['feat(ai)!: message with scope and breaking change'] = true,
  ['style(ALL): style all modules'] = true,

  ['unknown: unknown type'] = false,
  ['feat(unknown): unknown scope'] = false,
  ['refactor(): empty scope'] = false,
  ['ci( ): whitespace as scope'] = false,

  ['ci no colon after type'] = false,
  [': no type before colon 1'] = false,
  [' : no type before colon 2'] = false,
  ['  : no type before colon 3'] = false,
  ['ci:'] = false,
  ['ci: '] = false,
  ['ci:  '] = false,

  ['feat: message with : in it'] = true,
  ['feat(ai): message with : in it'] = true,

  ['test:  extra space after colon'] = false,
  ['ci:	tab after colon'] = false,
  ['ci:no space after colon'] = false,
  ['ci : extra space before colon'] = false,

  ['ci: bad punctuation at end of sentence.'] = false,
  ['ci: bad punctuation at end of sentence,'] = false,
  ['ci: bad punctuation at end of sentence?'] = false,
  ['ci: bad punctuation at end of sentence!'] = false,
  ['ci: bad punctuation at end of sentence;'] = false,
  ['ci: good punctuation at end of sentence:'] = true,
  ['ci: good punctuation at end of sentence"'] = true,
  ["ci: good punctuation at end of sentence'"] = true,
  ['ci: good punctuation at end of sentence)'] = true,
  ['ci: good punctuation at end of sentence]'] = true,

  ['ci: Capitalized first word'] = false,
  ['ci: UPPER_CASE First Word'] = true,
  ['ci: very very very very very very very very very very very looong subject'] = false,

  -- Body
  ['ci: desc\n\nBody'] = true,
  ['ci: desc\n\nBody\n\nwith\n   \nempty and blank lines'] = true,

  ['ci: desc\nSecond line is not empty'] = false,
  ['ci: desc\n\n First body line starts with whitespace'] = false,
  ['ci: desc\n\nBody\nwith\nVery very very very very very very very very very very very very looong body line'] = false,

  ['ci: only two lines\n\n'] = false,
  ['ci: desc\n\nLast line is empty\n\n'] = false,
  ['ci: desc\n\nLast line is blank\n  '] = false,

  -- Footer
  -- No validation for footer

  -- Bad wordings
  ['ci: this has Fixed #1'] = false,
  ['ci: this has fixed #1'] = false,
  ['ci: this Fixes #1'] = false,
  ['ci: this fixes #1'] = false,
  ['ci: this will Fix #1'] = false,
  ['ci: this will fix #1'] = false,
  ['ci: this has Closed #1'] = false,
  ['ci: this has closed #1'] = false,
  ['ci: this Closes #1'] = false,
  ['ci: this closes #1'] = false,
  ['ci: this will Close #1'] = false,
  ['ci: this will close #1'] = false,
  ['ci: this has Resolved #1'] = false,
  ['ci: this has resolved #1'] = false,
  ['ci: this Resolves #1'] = false,
  ['ci: this resolves #1'] = false,

  ['ci: desc\n\nthis has Fixed #1'] = false,
  ['ci: desc\n\nthis has fixed #1'] = false,
  ['ci: desc\n\nthis Fixes #1'] = false,
  ['ci: desc\n\nthis fixes #1'] = false,
  ['ci: desc\n\nthis will Fix #1'] = false,
  ['ci: desc\n\nthis will fix #1'] = false,
  ['ci: desc\n\nthis has Closed #1'] = false,
  ['ci: desc\n\nthis has closed #1'] = false,
  ['ci: desc\n\nthis Closes #1'] = false,
  ['ci: desc\n\nthis closes #1'] = false,
  ['ci: desc\n\nthis will Close #1'] = false,
  ['ci: desc\n\nthis will close #1'] = false,
  ['ci: desc\n\nthis has Resolved #1'] = false,
  ['ci: desc\n\nthis has resolved #1'] = false,
  ['ci: desc\n\nthis Resolves #1'] = false,
  ['ci: desc\n\nthis resolves #1'] = false,

  -- Ignore comments
  ['# Comment\nci: desc'] = true,
  [' # Comment\nci: desc'] = true,
  ['ci: desc\n# Comment\n\nBody'] = true,

  -- Allow all empty lines
  [''] = true,
  ['\n'] = true,
  ['\n# Comment'] = true,
}

_G.test_cases_failed = {}

vim.loop.os_unsetenv('LINTCOMMIT_FAIL_ON_FIXUP')
for message, expected in pairs(test_cases) do
  local lines = vim.split(message, '\n')
  local is_valid = validate_commit_msg(lines)
  if is_valid ~= expected then
    table.insert(_G.test_cases_failed, { msg = message, expected = expected, actual = is_valid })
  end
end

local fixup_test_cases = {
  ['fixup'] = false,
  ['fixup: should fail'] = false,
  ['fixup! should fail'] = false,

  -- Should only matter in subject
  ['ci: desc\n\nfixup'] = true,
}
vim.loop.os_setenv('LINTCOMMIT_FAIL_ON_FIXUP', 'true')
for message, expected in pairs(fixup_test_cases) do
  local lines = vim.split(message, '\n')
  local is_valid = validate_commit_msg(lines)
  if is_valid ~= expected then
    table.insert(_G.test_cases_failed, { msg = message, expected = expected, actual = is_valid })
  end
end
