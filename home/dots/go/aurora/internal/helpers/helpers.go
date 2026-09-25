package helpers

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"aurora/internal/cursor"
	"aurora/internal/execx"
	"aurora/internal/hyprfix"
)

func cmdline(pid int) string {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline"))
	if err != nil {
		return ""
	}
	return strings.ReplaceAll(string(b), "\x00", " ")
}

func killMatching(needles ...string) {
	self := os.Getpid()
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return
	}
	for _, e := range ents {
		pid, err := strconv.Atoi(e.Name())
		if err != nil || pid <= 1 || pid == self {
			continue
		}
		cmd := cmdline(pid)
		if strings.Contains(cmd, "aurora-kill-qs-helpers") || strings.Contains(cmd, "aurora helpers") {
			continue
		}
		hit := false
		for _, n := range needles {
			if strings.Contains(cmd, n) {
				hit = true
				break
			}
		}
		if !hit {
			continue
		}
		p, err := os.FindProcess(pid)
		if err != nil {
			continue
		}
		_ = p.Signal(syscall.SIGTERM)
	}
}

func KillHelpers() int {
	killMatching(
		"wl-paste --watch cliphist store",
		"mpris-bridge.py",
		"aurora-mpris",
		"/mpris-bridge",
	)
	return 0
}

func SessionStart() int {
	lockPath := filepath.Join(execx.Runtime(), "aurora-qs.start.lock")
	_ = os.MkdirAll(execx.Runtime(), 0o755)
	f, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return 0
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return 0
	}
	_ = hyprfix.Recover()
	_ = execx.RunOK(2*time.Second, "xrandr",
		"--output", "DP-1", "--primary", "--mode", "2560x1080", "--pos", "0x0",
		"--output", "HDMI-A-1", "--mode", "1920x1080", "--pos", "2560x0")
	_ = cursor.Load()
	if execx.RunOK(400*time.Millisecond, "pgrep", "-x", "quickshell") {
		return 0
	}
	_ = execx.RunOK(2*time.Second, "systemctl", "--user", "import-environment",
		"WAYLAND_DISPLAY", "DISPLAY", "XDG_RUNTIME_DIR", "HYPRLAND_INSTANCE_SIGNATURE")
	_ = execx.RunOK(2*time.Second, "systemctl", "--user", "reset-failed", "quickshell.service")
	_ = execx.RunOK(2*time.Second, "systemctl", "--user", "start", "quickshell.service")
	for i := 0; i < 25; i++ {
		if execx.RunOK(400*time.Millisecond, "pgrep", "-x", "quickshell") {
			return 0
		}
		code, out := execx.Run(time.Second, "systemctl", "--user", "is-active", "quickshell.service")
		_ = code
		if strings.TrimSpace(out) == "active" {
			return 0
		}
		if strings.TrimSpace(out) == "failed" {
			_ = execx.RunOK(2*time.Second, "systemctl", "--user", "reset-failed", "quickshell.service")
			_ = execx.RunOK(2*time.Second, "systemctl", "--user", "start", "quickshell.service")
		}
		time.Sleep(200 * time.Millisecond)
	}
	return 0
}

func Main(args []string) int {
	if len(args) == 0 {
		return KillHelpers()
	}
	switch args[0] {
	case "kill-qs", "qs", "kill":
		return KillHelpers()
	case "session", "session-start":
		return SessionStart()
	default:
		return KillHelpers()
	}
}
