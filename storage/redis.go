package storage

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"time"

	"github.com/go-redis/redis/v8"
)

var redisClient = redis.NewClient(&redis.Options{
	Addr: "localhost:6379",
})

// GenerateToken generates a secure random token, stores it in Redis, and invalidates previous tokens.
func GenerateToken(username string) (string, error) {
	token := generateRandomToken()
	ctx := context.Background()

	// Store token for the user with a 60-minute expiration
	err := redisClient.Set(ctx, username, token, 60*time.Minute).Err()
	if err != nil {
		return "", err
	}
	return token, nil
}

// ValidateToken checks if a given token is valid for a specific user.
func ValidateToken(username, token string) bool {
	ctx := context.Background()
	storedToken, err := redisClient.Get(ctx, username).Result()
	if err != nil || storedToken != token {
		return false
	}
	return true
}

// generateRandomToken generates a secure random 128-bit token and returns it as a hex string.
func generateRandomToken() string {
	bytes := make([]byte, 16) // 16 bytes = 128 bits
	if _, err := rand.Read(bytes); err != nil {
		// Handle error appropriately; returning empty token for simplicity
		return ""
	}
	return hex.EncodeToString(bytes)
}
