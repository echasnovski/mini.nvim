" Add project root as full path to runtime path (in order to be able to
" `require()`) modules from this module
let &rtp.=','.getcwd()
set rtp+=deps/plenary.nvim

runtime! plugin/plenary.vim

set noswapfile
