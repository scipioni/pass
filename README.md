# GPG/SSH Key Management and Password Store System

This system provides a comprehensive solution for managing GPG keys, deriving SSH keys from GPG keys, and maintaining a team password store with Git synchronization.

## Overview

This system includes:

1. **GPG Key Generation Script**: Creates new GPG keys with configurable parameters
2. **SSH Key Derivation Script**: Extracts SSH keys from existing GPG keys (defaults to Ed25519)
3. **Password Store Integration**: Uses `pass` (password-store) for team password management
4. **Git Synchronization**: Syncs password store with a remote Git repository
5. **Makefile**: Provides convenient command-line operations

## Prerequisites

Before using this system, ensure you have the following tools installed:

- `gpg` (GNU Privacy Guard) - for key generation and management
- `pass` (password-store) - for password management
- `ssh` - for SSH key usage
- `git` - for version control and team synchronization
- `make` - for running Makefile targets

### Installation (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install gnupg pass git openssh-client make
```

### Installation (macOS)
```bash
brew install gnupg pass git make
```

## Quick Start

1. **Generate a GPG key**
   ```bash
   make gpg-keygen
   ```

2. **Derive an SSH key from your GPG key**
   ```bash
   make ssh-keygen
   ```

3. **Initialize your password store**
   ```bash
   make pass-init
   ```

4. **Add a password**
   ```bash
   make pass-add NAME=websites/github
   ```

5. **Generate a new password**
   ```bash
   make pass-generate NAME=websites/aws LEN=20
   ```

6. **List your GPG keys**
   ```bash
   make gpg-list
   ```

## Available Commands

Run `make help` to see all available commands:

```
make gpg-keygen              - Generate a new GPG key
make gpg-list                - List GPG public keys with basic info
make gpg-list-secret         - List GPG secret keys with basic info
make ssh-keygen              - Derive SSH key (Ed25519 default) from GPG key
make pass-init               - Initialize password store
make pass-git-init           - Initialize Git repository for password store
make pass-git-setup          - Setup Git repository for password store (interactive)
make pass-sync               - Sync password store with Git remote
make pass-add NAME=path      - Add a new password entry
make pass-show NAME=path     - Show a password entry
make pass-list               - List all password entries
make pass-remove NAME=path   - Remove a password entry
make pass-generate NAME=path [LEN=16] - Generate and store a new password
make docs                    - Generate documentation
```

## GPG Key Management

### Generate a New GPG Key

Use the `gpg-keygen.sh` script:

```bash
./gpg-management/scripts/gpg-keygen.sh -n "Your Name" -e "your.email@example.com" -p "your-passphrase"
```

#### Options:
- `-t TYPE`: Key type (rsa, ecdsa, ed25519) [default: rsa]
- `-l LENGTH`: Key length for RSA (1024, 2048, 3072, 4096) or curve for ECC [default: 4096]
- `-e EMAIL`: Email address for the key
- `-n NAME`: Real name for the key
- `-p PASSPHRASE`: Passphrase for the key (optional, will prompt if not provided)
- `-x DAYS`: Expiration period in days (0 for no expiration) [default: 0]
- `-h`: Display help message

#### Using Makefile:
```bash
make gpg-keygen
```
This will prompt for name and email.

### List GPG Keys

List public keys with creation and expiration dates:
```bash
make gpg-list
```

List secret keys with creation and expiration dates:
```bash
make gpg-list-secret
```

## SSH Key Derivation

### Derive SSH Key from GPG Key

Use the `gpg-ssh-keygen.sh` script (now defaults to Ed25519):

```bash
./gpg-management/scripts/gpg-ssh-keygen.sh -k "your.email@example.com" -p "~/.ssh/id_ed25519_from_gpg" -t "ed25519"
```

#### Options:
- `-k KEY_ID`: GPG key ID or email to derive SSH key from
- `-p PATH`: Path for the SSH key [default: ~/.ssh/id_ed25519_from_gpg]
- `-t TYPE`: SSH key type (ed25519, rsa, ecdsa) [default: ed25519]
- `-c COMMENT`: Comment for the SSH key [default: derived from GPG key]
- `-h`: Display help message

#### Using Makefile:
```bash
make ssh-keygen
```
This will prompt for the GPG key ID, SSH key path, and SSH key type.

### Add SSH Key to SSH Agent

```bash
ssh-add ~/.ssh/id_ed25519_from_gpg
```

### Configure SSH to Use the Key

Add to your `~/.ssh/config`:

```
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519_from_gpg
```

## Password Store Management

### Initialize Password Store

With a GPG key:

```bash
# If you have a single GPG key
pass init

