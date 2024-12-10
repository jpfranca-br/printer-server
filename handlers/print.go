package handlers

import (
	"context"
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

var (
	printerAddress    = "localhost:9100"
	realTimeStatusCmd = []byte{0x10, 0x04, 0x01} // Real-time status command
)

// checkPrinterStatus checks the printer status using a TCP connection.
func checkPrinterStatus(conn net.Conn) (bool, error) {
	// Send Real-Time Status Command
	_, err := conn.Write(realTimeStatusCmd)
	if err != nil {
		return false, fmt.Errorf("failed to send status command: %v", err)
	}

	// Read Printer Response
	buffer := make([]byte, 1024)
	conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	n, err := conn.Read(buffer)
	if err != nil {
		return false, fmt.Errorf("failed to read response: %v", err)
	}

	response := buffer[:n]
	if len(response) > 0 && (response[0] == 0x16 || response[0] == 0x12) {
		return true, nil
	}

	return false, nil
}

// PrintHandler handles print requests with a context timeout.
func PrintHandler(w http.ResponseWriter, r *http.Request) {
	// Set up a context with a timeout for the entire handler
	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	// Decode the JSON request
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

	// Decode the message (Base64 or plain text)
	message, err := base64.StdEncoding.DecodeString(req.Message)
	if err != nil {
		message = []byte(req.Message) // Assume plain text if decoding fails
	}

	// Append newline or form feed to force buffer flush
	flushCommand := "\n"
	message = append(message, []byte(flushCommand)...)

	// Connect to the printer with a custom timeout
	conn, err := net.DialTimeout("tcp", printerAddress, 30*time.Second)
	if err != nil {
		http.Error(w, "Printer Offline or No Paper", http.StatusServiceUnavailable)
		return
	}
	defer conn.Close()

	// Check printer status before printing
	ready, err := checkPrinterStatus(conn)
	if err != nil || !ready {
		http.Error(w, "Printer Offline or No Paper", http.StatusServiceUnavailable)
		return
	}

	// Send the print message
	select {
	case <-ctx.Done():
		http.Error(w, "Request timed out", http.StatusGatewayTimeout)
		return
	default:
		_, err = conn.Write(message)
		if err != nil {
			http.Error(w, "Failed to send message to printer", http.StatusInternalServerError)
			return
		}
	}

	// Check printer status after printing
	ready, err = checkPrinterStatus(conn)
	if err != nil || !ready {
		http.Error(w, "Possible Problem During Printing", http.StatusInternalServerError)
		return
	}

	// Success response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"message": "Printed OK"}`))
}
