GITHUB_SRC_PATH="/Users/dan/github"
SYNC_DEST="/Users/dan/Documents/github-sync"

date 2>&1 | tee -a "${SYNC_DEST}/sync.log"

for file in $(ls -1 $GITHUB_SRC_PATH)
do
  if [ -d "${GITHUB_SRC_PATH}/${file}" ]
  then
    echo "Syncing ${file} to ${SYNC_DEST}" 2>&1 | tee -a "${SYNC_DEST}/sync.log"
    rsync -vro "${GITHUB_SRC_PATH}/${file}" $SYNC_DEST --exclude=.git --exclude=.terraform* --exclude=terraform.tfstate*
  fi
done