# Or specify a specific key
pass init your.email@example.com
```

Or using Makefile:

```bash
make pass-init
```

### Basic Password Store Operations

#### Add a Password
```bash
make pass-add NAME=websites/github
```

#### Generate and Store a New Password
```bash
make pass-generate NAME=services/database LEN=20
```

#### Show a Password
```bash
make pass-show NAME=websites/github
```

#### List All Passwords
```bash
make pass-list
```

#### Remove a Password
```bash
make pass-remove NAME=websites/github
```

### Advanced Operations

#### Copy Password to Clipboard
```bash
pass -c websites/github
```

#### Show Password Details (without copying to clipboard)
```bash
pass show websites/github
```

#### Edit an Existing Password
```bash
pass edit websites/github
```

## Team Collaboration

### Setup Git Repository for Password Store

1. **Create a private Git repository** (on GitHub, GitLab, etc.)

2. **Initialize Git for password store**:
   ```bash
   make pass-git-init
   ```
   This will prompt for the Git remote URL.

3. **Interactive setup** (recommended for team setups):
   ```bash
   make pass-git-setup
   ```

### Sync Password Store

#### Push Changes:
```bash
make pass-sync
```

#### Pull Changes:
```bash
cd ~/.password-store
git pull
```

### Team Setup Instructions

For team members to join the password store:

1. **Clone the repository**:
   ```bash
   git clone <your-git-repo-url> ~/.password-store
   ```

2. **Import the GPG public key** of the team:
   ```bash
   gpg --import team-public-keys.asc
   ```

3. **Set up your own GPG key** in the store:
   ```bash
   pass init your.email@example.com
   ```

### Multiple Recipients

To encrypt passwords for multiple team members:

1. **List current recipients**:
   ```bash
   pass show -c .gpg-id
   ```

2. **Add a new recipient**:
   ```bash
   echo "new.member@email.com" >> ~/.password-store/.gpg-id
   pass git push
   ```

3. **Re-encrypt the entire store** for the new recipient:
   ```bash
   pass git reencrypt
   ```

## Security Best Practices

### GPG Key Security

1. **Use a strong passphrase**: At least 12 characters with mixed case, numbers, and symbols.

2. **Enable GPG agent**: This securely handles your passphrase and prevents repeated prompts.
   ```bash
   gpgconf --enable-agent
   ```

3. **Backup your keys**: Export your keys to a secure location.
   ```bash
   # Export private key
   gpg --export-secret-keys your.email@example.com > private-key-backup.gpg
   # Export public key
   gpg --export your.email@example.com > public-key-backup.gpg
   ```

4. **Use subkeys**: When possible, create subkeys for specific purposes to keep your primary key secure offline.

### Password Store Security

1. **Use strong, unique passwords** for each service.

2. **Regular updates**: Update passwords periodically for critical services.

3. **Secure access**: Only grant access to team members who need it.

4. **Monitor access**: Keep track of who has access to the password repository.

### SSH Key Security

1. **Use SSH key passphrases**: Even though derived from GPG, protect your SSH keys with a passphrase.

2. **Proper file permissions**: Ensure SSH key files have restrictive permissions (600).

3. **Don't reuse keys**: Use different SSH keys for different contexts when possible.

4. **Use Ed25519 keys**: More secure and faster than RSA (now the default).

### Git Repository Security

1. **Use private repositories**: Ensure your password store Git repository is private.

2. **Audit access**: Regularly review who has access to the repository.

3. **Secure communication**: Use HTTPS or SSH for Git operations, never HTTP.

## Troubleshooting

### GPG Agent Issues

If GPG isn't prompting for passwords, start the agent:
```bash
gpg-agent --daemon
```

### Git Credential Issues

If pushing to Git fails due to authentication:
```bash
# Configure Git credentials
git config --global credential.helper store
```

### Password Store Not Working

Verify your GPG key is properly configured:
```bash
gpg --list-secret-keys
```

### SSH Key Not Working

Test the SSH key:
```bash
ssh -T git@github.com
```

## Advanced Configuration

### GPG Configuration

You can customize GPG behavior by creating `~/.gnupg/gpg.conf`:

```
personal-cipher-preferences AES256 AES192 AES
personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed
default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
cert-digest-algo SHA512
s2k-digest-algo SHA512
s2k-cipher-algo AES256
default-key [your-key-id]
```

### GPG Agent Configuration

Create `~/.gnupg/gpg-agent.conf`:

```
default-cache-ttl 1800
max-cache-ttl 7200
```

After changing agent configuration, reload:
```bash
gpg-connect-agent reloadagent /bye
```

## License

This project is made available under the MIT License.