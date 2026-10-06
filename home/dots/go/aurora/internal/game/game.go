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

func inBox() bool {
	if os.Getenv("STEAM_CONTAINER") != "" {
		return true
	}
	_, err := os.Stat("/.dockerenv")
	return err == nil
}

func composePath() string {
	if c := os.Getenv("COMPOSE"); c != "" {
		return c
	}
	return filepath.Join(execx.Home(), "containers", "steam", "compose.yml")
}

func ensureXwayland() {
	sock := "/tmp/.X11-unix/X0"
	if st, err := os.Stat(sock); err == nil && !st.IsDir() {
		return
	}
	if st, err := os.Stat(sock); err == nil && st.IsDir() {
		_ = exec.Command("docker", "run", "--rm", "--user", "0", "--entrypoint", "/bin/rmdir",
			"-v", "/tmp/.X11-unix:/tmp/.X11-unix", "steam-box:1", "/tmp/.X11-unix/X0").Run()
	}
	_ = os.Remove(sock)
	_ = execx.RunOK(2*time.Second, "systemctl", "--user", "stop", "aurora-xwayland.service")
}

func fixShadercacheBind() {
	src := filepath.Join(execx.Home(), ".cache", "steam-shadercache")
	dst := "/steam/steamapps/shadercache"
	_ = os.MkdirAll(src, 0o755)
	if !execx.RunOK(2*time.Second, "findmnt", "-T", dst) {
		_ = execx.RunOK(5*time.Second, "systemctl", "restart", "steam-steamapps-shadercache.mount")
	}
	_, info := execx.Run(2*time.Second, "findmnt", "-n", "-o", "SOURCE", "-T", dst)
	info = strings.TrimSpace(info)
	if info == "" || strings.Contains(info, "//deleted") {
		fmt.Fprintf(os.Stderr, "game-lib: shadercache bind stale (%s), remounting\n", info)
		_ = execx.RunOK(5*time.Second, "systemctl", "restart", "steam-steamapps-shadercache.mount")
	}
	check := filepath.Join(dst, ".aurora-bind-check")
	if f, err := os.Create(check); err == nil {
		_ = f.Close()
		_ = os.Remove(check)
	} else {
		fmt.Fprintln(os.Stderr, "game-lib: shadercache bind not writable, remounting")
		_ = execx.RunOK(5*time.Second, "systemctl", "restart", "steam-steamapps-shadercache.mount")
	}
}

func ensureSteam() int {
	fixShadercacheBind()
	_ = exec.Command("docker", "rm", "-f", "terraria", "albion").Run()
	_, running := execx.Run(2*time.Second, "docker", "inspect", "-f", "{{.State.Running}}", "steam")
	if strings.TrimSpace(running) == "true" {
		return 0
	}
	cmd := exec.Command("docker", "compose", "-f", composePath(), "up", "-d", "--no-deps", "--no-build", "steam")
	_ = cmd.Run()
	for i := 0; i < 40; i++ {
		_, running = execx.Run(2*time.Second, "docker", "inspect", "-f", "{{.State.Running}}", "steam")
		if strings.TrimSpace(running) == "true" {
			return 0
		}
		time.Sleep(250 * time.Millisecond)
	}
	fmt.Fprintln(os.Stderr, "game-lib: steam container did not start")
	return 1
}

func stopOther(keep string) {
	_ = exec.Command("docker", "rm", "-f", "terraria", "albion").Run()
	switch keep {
	case "terraria":
		_ = exec.Command("pkill", "-x", "Albion-Online").Run()
		_ = exec.Command("pkill", "-x", "AlbionOnline").Run()
		_ = exec.Command("pkill", "-x", "AlienShooter.exe").Run()
	case "albion":
		_ = exec.Command("pkill", "-x", "Terraria.exe").Run()
		_ = exec.Command("pkill", "-x", "Terraria.bin").Run()
		_ = exec.Command("pkill", "-x", "AlienShooter.exe").Run()
	case "alien-shooter":
		_ = exec.Command("pkill", "-x", "Terraria.exe").Run()
		_ = exec.Command("pkill", "-x", "Terraria.bin").Run()
		_ = exec.Command("pkill", "-x", "Albion-Online").Run()
		_ = exec.Command("pkill", "-x", "AlbionOnline").Run()
	}
}

func hostSession(appid string, names ...string) int {
	_ = protect.Main(nil)
	ensureXwayland()
	_ = os.MkdirAll(filepath.Join(execx.Home(), "programs", "steam"), 0o755)
	if ensureSteam() != 0 {
		return 1
	}
	args := append([]string{"exec", "steam", "aurora", "game", "session", appid}, names...)
	cmd := exec.Command("docker", args...)
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

func Main(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: aurora game terraria|albion|alien-shooter|generals|steam [args]")
		return 2
	}
	switch args[0] {
	case "terraria":
		if inBox() {
			fmt.Fprintln(os.Stderr, "terraria: host launcher, not a launch-option wrapper")
			return 1
		}
		stopOther("terraria")
		return hostSession("105600", "Terraria.bin", "Terraria.exe")
	case "alien-shooter", "alienshooter":
		if inBox() {
			fmt.Fprintln(os.Stderr, "alien-shooter: host launcher, not a launch-option wrapper")
			return 1
		}
		stopOther("alien-shooter")
		return hostSession("33100", "AlienShooter.exe", "alien_shooter.exe")
	case "albion":
		return albionMain(args[1:])
	case "generals", "cnc-generals", "generals-online":
		return generalsMain(args[1:])
	case "steam":
		return steamMain(args[1:])
	case "session":
		return sessionMain(args[1:])
	default:
		fmt.Fprintln(os.Stderr, "usage: aurora game terraria|albion|alien-shooter|generals|steam [args]")
		return 2
	}
}
