package game

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"aurora/internal/execx"
)

func generalsRes() (w, h string) {
	w = envOr("GENERALS_WIDTH", "2560")
	h = envOr("GENERALS_HEIGHT", "1080")
	return w, h
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func generalsExe(zh string) string {
	for _, name := range []string{"GeneralsOnlineZH_60.exe", "GeneralsOnlineZH.exe"} {
		p := filepath.Join(zh, name)
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	return ""
}

func closeWineDesktop() {
	out, err := exec.Command("hyprctl", "-j", "clients").Output()
	if err != nil {
		return
	}
	type client struct {
		Class   string `json:"class"`
		Title   string `json:"title"`
		Address string `json:"address"`
	}
	var clients []client
	if json.Unmarshal(out, &clients) != nil {
		return
	}
	for _, c := range clients {
		if c.Class != "steam_proton" || !strings.Contains(c.Title, "Wine Desktop") || c.Address == "" {
			continue
		}
		expr := fmt.Sprintf(
			`(function() local w = hl.get_window("address:%s"); if w then hl.dispatch(hl.dsp.window.close({ window = w })) end; return true end)()`,
			c.Address,
		)
		_ = exec.Command("hyprctl", "eval", expr).Run()
	}
}

func cleanupWine(wineserver, prefix string) {
	if wineserver != "" {
		cmd := exec.Command("steam-run", "env",
			"WINEPREFIX="+prefix, "WINEARCH=win64", wineserver, "-k")
		_ = cmd.Run()
	}
	time.Sleep(300 * time.Millisecond)
	closeWineDesktop()
	_ = exec.Command("pkill", "-f", `Games/generals/.*/explorer\.exe`).Run()
	time.Sleep(200 * time.Millisecond)
	closeWineDesktop()
}

func generalsLive() bool {
	out, err := exec.Command("pgrep", "-f", "GeneralsOnlineZH").Output()
	if err != nil {
		return false
	}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		pid := strings.TrimSpace(line)
		if pid == "" {
			continue
		}
		st, err := os.ReadFile(filepath.Join("/proc", pid, "status"))
		if err != nil {
			continue
		}
		if bytes.Contains(st, []byte("State:\tZ")) {
			continue
		}
		commB, err := os.ReadFile(filepath.Join("/proc", pid, "comm"))
		if err != nil {
			continue
		}
		comm := strings.TrimSpace(string(commB))
		if strings.HasPrefix(comm, "GeneralsOnline") || comm == "generals.exe" || comm == "Generals.exe" {
			return true
		}
		cmdB, err := os.ReadFile(filepath.Join("/proc", pid, "cmdline"))
		if err != nil {
			continue
		}
		cmd0 := strings.Split(string(cmdB), "\x00")[0]
		switch {
		case strings.Contains(cmd0, "explorer.exe"),
			strings.Contains(cmd0, "start.exe"),
			strings.HasSuffix(cmd0, "/bin/wine"),
			strings.HasSuffix(cmd0, "/bin/wine64"),
			strings.Contains(cmd0, "bwrap"),
			strings.Contains(cmd0, "steam-run"):
			continue
		}
		if strings.Contains(cmd0, "GeneralsOnlineZH") {
			return true
		}
	}
	return false
}

func ensureHotkeys(csf string) {
	if st, err := os.Stat(csf); err == nil && st.Size() >= 100000 {
		return
	}
	_ = os.MkdirAll(filepath.Dir(csf), 0o755)
	client := &http.Client{Timeout: 45 * time.Second}
	resp, err := client.Get("https://www.gentool.net/download/hotkeys/HotkeysEnglishZH_v1.5.zip")
	if err != nil {
		fmt.Fprintln(os.Stderr, "hotkeys skip:", err)
		return
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return
	}
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return
	}
	for _, f := range zr.File {
		if !strings.HasSuffix(strings.ToLower(f.Name), ".csf") {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return
		}
		b, err := io.ReadAll(rc)
		_ = rc.Close()
		if err != nil {
			return
		}
		_ = os.WriteFile(csf, b, 0o644)
		return
	}
}

func patchCameraSettings(path string) {
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	s := map[string]any{}
	if b, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(b, &s)
	}
	cam, _ := s["camera"].(map[string]any)
	if cam == nil {
		cam = map[string]any{}
		s["camera"] = cam
	}
	if _, ok := cam["max_height_only_when_lobby_host"]; !ok {
		cam["max_height_only_when_lobby_host"] = 500.0
	}
	if _, ok := cam["min_height"]; !ok {
		cam["min_height"] = 100.0
	}
	if _, ok := cam["move_speed_ratio"]; !ok {
		cam["move_speed_ratio"] = 1.0
	}
	net, _ := s["network"].(map[string]any)
	if net == nil {
		net = map[string]any{}
		s["network"] = net
	}
	net["use_alternative_endpoint"] = true
	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return
	}
	_ = os.WriteFile(path, append(b, '\n'), 0o644)
}

