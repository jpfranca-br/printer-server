#!/bin/bash
echo "Starting Printer Server Setup"

# Variables
GO_VERSION="1.23.4" # Update this to the latest version if needed
GO_TAR="go$GO_VERSION.linux-amd64.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/$GO_TAR"
GO_INSTALL_DIR="/usr/local/go"
WORKSPACE_DIR="$HOME/go"
SHELL_CONFIG="$HOME/.bashrc" # Update to ~/.zshrc if using Zsh

# Update and Install Prerequisites
echo "Updating system and installing prerequisites..."
sudo apt update && sudo apt install -y wget tar redis git

# Download and Install Go
echo "Downloading Go $GO_VERSION..."
wget -q $GO_DOWNLOAD_URL -O /tmp/$GO_TAR
if [ $? -ne 0 ]; then
    echo "Error downloading Go. Please check your internet connection or URL."
    exit 1
fi

echo "Installing Go..."
sudo tar -C /usr/local -xzf /tmp/$GO_TAR
if [ $? -ne 0 ]; then
    echo "Error extracting Go tarball. Check permissions or file integrity."
    exit 1
fi

# Add Go to PATH Permanently
echo "Adding Go to PATH..."
if ! grep -q "$GO_INSTALL_DIR/bin" $SHELL_CONFIG; then
    echo "export PATH=\$PATH:$GO_INSTALL_DIR/bin" >> $SHELL_CONFIG
    echo "export GOPATH=$WORKSPACE_DIR" >> $SHELL_CONFIG
    echo "export PATH=\$PATH:\$GOPATH/bin" >> $SHELL_CONFIG
fi

# Apply PATH changes for the current session
export PATH=$PATH:$GO_INSTALL_DIR/bin:$WORKSPACE_DIR/bin

# Verify Go Installation
if go version &> /dev/null; then
    echo "Go installed successfully: $(go version)"
else
    echo "Go installation failed. Please check the script and try again."
    exit 1
fi

# Create Workspace Directory
echo "Creating Go workspace..."
mkdir -p $WORKSPACE_DIR/{bin,src,pkg}

# Download source
echo "Initializing Go module source..."
rm -rf ~/printer-server && cd ~/ && git clone https://github.com/jpfranca-br/printer-server.git

# Initialize Go Module
echo "Initializing Go module..."
cd ~/printer-server
go mod init printer-server

# Install Go Dependencies
echo "Installing Go dependencies..."
go get github.com/gorilla/mux
go get github.com/go-redis/redis/v8
go install golang.org/x/lint/golint@latest
go get golang.org/x/crypto/bcrypt

# Start Redis
echo "Starting Redis..."
sudo systemctl daemon-reload # Reload systemd to handle any updates
if sudo systemctl start redis-server; then
    echo "Redis started successfully."
else
    echo "Failed to start Redis. Please check manually."
    exit 1
fi

if sudo systemctl enable redis-server; then
    echo "Redis enabled successfully."
else
    echo "Failed to enable Redis at startup. Please check manually."
fi

# Cleanup
echo "Cleaning up..."
rm /tmp/$GO_TAR

echo "Go and dependencies installed successfully!"
echo "Remember to open a new terminal or run 'source $SHELL_CONFIG' to apply PATH changes."
