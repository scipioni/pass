# GPG/SSH Key Management Makefile
# Provides basic operations for GPG key management and password store

.PHONY: help gpg-keygen ssh-keygen gpg-list gpg-list-secret gpg-agent-setup ssh-agent-setup agent-setup pass-init pass-git-init pass-git-setup pass-sync pass-add pass-show pass-list pass-remove pass-generate docs

# Default target
help:
	@echo "GPG/SSH Key Management and Password Store Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make gpg-keygen              - Generate a new GPG key"
	@echo "  make gpg-list                - List GPG public keys with basic info"
	@echo "  make gpg-list-secret         - List GPG secret keys with basic info"
	@echo "  make ssh-keygen              - Derive SSH key (Ed25519 default) from GPG key"
	@echo "  make gpg-agent-setup         - Setup GPG agent configuration"
	@echo "  make ssh-agent-setup         - Setup SSH agent configuration"
	@echo "  make agent-setup             - Setup both GPG and SSH agent configurations"
	@echo "  make pass-init               - Initialize password store"
	@echo "  make pass-git-init           - Initialize Git repository for password store"
	@echo "  make pass-git-setup          - Setup Git repository for password store (interactive)"
	@echo "  make pass-sync               - Sync password store with Git remote"
	@echo "  make pass-add NAME=path      - Add a new password entry"
	@echo "  make pass-show NAME=path     - Show a password entry"
	@echo "  make pass-list               - List all password entries"
	@echo "  make pass-remove NAME=path   - Remove a password entry"
	@echo "  make pass-generate NAME=path [LEN=16] - Generate and store a new password"
	@echo "  make docs                    - Generate documentation"
	@echo ""

# GPG Key Generation
gpg-keygen:
	@echo "Generating a new GPG key..."
	@read -p "Enter your name: " name; \
	read -p "Enter your email: " email; \
	$(CURDIR)/gpg-management/scripts/gpg-keygen.sh -n "$$name" -e "$$email"

# List GPG public keys
gpg-list:
	@echo "Listing GPG public keys with expiration dates..."
	@echo "TYPE     KEYID              CREATED      EXPIRES" && \
	gpg --list-keys --keyid-format LONG --with-colons | awk -F: '/^pub:/ { \
		keytype=$$3; \
		keyid=$$5; \
		created=$$6; \
		expires=$$7; \
		gsub(/0x/, "", keyid); \
		created_date = created != "" ? strftime("%Y-%m-%d", created) : ""; \
		expires_date = expires != "" ? (expires == "0" ? "never" : strftime("%Y-%m-%d", expires)) : "none"; \
		printf "%-8s %-18s %-12s %s\n", keytype, keyid, created_date, expires_date; \
	}'

# List GPG secret keys
gpg-list-secret:
	@echo "Listing GPG secret keys with expiration dates..."
	@echo "TYPE     KEYID              CREATED      EXPIRES" && \
	gpg --list-secret-keys --keyid-format LONG --with-colons | awk -F: '/^sec:/ { \
		keytype=$$3; \
		keyid=$$5; \
		created=$$6; \
		expires=$$7; \
		gsub(/0x/, "", keyid); \
		created_date = created != "" ? strftime("%Y-%m-%d", created) : ""; \
		expires_date = expires != "" ? (expires == "0" ? "never" : strftime("%Y-%m-%d", expires)) : "none"; \
		printf "%-8s %-18s %-12s %s\n", keytype, keyid, created_date, expires_date; \
	}'

# GPG Agent Setup
gpg-agent-setup:
	@echo "Setting up GPG agent configuration..."
	@mkdir -p ~/.gnupg
	@chmod 700 ~/.gnupg
	@if [ ! -f ~/.gnupg/gpg-agent.conf ]; then \
		echo "default-cache-ttl 600" > ~/.gnupg/gpg-agent.conf; \
		echo "max-cache-ttl 7200" >> ~/.gnupg/gpg-agent.conf; \
		echo "pinentry-program $(shell which pinentry 2>/dev/null || echo /usr/bin/pinentry)" >> ~/.gnupg/gpg-agent.conf; \
		echo "enable-ssh-support" >> ~/.gnupg/gpg-agent.conf; \
		echo "GPG agent configuration created at ~/.gnupg/gpg-agent.conf"; \
	else \
		echo "GPG agent configuration already exists at ~/.gnupg/gpg-agent.conf"; \
	fi
	@echo "Reloading GPG agent..."
	@gpg-connect-agent reloadagent /bye 2>/dev/null || echo "Could not reload GPG agent, it may not be running"

