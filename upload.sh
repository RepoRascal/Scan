#!/bin/bash

TARGET_SIZE=${TARGET_SIZE:-100000000}  # 100MB default
CHUNK_SIZE=${CHUNK_SIZE:-95000000}    # slightly less than 100MB default
REPO_DIR=${REPO_DIR:-'./'}  # This sets the current directory as default
FILE_TO_MONITOR="ptr.txt"
TEMP_FILE="temp_ptr.txt"
LAST_PUSHED_SIZE=0
LOG_FILE="upload_log.txt"

function log_message {
    echo "$(date +%Y-%m-%d\ %H:%M:%S) - $1" | tee -a $LOG_FILE
}

# Git setup for SSH (if required)
# Assuming you've added the private key as an environment variable PRIVATE_SSH_KEY in CircleCI
PRIVATE_KEY_PATH="id_rsa"
echo "$PRIVATE_SSH_KEY" > $PRIVATE_KEY_PATH
chmod 600 $PRIVATE_KEY_PATH
eval $(ssh-agent -s)
ssh-add $PRIVATE_KEY_PATH

# Initialize a new git repository and set the remote
cd "$REPO_DIR"
git init
# Avoiding error if remote already exists
if ! git remote | grep -q 'origin'; then
    git remote add origin https://github.com/RepoRascal/Scan.git
fi

while true; do
  # Check if rsync is installed
  if ! command -v rsync &> /dev/null; then
      log_message "rsync command not found! Installing..."
      sudo apt-get update && sudo apt-get install -y rsync
  fi

  # Using rsync to copy only the new content
  rsync --inplace --size-only --append "$FILE_TO_MONITOR" "$TEMP_FILE"

  CURRENT_SIZE=$(stat -c%s "$TEMP_FILE")

  # Check if the file size minus what we last pushed is greater than our target
  if [[ $((CURRENT_SIZE - LAST_PUSHED_SIZE)) -ge $TARGET_SIZE ]]; then
    CHUNK_NAME="ptr_chunk_$(date +%Y%m%d%H%M%S)"
    tail -c +$((LAST_PUSHED_SIZE + 1)) "$TEMP_FILE" | head -c $CHUNK_SIZE > "${REPO_DIR}/$CHUNK_NAME"

    LAST_PUSHED_SIZE=$((LAST_PUSHED_SIZE + CHUNK_SIZE))

    # Now commit and push
    git add "$CHUNK_NAME"
    git commit -m "Add new chunk of ptr.txt"
    if git push origin main; then
        log_message "Successfully pushed $CHUNK_NAME to GitHub."
    else
        log_message "Failed to push $CHUNK_NAME to GitHub!"
    fi
  fi

  sleep 60  # Wait for a minute before checking again
done
