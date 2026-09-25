package main

import (
	"os"

	"aurora/internal/reaper"
)

func main() {
	reaper.Main(os.Args[1:])
}
