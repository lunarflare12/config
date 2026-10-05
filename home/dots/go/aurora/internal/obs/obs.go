package obs

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"aurora/internal/execx"
)

const obsBin = "/run/current-system/sw/bin/obs"

var quotedRE = regexp.MustCompile(`"([^"]+)"`)

func runtimeDir() string {
	return execx.Runtime()
}

func pidFile() string { return filepath.Join(runtimeDir(), "obs-tray.pid") }
func sniFile() string { return filepath.Join(runtimeDir(), "obs-sni") }
func logFile() string { return filepath.Join(runtimeDir(), "obs-launch.log") }

func logf(format string, args ...any) {
	f, err := os.OpenFile(logFile(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = fmt.Fprintf(f, "%s %s\n", time.Now().Format("15:04:05"), fmt.Sprintf(format, args...))
}

func isSocket(path string) bool {
	st, err := os.Stat(path)
	return err == nil && st.Mode()&os.ModeSocket != 0
}

func ensureHyprEnv() {
	_ = os.Setenv("XDG_RUNTIME_DIR", runtimeDir())
	if os.Getenv("WAYLAND_DISPLAY") == "" {
		rt := runtimeDir()
		if isSocket(filepath.Join(rt, "wayland-1")) {
			_ = os.Setenv("WAYLAND_DISPLAY", "wayland-1")
		} else if isSocket(filepath.Join(rt, "wayland-0")) {
			_ = os.Setenv("WAYLAND_DISPLAY", "wayland-0")
		}
	}
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") == "" {
		hyprDir := filepath.Join(runtimeDir(), "hypr")
		if ents, err := os.ReadDir(hyprDir); err == nil {
			for _, e := range ents {
				if e.IsDir() {
					_ = os.Setenv("HYPRLAND_INSTANCE_SIGNATURE", e.Name())
					break
				}
			}
		}
	}
	if os.Getenv("DBUS_SESSION_BUS_ADDRESS") == "" {
		bus := filepath.Join(runtimeDir(), "bus")
		if isSocket(bus) {
			_ = os.Setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path="+bus)
		}
	}
}

func prepEnv() {
	ld := "/run/opengl-driver/lib"
	if cur := os.Getenv("LD_LIBRARY_PATH"); cur != "" {
		ld = ld + ":" + cur
	}
	_ = os.Setenv("LD_LIBRARY_PATH", ld)
	_ = os.Unsetenv("LIBVA_DRIVER_NAME")
	_ = os.Unsetenv("LIBVA_DRIVERS_PATH")
}

func isObsPid(pid string) bool {
	if pid == "" {
		return false
	}
	b, err := os.ReadFile("/proc/" + pid + "/cmdline")
	if err != nil {
		return false
	}
	cmd := strings.ReplaceAll(string(b), "\x00", " ")
	cmd = strings.TrimSpace(cmd)
	switch {
	case strings.Contains(cmd, "/.obs-wrapped"):
		return true
	case strings.Contains(cmd, "/bin/obs ") || strings.HasSuffix(cmd, "/bin/obs"):
		return true
	case strings.Contains(cmd, "/obs --") || strings.HasSuffix(cmd, "/obs"):
		return true
	}
	return false
}

func pgrepExact(name string) []string {
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range ents {
		if !e.IsDir() {
			continue
		}
		pid := e.Name()
		if _, err := strconv.Atoi(pid); err != nil {
			continue
		}
		b, err := os.ReadFile(filepath.Join("/proc", pid, "comm"))
		if err != nil {
			continue
		}
		if strings.TrimSpace(string(b)) == name {
			out = append(out, pid)
		}
	}
	return out
}

func obsPid() (string, bool) {
	if b, err := os.ReadFile(pidFile()); err == nil {
		p := strings.TrimSpace(string(b))
		p = strings.ReplaceAll(p, " ", "")
		if isObsPid(p) {
			return p, true
		}
		_ = os.Remove(pidFile())
	}
	for _, name := range []string{".obs-wrapped", "obs"} {
		for _, p := range pgrepExact(name) {
			if isObsPid(p) {
				return p, true
			}
		}
	}
	return "", false
}

func hyprctl() string {
	return execx.Look("hyprctl")
}

func obsWindowMapped() bool {
	h := hyprctl()
	if h == "" {
		return false
	}
	code, out := execx.Run(2*time.Second, h, "repl",
		`for _,w in pairs(hl.get_windows()) do local c=(w.class or ""):lower(); if c:find("obsproject") then print("yes"); return end end`)
	return code == 0 && strings.Contains(out, "yes")
}

func hyprFocusObs() bool {
	h := hyprctl()
	if h == "" {
		return false
	}
	code, out := execx.Run(2*time.Second, h, "dispatch", `hl.dsp.focus({ window = "class:com.obsproject.Studio" })`)
	out = strings.TrimSpace(out)
	if strings.Contains(out, "window not found") {
		return false
	}
	if code == 0 && (out == "ok" || strings.HasPrefix(out, "ok")) {
		return true
	}
	return false
}

func sniActivateOne(dest, path string) bool {
	for _, iface := range []string{"org.kde.StatusNotifierItem", "org.freedesktop.StatusNotifierItem"} {
		if execx.RunOK(300*time.Millisecond, "busctl", "--user", "call", dest, path, iface, "Activate", "ii", "0", "0") {
			return true
		}
	}
	return false
}

func sniActivate() bool {
	if b, err := os.ReadFile(sniFile()); err == nil {
		raw := strings.TrimSpace(string(b))
		if strings.Contains(raw, "/") {
			dest, path, _ := strings.Cut(raw, "/")
			if sniActivateOne(dest, "/"+path) {
				return true
			}
		}
	}

	code, out := execx.Run(300*time.Millisecond, "busctl", "--user", "get-property",
		"org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
		"org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
	if code != 0 {
		return false
	}

	for _, raw := range quotedRE.FindAllStringSubmatch(out, -1) {
		if len(raw) < 2 {
			continue
		}
		item := raw[1]
		low := strings.ToLower(item)
		if strings.Contains(low, "obsidian") || strings.Contains(low, "steam") {
			continue
		}
		if !strings.Contains(item, "/") {
			continue
		}
		dest, path, _ := strings.Cut(item, "/")
		path = "/" + path
		_, prop := execx.Run(200*time.Millisecond, "busctl", "--user", "get-property", dest, path,
			"org.kde.StatusNotifierItem", "Id")
		blob := strings.ToLower(prop)
		if !strings.Contains(blob, `s "obs"`) && !strings.Contains(blob, "obs-tray") {
			continue
		}
		if sniActivateOne(dest, path) {
			_ = os.WriteFile(sniFile(), []byte(item), 0o644)
			return true
		}
	}
	return false
}

func waitForWindow(n int) bool {
	for i := 0; i < n; i++ {
		if obsWindowMapped() {
			_ = hyprFocusObs()
			return true
		}
		time.Sleep(50 * time.Millisecond)
	}
	return false
}

func showWindow() bool {
	if obsWindowMapped() {
		logf("already mapped → focus")
		_ = hyprFocusObs()
		return true
	}
	logf("unmapped → SNI Activate")
	_ = sniActivate()
	if waitForWindow(30) {
		logf("window mapped after SNI")
		return true
	}
	_ = os.Remove(sniFile())
	_ = sniActivate()
	if waitForWindow(20) {
		logf("window mapped after SNI rediscover")
		return true
	}
	logf("SNI failed to map window")
	return false
}

func killObs() {
	_ = exec.Command("systemctl", "--user", "stop", "obs-tray.service").Run()
	if p, ok := obsPid(); ok {
		if pid, err := strconv.Atoi(p); err == nil {
			_ = syscall.Kill(pid, syscall.SIGTERM)
		}
	}
	time.Sleep(200 * time.Millisecond)
	if p, ok := obsPid(); ok {
		if pid, err := strconv.Atoi(p); err == nil {
			_ = syscall.Kill(pid, syscall.SIGKILL)
		}
	}
	_ = os.Remove(pidFile())
	_ = os.Remove(sniFile())
}

func startVisible(args []string) int {
	logf("starting VISIBLE obs (no minimize)")
	argv := append([]string{obsBin, "--disable-missing-files-check"}, args...)
	err := syscall.Exec(obsBin, argv, os.Environ())
	if err != nil {
		fmt.Fprintln(os.Stderr, "obs:", err)
		return 1
	}
	return 0
}

func startTray(args []string) int {
	ensureHyprEnv()
	if _, ok := obsPid(); ok {
		return 0
	}
	_ = os.WriteFile(pidFile(), []byte(strconv.Itoa(os.Getpid())+"\n"), 0o644)
	argv := append([]string{obsBin, "--minimize-to-tray", "--disable-missing-files-check"}, args...)
	err := syscall.Exec(obsBin, argv, os.Environ())
	if err != nil {
		fmt.Fprintln(os.Stderr, "obs:", err)
		return 1
	}
	return 0
}

func Main(args []string) int {
	prepEnv()
	if len(args) > 0 && args[0] == "--tray" {
		return startTray(args[1:])
	}

	ensureHyprEnv()
	logf("launch begin wayland=%s hypr=%s dbus=%s",
		os.Getenv("WAYLAND_DISPLAY"),
		os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"),
		os.Getenv("DBUS_SESSION_BUS_ADDRESS"))

	if _, ok := obsPid(); ok {
		if showWindow() {
			logf("launch ok (raised)")
			return 0
		}
		logf("raise failed → kill + visible start")
		killObs()
		return startVisible(args)
	}

	logf("not running → visible start")
	_ = exec.Command("systemctl", "--user", "stop", "obs-tray.service").Run()
	return startVisible(args)
}
