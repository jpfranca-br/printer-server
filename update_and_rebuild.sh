#!/bin/bash

# Variables - local files
SRC_DIR="$HOME/printer-server"

# Function to check the last command's status
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Get latest changes
cd "$SRC_DIR"
git pull
git status

# Install Go Dependencies
echo "Installing Go dependencies..."
go mod tidy
check_status "Failed to install Go dependencies."

# Rebuild printer-server
go build -o printer-server main.go
check_status "Failed to build printer-server. Please check manually: go build -o printer-server main.go"

# Rebuild user-manager
cd "$SRC_DIR"
go build -o user-manager user-manager.go
check_status "Failed to build user-manager. Please check manually: go build -o user-manager user-manager.go"
    
# Reloading daemon
echo "Reloading daemon..."
sudo systemctl daemon-reload

# Restart and enable printer-server
echo "Starting printer-server..."
sudo systemctl restart printer-server
check_status "Failed to (re)start printer-server. Please check manually."
sudo systemctl enable printer-server
check_status "Failed to enable printer-server at startup."

# Finish
echo "Update completed"
echo "It is a good idea to run: sudo apt-get upgrade -y"
