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

# Variables - local files
GO_INSTALL_DIR="/usr/local/go"
SRC_DIR="$HOME/printer-server"
FRP_DIR="$HOME/frp"
SHELL_CONFIG="${HOME}/.$(basename $SHELL)rc"
NGINX_CONFIG="/etc/nginx/sites-available/default"

##########################################################################################
### FUNCTIONS
##########################################################################################

# Function to check the last command's status
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Function to validate Yes/No input
ask_yes_no() {
    local prompt="$1"
    while true; do
        read -p "$prompt (Y/N): " choice
        case "$choice" in
            [Yy]* ) return 0 ;;  # Yes
            [Nn]* ) return 1 ;;  # No
            * ) echo "Please answer Y or N." ;;
        esac
    done
}

##########################################################################################
### USER INPUT
##########################################################################################

# Ask if the user wants to install the Printer Server and Reverse Proxy (which is mandatory for printer server)
if ask_yes_no "Do you want to install Printer Server"; then
    install_printer_server=true
    install_frp=true
else
    install_printer_server=false
        # Ask if the user wants to install FRP
    if ask_yes_no "Do you want to install Fast Reverse Proxy"; then
        install_frp=true
    else
        install_frp=false
    fi
fi

# Prompt user for email
while true; do
    read -p "Enter your email address (for Certbot notifications): " user_email
    # Check if input matches a basic email pattern
    if [[ $user_email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "Valid email: $user_email"
        break
    else
        echo "Invalid email address. Please try again."
    fi
done

if $install_printer_server; then
    # Install only 1 domain
    n=1
    # Prompt user for the printer local port
    while true; do
        read -p "Enter the printer local IP (x.x.x.x) or servername: " printer_local_ip
        # Check if input matches a valid IP address or server name
        if [[ $printer_local_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            # Extract the octets of the IP and validate their range
            IFS='.' read -r -a octets <<< "$printer_local_ip"
            if ((octets[0] >= 0 && octets[0] <= 255)) && \
               ((octets[1] >= 0 && octets[1] <= 255)) && \
               ((octets[2] >= 0 && octets[2] <= 255)) && \
               ((octets[3] >= 0 && octets[3] <= 255)); then
                echo "Valid IP address: $printer_local_ip"
                break
            else
                echo "Invalid IP address. Each octet must be between 0 and 255."
            fi
        elif [[ $printer_local_ip =~ ^(([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})$ ]]; then
            # If input matches a valid server name
            echo "Valid server name: $printer_local_ip"
            break
        else
            echo "Invalid input. Please enter a valid IP address (e.g., 192.168.1.1) or server name (e.g., printer.local)."
        fi
    done
else
    # Prompt user for the number of domains
    while true; do
        read -p "Enter the number of domains (must be 1 or more): " n
        # Check if input is an integer and greater than 0
        if [[ $n =~ ^[0-9]+$ ]] && (( n > 0 )); then
            break
        else
            echo "Invalid input. Please enter a integer greater than 0."
        fi
    done
    echo "You entered: $n domains"
fi

domains=()
for ((i=1; i<=n; i++)); do
    while true; do
        read -p "Enter domain $i: " domain
        # Check if input matches a basic domain pattern
        if [[ $domain =~ ^(([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})$ ]]; then
            domains+=("$domain")
            break
        else
            echo "Invalid domain. Please try again (e.g., example.com or sub.example.com)."
        fi
    done
done

printer_domain=${domains[0]}

# Print entered domains for verification
echo "Entered domains: ${domains[@]}"

if ! ask_yes_no "Start the installation?"; then
    echo "Exiting without further actions..."
    exit 1
fi

##########################################################################################
### INSTALL DEPENDENCIES
##########################################################################################

cd $HOME

# Update and install dependencies
echo "Updating system and installing prerequisites..."
sudo apt-get update -y && sudo apt-get install -y apt-utils ufw certbot python3-certbot-nginx wget tar redis
check_status "Failed to install common prerequisites."
if install_printer_server; then
    sudo apt-get install -y redis
    check_status "Failed to install printer server prerequisites."
fi

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
# FRP will be installed separately of as part of printer server environment
if $install_frp; then
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

    # Generate a GUID token using uuidgen
    if command -v uuidgen >/dev/null 2>&1; then
        frp_token=$(uuidgen)
    else
        # Fallback: Generate a random string using openssl if uuidgen is not available
        frp_token=$(openssl rand -hex 16)
    fi
    echo "Generated FRP token: $frp_token"
    # Create/rewrite ~/frp/frps.toml
    sudo touch $FRP_DIR/frps.toml
    sudo chmod 644 $FRP_DIR/frps.toml
    sudo bash -c "cat > $FRP_DIR/frps.toml" <<EOL
# frps.toml
bindPort = 7000
$(if ! $install_printer_server; then echo "vhostHTTPPort = 8080"; fi)
auth.method = "token"
auth.token = "$frp_token"
EOL
    # note that vhostHTTPPort = 8080 only exists if printer_server is not installed
    # Create/rewrite ~/frp/frpc.toml
    sudo touch $FRP_DIR/frpc.toml
    sudo chmod 644 $FRP_DIR/frpc.toml
    sudo bash -c "cat > $FRP_DIR/frpc.toml" <<EOL
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
    # CleanUP
    echo "Cleaning up temporary files..."
    [ -f /tmp/$FRP_TAR ] && rm /tmp/$FRP_TAR
fi

##########################################################################################
### GO
##########################################################################################

if $install_printer_server; then
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
    # CleanUP
    echo "Cleaning up temporary files..."
    [ -f /tmp/$GO_TAR ] && rm /tmp/$GO_TAR
fi

##########################################################################################
### PRINTER-SERVER
##########################################################################################

if $install_printer_server; then
    # Clone Source Code
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
fi

##########################################################################################
### ENABLING SERVICES
##########################################################################################

# Reloading daemon
echo "Reloading daemon..."
sudo systemctl daemon-reload

if $install_frp; then
    # Start and enable frps
    echo "Starting frps..."
    sudo systemctl restart frps
    check_status "Failed to (re)start frps. Please check manually."
    sudo systemctl enable frps
    check_status "Failed to enable frps at startup."
fi

if $install_printer_server; then
    # Start and enable Redis
    echo "Starting Redis..."
    sudo systemctl restart redis-server
    check_status "Failed to (re)start Redis. Please check manually."
    sudo systemctl enable redis-server
    check_status "Failed to enable Redis at startup."
    
    # Start and enable printer-server
    echo "Starting printer-server..."
    sudo systemctl restart printer-server
    check_status "Failed to (re)start printer-server. Please check manually."
    sudo systemctl enable printer-server
    check_status "Failed to enable printer-server at startup."
fi

##########################################################################################
### UFW
##########################################################################################

# Configure UFW
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 7000/tcp
echo "y" | sudo ufw enable

##########################################################################################
### FINISH
##########################################################################################
echo "Setup complete"
echo "Remember to open a new terminal or run 'source $SHELL_CONFIG' to apply PATH changes."
echo "It is a good idea to run: sudo apt-get upgrade -y"
echo "This is the frpc.toml file to put on your client:"
cat $HOME/frp/frpc.toml
