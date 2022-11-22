# Push standalone repos result
local_repos="$( ls -d dual/repos/*/ )"

for repo in $local_repos; do
  printf "\n\033[1mPushing $( basename $repo )\033[0m\n"
  cd $repo > /dev/null
  # Push only if there is something to push (saves time)
  if [ $( git rev-parse main ) != $( git rev-parse origin/main ) ]
  then
    git push origin main
  fi
  cd - > /dev/null
done

echo ''
