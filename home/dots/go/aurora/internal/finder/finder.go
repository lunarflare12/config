package finder

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"aurora/internal/execx"
)

func Main(args []string) int {
	xfq := "/run/current-system/sw/bin/xfconf-query"
	if st, err := os.Stat(xfq); err == nil && !st.IsDir() {
		sets := [][]string{
			{"-c", "thunar", "-p", "/last-side-pane", "-s", "ThunarShortcutsPane"},
			{"-c", "thunar", "-p", "/last-separator-position", "-s", "220"},
			{"-c", "thunar", "-p", "/last-menubar-visible", "-s", "false"},
			{"-c", "thunar", "-p", "/last-location-bar", "-s", "ThunarLocationButtons"},
			{"-c", "thunar", "-p", "/hidden-bookmarks", "-r"},
		}
		for _, a := range sets {
			_ = execx.RunOK(2*time.Second, xfq, a...)
		}
		_ = exec.Command(xfq, "-c", "thunar", "-p", "/hidden-bookmarks", "-n", "-a",
			"-t", "string", "-s", "recent:///",
			"-t", "string", "-s", "computer:///").Run()
	}

	systemThunar := "/run/current-system/sw/bin/thunar"
	patched := filepath.Join(execx.Home(), ".local", "lib", "thunar-patched", "bin", "thunar")
	thunar := ""
	if st, err := os.Stat(patched); err == nil && !st.IsDir() {
		thunar = patched
		if os.Getenv("THUNARX_DIRS") == "" {
			if st, err := os.Stat(systemThunar); err == nil && !st.IsDir() {
				if target, err := filepath.EvalSymlinks(systemThunar); err == nil {
					plugin := filepath.Join(filepath.Dir(target), "..", "lib", "thunarx-3")
					if st, err := os.Stat(plugin); err == nil && st.IsDir() {
						_ = os.Setenv("THUNARX_DIRS", plugin)
					}
				}
			}
		}
	} else if st, err := os.Stat(systemThunar); err == nil && !st.IsDir() {
		thunar = systemThunar
	} else if p, err := exec.LookPath("thunar"); err == nil {
		thunar = p
	}
	if thunar == "" {
		fmt.Fprintln(os.Stderr, "finder: thunar not found")
		return 1
	}
	cmd := exec.Command(thunar, args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}
