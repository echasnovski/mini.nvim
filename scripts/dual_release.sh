# Make release from current commits (sync repos before doing this)
local_repos="$( ls -d dual/repos/*/ )"

# Register tag name and message as script arguments
if [ -z "$1" ] || [ -z "$2" ]
then
  printf "Supply tag name and message as script arguments\n"
  exit 2
fi
tag_name=$1
tag_message=$2

for repo in $local_repos; do
  printf "\n\033[1mReleasing $( basename $repo )\033[0m\n"
  cd $repo > /dev/null

  # Ensure that all history is downloaded to allow proper pull of `stable`
  printf "\033[4mPulling all \`main\` history\033[0m\n"
  git checkout main
  git pull --unshallow
  echo ''

  # Ensure branch on latest `main`
  printf "\033[4mMaking \`stable\` point to latest \`main\`\033[0m\n"
  git checkout -B stable
  git checkout main
  echo ''

  # Create tag
  printf "\033[4mCreating tag\033[0m\n"
  git tag -a "$tag_name" -m "$tag_message"
  echo ''

  # Push
  printf "\033[4mPushing\033[0m\n"
  git push origin $tag_name
  git push origin stable
  echo ''

  cd - > /dev/null
done

echo ''
