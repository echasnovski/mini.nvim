--- Test `@toc` and `@toc_entry` sections
---
--- Table of contents:
---@toc

--- TOC entry with leading spaces
---@toc_entry     Entry #1

--- Multiline TOC entry
---@toc_entry Entry #2:
--- This time it is
--- multiline

--- TOC entry with multiline tag
---@tag toc-entry-with
--- multiline-tag
---@toc_entry Entry #3

--- TOC entry with multiline tag and entry
---@tag toc-second-entry-with
--- multiline-tag-2
---@toc_entry Entry #4:
--- Multiline with
--- three lines

--- TOC entry without description
---@tag toc-entry-without-description
---@toc_entry

--- TOC entry without tag
---@toc_entry Entry #6 (without tag)

--- TOC entry with very long description
---@toc_entry Entry #7: A very-very-very-very-very-very-very-very-very-very long description

--- Test of `MiniDoc.current.toc`
---
---@eval return 'Number of current TOC entries: ' .. #MiniDoc.current.toc
