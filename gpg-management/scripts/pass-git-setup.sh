#!/bin/bash

# Pass Git Repository Setup Script
# This script helps set up a Git repository for sharing password stores in a team

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PASS_DIR="$HOME/.password-store"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_NAME="team-password-store"
REPO_DIR="$HOME/$REPO_NAME"

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -u URL           Git remote URL for the password store repository"
    echo "  -n NAME          Name for the local repository directory [default: team-password-store]"
    echo "  -h               Display this help message"
    echo ""
    echo "Example: $0 -u \"git@github.com:team/password-store.git\" -n \"my-password-store\""
    exit 1
}

# Parse command line arguments
while getopts "u:n:h" opt; do
    case $opt in
        u) GIT_REMOTE_URL="$OPTARG" ;;
        n) REPO_NAME="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check if pass is installed
if ! command -v pass &> /dev/null; then
    echo -e "${RED}Error: 'pass' is not installed. Please install password-store first.${NC}"
    exit 1
fi

# Initialize password store if not already done
if [ ! -d "$PASS_DIR" ]; then
    echo -e "${YELLOW}Password store not initialized. Initializing...${NC}"
    
    # List available GPG keys
    echo -e "${GREEN}Available GPG keys:${NC}"
    gpg --list-secret-keys --keyid-format LONG
    
    read -p "Enter the GPG key ID or email to use for password store: " GPG_KEY
    if [ -z "$GPG_KEY" ]; then
        echo -e "${RED}Error: GPG key is required.${NC}"
        exit 1
    fi
    
    pass init "$GPG_KEY"
    echo -e "${GREEN}Password store initialized with key: $GPG_KEY${NC}"
else
    echo -e "${GREEN}Password store already exists at $PASS_DIR${NC}"
fi

# Check if Git remote URL is provided
if [ -z "$GIT_REMOTE_URL" ]; then
    echo -e "${YELLOW}No Git remote URL provided. You can initialize an empty Git repo or clone an existing one.${NC}"
    echo "1. Initialize new Git repository"
    echo "2. Clone existing repository"
    read -p "Choose an option (1 or 2): " choice
    
    case $choice in
        1)
            # Initialize new Git repository
            if [ -d "$PASS_DIR/.git" ]; then
                echo -e "${YELLOW}Git repository already exists in password store.${NC}"
            else
                echo -e "${GREEN}Initializing new Git repository for password store...${NC}"
                cd "$PASS_DIR"
                git init
                echo -e "${GREEN}Git repository initialized.${NC}"
                
                # Prompt for remote URL after initialization
                read -p "Enter Git remote URL: " GIT_REMOTE_URL
                if [ -n "$GIT_REMOTE_URL" ]; then
                    git remote add origin "$GIT_REMOTE_URL"
                    echo -e "${GREEN}Remote origin added: $GIT_REMOTE_URL${NC}"
                fi
            fi
            ;;
        2)
            # Clone existing repository
            read -p "Enter Git remote URL to clone: " GIT_REMOTE_URL
            if [ -z "$GIT_REMOTE_URL" ]; then
                echo -e "${RED}Error: Git remote URL is required.${NC}"
                exit 1
            fi
            
            # If password store already exists, warn user
            if [ -d "$PASS_DIR" ] && [ -n "$(ls -A "$PASS_DIR")" ]; then
                echo -e "${YELLOW}Warning: Password store directory is not empty.${NC}"
                read -p "This will replace your current password store. Continue? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                    exit 0
                fi
            fi
            
            echo -e "${GREEN}Cloning password store repository...${NC}"
            cd "$HOME"
            git clone "$GIT_REMOTE_URL" "$PASS_DIR"
            echo -e "${GREEN}Password store repository cloned.${NC}"
            ;;
        *)
            echo -e "${RED}Invalid option. Exiting.${NC}"
            exit 1
            ;;
    esac
else
    # Git remote URL provided via command line
    if [ -d "$PASS_DIR/.git" ]; then
        echo -e "${YELLOW}Git repository already exists in password store.${NC}"
        echo -e "${YELLOW}Adding provided remote URL...${NC}"
        cd "$PASS_DIR"
        git remote set-url origin "$GIT_REMOTE_URL" || git remote add origin "$GIT_REMOTE_URL"
        echo -e "${GREEN}Remote origin set to: $GIT_REMOTE_URL${NC}"
    else
        echo -e "${GREEN}Initializing new Git repository for password store...${NC}"
        cd "$PASS_DIR"
        git init
        git remote add origin "$GIT_REMOTE_URL"
        echo -e "${GREEN}Git repository initialized with remote: $GIT_REMOTE_URL${NC}"
    fi
fi

# Setup git configuration for password store
if [ -d "$PASS_DIR/.git" ]; then
    cd "$PASS_DIR"
    
    # Configure git user (if not already configured)
    if ! git config --get user.name > /dev/null; then
        read -p "Enter your Git username: " git_username
        git config user.name "$git_username"
    fi
    
    if ! git config --get user.email > /dev/null; then
        read -p "Enter your Git email: " git_email
        git config user.email "$git_email"
    fi
    
    # Set default branch to main
    git config init.defaultBranch main
fi

# Add .gitignore if it doesn't exist
if [ ! -f "$PASS_DIR/.gitignore" ]; then
    cat > "$PASS_DIR/.gitignore" << EOF
# Ignore gpg-agent socket files
.ssh/
.gnupg/

# Other potential sensitive files
*.tmp
*.temp
EOF
    echo -e "${GREEN}.gitignore created for password store.${NC}"
    
    # Add and commit the .gitignore
    if [ -d "$PASS_DIR/.git" ]; then
        cd "$PASS_DIR"
        git add .gitignore
        git commit -m "Add .gitignore for password store"
    fi
fi

echo -e "${GREEN}Git repository setup for password store complete!${NC}"

# Show status
if [ -d "$PASS_DIR/.git" ]; then
    cd "$PASS_DIR"
    echo -e "${GREEN}Current Git status:${NC}"
    git status --short
    echo -e "${GREEN}Remote URLs:${NC}"
    git remote -v
fi

echo -e "${GREEN}"
echo "Next steps:"
echo "1. Add passwords: pass insert website/github"
echo "2. Generate passwords: pass generate services/aws 16"
echo "3. Sync with team: cd ~/.password-store && git add . && git commit -m \"Update passwords\" && git push"
echo -e "${NC}"