package container

import (
	"os"
	"os/exec"
	"path/filepath"
)

func steamEntry(args []string) int {
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		runtime = "/tmp/xdg"
	}
	home := os.Getenv("HOME")
	if home == "" {
		home = "/home/dd"
	}

	for _, d := range []string{
		runtime,
		filepath.Join(home, ".local/share/Steam"),
		filepath.Join(home, ".steam"),
		filepath.Join(home, ".cache/steam-shadercache"),
		filepath.Join(home, ".cache/dxvk"),
		filepath.Join(home, ".config/dxvk"),
	} {
		_ = os.MkdirAll(d, 0o755)
	}

	hostBus := "/run/user/1000/bus"
	if st, err := os.Stat(hostBus); err == nil && st.Mode()&os.ModeSocket != 0 {
		_ = os.Setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path="+hostBus)
	} else if st, err := os.Stat(filepath.Join(runtime, "bus")); err == nil && st.Mode()&os.ModeSocket != 0 {
		_ = os.Setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path="+filepath.Join(runtime, "bus"))
	} else {
		_ = exec.Command("dbus-daemon", "--session", "--fork", "--address=unix:path="+filepath.Join(runtime, "bus")).Run()
		_ = os.Setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path="+filepath.Join(runtime, "bus"))
	}

	_ = os.Unsetenv("GBM_BACKEND")
	_ = os.Unsetenv("NVD_BACKEND")
	_ = os.Setenv("HOME", home)
	_ = os.Setenv("XDG_RUNTIME_DIR", runtime)
	setDefault("GDK_BACKEND", "x11")
	setDefault("QT_QPA_PLATFORM", "xcb")
	setDefault("STEAM_FORCE_DESKTOPUI_SCALING", "1")
	setDefault("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
	_ = os.Setenv("STEAM_CONTAINER", "1")
	setDefault("SSL_CERT_FILE", "/etc/ssl/certs/ca-bundle.crt")
	if v := os.Getenv("SSL_CERT_FILE"); v != "" {
		setDefault("NIX_SSL_CERT_FILE", v)
		setDefault("CURL_CA_BUNDLE", v)
	}
	setDefault("VK_ICD_FILENAMES", "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json:/run/opengl-driver-32/share/vulkan/icd.d/nvidia_icd.json")
	if v := os.Getenv("VK_ICD_FILENAMES"); v != "" {
		setDefault("VK_DRIVER_FILES", v)
	}
	ld := "/run/opengl-driver/lib:/run/opengl-driver-32/lib"
	if cur := os.Getenv("LD_LIBRARY_PATH"); cur != "" {
		ld = ld + ":" + cur
	}
	_ = os.Setenv("LD_LIBRARY_PATH", ld)
	setDefault("PULSE_SERVER", "unix:/run/user/1000/pulse/native")
	setDefault("SDL_AUDIODRIVER", "pulseaudio")

	if len(args) == 0 {
		return 127
	}
	cmd := exec.Command(args[0], args[1:]...)
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

func setDefault(key, val string) {
	if os.Getenv(key) == "" {
		_ = os.Setenv(key, val)
	}
}
