package container

import (
	"fmt"
	"os"
)

func Main(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: aurora container apps|steam|telegram -- CMD...")
		return 2
	}
	switch args[0] {
	case "apps":
		return appsEntry(args[1:])
	case "steam":
		return steamEntry(args[1:])
	case "telegram":
		return telegramEntry(args[1:])
	default:
		fmt.Fprintln(os.Stderr, "usage: aurora container apps|steam|telegram -- CMD...")
		return 2
	}
}
