-- Add project root as full path to runtime path (in order to be able to
-- `require()`) modules from this module
vim.cmd([[let &rtp.=','.getcwd()]])
