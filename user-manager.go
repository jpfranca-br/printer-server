package main

import (
        "encoding/json"
        "fmt"
        "golang.org/x/crypto/bcrypt"
        "io/ioutil"
        "os"
        "github.com/go-redis/redis/v8"
)

var redisClient = redis.NewClient(&redis.Options{
    Addr: "localhost:6379", // Adjust as needed
})

type User struct {
        Username string `json:"username"`
        Password string `json:"password"` // This will store the hashed password
}

var users []User
var filePath = "users.json"

func loadUsers() {
        // Debug: Print the resolved filePath
        fmt.Printf("Debug: Loading users from file: %s\n", filePath)

        data, err := ioutil.ReadFile(filePath)
        if err != nil {
                if os.IsNotExist(err) {
                        fmt.Printf("Debug: File %s does not exist. Creating a new file.\n", filePath)
                        users = []User{} // Initialize an empty user list
                        saveUsers()      // Save the empty user list to create the file
                        return
                }

                // Handle other types of errors
                fmt.Printf("Debug: Could not read file %s. Error: %v\n", filePath, err)
                users = []User{}
                return
        }

        // Unmarshal data into the users slice
        json.Unmarshal(data, &users)
}

func saveUsers() {
        // Debug: Print the filePath before saving
        fmt.Printf("Debug: Saving users to file: %s\n", filePath)

        data, _ := json.MarshalIndent(users, "", "  ")
        err := ioutil.WriteFile(filePath, data, 0644)
        if err != nil {
                fmt.Printf("Debug: Failed to save users to file %s. Error: %v\n", filePath, err)
        }
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
            // Remove the user from the list
            users = append(users[:i], users[i+1:]...)
            saveUsers()
            fmt.Println("User deleted")

            // Remove the token associated with the user from Redis
            ctx := context.Background()
            err := redisClient.Del(ctx, username).Err()
            if err != nil {
                fmt.Printf("Error removing token for user %s from Redis: %v\n", username, err)
            } else {
                fmt.Printf("Token for user %s removed from Redis.\n", username)
            }

            return
        }
    }
    fmt.Println("User not found")
}

func deleteUserOLD(username string) {
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
        // Debug: Print the resolved filePath
        fmt.Printf("Debug: Using configuration file at: %s\n", filePath)

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
