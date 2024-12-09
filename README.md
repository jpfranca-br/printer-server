### **Printer Server Project README**

---

#### **Overview**

This project sets up a **Printer Server** with:
- **NGINX** for reverse proxy and SSL certificates.
- **Fast Reverse Proxy Server (FRPS)** for TCP/HTTP forwarding.
- A Go-based backend to send and manage print requests over TCP.

---

### **Setup Instructions**

1. Clone repo and run setup
   ```bash
   sudo apt install git -y
   cd ~
   rm -rf printer-server
   git clone https://github.com/jpfranca-br/printer-server.git
   cd printer-server
   chmod +x setup.sh
   ./setup.sh
   ```
This script will:
- Install Nginx and create certificates for the domains
- Ff you want to install Printer Server, script will also install FRP, Go, Redis and build Printer Server
   - Othersiwe, you have to option to install FRP
- Create, enable and run services

### **Server Information**

1. **Server Code**:
   - Located at: `~/printer-server`.

2. **User Management Module**:
   - Located at: `~/printer-server/user-manager`.

4. **How to Build and Run the User Management Module**:
   - Run user manager:
     ```bash
     cd ~/printer-server
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
