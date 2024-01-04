# Perform local sync of standalone repositories
repos_dir=dual/repos
patches_dir=dual/patches

mkdir -p $repos_dir
mkdir -p $patches_dir

sync_module () {
  # First argument is a string with module name. Others - extra paths to track
  # for module.
  module=$1
  shift

  repo="$( realpath $repos_dir/mini.$module )"
  patch="$( realpath $patches_dir/mini.$module.patch )"

  printf "\n\033[1mmini.$module\033[0m\n"

  # Possibly pull repository
  if [[ ! -d $repo ]]
  then
    printf "Pulling\n"
    git clone --filter=blob:none https://github.com/echasnovski/mini.$module.git $repo
  else
    printf "No pulling (already present)\n"
  fi

  # Make patch with commits from 'sync' branch to current HEAD which affect
  # files related to the module
  printf "Making patch\n"
  git format-patch sync..HEAD --output $patch -- \
    lua/mini/$module.lua \
    doc/mini-$module.txt \
    readmes/mini-$module.md \
    LICENSE \
    $@

  # Do nothing if patch is empty
  if [[ ! -s $patch ]]
  then
    rm $patch
    printf "Patch is empty\n"
    return
  fi

  # Tweak patch:
  # - Move 'readmes/mini-xxx.md' to 'README.md'.
  # - This also means move all references used in it one step higher (and hope
  #   that it doesn't occur anywhere else in patch).
  sed -i "s/readmes\/mini-$module\.md/README.md/" $patch
  sed -i "s/\[help file\](\.\.\//[help file](/" $patch

  # Apply patch
  printf "Applying patch\n"
  cd $repo
  git am $patch
  cd - > /dev/null
}

sync_module "ai"
sync_module "align"
sync_module "animate"
sync_module "base16" colors/minischeme.lua colors/minicyan.lua
sync_module "basics"
sync_module "bracketed"
sync_module "bufremove"
sync_module "clue"
sync_module "colors"
sync_module "comment"
sync_module "completion"
sync_module "cursorword"
sync_module "doc"
sync_module "extra"
sync_module "files"
sync_module "fuzzy"
sync_module "hipatterns"
sync_module "hues" colors/randomhue.lua
sync_module "indentscope"
sync_module "jump"
sync_module "jump2d"
sync_module "map"
sync_module "misc"
sync_module "move"
sync_module "notify"
sync_module "operators"
sync_module "pairs"
sync_module "pick"
sync_module "sessions"
sync_module "splitjoin"
sync_module "starter"
sync_module "statusline"
sync_module "surround"
sync_module "tabline"
sync_module "test"
sync_module "trailspace"
sync_module "visits"
