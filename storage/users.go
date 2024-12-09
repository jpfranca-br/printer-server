package storage

import (
	"encoding/json"
	"golang.org/x/crypto/bcrypt"
	"io/ioutil"
	"log"
)

var filePath = "users.json" // Adjust the path if necessary

type User struct {
	Username string `json:"username"`
	Password string `json:"password"` // Hashed password
}

// LoadUsers loads the users from the JSON file.
func LoadUsers() []User {
	var users []User
	data, err := ioutil.ReadFile(filePath)
	if err != nil {
		log.Printf("Error reading users file: %v", err)
		return users
	}
	json.Unmarshal(data, &users)
	return users
}

// CheckPasswordHash compares a plaintext password with a hashed password.
func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}
