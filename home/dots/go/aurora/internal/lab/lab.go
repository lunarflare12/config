package lab

import (
	"encoding/json"
	"fmt"
	"os"
	"syscall"
)

func Main(args []string) int {
	if len(args) == 0 || args[0] == "status" || args[0] == "list" {
		return emitStatus(status(true))
	}
	if args[0] == "status-light" {
		return emitStatus(status(false))
	}
	if args[0] == "toggle" && len(args) >= 3 {
		if syscall.Geteuid() != 0 {
			return guiToggle(args[1], args[2])
		}
		return toggle(args[1], args[2])
	}
	if args[0] == "gui-toggle" && len(args) >= 3 {
		return guiToggle(args[1], args[2])
	}
	if args[0] == "docker" && len(args) >= 3 {
		return dockerAction(args[1], args[2])
	}
	if args[0] == "vm" && len(args) >= 3 {
		return vmAction(args[1], args[2])
	}
	fmt.Fprintln(os.Stderr, "usage: lab-ctl status|status-light | toggle wireguard|amnezia|vless|openconnect NAME | docker start|stop|pause|unpause|restart|rm NAME | vm start|stop|destroy NAME")
	return 2
}

func emitStatus(payload map[string]any) int {
	data, err := json.Marshal(payload)
	if err != nil {
		return 1
	}
	_, _ = os.Stdout.Write(data)
	_, _ = os.Stdout.Write([]byte("\n"))
	return 0
}