func writeOptionsINI(doc, w, h string) {
	_ = os.MkdirAll(doc, 0o755)
	opts := fmt.Sprintf(`[Options]
AntiAliasing = 2
BuildingOcclusion = yes
DynamicLOD = no
ExtraAnimations = yes
FPSLimit = 60
FirewallBehavior = 9
FirewallPortAllocationDelta = 0
FirewallPortOverride = 0
HeatEffects = yes
IdealStaticGameLOD = High
Resolution = %s %s
ScrollFactor = 50
SendDelay = no
ShowTrees = yes
StaticGameLOD = High
TextureReduction = 0
UseCloudMap = yes
UseLightMap = yes
UseShadowMap = yes
UseShadowVolumes = yes
Windowed = no
`, w, h)
	_ = os.WriteFile(filepath.Join(doc, "Options.ini"), []byte(opts), 0o644)
}

func upsertINI(text, key, val string) string {
	re := regexp.MustCompile(`(?m)^` + regexp.QuoteMeta(key) + `=.*$`)
	line := key + "=" + val
	if re.MatchString(text) {
		return re.ReplaceAllString(text, line)
	}
	return strings.TrimRight(text, "\n") + "\n" + line + "\n"
}

func patchGentool(cfg string) {
	b, err := os.ReadFile(cfg)
	if err != nil {
		return
	}
	t := string(b)
	if !strings.Contains(t, "[gentool76]") {
		t = "[gentool76]\n" + t
	}
	t = upsertINI(t, "pitch", "37")
	t = upsertINI(t, "cursorlock", "1")
	_ = os.WriteFile(cfg, []byte(t), 0o644)
}

func patchUserReg(prefix, w, h, browser string) {
	p := filepath.Join(prefix, "user.reg")
	t := ""
	if b, err := os.ReadFile(p); err == nil {
		t = string(b)
	}
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	if !regexp.MustCompile(`(?m)^\[Software\\\\Wine\\\\Explorer\]`).MatchString(t) {
		t += fmt.Sprintf("\n[Software\\\\Wine\\\\Explorer] %s\n#time=1dd000000000000\n\"Desktop\"=\"Default\"\n", ts)
	} else if regexp.MustCompile(`(?m)^"Desktop"=`).MatchString(t) {
		t = regexp.MustCompile(`(?m)^"Desktop"=".*"`).ReplaceAllString(t, `"Desktop"="Default"`)
	} else {
		t = regexp.MustCompile(`(?m)^(\[Software\\\\Wine\\\\Explorer\][^\n]*\n(?:#time=[^\n]*\n)?)`).
			ReplaceAllString(t, `${1}"Desktop"="Default"`+"\n")
	}
	desk := fmt.Sprintf(`"Default"="%sx%s"`, w, h)
	if regexp.MustCompile(`(?m)^\[Software\\\\Wine\\\\Explorer\\\\Desktops\]`).MatchString(t) {
		if regexp.MustCompile(`(?m)^"Default"="\d+x\d+"`).MatchString(t) {
			t = regexp.MustCompile(`(?m)^"Default"="\d+x\d+"`).ReplaceAllString(t, desk)
		} else {
			t = regexp.MustCompile(`(?m)^(\[Software\\\\Wine\\\\Explorer\\\\Desktops\][^\n]*\n(?:#time=[^\n]*\n)?)`).
				ReplaceAllString(t, `${1}`+desk+"\n")
		}
	} else {
		t += fmt.Sprintf("\n[Software\\\\Wine\\\\Explorer\\\\Desktops] %s\n#time=1dd000000000000\n%s\n", ts, desk)
	}
	t = regexp.MustCompile(`(?m)^"MouseWarpOverride"=".*"`).ReplaceAllString(t, `"MouseWarpOverride"="enable"`)
	t = regexp.MustCompile(`(?m)^"GrabFullscreen"=".*"`).ReplaceAllString(t, `"GrabFullscreen"="N"`)
	if !regexp.MustCompile(`(?m)^"MouseWarpOverride"=`).MatchString(t) {
		t += fmt.Sprintf("\n[Software\\\\Wine\\\\X11 Driver] %s\n\"MouseWarpOverride\"=\"enable\"\n\"GrabFullscreen\"=\"N\"\n", ts)
	}
	wb := fmt.Sprintf(`"Browsers"="%s %%s"`, browser)
	if regexp.MustCompile(`(?m)^\[Software\\\\Wine\\\\WineBrowser\]`).MatchString(t) {
		if regexp.MustCompile(`(?m)^"Browsers"=`).MatchString(t) {
			t = regexp.MustCompile(`(?m)^"Browsers"=.*$`).ReplaceAllString(t, wb)
		} else {
			t = regexp.MustCompile(`(?m)^(\[Software\\\\Wine\\\\WineBrowser\][^\n]*\n(?:#time=[^\n]*\n)?)`).
				ReplaceAllString(t, `${1}`+wb+"\n")
		}
	} else {
		t += fmt.Sprintf("\n[Software\\\\Wine\\\\WineBrowser] %s\n#time=1dd000000000000\n%s\n", ts, wb)
	}
	_ = os.WriteFile(p, []byte(t), 0o644)
	fmt.Printf("wine desktop %sx%s\n", w, h)
}

