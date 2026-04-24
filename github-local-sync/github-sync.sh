#!/usr/bin/env bash

GITHUB_SRC_PATH="/Users/dan/github-cerner"
SYNC_DEST="/Users/dan/Documents/github-sync"

exec > >(tee -a "${SYNC_DEST}/sync.log")
exec 2>&1

date

for repo_path in "${GITHUB_SRC_PATH}"/*
do
  if [[ -d "${repo_path}" ]]
  then
    repo_name="$(basename "${repo_path}")"
    echo "Syncing ${repo_name} to ${SYNC_DEST}"
    rsync -vro "${repo_path}" "${SYNC_DEST}" --exclude=".git" --exclude=".terraform*" --exclude="terraform.tfstate*"
  fi
done
