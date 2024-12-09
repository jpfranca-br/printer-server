#!/bin/bash

##########################################################################################
### INITIALIZATION
##########################################################################################

# Get the current username
username=$(whoami)

# GO Download Location
GO_VERSION="1.23.4"
GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/${GO_TAR}"

# FRP Download Location
FRP_VERSION="0.61.0"
FRP_TAR="frp_${FRP_VERSION}_linux_amd64.tar.gz"
FRP_DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_TAR}"

# PRINTER SERVER Download Location
################## PRINTER_SERVER_DOWNLOAD_URL="https://github.com/jpfranca-br/printer-server.git"

# Variables - local files
GO_INSTALL_DIR="/usr/local/go"
SRC_DIR="$HOME/printer-server"
FRP_DIR="$HOME/frp"
SHELL_CONFIG="${HOME}/.$(basename $SHELL)rc"
NGINX_CONFIG="/etc/nginx/sites-available/default"

# Function to check the last command's status
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

##########################################################################################
### USER INPUT
##########################################################################################

# Prompt user for email
read -p "Enter your email address (for Certbot notifications): " user_email

# Prompt user for domains
read -p "Enter the number of domains: " n
domains=()
for ((i=1; i<=n; i++)); do
    read -p "Enter domain $i: " domain
    domains+=("$domain")
done

# Prompt user for the domain that will be used for the printer
# This will be the printer server for the client
read -p "Enter the domain that will be used to access the printer: " printer_domain

# Prompt user for the printer local port
read -p "Enter the printer local IP: " printer_local_ip

# Prompt user for the FRP token
read -p "Enter the FRP token: " frp_token
check_status "Failed to read FRP token."

##########################################################################################
### INSTALL DEPENDENCIES
##########################################################################################

# Update and install dependencies
echo "Updating system and installing prerequisites..."
sudo apt-get update -y && sudo apt-get install -y apt-utils ufw certbot python3-certbot-nginx wget tar redis git
check_status "Failed to install prerequisites."

##########################################################################################
### NGINX AND CERTIFICATES
##########################################################################################

# Test and reload Nginx
echo "Testing and reloading Nginx"
sudo nginx -t
sudo systemctl reload nginx

# Prepare Certbot domain arguments
certbot_domains=""
nginx_server_name=""
for domain in "${domains[@]}"; do
    certbot_domains="$certbot_domains -d $domain"
    nginx_server_name="$nginx_server_name $domain"
done

# Obtain SSL certificates
sudo certbot --nginx $certbot_domains --non-interactive --agree-tos --email $user_email
check_status "Failed to get SSL certificates"

# Test and dry-run renew
sudo certbot renew --dry-run

