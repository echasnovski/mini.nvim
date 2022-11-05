# Push standalone repos result
local_repos="$( ls -d dual/repos/*/ )"

for repo in $local_repos; do
  printf "\n\033[1mPushing $( basename $repo )\033[0m\n"
  cd $repo > /dev/null
  git push origin main
  cd - > /dev/null
done
