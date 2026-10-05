package game

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"aurora/internal/execx"
)

func stripOverlay() {
	preload := os.Getenv("LD_PRELOAD")
	if preload == "" {
		return
	}
	var kept []string
	for _, p := range strings.Split(preload, ":") {
		if p == "" || strings.Contains(p, "gameoverlayrenderer") {
			continue
		}
		kept = append(kept, p)
	}
	_ = os.Setenv("LD_PRELOAD", strings.Join(kept, ":"))
}

func lowLatency() {
	_ = os.Setenv("__GL_SYNC_TO_VBLANK", "0")
	_ = os.Setenv("vblank_mode", "0")
	_ = os.Unsetenv("SDL_VIDEODRIVER")
}

func hyprSig() string {
	if s := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"); s != "" {
		return s
	}
	if s := os.Getenv("AURORA_HYPR_SIG"); s != "" {
		return s
	}
	xdg := os.Getenv("HOST_XDG_RUNTIME_DIR")
	if xdg == "" {
		xdg = "/run/user/1000"
	}
	hypr := filepath.Join(xdg, "hypr")
	ents, err := os.ReadDir(hypr)
	if err != nil {
		return ""
	}
	// newest first by mtime
	type cand struct {
		name string
		mod  time.Time
	}
	var list []cand
	for _, e := range ents {
		info, err := e.Info()
		if err != nil {
			continue
		}
		list = append(list, cand{e.Name(), info.ModTime()})
	}
	for i := 0; i < len(list); i++ {
		for j := i + 1; j < len(list); j++ {
			if list[j].mod.After(list[i].mod) {
				list[i], list[j] = list[j], list[i]
			}
		}
	}
	for _, c := range list {
		cmd := exec.Command("hyprctl", "version")
		cmd.Env = hostEnv(c.name)
		if err := cmd.Run(); err == nil {
			_ = os.Setenv("AURORA_HYPR_SIG", c.name)
			return c.name
		}
	}
	return ""
}

func hostEnv(sig string) []string {
	xdg := os.Getenv("HOST_XDG_RUNTIME_DIR")
	if xdg == "" {
		xdg = "/run/user/1000"
	}
	base := []string{
		"PATH=/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin",
		"XDG_RUNTIME_DIR=" + xdg,
		"HYPRLAND_INSTANCE_SIGNATURE=" + sig,
		"HOME=" + execx.Home(),
		"USER=dd",
	}
	for _, kv := range os.Environ() {
		if strings.HasPrefix(kv, "LD_PRELOAD=") ||
			strings.HasPrefix(kv, "LD_LIBRARY_PATH=") ||
			strings.HasPrefix(kv, "STEAM_RUNTIME_LIBRARY_PATH=") {
			continue
		}
		if strings.HasPrefix(kv, "PATH=") ||
			strings.HasPrefix(kv, "XDG_RUNTIME_DIR=") ||
			strings.HasPrefix(kv, "HYPRLAND_INSTANCE_SIGNATURE=") {
			continue
		}
		base = append(base, kv)
	}
	return base
}

func host(args ...string) *exec.Cmd {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Env = hostEnv(hyprSig())
	return cmd
}

func pinUS() {
	_ = host("hyprctl", "switchxkblayout", "zsa-technology-labs-moonlander-mark-i", "0").Run()
}

func outputsOK() bool {
	cmd := host("hyprctl", "monitors", "-j")
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	s := string(out)
	need := []string{
		`"width": 1920`, `"height": 1080`, `"refreshRate": 60`,
		`"width": 2560`, `"height": 1080`, `"refreshRate": 200`,
	}
	// crude: both monitors present with expected modes
	hasHDMI := strings.Contains(s, `"name": "HDMI-A-2"`) || strings.Contains(s, `"name": "HDMI-A-1"`)
	hasDP := strings.Contains(s, `"name": "DP-4"`) || strings.Contains(s, `"name": "DP-1"`)
	if !hasHDMI || !hasDP {
		return false
	}
	for _, n := range need {
		if !strings.Contains(s, n) {
			return false
		}
	}
	return strings.Contains(s, `"x": 2560`) && strings.Contains(s, `"x": 0`)
}

func pinOutputs() {
	if outputsOK() {
		return
	}
	cmd := host("hyprctl", "monitors", "-j")
	out, _ := cmd.Output()
	dp, hdmi := "DP-4", "HDMI-A-2"
	dpRe := regexp.MustCompile(`"name":\s*"(DP-[^"]+)"`)
	hdmiRe := regexp.MustCompile(`"name":\s*"(HDMI-[^"]+)"`)
	if m := dpRe.FindSubmatch(out); m != nil {
		dp = string(m[1])
	}
	if m := hdmiRe.FindSubmatch(out); m != nil {
		hdmi = string(m[1])
	}
	eval := fmt.Sprintf(`hl.monitor({ output = "%s", mode = "2560x1080@200.00Hz", position = "0x0", scale = 1, bitdepth = 8, disabled = false })
hl.monitor({ output = "%s", mode = "1920x1080@60.00Hz", position = "2560x0", scale = 1, bitdepth = 8, disabled = false })`, dp, hdmi)
	_ = host("hyprctl", "eval", eval).Run()
}

