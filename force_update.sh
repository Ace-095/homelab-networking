#!/bin/bash

# Option 1: Hardcode your token here (Uncomment the line below and add your token)
GITHUB_TOKEN="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-homelab"

# Option 2: Securely prompt for the token when running the script (Leave this as is if Option 1 is commented out)
if [ -z "$GITHUB_TOKEN" ]; then
    read -s -p "Enter your GitHub Personal Access Token (Key): " GITHUB_TOKEN
    echo ""
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: Token cannot be empty."
    exit 1
fi

echo "Staging all changes..."
git add .

echo "Committing changes..."
# Commits with a timestamp. If there are no changes, git commit might fail, but that's fine, we still want to push.
git commit -m "Automated forceful update: $(date)" || echo "No new changes to commit. Proceeding to push..."

# Set the remote URL temporarily to include the token for authentication
git remote set-url origin "https://Ace-095:${GITHUB_TOKEN}@github.com/Ace-095/homelab-networking.git"

echo "Force pushing to GitHub..."
# Force push to the main branch
git push -f origin main

# Clean up the remote URL to remove the token from git config for security
git remote set-url origin "https://github.com/Ace-095/homelab-networking.git"

echo "Update complete!"



# cd /home/ace/PROJECTS/MAIN/ACEHOMELAB/homelab-networking
# ./force_update.sh
