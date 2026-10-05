package space

import (
	"os"
	"path/filepath"
	"strings"

	"aurora/internal/execx"
)

func LoadEnv() {
	path := filepath.Join(execx.Home(), ".config", "aurora", "space-env.sh")
	b, err := os.ReadFile(path)
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "export ") {
			line = strings.TrimPrefix(line, "export ")
		}
		i := strings.IndexByte(line, '=')
		if i <= 0 {
			continue
		}
		k := line[:i]
		v := strings.Trim(line[i+1:], `"'`)
		if os.Getenv(k) == "" {
			_ = os.Setenv(k, v)
		}
	}
	defaults := map[string]string{
		"GTK_THEME":                            "WhiteSur-Dark",
		"GTK_APPLICATION_PREFER_DARK_THEME":    "1",
		"GTK_ICON_THEME":                       "WhiteSur-dark",
		"QT_QPA_PLATFORMTHEME":                 "qt6ct",
		"QT_STYLE_OVERRIDE":                    "kvantum",
		"QT_QUICK_CONTROLS_STYLE":              "Fusion",
		"ADW_DEBUG_COLOR_SCHEME":               "prefer-dark",
		"ELECTRON_FORCE_DARK":                  "1",
		"GTK_USE_PORTAL":                       "0",
		"COLOR_SCHEME":                         "prefer-dark",
	}
	for k, v := range defaults {
		if os.Getenv(k) == "" {
			_ = os.Setenv(k, v)
		}
	}
}

func LoadAppsEnv() {
	envf := filepath.Join(execx.Home(), "containers", "apps", ".env")
	b, err := os.ReadFile(envf)
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		i := strings.IndexByte(line, '=')
		if i <= 0 {
			continue
		}
		k := line[:i]
		v := strings.Trim(line[i+1:], `"'`)
		_ = os.Setenv(k, v)
	}
}

func DockerEnv() []string {
	LoadEnv()
	keys := []string{
		"GTK_THEME", "GTK_APPLICATION_PREFER_DARK_THEME", "GTK_ICON_THEME",
		"QT_QPA_PLATFORMTHEME", "QT_STYLE_OVERRIDE", "QT_QUICK_CONTROLS_STYLE",
		"ADW_DEBUG_COLOR_SCHEME", "ELECTRON_FORCE_DARK", "GTK_USE_PORTAL", "COLOR_SCHEME",
	}
	var out []string
	for _, k := range keys {
		out = append(out, "-e", k+"="+os.Getenv(k))
	}
	return out
}

func DisplayEnv() []string {
	wl := os.Getenv("WAYLAND_DISPLAY")
	if wl == "" {
		wl = "wayland-1"
	}
	return []string{
		"-e", "XDG_RUNTIME_DIR=/tmp/xdg",
		"-e", "WAYLAND_DISPLAY=" + wl,
		"-e", "GDK_BACKEND=wayland",
		"-e", "MOZ_ENABLE_WAYLAND=1",
		"-e", "QT_QPA_PLATFORM=wayland",
	}
}
