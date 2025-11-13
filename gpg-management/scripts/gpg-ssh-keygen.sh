#!/bin/bash

# GPG to SSH Key Derivation Script
# This script extracts an SSH key from an existing GPG key

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
    echo "  -k KEY_ID        GPG key ID or email to derive SSH key from"
    echo "  -p PATH          Path for the SSH key [default: ~/.ssh/id_ed25519_from_gpg]"
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
if ! gpg --list-secret-keys --keyid-format LONG | grep -q "$GPG_KEY_ID"; then
    echo -e "${RED}Error: GPG key with ID/email '$GPG_KEY_ID' not found.${NC}"
    exit 1
fi

# Get the keygrip of the subkey (encryption subkey)
KEYGRIP=$(gpg --list-secret-keys --with-keygrip "$GPG_KEY_ID" | grep -A 1 "ssb" | grep -o "[A-Z0-9]\{40\}" | head -n 1)

if [ -z "$KEYGRIP" ]; then
    echo -e "${RED}Error: Could not find a suitable subkey for SSH key derivation.${NC}"
    exit 1
fi

# Set SSH key comment if not provided
if [ -z "$SSH_KEY_COMMENT" ]; then
    SSH_KEY_COMMENT="ssh-$(gpg --list-secret-keys --keyid-format LONG "$GPG_KEY_ID" | grep -A 1 "sec\|ssb" | tail -n +2 | head -n 1 | xargs)"
fi

echo -e "${GREEN}Deriving SSH key (type: $SSH_KEY_TYPE) from GPG key...${NC}"

# Create SSH directory if it doesn't exist
SSH_DIR=$(dirname "$SSH_KEY_PATH")
mkdir -p "$SSH_DIR"

# Export the SSH key using gpg-agent
if [ -f "$SSH_KEY_PATH" ]; then
    read -p "SSH key file exists. Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
fi

# Use gpg-agent to export the SSH key
gpg-agent --export-ssh-key "$GPG_KEY_ID" > "$SSH_KEY_PATH"

# Set appropriate permissions for SSH private key
chmod 600 "$SSH_KEY_PATH"

# Generate the public key file
ssh-keygen -y -f "$SSH_KEY_PATH" > "$SSH_KEY_PATH.pub"

# Output success message
echo -e "${GREEN}SSH key (type: $SSH_KEY_TYPE) successfully derived from GPG key!${NC}"
echo -e "${GREEN}Private key: $SSH_KEY_PATH${NC}"
echo -e "${GREEN}Public key: $SSH_KEY_PATH.pub${NC}"

# Show the SSH public key content
echo -e "${GREEN}SSH Public Key:${NC}"
cat "$SSH_KEY_PATH.pub"

echo -e "${GREEN}SSH key derivation complete!${NC}"

# Optionally add the SSH key to the SSH agent
echo -e "${YELLOW}Would you like to add this key to your SSH agent? (y/N): ${NC}"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh-add "$SSH_KEY_PATH"
    echo -e "${GREEN}Key added to SSH agent.${NC}"
fi