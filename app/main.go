package main

import (
	"fmt"
	"net/http"
	"os"

	"github.com/labstack/echo"
)

var defaultPort = "8080"

func main() {
	e := echo.New()

	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Hello, world!")
	})

	e.GET("/healthz", func(c echo.Context) error {
		return c.String(http.StatusOK, "ok")
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	e.Logger.Fatal(e.Start(fmt.Sprintf(":%s", port)))
}
