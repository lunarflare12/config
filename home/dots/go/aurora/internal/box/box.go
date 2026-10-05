package box

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"aurora/internal/execx"
)

var nameSafe = regexp.MustCompile(`[^A-Za-z0-9._-]`)

func usage() {
	fmt.Fprintln(os.Stderr, `wayland-box [--name NAME] [--offline] [--home DIR] [--bind PATH]... [--map SRC DST]... [--] CMD [ARGS...]

  --name     sandbox id (default: command basename)
  --offline  no network
  --home     override isolated HOME
  --bind     extra host path, mounted at the same place (repeatable)
  --map      extra host path SRC mounted at DST (repeatable)`)
}

func findStoreBin(name, glob string) string {
	if p := execx.Look(name); p != "" {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	matches, _ := filepath.Glob("/nix/store/" + glob)
	for _, p := range matches {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	return ""
}

func exists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// Main implements the wayland-box / bwrap CLI.
func Main(args []string) int {
	name := ""
	offline := false
	boxHome := ""
	var extraBinds []string
	var extraMaps []string // src,dst pairs

	i := 0
	for i < len(args) {
		a := args[i]
		switch {
		case a == "-h" || a == "--help":
			usage()
			return 2
		case a == "--name":
			if i+1 >= len(args) {
				usage()
				return 2
			}
			name = args[i+1]
			i += 2
		case a == "--offline":
			offline = true
			i++
		case a == "--home":
			if i+1 >= len(args) {
				usage()
				return 2
			}
			boxHome = args[i+1]
			i += 2
		case a == "--bind":
			if i+1 >= len(args) {
				usage()
				return 2
			}
			extraBinds = append(extraBinds, args[i+1])
			i += 2
		case a == "--map":
			if i+2 >= len(args) {
				usage()
				return 2
			}
			extraMaps = append(extraMaps, args[i+1], args[i+2])
			i += 3
		case a == "--":
			i++
			goto doneFlags
		case strings.HasPrefix(a, "-"):
			fmt.Fprintf(os.Stderr, "wayland-box: unknown flag %s\n", a)
			usage()
			return 2
		default:
			goto doneFlags
		}
	}
doneFlags:
	cmdArgs := args[i:]
	if len(cmdArgs) == 0 {
		usage()
		return 2
	}

	bwrap := findStoreBin("bwrap", "*-bubblewrap-*/bin/bwrap")
	if bwrap == "" {
		fmt.Fprintln(os.Stderr, "wayland-box: bwrap not found")
		return 1
	}
	proxy := findStoreBin("xdg-dbus-proxy", "*-xdg-dbus-proxy-*/bin/xdg-dbus-proxy")

	cmdBasename := filepath.Base(cmdArgs[0])
	if name == "" {
		name = cmdBasename
	}
	name = nameSafe.ReplaceAllString(name, "_")

	hostHome := os.Getenv("HOME")
	if hostHome == "" {
		fmt.Fprintln(os.Stderr, "wayland-box: HOME not set")
		return 1
	}
	hostUID := os.Getuid()
	hostRT := execx.Runtime()
	if hostRT == "" {
		hostRT = "/run/user/" + strconv.Itoa(hostUID)
	}
	wl := os.Getenv("WAYLAND_DISPLAY")
	if wl == "" {
		wl = "wayland-1"
	}
	if boxHome == "" {
		boxHome = filepath.Join(hostHome, ".local/share/wayland-box", name)
	}
	sandboxRT := filepath.Join(hostRT, "wayland-box-"+name)

	_ = os.MkdirAll(boxHome, 0o755)
	_ = os.MkdirAll(sandboxRT, 0o755)
	_ = os.MkdirAll(filepath.Join(hostHome, "Downloads"), 0o755)

	var proxyCmd *exec.Cmd
	var cleanupOnce sync.Once
	cleanup := func() {
		cleanupOnce.Do(func() {
			if proxyCmd != nil && proxyCmd.Process != nil {
				_ = proxyCmd.Process.Kill()
				_, _ = proxyCmd.Process.Wait()
			}
			_ = os.RemoveAll(sandboxRT)
		})
	}
	defer cleanup()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		cleanup()
		os.Exit(130)
	}()

	dbusSrc := os.Getenv("DBUS_SESSION_BUS_ADDRESS")
	if dbusSrc == "" {
		dbusSrc = "unix:path=" + filepath.Join(hostRT, "bus")
	}
	if proxy != "" {
		proxyCmd = exec.Command(proxy, dbusSrc, filepath.Join(sandboxRT, "bus"),
			"--filter",
			"--talk=org.freedesktop.DBus",
			"--talk=org.freedesktop.Notifications",
			"--talk=org.freedesktop.ScreenSaver",
			"--talk=org.freedesktop.portal.Desktop",
			"--talk=org.freedesktop.portal.Documents",
			"--talk=org.freedesktop.portal.FileChooser",
			"--talk=org.freedesktop.portal.OpenURI",
			"--talk=org.freedesktop.portal.Settings",
			"--talk=org.freedesktop.portal.IBus",
			"--talk=org.freedesktop.portal.IBus.Portal",
			"--talk=org.freedesktop.impl.portal.PermissionStore",
			"--talk=org.freedesktop.secrets",
			"--own=org.mpris.MediaPlayer2.spotify",
			"--own=org.mpris.MediaPlayer2.spotify.*",
			"--call=org.freedesktop.portal.*=*",
			"--broadcast=org.freedesktop.portal.*=@/org/freedesktop/portal/*",
		)
		proxyCmd.Stdout = nil
		proxyCmd.Stderr = nil
		if err := proxyCmd.Start(); err == nil {
			busSock := filepath.Join(sandboxRT, "bus")
			for n := 0; n < 10; n++ {
				if st, err := os.Stat(busSock); err == nil && st.Mode()&os.ModeSocket != 0 {
					break
				}
				// Also accept plain file existence (some systems report differently).
				if exists(busSock) {
					break
				}
				time.Sleep(50 * time.Millisecond)
			}
		} else {
			proxyCmd = nil
		}
	}

	bargs := []string{
		"--unshare-user",
		"--unshare-ipc",
		"--unshare-uts",
		"--unshare-cgroup-try",
		"--die-with-parent",
		"--new-session",
		"--hostname", "box-" + name,
		"--proc", "/proc",
		"--dev", "/dev",
		"--tmpfs", "/tmp",
		"--tmpfs", "/run/user",
		"--dir", hostRT,
		"--bind", boxHome, hostHome,
		"--bind", filepath.Join(hostHome, "Downloads"), filepath.Join(hostHome, "Downloads"),
		"--ro-bind", "/nix", "/nix",
		"--ro-bind", "/run/current-system", "/run/current-system",
		"--ro-bind", "/etc", "/etc",
		"--ro-bind-try", "/bin", "/bin",
		"--ro-bind-try", "/usr", "/usr",
		"--ro-bind-try", "/run/opengl-driver", "/run/opengl-driver",
		"--ro-bind-try", "/run/opengl-driver-32", "/run/opengl-driver-32",
		"--ro-bind-try", "/run/nscd", "/run/nscd",
		"--ro-bind-try", "/sys", "/sys",
		"--dev-bind-try", "/dev/dri", "/dev/dri",
		"--dev-bind-try", "/dev/nvidia0", "/dev/nvidia0",
		"--dev-bind-try", "/dev/nvidiactl", "/dev/nvidiactl",
		"--dev-bind-try", "/dev/nvidia-modeset", "/dev/nvidia-modeset",
		"--dev-bind-try", "/dev/nvidia-uvm", "/dev/nvidia-uvm",
		"--dev-bind-try", "/dev/nvidia-uvm-tools", "/dev/nvidia-uvm-tools",
		"--bind-try", filepath.Join(hostRT, wl), filepath.Join(hostRT, wl),
		"--bind-try", filepath.Join(hostRT, wl+".lock"), filepath.Join(hostRT, wl+".lock"),
		"--bind-try", filepath.Join(hostRT, "pipewire-0"), filepath.Join(hostRT, "pipewire-0"),
		"--bind-try", filepath.Join(hostRT, "pipewire-0.lock"), filepath.Join(hostRT, "pipewire-0.lock"),
		"--bind-try", filepath.Join(hostRT, "pulse"), filepath.Join(hostRT, "pulse"),
		"--ro-bind-try", filepath.Join(hostHome, ".local/share/fonts"), filepath.Join(hostHome, ".local/share/fonts"),
		"--ro-bind-try", filepath.Join(hostHome, ".icons"), filepath.Join(hostHome, ".icons"),
		"--ro-bind-try", filepath.Join(hostHome, ".config/fontconfig"), filepath.Join(hostHome, ".config/fontconfig"),
		"--chdir", hostHome,
		"--setenv", "HOME", hostHome,
		"--setenv", "XDG_RUNTIME_DIR", hostRT,
		"--setenv", "XDG_SESSION_TYPE", "wayland",
		"--setenv", "WAYLAND_DISPLAY", wl,
		"--setenv", "QT_QPA_PLATFORM", "wayland",
		"--setenv", "GDK_BACKEND", "wayland",
		"--setenv", "SDL_VIDEODRIVER", "wayland",
		"--setenv", "MOZ_ENABLE_WAYLAND", "1",
		"--setenv", "ELECTRON_OZONE_PLATFORM_HINT", "wayland",
		"--unsetenv", "DISPLAY",
		"--unsetenv", "XAUTHORITY",
		"--unsetenv", "HYPRLAND_INSTANCE_SIGNATURE",
		"--unsetenv", "SWAYSOCK",
		"--unsetenv", "I3SOCK",
	}

	if offline {
		bargs = append(bargs, "--unshare-net")
	}

	busPath := filepath.Join(sandboxRT, "bus")
	if exists(busPath) {
		bargs = append(bargs,
			"--bind", busPath, filepath.Join(hostRT, "bus"),
			"--setenv", "DBUS_SESSION_BUS_ADDRESS", "unix:path="+filepath.Join(hostRT, "bus"),
		)
	}

	for _, p := range extraBinds {
		if exists(p) {
			bargs = append(bargs, "--bind", p, p)
		}
	}
	for j := 0; j+1 < len(extraMaps); j += 2 {
		src, dst := extraMaps[j], extraMaps[j+1]
		if exists(src) && dst != "" && exists(dst) {
			bargs = append(bargs, "--bind", src, dst)
		}
	}

	bargs = append(bargs, "--")
	bargs = append(bargs, cmdArgs...)

	cmd := exec.Command(bwrap, bargs...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
}
