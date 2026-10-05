package dispatch

import (
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"aurora/internal/execx"
)

var openRoots = []string{
	"chrome-dd",
	"chrome-az",
	"chrome-hika",
	"chrome-sciencesoft",
	"firefox",
	"zen",
	"telegram-1",
	"telegram-2",
}

func ensureHostEnv() {
	user := os.Getenv("USER")
	if user == "" {
		user = "dd"
	}
	path := os.Getenv("PATH")
	prefix := "/run/current-system/sw/bin:/etc/profiles/per-user/" + user + "/bin"
	if path == "" {
		_ = os.Setenv("PATH", prefix)
	} else if !strings.HasPrefix(path, prefix) {
		_ = os.Setenv("PATH", prefix+":"+path)
	}
	if os.Getenv("HOME") == "" {
		_ = os.Setenv("HOME", "/home/dd")
	}
	if os.Getenv("XDG_RUNTIME_DIR") == "" {
		_ = os.Setenv("XDG_RUNTIME_DIR", "/run/user/"+strconv.Itoa(os.Getuid()))
	}
	if os.Getenv("WAYLAND_DISPLAY") == "" {
		_ = os.Setenv("WAYLAND_DISPLAY", "wayland-1")
	}
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") == "" {
		hyprDir := filepath.Join(execx.Runtime(), "hypr")
		if ents, err := os.ReadDir(hyprDir); err == nil {
			var bestName string
			var bestMod time.Time
			for _, e := range ents {
				if !e.IsDir() {
					continue
				}
				info, err := e.Info()
				if err != nil {
					continue
				}
				if bestName == "" || info.ModTime().After(bestMod) {
					bestName = e.Name()
					bestMod = info.ModTime()
				}
			}
			if bestName != "" {
				_ = os.Setenv("HYPRLAND_INSTANCE_SIGNATURE", bestName)
			}
		}
	}
	_ = os.Unsetenv("DISPLAY")
}

func decodeURI(s string) string {
	if out, err := url.PathUnescape(s); err == nil {
		return out
	}
	if out, err := url.QueryUnescape(s); err == nil {
		return out
	}
	return s
}

func fileURI(path string) string {
	return "file://" + (&url.URL{Path: path}).EscapedPath()
}

func hostPath(raw, root, name string) string {
	raw = strings.TrimPrefix(raw, "file://localhost")
	raw = strings.TrimPrefix(raw, "file://")
	raw = decodeURI(raw)
	home := execx.Home()
	switch {
	case raw == "/home/app/Downloads" || strings.HasPrefix(raw, "/home/app/Downloads/"):
		return filepath.Join(home, "Downloads") + strings.TrimPrefix(raw, "/home/app/Downloads")
	case raw == "/home/telegram/Downloads" || strings.HasPrefix(raw, "/home/telegram/Downloads/"):
		return filepath.Join(home, "Downloads", name) + strings.TrimPrefix(raw, "/home/telegram/Downloads")
	case strings.HasPrefix(raw, "/home/app/"):
		return root + strings.TrimPrefix(raw, "/home/app")
	case strings.HasPrefix(raw, "/home/telegram/"):
		return filepath.Join(home, "Downloads", name) + strings.TrimPrefix(raw, "/home/telegram")
	default:
		return raw
	}
}

func finderArgv(path string) []string {
	if p := execx.Look("finder"); p != "" {
		return []string{p, path}
	}
	if p := execx.Look("aurora"); p != "" {
		return []string{p, "finder", path}
	}
	return []string{"thunar", path}
}

