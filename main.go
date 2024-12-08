package main

import (
	"log"
	"net/http"

	"github.com/gorilla/mux"
	"handlers"
)

func main() {
	r := mux.NewRouter()

	// Routes
	r.HandleFunc("/auth", handlers.AuthHandler).Methods("POST")
	r.HandleFunc("/print", handlers.PrintHandler).Methods("POST")

	// Start the server
	log.Println("Starting server on :8080")
	if err := http.ListenAndServe(":8080", r); err != nil {
		log.Fatalf("Server failed: %s", err)
	}
}
