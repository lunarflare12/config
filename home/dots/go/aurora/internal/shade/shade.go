package shade

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"aurora/internal/execx"
)

func cfgDir() string {
	if d := os.Getenv("XDG_CONFIG_HOME"); d != "" {
		return filepath.Join(d, "hypr")
	}
	return filepath.Join(execx.Home(), ".config", "hypr")
}

func shaderRoot() string { return filepath.Join(cfgDir(), "shaders", "liixini") }
func currentFile() string { return filepath.Join(shaderRoot(), "CURRENT") }
func dirFile() string     { return filepath.Join(cfgDir(), "hypr-window-shade-dir") }

func resolveSo() (string, error) {
	if b, err := os.ReadFile(dirFile()); err == nil {
		dir := strings.TrimSpace(string(b))
		for _, cand := range []string{
			filepath.Join(dir, "lib", "libHyprWindowShade.so"),
			filepath.Join(dir, "lib", "HyprWindowShade.so"),
		} {
			if st, err := os.Stat(cand); err == nil && !st.IsDir() {
				return cand, nil
			}
		}
	}
	matches, _ := filepath.Glob("/nix/store/*HyprWindowShade*/lib/libHyprWindowShade.so")
	for _, cand := range matches {
		if st, err := os.Stat(cand); err == nil && !st.IsDir() {
			return cand, nil
		}
	}
	return "", fmt.Errorf("plugin .so not found")
}

func pluginLoaded() bool {
	_, out := execx.Run(2*time.Second, "hyprctl", "plugin", "list")
	return strings.Contains(strings.ToLower(out), "hyprwindowshade")
}

func unload() {
	so, err := resolveSo()
	if err != nil {
		return
	}
	_, _ = execx.Run(3*time.Second, "hyprctl", "plugin", "unload", so)
}

func load(effect string) int {
	so, err := resolveSo()
	if err != nil {
		fmt.Fprintln(os.Stderr, "hypr-window-shade: plugin .so not found (rebuild home-manager)")
		return 1
	}
	if !pluginLoaded() {
		if code, _ := execx.Run(5*time.Second, "hyprctl", "plugin", "load", so); code != 0 {
			return code
		}
	}
	if effect != "" {
		_ = os.MkdirAll(shaderRoot(), 0o755)
		_ = os.WriteFile(currentFile(), []byte(effect+"\n"), 0o644)
		_, _ = execx.Run(5*time.Second, "hyprctl", "reload")
	}
	return 0
}

func list() int {
	ents, err := os.ReadDir(shaderRoot())
	if err != nil {
		return 0
	}
	var names []string
	for _, e := range ents {
		if e.IsDir() {
			names = append(names, e.Name())
		}
	}
	for i := 0; i < len(names); i++ {
		for j := i + 1; j < len(names); j++ {
			if names[j] < names[i] {
				names[i], names[j] = names[j], names[i]
			}
		}
	}
	for _, n := range names {
		fmt.Println(n)
	}
	return 0
}

func current() int {
	b, err := os.ReadFile(currentFile())
	if err != nil {
		fmt.Println("crosshatch")
		return 0
	}
	fmt.Println(strings.TrimSpace(string(b)))
	return 0
}

func Main(args []string) int {
	cmd := "load"
	if len(args) > 0 {
		cmd = args[0]
	}
	switch cmd {
	case "load", "reload":
		effect := ""
		if len(args) > 1 {
			effect = args[1]
		}
		return load(effect)
	case "unload", "unload-game":
		unload()
		return 0
	case "set":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "usage: aurora shade set <effect>")
			return 2
		}
		return load(args[1])
	case "list":
		return list()
	case "current":
		return current()
	default:
		fmt.Fprintln(os.Stderr, "usage: aurora shade load|reload|unload|set <effect>|list|current")
		return 2
	}
}
