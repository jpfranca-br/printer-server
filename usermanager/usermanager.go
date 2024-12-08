package main

import (
	"encoding/json"
	"embed"
	"fmt"
	"golang.org/x/crypto/bcrypt"
	"os"
)

// User structure
type User struct {
	Username string `json:"username"`
	Password string `json:"password"` // This will store the hashed password
}

var users []User

// Embed the users.json file
//go:embed printer-server/config/users.json
var embeddedUsersFile embed.FS

func loadUsers() {
	// Attempt to read the embedded file
	data, err := embeddedUsersFile.ReadFile("printer-server/config/users.json")
	if err != nil {
		fmt.Println("Error reading embedded users.json:", err)
		users = []User{}
		return
	}

	err = json.Unmarshal(data, &users)
	if err != nil {
		fmt.Println("Error unmarshalling users.json:", err)
		users = []User{}
	}
}

func saveUsers() {
	// Saving users.json back to the filesystem isn't compatible with embed, 
	// since embedded files are read-only. Inform the user about this limitation.
	fmt.Println("Save operation is not supported for embedded files. Changes will not persist.")
}

func hashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}

func checkPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

func addUser(username, password string) {
	hashedPassword, err := hashPassword(password)
	if err != nil {
		fmt.Println("Error hashing password:", err)
		return
	}

	for i, user := range users {
		if user.Username == username {
			users[i].Password = hashedPassword
			saveUsers()
			fmt.Println("User updated")
			return
		}
	}

	users = append(users, User{Username: username, Password: hashedPassword})
	saveUsers()
	fmt.Println("User added")
}

func deleteUser(username string) {
	for i, user := range users {
		if user.Username == username {
			users = append(users[:i], users[i+1:]...)
			saveUsers()
			fmt.Println("User deleted")
			return
		}
	}
	fmt.Println("User not found")
}

func listUsers() {
	for _, user := range users {
		fmt.Println("Username:", user.Username)
		// Password hashes are not displayed for security reasons
	}
}

func main() {
	loadUsers()

	if len(os.Args) < 2 {
		fmt.Println("Usage: usermanager <add|delete|list> [args...]")
		return
	}

	switch os.Args[1] {
	case "add":
		if len(os.Args) < 4 {
			fmt.Println("Usage: usermanager add <username> <password>")
			return
		}
		addUser(os.Args[2], os.Args[3])
	case "delete":
		if len(os.Args) < 3 {
			fmt.Println("Usage: usermanager delete <username>")
			return
		}
		deleteUser(os.Args[2])
	case "list":
		listUsers()
	default:
		fmt.Println("Usage: usermanager <add|delete|list> [args...]")
	}
}
