package handlers

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"time"

	"printer-server/storage"
)

type PrintRequest struct {
	Username string `json:"username"`
	Token    string `json:"token"`
	Message  string `json:"message"`
}

func PrintHandler(w http.ResponseWriter, r *http.Request) {
    var req PrintRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // Validate the token
    if !storage.ValidateToken(req.Username, req.Token) {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }

    // Decode the message if it is Base64
    message, err := base64.StdEncoding.DecodeString(req.Message)
    if err != nil {
        message = []byte(req.Message) // Assume plain text if decoding fails
    }

    // Append newline or form feed to force buffer flush
    flushCommand := "\n" // Change to "\x0c" for a form feed if needed
    message = append(message, []byte(flushCommand)...)

    // Debug: Print the message to the console
    fmt.Printf("Debug: Sending message to localhost:9100: %s\n", string(message))

    // Send the message to localhost:9100 with retry logic
    retryIntervals := []time.Duration{2 * time.Second, 4 * time.Second, 8 * time.Second, 16 * time.Second, 32 * time.Second}
    for _, interval := range retryIntervals {
        conn, err := net.Dial("tcp", "localhost:9100")
        if err != nil {
            fmt.Printf("Debug: Failed to connect to localhost:9100, retrying in %v...\n", interval)
            time.Sleep(interval)
            continue
        }
        defer conn.Close()

        // Debug: Confirm the connection is open
        fmt.Println("Debug: Connection to localhost:9100 established")

        // Write the message to the connection
        _, writeErr := conn.Write(message)
        if writeErr != nil {
            fmt.Printf("Debug: Failed to write message to localhost:9100: %v\n", writeErr)
            time.Sleep(interval)
            continue
        }

        // Success: Message sent
        fmt.Println("Debug: Message sent successfully to localhost:9100")
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"message": "Message sent successfully"}`))
        return
    }

    // If all retries fail
    http.Error(w, "Failed to send message after retries", http.StatusInternalServerError)
}