func xwaylandPrimary() {
	want := "DP-4"
	cmd := host("hyprctl", "monitors", "-j")
	if out, err := cmd.Output(); err == nil {
		dpRe := regexp.MustCompile(`"name":\s*"(DP-[^"]+)"`)
		if m := dpRe.FindSubmatch(out); m != nil {
			want = string(m[1])
		}
	}
	disp := os.Getenv("DISPLAY")
	if disp == "" {
		disp = ":0"
	}
	c := host("env", "DISPLAY="+disp, "xrandr", "--output", want, "--primary")
	_ = c.Run()
}

func xwaylandUltrawide() {
	pinOutputs()
	xwaylandPrimary()
}

func patchAlbionPrefs() {
	prefs := filepath.Join(execx.Home(), ".config", "unity3d", "Sandbox Interactive GmbH", "Albion Online Client", "prefs")
	b, err := os.ReadFile(prefs)
	if err != nil {
		return
	}
	s := string(b)
	reW := regexp.MustCompile(`(Screenmanager Resolution Width" type="int">)[0-9]*`)
	reH := regexp.MustCompile(`(Screenmanager Resolution Height" type="int">)[0-9]*`)
	reM := regexp.MustCompile(`(UnitySelectMonitor" type="int">)[0-9]*`)
	s = reW.ReplaceAllString(s, `${1}2560`)
	s = reH.ReplaceAllString(s, `${1}1080`)
	s = reM.ReplaceAllString(s, `${1}1`)
	_ = os.WriteFile(prefs, []byte(s), 0o644)
}

func albionMain(args []string) int {
	if !inBox() {
		stopOther("albion")
		return hostSession("761890", "Albion-Online", "AlbionOnline")
	}

	stripOverlay()
	lowLatency()
	xh := os.Getenv("XDG_CACHE_HOME")
	if xh == "" {
		xh = filepath.Join(execx.Home(), ".cache")
	}
	albionNV := filepath.Join(xh, "nvidia", "albion")
	_ = os.MkdirAll(albionNV, 0o755)
	_ = os.WriteFile(filepath.Join(albionNV, ".frozen"), []byte("frozen\n"), 0o644)
	_ = os.Setenv("__GL_SHADER_DISK_CACHE", "1")
	_ = os.Setenv("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")
	if os.Getenv("__GL_SHADER_DISK_CACHE_SIZE") == "" {
		_ = os.Setenv("__GL_SHADER_DISK_CACHE_SIZE", "34359738368")
	}
	_ = os.Setenv("__GL_SHADER_DISK_CACHE_PATH", albionNV)
	_ = os.Setenv("__GL_SHADER_DISK_CACHE_APP_NAME", "steamapp_shader_cache")
	_ = os.Setenv("__GL_SHADER_DISK_CACHE_READ_ONLY_APP_NAME", "steam_shader_cache;steamapp_merged_shader_cache")
	xwaylandUltrawide()
	_ = os.Setenv("SDL_VIDEODRIVER", "x11")
	if os.Getenv("SDL_VIDEO_FULLSCREEN_DISPLAY") == "" {
		_ = os.Setenv("SDL_VIDEO_FULLSCREEN_DISPLAY", "0")
	}
	patchAlbionPrefs()
	_ = os.Unsetenv("GTK_IM_MODULE")
	_ = os.Unsetenv("QT_IM_MODULE")
	_ = os.Unsetenv("SDL_IM_MODULE")
	_ = os.Unsetenv("XMODIFIERS")

	pinUS()
	go func() {
		for i := 0; i < 40; i++ {
			pinUS()
			time.Sleep(time.Second)
		}
	}()

	filtered := filterAlbionArgs(args)
	filtered = append(filtered, "-screen-fullscreen", "0", "-screen-width", "2560", "-screen-height", "1080", "-monitor", "1")
	bin := filtered[0]
	rest := filtered[1:]
	if _, err := exec.LookPath("gamemoderun"); err == nil {
		cmd := exec.Command("gamemoderun", append([]string{bin}, rest...)...)
		cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
		if err := cmd.Run(); err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				return ee.ExitCode()
			}
			return 1
		}
		return 0
	}
	cmd := exec.Command(bin, rest...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}

func filterAlbionArgs(args []string) []string {
	out := make([]string, 0, len(args))
	skipNext := false
	for _, a := range args {
		if skipNext {
			skipNext = false
			continue
		}
		switch a {
		case "-screen-fullscreen":
			skipNext = true
			continue
		case "-screen-fullscreen 1", "-screen-fullscreen 0", "+fullscreen":
			continue
		}
		out = append(out, a)
	}
	return out
}
