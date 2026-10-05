package container

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

const gtkINI = `[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=WhiteSur-Dark
gtk-icon-theme-name=WhiteSur-dark
`

func appsEntry(args []string) int {
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		runtime = "/tmp/xdg"
	}
	home := os.Getenv("HOME")
	if home == "" {
		home = "/home/app"
	}

	_ = os.MkdirAll(filepath.Join(home, "Downloads"), 0o755)
	_ = os.MkdirAll(filepath.Join(home, "ipc"), 0o755)

	var dbusAddr string
	hostBus := "/run/user/1000/bus"
	if st, err := os.Stat(hostBus); err == nil && st.Mode()&os.ModeSocket != 0 {
		dbusAddr = "unix:path=" + hostBus
	} else if st, err := os.Stat(filepath.Join(runtime, "bus")); err == nil && st.Mode()&os.ModeSocket != 0 {
		dbusAddr = "unix:path=" + filepath.Join(runtime, "bus")
	} else {
		_ = exec.Command("dbus-daemon", "--session", "--fork", "--address=unix:path="+filepath.Join(runtime, "bus")).Run()
		dbusAddr = "unix:path=" + filepath.Join(runtime, "bus")
	}

	for _, cand := range []string{
		"/usr/local/bin/filemanager1-stub",
		filepath.Join(home, ".local/bin/filemanager1-stub"),
		"/home/app/.local/bin/filemanager1-stub",
	} {
		if st, err := os.Stat(cand); err == nil && !st.IsDir() && st.Mode()&0o111 != 0 {
			cmd := exec.Command(cand)
			cmd.Env = append(os.Environ(), "DBUS_SESSION_BUS_ADDRESS="+dbusAddr, "HOME="+home)
			_ = cmd.Start()
			break
		}
	}

	setDefault("GTK_THEME", "WhiteSur-Dark")
	setDefault("GTK_APPLICATION_PREFER_DARK_THEME", "1")
	setDefault("GTK_ICON_THEME", "WhiteSur-dark")
	setDefault("ADW_DEBUG_COLOR_SCHEME", "prefer-dark")
	setDefault("QT_QPA_PLATFORMTHEME", "qt6ct")
	setDefault("QT_STYLE_OVERRIDE", "kvantum")
	setDefault("QT_QUICK_CONTROLS_STYLE", "Fusion")
	setDefault("ELECTRON_FORCE_DARK", "1")
	setDefault("GTK_USE_PORTAL", "0")
	setDefault("COLOR_SCHEME", "prefer-dark")
	setDefault("WAYLAND_DISPLAY", "wayland-1")
	setDefault("GDK_BACKEND", "wayland")
	setDefault("MOZ_ENABLE_WAYLAND", "1")
	setDefault("QT_QPA_PLATFORM", "wayland")
	setDefault("PIPEWIRE_REMOTE", "unix:/tmp/pipewire-0")
	_ = os.Unsetenv("DISPLAY")

	for _, sub := range []string{"gtk-3.0", "gtk-4.0"} {
		dir := filepath.Join(home, ".config", sub)
		_ = os.MkdirAll(dir, 0o755)
		_ = os.WriteFile(filepath.Join(dir, "settings.ini"), []byte(gtkINI), 0o644)
	}

	base := filepath.Base(args[0])
	switch base {
	case "idea", "idea.sh", ".idea-wrapped":
		removeGlob(filepath.Join(home, ".config/JetBrains/IntelliJIdea*/.lock"))
		removeGlob(filepath.Join(home, ".cache/JetBrains/IntelliJIdea*/.port"))
	case "qbittorrent", ".qbittorrent-wrapped":
		_ = os.Remove(filepath.Join(home, ".config/qBittorrent/lockfile"))
	}

	var fwd *exec.Cmd
	if _, err := exec.Command("getent", "hosts", "open-webui").Output(); err == nil {
		socat := os.Getenv("SOCAT_BIN")
		if socat == "" {
			matches, _ := filepath.Glob("/nix/store/*-socat-*/bin/socat")
			if len(matches) > 0 {
				socat = matches[0]
			}
		}
		if st, err := os.Stat(socat); err == nil && st.Mode()&0o111 != 0 {
			fwd = exec.Command(socat, "TCP-LISTEN:3000,fork,reuseaddr,bind=127.0.0.1", "TCP:open-webui:8080")
			_ = fwd.Start()
		}
	}

	if len(args) == 0 {
		return 127
	}

	env := []string{
		"DBUS_SESSION_BUS_ADDRESS=" + dbusAddr,
		"HOME=" + home,
		"XDG_RUNTIME_DIR=" + runtime,
	}
	for _, k := range []string{
		"WAYLAND_DISPLAY", "GDK_BACKEND", "MOZ_ENABLE_WAYLAND", "QT_QPA_PLATFORM",
		"GTK_THEME", "GTK_APPLICATION_PREFER_DARK_THEME", "GTK_ICON_THEME",
		"ADW_DEBUG_COLOR_SCHEME", "QT_QPA_PLATFORMTHEME", "QT_STYLE_OVERRIDE",
		"QT_QUICK_CONTROLS_STYLE", "ELECTRON_FORCE_DARK", "GTK_USE_PORTAL", "COLOR_SCHEME",
		"PIPEWIRE_REMOTE",
	} {
		if v := os.Getenv(k); v != "" {
			env = append(env, k+"="+v)
		}
	}
	cmdEnv := filterEnv(os.Environ(), "DISPLAY")
	cmdEnv = append(cmdEnv, env...)
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Env = cmdEnv
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if fwd != nil && fwd.Process != nil {
			_ = fwd.Process.Signal(syscall.SIGTERM)
		}
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	if fwd != nil && fwd.Process != nil {
		_ = fwd.Process.Signal(syscall.SIGTERM)
	}
	return 0
}

