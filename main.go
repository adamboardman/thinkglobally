package main

import (
	"flag"
	"github.com/adamboardman/conceptualiser/server"
	"github.com/gin-gonic/gin"
)

func main() {
	isDebugging := false
	flag.BoolVar(&isDebugging, "debugging", false, "if true, we start HTTP server")
	flag.Parse()

	if !isDebugging {
		gin.SetMode(gin.ReleaseMode)
	}
	a := server.WebApp{}
	a.Init("aye-social")

	a.Run(":3030")
}