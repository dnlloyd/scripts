unsynced_repos=()
invalid_repos=()

cd /Users/dan/github

for org in $( ls -1 | egrep -v "MCC-Students|BankUnited-Terraform|Ciitizen|pymetrics|invitae-internal" )
do
  echo "checking if ORG:${org} is a valid dir"
  if [[ -d "${org}" ]]
  then
    echo "ORG:${org} is a valid dir"
    echo "changing dir to ORG:${org}"
    cd $org

    for repo in $( ls -1 | egrep -v "aws-firewall-manager|ciitizen-dms|my-gha-workflows|tf-huma" )
    do
      echo "checking if REPO:${repo} is a valid dir"
      if [[ -d "${repo}" ]]
      then
        echo "REPO:${repo} is a valid dir"

        echo "changing dir to REPO:${repo}"
        cd $repo

        echo "***********************************************"
        echo "* ${repo}"
        echo "***********************************************"

        git status --porcelain

        if  [ $? -ne 0 ]
          then
            echo "Repo is INVALID"
            invalid_repos+=("${org}/${repo}")
          else
            if [[ `git status --porcelain` ]]
            then
              # repo is out of sync
              echo "Repo is OUT OF SYNC"
              unsynced_repos+=("${org}/${repo}")
            else
              # repo is up to date
              echo "No changes"
            fi
        fi

        echo "----------------------------------------------\n"

        cd ..
      else
        echo "skipping repository ${repo}, not a dir"
      fi
    done

    cd ..
  else
    echo "skipping organization ${org}, not a dir"
  fi
done

echo "\n\n====================================================="
echo "Out of sync repos"
echo "====================================================="
for repo in ${unsynced_repos[@]}
do
  echo $repo
done
echo ""
echo "====================================================="
echo "Invalid repos"
echo "====================================================="
for repo in ${invalid_repos[@]}
do
  echo $repo
done