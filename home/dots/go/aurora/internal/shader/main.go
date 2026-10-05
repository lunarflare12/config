package shader

import (
	"fmt"
	"os"
)

// Main is the CLI entry for aurora shader subcommands.
// Commands: status|check [appid]|update [appid]|build [appid]|stop
func Main(args []string) int {
	cmd := "status"
	if len(args) > 0 {
		cmd = args[0]
	}
	var appid string
	if len(args) > 1 {
		appid = args[1]
	}
	switch cmd {
	case "status":
		return cmdStatus()
	case "build":
		return cmdBuild(appid)
	case "stop":
		return cmdStop()
	case "check":
		return cmdCheck(appid, false)
	case "update":
		return cmdUpdate(appid)
	default:
		fmt.Fprintln(os.Stderr, "usage: shader status|check [appid]|update [appid]|build [appid]|stop")
		return 2
	}
}
