package dispatch

import (
	"os"
	"path/filepath"
	"strings"
)

func isTelegramURL(u string) bool {
	switch {
	case strings.HasPrefix(u, "tg:"),
		strings.HasPrefix(u, "telegram:"),
		strings.HasPrefix(u, "tonsite:"),
		strings.HasPrefix(u, "https://t.me/"),
		u == "https://t.me",
		strings.HasPrefix(u, "http://t.me/"),
		strings.HasPrefix(u, "https://telegram.me/"),
		strings.HasPrefix(u, "https://telegram.dog/"):
		return true
	default:
		return false
	}
}

func xdgOpenMain(args []string) int {
	if len(args) == 0 {
		return 0
	}
	home := os.Getenv("HOME")
	if home == "" {
		home = "/home/app"
	}
	ipc := filepath.Join(home, "ipc")
	_ = os.MkdirAll(ipc, 0o755)

	url := strings.Join(args, " ")
	if isTelegramURL(url) {
		_ = os.WriteFile(filepath.Join(ipc, "telegram.url"), []byte(url+"\n"), 0o644)
		return 0
	}
	_ = os.WriteFile(filepath.Join(ipc, "launch.path"), []byte(url+"\n"), 0o644)
	_ = os.WriteFile(filepath.Join(ipc, "launch.last"), []byte(url+"\n"), 0o644)
	return 0
}
