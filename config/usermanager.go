package main

import (
        "encoding/json"
        "fmt"
        "golang.org/x/crypto/bcrypt"
        "io/ioutil"
        "os"
)

type User struct {
        Username string json:"username"
        Password string json:"password" // This will store the hashed password
}

var users []User
var filePath = "users.json" // Update the path if necessary

func loadUsers() {
        data, err := ioutil.ReadFile(filePath)
        if err != nil {
                users = []User{}
                return
        }
        json.Unmarshal(data, &users)
}

func saveUsers() {
        data, _ := json.MarshalIndent(users, "", "  ")
        ioutil.WriteFile(filePath, data, 0644)
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