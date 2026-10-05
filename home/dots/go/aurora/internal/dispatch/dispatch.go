package dispatch

import (
	"fmt"
	"os"
)

func usage() {
	fmt.Fprintln(os.Stderr, `aurora dispatch <open|telegram-link|xdg-open> [args]`)
}

// Main routes dispatch subcommands.
func Main(args []string) int {
	if len(args) == 0 {
		usage()
		return 2
	}
	switch args[0] {
	case "open":
		return openMain(args[1:])
	case "telegram-link":
		return telegramLinkMain(args[1:])
	case "xdg-open", "xdg-open-in-container":
		return xdgOpenMain(args[1:])
	default:
		usage()
		return 2
	}
}
