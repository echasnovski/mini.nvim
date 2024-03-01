#!/usr/bin/env bash

msg_file_dir='lintcommit-msg-files/'
mkdir -p $msg_file_dir
function cleanup {
  rm -rf $msg_file_dir
}
trap cleanup EXIT

range="${1:-origin/sync..HEAD}"
msg_files=()
for commit in $( git rev-list --reverse $range -- ); do \
  file="$msg_file_dir$commit" ; \
  git log -1 --pretty=format:%B $commit > $file ; \
  msg_files+=($file) ; \
done

nvim --headless --noplugin -u ./scripts/lintcommit.lua -- ${msg_files[*]}
