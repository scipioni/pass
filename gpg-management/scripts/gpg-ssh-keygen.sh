#!/bin/bash

# GPG to SSH Key Derivation Script
# This script helps configure SSH to use GPG keys via GPG agent

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
GPG_KEY_ID=""
SSH_KEY_PATH="$HOME/.ssh/id_ed25519_from_gpg"
SSH_KEY_TYPE="ed25519"
SSH_KEY_COMMENT=""

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -k KEY_ID        GPG key ID or email for SSH authentication"
    echo "  -p PATH          Path for the SSH key placeholder [default: ~/.ssh/id_ed25519_from_gpg]"
    echo "  -t TYPE          SSH key type (ed25519, rsa, ecdsa) [default: ed25519]"
    echo "  -c COMMENT       Comment for the SSH key [default: derived from GPG key]"
    echo "  -h               Display this help message"
    echo ""
    echo "Example: $0 -k \"john.doe@example.com\" -p \"~/.ssh/id_gpg\" -t \"ed25519\" -c \"GPG-derived SSH key\""
    exit 1
}

# Parse command line arguments
while getopts "k:p:t:c:h" opt; do
    case $opt in
        k) GPG_KEY_ID="$OPTARG" ;;
        p) SSH_KEY_PATH="$OPTARG" ;;
        t) SSH_KEY_TYPE="$OPTARG" ;;
        c) SSH_KEY_COMMENT="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check for required parameters
if [ -z "$GPG_KEY_ID" ]; then
    echo -e "${RED}Error: GPG key ID or email is required.${NC}"
    usage
fi

# Validate SSH key type
case $SSH_KEY_TYPE in
    ed25519|rsa|ecdsa)
        ;;
    *)
        echo -e "${RED}Error: Unsupported SSH key type: $SSH_KEY_TYPE. Use ed25519, rsa, or ecdsa.${NC}"
        exit 1
        ;;
esac

# Expand tilde in SSH key path
SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# Use appropriate default path based on key type
if [ "$SSH_KEY_PATH" = "$HOME/.ssh/id_ed25519_from_gpg" ] && [ "$SSH_KEY_TYPE" != "ed25519" ]; then
    case $SSH_KEY_TYPE in
        rsa) SSH_KEY_PATH="$HOME/.ssh/id_rsa_from_gpg" ;;
        ecdsa) SSH_KEY_PATH="$HOME/.ssh/id_ecdsa_from_gpg" ;;
    esac
fi

# Check if GPG key exists
if ! gpg --list-secret-keys --keyid-format LONG "$GPG_KEY_ID" >/dev/null 2>&1; then
    echo -e "${RED}Error: GPG key with ID/email '$GPG_KEY_ID' not found.${NC}"
    exit 1
fi

# Check if the GPG key has authentication capability
KEY_LINE=$(gpg --list-secret-keys --keyid-format LONG "$GPG_KEY_ID" | grep -E "^(sec|ssb)" | head -n 1)
if echo "$KEY_LINE" | grep -q "[Aa]"; then
    echo -e "${GREEN}GPG key has authentication capability.${NC}"
else
    echo -e "${YELLOW}Warning: GPG key might not have dedicated authentication capability.${NC}"
    echo -e "${YELLOW}This could limit SSH usage. Make sure your key was created with auth subkey.${NC}"
fi

# Set SSH key comment if not provided
if [ -z "$SSH_KEY_COMMENT" ]; then
    SSH_KEY_COMMENT="ssh-$(gpg --list-secret-keys --keyid-format LONG "$GPG_KEY_ID" | grep -A 1 "sec\|ssb" | tail -n +2 | head -n 1 | xargs)"
fi

echo -e "${GREEN}Configuring SSH to use GPG key...${NC}"

# Create SSH directory if it doesn't exist
SSH_DIR=$(dirname "$SSH_KEY_PATH")
mkdir -p "$SSH_DIR"

# Check if placeholder file exists
if [ -f "$SSH_KEY_PATH" ]; then
    read -p "SSH key placeholder file exists. Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
fi

# Create a placeholder file with instructions
cat > "$SSH_KEY_PATH" << 'EOF'
# GPG-to-SSH Key Configuration
# 
# This file is a placeholder. The actual SSH key comes from your GPG key via GPG agent.
# To use this configuration:
#
# 1. Make sure GPG agent is configured with SSH support:
#    make gpg-agent-setup
#
# 2. Ensure your environment is set up:
#    export GPG_TTY=$(tty)
#    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
#
# 3. Add your GPG key to the SSH agent:
#    gpg-connect-agent reloadagent /bye
#
# 4. List available SSH keys:
#    ssh-add -l
#
# 5. Use SSH normally - it will use your GPG key
#
# For permanent setup, add these lines to your shell profile:
# export GPG_TTY=$(tty)
# export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
# source ~/.gnupg/gpg-agent.conf  # to get the SSH socket setting
EOF

# Create the public key placeholder as well
SSH_PUB_PATH="$SSH_KEY_PATH.pub"
cat > "$SSH_PUB_PATH" << EOF
# This is a placeholder for the SSH public key.
# The actual public key is accessible via the GPG agent.
# Use 'ssh-add -L' to list your SSH keys when GPG agent is properly configured.
EOF

# Set appropriate permissions for SSH private key
chmod 600 "$SSH_KEY_PATH"

# Output success message
echo -e "${GREEN}SSH configuration for GPG key completed!${NC}"
echo -e "${GREEN}Placeholder files created:${NC}"
echo -e "${GREEN}  Private key (placeholder): $SSH_KEY_PATH${NC}"
echo -e "${GREEN}  Public key (placeholder): $SSH_KEY_PATH.pub${NC}"

echo -e "${YELLOW}"
echo "To use your GPG key for SSH authentication:"
echo "1. Make sure GPG agent is configured: make gpg-agent-setup"
echo "2. Ensure your GPG agent is running with SSH support"
echo "3. Use 'ssh-add -L' to list available keys from GPG"
echo "4. Your SSH will automatically use GPG keys when properly configured"
echo -e "${NC}"

echo -e "${GREEN}Configuration complete!${NC}"