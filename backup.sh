TARGET_IP="192.168.0.228"
TARGET_USER="dan"
REMOTE_BACKUP_DIR="/Users/dan/Foghorn-Backup/"
LOCAL_BACKUP_DIR="/Users/dan/Documents/backup"

echo "############## Backing up local Github to personal Macbook Pro ##############"
GITHUB_SOURCE_DIR="/Users/dan/github"
GITHUB_TARGET_DIR="/Users/dan/github-public/"
rsync -avtro --progress "${GITHUB_SOURCE_DIR}/*" $TARGET_USER@$TARGET_IP:$GITHUB_TARGET_DIR

echo "############## Capturing current home dir contents ##############"
ICLOUD_BACKUP_DIR="/Users/dan/Documents/backup"
ls -al $HOME > $ICLOUD_BACKUP_DIR/home-dir-contents.txt

# CryptoMator volume must be mounted
LOCAL_ENCRYPTED_DIR="/Volumes/encrypted"
echo "############## Copying encrypted files##############"
rsync -avtro --progress $HOME/.ssh $LOCAL_ENCRYPTED_DIR/ssh
# CryptoMator volume is stored in ~/Documents/encrypted


HOME_FILES=(".zsh_history" ".viminfo")
echo "############## Backing up Home files to iCloud ##############"
for file in "${HOME_FILES[@]}"
do
  rsync -avtro --progress $file $LOCAL_BACKUP_DIR/home-files-foghorn
done

echo "############## Capturing Homebrew apps ##############"
brew list > $LOCAL_BACKUP_DIR/homebrew-apps.txt

# TODO: 
#  - iTerm2 settings
#  - .zshrc
