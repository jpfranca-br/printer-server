### **Printer Server Project README**

---

#### **Overview**

This project sets up a **Printer Server** with:
- **NGINX** for reverse proxy and SSL certificates.
- **Fast Reverse Proxy Server (FRPS)** for TCP/HTTP forwarding.
- A Go-based backend to send and manage print requests over TCP.

---

### **Setup Instructions**

#### **1. Install and Configure FRPS (Fast Reverse Proxy Server)**

1. Clone and run the FRPS setup project:
   ```bash
   git clone https://github.com/jpfranca-br/frps-setup.git
   cd frps-setup
   ./setup.sh
   ```

2. **Configure Subdomain**:
   - During setup, create only **one subdomain**.

3. **Edit FRPS Configuration**:
   - Open the `frps.toml` configuration file:
     ```bash
     nano ~/frp/frps.toml
     ```
   - Comment out the following line:
     ```
     # vhostHTTPPort = 8080
     ```

4. Restart the FRPS service:
   ```bash
   sudo systemctl restart frps
   sudo systemctl status frps
   ```

---

#### **2. Install and Setup the Printer Server**

1. Run the following commands to download and execute the Printer Server setup script:
   ```bash
   cd ~
   curl -o printer-server-setup.sh https://raw.githubusercontent.com/jpfranca-br/printer-server/main/printer-server-setup.sh
   chmod +x printer-server-setup.sh
   ./printer-server-setup.sh
   rm ~/printer-server-setup.sh
   ```

This script will:
- Install Go and its dependencies.
- Clone the Printer Server repository.
- Set up Redis.
- Compile and run the Go-based server.

---

### **Server Information**

1. **Server Code**:
   - Located at: `~/projects/printer-server/main.go`.

2. **User Management Module**:
   - Located at: `~/projects/printer-server/config/usermanager.go`.

3. **How to Build and Run the Server**:
   - Build the server binary:
     ```bash
     cd ~/projects/printer-server
     go build -o printer_server main.go
     ```
   - Run the server:
     ```bash
     ./printer_server
     ```

4. **How to Build and Run the User Management Module**:
   - Build the user manager binary:
     ```bash
     cd ~/projects/printer-server/config
     go build -o usermanager usermanager.go
     ```
   - Run the user manager:
     ```bash
     ./usermanager <command>
     ```

     Example commands:
     - Add a user:
       ```bash
       ./usermanager add <username> <password>
       ```
     - List users:
       ```bash
       ./usermanager list
       ```
     - Delete a user:
       ```bash
       ./usermanager delete <username>
       ```

---

### **Using the Printer Server API**

#### **1. Authenticate (`/auth`)**

Use this endpoint to authenticate and retrieve a token.

```bash
curl -X POST https://<your-server>/auth \
-H "Content-Type: application/json" \
-d '{"username": "<your-username>", "password": "<your-password>"}'
```

**Example Response**:
```json
{
    "token": "example-token-12345abcdef67890",
    "expires_at": "2024-12-08T22:45:00Z"
}
```

---

#### **2. Print a Message (`/print`)**

Use this endpoint to send a print request to the printer. Replace `<token>` with the token received from `/auth`.

```bash
curl -X POST https://<your-server>/print \
-H "Content-Type: application/json" \
-d '{
    "username": "<your-username>",
    "token": "example-token-12345abcdef67890",
    "message": "Hello, Printer!"
}'
```

**Example Response**:
```json
{
    "message": "Message sent successfully"
}
```

---

### **Notes**

1. **Token Expiration**:
   - Tokens are valid for 60 minutes. After that, you need to reauthenticate.

2. **Error Handling**:
   - If authentication or print requests fail, the API will return an appropriate error message.

3. **Logs and Debugging**:
   - Check server logs to debug any issues with the API or printer communication.

4. **Security**:
   - Use strong passwords for authentication.
   - Protect the FRPS server with a robust token and firewall rules.