# SSH Agent Setup
ssh-agent-setup:
	@echo "Setting up SSH agent configuration..."
	@mkdir -p ~/.ssh
	@chmod 700 ~/.ssh
	@echo "Adding SSH agent configuration to shell profiles..."
	@echo "You will need to add SSH agent startup to your shell profile."
	@echo "For bash, add to ~/.bashrc:"
	@echo "  if [ -f ~/.ssh/agent-startup ]; then"
	@echo "    . ~/.ssh/agent-startup"
	@echo "  fi"
	@echo ""
	@echo "For zsh, add to ~/.zshrc:"
	@echo "  if [ -f ~/.ssh/agent-startup ]; then"
	@echo "    . ~/.ssh/agent-startup"
	@echo "  fi"
	@echo ""
	@echo "For fish, add to ~/.config/fish/config.fish:"
	@echo "  if test -f ~/.ssh/agent-startup"
	@echo "    source ~/.ssh/agent-startup"
	@echo "  end"

# Agent Setup (both GPG and SSH)
agent-setup:
	@$(MAKE) gpg-agent-setup
	@$(MAKE) ssh-agent-setup

# SSH Key Generation from GPG
ssh-keygen:
	@echo "Deriving SSH key from GPG key..."
	@read -p "Enter GPG key ID or email: " keyid; \
	read -p "Enter SSH key path (default: ~/.ssh/id_ed25519_from_gpg): " path; \
	read -p "Enter SSH key type (ed25519, rsa, ecdsa) [default: ed25519]: " type; \
	if [ -z "$$path" ]; then path="~/.ssh/id_ed25519_from_gpg"; fi; \
	if [ -z "$$type" ]; then type="ed25519"; fi; \
	$(CURDIR)/gpg-management/scripts/gpg-ssh-keygen.sh -k "$$keyid" -p "$$path" -t "$$type"

# Password Store Initialization
pass-init:
	@echo "Initializing password store..."
	@pass init

# Password Store Git Initialization
pass-git-init:
	@echo "Initializing Git repository for password store..."
	@read -p "Enter Git remote URL: " remote; \
	if [ -d ~/.password-store ]; then \
		cd ~/.password-store && \
		git init && \
		git remote add origin "$$remote" && \
		echo "Initialized Git repository for password store"; \
	else \
		echo "Error: Password store not initialized. Run 'make pass-init' first."; \
	fi

# Password Store Git Setup (Interactive)
pass-git-setup:
	@echo "Setting up Git repository for password store..."
	@$(CURDIR)/gpg-management/scripts/pass-git-setup.sh

# Password Store Git Sync
pass-sync:
	@echo "Syncing password store with Git remote..."
	@if [ -d ~/.password-store ]; then \
		cd ~/.password-store && \
		git add . && \
		git commit -m "Sync password store updates" && \
		git pull --rebase && \
		git push origin master; \
	else \
		echo "Error: Password store not initialized or Git not set up."; \
	fi

# Add a password entry
pass-add:
	@echo "Adding a new password entry..."
	@if [ -z "$(NAME)" ]; then \
		read -p "Enter path for new password entry: " name; \
	else \
		name=$(NAME); \
	fi; \
	if [ -n "$$name" ]; then \
		pass insert "$$name"; \
	else \
		echo "No name provided. Use: make pass-add NAME=path"; \
	fi

# Show a password entry
pass-show:
	@echo "Showing password entry..."
	@if [ -z "$(NAME)" ]; then \
		read -p "Enter path for password entry: " name; \
	else \
		name=$(NAME); \
	fi; \
	if [ -n "$$name" ]; then \
		pass show "$$name"; \
	else \
		echo "No name provided. Use: make pass-show NAME=path"; \
	fi

# List all password entries
pass-list:
	@echo "Listing all password entries..."
	@pass list

# Remove a password entry
pass-remove:
	@echo "Removing password entry..."
	@if [ -z "$(NAME)" ]; then \
		read -p "Enter path for password entry to remove: " name; \
	else \
		name=$(NAME); \
	fi; \
	if [ -n "$$name" ]; then \
		pass rm -r "$$name"; \
	else \
		echo "No name provided. Use: make pass-remove NAME=path"; \
	fi

# Generate and store a new password
pass-generate:
	@echo "Generating and storing a new password..."
	@if [ -z "$(NAME)" ]; then \
		read -p "Enter path for new password entry: " name; \
	else \
		name=$(NAME); \
	fi; \
	if [ -z "$(LEN)" ]; then \
		len=16; \
	else \
		len=$(LEN); \
	fi; \
	if [ -n "$$name" ]; then \
		pass generate "$$name" $$len; \
	else \
		echo "No name provided. Use: make pass-generate NAME=path [LEN=16]"; \
	fi

# Generate documentation
docs:
	@echo "Documentation is available in the docs directory."
	@echo "See README.md and other documentation files in gpg-management/docs/"