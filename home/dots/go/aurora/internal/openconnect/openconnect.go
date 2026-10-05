package openconnect

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"aurora/internal/execx"
)

var nameRE = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`)

func confPath(name string) string {
	for _, c := range []string{
		"/etc/openconnect/" + name + ".conf",
		filepath.Join(execx.Home(), ".config", "openconnect", name+".conf"),
	} {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return ""
}

func readKV(key, file string) string {
	b, err := os.ReadFile(file)
	if err != nil {
		return ""
	}
	key = strings.ToLower(key)
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if i := strings.IndexByte(line, '#'); i >= 0 {
			line = strings.TrimSpace(line[:i])
		}
		var k, v string
		if i := strings.IndexByte(line, '='); i >= 0 {
			k, v = strings.TrimSpace(line[:i]), strings.TrimSpace(line[i+1:])
		} else {
			fields := strings.Fields(line)
			if len(fields) < 2 {
				continue
			}
			k, v = fields[0], strings.Join(fields[1:], " ")
		}
		if strings.ToLower(k) == key {
			return v
		}
	}
	return ""
}

func runDir() string { return "/run/aurora-openconnect" }
func pidFile(name string) string {
	return filepath.Join(runDir(), name+".pid")
}
func stateFile(name string) string {
	return filepath.Join(runDir(), name+".bypass")
}

func alive(name string) (int, bool) {
	b, err := os.ReadFile(pidFile(name))
	if err != nil {
		return 0, false
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(b)))
	if err != nil || pid <= 0 {
		return 0, false
	}
	cmdline, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline"))
	if err != nil {
		return 0, false
	}
	return pid, strings.Contains(string(cmdline), "openconnect")
}

func lanGWDev() (gw, dev string) {
	out, err := exec.Command("ip", "-4", "route", "show", "default").Output()
	if err != nil {
		return "", ""
	}
	sc := bufio.NewScanner(strings.NewReader(string(out)))
	for sc.Scan() {
		f := strings.Fields(sc.Text())
		for i, x := range f {
			if x == "via" && i+1 < len(f) {
				gw = f[i+1]
			}
			if x == "dev" && i+1 < len(f) {
				dev = f[i+1]
			}
		}
		if gw != "" && dev != "" {
			return gw, dev
		}
	}
	return gw, dev
}

func applyBypass(name string, hosts []string) {
	gw, dev := lanGWDev()
	if gw == "" || dev == "" {
		return
	}
	_ = os.MkdirAll(runDir(), 0o755)
	f, err := os.Create(stateFile(name))
	if err != nil {
		return
	}
	defer f.Close()
	for _, h := range hosts {
		if net := regexp.MustCompile(`^[0-9.]+$`); !net.MatchString(h) {
			continue
		}
		if exec.Command("ip", "route", "replace", h+"/32", "via", gw, "dev", dev).Run() == nil {
			fmt.Fprintln(f, h)
		}
	}
}

func clearBypass(name string) {
	b, err := os.ReadFile(stateFile(name))
	if err != nil {
		return
	}
	for _, h := range strings.Split(string(b), "\n") {
		h = strings.TrimSpace(h)
		if h == "" {
			continue
		}
		_ = exec.Command("ip", "route", "del", h+"/32").Run()
	}
	_ = os.Remove(stateFile(name))
}

func killTunnel(name, conf string) {
	if pid, ok := alive(name); ok {
		p, _ := os.FindProcess(pid)
		_ = p.Signal(syscall.SIGTERM)
		for i := 0; i < 10; i++ {
			if _, err := os.Stat(filepath.Join("/proc", strconv.Itoa(pid))); err != nil {
				break
			}
			time.Sleep(200 * time.Millisecond)
		}
		_ = p.Signal(syscall.SIGKILL)
	}
	_ = os.Remove(pidFile(name))
	clearBypass(name)
	if iface := readKV("interface", conf); iface != "" {
		_ = exec.Command("ip", "link", "delete", iface).Run()
	}
}

func Main(args []string) int {
	if len(args) < 2 || !nameRE.MatchString(args[1]) {
		fmt.Fprintln(os.Stderr, "usage: aurora openconnect up|down NAME")
		return 2
	}
	action, name := args[0], args[1]
	conf := confPath(name)
	if conf == "" {
		fmt.Fprintf(os.Stderr, "openconnect config not found for %s\n", name)
		return 1
	}
	_ = os.MkdirAll(runDir(), 0o755)

	switch action {
	case "down":
		killTunnel(name, conf)
		fmt.Println("openconnect", name, "down")
		return 0
	case "up":
		if pid, ok := alive(name); ok {
			fmt.Printf("openconnect %s already up (pid %d)\n", name, pid)
			return 0
		}
		url := readKV("url", conf)
		user := readKV("user", conf)
		protocol := readKV("protocol", conf)
		iface := readKV("interface", conf)
		bypass := readKV("bypass", conf)
		if protocol == "" {
			protocol = "anyconnect"
		}
		if iface == "" {
			iface = name
		}
		if url == "" {
			fmt.Fprintf(os.Stderr, "url missing in %s\n", conf)
			return 1
		}
		if bypass != "" {
			applyBypass(name, strings.Fields(bypass))
		}
		argv := []string{"openconnect", "--protocol=" + protocol, "--interface=" + iface, "--pid-file=" + pidFile(name)}
		if user != "" {
			argv = append(argv, "--user="+user)
		}
		argv = append(argv, url)
		fmt.Printf("Connecting %s → %s (password + MFA in this terminal)\n", name, url)
		fmt.Println("Ctrl+C disconnects.")
		cmd := exec.Command(argv[0], argv[1:]...)
		cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
		if err := cmd.Run(); err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				return ee.ExitCode()
			}
			return 1
		}
		return 0
	default:
		fmt.Fprintln(os.Stderr, "usage: aurora openconnect up|down NAME")
		return 2
	}
}
