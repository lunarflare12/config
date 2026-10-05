package apps

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"aurora/internal/execx"
	"aurora/internal/libreofficeui"
	"aurora/internal/space"
)

type chromeSpec struct {
	service string
	class   string
	profile string
	extra   []string
}

func appsCompose() string {
	return filepath.Join(execx.Home(), "containers", "apps", "compose.yml")
}

func tgCompose() string {
	return filepath.Join(execx.Home(), "containers", "telegram", "compose.yml")
}

func dockerUp(compose, service string) error {
	return exec.Command("docker", "compose", "-f", compose, "up", "-d", "--no-build", service).Run()
}

func running(name string) bool {
	_, out := execx.Run(2*time.Second, "docker", "inspect", "-f", "{{.State.Running}}", name)
	return strings.TrimSpace(out) == "true"
}

func dockerExec(user, container string, env []string, argv ...string) int {
	args := []string{"exec", "-u", user}
	args = append(args, env...)
	args = append(args, container)
	args = append(args, argv...)
	cmd := exec.Command("docker", args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}

func runChrome(spec chromeSpec, args []string) int {
	space.LoadEnv()
	space.LoadAppsEnv()
	chromeBin := os.Getenv("CHROME_BIN")
	if chromeBin == "" {
		fmt.Fprintln(os.Stderr, "apps: CHROME_BIN missing in containers/apps/.env")
		return 1
	}
	_ = dockerUp(appsCompose(), spec.service)
	if len(args) == 0 {
		return 0
	}
	env := append(space.DisplayEnv(), space.DockerEnv()...)
	argv := []string{
		chromeBin,
		"--user-data-dir=/home/app/.config/google-chrome",
		"--profile-directory=" + spec.profile,
		"--class=" + spec.class,
	}
	argv = append(argv, spec.extra...)
	argv = append(argv,
		"--ozone-platform=wayland",
		"--force-dark-mode",
		"--ignore-gpu-blocklist",
		"--enable-gpu-rasterization",
		"--enable-zero-copy",
		"--no-sandbox",
		"--disable-features=WebRtcPipeWireCamera",
		"--renderer-process-limit=6",
	)
	argv = append(argv, args...)
	return dockerExec("app", spec.service, env, argv...)
}

func findBin(names ...string) string {
	for _, n := range names {
		if p, err := exec.LookPath(n); err == nil {
			return p
		}
	}
	user := os.Getenv("USER")
	if user == "" {
		user = "dd"
	}
	for _, n := range names {
		for _, dir := range []string{
			"/etc/profiles/per-user/" + user + "/bin",
			"/run/current-system/sw/bin",
			filepath.Join(execx.Home(), ".nix-profile", "bin"),
		} {
			p := filepath.Join(dir, n)
			if st, err := os.Stat(p); err == nil && !st.IsDir() {
				return p
			}
		}
	}
	return ""
}

func discord(args []string) int {
	bin := findBin("vesktop")
	if bin == "" {
		matches, _ := filepath.Glob("/nix/store/*-vesktop-*/bin/vesktop")
		for _, m := range matches {
			if bin == "" || m > bin {
				bin = m
			}
		}
	}
	if bin == "" {
		fmt.Fprintln(os.Stderr, "discord: vesktop not found (home-manager switch needed)")
		return 1
	}
	if os.Getenv("ELECTRON_OZONE_PLATFORM_HINT") == "" {
		_ = os.Setenv("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
	}
	cmd := exec.Command(bin, append([]string{
		"--ozone-platform=wayland",
		"--force-dark-mode",
		"--js-flags=--max-old-space-size=512",
	}, args...)...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}

func ensureTelegramImage() {
	if execx.RunOK(2*time.Second, "docker", "image", "inspect", "telegram-desktop:7.2.9") {
		return
	}
	ctx := filepath.Join(execx.Home(), "Documents", "projects", "config", "home", "dots", "containers", "telegram")
	tarball := filepath.Join(execx.Home(), ".local", "share", "aurora", "containers", "telegram", "td-setup.tar.xz")
	if _, err := os.Stat(tarball); err != nil {
		tarball += ".hm.bak"
	}
	dst := filepath.Join(ctx, "td-setup.tar.xz")
	if _, err := os.Stat(dst); err != nil {
		if b, err := os.ReadFile(tarball); err == nil {
			_ = os.WriteFile(dst, b, 0o644)
		}
	}
	_ = exec.Command("docker", "build", "-t", "telegram-desktop:7.2.9", ctx).Run()
}

func telegram1(args []string) int {
	space.LoadEnv()
	url := ""
	if len(args) > 0 {
		url = args[0]
	}
	if running("telegram-1") {
		if url == "" {
			return 0
		}
		env := append(space.DisplayEnv(), space.DockerEnv()...)
		env = append(env,
			"-e", "DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/xdg/bus",
			"-e", "QT_QPA_PLATFORM=wayland",
		)
		dargs := []string{"exec", "-d", "-u", "telegram"}
		dargs = append(dargs, env...)
		dargs = append(dargs, "telegram-1", "/opt/Telegram/Telegram",
			"-workdir", "/home/telegram/.local/share/TelegramDesktop", url)
		_ = exec.Command("docker", dargs...).Run()
		return 0
	}
	ipcDir := filepath.Join(execx.Home(), "programs", "telegram-1", "ipc")
	_ = os.MkdirAll(ipcDir, 0o755)
	if url != "" {
		_ = os.WriteFile(filepath.Join(ipcDir, "telegram.url"), []byte(url+"\n"), 0o644)
	}
	ensureTelegramImage()
	_ = dockerUp(tgCompose(), "telegram-1")
	return 0
}

func telegram2(args []string) int {
	if !execx.RunOK(2*time.Second, "docker", "image", "inspect", "telegram-desktop:7.2.9") {
		return telegram1(args)
	}
	_ = dockerUp(tgCompose(), "telegram-2")
	return 0
}

func Main(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: aurora apps <name> [args]")
		return 2
	}
	cmd := args[0]
	rest := args[1:]
	switch cmd {
	case "chrome", "google-chrome", "chrome-dd":
		return runChrome(chromeSpec{"chrome-dd", "chrome-dd", "Default", nil}, rest)
	case "chrome-az":
		return runChrome(chromeSpec{"chrome-az", "chrome-az", "Profile 2", nil}, rest)
	case "chrome-hika":
		return runChrome(chromeSpec{"chrome-hika", "chrome-hika", "Profile 1", nil}, rest)
	case "chrome-sciencesoft":
		return runChrome(chromeSpec{
			"chrome-sciencesoft", "chrome-sciencesoft", "Default",
			[]string{
				"--proxy-server=socks5://127.0.0.1:1080",
				`--host-resolver-rules=MAP * ~NOTFOUND , EXCLUDE 127.0.0.1`,
			},
		}, rest)
	case "discord":
		return discord(rest)
	case "telegram-1", "telegram1":
		return telegram1(rest)
	case "telegram-2", "telegram2":
		return telegram2(rest)
	case "firefox":
		return firefoxLike("firefox", "FIREFOX_BIN", "/home/app/.mozilla/firefox/dd", rest)
	case "zen":
		return firefoxLike("zen", "ZEN_BIN", "/home/app/.zen", rest)
	case "code", "vscode":
		return electronBox("vscode", "VSCODE_BIN", []string{
			"--ozone-platform=wayland", "--force-dark-mode", "--no-sandbox", "--disable-setuid-sandbox",
			"--user-data-dir=/home/app/.config/Code",
		}, rest)
	case "obsidian":
		return electronBox("obsidian", "OBSIDIAN_BIN", []string{
			"--ozone-platform=wayland", "--force-dark-mode", "--no-sandbox", "--disable-setuid-sandbox",
		}, rest)
	case "openlens":
		return openlens(rest)
	case "spotify":
		return spotifyLaunch()
	case "idea", "idea-ultimate":
		return ideaLaunch()
	case "cursor":
		return cursorLaunch(rest)
	case "libreoffice":
		return libreoffice(rest)
	case "prismlauncher", "prism":
		return prism(rest)
	case "qbittorrent", "qbit":
		return qbittorrent(rest)
	default:
		fmt.Fprintf(os.Stderr, "apps: unknown %s\n", cmd)
		return 2
	}
}

func auroraCompose() string {
	p := filepath.Join(execx.Home(), ".local", "share", "aurora", "containers", "apps", "compose.yml")
	if _, err := os.Stat(p); err == nil {
		return p
	}
	return appsCompose()
}

func resolveGcroot(envKey, gcname, binName string) string {
	if v := os.Getenv(envKey); v != "" {
		return v
	}
	gc := filepath.Join(execx.Home(), ".local", "share", "aurora", gcname+".gcroot")
	if target, err := filepath.EvalSymlinks(gc); err == nil {
		return filepath.Join(target, "bin", binName)
	}
	return ""
}

func prism(args []string) int {
	space.LoadEnv()
	space.LoadAppsEnv()
	bin := resolveGcroot("PRISM_BIN", "prismlauncher", "prismlauncher")
	if bin == "" {
		fmt.Fprintln(os.Stderr, "apps: PRISM_BIN missing in containers/apps/.env")
		return 1
	}
	_ = dockerUp(auroraCompose(), "prismlauncher")
	if len(args) == 0 {
		return 0
	}
	env := append(space.DisplayEnv(), space.DockerEnv()...)
	return dockerExec("app", "prismlauncher", env, append([]string{bin}, args...)...)
}

func qbittorrent(args []string) int {
	space.LoadEnv()
	space.LoadAppsEnv()
	bin := resolveGcroot("QBITTORRENT_BIN", "qbittorrent", "qbittorrent")
	if bin == "" {
		fmt.Fprintln(os.Stderr, "apps: QBITTORRENT_BIN missing in containers/apps/.env")
		return 1
	}
	_ = os.Setenv("QBITTORRENT_BIN", bin)
	conf := filepath.Join(execx.Home(), "programs", "qbittorrent", ".config", "qBittorrent", "qBittorrent.conf")
	if _, err := os.Stat(conf); err != nil {
		_ = os.MkdirAll(filepath.Dir(conf), 0o755)
		_ = os.MkdirAll(filepath.Join(execx.Home(), "Downloads", "torrents"), 0o755)
		_ = os.WriteFile(conf, []byte(`[Preferences]
Connection\PortRangeMin=6881
Connection\UPnP=false
Downloads\SavePath=/home/app/Downloads
WebUI\Enabled=false
`), 0o644)
	}
	_ = dockerUp(auroraCompose(), "qbittorrent")
	env := append(space.DisplayEnv(), space.DockerEnv()...)
	if !execx.RunOK(2*time.Second, "docker", "exec", "qbittorrent", "pidof", "qbittorrent") {
		dargs := []string{"exec", "-d", "-u", "app"}
		dargs = append(dargs, env...)
		dargs = append(dargs, "qbittorrent", bin)
		_ = exec.Command("docker", dargs...).Run()
	}
	if len(args) == 0 {
		return 0
	}
	return dockerExec("app", "qbittorrent", env, append([]string{bin}, args...)...)
}

func firefoxLike(service, binEnv, profile string, args []string) int {
	space.LoadEnv()
	space.LoadAppsEnv()
	bin := os.Getenv(binEnv)
	if bin == "" {
		fmt.Fprintf(os.Stderr, "apps: %s missing in containers/apps/.env\n", binEnv)
		return 1
	}
	_ = dockerUp(appsCompose(), service)
	if len(args) == 0 {
		return 0
	}
	env := append(space.DisplayEnv(), space.DockerEnv()...)
	env = append(env, "-e", "MOZ_ENABLE_WAYLAND=1")
	argv := append([]string{bin, "--profile", profile, "--no-remote"}, args...)
	return dockerExec("app", service, env, argv...)
}

func electronBox(service, binEnv string, flags, args []string) int {
	space.LoadEnv()
	space.LoadAppsEnv()
	bin := os.Getenv(binEnv)
	if bin == "" {
		fmt.Fprintf(os.Stderr, "apps: %s missing in containers/apps/.env\n", binEnv)
		return 1
	}
	_ = dockerUp(appsCompose(), service)
	if len(args) == 0 {
		return 0
	}
	env := []string{"-e", "XDG_RUNTIME_DIR=/tmp/xdg", "-e", "WAYLAND_DISPLAY=wayland-1"}
	if service == "obsidian" {
		env = append(space.DisplayEnv(), space.DockerEnv()...)
	}
	argv := append([]string{bin}, flags...)
	argv = append(argv, args...)
	return dockerExec("app", service, env, argv...)
}

func openlens(args []string) int {
	space.LoadEnv()
	space.LoadAppsEnv()
	bin := os.Getenv("OPENLENS_BIN")
	if bin == "" {
		if app := os.Getenv("OPENLENS_APP"); app != "" {
			bin = filepath.Join(app, "open-lens")
		}
	}
	if bin == "" {
		fmt.Fprintln(os.Stderr, "apps: OPENLENS_APP missing in containers/apps/.env")
		return 1
	}
	_ = dockerUp(appsCompose(), "openlens")
	if len(args) == 0 {
		return 0
	}
	env := []string{"-e", "XDG_RUNTIME_DIR=/tmp/xdg", "-e", "WAYLAND_DISPLAY=wayland-1"}
	argv := append([]string{bin, "--ozone-platform=wayland", "--no-sandbox", "--disable-setuid-sandbox"}, args...)
	return dockerExec("app", "openlens", env, argv...)
}

func spotifyLaunch() int {
	space.LoadEnv()
	_ = os.MkdirAll(filepath.Join(execx.Home(), ".config", "spicetify"), 0o755)
	_ = os.MkdirAll(filepath.Join(execx.Home(), ".cache", "aurora", "spotify-xpui", "extensions"), 0o755)
	envf := filepath.Join(execx.Home(), ".cache", "aurora", "spotify-compose.env")
	if b, err := os.ReadFile(envf); err == nil {
		for _, line := range strings.Split(string(b), "\n") {
			line = strings.TrimSpace(line)
			if i := strings.IndexByte(line, '='); i > 0 {
				_ = os.Setenv(line[:i], strings.Trim(line[i+1:], `"'`))
			}
		}
	}
	go func() {
		if a := execx.Look("aurora"); a != "" {
			_ = exec.Command(a, "spotify", "theme").Run()
		}
	}()
	_, state := execx.Run(2*time.Second, "docker", "inspect", "-f", "{{.State.Status}}", "spotify")
	state = strings.TrimSpace(state)
	if state == "running" {
		return 0
	}
	if state != "" {
		cmd := exec.Command("docker", "start", "spotify")
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		_ = cmd.Run()
		return 0
	}
	_ = dockerUp(appsCompose(), "spotify")
	return 0
}

func ideaLaunch() int {
	space.LoadEnv()
	if !running("idea") {
		jb := filepath.Join(execx.Home(), "programs", "idea", ".config", "JetBrains")
		matches, _ := filepath.Glob(filepath.Join(jb, "IntelliJIdea*", ".lock"))
		for _, m := range matches {
			_ = os.Remove(m)
		}
		ports, _ := filepath.Glob(filepath.Join(execx.Home(), "programs", "idea", ".cache", "JetBrains", "IntelliJIdea*", ".port"))
		for _, m := range ports {
			_ = os.Remove(m)
		}
	}
	_ = dockerUp(appsCompose(), "idea")
	return 0
}

func cursorLaunch(args []string) int {
	space.LoadEnv()
	_ = os.Unsetenv("NIXOS_OZONE_WL")
	_ = os.Unsetenv("ELECTRON_OZONE_PLATFORM_HINT")
	_ = os.Setenv("GTK_USE_PORTAL", "1")
	bin := "/run/current-system/sw/bin/cursor"
	if st, err := os.Stat(bin); err != nil || st.IsDir() {
		bin = findBin("cursor")
	}
	if bin == "" {
		fmt.Fprintln(os.Stderr, "cursor: binary not found")
		return 1
	}
	cmd := exec.Command(bin, append([]string{"--ozone-platform=wayland", "--force-dark-mode"}, args...)...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}

func libreoffice(args []string) int {
	space.LoadEnv()
	space.LoadAppsEnv()
	bin := os.Getenv("LIBREOFFICE_BIN")
	if bin == "" {
		fmt.Fprintln(os.Stderr, "apps: LIBREOFFICE_BIN missing in containers/apps/.env")
		return 1
	}
	loHome := filepath.Join(execx.Home(), "programs", "libreoffice")
	lock := filepath.Join(loHome, ".config", "libreoffice", "4", ".lock")
	if _, err := os.Stat(lock); err != nil {
		_ = os.Setenv("HOME", loHome)
		_ = libreofficeui.Main(nil)
		_ = os.Setenv("HOME", execx.Home())
	}
	_ = dockerUp(appsCompose(), "libreoffice")
	if len(args) == 0 {
		return 0
	}
	env := append(space.DisplayEnv(), space.DockerEnv()...)
	env = append(env,
		"-e", "GDK_BACKEND=wayland",
		"-e", "SAL_USE_VCLPLUGIN=gtk3",
		"-e", "GTK_THEME=WhiteSur-Dark",
		"-e", "GTK_APPLICATION_PREFER_DARK_THEME=1",
		"-e", "ADW_DEBUG_COLOR_SCHEME=prefer-dark",
	)
	argv := append([]string{bin}, args...)
	return dockerExec("app", "libreoffice", env, argv...)
}
