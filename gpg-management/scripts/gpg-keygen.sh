#!/bin/bash

# GPG Key Generation Script
# This script generates a new GPG key with configurable parameters

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
KEY_TYPE="rsa"
KEY_LENGTH="4096"
EXPIRE_DATE="0"  # 0 means no expiration
NAME_REAL=""
EMAIL_ADDRESS=""
PASSPHRASE=""
KEY_SUBPACKET=""
KEY_SUBPACKET_LENGTH=""

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -t TYPE          Key type (rsa, ecdsa, ed25519) [default: rsa]"
    echo "  -l LENGTH        Key length for RSA (1024, 2048, 3072, 4096) or curve for ECC [default: 4096]"
    echo "  -e EMAIL         Email address for the key"
    echo "  -n NAME          Real name for the key"
    echo "  -p PASSPHRASE    Passphrase for the key (optional, will prompt if not provided)"
    echo "  -x DAYS          Expiration period in days (0 for no expiration) [default: 0]"
    echo "  -h               Display this help message"
    echo ""
    echo "Example: $0 -n \"John Doe\" -e \"john.doe@example.com\" -p \"mypass\""
    exit 1
}

# Parse command line arguments
while getopts "t:l:e:n:p:x:h" opt; do
    case $opt in
        t) KEY_TYPE="$OPTARG" ;;
        l) KEY_LENGTH="$OPTARG" ;;
        e) EMAIL_ADDRESS="$OPTARG" ;;
        n) NAME_REAL="$OPTARG" ;;
        p) PASSPHRASE="$OPTARG" ;;
        x) EXPIRE_DATE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check for required parameters
if [ -z "$NAME_REAL" ] || [ -z "$EMAIL_ADDRESS" ]; then
    echo -e "${RED}Error: Name and email are required.${NC}"
    usage
fi

# Validate key type
case $KEY_TYPE in
    rsa|ecdsa|ed25519)
        if [ "$KEY_TYPE" = "rsa" ] && [ -z "$KEY_LENGTH" ]; then
            KEY_LENGTH=4096
        fi
        ;;
    *)
        echo -e "${RED}Error: Unsupported key type: $KEY_TYPE${NC}"
        exit 1
        ;;
esac

# Validate key length for RSA
if [ "$KEY_TYPE" = "rsa" ]; then
    case $KEY_LENGTH in
        1024|2048|3072|4096)
            ;;
        *)
            echo -e "${RED}Error: Unsupported RSA key length: $KEY_LENGTH${NC}"
            exit 1
            ;;
    esac
fi

# Validate expiration date
if ! [[ "$EXPIRE_DATE" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Expiration date must be a number.${NC}"
    exit 1
fi

# Prompt for passphrase if not provided
if [ -z "$PASSPHRASE" ]; then
    echo -e "${YELLOW}Enter passphrase for the new key:${NC}"
    read -s -p "Passphrase: " PASSPHRASE
    echo
    read -s -p "Confirm Passphrase: " PASSPHRASE_CONFIRM
    echo
    
    if [ "$PASSPHRASE" != "$PASSPHRASE_CONFIRM" ]; then
        echo -e "${RED}Error: Passphrases do not match.${NC}"
        exit 1
    fi
fi

# Create a temporary file for GPG batch input
BATCH_FILE=$(mktemp)
trap 'rm -f "$BATCH_FILE"' EXIT

# Define key expiration based on input
if [ "$EXPIRE_DATE" = "0" ]; then
    EXPIRATION_LINE="0"
else
    EXPIRATION_LINE="$EXPIRE_DATE"
fi

# Write batch configuration to temporary file
cat > "$BATCH_FILE" << EOF
Key-Type: $KEY_TYPE
Key-Length: $KEY_LENGTH
Name-Real: $NAME_REAL
Name-Email: $EMAIL_ADDRESS
Expire-Date: $EXPIRATION_LINE
Passphrase: $PASSPHRASE
%commit
EOF

echo -e "${GREEN}Generating GPG key...${NC}"

# Generate the GPG key using batch mode
gpg --batch --generate-key "$BATCH_FILE"

# Check if key generation was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}GPG key successfully generated!${NC}"
    
    # List the new key
    echo -e "${GREEN}New key details:${NC}"
    gpg --list-secret-keys --keyid-format LONG | grep -A 5 -B 5 "$EMAIL_ADDRESS"
else
    echo -e "${RED}Error: Failed to generate GPG key.${NC}"
    exit 1
fi

echo -e "${GREEN}Key generation complete!${NC}"