func generalsBrowser(args []string) int {
	url := ""
	for _, a := range args {
		if strings.HasPrefix(a, "http://") || strings.HasPrefix(a, "https://") {
			url = a
			break
		}
	}
	if url == "" && len(args) > 0 {
		url = args[len(args)-1]
	}
	if url == "" {
		return 0
	}
	f, _ := os.OpenFile("/tmp/go-winebrowser.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if f != nil {
		fmt.Fprintf(f, "%s argv: %v\n", time.Now().Format(time.RFC3339), args)
		_ = f.Close()
	}
	if strings.Contains(url, "playgenerals.online/login") {
		code := ""
		if i := strings.Index(url, "code="); i >= 0 {
			code = url[i+5:]
			if j := strings.IndexByte(code, '&'); j >= 0 {
				code = code[:j]
			}
		}
		if code != "" {
			_ = exec.Command("wl-copy", code).Run()
		}
		_ = exec.Command("notify-send", "-u", "critical", "Generals Online",
			fmt.Sprintf("Login page Error 102. Code in clipboard: %s. Open Discord Command Center.", orDash(code))).Run()
		url = "https://discord.playgenerals.online/"
	}
	chrome := execx.Look("google-chrome")
	if chrome != "" {
		_ = exec.Command(chrome, url).Start()
	} else {
		_ = exec.Command("xdg-open", url).Start()
	}
	return 0
}

func orDash(s string) string {
	if s == "" {
		return "?"
	}
	return s
}

func pinGeneralsOutputs() {
	out, err := exec.Command("hyprctl", "monitors", "-j").Output()
	if err != nil {
		return
	}
	type mon struct {
		Name string `json:"name"`
	}
	var mons []mon
	if json.Unmarshal(out, &mons) != nil {
		return
	}
	dp, hdmi := "DP-4", "HDMI-A-2"
	for _, m := range mons {
		if strings.HasPrefix(m.Name, "DP-") {
			dp = m.Name
			break
		}
	}
	for _, m := range mons {
		if strings.HasPrefix(m.Name, "HDMI-") {
			hdmi = m.Name
			break
		}
	}
	expr := fmt.Sprintf(`
hl.monitor({ output = "%s", mode = "2560x1080@200.00Hz", position = "0x0", scale = 1, bitdepth = 8, disabled = false })
hl.monitor({ output = "%s", mode = "1920x1080@60.00Hz", position = "2560x0", scale = 1, bitdepth = 8, disabled = false })
`, dp, hdmi)
	_ = exec.Command("hyprctl", "eval", expr).Run()
}

func watchLoginCode(logPath string, stop <-chan struct{}) {
	opened := ""
	for i := 0; i < 120; i++ {
		select {
		case <-stop:
			return
		default:
		}
		b, err := os.ReadFile(logPath)
		if err == nil {
			re := regexp.MustCompile(`"login_code"\s*:\s*"([A-Za-z0-9]+)"`)
			matches := re.FindAllSubmatch(b, -1)
			if len(matches) > 0 {
				code := string(matches[len(matches)-1][1])
				if code != "" && code != opened {
					opened = code
					_ = exec.Command("wl-copy", code).Run()
					_ = exec.Command("notify-send", "Generals Online", "Login code copied: "+code).Run()
				}
			}
		}
		time.Sleep(2 * time.Second)
	}
}

func placeWineDesktop() {
	outName := envOr("GENERALS_OUTPUT", "DP-4")
	for i := 0; i < 40; i++ {
		out, err := exec.Command("hyprctl", "-j", "clients").Output()
		if err == nil {
			type client struct {
				Class   string `json:"class"`
				Title   string `json:"title"`
				Address string `json:"address"`
			}
			var clients []client
			if json.Unmarshal(out, &clients) == nil {
				for _, c := range clients {
					if c.Class == "steam_proton" && strings.Contains(c.Title, "Wine Desktop") && c.Address != "" {
						_ = exec.Command("hyprctl", "eval",
							fmt.Sprintf(`hl.dispatch(hl.dsp.window.move({ output = "%s", window = "%s" }))`, outName, c.Address)).Run()
						_ = exec.Command("hyprctl", "eval",
							fmt.Sprintf(`hl.dispatch(hl.dsp.window.fullscreen_state({ window = "%s", internal = 0, client = 0 }))`, c.Address)).Run()
						return
					}
				}
			}
		}
		time.Sleep(400 * time.Millisecond)
	}
}

