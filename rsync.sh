# TARGET_IP="192.168.0.64" # Personal
TARGET_IP="192.168.0.65" # New Mac

rsync -avtro /Users/dan/github dan@$TARGET_IP:/Users/dan/Foghorn-Backup/
# rsync -avtro /Users/dan/.zsh_history dan@$TARGET_IP:/Users/dan/Foghorn-Backup/.zsh_history
# rsync -avtro /Users/dan/.ssh dan@$TARGET_IP:/Users/dan/Foghorn-Backup/