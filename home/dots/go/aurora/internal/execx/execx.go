package execx

import (
	"context"
	"errors"
	"io"
	"os"
	"os/exec"
	"strconv"
	"time"
)

func Home() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	return "/home/dd"
}

func Runtime() string {
	if d := os.Getenv("XDG_RUNTIME_DIR"); d != "" {
		return d
	}
	return "/run/user/" + strconv.Itoa(os.Getuid())
}

func Run(timeout time.Duration, name string, args ...string) (int, string) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stderr = io.Discard
	out, err := cmd.Output()
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			return ee.ExitCode(), string(out)
		}
		return 1, ""
	}
	return 0, string(out)
}

func RunOK(timeout time.Duration, name string, args ...string) bool {
	code, _ := Run(timeout, name, args...)
	return code == 0
}

func Look(name string) string {
	if p, err := exec.LookPath(name); err == nil && p != "" {
		return p
	}
	user := os.Getenv("USER")
	if user == "" {
		user = "dd"
	}
	for _, dir := range []string{
		"/run/current-system/sw/bin",
		"/etc/profiles/per-user/" + user + "/bin",
	} {
		p := dir + "/" + name
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	return ""
}
