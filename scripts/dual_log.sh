# Check standalone repos result
local_repos="$( ls -d dual/repos/*/ )"

for repo in $local_repos; do
  cd $repo > /dev/null
  # Show only logs with actual changes (saves screen lines)
  if [ $( git rev-parse main ) != $( git rev-parse origin/main ) ]
  then
    printf "\n\033[1m$( basename $repo )\033[0m\n"
    git log origin/main..main --abbrev-commit --format=oneline
  fi
  cd - > /dev/null
done
