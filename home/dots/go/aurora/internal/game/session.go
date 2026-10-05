package game

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"aurora/internal/execx"
	"aurora/internal/protect"
)

func readSteamBin() (string, error) {
	b, err := os.ReadFile(filepath.Join(execx.Home(), ".local/share/aurora/steam-bin"))
	if err != nil {
		return "", err
	}
	p := strings.TrimSpace(string(b))
	if p == "" {
		return "", fmt.Errorf("empty steam-bin")
	}
	if st, err := os.Stat(p); err != nil || st.IsDir() {
		return "", fmt.Errorf("steam-bin not executable: %s", p)
	}
	return p, nil
}

func gameAlive(names ...string) bool {
	dents, err := os.ReadDir("/proc")
	if err != nil {
		return false
	}
	for _, d := range dents {
		if !d.IsDir() {
			continue
		}
		pid := d.Name()
		if _, err := strconv.Atoi(pid); err != nil {
			continue
		}
		b, err := os.ReadFile(filepath.Join("/proc", pid, "comm"))
		if err != nil {
			continue
		}
		comm := strings.TrimSpace(string(b))
		for _, pat := range names {
			if pat != "" && comm == pat {
				return true
			}
		}
	}
	return false
}

func steamAlive() bool {
	if execx.RunOK(2*time.Second, "pgrep", "-f", `/.local/share/Steam/ubuntu12_32/steam$`) {
		return true
	}
	return execx.RunOK(2*time.Second, "pgrep", "-f", `/.local/share/Steam/steam.sh`)
}

func protectCaches() {
	_ = protect.Main(nil)
}

func sessionMain(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: aurora game session APPID COMM...")
		return 2
	}
	appid := args[0]
	names := args[1:]

	steamBin, err := readSteamBin()
	if err != nil {
		fmt.Fprintln(os.Stderr, "game-session: missing ~/.local/share/aurora/steam-bin")
		return 1
	}

	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		runtime = "/tmp/xdg"
	}
	if os.Getenv("DBUS_SESSION_BUS_ADDRESS") == "" {
		_ = os.Setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path="+filepath.Join(runtime, "bus"))
	}

	home := execx.Home()
	for _, keep := range []string{
		filepath.Join(home, ".cache/nvidia/terraria"),
		filepath.Join(home, ".cache/nvidia/albion"),
	} {
		_ = os.MkdirAll(keep, 0o755)
		_ = os.WriteFile(filepath.Join(keep, ".aurora-no-delete"), []byte("protected\n"), 0o644)
	}
	protectCaches()

	nvName := appid
	switch appid {
	case "105600":
		nvName = "terraria"
	case "761890":
		nvName = "albion"
	}
	nvPath := filepath.Join(home, ".cache/nvidia", nvName)
	_ = os.MkdirAll(nvPath, 0o755)

	for i := 0; i < 60 && !steamAlive(); i++ {
		time.Sleep(500 * time.Millisecond)
	}
	if !steamAlive() {
		fmt.Fprintln(os.Stderr, "game-session: steam is not running in this container")
		return 1
	}

	_ = exec.Command(steamBin, "-forcedesktopscaling", "1", "-applaunch", appid).Run()

	appeared := false
	for i := 0; i < 3600; i++ {
		if gameAlive(names...) {
			appeared = true
			break
		}
		if !steamAlive() {
			return 1
		}
		time.Sleep(time.Second)
	}
	if !appeared {
		return 1
	}

	miss := 0
	for miss < 3 {
		if gameAlive(names...) {
			miss = 0
		} else {
			miss++
		}
		time.Sleep(time.Second)
	}

	protectCaches()
	return 0
}
