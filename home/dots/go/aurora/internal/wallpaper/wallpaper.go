package wallpaper

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"aurora/internal/execx"
)

func isVideo(path string) bool {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".mp4", ".webm", ".mkv", ".mov":
		return true
	default:
		return false
	}
}

func wallDir() string { return filepath.Join(execx.Home(), "Pictures", "Wallpapers") }

func statePath() string {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		base = filepath.Join(execx.Home(), ".local", "state")
	}
	return filepath.Join(base, "aurora", "wallpaper")
}

func cachePath() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(execx.Home(), ".cache")
	}
	return filepath.Join(base, "aurora", "current-wallpaper")
}

func readLine(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(strings.ReplaceAll(string(b), "\n", ""))
}

func resolve() string {
	dir := wallDir()
	legacy := filepath.Join(execx.Home(), "Wallpapers")
	for _, p := range []string{statePath(), cachePath()} {
		raw := readLine(p)
		if raw == "" {
			continue
		}
		if strings.HasPrefix(raw, legacy+"/") {
			raw = filepath.Join(dir, filepath.Base(raw))
		}
		if st, err := os.Stat(raw); err == nil && !st.IsDir() {
			if strings.HasPrefix(raw, dir+"/") {
				return raw
			}
			alt := filepath.Join(dir, filepath.Base(raw))
			if _, err := os.Stat(alt); err == nil {
				return alt
			}
			return raw
		}
		alt := filepath.Join(dir, filepath.Base(raw))
		if _, err := os.Stat(alt); err == nil {
			return alt
		}
	}
	ents, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	var first string
	for _, e := range ents {
		if e.IsDir() || strings.HasPrefix(e.Name(), ".") {
			continue
		}
		switch strings.ToLower(filepath.Ext(e.Name())) {
		case ".png", ".jpg", ".jpeg", ".webp":
			p := filepath.Join(dir, e.Name())
			if first == "" || p < first {
				first = p
			}
		}
	}
	return first
}

func persist(path string) {
	abs, err := filepath.EvalSymlinks(path)
	if err != nil {
		abs = path
	}
	_ = os.MkdirAll(filepath.Dir(statePath()), 0o755)
	_ = os.MkdirAll(filepath.Dir(cachePath()), 0o755)
	_ = os.WriteFile(statePath(), []byte(abs+"\n"), 0o644)
	_ = os.WriteFile(cachePath(), []byte(abs+"\n"), 0o644)
	_ = os.WriteFile(filepath.Join(wallDir(), ".current"), []byte(filepath.Base(abs)+"\n"), 0o644)
}

func mpvpaperBin() string {
	if p := execx.Look("mpvpaper"); p != "" {
		return p
	}
	link := filepath.Join(execx.Home(), ".local", "state", "aurora", "mpvpaper", "bin", "mpvpaper")
	if st, err := os.Stat(link); err == nil && !st.IsDir() {
		return link
	}
	return ""
}

func videoAlive() bool {
	return execx.RunOK(400*time.Millisecond, "pgrep", "-x", "mpvpaper") ||
		execx.RunOK(400*time.Millisecond, "pgrep", "-x", ".mpvpaper-wrapp")
}

func videoStopped() bool {
	_, out := execx.Run(400*time.Millisecond, "ps", "-o", "stat=", "-C", "mpvpaper")
	if strings.Contains(out, "T") {
		return true
	}
	_, out = execx.Run(400*time.Millisecond, "ps", "-o", "stat=", "-C", ".mpvpaper-wrapp")
	return strings.Contains(out, "T")
}

func videoOnThisCompositor() bool {
	_, layers := execx.Run(2*time.Second, "hyprctl", "layers")
	if layers == "" {
		return videoAlive() && !videoStopped()
	}
	return strings.Contains(layers, "mpvpaper")
}

func videoHealthy() bool {
	return videoAlive() && !videoStopped() && videoOnThisCompositor()
}