func scopeEnv() []string {
	return []string{
		"HOME=" + execx.Home(),
		"XDG_RUNTIME_DIR=" + execx.Runtime(),
		"WAYLAND_DISPLAY=" + envOr("WAYLAND_DISPLAY", "wayland-1"),
		"HYPRLAND_INSTANCE_SIGNATURE=" + os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"),
		"DISPLAY=",
	}
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func runScoped(argv ...string) {
	args := []string{"--user", "--scope", "--collect", "--quiet"}
	for _, e := range scopeEnv() {
		args = append(args, "-E", e)
	}
	args = append(args, "--")
	args = append(args, argv...)
	cmd := exec.Command("systemd-run", args...)
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Start(); err != nil {
		fallback := exec.Command(argv[0], argv[1:]...)
		fallback.Stdout = nil
		fallback.Stderr = nil
		_ = fallback.Start()
	}
}

func gdbusOK(args ...string) bool {
	return execx.RunOK(3*time.Second, "gdbus", append([]string{"call", "--session"}, args...)...)
}

func reveal(path string) {
	if st, err := os.Stat(path); err == nil && st.IsDir() {
		runScoped(finderArgv(path)...)
		return
	}

	dir := filepath.Dir(path)
	name := filepath.Base(path)
	if st, err := os.Stat(dir); err != nil || !st.IsDir() {
		dir = filepath.Join(execx.Home(), "Downloads")
	}
	uri := fileURI(path)
	dirURI := fileURI(dir)

	if gdbusOK("--dest", "org.xfce.Thunar",
		"--object-path", "/org/xfce/FileManager",
		"--method", "org.xfce.FileManager.DisplayFolderAndSelect",
		dirURI, name, "", "") {
		return
	}
	if gdbusOK("--dest", "org.freedesktop.FileManager1",
		"--object-path", "/org/freedesktop/FileManager1",
		"--method", "org.freedesktop.FileManager1.ShowItems",
		"['"+uri+"']", "") {
		return
	}

	runScoped(finderArgv(dir)...)
	for i := 0; i < 30; i++ {
		time.Sleep(100 * time.Millisecond)
		if gdbusOK("--dest", "org.xfce.Thunar",
			"--object-path", "/org/xfce/FileManager",
			"--method", "org.xfce.FileManager.DisplayFolderAndSelect",
			dirURI, name, "", "") {
			return
		}
		if gdbusOK("--dest", "org.freedesktop.FileManager1",
			"--object-path", "/org/freedesktop/FileManager1",
			"--method", "org.freedesktop.FileManager1.ShowItems",
			"['"+uri+"']", "") {
			return
		}
	}
}

func launch(path string) {
	if st, err := os.Stat(path); err == nil && st.IsDir() {
		reveal(path)
		return
	}
	if _, err := os.Stat(path); err != nil {
		dir := filepath.Dir(path)
		if st, err := os.Stat(dir); err == nil && st.IsDir() {
			reveal(dir)
		}
		return
	}
	runScoped("xdg-open", path)
}

func openMain(_ []string) int {
	ensureHostEnv()
	home := execx.Home()

	var bestFile, bestName, bestKind string
	var bestMtime int64
	for _, name := range openRoots {
		base := filepath.Join(home, "programs", name, "ipc")
		for _, kind := range []string{"launch", "open"} {
			file := filepath.Join(base, kind+".path")
			st, err := os.Stat(file)
			if err != nil || st.Size() == 0 {
				continue
			}
			mtime := st.ModTime().Unix()
			if bestFile == "" || mtime > bestMtime {
				bestFile = file
				bestMtime = mtime
				bestName = name
				bestKind = kind
			}
		}
	}
	if bestFile == "" {
		return 0
	}

	rawBytes, err := os.ReadFile(bestFile)
	_ = os.Remove(bestFile)
	for _, name := range openRoots {
		for _, kind := range []string{"launch", "open"} {
			f := filepath.Join(home, "programs", name, "ipc", kind+".path")
			if st, err := os.Stat(f); err == nil && st.Size() == 0 {
				_ = os.Remove(f)
			}
		}
	}
	if err != nil {
		return 0
	}
	raw := strings.TrimRight(string(rawBytes), "\r\n")
	raw = strings.ReplaceAll(raw, "\r", "")
	if raw == "" {
		return 0
	}

	target := hostPath(raw, filepath.Join(home, "programs", bestName), bestName)
	action := bestKind
	if target == "" || action == "" {
		return 0
	}

	stamp := filepath.Join(execx.Runtime(), "container-open.last")
	now := strconv.FormatInt(time.Now().Unix(), 10)
	_ = os.WriteFile(stamp, []byte(now+"\x00"+action+"\x00"+target+"\n"), 0o644)

	if action == "launch" {
		if _, err := os.Stat(target); err != nil {
			fmt.Fprintf(os.Stderr, "container-open: missing %s (raw=%s)\n", target, raw)
			dir := filepath.Dir(target)
			if st, err := os.Stat(dir); err == nil && st.IsDir() {
				reveal(dir)
			}
			return 0
		}
		launch(target)
	} else {
		reveal(target)
	}
	return 0
}
