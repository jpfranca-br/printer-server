package handlers

import (
	"encoding/json"
	"net/http"
	"printer_server/storage" // Ensure the correct import path
	"time"
)

type AuthRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type AuthResponse struct {
	Token     string `json:"token"`
	ExpiresAt string `json:"expires_at"` // New field for token expiration
}

func AuthHandler(w http.ResponseWriter, r *http.Request) {
	var req AuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Validate the user credentials
	if !validateUserCredentials(req.Username, req.Password) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Generate a token for the authenticated user
	token, err := storage.GenerateToken(req.Username)
	if err != nil {
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Calculate the expiration time (60 minutes from now)
	expiresAt := time.Now().Add(60 * time.Minute).Format(time.RFC3339)

	// Respond with the token and expiration time
	response := AuthResponse{
		Token:     token,
		ExpiresAt: expiresAt,
	}
	json.NewEncoder(w).Encode(response)
}

// validateUserCredentials checks the username and hashed password.
func validateUserCredentials(username, password string) bool {
	// Load users from the storage
	users := storage.LoadUsers()

	for _, user := range users {
		if user.Username == username {
			// Check the password hash using bcrypt
			return storage.CheckPasswordHash(password, user.Password)
		}
	}

	return false
}
