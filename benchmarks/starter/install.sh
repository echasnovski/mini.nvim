#! /bin/bash
PLUGINPATH=/tmp/nvim/site/pack/bench/opt
rm -rf $PLUGINPATH
mkdir -p $PLUGINPATH
cd $PLUGINPATH

git clone --depth 1 https://github.com/echasnovski/mini.nvim
git clone --depth 1 https://github.com/goolord/alpha-nvim
git clone --depth 1 https://github.com/glepnir/dashboard-nvim
git clone --depth 1 https://github.com/mhinz/vim-startify
