# Printer Server

## Overview
The Printer Server is a powerful tool for managing print requests efficiently and securely over TCP. Designed with modularity and scalability in mind, this project combines modern technologies like **Go**, **NGINX**, **Redis**, and **FRP** to deliver a reliable and easy-to-use printing solution.

### Key Features
- **Authentication**: Token-based authentication for secure access.
- **Print Management**: Handle print requests seamlessly via a RESTful API.
- **Scalable Setup**: Supports multiple domains and robust proxy configurations.
- **Modular Design**: Independent components for user management, authentication, and printing.
- **SSL Secured**: Secure your connections using NGINX with SSL certificates.

---

## Architecture
The system is built using the following key components:

1. **NGINX**: Acts as a reverse proxy, managing incoming requests and securing them with SSL.
2. **FRP (Fast Reverse Proxy)**: Facilitates TCP/HTTP forwarding for remote access.
3. **Go Backend**:
   - Handles authentication, user management, and print requests.
   - Interfaces with Redis for state management.
4. **Redis**: Used as a lightweight database to store session data and manage state.

---

## Setup Instructions

### Prerequisites
Ensure your system has the following:
- **Ubuntu** or a compatible Linux distribution.
- **Git** installed.

### Installation

1. Clone the repository and execute the setup script:
   ```bash
   sudo apt install git -y
   cd ~
   git clone https://github.com/jpfranca-br/printer-server.git
   cd printer-server
   chmod +x *.sh
   ./setup.sh
   ```
   - The script installs all dependencies, configures NGINX, sets up Redis, and builds the Go binaries.

2. Follow the interactive prompts:
   - **Install only NGINX and certificates**: Answer `NO` to install Printer Server and `NO` to install FRP. This setup allows for configuring multiple domains to redirect all traffic to port 8080 (users can later modify the NGINX configuration).
   - **Install NGINX, certificates, and FRP**: Answer `NO` to install Printer Server and `YES` to install FRP. This configuration supports multiple domains, redirecting traffic to port 8080, and is particularly useful for accessing Internal Web Services with Custom Domains in LAN. See the [FRP Documentation](https://github.com/fatedier/frp?tab=readme-ov-file#accessing-internal-web-services-with-custom-domains-in-lan) for more details.
   - **Install NGINX, certificates, FRP, Redis, and Printer Server**: Answer `YES` to install Printer Server. This configuration exposes a local printer (where the FRP Client is installed) securely to the internet.

3. **FRP Client Configuration**:
   - At the end of the setup, the script displays the content of the `frpc.toml` configuration file.
   - This file should be copied to the client machine that is on the same LAN as the printer (or modified to support multiple clients in the case of custom domains).
   - On the client machine, run the FRP client using:
     ```bash
     ./frpc -c ./frpc.toml
     ```

4. Services will be enabled and started automatically:
   - **NGINX** for reverse proxy.
   - **Redis** for state management.
   - **Printer Server** for handling API requests.

---

## Usage Instructions

### Authentication Endpoint
Authenticate users to obtain a session token:
```bash
curl -X POST https://<your-server>/auth \
-H "Content-Type: application/json" \
-d '{"username": "<your-username>", "password": "<your-password>"}'
```
**Response**:
```json
{
  "token": "example-token-12345abcdef67890",
  "expires_at": "2024-12-08T22:45:00Z"
}
```

### Print Request Endpoint
Send a message to the printer using a valid token:
```bash
curl -X POST https://<your-server>/print \
-H "Content-Type: application/json" \
-d '{
  "username": "<your-username>",
  "token": "<your-token>",
  "message": "Hello, Printer!"
}'
```
**Response**:
```json
{
  "message": "Message sent successfully"
}
```

---

## User Management
Manage users via the CLI utility:

1. Add a user:
   ```bash
   ./usermanager add <username> <password>
   ```

2. List all users:
   ```bash
   ./usermanager list
   ```

3. Delete a user:
   ```bash
   ./usermanager delete <username>
   ```

---

## Notes

1. **Token Expiration**:
   - Tokens expire after 60 minutes. Re-authentication is required thereafter.

2. **Error Handling**:
   - API responses provide detailed error messages for easier debugging.

3. **Logs**:
   - Check server logs for any issues related to API or printer communication.

4. **Security**:
   - Use strong passwords for user accounts.
   - Protect the FRP server with robust tokens and firewall rules.

---

## Contributions
Contributions are welcome! Fork the repository and submit a pull request for review.

---

## License
This project is licensed under the MIT License. See `LICENSE` for details.