func dropVideo() {
	_ = execx.RunOK(2*time.Second, "systemctl", "--user", "kill", "--kill-whom=all", "-s", "KILL", "aurora-wallpaper.service")
	_ = execx.RunOK(2*time.Second, "systemctl", "--user", "stop", "--no-block", "aurora-wallpaper.service")
	_ = execx.RunOK(time.Second, "pkill", "-9", "-x", "mpvpaper")
	_ = execx.RunOK(time.Second, "pkill", "-9", "-x", ".mpvpaper-wrapp")
	for i := 0; i < 20 && videoAlive(); i++ {
		time.Sleep(50 * time.Millisecond)
	}
	_ = execx.RunOK(time.Second, "systemctl", "--user", "reset-failed", "aurora-wallpaper.service")
}

func lock() (*os.File, bool) {
	path := filepath.Join(execx.Runtime(), "aurora-apply-wallpaper.lock")
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return nil, false
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		_ = f.Close()
		return nil, false
	}
	return f, true
}

func waitAwww() bool {
	if execx.RunOK(time.Second, "awww", "query") {
		return true
	}
	_ = execx.RunOK(2*time.Second, "systemctl", "--user", "start", "--no-block", "awww.service")
	for i := 0; i < 30; i++ {
		if execx.RunOK(time.Second, "awww", "query") {
			return true
		}
		time.Sleep(200 * time.Millisecond)
	}
	return false
}

func Apply(path string) int {
	if path == "" {
		return 2
	}
	if _, err := os.Stat(path); err != nil {
		return 1
	}
	abs, err := filepath.EvalSymlinks(path)
	if err != nil {
		abs = path
	}
	lk, ok := lock()
	if !ok {
		return 0
	}
	defer func() { _ = lk.Close() }()
	dropVideo()
	if isVideo(abs) {
		bin := mpvpaperBin()
		if bin == "" {
			return 1
		}
		_ = execx.RunOK(2*time.Second, "awww", "kill")
		code, _ := execx.Run(8*time.Second, "systemd-run", "--user", "--collect", "--unit=aurora-wallpaper",
			"-p", "TimeoutStopSec=2", "-p", "KillSignal=SIGKILL", "-p", "SendSIGKILL=yes",
			bin, "-p", "-o", "no-audio loop hwdec=auto panscan=1.0 really-quiet", "*", abs)
		return code
	}
	waitAwww()
	code, _ := execx.Run(8*time.Second, "awww", "img", abs,
		"--transition-type", "grow", "--transition-pos", "center",
		"--transition-duration", "1.15", "--transition-fps", "60",
		"--transition-bezier", ".43,1.19,1,.4")
	return code
}

func Set(path string) int {
	if path == "" {
		return 2
	}
	if strings.HasPrefix(path, filepath.Join(execx.Home(), "Wallpapers")+"/") {
		path = filepath.Join(wallDir(), filepath.Base(path))
	}
	if _, err := os.Stat(path); err != nil {
		return 1
	}
	persist(path)
	return Apply(path)
}

func Load() int {
	path := resolve()
	if path == "" {
		return 1
	}
	if isVideo(path) {
		return Apply(path)
	}
	if !waitAwww() {
		return 0
	}
	code, _ := execx.Run(8*time.Second, "awww", "img", path, "--transition-type", "none")
	return code
}

func Running() bool {
	return videoAlive() ||
		execx.RunOK(400*time.Millisecond, "pgrep", "-x", "awww-daemon") ||
		execx.RunOK(400*time.Millisecond, "pgrep", "-x", ".awww-wrapped")
}

func Ensure() int {
	path := resolve()
	if path != "" && isVideo(path) {
		if videoHealthy() {
			return 0
		}
		return Load()
	}
	if Running() {
		return 0
	}
	return Load()
}

