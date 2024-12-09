#!/bin/bash

echo "Starting Printer Server Setup"

# Variables
GO_VERSION="1.23.4"
GO_TAR="go$GO_VERSION.linux-amd64.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/$GO_TAR"
GO_INSTALL_DIR="/usr/local/go"
SRC_DIR="$HOME/projects/printer-server"
SHELL_CONFIG="${HOME}/.$(basename $SHELL)rc"

# Function to check the last command's status
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Update and Install Prerequisites
echo "Updating system and installing prerequisites..."
sudo apt update && sudo apt install -y wget tar redis git
check_status "Failed to install prerequisites."

# Download and Install Go
echo "Downloading Go $GO_VERSION..."
wget -q $GO_DOWNLOAD_URL -O /tmp/$GO_TAR
check_status "Error downloading Go. Please check your internet connection or URL."

echo "Installing Go..."
sudo tar -C /usr/local -xzf /tmp/$GO_TAR
check_status "Error extracting Go tarball. Check permissions or file integrity."

# Add Go to PATH Permanently
echo "Adding Go to PATH..."
if ! grep -q "$GO_INSTALL_DIR/bin" "$SHELL_CONFIG"; then
    echo "export PATH=\$PATH:$GO_INSTALL_DIR/bin" >> "$SHELL_CONFIG"
fi

# Apply PATH changes for the current session
export PATH=$PATH:$GO_INSTALL_DIR/bin

# Verify Go Installation
echo "Verifying Go installation..."
go version &> /dev/null
check_status "Go installation failed. Please check the script and try again."
echo "Go installed successfully: $(go version)"

# Create Project Directory
echo "Setting up project directory..."
mkdir -p "$SRC_DIR"
check_status "Failed to create project directory."

# Clone Source Code
echo "Cloning source code..."
rm -rf "$SRC_DIR" && git clone https://github.com/jpfranca-br/printer-server.git "$SRC_DIR"
check_status "Failed to clone printer-server repository."

# Initialize Go Module
echo "Initializing Go module..."
cd "$SRC_DIR"
if [ ! -f go.mod ]; then
    go mod init printer-server
    check_status "Failed to initialize Go module."
else
    echo "Go module already initialized."
fi

# Install Go Dependencies
echo "Installing Go dependencies..."
go mod tidy
check_status "Failed to install Go dependencies."

# Start Redis
echo "Starting Redis..."
sudo systemctl daemon-reload
sudo systemctl start redis-server
check_status "Failed to start Redis. Please check manually."

sudo systemctl enable redis-server
check_status "Failed to enable Redis at startup."

# Cleanup
echo "Cleaning up temporary files..."
[ -f /tmp/$GO_TAR ] && rm /tmp/$GO_TAR

# Instructions for User
echo "Setup complete!"
echo "Remember to open a new terminal or run 'source $SHELL_CONFIG' to apply PATH changes."