func generalsMain(args []string) int {
	if len(args) > 0 && (args[0] == "browser" || args[0] == "open-url") {
		return generalsBrowser(args[1:])
	}

	home := execx.Home()
	prefix := filepath.Join(home, "Games/generals")
	zh := filepath.Join(prefix, "drive_c/Program Files (x86)/EA Games/Command and Conquer Generals/Command and Conquer Generals Zero Hour")
	wine := filepath.Join(home, ".local/share/lutris/runners/wine/proton-cachyos-x86_64/files/bin/wine")
	wineserver := filepath.Join(filepath.Dir(wine), "wineserver")
	resW, resH := generalsRes()
	doc := filepath.Join(prefix, "drive_c/users/steamuser/Documents/Command and Conquer Generals Zero Hour Data")

	exe := generalsExe(zh)
	if exe == "" {
		fmt.Fprintln(os.Stderr, "GeneralsOnlineZH not found in:", zh)
		return 1
	}
	if st, err := os.Stat(wine); err != nil || st.IsDir() {
		fmt.Fprintln(os.Stderr, "wine not found:", wine)
		return 1
	}

	ensureXwayland()
	pinGeneralsOutputs()

	_ = os.Setenv("WINEPREFIX", prefix)
	_ = os.Setenv("WINEARCH", "win64")
	_ = os.Setenv("WINEESYNC", "0")
	_ = os.Setenv("WINEFSYNC", "0")
	dll := "d3d8=n,b;d3d9=b"
	_ = os.Setenv("WINEDLLOVERRIDES", dll)

	for _, d := range []string{
		filepath.Join(home, ".cache/steam-shadercache"),
		filepath.Join(home, ".cache/dxvk"),
		filepath.Join(home, ".cache/nvidia"),
	} {
		_ = os.MkdirAll(d, 0o755)
	}

	cleanup := func() { cleanupWine(wineserver, prefix) }
	defer cleanup()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)
	go func() {
		<-sigCh
		cleanup()
		os.Exit(0)
	}()

	// Detached reaper if Lutris SIGKILLs us.
	go func() {
		for i := 0; i < 180; i++ {
			if generalsLive() {
				break
			}
			time.Sleep(500 * time.Millisecond)
		}
		if !generalsLive() {
			return
		}
		for generalsLive() {
			time.Sleep(time.Second)
		}
		time.Sleep(400 * time.Millisecond)
		cleanupWine(wineserver, prefix)
	}()

	ensureHotkeys(filepath.Join(zh, "Data/English/generals.csf"))
	patchCameraSettings(filepath.Join(doc, "GeneralsOnlineData/settings.json"))
	writeOptionsINI(doc, resW, resH)
	patchGentool(filepath.Join(zh, "d3d8.cfg"))

	auroraBin := execx.Look("aurora")
	if auroraBin == "" {
		auroraBin = "/etc/profiles/per-user/dd/bin/aurora"
	}
	browser := auroraBin + " game generals browser"
	patchUserReg(prefix, resW, resH, browser)

	_ = exec.Command("hyprctl", "eval",
		`hl.window_rule({ name = "generals-wine-desktop-runtime", match = { class = "^steam_proton$", title = ".*Wine Desktop.*" }, fullscreen_state = "0 0", sync_fullscreen = false, confine_pointer = true, suppress_event = "x11configurerequest", decorate = false, border_size = 0 })`).Run()

	stopWatch := make(chan struct{})
	go watchLoginCode(filepath.Join(doc, "GeneralsOnlineData/GeneralsOnline.log"), stopWatch)
	defer close(stopWatch)

	go placeWineDesktop()

	wineArgs := append([]string{
		"env",
		"WINEPREFIX=" + prefix,
		"WINEARCH=win64",
		"WINEESYNC=0",
		"WINEFSYNC=0",
		"WINEDLLOVERRIDES=" + dll,
		wine, "explorer",
		fmt.Sprintf("/desktop=Default,%sx%s", resW, resH),
		exe,
	}, args...)
	cmd := exec.Command("steam-run", wineArgs...)
	cmd.Dir = zh
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		fmt.Fprintln(os.Stderr, "steam-run wine:", err)
		return 1
	}

	for i := 0; i < 120; i++ {
		if generalsLive() {
			break
		}
		time.Sleep(500 * time.Millisecond)
	}
	if !generalsLive() {
		fmt.Fprintln(os.Stderr, "GeneralsOnlineZH did not start")
		return 1
	}
	for generalsLive() {
		time.Sleep(time.Second)
	}
	cleanup()
	return 0
}