# Create/rewrite /etc/nginx/sites-available/default
sudo bash -c "cat > $NGINX_CONFIG" <<EOL
server {
    $(for domain in "${domains[@]}"; do
        echo "if (\$host = $domain) {"
        echo "    return 301 https://\$host\$request_uri;"
        echo "} # managed by Certbot"
        echo
    done)

    listen 80;
    server_name$nginx_server_name;
    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name$nginx_server_name;

    ssl_certificate /etc/letsencrypt/live/${domains[0]}/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/${domains[0]}/privkey.pem; # managed by Certbot

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Proxy all requests to localhost:8080
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Test and reload Nginx
echo "Testing and reloading Nginx"
sudo nginx -t
sudo systemctl reload nginx

##########################################################################################
### FRP
##########################################################################################

# Download FRP
echo "Downloading FRP $FRP_VERSION..."
wget -q "$FRP_DOWNLOAD_URL" -O "/tmp/$FRP_TAR"

# Ensure the FRP target directory exists
if [ ! -d "$FRP_DIR" ]; then
  echo "Creating directory $FRP_DIR..."
  mkdir -p "$FRP_DIR"
fi

# Extract FRP
echo "Extracting FRP to $FRP_DIR..."
sudo tar --strip-components=1 -C "$FRP_DIR" -xzf "/tmp/$FRP_TAR"

# Create/rewrite ~/frp/frps.toml
cat > $FRP_DIR/frps.toml <<EOL
# frps.toml
bindPort = 7000
vhostHTTPPort = 8080
auth.method = "token"
auth.token = "$frp_token"
EOL

# Create/rewrite ~/frp/frpc.toml
cat > $FRP_DIR/frpc.toml <<EOL
# frpc.toml
user = "$username"
loginFailExit = false

serverAddr = "$printer_domain"
serverPort = 7000

auth.method = "token"
auth.token = "$frp_token"

[[proxies]]
name = "tcp_server"
type = "tcp"
localIP = "$printer_local_ip"
localPort = 9100
remotePort = 9100
EOL

# Create/rewrite /etc/systemd/system/frps.service
sudo bash -c "cat > /etc/systemd/system/frps.service" <<EOL
[Unit]
Description=FRP Server
After=network.target

[Service]
ExecStart=$FRP_DIR/frps -c $FRP_DIR/frps.toml
Restart=always
RestartSec=5
User=$username
WorkingDirectory=$FRP_DIR

[Install]
WantedBy=multi-user.target
EOL

##########################################################################################
### GO
##########################################################################################

# Download Go
echo "Downloading Go $GO_VERSION..."
wget -q $GO_DOWNLOAD_URL -O /tmp/$GO_TAR

# Install Go
echo "Installing Go..."
sudo tar -C /usr/local -xzf /tmp/$GO_TAR

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

##########################################################################################
### PRINTER-SERVER
##########################################################################################

# Clone Source Code
################echo "Cloning source code..."
################rm -rf "$SRC_DIR" && git clone $PRINTER_SERVER_DOWNLOAD_URL "$SRC_DIR"
#check_status "Failed to clone printer-server repository."

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

# Build printer-server
cd "$SRC_DIR"
go build -o printer-server main.go
check_status "Failed to build printer-server. Please check manually: go build -o printer-server main.go"

# Build user-manager
cd "$SRC_DIR"
go build -o user-manager user-manager.go
check_status "Failed to build user-manager. Please check manually: go build -o user-manager user-manager.go"

# Create/rewrite /etc/systemd/system/printer-server.service
sudo bash -c "cat > /etc/systemd/system/printer-server.service" <<EOL
[Unit]
Description=printer Server
After=network.target

[Service]
ExecStart=$SRC_DIR/printer-server
Restart=always
RestartSec=5
User=$username
WorkingDirectory=$SRC_DIR

[Install]
WantedBy=multi-user.target
EOL
check_status "Failed to create/rewrite /etc/systemd/system/printer-server.service"

##########################################################################################
### ENABLING SERVICES
##########################################################################################

# Reloading daemon
echo "Reloading daemon..."
sudo systemctl daemon-reload

# Start and enable frps
echo "Starting frps..."
sudo systemctl start frps
check_status "Failed to start frps. Please check manually."
sudo systemctl enable frps
check_status "Failed to enable frps at startup."

# Start and enable Redis
echo "Starting Redis..."
sudo systemctl start redis-server
check_status "Failed to start Redis. Please check manually."
sudo systemctl enable redis-server
check_status "Failed to enable Redis at startup."

# Start and enable printer-server
echo "Starting printer-server..."
sudo systemctl start printer-server
check_status "Failed to start printer-server. Please check manually."
sudo systemctl enable printer-server
check_status "Failed to enable printer-server at startup."

##########################################################################################
### UFW
##########################################################################################

# Configure UFW
sudo ufw allow 22,80,443,7000
echo "y" | sudo ufw enable

##########################################################################################
### CLEANUP
##########################################################################################

echo "Cleaning up temporary files..."
[ -f /tmp/$GO_TAR ] && rm /tmp/$GO_TAR
[ -f /tmp/$FRP_TAR ] && rm /tmp/$FRP_TAR

##########################################################################################
### FINISH
##########################################################################################
echo "Setup complete"
echo "Domains: ${domains[*]}"
echo "Printer Domain: $printer_domain"
echo "Printer Local IP: $printer_local_ip"
echo "Remember to open a new terminal or run 'source $SHELL_CONFIG' to apply PATH changes."
echo "It is a good idea to run: sudo apt-get upgrade -y"
