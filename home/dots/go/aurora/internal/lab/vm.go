package lab

import (
	"os"
	"strings"
	"time"
)

type vmRow struct {
	Name  string `json:"name"`
	State string `json:"state"`
}

func vms() []vmRow {
	code, text, _ := run(8*time.Second, "virsh", "-c", "qemu:///system", "list", "--all")
	if code != 0 {
		return nil
	}
	var items []vmRow
	for _, line := range strings.Split(text, "\n") {
		raw := strings.TrimSpace(line)
		if raw == "" || strings.HasPrefix(raw, "Id") {
			continue
		}
		if len(strings.Trim(raw, "- ")) == 0 {
			continue
		}
		parts := strings.Fields(raw)
		if len(parts) < 3 {
			continue
		}
		if parts[0] != "-" && !isDigits(parts[0]) {
			continue
		}
		name := parts[1]
		stateRaw := strings.ToLower(strings.Join(parts[2:], " "))
		state := "shut off"
		switch {
		case strings.Contains(stateRaw, "running"):
			state = "running"
		case strings.Contains(stateRaw, "paused"):
			state = "paused"
		}
		items = append(items, vmRow{Name: name, State: state})
	}
	return items
}

func isDigits(s string) bool {
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return s != ""
}

func vmAction(action, name string) int {
	if !nameRE.MatchString(name) {
		_, _ = os.Stderr.WriteString("invalid name\n")
		return 2
	}
	var cmd []string
	switch action {
	case "start":
		cmd = []string{"virsh", "-c", "qemu:///system", "start", name}
	case "stop", "shutdown":
		cmd = []string{"virsh", "-c", "qemu:///system", "shutdown", name}
	case "destroy":
		cmd = []string{"virsh", "-c", "qemu:///system", "destroy", name}
	default:
		_, _ = os.Stderr.WriteString("invalid vm action\n")
		return 2
	}
	code, out, err := run(40*time.Second, cmd[0], cmd[1:]...)
	emit(out, err)
	return code
}
