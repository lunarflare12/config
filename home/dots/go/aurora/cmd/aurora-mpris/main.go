package main

import (
	"os"

	"aurora/internal/mpris"
)

func main() {
	mpris.Main(os.Args[1:])
}