func Daemon() int {
	path := resolve()
	if path != "" && isVideo(path) {
		for {
			time.Sleep(24 * time.Hour)
		}
	}
	bin := execx.Look("awww-daemon")
	if bin == "" {
		bin = execx.Look("awww")
		if bin == "" {
			return 1
		}
		return execCmd(bin, "daemon")
	}
	return execCmd(bin)
}

func Path() int {
	path := resolve()
	if path == "" {
		user := os.Getenv("USER")
		if user == "" {
			user = "dd"
		}
		for _, p := range []string{
			filepath.Join("/etc/profiles/per-user", user, "share/sddm/themes/glyph/assets/images/background.jpg"),
			"/run/current-system/sw/share/sddm/themes/glyph/assets/images/background.jpg",
		} {
			if _, err := os.Stat(p); err == nil {
				path = p
				break
			}
		}
	}
	if path == "" {
		return 1
	}
	fmt.Println(path)
	return 0
}

func pickTool(name string) string {
	if p := execx.Look(name); p != "" {
		return p
	}
	matches, _ := filepath.Glob("/nix/store/*-" + name + "-*/bin/" + name)
	if name == "magick" {
		matches, _ = filepath.Glob("/nix/store/*-imagemagick-*/bin/magick")
	}
	if name == "ffmpeg" {
		matches, _ = filepath.Glob("/nix/store/*-ffmpeg-*/bin/ffmpeg")
	}
	if len(matches) == 0 {
		return ""
	}
	return matches[len(matches)-1]
}

func Thumbs(dirs []string) int {
	if len(dirs) == 0 {
		dirs = []string{wallDir()}
	}
	destDir := filepath.Join(func() string {
		if c := os.Getenv("XDG_CACHE_HOME"); c != "" {
			return c
		}
		return filepath.Join(execx.Home(), ".cache")
	}(), "aurora", "wallpaper-thumbs")
	_ = os.MkdirAll(destDir, 0o755)
	magick := pickTool("magick")
	ffmpeg := pickTool("ffmpeg")
	if magick == "" && ffmpeg == "" {
		return 0
	}
	for _, dir := range dirs {
		ents, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range ents {
			if e.IsDir() || strings.HasPrefix(e.Name(), ".") {
				continue
			}
			switch strings.ToLower(filepath.Ext(e.Name())) {
			case ".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".webm", ".mkv", ".mov":
			default:
				continue
			}
			src := filepath.Join(dir, e.Name())
			stem := strings.TrimSuffix(e.Name(), filepath.Ext(e.Name()))
			dest := filepath.Join(destDir, stem+".jpg")
			if skipThumb(src, dest) {
				continue
			}
			if magick != "" {
				_ = execx.RunOK(20*time.Second, magick, src, "-resize", "1280x720^", "-gravity", "center", "-extent", "1280x720", "-quality", "85", "-strip", dest)
				continue
			}
			_ = execx.RunOK(20*time.Second, ffmpeg, "-y", "-loglevel", "error", "-i", src, "-vf", "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720", "-q:v", "3", dest)
		}
	}
	return 0
}

func skipThumb(src, dest string) bool {
	ds, err := os.Stat(dest)
	if err != nil {
		return false
	}
	ss, err := os.Stat(src)
	if err != nil {
		return true
	}
	if !ss.ModTime().After(ds.ModTime()) && ds.Size() >= 40000 {
		return true
	}
	return false
}

func execCmd(name string, args ...string) int {
	cmd := exec.Command(name, args...)
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

func Main(args []string) int {
	if len(args) == 0 {
		return Load()
	}
	switch args[0] {
	case "set":
		if len(args) < 2 {
			return 2
		}
		return Set(args[1])
	case "apply":
		if len(args) < 2 {
			return 2
		}
		return Apply(args[1])
	case "load":
		return Load()
	case "ensure":
		return Ensure()
	case "daemon":
		return Daemon()
	case "path":
		return Path()
	case "thumbs":
		return Thumbs(args[1:])
	default:
		return Set(args[0])
	}
}