func filterEnv(env []string, drop ...string) []string {
	skip := make(map[string]bool, len(drop))
	for _, k := range drop {
		skip[k] = true
	}
	out := make([]string, 0, len(env))
	for _, e := range env {
		key := e
		if i := strings.IndexByte(e, '='); i >= 0 {
			key = e[:i]
		}
		if skip[key] {
			continue
		}
		out = append(out, e)
	}
	return out
}

func removeGlob(pattern string) {
	matches, _ := filepath.Glob(pattern)
	for _, m := range matches {
		_ = os.Remove(m)
	}
}

func telegramEntry(args []string) int {
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		runtime = "/tmp/xdg"
	}
	home := os.Getenv("HOME")
	if home == "" {
		home = "/home/telegram"
	}
	workdir := filepath.Join(home, ".local/share/TelegramDesktop")

	_ = os.MkdirAll(runtime, 0o755)
	_ = os.MkdirAll(filepath.Join(home, "Downloads"), 0o755)
	_ = os.MkdirAll(filepath.Join(home, "ipc"), 0o755)
	_ = os.MkdirAll(workdir, 0o755)

	_ = os.Remove(filepath.Join(runtime, "bus"))
	_ = os.Remove(filepath.Join(workdir, "lock"))
	_ = os.Remove(filepath.Join(workdir, ".lock"))

	bus := filepath.Join(runtime, "bus")
	if st, err := os.Stat(bus); err != nil || st.Mode()&os.ModeSocket == 0 {
		_ = exec.Command("dbus-daemon", "--session", "--fork", "--address=unix:path="+bus).Run()
	}

	for _, cand := range []string{
		"/usr/local/bin/filemanager1-stub",
		filepath.Join(home, ".local/bin/filemanager1-stub"),
	} {
		if st, err := os.Stat(cand); err == nil && !st.IsDir() && st.Mode()&0o111 != 0 {
			cmd := exec.Command(cand)
			cmd.Env = append(os.Environ(), "DBUS_SESSION_BUS_ADDRESS=unix:path="+bus, "HOME="+home)
			_ = cmd.Start()
			break
		}
	}

	link := readTrim(filepath.Join("/ipc", "telegram.url"))
	if link == "" {
		link = readTrim(filepath.Join(home, "ipc", "telegram.url"))
		if link != "" {
			_ = os.WriteFile(filepath.Join(home, "ipc", "telegram.url"), nil, 0o644)
		}
	} else {
		_ = os.WriteFile(filepath.Join("/ipc", "telegram.url"), nil, 0o644)
	}

	gtkAlt := `[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=WhiteSur-Dark-alt
gtk-icon-theme-name=WhiteSur-dark
`
	for _, sub := range []string{"gtk-3.0", "gtk-4.0"} {
		dir := filepath.Join(home, ".config", sub)
		_ = os.MkdirAll(dir, 0o755)
		_ = os.WriteFile(filepath.Join(dir, "settings.ini"), []byte(gtkAlt), 0o644)
	}

	tgArgs := []string{
		"env", "-u", "QT_STYLE_OVERRIDE", "-u", "QT_QUICK_CONTROLS_STYLE", "-u", "QT_QPA_PLATFORMTHEME",
		"DBUS_SESSION_BUS_ADDRESS=unix:path=" + bus,
		"HOME=" + home,
		"XDG_RUNTIME_DIR=" + runtime,
	}
	tgArgs = append(tgArgs,
		"WAYLAND_DISPLAY="+def("WAYLAND_DISPLAY", "wayland-1"),
		"PULSE_SERVER="+def("PULSE_SERVER", "unix:/tmp/pulse-native"),
		"LANG="+def("LANG", "ru_RU.UTF-8"),
		"LC_ALL="+def("LC_ALL", "ru_RU.UTF-8"),
		"QT_QPA_PLATFORM="+def("QT_QPA_PLATFORM", "wayland"),
		"QT_AUTO_SCREEN_SCALE_FACTOR=1",
		"XDG_CURRENT_DESKTOP="+def("XDG_CURRENT_DESKTOP", "GNOME"),
		"GTK_THEME="+def("GTK_THEME", "WhiteSur-Dark-alt:dark"),
		"GTK_APPLICATION_PREFER_DARK_THEME=1",
		"ADW_DEBUG_COLOR_SCHEME=prefer-dark",
		"GTK_USE_PORTAL=0",
		"COLOR_SCHEME=prefer-dark",
		"/opt/Telegram/Telegram", "-workdir", workdir,
	)
	if link != "" {
		tgArgs = append(tgArgs, link)
	}

	cmd := exec.Command(tgArgs[0], tgArgs[1:]...)
	cmd.Stdin = os.Stdin
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

func def(key, val string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return val
}

func readTrim(path string) string {
	b, err := os.ReadFile(path)
	if err != nil || len(b) == 0 {
		return ""
	}
	return strings.TrimSpace(string(b))
}
