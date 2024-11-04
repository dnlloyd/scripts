# Usage
# ./mcc_git_cloner.sh CSIS-119 s12345678

export CANVAS_COURSE_ID=16666
# export CANVAS_TOKEN=

PROJECT_NAME="Python-Web-API"
GIT_GRADING_BRANCH="${PROJECT_NAME}-grading"
GIT_DIR="/Users/dan/github/MCC-Students/CSIS-119-fall-2024"
GIT_REPO=$1
GIT_USER=$2
GIT_USER_DIR="${GIT_DIR}/${GIT_USER}"
GIT_REPO_DIR="${GIT_USER_DIR}/${GIT_REPO}"
GIT_REPO_URL="https://github.com/${GIT_USER}/${GIT_REPO}"

DEFAULT_GITHUB_BRANCH=main
DISPLAY_LAST_COMMITS=10

# Lookup user name and email
if [[ $GIT_USER =~ ^(S|s) ]]
then
    echo "*********************************************"
    echo "Grading project for"
    python $SCRIPTS/mcc_student_lookup.py $GIT_USER
    echo "*********************************************"
else
    echo "Unsupported repo name: ${GIT_USER}"
fi

# Create Github user dir
# /Users/dan/github/MCC-Students/CSIS-119-fall-2024/s12345678
if [ -d "${GIT_USER_DIR}" ]
then
    echo "User dir (${GIT_USER_DIR}) exists, not creating it..."
else
    echo "Making user dir ${GIT_USER}"
    mkdir $GIT_USER_DIR
fi

echo "Changing dir to ${GIT_USER_DIR}"
cd $GIT_USER_DIR
if [[ $? -ne 0 ]]
then
    echo "Unable to cd to ${GIT_USER_DIR}, exiting"
    exit 1
fi

# Clone repo. If repo already exists skip and pull down latest updates from $DEFAULT_GITHUB_BRANCH
# /Users/dan/github/MCC-Students/CSIS-119-fall-2024/s12345678/CSIS-119
if [ -d "${GIT_REPO_DIR}" ]
then
    echo "Repo dir (${GIT_USER_DIR}/${GIT_REPO}) exists, not cloning it..."
else
    echo "Cloning repo: ${GIT_REPO_URL}"
    git clone $GIT_REPO_URL
    
    if [[ $? -ne 0 ]]
    then
        echo "Unable to clone ${GIT_REPO_URL}, returning to previous dir and exiting"
        cd -
        exit 1
    fi
fi

echo "Changing dir to ${GIT_REPO_DIR}"
cd $GIT_REPO_DIR
if [[ $? -ne 0 ]]
then
    echo "Unable to cd to ${GIT_REPO_DIR}, exiting"
    exit 1
fi

echo "Checking out default branch: ${DEFAULT_GITHUB_BRANCH}"
git checkout $DEFAULT_GITHUB_BRANCH
if [[ $? -ne 0 ]]
then
    echo "Unable to checkout default branch ${DEFAULT_GITHUB_BRANCH} for ${GIT_REPO_URL}, exiting"
    exit 1
fi

echo "Updating default branch ${DEFAULT_GITHUB_BRANCH}"
git pull origin $DEFAULT_GITHUB_BRANCH
if [[ $? -ne 0 ]]
then
    echo "Unable to pull down default branch ${DEFAULT_GITHUB_BRANCH} for ${GIT_REPO_URL}, exiting"
    exit 1
fi

# TODO: Only do this if $GIT_GRADING_BRANCH doesn't already exist, if GIT_GRADING_BRANCH does
# TODO: exist, it should be at the merge commit from the last project so we'll just use that commit SHA
# Attempt to get intial commit
echo "Attempting get intial commit"
initial_commit_sha=`git rev-list --max-parents=0 HEAD | tail -n 1`
if [[ $? -ne 0 ]]
then
    echo "Unable to get intial commit for ${GIT_REPO_URL}, exiting"
    echo "Initial cmmit SHA: ${initial_commit_sha}"
    exit 1
fi

# TODO: Only ceate if GIT_GRADING_BRANCH doesnt exist
# Create Git grading branch
echo "Creating grading branch ${GIT_GRADING_BRANCH} using initial commit: ${initial_commit_sha}"
git checkout -b $GIT_GRADING_BRANCH $initial_commit_sha
if [[ $? -ne 0 ]]
then
    echo "Unable create grading branch ${GIT_GRADING_BRANCH} for ${GIT_REPO_URL}, exiting"
    exit 1
fi

# Display Git history to validate before pushing
echo "Last ${DISPLAY_LAST_COMMITS} commits to grading branch ${GIT_GRADING_BRANCH}"
git --no-pager log -n $DISPLAY_LAST_COMMITS

read -p "Would you still like to push ${GIT_GRADING_BRANCH} (y/n): " push_branch

# TODO: Not necessary if GIT_GRADING_BRANCH already exists
# Push grading branch
if [[ $push_branch == "y" ]]
then
    git push origin $GIT_GRADING_BRANCH
    
    if [[ $? -ne 0 ]]
    then
        echo "Unable to push ${GIT_GRADING_BRANCH} to ${GIT_REPO_URL}, returning to previous dir and exiting"
        cd -
        exit 1
    else
        # Grading PR link
        echo "PR Link: ${GIT_REPO_URL}/compare/${GIT_GRADING_BRANCH}...${DEFAULT_GITHUB_BRANCH}?expand=1"

        echo "*********************************************"
        echo "${PROJECT_NAME} graded"
        echo "Please review comments below"
        echo "*********************************************"
    fi
else
    echo "Exiting, branch will need to be pushed manaully"
    exit 0
fi

# Opening VSCode for testing
echo "Checking out default branch ${DEFAULT_GITHUB_BRANCH}"
git checkout $DEFAULT_GITHUB_BRANCH
if [[ $? -ne 0 ]]
then
    echo "Unable to checkout default branch ${DEFAULT_GITHUB_BRANCH} for ${GIT_REPO_URL}, exiting"
    exit 1
fi

echo "Updating default branch ${DEFAULT_GITHUB_BRANCH}"
git pull origin $DEFAULT_GITHUB_BRANCH
if [[ $? -ne 0 ]]
then
    echo "Unable to pull down default branch ${DEFAULT_GITHUB_BRANCH} for ${GIT_REPO_URL}, exiting"
    exit 1
fi

code .

echo "cd ${GIT_REPO_DIR}"
