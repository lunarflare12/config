package game

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"aurora/internal/execx"
	"aurora/internal/protect"
)

func spaceDockerEnv() []string {
	get := func(k, def string) string {
		if v := os.Getenv(k); v != "" {
			return v
		}
		return def
	}
	keys := []struct{ k, def string }{
		{"GTK_THEME", "WhiteSur-Dark"},
		{"GTK_APPLICATION_PREFER_DARK_THEME", "1"},
		{"GTK_ICON_THEME", "WhiteSur-dark"},
		{"QT_QPA_PLATFORMTHEME", "qt6ct"},
		{"QT_STYLE_OVERRIDE", "kvantum"},
		{"QT_QUICK_CONTROLS_STYLE", "Fusion"},
		{"ADW_DEBUG_COLOR_SCHEME", "prefer-dark"},
		{"ELECTRON_FORCE_DARK", "1"},
		{"GTK_USE_PORTAL", "0"},
		{"COLOR_SCHEME", "prefer-dark"},
	}
	var out []string
	for _, kv := range keys {
		out = append(out, "-e", kv.k+"="+get(kv.k, kv.def))
	}
	return out
}

func loadSpaceEnv() {
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
		if i := strings.IndexByte(line, '='); i > 0 {
			k := line[:i]
			v := strings.Trim(line[i+1:], `"'`)
			if os.Getenv(k) == "" {
				_ = os.Setenv(k, v)
			}
		}
	}
}

func steamMain(args []string) int {
	loadSpaceEnv()
	_ = protect.Main(nil)
	if a := execx.Look("aurora"); a != "" {
		_ = execx.RunOK(3*time.Second, a, "fossilize")
	}

	uri := ""
	if len(args) > 0 {
		uri = args[0]
	}
	switch {
	case strings.Contains(uri, "105600"):
		return Main([]string{"terraria"})
	case strings.Contains(uri, "761890"):
		return Main([]string{"albion"})
	case strings.Contains(uri, "33100"):
		return Main([]string{"alien-shooter"})
	}

	_ = os.MkdirAll(filepath.Join(execx.Home(), "programs", "steam"), 0o755)
	_ = exec.Command("docker", "rm", "-f", "terraria", "albion").Run()

	if !execx.RunOK(2*time.Second, "docker", "image", "inspect", "steam-box:1") {
		build := filepath.Join(execx.Home(), "Documents", "projects", "config", "home", "dots", "containers", "steam")
		_ = exec.Command("docker", "build", "-t", "steam-box:1", build).Run()
	}
	_ = exec.Command("docker", "compose", "-f", composePath(), "up", "-d", "--no-deps", "--no-build", "steam").Run()
	for i := 0; i < 30; i++ {
		_, running := execx.Run(2*time.Second, "docker", "inspect", "-f", "{{.State.Running}}", "steam")
		if strings.TrimSpace(running) == "true" {
			break
		}
		time.Sleep(200 * time.Millisecond)
	}

	if len(args) == 0 {
		return 0
	}

	steamBin := ""
	if b, err := os.ReadFile(filepath.Join(execx.Home(), ".local", "share", "aurora", "steam-bin")); err == nil {
		steamBin = strings.TrimSpace(string(b))
	}
	if steamBin == "" || !fileExec(steamBin) {
		steamBin, _ = exec.LookPath("steam-fhs")
	}
	if steamBin == "" || !fileExec(steamBin) {
		fmt.Fprintln(os.Stderr, "steam: missing ~/.local/share/aurora/steam-bin (rebuild system with modules/steam.nix)")
		return 1
	}

	disp := os.Getenv("DISPLAY")
	if disp == "" {
		disp = ":0"
	}
	dargs := []string{"exec", "-u", "app", "-e", "DISPLAY=" + disp, "-e", "STEAM_CONTAINER=1"}
	dargs = append(dargs, spaceDockerEnv()...)
	dargs = append(dargs, "steam", steamBin, "-forcedesktopscaling", "1")
	dargs = append(dargs, args...)
	cmd := exec.Command("docker", dargs...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}

func fileExec(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir() && st.Mode()&0o111 != 0
}
