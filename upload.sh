#!/bin/bash

TARGET_SIZE=${TARGET_SIZE:-100000000}  # 100MB default
CHUNK_SIZE=${CHUNK_SIZE:-95000000}    # slightly less than 100MB default
REPO_DIR=${REPO_DIR:-'./'}  # This sets the current directory as default
FILE_TO_MONITOR="${REPO_DIR}/ptr.txt"
TEMP_FILE="${REPO_DIR}/temp_ptr.txt"
LAST_PUSHED_SIZE=0
LOG_FILE="${REPO_DIR}/upload_log.txt"

function log_message {
    echo "$(date +%Y-%m-%d\ %H:%M:%S) - $1" | tee -a $LOG_FILE
}

# Check for presence of ptr.txt
if [[ ! -f $FILE_TO_MONITOR ]]; then
    log_message "Error: $FILE_TO_MONITOR not found!"
    exit 1
fi

# Git setup for SSH (if required)
PRIVATE_KEY_PATH="~/.ssh/id_rsa"
echo "$PRIVATE_SSH_KEY" > $PRIVATE_KEY_PATH
chmod 600 $PRIVATE_KEY_PATH
eval $(ssh-agent -s)
ssh-add $PRIVATE_KEY_PATH

# Initialize a new git repository and set the remote
cd "$REPO_DIR"
git init
if ! git remote | grep -q 'origin'; then
    git remote add origin git@github.com:RepoRascal/Scan.git
fi


while true; do
  if ! command -v rsync &> /dev/null; then
      log_message "rsync command not found! Installing..."
      sudo apt-get update && sudo apt-get install -y rsync
  fi

  # Using rsync to copy only the new content
  rsync --inplace --size-only --append "$FILE_TO_MONITOR" "$TEMP_FILE"

  CURRENT_SIZE=$(stat -c%s "$TEMP_FILE")

  if [[ $((CURRENT_SIZE - LAST_PUSHED_SIZE)) -ge $TARGET_SIZE ]]; then
    CHUNK_NAME="ptr_chunk_$(date +%Y%m%d%H%M%S)"
    tail -c +$((LAST_PUSHED_SIZE + 1)) "$TEMP_FILE" | head -c $CHUNK_SIZE > "${REPO_DIR}/$CHUNK_NAME"
    LAST_PUSHED_SIZE=$((LAST_PUSHED_SIZE + CHUNK_SIZE))

    git add "$CHUNK_NAME"
    git commit -m "Add new chunk of ptr.txt"
    if git push origin main; then
        log_message "Successfully pushed $CHUNK_NAME to GitHub."
    else
        log_message "Failed to push $CHUNK_NAME to GitHub!"
    fi
  fi

  sleep 60
done
