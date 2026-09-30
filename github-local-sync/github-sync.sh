#!/bin/sh

GITHUB_SRC_PATH="/Users/dan/github"
SYNC_DEST="/Users/dan/Documents/github-sync"

date 2>&1 | tee -a "${SYNC_DEST}/sync.log"

for dir in "$GITHUB_SRC_PATH"/*; do
  [ -d "$dir" ] || continue
  file=${dir##*/}
  echo "Syncing ${file} to ${SYNC_DEST}" 2>&1 | tee -a "${SYNC_DEST}/sync.log"
  rsync -vrto "$dir" "$SYNC_DEST" \
    --exclude='.git' \
    --exclude='node_modules/' \
    --exclude='.terraform*' \
    --exclude='terraform.tfstate*'
done
