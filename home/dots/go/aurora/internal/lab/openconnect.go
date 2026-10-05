package lab

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"aurora/internal/execx"
)

var ocDirs = []string{
	"/etc/openconnect",
	filepath.Join(execx.Home(), ".config/openconnect"),
}

const ocRun = "/run/aurora-openconnect"

func ocPIDPath(name string) string {
	return filepath.Join(ocRun, name+".pid")
}

func ocTunnelScript() string {
	// Thin shim still works for kitty/sudo; prefer aurora binary.
	aurora := filepath.Join(execx.Home(), ".local/bin/aurora")
	if st, err := os.Stat(aurora); err == nil && !st.IsDir() {
		return aurora
	}
	if p := execx.Look("aurora"); p != "" {
		return p
	}
	return "aurora"
}

func ocUpArgs(name string) []string {
	script := ocTunnelScript()
	if strings.HasSuffix(script, "aurora") {
		return []string{script, "openconnect", "up", name}
	}
	return []string{script, "up", name}
}

func ocDownArgs(name string) []string {
	script := ocTunnelScript()
	if strings.HasSuffix(script, "aurora") {
		return []string{script, "openconnect", "down", name}
	}
	return []string{script, "down", name}
}

func ocUp(name string) bool {
	pidPath := ocPIDPath(name)
	raw, err := os.ReadFile(pidPath)
	if err != nil {
		return false
	}
	pid := strings.TrimSpace(string(raw))
	if pid == "" {
		return false
	}
	proc := filepath.Join("/proc", pid)
	if st, err := os.Stat(proc); err != nil || !st.IsDir() {
		return false
	}
	cmd, err := os.ReadFile(filepath.Join(proc, "cmdline"))
	if err != nil {
		return false
	}
	return strings.Contains(string(cmd), "openconnect")
}

func openconnectConfigs() []tunnelRow {
	seen := map[string]bool{}
	var out []tunnelRow
	for _, directory := range ocDirs {
		ents, err := os.ReadDir(directory)
		if err != nil {
			continue
		}
		for _, e := range ents {
			filename := e.Name()
			if !stringsHasSuffix(filename, ".conf") {
				continue
			}
			name := filename[:len(filename)-5]
			if !nameRE.MatchString(name) || seen[name] {
				continue
			}
			seen[name] = true
			path := filepath.Join(directory, filename)
			label, folder := hashMetaLines(path)
			if folder == "" {
				folder = "work"
			}
			out = append(out, tunnelRow{
				Name:   name,
				Label:  orDefault(label, name),
				Folder: folder,
				Up:     ocUp(name),
				Path:   path,
				Kind:   "openconnect",
			})
		}
	}
	return out
}

func ocConfURL(path string) string {
	fh, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer fh.Close()
	sc := bufio.NewScanner(fh)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		line = strings.Split(line, "#")[0]
		line = strings.TrimSpace(line)
		key, rest, ok := strings.Cut(line, "=")
		if !ok {
			key, rest, ok = strings.Cut(line, " ")
		}
		if !ok {
			continue
		}
		if strings.EqualFold(strings.TrimSpace(key), "url") {
			return strings.TrimSpace(rest)
		}
	}
	return ""
}

func toggleOpenconnect(name string) int {
	var row *tunnelRow
	for _, item := range openconnectConfigs() {
		if item.Name == name {
			r := item
			row = &r
			break
		}
	}
	if row == nil {
		fmt.Fprintln(os.Stderr, "openconnect config not found")
		return 1
	}
	script := ocTunnelScript()
	if _, err := os.Stat(script); err != nil {
		fmt.Fprintf(os.Stderr, "missing %s\n", script)
		return 1
	}
	if row.Up {
		args := ocDownArgs(name)
		code, out, err := run(20*time.Second, args[0], args[1:]...)
		emit(out, err)
		return code
	}
	// Interactive password + MFA — must run in a real TTY.
	if !isatty() {
		return openconnectKitty(name)
	}
	fmt.Fprintf(os.Stderr, "openconnect %s → %s (password + MFA)\n", name, orDefault(ocConfURL(row.Path), "?"))
	args := ocUpArgs(name)
	err := syscall.Exec(args[0], args, os.Environ())
	if err != nil {
		fmt.Fprintf(os.Stderr, "exec: %v\n", err)
		return 1
	}
	return 1
}

func isatty() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return (fi.Mode() & os.ModeCharDevice) != 0
}

func openconnectKitty(name string) int {
	kitty := execx.Look("kitty")
	if kitty == "" {
		kitty = "kitty"
	}
	up := ocUpArgs(name)
	argv := []string{
		kitty, "--class", "termfloat",
		"-o", "confirm_os_window_close=0",
		"-e", sudoBin, "--",
	}
	argv = append(argv, up...)
	if err := syscall.Exec(kitty, argv, os.Environ()); err != nil {
		fmt.Fprintf(os.Stderr, "kitty: %v\n", err)
		return 1
	}
	return 1
}
