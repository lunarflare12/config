package lab

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"aurora/internal/awgprotect"
	"aurora/internal/execx"
)

const (
	sudoBin    = "/run/wrappers/bin/sudo"
	pkexecBin  = "/run/wrappers/bin/pkexec"
	policyPath = "/etc/polkit-1/actions/org.aurora.vpnctl.policy"
)

func auroraBin() string {
	for _, p := range []string{
		filepath.Join(execx.Home(), ".local/bin/aurora"),
		"/etc/profiles/per-user/dd/bin/aurora",
		"/run/current-system/sw/bin/aurora",
	} {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	return "aurora"
}

func ensureProtectHooks(path string) {
	st, err := os.Stat(path)
	if err != nil || st.Mode()&0o200 == 0 {
		return
	}
	text, err := os.ReadFile(path)
	if err != nil {
		return
	}
	blob := string(text)
	if strings.Contains(blob, "awg-protect-endpoint.sh") || strings.Contains(blob, "awg-protect") {
		return
	}
	aurora := auroraBin()
	hookUp := "PreUp = " + aurora + " awg-protect up %i\n"
	hookAfter := "PostUp = " + aurora + " awg-protect up %i\n"
	hookDown := "PostDown = " + aurora + " awg-protect down %i\n"
	lines := strings.Split(blob, "\n")
	var out []string
	inserted := false
	for _, line := range lines {
		out = append(out, line)
		if !inserted && strings.TrimSpace(line) == "[Interface]" {
			out = append(out, strings.TrimSuffix(hookUp, "\n"), strings.TrimSuffix(hookAfter, "\n"), strings.TrimSuffix(hookDown, "\n"))
			inserted = true
		}
	}
	if !inserted {
		return
	}
	_ = os.WriteFile(path, []byte(strings.Join(out, "\n")), st.Mode())
}

func protectEndpoint(name, action string) {
	_ = awgprotect.Main([]string{action, name})
}

func toggle(kind, name string) int {
	if !nameRE.MatchString(name) {
		fmt.Fprintln(os.Stderr, "invalid name")
		return 2
	}
	if kind == "vless" {
		return toggleVless(name)
	}
	if kind == "openconnect" {
		return toggleOpenconnect(name)
	}
	var dirs []string
	var tool string
	switch kind {
	case "wireguard":
		dirs, tool = wgDirs, "wg-quick"
	case "amnezia":
		dirs, tool = awgDirs, "awg-quick"
	default:
		fmt.Fprintln(os.Stderr, "invalid kind")
		return 2
	}
	var row *tunnelRow
	for _, item := range configs(dirs) {
		if item.Name == name {
			r := item
			row = &r
			break
		}
	}
	if row == nil {
		fmt.Fprintln(os.Stderr, "config not found")
		return 1
	}
	ensureProtectHooks(row.Path)
	action := "down"
	if !row.Up {
		action = "up"
	}
	if action == "up" {
		protectEndpoint(name, "up")
	}
	code, out, err := run(40*time.Second, tool, action, row.Path)
	if action == "up" && code == 0 {
		protectEndpoint(name, "up")
	} else if action == "down" || code != 0 {
		protectEndpoint(name, "down")
	}
	emit(out, err)
	return code
}

func vpnBin() string {
	path := "/run/current-system/sw/bin/vpn-ctl"
	if st, err := os.Stat(path); err == nil && !st.IsDir() {
		if resolved, err := os.Readlink(path); err == nil && resolved != "" {
			return resolved
		}
		return path
	}
	if p := execx.Look("vpn-ctl"); p != "" {
		return p
	}
	return "vpn-ctl"
}

func guiToggle(kind, name string) int {
	if kind == "openconnect" {
		// SoftServe needs an interactive TTY for password + Microsoft MFA.
		if ocUp(name) {
			code, out, err := run(20*time.Second, sudoBin, "-n", "--", ocTunnelScript(), "down", name)
			emit(out, err)
			return code
		}
		return openconnectKitty(name)
	}
	if syscall.Geteuid() == 0 {
		return toggle(kind, name)
	}
	vpn := vpnBin()
	dirs := wgDirs
	if kind != "wireguard" {
		dirs = awgDirs
	}
	for _, item := range configs(dirs) {
		if item.Name == name {
			ensureProtectHooks(item.Path)
			break
		}
	}
	code, out, err := run(40*time.Second, sudoBin, "-n", "--", vpn, "toggle", kind, name)
	if code == 0 {
		emit(out, err)
		return 0
	}
	emit(out, err)
	if !strings.Contains(err, "password is required") && !strings.Contains(err, "a terminal is required") {
		return code
	}
	if _, err := os.Stat(policyPath); err == nil {
		if _, err := os.Stat(pkexecBin); err == nil {
			pk := exec.Command(pkexecBin, vpn, "toggle", kind, name)
			pk.Stdin = os.Stdin
			pk.Stdout = os.Stdout
			pk.Stderr = os.Stderr
			if err := pk.Run(); err == nil {
				return 0
			} else if ee, ok := err.(*exec.ExitError); ok {
				if ec := ee.ExitCode(); ec != 126 && ec != 127 {
					return ec
				}
			}
		}
	}
	kitty := execx.Look("kitty")
	if kitty == "" {
		kitty = "kitty"
	}
	argv := []string{kitty, "--class", "termfloat", "-o", "confirm_os_window_close=0", "-e", sudoBin, "--", vpn, "toggle", kind, name}
	if err := syscall.Exec(kitty, argv, os.Environ()); err != nil {
		return 1
	}
	return 1
}
