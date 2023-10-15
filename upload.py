#!/bin/bash

CHUNK_SIZE=95000000  # 95MB

# CircleCI will check out your repository to the folder "~/project"
# So, your repository content will be in that directory.
REPO_DIR="~/project"

FILE="${REPO_DIR}/ptr.txt"

# Identify the last line of the first uploaded chunk.
LAST_LINE=$(tail -n 1 "${REPO_DIR}/path/to/the/first/uploaded/chunk")

# Find the line number of that line in ptr.txt.
LINE_NUMBER=$(grep -nF "$LAST_LINE" "$FILE" | cut -d: -f1)

# Extract everything up to that line and save to a temporary chunk.
head -n "$LINE_NUMBER" "$FILE" > "${REPO_DIR}/initial_chunk"

# Split the initial_chunk into smaller files of 95MB each.
cd "$REPO_DIR"
split -b "$CHUNK_SIZE" -d --additional-suffix=.txt initial_chunk older_chunk_

# Now, commit and push the older chunks.
git add older_chunk_*
git commit -m "Add older chunks of ptr.txt"
git push origin main

# Clean up the initial_chunk.
rm initial_chunk
