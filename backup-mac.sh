############ VARIABLES / OPTIONS ############
CHECK_FOR_STALE_GITHUB="false"
COPY_TO_CRYPTOMATOR_VOLUME="false"

TARGET_IP="192.168.0.228"
TARGET_USER="dan"

REMOTE_BACKUP_DIR="/Users/dan/Foghorn-Backup/"
LOCAL_BACKUP_DIR="/Users/dan/Documents/backup"

GITHUB_SOURCE_DIR="/Users/dan/github"
GITHUB_TARGET_DIR="/Users/dan/github-public/"

ICLOUD_BACKUP_DIR="/Users/dan/Documents/backup"

CRYPTOMATOR_DIR="/Volumes/encrypted"
LOCAL_ENCRYPTED_DIR="/Users/dan/Documents/encrypted"

HOME_FILES=(".zsh_history" ".viminfo" ".kube" ".oh-my-zsh" ".zshrc")

IMOVIE_SOURCE_DIR="/Users/dan/Movies/iMovie Library.imovielibrary"
IMOVIE_TARGET_DIR="/Users/dan/Movies/iMovie Library.imovielibrary"


########### Github repo status ############
if [[ $CHECK_FOR_STALE_GITHUB == "true" ]]; then
  echo "############## Checking for stale Github repos ##############"
  $SCRIPTS/git-status.sh
else
  echo "############## Skipping stale Github check ##############"
fi


############## Github Backup ##############
echo "############## Backing up local Github to personal Macbook Pro ##############"
rsync -avtro --progress $GITHUB_SOURCE_DIR/* $TARGET_USER@$TARGET_IP:$GITHUB_TARGET_DIR


############## Home Dir contents ##############
echo "############## Capturing current home dir contents ##############"
ls -al $HOME > $ICLOUD_BACKUP_DIR/home-dir-contents.txt


############## Sensitive data backup ##############
# CryptoMator volume must be mounted
# CryptoMator volume is stored in ~/Documents/encrypted
if [[ $COPY_TO_CRYPTOMATOR_VOLUME == "true" ]]; then  
  echo "############## Copying encrypted files##############"
  rsync -avtro --progress $HOME/.ssh $CRYPTOMATOR_DIR/ssh
  rsync -avtro --progress $HOME/.aws $CRYPTOMATOR_DIR/aws_creds
  rsync -avtro --progress $HOME/.gnupg $CRYPTOMATOR_DIR/gnupg
else
  echo "############## Skipping encrypted files ##############"
fi

############## Backup CryptoMator to personal mac ##############
echo "############## Backing up CryptoMator to personal Macbook Pro ##############"
rsync -avtro --progress $LOCAL_ENCRYPTED_DIR $TARGET_USER@$TARGET_IP:$REMOTE_BACKUP_DIR


############## Home files backup ##############
echo "############## Backing up Home files to iCloud ##############"
for file in "${HOME_FILES[@]}"
do
  rsync -avtro --progress ~/$file $LOCAL_BACKUP_DIR/home-files-foghorn/
done

############## Homebrew apps ##############
echo "############## Capturing Homebrew apps ##############"
brew list > $LOCAL_BACKUP_DIR/homebrew-apps.txt

############## Mac installed apps ##############
echo "############## Mac installed apps  ##############"
system_profiler SPApplicationsDataType > $LOCAL_BACKUP_DIR/mac-installed-apps.txt

############## Pyenv versions ##############
echo "############## Pyenv versions ##############"
pyenv versions > $LOCAL_BACKUP_DIR/pyenv-versions.txt


############## iMovie projects ##############
echo "############## Backing up iMove projects to personal Macbook Pro ##############"
cd "/Users/dan/Movies/iMovie Library.imovielibrary"

for dir in $(ls -l | grep '^d' | awk '{print $9}' | egrep -v "^_|deleteme")
do
  rsync -avtro --progress $dir $TARGET_USER@$TARGET_IP:"${IMOVIE_TARGET_DIR}"
done
