package shot

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"

	"aurora/internal/execx"
)

func Main(args []string) int {
	if len(args) != 4 {
		return 1
	}
	x, e1 := strconv.Atoi(args[0])
	y, e2 := strconv.Atoi(args[1])
	w, e3 := strconv.Atoi(args[2])
	h, e4 := strconv.Atoi(args[3])
	if e1 != nil || e2 != nil || e3 != nil || e4 != nil || w < 8 || h < 8 {
		return 1
	}
	time.Sleep(12 * time.Millisecond)
	dir := os.Getenv("HYPRSHOT_DIR")
	if dir == "" {
		dir = filepath.Join(execx.Home(), "Pictures", "Screenshots")
	}
	_ = os.MkdirAll(dir, 0o755)
	dest := filepath.Join(dir, fmt.Sprintf("screenshot_%s.png", time.Now().Format("2006-01-02_15-04-05")))
	tmp := filepath.Join(execx.Runtime(), fmt.Sprintf("aurora-shot-%d.png", os.Getpid()))
	if !execx.RunOK(8*time.Second, "grim", "-l", "1", "-g", fmt.Sprintf("%d,%d %dx%d", x, y, w, h), tmp) {
		return 1
	}
	if err := os.Rename(tmp, dest); err != nil {
		_ = os.Remove(tmp)
		return 1
	}
	if os.Getenv("GTK_ICON_THEME") == "" {
		_ = os.Setenv("GTK_ICON_THEME", "Adwaita")
	}
	satty := execx.Look("satty")
	if satty == "" {
		return 1
	}
	cmd := exec.Command(satty,
		"--filename", dest,
		"--output-filename", dest,
		"--early-exit", "all",
		"--copy-command", "wl-copy",
		"--actions-on-enter", "save-to-clipboard,save-to-file",
		"--actions-on-escape", "save-to-clipboard,exit",
		"--no-window-decoration",
		"--disable-notifications",
		"--initial-tool", "brush",
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}
